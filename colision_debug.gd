extends Node3D
# Vista de depuración: dibuja en ROJO el borde de las colisiones del escenario.
# Actívala con "Mostrar" en el Inspector (o con la tecla F2 al jugar).
@export var mostrar = false:
	set(valor):
		mostrar = valor
		if _malla:
			_malla.visible = mostrar
var _malla: MeshInstance3D


func _ready():
	var cuerpo = get_parent().get_node_or_null("Colision")
	if cuerpo == null:
		return
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for forma in cuerpo.get_children():
		if not (forma is CollisionShape3D) or forma.shape == null:
			continue
		var caras = forma.shape.get_faces()
		for i in range(0, caras.size(), 3):
			for j in 3:
				var a = caras[i + j]
				var b = caras[i + (j + 1) % 3]
				if a.z > 0.5 and b.z > 0.5:     # solo el borde delantero
					im.surface_add_vertex(Vector3(a.x, a.y, 0.6))
					im.surface_add_vertex(Vector3(b.x, b.y, 0.6))
	im.surface_end()
	_malla = MeshInstance3D.new()
	_malla.mesh = im
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.1, 0.1)
	mat.no_depth_test = true
	_malla.material_override = mat
	_malla.visible = mostrar
	add_child(_malla)


func _unhandled_key_input(evento):
	if evento is InputEventKey and evento.pressed and evento.keycode == KEY_F2:
		mostrar = not mostrar
