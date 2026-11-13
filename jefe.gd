extends Node
 
enum Accion { ATACAR, CARGAR, DEFENDER }
 
@export var ritmo: float = 1.0
@export var danio: int = 7
@export var cuantos_turnos: int = 8
# El patrón: se recorre con un índice, como la patrulla.
@export var patron: Array[int] = [0, 0, 1, 2]
 
var indice: int = 0
var turno_numero: int = 0
var ultima_accion: int = 0
var reloj: float = 0.0
 
 
func _ready() -> void:
	reloj = ritmo
	_preparar_animaciones()
 
 
func _physics_process(delta: float) -> void:
	if turno_numero >= cuantos_turnos:
		return
 
	reloj -= delta
 
	if reloj <= 0.001:
		reloj = ritmo
		jugar_turno()
 
 
func jugar_turno() -> void:
	turno_numero += 1
 
	var accion = patron[indice]
	indice = (indice + 1) % patron.size()
	ultima_accion = accion
	_animar(accion)
 
	print("turno ", turno_numero, ": ", Accion.keys()[accion])
 
	match accion:
		Accion.ATACAR:
			print("    ataca: ", danio, " de daño")
 
		Accion.CARGAR:
			print("    carga fuerzas")
 
		Accion.DEFENDER:
			print("    se defiende")
 
 
# ======================================================================================
# ANIMACIONES (extra, no son parte del taller): usa el AnimationPlayer del nodo "Modelo"
# ======================================================================================
const ANIM_POR_ACCION := {0: "atacar", 1: "cargar", 2: "defender", 3: "golpe_fuerte", 4: "curarse"}
var anim: AnimationPlayer
 
 
func _preparar_animaciones() -> void:
	var modelo = get_node_or_null("Modelo")
	if modelo == null:
		push_warning("Jefe: no encuentro el nodo 'Modelo' (hijo de este nodo).")
		return
	var players := modelo.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("Jefe: 'Modelo' no tiene AnimationPlayer.")
		return
	anim = players[0]
	for nombre in ["idle", "cargado_idle"]:
		if anim.has_animation(nombre):
			anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	anim.animation_finished.connect(_al_terminar_animacion)
	anim.speed_scale = 1.0
	anim.play("idle")
 
 
## Reproduce la animacion. Si ajustar es true, dura exactamente un turno (ritmo).
func _reproducir(nombre: String, ajustar: bool = true) -> void:
	if anim == null or not anim.has_animation(nombre):
		return
	if ajustar:
		anim.speed_scale = clampf(anim.get_animation(nombre).length / ritmo, 0.5, 4.0)
	else:
		anim.speed_scale = 1.0
	anim.play(nombre, 0.12)
 
 
func _animar(accion: int) -> void:
	_reproducir(ANIM_POR_ACCION.get(accion, "idle"))
 
 
func _al_terminar_animacion(_nombre: StringName) -> void:
	if anim.is_playing():   # ya empezo otra (el siguiente turno)
		return
	_reproducir("idle", false)
