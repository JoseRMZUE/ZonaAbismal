class_name Chispas
extends RefCounted
# Destello del parry: una ráfaga de chispas y un fogonazo de luz dorada donde
# chocan las armas. Se llama desde cualquier script:
#
#     Chispas.parry(self, punto_del_choque)
#
# Crea las chispas y la luz sueltas en la escena y se borran solas.

const COLOR_LUZ = Color(1.0, 0.82, 0.45)


static func parry(desde: Node, posicion: Vector3) -> void:
	if desde == null or not desde.is_inside_tree():
		return
	var escena = desde.get_tree().current_scene
	if escena == null:
		return

	# 1. Las chispas: bolitas que salen en todas direcciones, caen y se apagan.
	var chispas = CPUParticles3D.new()
	chispas.one_shot = true
	chispas.explosiveness = 1.0         # salen todas juntas, de golpe
	chispas.amount = 36
	chispas.lifetime = 0.55
	chispas.spread = 180.0
	chispas.initial_velocity_min = 2.5
	chispas.initial_velocity_max = 7.0
	chispas.damping_min = 2.0
	chispas.damping_max = 5.0
	chispas.gravity = Vector3(0, -9.0, 0)
	var malla = SphereMesh.new()
	malla.radius = 0.03
	malla.height = 0.06
	malla.radial_segments = 6
	malla.rings = 3
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	malla.material = material
	chispas.mesh = malla
	# De blanco-amarillo caliente a naranja que se apaga.
	var degradado = Gradient.new()
	degradado.colors = PackedColorArray([Color(1.0, 1.0, 0.85, 1.0), Color(1.0, 0.55, 0.12, 0.0)])
	chispas.color_ramp = degradado
	chispas.finished.connect(chispas.queue_free)
	escena.add_child(chispas)
	chispas.global_position = posicion
	chispas.emitting = true

	# 2. El fogonazo: una luz que alumbra todo de golpe y se apaga rápido.
	var luz = OmniLight3D.new()
	luz.light_color = COLOR_LUZ
	luz.light_energy = 9.0
	luz.omni_range = 6.0
	escena.add_child(luz)
	luz.global_position = posicion
	var tween = luz.create_tween()
	tween.tween_property(luz, "light_energy", 0.0, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(luz.queue_free)
