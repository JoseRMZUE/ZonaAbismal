class_name CicloDia
extends Node

const NARANJA := Color("#D4A017")   # el color bajo de tu paleta

@export var hora := 17.0               # h, al empezar (tu recuadro)
@export var duracion_dia := 48.0       # s reales que dura un día de 24 h
@export var pausado := true            # fija: tu luz no cambia

func avanzar(dt: float) -> void:
	if not pausado:
		hora = fposmod(hora + dt * 24.0 / duracion_dia, 24.0)

static func elevacion(h: float) -> float:
	return (h - 6.0) * 15.0

static func factor_sol(h: float) -> float:
	return maxf(0.0, sin(deg_to_rad(elevacion(h))))

static func color_sol(h: float) -> Color:
	return NARANJA.lerp(Color.WHITE, factor_sol(h))
