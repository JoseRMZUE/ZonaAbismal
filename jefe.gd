extends Node


enum Accion { ATACAR, CARGAR, DEFENDER }


@export var ritmo: float = 1.0
@export var danio: int = 7
@export var cuantos_turnos: int = 8
@export var patron: Array[int] = [0, 0, 1, 2]


var indice: int = 0
var turno_numero: int = 0
var reloj: float = 0.0


func _ready() -> void:
	reloj = ritmo


func _physics_process(delta: float) -> void:
	if turno_numero >= cuantos_turnos:
		return

	reloj -= delta

	if reloj <= 0.001:
		reloj = ritmo
		jugar_turno()


func jugar_turno() -> void:
	turno_numero += 1

	var accion = patron[indice]
	indice = (indice + 1) % patron.size()

	print("turno ", turno_numero, ": ", Accion.keys()[accion])

	match accion:
		Accion.ATACAR:
			print("    ataca: ", danio, " de daño")

		Accion.CARGAR:
			print("    carga fuerzas")

		Accion.DEFENDER:
			print("    se defiende")
