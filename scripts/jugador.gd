extends CharacterBody2D

@export var velocidad: float = 300.0
@export var escena_bala: PackedScene
@export var color_defensa: Color = Color.YELLOW
@export var vida_maxima: int = 3
@export var tiempo_respawn: float = 4.0

# Vida actual: la controla el servidor y se copia a todos (sirve para hacer una barra de vida)
var vida: int = 3
# Capa de colisión original, para devolvérsela al personaje cuando revive
var capa_original: int = 0

# Estas variables solo se usan en el servidor
var defensa_disponible: bool = true
var direccion_recibida: Vector2 = Vector2.ZERO  # lo que el jugador está apretando
var ultima_direccion: Vector2 = Vector2.RIGHT   # hacia dónde mira
var contador_balas: int = 0  # para darle un nombre único a cada bala
var esta_muerto: bool = false
var esta_defendiendose: bool = false  # mientras es true, no recibe daño
var posicion_inicial: Vector2 = Vector2.ZERO  # donde reaparece el personaje


# _ready: se ejecuta una vez, cuando el personaje entra a la escena
func _ready() -> void:
	vida = vida_maxima
	capa_original = collision_layer

	# Nodo que copia la posición y la vida del servidor a todos los jugadores
	var sincronizador := MultiplayerSynchronizer.new()
	sincronizador.name = "SincronizadorPos"
	sincronizador.replication_config = SceneReplicationConfig.new()
	sincronizador.replication_config.add_property(":position")
	sincronizador.replication_config.add_property(":vida")
	add_child(sincronizador)

	# Esperamos un cuadro para guardar dónde apareció el personaje: ahí va a reaparecer
	await get_tree().process_frame
	posicion_inicial = global_position


# ¿Este personaje lo controla esta computadora? (el nombre del nodo es el ID del jugador)
func es_mio() -> bool:
	return name.to_int() == multiplayer.get_unique_id()


# ¿El pedido es válido? Solo el servidor lo acepta, solo si lo mandó el dueño del personaje
# y solo si el personaje está vivo (muerto no se mueve, no dispara ni se defiende)
func _pedido_valido() -> bool:
	var quien_envio := multiplayer.get_remote_sender_id()
	if quien_envio == 0:  # 0 = lo mandó el propio servidor, que siempre tiene ID 1
		quien_envio = 1
	return multiplayer.is_server() and quien_envio == name.to_int() and not esta_muerto


# _physics_process: se ejecuta en cada paso de física (unas 60 veces por segundo)
func _physics_process(_delta: float) -> void:
	# Cada jugador solo le avisa al servidor qué está apretando
	if es_mio():
		var direccion := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		enviar_direccion.rpc_id(1, direccion)

	# El movimiento real lo hace SOLO el servidor
	if multiplayer.is_server():
		if direccion_recibida != Vector2.ZERO:
			ultima_direccion = direccion_recibida.normalized()
		velocity = direccion_recibida * velocidad
		move_and_slide()


# _input: se ejecuta cada vez que el jugador hace clic, toca una tecla, etc.
func _input(evento: InputEvent) -> void:
	if not es_mio():
		return

	if evento is InputEventMouseButton and evento.pressed:
		if evento.button_index == MOUSE_BUTTON_LEFT:
			pedir_disparo.rpc_id(1)    # clic izquierdo: pedir disparar
		elif evento.button_index == MOUSE_BUTTON_RIGHT:
			pedir_defensa.rpc_id(1)    # clic derecho: pedir defenderse


# --- Cliente -> Servidor: pedidos ---
# any_peer: cualquier jugador puede llamarlas, por eso el servidor las valida

@rpc("any_peer", "call_local", "unreliable_ordered")
func enviar_direccion(direccion: Vector2) -> void:
	if _pedido_valido():
		direccion_recibida = direccion


@rpc("any_peer", "call_local", "reliable")
func pedir_disparo() -> void:
	if _pedido_valido():
		contador_balas += 1
		disparar_remoto.rpc(global_position, ultima_direccion, contador_balas)


@rpc("any_peer", "call_local", "reliable")
func pedir_defensa() -> void:
	# El cooldown lo controla el servidor, así nadie se lo puede saltar
	if _pedido_valido() and defensa_disponible:
		defensa_disponible = false
		aplicar_defensa_remoto.rpc()
		await get_tree().create_timer(5.0).timeout
		defensa_disponible = true


# --- Servidor -> Todos: órdenes ---
# authority: solo el servidor puede llamarlas

@rpc("authority", "call_local", "reliable")
func disparar_remoto(posicion: Vector2, direccion: Vector2, numero: int) -> void:
	if escena_bala:
		var bala = escena_bala.instantiate()
		# Mismo nombre en todas las computadoras, así el servidor puede referirse a esta bala
		bala.name = "Bala_%s_%d" % [name, numero]
		# La bala necesita saber quién la disparó para no chocar con esa persona
		bala.dueno = self
		get_tree().root.add_child(bala)
		bala.global_position = posicion
		bala.rotation = direccion.angle()


@rpc("authority", "call_local", "reliable")
func aplicar_defensa_remoto() -> void:
	esta_defendiendose = true
	var color_original = modulate
	modulate = color_defensa
	await get_tree().create_timer(1.5).timeout
	esta_defendiendose = false
	modulate = color_original


# --- Vida y respawn ---

# Lo llama la bala cuando golpea a este personaje (solo actúa en el servidor)
func recibir_dano(cantidad: int) -> void:
	# Solo el servidor aplica el daño, y no si está muerto o defendiéndose
	if not multiplayer.is_server() or esta_muerto or esta_defendiendose:
		return

	vida -= cantidad
	if vida <= 0:
		morir_y_respawnear()


# El servidor manda morir, espera unos segundos y manda reaparecer
func morir_y_respawnear() -> void:
	esta_muerto = true
	vida = 0
	direccion_recibida = Vector2.ZERO  # frena al personaje
	morir_remoto.rpc()

	await get_tree().create_timer(tiempo_respawn).timeout

	vida = vida_maxima
	esta_muerto = false
	respawnear_remoto.rpc(posicion_inicial)


@rpc("authority", "call_local", "reliable")
func morir_remoto() -> void:
	visible = false
	# Sin colisión, las balas lo atraviesan mientras está muerto
	set_deferred("collision_layer", 0)


@rpc("authority", "call_local", "reliable")
func respawnear_remoto(posicion: Vector2) -> void:
	global_position = posicion
	visible = true
	set_deferred("collision_layer", capa_original)
