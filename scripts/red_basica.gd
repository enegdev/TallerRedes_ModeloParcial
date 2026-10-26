extends Node

@export var contenedor_menu: Control # Opcional: Nodo padre que agrupa la UI
@export var boton_crear_partida: Button
@export var boton_unirse: Button
@export var check_steam: CheckButton
@export var campo_texto: LineEdit
@export var escena_del_jugador: PackedScene
@export var texto_mi_id: Label

var ip_del_servidor: String = "127.0.0.1"
var puerto: int = 7777
var multiplayer_spawner: MultiplayerSpawner

func _ready() -> void:
	_preparar_multiplayer_spawner()
	
	boton_crear_partida.pressed.connect(crear_partida)
	boton_unirse.pressed.connect(unirse_a_partida)

	multiplayer.peer_connected.connect(_cuando_entra_un_jugador)
	multiplayer.connected_to_server.connect(_cuando_me_conecto)

	if check_steam:
		check_steam.toggled.connect(func(_activado): _actualizar_estado_interfaz())

	var steam_autoload = get_node_or_null("/root/SteamAutoload")
	if steam_autoload:
		steam_autoload.estado_steam_cambiado.connect(func(_exito): _actualizar_estado_interfaz())
	
	_actualizar_estado_interfaz()

func _actualizar_estado_interfaz() -> void:
	var usa_steam = check_steam and check_steam.button_pressed
	var steam_autoload = get_node_or_null("/root/SteamAutoload")
	var steam_listo = steam_autoload and steam_autoload.steam_activo

	if usa_steam:
		if steam_listo:
			boton_crear_partida.disabled = false
			boton_unirse.disabled = false
			texto_mi_id.text = "Steam conectado como: " + steam_autoload.mi_nombre_steam
		else:
			boton_crear_partida.disabled = true
			boton_unirse.disabled = true
			texto_mi_id.text = "Error: Steam no está abierto o no está conectado"
	else:
		boton_crear_partida.disabled = false
		boton_unirse.disabled = false
		texto_mi_id.text = "Modo Localhost preparado"

func _preparar_multiplayer_spawner() -> void:
	multiplayer_spawner = MultiplayerSpawner.new()
	add_child(multiplayer_spawner)
	multiplayer_spawner.spawn_path = NodePath("..")
	multiplayer_spawner.spawn_function = _armar_jugador

func crear_partida() -> void:
	_ocultar_ui()

	if check_steam and check_steam.button_pressed:
		var conexion = SteamMultiplayerPeer.new()
		conexion.create_host(0)
		multiplayer.multiplayer_peer = conexion
		
		var steam_id_str = str(Steam.getSteamID())
		DisplayServer.clipboard_set(steam_id_str)
		texto_mi_id.text = "Host Steam ID: " + steam_id_str + " (¡Copiado!)"
	else:
		var conexion = ENetMultiplayerPeer.new()
		conexion.create_server(puerto)
		multiplayer.multiplayer_peer = conexion
		
		DisplayServer.clipboard_set(ip_del_servidor)
		texto_mi_id.text = "Host Localhost (IP copiada: " + ip_del_servidor + ")"

	_hacer_aparecer_jugador(1)

func unirse_a_partida() -> void:
	_ocultar_ui()
	var entrada = campo_texto.text if campo_texto else ""

	if check_steam and check_steam.button_pressed:
		var conexion = SteamMultiplayerPeer.new()
		conexion.create_client(entrada.to_int(), 0)
		multiplayer.multiplayer_peer = conexion
	else:
		var ip = entrada if entrada != "" else ip_del_servidor
		var conexion = ENetMultiplayerPeer.new()
		conexion.create_client(ip, puerto)
		multiplayer.multiplayer_peer = conexion

func _cuando_me_conecto() -> void:
	texto_mi_id.text = "Conectado | ID: " + str(multiplayer.get_unique_id())

func _cuando_entra_un_jugador(id_jugador: int) -> void:
	if multiplayer.is_server():
		_hacer_aparecer_jugador(id_jugador)

func _hacer_aparecer_jugador(id_jugador: int) -> void:
	var preparador = get_tree().get_first_node_in_group("repartidor")
	var datos = preparador.dar_datos()
	datos["id"] = id_jugador
	multiplayer_spawner.spawn(datos)

func _armar_jugador(datos: Dictionary) -> Node:
	var jugador = escena_del_jugador.instantiate()
	jugador.name = str(datos["id"])
	jugador.position = datos["lugar"]
	jugador.modulate = datos["color"]
	return jugador

func _ocultar_ui() -> void:
	if contenedor_menu:
		contenedor_menu.visible = false
	else:
		if boton_crear_partida: boton_crear_partida.visible = false
		if boton_unirse: boton_unirse.visible = false
		if check_steam: check_steam.visible = false
		if campo_texto: campo_texto.visible = false
