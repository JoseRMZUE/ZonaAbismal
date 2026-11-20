extends CharacterBody3D


enum Estado { PATRULLA, PERSEGUIR }


@export var objetivo: Node3D
@export var rapidez = 2.0
@export var radio_ver = 3.0
@export var radio_perder = 5.0
@export var gravedad = 30.0
@export var vida = 60

@export var puntos: Array[Vector3] = [
	Vector3(-5, 0, 0),
	Vector3(5, 0, 0)
]


@onready var anim = $Modelo/AnimationPlayer


var estado = Estado.PATRULLA
var punto = 0


func _ready():
	if objetivo == null:
		objetivo = get_tree().get_first_node_in_group("jugador") as Node3D


func _physics_process(delta):
	if not is_instance_valid(objetivo):
		objetivo = get_tree().get_first_node_in_group("jugador") as Node3D
	if objetivo == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if puntos.is_empty():
		push_warning("Enemigo: no hay puntos de patrulla asignados.")
		return

	if not is_on_floor():
		velocity.y -= gravedad * delta

	var distancia = global_position.distance_to(objetivo.global_position)
	var ve_al_jugador = _hay_linea_de_vision()

	match estado:
		Estado.PATRULLA:
			if distancia < radio_ver and ve_al_jugador:
				estado = Estado.PERSEGUIR
				print("lo vio a ", snappedf(distancia, 0.01), " m")
				print("destello")

			ir_a(puntos[punto])

			if global_position.distance_to(puntos[punto]) < 0.3:
				punto = (punto + 1) % puntos.size()

		Estado.PERSEGUIR:
			if distancia > radio_perder or not ve_al_jugador:
				estado = Estado.PATRULLA
				print("perdió visión del jugador a ", snappedf(distancia, 0.01), " m")
				ir_a(puntos[punto])
			else:
				ir_a(objetivo.global_position)

	move_and_slide()


func _hay_linea_de_vision() -> bool:
	var desde: Vector3 = global_position + Vector3(0, 0.9, 0)
	var hasta: Vector3 = objetivo.global_position + Vector3(0, 0.9, 0)
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	consulta.collision_mask = 0xFFFFFFFF
	consulta.exclude = [get_rid()]
	var impacto = get_world_3d().direct_space_state.intersect_ray(consulta)
	if impacto.is_empty():
		return true
	var collider = impacto.get("collider") as Node
	return collider == objetivo or (collider != null and collider.is_in_group("jugador"))


func ir_a(p):
	var hacia = p - global_position
	hacia.y = 0.0
	hacia.z = 0.0

	if hacia.length() < 0.05:
		velocity.x = 0.0
		anim.play("idle")
		return

	var dir = hacia.normalized()

	velocity.x = dir.x * rapidez
	velocity.z = 0.0

	rotation.y = -PI / 2 * sign(dir.x)

	anim.play("walk")
	
func recibir_golpe(danio):
	vida -= danio
	print(name, ": vida ", vida)
	if vida <= 0:
		print(name, " destruida")
		queue_free()
