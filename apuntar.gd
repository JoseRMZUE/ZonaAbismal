extends Node

@export var tecla = "disparar"
@export var alcance = 2.5
@export_enum("Personaje", "Centro de la cámara", "Mouse") var desde = 0
@export var danio = 20
@export var cadencia = 0.3
@export var tras_parry = false
# SONIDO: segundos entre apretar el botón y que la espada toque en la animación
# (si el Personaje tiene "adelanto_golpe", se usa ese valor).
@export var retraso_impacto = 0.17
@onready var pj = get_parent()

var origen = Vector3.ZERO
var espera = 0.0
var reloj_doble = 0.0   # PARRY: cuánto le queda al doble daño tras un parry

func _physics_process(delta):
	espera -= delta
	# PARRY: el doble daño dura lo mismo que el aturdido del enemigo.
	if tras_parry and reloj_doble > 0.0:
		reloj_doble -= delta
		if reloj_doble <= 0.0:
			tras_parry = false
			print("se acabó el doble daño")
	if Input.is_action_pressed(tecla) and espera <= 0.001:
		espera = cadencia
		# SONIDO: el tajo de la espada suena siempre, le dé o no a algo.
		Sonido.reproducir(pj, "espada_aire")
		var golpe = lanzar_rayo()
		if golpe.is_empty():
			print("no le dio a nada en ", alcance, " m")
			return
		var d = snappedf(origen.distance_to(golpe.position), 0.01)
		print("le dio a ", golpe.collider.name, " a ", d, " m")
		if golpe.collider.has_method("recibir_golpe"):
			var danio_final = danio
			var sonido = "espada_golpe"
			if tras_parry:
				danio_final = danio * 2
				# PARRY: el doble es para UN golpe; después vuelve a lo normal.
				tras_parry = false
				reloj_doble = 0.0
				print("doble daño tras parry: ", danio_final)
				sonido = "espada_contragolpe"
			golpe.collider.recibir_golpe(danio_final)
			# SONIDO: el impacto suena cuando la espada toca en la animación.
			var retraso = retraso_impacto
			if "adelanto_golpe" in pj:
				retraso = pj.adelanto_golpe
			Sonido.reproducir(pj, sonido, golpe.position, retraso)


# PARRY: la llama parry.gd cuando un parry sale bien.
func activar_doble(segundos):
	tras_parry = true
	reloj_doble = segundos

func lanzar_rayo():
	var hacia
	if desde == 0:
		origen = pj.global_position + Vector3(0, 0.8, 0)
		hacia = origen - pj.global_basis.z * alcance
	else:
		var cam = get_viewport().get_camera_3d()
		var punto = get_viewport().get_visible_rect().size / 2
		if desde == 2:
			punto = get_viewport().get_mouse_position()
		origen = cam.project_ray_origin(punto)
		hacia = origen + cam.project_ray_normal(punto) * alcance
	var consulta = PhysicsRayQueryParameters3D.create(origen, hacia)
	consulta.exclude = [pj.get_rid()]
	return pj.get_world_3d().direct_space_state.intersect_ray(consulta)
