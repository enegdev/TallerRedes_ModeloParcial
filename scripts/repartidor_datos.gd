extends Node

# Este nodo es el "repartidor": cada vez que aparece un jugador nuevo,
# le dice en qué lugar ponerlo y de qué color pintarlo.
#
# Cómo se arma en el editor:
#   1. Agregá un nodo "Node" al nivel y ponele este script.
#   2. En la pestaña Nodo (al lado de Inspector) -> Grupos, agregá el grupo
#      "preparador_de_jugadores". Tiene que estar escrito igual que en el script
#      principal, porque así lo encuentra.
#
# Solo lo usa el SERVIDOR. Los clientes no le piden nada: reciben el lugar
# y el color ya decididos.

# Los colores y los lugares también se pueden cambiar desde el Inspector
@export var colores: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
@export var lugares: Array[Vector2] = [Vector2(100, 100), Vector2(300, 100), Vector2(100, 300), Vector2(300, 300)]

# Posición (dentro de cada lista) del próximo lugar y del próximo color a repartir
var proximo_lugar: int = 0
var proximo_color: int = 0

# Devuelve un "paquetito" con el lugar y el color del próximo jugador.
# Un Dictionary es una caja con etiquetas: acá "lugar" y "color".
func dar_datos() -> Dictionary:
	var datos = {"lugar": lugares[proximo_lugar], "color": colores[proximo_color]}

	# Avanzamos al siguiente lugar. Si ya usamos todos, volvemos al primero.
	proximo_lugar += 1
	if proximo_lugar >= lugares.size():
		proximo_lugar = 0

	# Lo mismo con los colores
	proximo_color += 1
	if proximo_color >= colores.size():
		proximo_color = 0

	return datos
