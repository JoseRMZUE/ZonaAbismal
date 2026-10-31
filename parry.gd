extends Node

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "parry"
@export var duracion = 0.2
@export var recarga = 0.5
@onready var pj = get_parent()

var estado = Estado.LISTA
var tiempo = 0.0
var fervor = 0


func _physics_process(delta):
	tiempo -= delta
	match estado:
		Estado.LISTA:
			if Input.is_action_just_pressed(tecla):
				empezar()
		Estado.ACTIVA:
			if tiempo <= 0.001:
				terminar()
		Estado.RECARGA:
			if tiempo <= 0.001:
				estado = Estado.LISTA


func empezar():
	estado = Estado.ACTIVA
	tiempo = duracion
	print("empieza: ", tecla)
	
	# enchufes: le decimos al Personaje qué hacer mientras el parry está activo
	pj.multiplicador = 0
	pj.empuje = Vector3.ZERO
	pj.accion = "interact-right"

	# la regla propia de Zona Abismal: el fervor
	fervor += 6
	if fervor > 100:
		fervor = 100
	print("fervor: ", fervor, "%")
	if fervor >= 100:
		print("habilidad lista")

func terminar():
	estado = Estado.RECARGA
	tiempo = recarga
	print("termina: ", tecla)
	pj.multiplicador = 1.0
	pj.accion = ""
