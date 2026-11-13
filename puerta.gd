extends Area3D
# Puerta entre dos partes del escenario que el dibujo no une (por ejemplo, el
# pasillo de abajo y el salón de las gárgolas). Al entrar, el jugador aparece
# en el Marker3D "destino".
@export var destino: Marker3D


func _ready():
	body_entered.connect(_al_entrar)


func _al_entrar(cuerpo):
	if destino == null or not cuerpo.is_in_group("jugador"):
		return
	cuerpo.global_position = destino.global_position
	cuerpo.velocity = Vector3.ZERO
	var cam = get_viewport().get_camera_3d()
	if cam != null and cam.has_method("centrar"):
		cam.centrar()
	print("puerta: ", name, " -> ", destino.name, " cuadro ", Engine.get_physics_frames())
