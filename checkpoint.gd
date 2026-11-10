extends Area3D
# Checkpoint entre Sala A y Sala B (plan de trabajo, Sesión 4).
# Es un Area3D que detecta cuando el Personaje pasa por el arco. Guarda
# el punto de reaparición en la Salud del jugador (Taller 10, Tarea C de
# Johan); si la Salud todavía no existe en el repo, solo avisa por
# consola y no se cae: así cada tarea sigue siendo independiente.


func _ready():
	body_entered.connect(_al_entrar)


func _al_entrar(cuerpo):
	if not cuerpo.is_in_group("jugador"):
		return
	var salud = cuerpo.get_node_or_null("Salud")
	if salud != null and "punto" in salud:
		salud.punto = global_position
	print("checkpoint: ", name, " cuadro ", Engine.get_physics_frames())
