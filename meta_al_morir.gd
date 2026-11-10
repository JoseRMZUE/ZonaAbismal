extends Node
# Nodo hijo que se le cuelga a un enemigo en main.tscn, sin tocar el
# script del enemigo (regla del taller: nadie edita el archivo de otro).
# Cuando el enemigo muere (queue_free), le avisa una meta a la Partida.

var arbol = null


func _ready():
	# Se guarda aquí: cuando el padre sale del árbol, este hijo ya salió
	# también y get_tree() daría null.
	arbol = get_tree()
	get_parent().tree_exiting.connect(_al_morir)


func _al_morir():
	# Solo cuenta si el padre murió con queue_free (muerte real jugando),
	# no cuando la escena entera se está cerrando o recargando.
	if arbol == null or not get_parent().is_queued_for_deletion():
		return
	var partida = arbol.get_first_node_in_group("partida")
	if partida != null and partida.is_inside_tree():
		partida.avisar_meta()
