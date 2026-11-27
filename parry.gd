extends Node

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "parry"
@export var duracion = 0.2
@export var recarga = 0.5
@onready var pj = get_parent()
@export var margen = 0.15

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


# PARRY: los enemigos preguntan si el parry está activo justo cuando les llega el golpe.

func esta_activa():
	if estado == Estado.ACTIVA:
		return true
	if estado == Estado.RECARGA:
		return (recarga - tiempo) <= margen
	return false

# PARRY: un enemigo avisa que su golpe fue desviado. Prende el doble daño en
# apuntar.gd (antes era una casilla manual del Inspector) mientras dure el aturdido.
# enemigo_pos (opcional): dónde está el enemigo, para que el destello salga
# a mitad de camino entre los dos, donde chocan las armas.
func exito(segundos, enemigo_pos = null):
	print("parry exitoso: doble daño por ", segundos, " s")
	# DESTELLO + SONIDO: el choque del parry.
	var punto = pj.global_position + Vector3(0, 1.1, 0)
	if enemigo_pos != null:
		punto = punto.lerp(enemigo_pos + Vector3(0, 1.1, 0), 0.5)
	else:
		punto -= pj.global_basis.z * 0.7    # sin enemigo: delante del jugador
	Sonido.reproducir(pj, "parry", punto)
	Chispas.parry(pj, punto)
	var apuntar = pj.get_node_or_null("Apuntar")
	if apuntar != null and apuntar.has_method("activar_doble"):
		apuntar.activar_doble(segundos)
