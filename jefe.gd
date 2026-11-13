extends Node
 
enum Accion { ATACAR, CARGAR, DEFENDER, GOLPE_FUERTE, CURARSE }
 
@export var ritmo: float = 1.0
@export var danio: int = 7
@export var cuantos_turnos: int = 8
@export var patron: Array[int] = [0, 0, 1, 2]
@export var vida: int = 80
@export var vida_baja: int = 20
@export var curas: int = 1
@export var cura: int = 15
# De cada 100 turnos normales, cuántos va a cada acción.
@export var pesos: Array[int] = [60, 25, 15]
@export var semilla: int = 7
@export var factor_acelera: float = 0.75
 
var indice: int = 0
var turno_numero: int = 0
var reloj: float = 0.0
var cargado: bool = false
var ultima_accion: int = 0
 
var rng := RandomNumberGenerator.new()
var veces: Array[int] = [0, 0, 0]
 
 
func _ready() -> void:
	rng.seed = semilla
	reloj = ritmo
	_preparar_animaciones()
 
 
func _physics_process(delta: float) -> void:
	# Prueba: Enter = el jugador falló. Borrar estas dos líneas antes del commit.
	if Input.is_action_just_pressed("ui_accept"):
		jugador_fallo()
 
	if muerto:
		return
 
	if turno_numero >= cuantos_turnos:
		return
 
	reloj -= delta
 
	if reloj <= 0.001:
		reloj = ritmo
		jugar_turno()
 
	if turno_numero == cuantos_turnos:
		print("veces: ", veces)
 
 
func jugar_turno() -> void:
	turno_numero += 1
 
	var accion = decidir()
	ultima_accion = accion
	_animar(accion)
 
	print("turno ", turno_numero, ": ", Accion.keys()[accion], " (vida ", vida, ")")
 
	match accion:
		Accion.ATACAR:
			print("    ataca: ", danio, " de daño")
 
		Accion.CARGAR:
			cargado = true
			print("    carga fuerzas")
 
		Accion.DEFENDER:
			print("    se defiende")
 
		Accion.GOLPE_FUERTE:
			cargado = false
			print("    golpe fuerte: ", danio * 2, " de daño")
 
		Accion.CURARSE:
			curas -= 1
			vida += cura
			print("    se cura: vida ", vida)
 
 
func decidir() -> int:
	if cargado:
		return Accion.GOLPE_FUERTE
 
	if vida <= vida_baja and curas > 0:
		return Accion.CURARSE
 
	var a = elegir_por_peso()
	veces[a] += 1
	return a
 
 
# Saca un número de 1 a la suma de los pesos y ve en qué tramo cayó.
func elegir_por_peso() -> int:
	var total := 0
 
	for p in pesos:
		total += p
 
	var sale := rng.randi_range(1, total)
	var acumulado := 0
 
	for i in range(pesos.size()):
		acumulado += pesos[i]
 
		if sale <= acumulado:
			return i
 
	return 0
 
 
# Cuando el jugador falla la pregunta, el enemigo se acelera.
func jugador_fallo() -> void:
	ritmo *= factor_acelera
	print("    falló: el turno ahora dura ", snappedf(ritmo, 0.01), " s")
 
	# Ruge solo si no esta en medio de una accion importante.
	if anim != null and not muerto and (not anim.is_playing() or anim.current_animation == "idle"):
		_reproducir("furia", false)
 
 
func recibir_golpe(cuanto: int) -> void:
	vida -= cuanto
	print("    el enemigo recibe ", cuanto, ": vida ", vida)
 
	if vida <= 0:
		_morir()
	elif anim != null and not (anim.current_animation in ANIM_PROTEGIDAS):
		_reproducir("golpe_recibido", false)
 
 
# Animaciones que un golpe recibido no interrumpe.
const ANIM_PROTEGIDAS := ["cargar", "cargado_idle", "golpe_fuerte", "muerte"]
var muerto: bool = false
 
 
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
 
 
func _al_terminar_animacion(nombre: StringName) -> void:
	if muerto or anim.is_playing():   # ya empezo otra (el siguiente turno)
		return
	if nombre == &"cargar" or nombre == &"cargado_idle":
		_reproducir("cargado_idle" if cargado else "idle", false)
	else:
		_reproducir("idle", false)
 
 
func _morir() -> void:
	muerto = true
	print("    el enemigo muere")
	_reproducir("muerte", false)
