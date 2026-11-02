class_name LuzJugador
extends OmniLight3D


@export var rango: float = 5.0
@export var altura: float = 1.2


func _ready() -> void:
	position = Vector3(0.0, altura, 0.0)

	omni_range = rango
	omni_attenuation = 2.0

	print(
		"Atenuación: ",
		atenuacion(1.0),
		" ",
		atenuacion(2.0),
		" ",
		atenuacion(4.0)
	)

	print(
		"Blinn-Phong caso 1: ",
		blinn_phong(
			Vector3(0, 1, 0),
			Vector3(0, 1, 1),
			Vector3(0, 1, -1),
			32.0
		)
	)

	print(
		"Blinn-Phong caso 2: ",
		blinn_phong(
			Vector3(0, 1, 0),
			Vector3(0, 1, 1),
			Vector3(0, 1, 0),
			32.0
		)
	)


static func atenuacion(
	d: float,
	exponente: float = 2.0
) -> float:
	return 1.0 / pow(maxf(d, 0.0001), exponente)


static func blinn_phong(
	normal: Vector3,
	hacia_luz: Vector3,
	hacia_ojo: Vector3,
	brillo: float
) -> float:
	var n = normal.normalized()
	var l = hacia_luz.normalized()
	var v = hacia_ojo.normalized()

	var h = (l + v).normalized()

	return pow(maxf(0.0, n.dot(h)), brillo)
