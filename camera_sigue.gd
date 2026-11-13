extends Camera3D

@export var objetivo: Node3D
@export var distancia = Vector3(0, 12, 4)
@export var suavizado = 3.0
@export var limite_min = Vector2(-3, -10)   # x y z mínimas
@export var limite_max = Vector2(3, 10)     # x y z máximas

@export_group("Vista lateral (metroidvania)")
# Con "Lateral" la cámara mira recto hacia el escenario (sin inclinación),
# así los pies del personaje coinciden con el piso pintado del fondo.
@export var lateral = false
@export var distancia_z = 20.0              # qué tan lejos del plano del personaje
@export var desfase_y = 1.5                 # cuánto sube la cámara sobre el personaje
# Rectángulo del mapa en metros (x, y, ancho, alto). La cámara no sale de él.
@export var area_mapa = Rect2(0, 0, 0, 0)


func _ready():
	top_level = true
	if lateral:
		rotation = Vector3.ZERO
		global_position = _destino()
		return
	# Se orienta UNA vez, mirando al objetivo.
	look_at_from_position(objetivo.global_position + distancia,
		objetivo.global_position)


func _physics_process(delta):
	if lateral:
		global_position = global_position.lerp(_destino(), clampf(suavizado * delta, 0.0, 1.0))
		return
	var foco = objetivo.global_position
	foco.x = clamp(foco.x, limite_min.x, limite_max.x)
	foco.z = clamp(foco.z, limite_min.y, limite_max.y)
	var destino = foco + distancia
	global_position = global_position.lerp(destino, suavizado * delta)


# Dónde quiere estar la cámara (centrada en el personaje y dentro del mapa).
func _destino():
	var p = objetivo.global_position
	var d = Vector3(p.x, p.y + desfase_y, distancia_z)
	if area_mapa.size.x > 0.0:
		var mitad_alto = size / 2.0
		var vista = get_viewport().get_visible_rect().size
		var mitad_ancho = mitad_alto * vista.x / maxf(vista.y, 1.0)
		d.x = _dentro(d.x, area_mapa.position.x + mitad_ancho, area_mapa.end.x - mitad_ancho)
		d.y = _dentro(d.y, area_mapa.position.y + mitad_alto, area_mapa.end.y - mitad_alto)
	return d


func _dentro(v, minimo, maximo):
	if minimo > maximo:                      # el mapa es más chico que la vista
		return (minimo + maximo) / 2.0
	return clampf(v, minimo, maximo)


# Salta de golpe a donde está el personaje (para puertas y reinicios).
func centrar():
	if lateral:
		global_position = _destino()
