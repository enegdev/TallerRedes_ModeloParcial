extends Node

# Señal que avisa si Steam se conectó o falló
signal estado_steam_cambiado(exito: bool)

var steam_activo: bool = false
var mi_steam_id: int = 0
var mi_nombre_steam: String = ""

var app_id_prueba: String = "480" 

func _ready() -> void:
	_asegurar_steam_appid()
	_inicializar_steam()

func _process(_delta: float) -> void:
	if steam_activo:
		Steam.run_callbacks()

func _asegurar_steam_appid() -> void:
	if not FileAccess.file_exists("res://steam_appid.txt"):
		var archivo = FileAccess.open("res://steam_appid.txt", FileAccess.WRITE)
		if archivo:
			archivo.store_string(app_id_prueba)
			archivo.close()

func _inicializar_steam() -> void:
	if ClassDB.class_exists("Steam") or Engine.has_singleton("Steam"):
		var respuesta = Steam.steamInit()
		
		var exito: bool = false
		if typeof(respuesta) == TYPE_BOOL:
			exito = respuesta
		elif typeof(respuesta) == TYPE_DICTIONARY:
			exito = (respuesta.get("status", -1) == 0)

		if exito:
			steam_activo = true
			mi_steam_id = Steam.getSteamID()
			mi_nombre_steam = Steam.getPersonaName()
			print("Steam conectado correctamente. Usuario: ", mi_nombre_steam, " (ID: ", mi_steam_id, ")")
		else:
			print("Advertencia: No se pudo conectar con Steam.")
		
		# Emitimos la señal con el resultado
		estado_steam_cambiado.emit(steam_activo)
	else:
		print("GodotSteam no detectado.")
		estado_steam_cambiado.emit(false)
