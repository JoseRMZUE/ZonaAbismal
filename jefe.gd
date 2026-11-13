extends CharacterBody3D

signal impacto(accion: String, cantidad: int)   # en el instante del golpe: conectala al dano del jugador
signal fase_final_iniciada
signal jefe_vencido
 
enum Accion { ATACAR, CARGAR, DEFENDER, GOLPE_FUERTE, CURARSE }
 

@export var ritmo: float = 1.5               
@export var danio: int = 1                   
@export var cuantos_turnos: int = 0          
@export var vida: int = 10
@export var vida_baja: int = 5               
@export var curas: int = 0                   
@export var cura: int = 0
@export var aturdimiento: float = 1.5        
@export var golpes_por_parry: int = 1        
# conexion con el jugador (Personaje > Parry / Salud)
@export var alcance_ataque: float = 3.0      
@export var margen_parry: float = 0.15       
@export var patron: Array[int] = [0, 1, 2]   
@export var pesos: Array[int] = [40, 40, 20]               
@export var pesos_fase_final: Array[int] = [30, 45, 25]    
@export var semilla: int = 0                 
@export var factor_acelera: float = 0.75
@export var mirar_al_jugador: bool = true
@export var liberar_al_morir: bool = true    
@export var espera_liberar: float = 4.0
@export var modo_prueba: bool = false        
 

var indice: int = 0
var turno_numero: int = 0
var reloj: float = 0.0
var cargado: bool = false
var ultima_accion: int = 0
var aturdido: bool = false
var aturdido_restante: float = 0.0
var golpes_pendientes: int = 0
var en_fase_final: bool = false
var muerto: bool = false
var _fin_impreso: bool = false
 
var rng := RandomNumberGenerator.new()
var veces: Array[int] = [0, 0, 0]
 
# animaciones
const ANIM_POR_ACCION := {0: "atacar", 1: "cargar", 2: "defender", 3: "golpe_fuerte", 4: "curarse"}
const ANIM_PROTEGIDAS := ["cargar", "cargado_idle", "golpe_fuerte", "muerte"]
const IMPACTOS := {"atacar": 0.40, "golpe_fuerte": 0.68}   
var modelo: Node3D
var anim: AnimationPlayer
var _anim_prev: String = ""
var _pos_prev: float = 0.0
 
 
func _ready() -> void:
	if semilla == 0:
		rng.randomize()
	else:
		rng.seed = semilla
	reloj = ritmo
	_preparar_animaciones()
 
 
func _physics_process(delta: float) -> void:
	_vigilar_impacto()
 
	if modo_prueba:
		_prueba()
 
	if muerto:
		return
 
	if aturdido:
		aturdido_restante -= delta
		if aturdido_restante <= 0.001:
			_terminar_aturdimiento()
		return
 
	if cuantos_turnos > 0 and turno_numero >= cuantos_turnos:
		if not _fin_impreso:
			_fin_impreso = true
			print("veces: ", veces)
		return
 
	reloj -= delta
 
	if reloj <= 0.001:
		reloj = ritmo
		jugar_turno()
 
 
func _prueba() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		jugador_fallo()
	if Input.is_action_just_pressed("ui_up"):
		aturdir()
	if Input.is_action_just_pressed("ui_down"):
		recibir_golpe(danio)
 
 
func jugar_turno() -> void:
	turno_numero += 1
 
	var accion: int = decidir()
	ultima_accion = accion
	_mirar_al_jugador()
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
 

	if indice < patron.size():
		var a: int = patron[indice]
		indice += 1
		return a
 
	var elegida := elegir_por_peso()
	veces[elegida] += 1
	return elegida
 
 
func _pesos_actuales() -> Array[int]:
	return pesos_fase_final if vida <= vida_baja else pesos
 
 
func elegir_por_peso() -> int:
	var activos := _pesos_actuales()
	var total := 0
 
	for p in activos:
		total += p
 
	var sale := rng.randi_range(1, total)
	var acumulado := 0
 
	for i in range(activos.size()):
		acumulado += activos[i]
 
		if sale <= acumulado:
			return i
 
	return 0
 
 
func jugador_fallo() -> void:
	ritmo *= factor_acelera
	print("    falló: el turno ahora dura ", snappedf(ritmo, 0.01), " s")
 
	if anim != null and not muerto and not aturdido and (not anim.is_playing() or anim.current_animation == "idle"):
		_reproducir("furia", false)
 
 
func aturdir() -> void:
	if muerto:
		return
	aturdido = true
	aturdido_restante = aturdimiento
	golpes_pendientes = golpes_por_parry
	_mirar_al_jugador()
	print("    PARRY: el jefe queda aturdido ", aturdimiento, " s")
	_reproducir("golpe_recibido", false)
 
 
func recibir_golpe(cuanto: int) -> void:
	if muerto:
		return
 
	if not aturdido or golpes_pendientes <= 0:
		print("    el jefe bloquea: solo recibe daño tras un parry")
		return
 
	var total := cuanto * 2 if golpes_pendientes == golpes_por_parry else cuanto
	golpes_pendientes -= 1
	vida = maxi(vida - total, 0)
 
	print("    el enemigo recibe ", total, ": vida ", vida)
 
	if vida <= 0:
		_morir()
		return
 
	if vida <= vida_baja and not en_fase_final:
		en_fase_final = true
		print("    FASE FINAL: pesos ", pesos_fase_final)
		fase_final_iniciada.emit()
 
	_reproducir("golpe_recibido", false)
 
 
func _terminar_aturdimiento() -> void:
	aturdido = false
	golpes_pendientes = 0
	reloj = ritmo
	print("    el jefe se recupera")
	_reproducir("cargado_idle" if cargado else "idle", false)
 
 
func _morir() -> void:
	if muerto:
		return
	muerto = true
	aturdido = false
	print("    el jefe es vencido")
	_reproducir("muerte", false)
	jefe_vencido.emit()
 
	if liberar_al_morir:
		await get_tree().create_timer(espera_liberar).timeout
		queue_free()
 
 
func _preparar_animaciones() -> void:
	modelo = get_node_or_null("Modelo") as Node3D
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
 
 
func _reproducir(nombre: String, ajustar: bool = true) -> void:
	if anim == null or not anim.has_animation(nombre):
		return
	if ajustar:
		anim.speed_scale = clampf(anim.get_animation(nombre).length / ritmo, 0.5, 4.0)
	elif nombre == "idle" or nombre == "cargado_idle":
		anim.speed_scale = clampf(1.0 / ritmo, 0.8, 2.5)
	else:
		anim.speed_scale = 1.0
	anim.play(nombre, 0.12)
 
 
func _animar(accion: int) -> void:
	_reproducir(ANIM_POR_ACCION.get(accion, "idle"))
 
 
func _al_terminar_animacion(nombre: StringName) -> void:
	if muerto or anim.is_playing():   
		return
	if aturdido:                      
		anim.speed_scale = 0.4
		anim.play("idle", 0.12)
		return
	if nombre == &"cargar" or nombre == &"cargado_idle":
		_reproducir("cargado_idle" if cargado else "idle", false)
	else:
		_reproducir("idle", false)
 
 
# Emite `impacto` cuando la animacion de ataque llega al momento del golpe.
func _vigilar_impacto() -> void:
	if anim == null or not anim.is_playing():
		_anim_prev = ""
		return
	var nombre := String(anim.current_animation)
	var pos := anim.current_animation_position
	if nombre == _anim_prev and IMPACTOS.has(nombre):
		var t: float = IMPACTOS[nombre]
		if _pos_prev < t and pos >= t:
			var cantidad := danio if nombre == "atacar" else danio * 2
			impacto.emit(nombre, cantidad)
			_resolver_impacto(nombre, cantidad)
	_anim_prev = nombre
	_pos_prev = pos
 
 
func _resolver_impacto(accion: String, cantidad: int) -> void:
	var jugador := get_tree().get_first_node_in_group("jugador") as Node3D
	if jugador == null or muerto or aturdido:
		return
 
	var dif: Vector3 = jugador.global_position - global_position
	if Vector2(dif.x, dif.z).length() > alcance_ataque or absf(dif.y) > 2.5:
		print("    el golpe no alcanza al jugador")
		return
 
	if _parry_activo(jugador):
		print("    ¡parry! desvia el ", accion)
		aturdir()
		return
 
	var salud = jugador.get_node_or_null("Salud")
	if salud != null and salud.has_method("recibir_golpe"):
		salud.recibir_golpe(cantidad)
 
 
func _parry_activo(jugador: Node) -> bool:
	var parry = jugador.get_node_or_null("Parry")
	if parry == null:
		return false
	if int(parry.estado) == 1:
		return true
	if int(parry.estado) == 2:
		var desde_que_termino: float = float(parry.recarga) - float(parry.tiempo)
		return desde_que_termino <= margen_parry
	return false
 
 
func _mirar_al_jugador() -> void:
	if not mirar_al_jugador or modelo == null:
		return
	var jugador := get_tree().get_first_node_in_group("jugador") as Node3D
	if jugador == null:
		return
	var dir: Vector3 = jugador.global_position - global_position
	dir.y = 0.0
	if dir.length() > 0.1:
		modelo.global_rotation.y = atan2(dir.x, dir.z)
