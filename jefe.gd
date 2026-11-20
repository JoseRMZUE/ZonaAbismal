extends CharacterBody3D

signal impacto(accion: String, cantidad: int)   # en el instante del golpe: conectala al dano del jugador
signal fase_final_iniciada
signal jefe_vencido
 
enum Accion { ATACAR, CARGAR, DEFENDER, GOLPE_FUERTE, CURARSE }
 

@export var ritmo: float = 1.15              
@export var danio: int = 1                   
@export var cuantos_turnos: int = 0          
@export var vida: int = 10
@export var vida_baja: int = 5               
@export var curas: int = 0                   
@export var cura: int = 0
@export var aturdimiento: float = 1.5        
@export var golpes_por_parry: int = 1        
# conexion con el jugador (Personaje > Parry / Salud)
@export var alcance_ataque: float = 2.0      
@export var margen_parry: float = 0.15       
@export var patron: Array[int] = [0, 0, 1, 0, 0, 2]
@export var pesos: Array[int] = [40, 40, 20]               
@export var pesos_fase_final: Array[int] = [30, 45, 25]    
@export var semilla: int = 0                 
@export var factor_acelera: float = 0.90
@export var mirar_al_jugador: bool = true
@export var liberar_al_morir: bool = true    
@export var espera_liberar: float = 4.0
@export var modo_prueba: bool = false        
@export_group("Comportamiento en sala")
@export var radio_activacion: float = 16.0
@export var velocidad_persecucion: float = 3.5 # velocidad de carrera a larga distancia
@export var velocidad_caminar: float = 1.45
@export var distancia_correr: float = 4.0
@export var duracion_persecucion: float = 0.45
@export var distancia_frenado: float = 1.0
@export var aceleracion_movimiento: float = 5.5
@export var distancia_perseguir: float = 2.0
 

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
var jugador_en_sala: bool = false
var persecucion_restante: float = 0.0
var ataques_seguidos: int = 0
var persiguiendo: bool = false
var jugador_en_rango_anterior: bool = false
 
# animaciones
const ANIM_POR_ACCION := {0: "atacar", 1: "cargar", 2: "defender", 3: "golpe_fuerte", 4: "curarse"}
const ANIM_PROTEGIDAS := ["cargar", "cargado_idle", "golpe_fuerte", "muerte"]
const IMPACTOS := {"atacar": 0.43, "golpe_fuerte": 1.05}
const CLIPS_CREATURE := {
	"idle": "mutant breathing idle.fbx",
	"cargado_idle": "mutant flexing muscles.fbx",
	"walk": "mutant walking.fbx",
	"run": "mutant run.fbx",
	"atacar": "mutant punch.fbx",
	"cargar": "mutant roaring.fbx",
	"defender": "mutant flexing muscles.fbx",
	"golpe_fuerte": "mutant jump attack.fbx",
	"curarse": "mutant idle (2).fbx",
	"furia": "mutant roaring.fbx",
	"golpe_recibido": "mutant jumping.fbx",
	"muerte": "mutant dying.fbx"
}
var modelo: Node3D
var anim: AnimationPlayer
var _anim_prev: String = ""
var _pos_prev: float = 0.0
var _salto_activo: bool = false
var _clip_salto_fuente: Animation
var _track_raiz_salto: int = -1
var _posicion_raiz_salto_previa: Vector3 = Vector3.ZERO
 

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

	# El root motion del salto desplaza el cuerpo con colisiones. Se pausa
	# el movimiento normal mientras dura el clip para evitar sumar velocidades.
	if _salto_activo:
		_actualizar_salto_animado()
		return

	if aturdido:
		velocity.x = move_toward(velocity.x, 0.0, aceleracion_movimiento * delta)
		velocity.z = move_toward(velocity.z, 0.0, aceleracion_movimiento * delta)
		move_and_slide()
		aturdido_restante -= delta
		if aturdido_restante <= 0.001:
			_terminar_aturdimiento()
		return

	var jugador := get_tree().get_first_node_in_group("jugador") as Node3D
	var esta_en_sala := (
		jugador != null
		and global_position.distance_to(jugador.global_position) <= radio_activacion
		and _hay_linea_de_vision(jugador)
	)
	if esta_en_sala and not jugador_en_sala:
		jugador_en_sala = true
		reloj = ritmo
		print("El jefe detecta al jugador: comienza el combate")
	elif not esta_en_sala:
		if jugador_en_sala:
			print("El jugador salió de la sala: el jefe se calma")
		jugador_en_sala = false
		jugador_en_rango_anterior = false
		persecucion_restante = 0.0
		velocity.x = move_toward(velocity.x, 0.0, aceleracion_movimiento * delta)
		velocity.z = move_toward(velocity.z, 0.0, aceleracion_movimiento * delta)
		move_and_slide()
		return

	var distancia_al_jugador := Vector2(
		jugador.global_position.x - global_position.x,
		jugador.global_position.z - global_position.z
	).length()

	var dentro_del_alcance := distancia_al_jugador <= alcance_ataque
	if not dentro_del_alcance:
		jugador_en_rango_anterior = false
	elif not jugador_en_rango_anterior:
		jugador_en_rango_anterior = true
		persiguiendo = false
		persecucion_restante = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		reloj = ritmo
		jugar_turno()
		return

	var distancia_objetivo := minf(distancia_perseguir, alcance_ataque)
	if distancia_al_jugador > distancia_objetivo:
		persiguiendo = true
		persecucion_restante = 0.0
		reloj = ritmo
		_perseguir_jugador(jugador, delta)
		return

	if persiguiendo:
		persiguiendo = false
		reloj = ritmo

	if persecucion_restante > 0.0:
		persecucion_restante -= delta
		_perseguir_jugador(jugador, delta)
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
	if accion == Accion.ATACAR or accion == Accion.GOLPE_FUERTE:
		ataques_seguidos += 1
		# Encadena ataques; cada tercer ataque hace una breve embestida de persecución.
		if ataques_seguidos % 3 == 0:
			persecucion_restante = duracion_persecucion
	else:
		ataques_seguidos = 0
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
	ritmo = maxf(ritmo * factor_acelera, 0.95)
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


func _perseguir_jugador(jugador: Node3D, delta: float) -> void:
	if jugador == null or muerto or aturdido:
		return

	_mirar_al_jugador()
	var direccion := jugador.global_position - global_position
	direccion.y = 0.0
	var distancia := direccion.length()
	var corre := distancia >= distancia_correr
	var velocidad_objetivo := velocidad_persecucion if corre else velocidad_caminar
	var objetivo := Vector3.ZERO

	if distancia > distancia_frenado and distancia > 0.01:
		objetivo = direccion.normalized() * velocidad_objetivo

	velocity.x = move_toward(velocity.x, objetivo.x, aceleracion_movimiento * delta)
	velocity.z = move_toward(velocity.z, objetivo.z, aceleracion_movimiento * delta)
	move_and_slide()

	if anim != null:
		var animacion_movimiento := "run" if corre else "walk"
		if not anim.is_playing() or String(anim.current_animation) != animacion_movimiento:
			_reproducir(animacion_movimiento, false)

func _morir() -> void:
	if muerto:
		return
	muerto = true
	aturdido = false
	print("    el jefe es vencido")
	_reproducir("muerte", false)
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null and partida.has_method("dejar_ceniza_enemigo"):
		# Recompensa especial: puntos extra y hasta dos vidas al absorberla.
		partida.dejar_ceniza_enemigo(global_position, partida.puntos_jefe, 2)
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
	_cargar_animaciones_creaturepack()
	for nombre in ["idle", "cargado_idle", "walk", "run"]:
		if anim.has_animation(nombre):
			anim.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	if not anim.animation_finished.is_connected(_al_terminar_animacion):
		anim.animation_finished.connect(_al_terminar_animacion)
	anim.speed_scale = 1.0
	_reproducir("idle", false)


func _cargar_animaciones_creaturepack() -> void:
	# Todos los FBX comparten el rig Mixamo de Mutant.fbx. Se eliminan sus
	# traslaciones horizontales para que no separen el modelo de la cápsula.
	var biblioteca := anim.get_animation_library("")
	if biblioteca == null:
		biblioteca = AnimationLibrary.new()
		var error := anim.add_animation_library("", biblioteca)
		if error != OK:
			push_warning("Jefe: no se pudo crear la biblioteca de animación (%s)." % error_string(error))
			return

	for nombre in CLIPS_CREATURE:
		var ruta := "res://Jefe/CreaturePack/" + String(CLIPS_CREATURE[nombre])
		var escena := load(ruta) as PackedScene
		if escena == null:
			push_warning("Jefe: no se pudo cargar el clip %s." % ruta)
			continue

		var fuente := escena.instantiate()
		var players := fuente.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty() or not players[0].has_animation("mixamo_com"):
			push_warning("Jefe: el clip %s no contiene mixamo_com." % ruta)
			fuente.free()
			continue

		var clip: Animation = players[0].get_animation("mixamo_com").duplicate(true)
		clip.resource_name = String(nombre)
		var indice_raiz := _buscar_track_posicion_raiz(clip)

		if indice_raiz >= 0:
			if nombre == "golpe_fuerte":
				# El original conserva el desplazamiento frontal para mover
				# físicamente al jefe durante el ataque en salto.
				_clip_salto_fuente = clip.duplicate(true)
				_track_raiz_salto = indice_raiz
			_neutralizar_avance_horizontal(clip, indice_raiz)

		if biblioteca.has_animation(nombre):
			biblioteca.remove_animation(nombre)
		var error := biblioteca.add_animation(nombre, clip)
		if error != OK:
			push_warning("Jefe: no se pudo registrar '%s' (%s)." % [nombre, error_string(error)])
		fuente.free()


func _buscar_track_posicion_raiz(clip: Animation) -> int:
	for i in range(clip.get_track_count()):
		var ruta := String(clip.track_get_path(i))
		if "mixamorig_Hips" in ruta and clip.track_get_type(i) == Animation.TYPE_POSITION_3D:
			return i
	return -1


func _neutralizar_avance_horizontal(clip: Animation, indice_raiz: int) -> void:
	if indice_raiz < 0 or clip.track_get_key_count(indice_raiz) == 0:
		return
	var posicion_inicial: Vector3 = clip.track_get_key_value(indice_raiz, 0)
	for i in range(clip.track_get_key_count(indice_raiz)):
		var posicion: Vector3 = clip.track_get_key_value(indice_raiz, i)
		posicion.x = posicion_inicial.x
		posicion.z = posicion_inicial.z
		clip.track_set_key_value(indice_raiz, i, posicion)


func _iniciar_salto_animado() -> void:
	if _clip_salto_fuente == null or _track_raiz_salto < 0:
		_salto_activo = false
		return
	_posicion_raiz_salto_previa = _clip_salto_fuente.position_track_interpolate(_track_raiz_salto, 0.0)
	velocity.x = 0.0
	velocity.z = 0.0
	_salto_activo = true


func _actualizar_salto_animado() -> void:
	if anim == null or _clip_salto_fuente == null or String(anim.current_animation) != "golpe_fuerte":
		_salto_activo = false
		return

	var tiempo_clip := clampf(anim.current_animation_position, 0.0, _clip_salto_fuente.length)
	var posicion_raiz: Vector3 = _clip_salto_fuente.position_track_interpolate(_track_raiz_salto, tiempo_clip)
	var avance_local := posicion_raiz - _posicion_raiz_salto_previa
	_posicion_raiz_salto_previa = posicion_raiz

	# El esqueleto ya no avanza por separado: el cuerpo sigue el desplazamiento
	# de la animación hacia delante mediante colisión y queda en el punto final.
	avance_local.y = 0.0
	var avance_mundo := modelo.global_transform.basis * avance_local
	avance_mundo.y = 0.0
	if avance_mundo.length_squared() > 0.000001:
		move_and_collide(avance_mundo)

	if not anim.is_playing() or tiempo_clip >= _clip_salto_fuente.length - 0.001:
		_salto_activo = false
		velocity.x = 0.0
		velocity.z = 0.0

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
	if accion == Accion.GOLPE_FUERTE:
		_iniciar_salto_animado()
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
	if jugador == null or muerto or aturdido or not _hay_linea_de_vision(jugador):
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


func _hay_linea_de_vision(jugador: Node3D) -> bool:
	var desde := global_position + Vector3(0, 0.9, 0)
	var hasta := jugador.global_position + Vector3(0, 0.9, 0)
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	consulta.collision_mask = 0xFFFFFFFF
	consulta.exclude = [get_rid()]
	var impacto = get_world_3d().direct_space_state.intersect_ray(consulta)
	if impacto.is_empty():
		return true
	var collider = impacto.get("collider") as Node
	return collider == jugador or (collider != null and collider.is_in_group("jugador"))
 

func _mirar_al_jugador() -> void:
	if not mirar_al_jugador or modelo == null:
		return
	var jugador := get_tree().get_first_node_in_group("jugador") as Node3D
	if jugador == null:
		return
	var dir: Vector3 = jugador.global_position - global_position
	dir.y = 0.0
	if dir.length() > 0.1:
		var objetivo := atan2(dir.x, dir.z)
		modelo.global_rotation.y = lerp_angle(modelo.global_rotation.y, objetivo, 0.18)
