extends Node


@export var tecla = "interactuar"
@export var alcance = 1.5
@export var tiempo_necesario = 1.5

@onready var pj = get_parent()


var progreso = 0.0
var actual = null
var aviso_sin_objeto = false


func _physics_process(delta):
	var obj = mas_cercano()

	# Si el jugador no mantiene presionada la tecla,
	# se reinicia la interacción.
	if not Input.is_action_pressed(tecla):
		progreso = 0.0
		actual = null
		aviso_sin_objeto = false
		return

	# Si mantiene la tecla, pero no hay ningún objeto
	# dentro del alcance.
	if obj == null:
		if not aviso_sin_objeto:
			print("nada a menos de ", alcance, " m")
			aviso_sin_objeto = true

		progreso = 0.0
		actual = null
		return

	# Hay un objeto dentro del alcance.
	aviso_sin_objeto = false

	# Si cambió el objeto, el progreso vuelve a cero.
	if obj != actual:
		actual = obj
		progreso = 0.0

	var antes = progreso

	# Aumenta el progreso según el tiempo necesario.
	progreso += delta / tiempo_necesario

	# Muestra el avance cada 25%.
	if int(progreso * 4) > int(antes * 4) and progreso < 0.999:
		print(obj.name, ": ", int(progreso * 4) * 25, " %")

	# Completa la interacción.
	if progreso >= 0.999:
		print("completado: ", obj.name)

		# Si el objeto tiene una función usar(), la ejecuta.
		if obj.has_method("usar"):
			obj.usar()

		progreso = 0.0
		actual = null


func mas_cercano():
	var mejor = null

	for obj in get_tree().get_nodes_in_group("interactivos"):
		var d = distancia_a(obj)

		if d <= alcance and (mejor == null or d < distancia_a(mejor)):
			mejor = obj

	return mejor


func distancia_a(obj):
	# En el juego 2.5D solo se calcula la distancia
	# usando los ejes X y Z. Se ignora Y.
	var a = Vector2(
		pj.global_position.x,
		pj.global_position.z
	)

	var b = Vector2(
		obj.global_position.x,
		obj.global_position.z
	)

	return a.distance_to(b)
