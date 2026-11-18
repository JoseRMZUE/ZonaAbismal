extends Node
# Taller 10 · Tarea A · Barreto Ramírez José David
# Receta P (la partida): JUGANDO / GANO / PERDIO, metas, pausa y reinicio.
# Nuestro juego (documento de concepto): partida de 15-20 min, sin game
# over; el tiempo límite de 1200 s es solo el techo.
#
# Sesión 5 (plan de trabajo): este mismo nodo ahora también
#   - guarda el checkpoint y, al llegar la vida a 0, hace REAPARECER al
#     jugador ahí (vidas en 3, fervor en 0) en vez de recargar la escena;
#   - lleva los puntos y la CENIZA: la muerte deja los puntos en el lugar
#     exacto; si se muere otra vez sin recogerlos, se pierden para siempre;
#   - avisa cuando se cumplen las metas (los dos guardianes caídos) y la
#     victoria llega solo al vencer al jefe (la dispara flujo_zona.gd).

signal metas_cumplidas
signal puntos_cambiaron
signal jugador_cayo(hay_ceniza)
signal jugador_revivio
signal ceniza_recuperada(cantidad)
signal ceniza_perdida
signal zona_terminada

enum Estado { JUGANDO, GANO, PERDIO }

@export var tiempo_limite = 30.0
# false: al acabarse el tiempo se pierde. true: sobrevivir gana.
@export var gana_con_tiempo = false
# Cuántas metas hay que cumplir. 0 = no se cuentan.
@export var metas = 3
# true: cumplir las metas gana la partida (Taller 10). false: solo se avisa
# con la señal metas_cumplidas y la victoria la dispara otro (el jefe).
@export var gana_con_metas = true
# true: al ganar se congela el juego (Taller 10). false: se puede seguir
# caminando (hasta el bosque) mientras se muestra la victoria.
@export var pausa_al_ganar = true
# true: tras ganar NO se reinicia solo; espera a que el jugador pulse ENTER.
@export var reinicio_manual = false
@export var espera_reinicio = 2.0

# Sesión 5: muerte, checkpoint y ceniza
@export var espera_revivir = 1.6        # segundos de "has caído" antes de reaparecer
@export var invulnerable_al_revivir = 2.0
@export var puntos_acolito = 10         # lo usa meta_al_morir.gd
@export var puntos_parry = 5
@export var puntos_coleccionable = 20
@export var puntos_jefe = 100
# perder la ceniza tantas veces = la peor puntuación posible (concepto, regla 6)
@export var perdidas_para_peor = 2

# static: es del script, no del nodo. Sobrevive a recargar la escena.
static var intentos = 1
static var mejor = 0.0

var estado = Estado.JUGANDO
var tiempo = 0.0
var hechas = 0
var reloj = 0.0

var punto = Vector3.ZERO          # dónde reaparece (el último checkpoint)
var hay_checkpoint = false
var puntos = 0                    # lo que lleva el jugador ahora mismo
var puntos_totales = 0            # todo lo ganado en la partida (para el reporte)
var muertes = 0
var cenizas_perdidas = 0
var ceniza_actual = null          # el montículo que espera en el mapa (o null)
var cayendo = false               # entre "se le acabó la vida" y "reaparece"
var fin_zona = false
var tiempo_ganado = 0.0
var vida_maxima = 3
var enemigos = []                 # {nodo, pos, vida, ritmo}

var jugador = null
var salud = null
var parry = null


func _ready():
	# Always: este nodo sigue vivo aunque el juego quede en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("partida")
	tiempo = tiempo_limite
	print("intento ", intentos, " · mejor tiempo ", snappedf(mejor, 0.01))
	call_deferred("_preparar")


func _preparar():
	jugador = get_tree().get_first_node_in_group("jugador")
	if jugador == null:
		return
	salud = jugador.get_node_or_null("Salud")
	parry = jugador.get_node_or_null("Parry")
	punto = jugador.global_position       # sin checkpoint, reaparece donde empezó
	if salud != null and "vida" in salud:
		vida_maxima = salud.vida


func _physics_process(delta):
	if estado != Estado.JUGANDO:
		if estado == Estado.GANO and reinicio_manual:
			return
		reloj -= delta
		if reloj <= 0.001:
			reiniciar()
		return
	tiempo = maxf(tiempo - delta, 0.0)
	if tiempo <= 0.001:
		if gana_con_tiempo:
			ganar()
		else:
			perder("se acabó el tiempo")
		return
	_vigilar_muerte()


# ---------------------------------------------------------------------------
# Metas, victoria y derrota (Taller 10)
# ---------------------------------------------------------------------------

# La llaman los objetivos del juego: no saben qué pasa después.
func avisar_meta(valor = 0):
	if estado != Estado.JUGANDO:
		return
	if valor > 0:
		sumar_puntos(valor, "enemigo caído")
	hechas += 1
	print("meta ", hechas, " de ", metas)
	if metas > 0 and hechas == metas:
		metas_cumplidas.emit()
		if gana_con_metas:
			ganar()


func ganar():
	terminar(Estado.GANO, "ganó")


func perder(motivo):
	terminar(Estado.PERDIO, motivo)


# La guarda: la partida termina una sola vez.
func terminar(nuevo, motivo):
	if estado != Estado.JUGANDO:
		return
	estado = nuevo
	print("fin: ", Estado.keys()[estado], " cuadro ",
		Engine.get_physics_frames(), " (", motivo, ")")
	tiempo_ganado = tiempo_limite - tiempo
	# Al ganar se puede dejar el juego corriendo (pausa_al_ganar = false).
	if nuevo != Estado.GANO or pausa_al_ganar:
		get_tree().paused = true
	reloj = espera_reinicio
	if estado == Estado.GANO and (mejor == 0.0 or tiempo_ganado < mejor):
		mejor = tiempo_ganado


func reiniciar():
	intentos += 1
	# Primero quitar la pausa: si no, la escena nueva nace congelada.
	get_tree().paused = false
	get_tree().reload_current_scene()


# El jugador cruzó la puerta del bosque: la zona se termina.
func terminar_zona():
	if fin_zona or estado != Estado.GANO:
		return
	fin_zona = true
	print("zona terminada · puntos ", puntaje_final(), " · muertes ", muertes)
	zona_terminada.emit()


# ---------------------------------------------------------------------------
# Puntos y ceniza (documento de concepto, Tramo 3)
# ---------------------------------------------------------------------------

func sumar_puntos(cantidad, motivo = ""):
	if estado != Estado.JUGANDO and estado != Estado.GANO:
		return
	puntos += cantidad
	puntos_totales += cantidad
	print("+", cantidad, " puntos (", motivo, ") · llevas ", puntos)
	puntos_cambiaron.emit()


# 0 si la ceniza se perdió las veces que dice el concepto: la peor puntuación.
func puntaje_final():
	if cenizas_perdidas >= perdidas_para_peor:
		return 0
	return puntos


func es_la_peor():
	return cenizas_perdidas >= perdidas_para_peor


# La llama ceniza.gd cuando el jugador mantiene E sobre el montículo.
func recuperar_ceniza(nodo, cantidad):
	if nodo == ceniza_actual:
		ceniza_actual = null
	puntos += cantidad
	print("ceniza recuperada: +", cantidad, " · llevas ", puntos)
	ceniza_recuperada.emit(cantidad)
	puntos_cambiaron.emit()


# ---------------------------------------------------------------------------
# Morir y reaparecer en el checkpoint
# ---------------------------------------------------------------------------

func guardar_checkpoint(donde):
	punto = donde
	hay_checkpoint = true
	print("checkpoint guardado en ", donde.snappedf(0.01))


func _vigilar_muerte():
	if cayendo or salud == null or not is_instance_valid(salud):
		return
	if salud.vida <= 0:
		_morir()


func _morir():
	cayendo = true
	muertes += 1
	var lugar = jugador.global_position
	print("el jugador cayó en ", lugar.snappedf(0.01), " (muerte ", muertes, ")")
	# 1. La ceniza que seguía esperando se pierde para siempre.
	var perdio = false
	if ceniza_actual != null and is_instance_valid(ceniza_actual):
		ceniza_actual.desvanecer()
		cenizas_perdidas += 1
		perdio = true
		print("ceniza perdida para siempre (", cenizas_perdidas, ")")
	ceniza_actual = null
	# 2. Lo que llevaba se queda en el lugar exacto de la muerte.
	var hay = false
	if puntos > 0:
		ceniza_actual = _crear_ceniza(lugar, puntos)
		hay = true
		puntos = 0
		puntos_cambiaron.emit()
	jugador_cayo.emit(hay)
	if perdio:
		ceniza_perdida.emit()
	# 3. El jugador queda quieto mientras se ve "has caído".
	jugador.process_mode = Node.PROCESS_MODE_DISABLED
	jugador.velocity = Vector3.ZERO
	await get_tree().create_timer(espera_revivir, true, true).timeout
	_revivir()


func _crear_ceniza(lugar, cantidad):
	var nodo = Node3D.new()
	nodo.set_script(load("res://ceniza.gd"))
	nodo.cantidad = cantidad
	nodo.es_rastro = false
	get_parent().add_child(nodo)
	nodo.global_position = lugar
	return nodo


func _revivir():
	if estado != Estado.JUGANDO or jugador == null:
		cayendo = false
		return
	jugador.process_mode = Node.PROCESS_MODE_INHERIT
	jugador.global_position = punto
	jugador.velocity = Vector3.ZERO
	# Qué se restaura (concepto): vidas en 3 y fervor en 0 %.
	salud.vida = vida_maxima
	salud.reloj = invulnerable_al_revivir
	if parry != null and "fervor" in parry:
		parry.fervor = 0
	_recomponer_enemigos()
	var cam = get_viewport().get_camera_3d()
	if cam != null and cam.has_method("centrar"):
		cam.centrar()
	cayendo = false
	print("reaparece en ", punto.snappedf(0.01), " con ", vida_maxima, " vidas")
	jugador_revivio.emit()


# ---------------------------------------------------------------------------
# Los enemigos vivos se recomponen al reaparecer el jugador
# ---------------------------------------------------------------------------

func registrar_enemigo(nodo):
	for d in enemigos:
		if d.nodo == nodo:
			return
	var d = {"nodo": nodo, "pos": nodo.global_position, "vida": 0, "ritmo": 0.0}
	if "vida" in nodo:
		d.vida = nodo.vida
	if "ritmo" in nodo:
		d.ritmo = nodo.ritmo
	enemigos.append(d)


func _recomponer_enemigos():
	for d in enemigos:
		var n = d.nodo
		# Los caídos no vuelven: así las puertas ya abiertas siguen abiertas.
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		if "muerto" in n and n.muerto:
			continue
		n.global_position = d.pos
		if "velocity" in n:
			n.velocity = Vector3.ZERO
		if "vida" in n:
			n.vida = d.vida
		# El jefe lleva cuenta de su combate: se vuelve a empezar.
		for campo in ["aturdido", "cargado", "en_fase_final"]:
			if campo in n:
				n.set(campo, false)
		if "golpes_pendientes" in n:
			n.golpes_pendientes = 0
		if "ritmo" in n:
			n.ritmo = d.ritmo
		if "reloj" in n and "ritmo" in n:
			n.reloj = n.ritmo
		if n.has_method("_reproducir"):
			n._reproducir("idle", false)
