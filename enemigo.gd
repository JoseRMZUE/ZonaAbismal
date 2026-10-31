extends CharacterBody3D


@export var objetivo: Node3D
@export var gravedad = 30.0

@onready var anim = $Modelo/AnimationPlayer


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta

	anim.play("idle")

	move_and_slide()

	var hacia = objetivo.global_position - global_position
	hacia.y = 0.0

	if Engine.get_physics_frames() % 30 == 0:
		print("distancia ", snappedf(hacia.length(), 0.01))
