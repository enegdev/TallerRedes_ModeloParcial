extends Area2D

@export var velocidad: float = 500.0
@export var tiempo_de_vida: float = 3.0
@export var valor_impacto: int = 1

# Quién disparó la bala (la asigna el personaje al crearla)
var dueno: Node = null
# Solo lo usa el servidor, para no procesar dos impactos de la misma bala
var ya_golpeo: bool = false


# _ready: se ejecuta una vez, cuando la bala aparece en la escena
func _ready() -> void:
	# body_entered: señal que Godot emite cuando un cuerpo entra al área de la bala
	body_entered.connect(_al_tocar_cuerpo)

	# La bala se borra sola después de unos segundos
	await get_tree().create_timer(tiempo_de_vida).timeout
	queue_free()


# _process: se ejecuta en cada cuadro del juego
func _process(delta: float) -> void:
	# transform.x es el "forward" (adelante) de la bala: hacia donde apunta
	position += transform.x * velocidad * delta


# Se ejecuta cuando la bala toca un cuerpo (una pared, otro jugador, etc.)
func _al_tocar_cuerpo(cuerpo: Node2D) -> void:
	# Solo el servidor decide los impactos
	if not multiplayer.is_server() or ya_golpeo:
		return

	# La bala no choca con quien la disparó
	if cuerpo == dueno:
		return

	ya_golpeo = true

	# Si lo que tocó puede recibir daño (un personaje), se lo hacemos
	if cuerpo.has_method("recibir_dano"):
		cuerpo.recibir_dano(valor_impacto)

	destruir.rpc()


# authority: solo el servidor puede llamarla. Le ordena a todos que borren esta bala
@rpc("authority", "call_local", "reliable")
func destruir() -> void:
	queue_free()
