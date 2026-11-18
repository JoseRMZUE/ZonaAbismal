extends Area3D
# Puerta entre dos partes del escenario que el dibujo no une (por ejemplo, el
# pasillo de abajo y el salón de las gárgolas). Al entrar, el jugador aparece
# en el Marker3D "destino".
#
# Sesión 5: la puerta puede estar SELLADA (abierta = false) hasta que el
# juego la abra con abrir(): el resplandor dorado solo está cuando se puede
# pasar. Con abierta = true (por defecto) se comporta como antes.
signal cruzada
signal se_abrio

@export var destino: Marker3D
@export var abierta = true
@export var aviso_sellada = "La puerta está sellada."

var _luz = null
var _brillo = null
var _energia = 1.0
var _espera_aviso = 0.0


func _ready():
	body_entered.connect(_al_entrar)
	_luz = get_node_or_null("Luz")
	_brillo = get_node_or_null("Resplandor")
	if _luz != null:
		_energia = _luz.light_energy
	_aspecto(abierta, false)


func _process(delta):
	_espera_aviso = maxf(_espera_aviso - delta, 0.0)


func abrir():
	if abierta:
		return
	abierta = true
	_aspecto(true, true)
	print("puerta: ", name, " se abre cuadro ", Engine.get_physics_frames())
	se_abrio.emit()
	# Si el jugador justo estaba parado dentro, body_entered no vuelve a
	# avisar: se revisa un instante después de abrirse.
	get_tree().create_timer(1.2).timeout.connect(_revisar_dentro)


func _revisar_dentro():
	if not abierta:
		return
	for cuerpo in get_overlapping_bodies():
		_al_entrar(cuerpo)


func cerrar():
	abierta = false
	_aspecto(false, false)


# Sellada: sin resplandor y con la luz casi apagada.
func _aspecto(abierta_ahora, animado):
	if _brillo != null:
		_brillo.visible = abierta_ahora
		if abierta_ahora and animado:
			_brillo.scale = Vector3(0.1, 0.1, 0.1)
			create_tween().tween_property(_brillo, "scale", Vector3.ONE, 0.8)
	if _luz != null:
		if abierta_ahora and animado:
			_luz.light_energy = 0.0
			create_tween().tween_property(_luz, "light_energy", _energia, 0.8)
		else:
			_luz.light_energy = _energia if abierta_ahora else 0.0


func _al_entrar(cuerpo):
	if not cuerpo.is_in_group("jugador"):
		return
	if not abierta:
		if _espera_aviso <= 0.001:
			_espera_aviso = 2.0
			get_tree().call_group("hud", "mensaje", aviso_sellada, 2.5)
			print("puerta: ", name, " sellada")
		return
	if destino == null:
		return
	cuerpo.global_position = destino.global_position
	cuerpo.velocity = Vector3.ZERO
	var cam = get_viewport().get_camera_3d()
	if cam != null and cam.has_method("centrar"):
		cam.centrar()
	print("puerta: ", name, " -> ", destino.name, " cuadro ", Engine.get_physics_frames())
	cruzada.emit()
