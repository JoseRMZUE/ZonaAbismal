extends Node
# Nodo hijo que se le cuelga a un enemigo en main.tscn, sin tocar el
# script del enemigo (regla del taller: nadie edita el archivo de otro).
# Cuando el enemigo muere (queue_free), le avisa una meta a la Partida y
# le entrega los puntos que vale (concepto: Acólito = 10).
#
# Sesión 5: además lo registra en la Partida para que, si el jugador cae y
# reaparece, el enemigo vivo vuelva a su sitio con la vida completa.

@export var puntos = 10

var arbol = null


func _ready():
	# Se guarda aquí: cuando el padre sale del árbol, este hijo ya salió
	# también y get_tree() daría null.
	arbol = get_tree()
	get_parent().tree_exiting.connect(_al_morir)
	call_deferred("_registrar")


func _registrar():
	var partida = arbol.get_first_node_in_group("partida")
	if partida != null and is_instance_valid(get_parent()):
		partida.registrar_enemigo(get_parent())


func _al_morir():
	# Solo cuenta si el padre murió con queue_free (muerte real jugando),
	# no cuando la escena entera se está cerrando o recargando.
	if arbol == null or not get_parent().is_queued_for_deletion():
		return
	var partida = arbol.get_first_node_in_group("partida")
	if partida != null and partida.is_inside_tree():
		partida.avisar_meta(puntos)
