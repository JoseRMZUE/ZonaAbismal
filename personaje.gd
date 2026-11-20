extends CharacterBody3D


enum Estado { QUIETO, CAMINAR, AIRE }
const RUIDO = [0.0, 2.0, 0.0]
@export var camara: Camera3D
@export var speed = 4.5
@export var gravedad = 30.0
@export var altura_salto = 3.3
@export var tiempo_arranque = 0.15

# ---- Animación (Mixamo) ----------------------------------------------------
# A cuántos m/s "camina" el clip caminar y a cuántos "corre" el clip correr
# (con esos números los pies no patinan). El clip se acelera o frena un poco
# para acompañar la rapidez real.
@export var paso_animacion = 1.4
@export var paso_carrera = 4.0
# Desde qué rapidez objetivo (m/s) se usa correr en vez de caminar.
@export var umbral_correr = 3.0
# Segundos de fundido entre dos animaciones (lo que quita los saltos bruscos).
@export var mezcla = 0.2
# Qué tan rápido gira el modelo al cambiar de lado (rad/s). El Personaje sigue
# girando de golpe porque Apuntar dispara el rayo con esa dirección.
@export var giro_visual = 18.0
# Segundos entre que se aprieta el botón y el momento del golpe en la animación.
@export var adelanto_golpe = 0.17
# Cuándo se puede encadenar el siguiente golpe (igual a la cadencia de Apuntar).
@export var cadencia_combo = 0.30
# Cuánto tiempo, después de un golpe, se puede seguir el combo.
@export var ventana_combo = 0.35
# Cuánto dura en pantalla la animación de "golpeado".
@export var dura_golpeado = 0.5
# Cuánto dura "has caído" para que alcance a verse la animación de morir.
@export var espera_muerte = 3.2
@onready var anim = $Modelo/idle/AnimationPlayer
@onready var modelo = $Modelo

# Enchufes: otros scripts (las acciones del juego) cambian estas tres variables.
var multiplicador = 1.0     # 1 = rapidez normal, 0.5 = la mitad, 0 = quieto
var empuje = Vector3.ZERO   # velocidad extra en m/s (dash, retroceso)
var accion = ""             # animación de la acción; "" = ninguna
var avance = 0.0
var estado = Estado.QUIETO
var ruido = 0.0
var reloj_ataque = 0.0

# Los golpes del combo 1-2-3: "impacto" = segundo del clip en que la espada
# pega. El clip arranca "adelanto_golpe" segundos antes de ese instante.
const GOLPES = [
	{"clip": "ataque_1", "impacto": 0.83, "dura": 0.55},
	{"clip": "ataque_2", "impacto": 0.87, "dura": 0.55},
	{"clip": "combo", "impacto": 3.00, "dura": 0.65},
]
# El golpe especial que sale justo después de un parry exitoso.
const CONTRAGOLPE = {"clip": "ataque_parry", "impacto": 0.60, "dura": 0.75}
# Si falta un clip nuevo en la biblioteca, se usa el viejo.
const RESPALDO = {"caminar": "walk", "correr": "walk", "saltar": "jump", "caer": "fall",
	"guardia": "idle", "aterrizar": "idle", "golpeado": "idle", "morir": "idle",
	"parry_bloqueo": "interact-right", "parry_impacto": "interact-right",
	"ataque_1": "attack-melee-right", "ataque_2": "attack-melee-right",
	"combo": "attack-melee-right", "ataque_parry": "attack-melee-right"}

var actual = ""             # clip que se está reproduciendo
var cadena = 0              # cuál golpe del combo toca (0, 1 o 2)
var t_golpe = 99.0          # segundos desde que empezó el último golpe
var dura_golpe = 0.55
var buffer_ataque = 0.0     # el botón se recuerda un instante (no se pierde)
var t_golpeado = 0.0
var t_aterrizaje = 0.0
var vida_antes = -1
var fase_parry = ""         # "", "bloqueo", "impacto", "guardia"
var t_fase = 0.0
var tras_parry_antes = false
var parry_antes = 0
var en_piso_antes = true
var modo_aire = ""          # "", "saltar" o "caer"
var tiempo_aire = 0.0
var salto_pedido = false
var muerto = false
var giro = 0.0              # lo que le falta girar al modelo (rad)
var rot_antes = 0.0
var salud = null
var parry = null
var apuntar = null


func _ready():
	# Escaleras del escenario pintado: los escalones cortos cuentan como piso
	# (hasta 75°) y al bajar no lo despegan del suelo. Los muros de verdad
	# (casi 90°) siguen siendo muros.
	floor_max_angle = deg_to_rad(75.0)
	floor_snap_length = 0.35
	rot_antes = rotation.y
	call_deferred("_conectar")


# Busca a los compañeros (Salud, Parry, Apuntar, Partida) sin tocar sus archivos:
# solo lee sus variables públicas.
func _conectar():
	salud = get_node_or_null("Salud")
	parry = get_node_or_null("Parry")
	apuntar = get_node_or_null("Apuntar")
	if salud != null and "vida" in salud:
		vida_antes = salud.vida
	var partida = get_tree().get_first_node_in_group("partida")
	if partida != null:
		partida.jugador_cayo.connect(_al_caer)
		partida.jugador_revivio.connect(_al_revivir)
		# "Has caído" dura lo suficiente para ver caer al personaje.
		if "espera_revivir" in partida:
			partida.espera_revivir = maxf(partida.espera_revivir, espera_muerte)


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravedad * delta
	elif Input.is_action_just_pressed("saltar"):
		velocity.y = sqrt(2 * gravedad * altura_salto)
		salto_pedido = true

	var lado = Input.get_axis("move_left", "move_right")
	var paso = speed / tiempo_arranque * delta
	avance = move_toward(avance, lado * speed * multiplicador, paso)
	velocity.x = avance + empuje.x

	if lado != 0:
		rotation.y = -PI / 2 * sign(lado)   # mira hacia +X o hacia -X

	move_and_slide()
	var antes = estado
	estado = elegir_estado()
	ruido = RUIDO[estado]
	if estado != antes:
		print("estado ", Estado.keys()[estado], " · ruido ", ruido, " m")
	animar(delta, lado)
	_prueba()


func elegir_estado():
	if not is_on_floor():
		return Estado.AIRE
	var rapidez = absf(velocity.x)
	if rapidez < 0.1:
		return Estado.QUIETO
	return Estado.CAMINAR


# ---------------------------------------------------------------------------
# ANIMACIÓN. Orden de prioridad: golpeado > golpe (combo) > parry > aire >
# aterrizaje > correr / caminar > guardia > idle.
# ---------------------------------------------------------------------------

func animar(delta, lado):
	if muerto:
		return
	_girar_modelo(delta)
	t_golpe += delta
	t_fase += delta
	buffer_ataque = maxf(buffer_ataque - delta, 0.0)
	t_golpeado = maxf(t_golpeado - delta, 0.0)
	t_aterrizaje = maxf(t_aterrizaje - delta, 0.0)
	var en_piso = is_on_floor()
	_leer_vecinos()

	# 1. Recibir daño (sin matar: si muere, lo anima la señal jugador_cayo).
	if salud != null and "vida" in salud:
		if salud.vida < vida_antes and salud.vida > 0:
			t_golpeado = dura_golpeado
			cadena = 0
			t_golpe = 99.0
			fase_parry = ""
			t_aterrizaje = 0.0
			_poner("golpeado", 0.05, 1.4)
		vida_antes = salud.vida
	if t_golpeado > 0.0:
		_cerrar_vuelo(en_piso)
		return

	# 2. Parry: bloqueo al apretar, impacto al desviar, guardia mientras dura
	#    el contragolpe.
	if parry != null and "estado" in parry:
		if parry.estado == 1 and parry_antes != 1:     # ACTIVA
			fase_parry = "bloqueo"
			t_fase = 0.0
			t_golpe = 99.0
			cadena = 0
			_poner("parry_bloqueo", 0.05, 1.0)
		parry_antes = parry.estado
	var tras_parry = apuntar != null and "tras_parry" in apuntar and apuntar.tras_parry
	if tras_parry and not tras_parry_antes:
		fase_parry = "impacto"
		t_fase = 0.0
		_poner("parry_impacto", 0.04, 1.0)
	tras_parry_antes = tras_parry
	if fase_parry == "impacto" and t_fase >= 0.7:
		fase_parry = "guardia"
	if fase_parry == "guardia" and not tras_parry:
		fase_parry = ""
	if fase_parry == "bloqueo" and parry != null and parry.estado == 0 and t_fase >= 0.57:
		fase_parry = ""
	# Caminar de verdad cancela la pose de parry (el contragolpe sigue vivo).
	if fase_parry != "" and absf(avance) > 1.0:
		fase_parry = ""

	# 3. Ataque: combo de tres golpes, o el contragolpe tras un parry.
	# Si se aprieta un instante antes de que se pueda encadenar, se recuerda
	# (buffer); si se aprieta mucho antes, se ignora (no se acumulan golpes).
	if Input.is_action_just_pressed("disparar") and t_golpe >= cadencia_combo - 0.15:
		buffer_ataque = 0.15
	var quiere = buffer_ataque > 0.0 or Input.is_action_pressed("disparar")
	if quiere and t_golpe >= cadencia_combo:
		_golpear(tras_parry)
	if t_golpe < dura_golpe:
		_cerrar_vuelo(en_piso)
		return
	if t_golpe > dura_golpe + ventana_combo:
		cadena = 0

	# 4. Parry (pose quieta).
	if fase_parry == "bloqueo":
		_cerrar_vuelo(en_piso)
		return
	if fase_parry == "impacto":
		_cerrar_vuelo(en_piso)
		return

	# 5. En el aire.
	if not en_piso:
		tiempo_aire += delta
		if modo_aire == "":
			if salto_pedido:
				modo_aire = "saltar"
				_poner("saltar", 0.1, 1.0)
			elif tiempo_aire > 0.12:        # caminó fuera de un borde
				modo_aire = "caer"
				_poner("caer", 0.25, 1.0)
		elif modo_aire == "saltar" and not anim.is_playing():
			modo_aire = "caer"              # el salto terminó y todavía no toca piso
			_poner("caer", 0.15, 1.0)
		en_piso_antes = false
		return

	# 6. Acaba de tocar el piso.
	if not en_piso_antes:
		if modo_aire == "caer" and tiempo_aire > 0.3 and absf(lado) < 0.1:
			t_aterrizaje = 0.55
			_poner("aterrizar", 0.12, 1.4, 0.22)
		modo_aire = ""
		tiempo_aire = 0.0
		salto_pedido = false
		en_piso_antes = true
	if t_aterrizaje > 0.0 and absf(lado) < 0.1:
		return

	# 7. En el suelo.
	if absf(avance) > 0.1:
		var objetivo = absf(lado) * speed * multiplicador
		var corre = objetivo >= umbral_correr or (actual == "correr" and lado == 0.0)
		var paso_clip = paso_carrera if corre else paso_animacion
		var escala = clampf(absf(avance) / paso_clip, 0.5, 1.4)
		_poner("correr" if corre else "caminar", mezcla, escala)
	elif fase_parry == "guardia":
		_poner("guardia", 0.15, 1.0)
	else:
		_poner("idle", mezcla, 1.0)


# Si se golpea o se hace un parry en el aire, no se queda marcado el vuelo.
func _cerrar_vuelo(en_piso):
	if en_piso and not en_piso_antes:
		modo_aire = ""
		tiempo_aire = 0.0
		salto_pedido = false
	en_piso_antes = en_piso


func _golpear(contragolpe):
	var g = CONTRAGOLPE if contragolpe else GOLPES[cadena]
	var desde = maxf(g.impacto - adelanto_golpe, 0.0)
	_poner(g.clip, 0.10, 1.0, desde, true)
	t_golpe = 0.0
	dura_golpe = g.dura
	buffer_ataque = 0.0
	fase_parry = ""
	t_aterrizaje = 0.0
	if contragolpe:
		cadena = 1          # tras el contragolpe el combo sigue con el segundo
	else:
		cadena = (cadena + 1) % GOLPES.size()


# Reproduce un clip con fundido. Si ya es el que suena, solo ajusta la velocidad.
func _poner(nombre, fundido = 0.2, escala = 1.0, desde = 0.0, reiniciar = false):
	var clip = nombre
	if not anim.has_animation("personaje/" + clip):
		clip = RESPALDO.get(nombre, "idle")
	anim.speed_scale = escala
	if actual == nombre and anim.is_playing() and not reiniciar:
		return
	actual = nombre
	anim.play("personaje/" + clip, fundido)
	if desde > 0.0:
		anim.seek(desde, true)


# El Personaje gira de golpe (Apuntar lo necesita), pero el modelo gira suave.
func _girar_modelo(delta):
	var d = wrapf(rotation.y - rot_antes, -PI, PI)
	rot_antes = rotation.y
	if absf(d) > 0.001:
		giro = wrapf(giro - d, -PI, PI)
	giro = move_toward(giro, 0.0, giro_visual * delta)
	modelo.rotation.y = PI + giro


func _leer_vecinos():
	if salud == null:
		salud = get_node_or_null("Salud")
	if parry == null:
		parry = get_node_or_null("Parry")
	if apuntar == null:
		apuntar = get_node_or_null("Apuntar")


# Partida avisa que el jugador cayó: se anima morir mientras está congelado.
func _al_caer(_hay_ceniza):
	muerto = true
	fase_parry = ""
	cadena = 0
	t_golpe = 99.0
	t_golpeado = 0.0
	t_aterrizaje = 0.0
	anim.process_mode = Node.PROCESS_MODE_ALWAYS    # sigue animando aunque el nodo se congele
	actual = ""
	_poner("morir", 0.1, 1.7)


func _al_revivir():
	muerto = false
	anim.process_mode = Node.PROCESS_MODE_INHERIT
	actual = ""
	modo_aire = ""
	tiempo_aire = 0.0
	salto_pedido = false
	en_piso_antes = true
	giro = 0.0
	rot_antes = rotation.y
	modelo.rotation.y = PI
	if salud != null and "vida" in salud:
		vida_antes = salud.vida
	anim.speed_scale = 1.0
	_poner("idle", 0.0, 1.0)


# ---------------------------------------------------------------------------
# PRUEBAS AUTOMÁTICAS. No hace falta entender esta parte: en el Inspector del
# Personaje elijan "Prueba" (y, si la prueba usa una acción, escriban su nombre
# en "Accion Prueba"). Con F5 el personaje se mueve solo y escribe los números
# en el panel Output. La última línea de _physics_process() es _prueba().
# ---------------------------------------------------------------------------
@export_enum("Ninguna", "Avanzar 60 cuadros", "Avanzar 60 y soltar", "Avanzar y la acción desde el cuadro 30", "Mantener la acción 2 s", "Avanzar con la acción 60 cuadros", "Diagonal W+D 60 cuadros") var prueba = 0
@export var accion_prueba = ""
var _cuadro = 0
var _termino = false
var _y_max = 0.0
var _cuadro_max = 0


func _prueba():
	if prueba == 0 or _termino:
		return
	_cuadro += 1
	var avanzar = "move_right"
	var lado = "move_up"
	if _cuadro == 1:
		if prueba <= 3 or prueba == 5:
			_apretar(avanzar)
		if prueba == 4 or prueba == 5:
			_apretar(accion_prueba)
		if prueba == 6:
			_apretar(avanzar)
			_apretar(lado)
		return
	var n = _cuadro - 1
	if prueba == 3 and n == 30:
		_apretar(accion_prueba)
	if prueba == 2 and n == 60:
		Input.action_release(avanzar)
	var marcas = []
	if prueba == 1 or prueba == 5:
		marcas = [1, 2, 3, 5, 10, 15, 20, 30, 60]
	elif prueba == 2:
		marcas = [59, 60, 61, 62, 63, 65, 70, 80, 90]
	elif prueba == 3:
		marcas = [29, 30, 31, 32, 33, 35, 40, 45, 50, 60, 75, 90]
	elif prueba == 6:
		marcas = [1, 30, 60]
	else:
		marcas = [1, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150]
	if n in marcas:
		print("[prueba] cuadro ", n, ": ", _resumen())
	_cambios(n)
	if global_position.y > _y_max + 0.0001:
		_y_max = global_position.y
		_cuadro_max = n
	if n == marcas[-1]:
		Input.action_release(avanzar)
		Input.action_release(lado)
		_soltar(accion_prueba)
		_termino = true
		if _y_max > 0.01:
			print("[prueba] altura máxima ", snappedf(_y_max, 0.01), " en el cuadro ", _cuadro_max)


func _resumen():
	var t = "posición " + str(global_position.snappedf(0.01))
	t += " · rapidez " + str(snappedf(absf(velocity.x), 0.01))
	t += " · y " + str(snappedf(global_position.y, 0.01))
	t += " · animación " + str(anim.current_animation)
	for nodo in _con_estado():
		t += " · " + str(nodo.name) + ".estado " + _nombre(nodo)
	return t


# Escribe el cuadro exacto en el que cambia cualquier variable "estado".
var _antes = {}


func _cambios(n):
	for nodo in _con_estado():
		var e = _nombre(nodo)
		if _antes.has(nodo) and _antes[nodo] != e:
			print("[prueba] cuadro ", n, ": ", nodo.name, ".estado cambia a ", e)
		_antes[nodo] = e


func _con_estado():
	var lista = []
	for nodo in [self] + get_children() + get_tree().get_nodes_in_group("probar"):
		if nodo.get_script() != null and "estado" in nodo:
			lista.append(nodo)
	return lista


func _nombre(nodo):
	var nombres = nodo.get_script().get_script_constant_map().get("Estado", {})
	for k in nombres:
		if nombres[k] == nodo.estado:
			return k
	return str(nodo.estado)


func _apretar(a):
	if a == "":
		print("[prueba] escriban el nombre de la acción en 'Accion Prueba'")
	elif not InputMap.has_action(a):
		print("[prueba] falta la acción '", a, "' en el Input Map")
	else:
		Input.action_press(a)


func _soltar(a):
	if a != "" and InputMap.has_action(a):
		Input.action_release(a)
