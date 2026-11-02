class_name LuzJugador
extends OmniLight3D


@export var rango: float = 5.0
@export var altura: float = 1.2


func _ready() -> void:
	position = Vector3(0.0, altura, 0.0)
	omni_range = rango
	omni_attenuation = 2.0

	print(
		atenuacion(1.0),
		" ",
		atenuacion(2.0),
		" ",
		atenuacion(4.0)
	)


static func atenuacion(d: float, exponente: float = 2.0) -> float:
	return 1.0 / pow(maxf(d, 0.0001), exponente)
