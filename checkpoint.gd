extends Area3D
# Checkpoint entre Sala A y Sala B (plan de trabajo, Sesión 4).
# Es un Area3D que detecta cuando el Personaje pasa por el arco. Le avisa
# a la Partida dónde está, y ahí reaparece el jugador al quedarse sin vidas
# (Sesión 5). Si la Salud tuviera la variable "punto", también la llena, para
# no romper la idea original del Taller 10.
var ya_aviso = false


func _ready():
	body_entered.connect(_al_entrar)


func _al_entrar(cuerpo):
	if not cuerpo.is_in_group("jugador"):
		return
	var salud = cuerpo.get_node_or_null("Salud")
	if salud != null and "punto" in salud:
		salud.punto = global_position
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null:
		partida.guardar_checkpoint(global_position)
		if not ya_aviso:
			get_tree().call_group("hud", "mensaje", "Punto de control guardado", 2.5)
	ya_aviso = true
	print("checkpoint: ", name, " cuadro ", Engine.get_physics_frames())
