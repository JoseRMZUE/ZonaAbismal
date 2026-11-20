extends Node3D

@export var cantidad: int = 20
@export var vida_recuperada: int = 1
@export var es_rastro: bool = false
@export var es_ceniza_muerte: bool = false

var usada = false
var luz = null
var punto = null
var polvo = null
var t = 0.0
var tween_desvanecer: Tween


func _ready():
	add_to_group("interactivos")
	_armar()


func _armar():
	var color = Color(0.831, 0.627, 0.094) if not es_rastro else Color(0.78, 0.7, 0.5)
	var escala = 1.0 if not es_rastro else 0.7
	# montículo: tres bultos redondeados de polvo, medio enterrados
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.55
	for datos in [[0.0, 0.5, 0.22], [-0.38, 0.32, 0.15], [0.36, 0.3, 0.14]]:
		var bulto = MeshInstance3D.new()
		var m = SphereMesh.new()
		m.radius = datos[1] * escala
		m.height = datos[1] * 2.0 * escala
		m.radial_segments = 12
		m.rings = 6
		bulto.mesh = m
		bulto.material_override = mat
		bulto.scale = Vector3(1.0, 0.8, 0.8)
		bulto.position = Vector3(datos[0] * escala, datos[2] * 0.1 * escala, 0.0)
		add_child(bulto)
	# punto de luz que se ve de lejos (concepto: "un punto de luz que guía")
	var tex = GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g = Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.86, 0.4, 0.85), Color(1, 0.7, 0.2, 0.0)])
	tex.gradient = g
	var brillo = Sprite3D.new()
	brillo.texture = tex
	brillo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	brillo.shaded = false
	brillo.transparent = true
	brillo.double_sided = true
	brillo.no_depth_test = true
	brillo.pixel_size = 0.018 * escala
	brillo.position = Vector3(0, 0.5 * escala, 0.3)
	brillo.modulate = Color(1, 1, 1, 0.9)
	add_child(brillo)
	punto = brillo
	luz = OmniLight3D.new()
	luz.light_color = color
	luz.light_energy = 0.9
	luz.omni_range = 3.5
	luz.position = Vector3(0, 0.7, 0.6)
	add_child(luz)
	# polvo dorado que sube despacio
	polvo = CPUParticles3D.new()
	polvo.amount = 10
	polvo.lifetime = 1.8
	polvo.direction = Vector3.UP
	polvo.spread = 25.0
	polvo.initial_velocity_min = 0.25
	polvo.initial_velocity_max = 0.5
	polvo.gravity = Vector3.ZERO
	polvo.scale_amount_min = 0.03
	polvo.scale_amount_max = 0.06
	var pm = SphereMesh.new()
	pm.radius = 0.5
	pm.height = 1.0
	pm.radial_segments = 6
	pm.rings = 3
	var pmat = StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(1, 0.8, 0.35)
	pm.material = pmat
	polvo.mesh = pm
	polvo.position = Vector3(0, 0.2, 0.1)
	add_child(polvo)


func _process(delta):
	t += delta
	if luz != null and not usada:
		luz.light_energy = 0.9 + 0.3 * sin(t * 3.0)
	if punto != null and not usada:
		punto.modulate.a = 0.75 + 0.2 * sin(t * 3.0)


# La llama interactuar.gd al completar el progreso.
func usar():
	if usada:
		return
	var partida = get_tree().get_first_node_in_group("partida")
	if partida == null or not partida.has_method("recuperar_ceniza"):
		return
	if partida.recuperar_ceniza(self, cantidad, vida_recuperada):
		desvanecer()
	else:
		get_tree().call_group("hud", "mensaje", "No se pudo absorber la ceniza", 2.0)


# Se recoge o se pierde: en los dos casos el montículo se apaga y se va.
func desvanecer():
	if usada:
		return
	usada = true
	remove_from_group("interactivos")
	tween_desvanecer = create_tween()
	tween_desvanecer.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	if luz != null:
		tween_desvanecer.parallel().tween_property(luz, "light_energy", 0.0, 0.5)
	tween_desvanecer.tween_callback(queue_free)


func eliminar_inmediatamente() -> void:
	# Se usa si el jugador vuelve a morir antes de recuperar su ceniza anterior.
	# No depende de que termine un tween: no puede quedar un resto visible ni interactivo.
	usada = true
	remove_from_group("interactivos")
	if tween_desvanecer != null and tween_desvanecer.is_running():
		tween_desvanecer.kill()
	hide()
	set_process(false)
	set_physics_process(false)
	queue_free()
