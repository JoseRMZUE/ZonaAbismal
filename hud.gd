extends CanvasLayer

const HUESO = Color("#E8E1D3")
const HUESO_SOMBRA = Color("#8E8078")
const FONDO = Color("#1B1F2B")
const NEGRO = Color("#120E18")
const ORO = Color("#D4A017")
const ORO_CLARO = Color("#F2D27A")
const ROJO = [Color("#E0856A"), Color("#B8453F"), Color("#B8453F"), Color("#7E2B35"), Color("#7E2B35")]
const VIOLETA = [Color("#B7A6F0"), Color("#7C68B8"), Color("#5B4B8A"), Color("#443669"), Color("#443669")]
const PISTA_ROJA = Color("#2A1018")
const PISTA_VIOLETA = Color("#1F1830")

# Letras y números de 3x5 puntos (pixel art, como los de la imagen).
const FUENTE = {
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
	"3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
	"6": "111100111101111", "7": "111001010010010", "8": "111101111101111",
	"9": "111101111001111", "/": "001001010100100", "-": "000000111000000",
	"A": "010101111101101", "C": "011100100100011", "D": "110101101101110",
	"E": "111100110100111", "F": "111100110100100", "I": "111010010010111",
	"L": "100100100100111", "N": "101111111101101", "O": "010101101101010",
	"R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
	"V": "101101101101010", "Z": "111001010100111", "!": "010010010000010",
	" ": "000000000000000",
}

var lienzo = null
var partida = null
var jugador = null
var salud = null
var parry = null
var interactuar = null

var p = 3                       # tamaño de un "punto" de pixel art en pantalla
var t = 0.0
var mensaje_texto = ""
var mensaje_t = 0.0
var mensaje_total = 1.0
var objetivo = ""
var objetivo_flash = 0.0
var vida_mostrada = 3.0
var fervor_mostrado = 0.0
var fade = 0.0
var fade_objetivo = 0.0
var cayo_con_ceniza = false
var estaba_ganado = false
var victoria_t = 0.0
var fin_visible = false
var fin_t = 0.0
# Pantalla de inicio (controles + ENTER). Solo sale la primera vez que se abre el juego.
var inicio_visible = false
var inicio_t = 0.0
# Avisos de parry (una vez por partida abierta): 1 = al primer golpe recibido,
# 2 = al primer parry que sale bien.
var aviso_tipo = 0   # 3 = al cruzar la puerta al salón del Jefe
var aviso_t = 0.0
var vida_previa = -1
# Pausa (P o Esc): los mismos controles del inicio, para repasarlos.
var pausa_visible = false
var pausa_t = 0.0
# Puertas que el HUD señala con una flecha cuando se abren.
var puertas = []            # [{nodo, cruzada, abierta_t}]
var doble_previo = false


func _ready():
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	lienzo = Control.new()
	lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.draw.connect(_dibujar)
	add_child(lienzo)
	call_deferred("_conectar")


func _conectar():
	partida = get_tree().get_first_node_in_group("partida")
	jugador = get_tree().get_first_node_in_group("jugador")
	if jugador != null:
		salud = jugador.get_node_or_null("Salud")
		parry = jugador.get_node_or_null("Parry")
		interactuar = jugador.get_node_or_null("Interactuar")
	if salud != null:
		vida_mostrada = float(salud.vida)
	if partida != null:
		partida.jugador_cayo.connect(_al_caer)
		partida.jugador_revivio.connect(_al_revivir)
		partida.ceniza_recuperada.connect(_ceniza_recuperada)
		partida.ceniza_perdida.connect(_ceniza_perdida)
		partida.zona_terminada.connect(_zona_terminada)
		_conectar_puertas()
		_abrir_inicio()


# ---------------------------------------------------------------------------
# Lo que le pueden pedir los demás
# ---------------------------------------------------------------------------

func mensaje(texto, segundos = 3.0):
	mensaje_texto = texto
	mensaje_t = segundos
	mensaje_total = maxf(segundos, 0.1)


func poner_objetivo(texto):
	if texto == objetivo:
		return
	objetivo = texto
	objetivo_flash = 1.5


func _al_caer(hay_ceniza):
	cayo_con_ceniza = hay_ceniza
	# Deja ver la animación de morir antes de oscurecer la pantalla.
	await get_tree().create_timer(1.9, true, true).timeout
	if partida.cayendo:
		fade_objetivo = 1.0


func _al_revivir():
	fade_objetivo = 0.0
	mensaje("Has vuelto al checkpoint", 2.5)


func _ceniza_recuperada(vida_recuperada, puntos_recibidos):
	var texto = "Ceniza: +" + str(puntos_recibidos) + " puntos"
	if vida_recuperada > 0:
		texto += " · +" + str(vida_recuperada) + " vida"
	elif salud != null and partida != null and salud.vida >= partida.vida_maxima:
		texto += " · vida completa"
	mensaje(texto, 3.0)


func _ceniza_perdida():
	mensaje("Tu ceniza se perdió para siempre", 4.0)


func _zona_terminada():
	fin_visible = true
	fin_t = 0.0


# Los avisos de parry salen solos, una sola vez cada uno:
#  - la primera vez que el jugador recibe un golpe (enseña qué hacer),
#  - la primera vez que un parry sale bien (enseña qué ganó).
func _vigilar_avisos_parry():
	if salud == null or not is_instance_valid(salud) or inicio_visible or fin_visible or pausa_visible:
		return
	var vida = int(salud.vida)
	if vida_previa < 0:
		vida_previa = vida
	var golpeado = vida < vida_previa and partida != null and not partida.cayendo
	vida_previa = vida
	var apuntar = null
	if jugador != null and is_instance_valid(jugador):
		apuntar = jugador.get_node_or_null("Apuntar")
	var doble = apuntar != null and "tras_parry" in apuntar and apuntar.tras_parry
	var salio_bien = doble and not doble_previo
	doble_previo = doble
	if salio_bien and not Engine.has_meta("zona_aviso_parry_ok"):
		Engine.set_meta("zona_aviso_parry_ok", true)
		Engine.set_meta("zona_aviso_parry_golpe", true)   # ya lo entendió: no hace falta el otro
		aviso_tipo = 2
		aviso_t = 6.0
	elif golpeado and not Engine.has_meta("zona_aviso_parry_golpe") and vida > 0:
		Engine.set_meta("zona_aviso_parry_golpe", true)
		aviso_tipo = 1
		aviso_t = 7.0


# El HUD señala las puertas que se abren (flecha dorada) hasta que se cruzan.
# El aviso grande del Jefe sale una sola vez al cruzar la puerta al salón.
func _conectar_puertas():
	var main = get_parent()
	if main == null:
		return
	for ruta in ["Puertas/PuertaAlSalon", "Puertas/PuertaAlBosque"]:
		var nodo = main.get_node_or_null(ruta)
		if nodo == null or not ("abierta" in nodo):
			continue
		var d = {"nodo": nodo, "cruzada": false, "abierta_t": 0.0}
		puertas.append(d)
		nodo.cruzada.connect(_puerta_cruzada.bind(d, ruta))


func _puerta_cruzada(d, ruta):
	d.cruzada = true
	if ruta.ends_with("PuertaAlSalon") and not Engine.has_meta("zona_aviso_salon"):
		Engine.set_meta("zona_aviso_salon", true)
		aviso_tipo = 3
		aviso_t = 8.0


# P o Esc: pausa con los controles a la vista.
func _alternar_pausa():
	if pausa_visible:
		pausa_visible = false
		get_tree().paused = false
		# Igual que en el inicio: lo que se gastó mirando no cuenta en el tiempo.
		if partida != null:
			partida.tiempo = minf(partida.tiempo + pausa_t, partida.tiempo_limite)
		return
	if inicio_visible or fin_visible or partida == null or get_tree().paused:
		return
	if partida.estado == partida.Estado.PERDIO or partida.cayendo:
		return
	pausa_visible = true
	pausa_t = 0.0
	get_tree().paused = true


# La pantalla de inicio pausa el juego hasta que el jugador aprieta ENTER.
# Se guarda una marca en Engine para que no vuelva a salir al reiniciar la escena.
func _abrir_inicio():
	if Engine.has_meta("zona_inicio_visto"):
		return
	inicio_visible = true
	inicio_t = 0.0
	get_tree().paused = true


func _cerrar_inicio():
	inicio_visible = false
	Engine.set_meta("zona_inicio_visto", true)
	get_tree().paused = false
	# La Partida cuenta el tiempo aunque el juego esté en pausa: se le devuelve
	# lo que se gastó leyendo, para que no cuente en el tiempo de la zona.
	if partida != null:
		partida.tiempo = minf(partida.tiempo + inicio_t, partida.tiempo_limite)


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		var k = event.keycode
		if k == KEY_P or k == KEY_ESCAPE or (pausa_visible and (k == KEY_ENTER or k == KEY_KP_ENTER)):
			if pausa_visible and pausa_t < 0.2:
				return
			_alternar_pausa()
			get_viewport().set_input_as_handled()
			return
	if pausa_visible:
		return
	if inicio_visible and inicio_t > 0.3 and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_cerrar_inicio()
			get_viewport().set_input_as_handled()
		return
	# ENTER (no la barra espaciadora, que es el salto) vuelve a empezar.
	if fin_visible and fin_t > 1.0 and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if partida != null:
				partida.reiniciar()


func _process(delta):
	t += delta
	mensaje_t = maxf(mensaje_t - delta, 0.0)
	objetivo_flash = maxf(objetivo_flash - delta, 0.0)
	victoria_t = maxf(victoria_t - delta, 0.0)
	fade = move_toward(fade, fade_objetivo, delta * 2.2)
	if fin_visible:
		fin_t += delta
	if inicio_visible:
		inicio_t += delta
	aviso_t = maxf(aviso_t - delta, 0.0)
	if pausa_visible:
		pausa_t += delta
	for d in puertas:
		if is_instance_valid(d.nodo) and d.nodo.abierta and not d.cruzada:
			d.abierta_t += delta
	_vigilar_avisos_parry()
	if salud != null and is_instance_valid(salud):
		vida_mostrada = move_toward(vida_mostrada, float(salud.vida), delta * 6.0)
	if parry != null and is_instance_valid(parry):
		fervor_mostrado = move_toward(fervor_mostrado, float(parry.fervor), delta * 80.0)
	if partida != null:
		var gano = partida.estado == partida.Estado.GANO
		if gano and not estaba_ganado:
			victoria_t = 6.0
		estaba_ganado = gano
	p = maxi(2, int(round(get_viewport().get_visible_rect().size.y / 216.0)))
	lienzo.queue_redraw()


# ---------------------------------------------------------------------------
# Dibujo
# ---------------------------------------------------------------------------

func _r(x, y, w, h, color):
	lienzo.draw_rect(Rect2(x * p, y * p, w * p, h * p), color)


func _texto_px(s, x, y, color):
	# devuelve el ancho dibujado en puntos
	var cx = x
	for ch in s:
		var patron = FUENTE.get(ch, FUENTE[" "])
		for i in range(15):
			if patron[i] == "1":
				_r(cx + (i % 3), y + floori(i / 3.0), 1, 1, color)
		cx += 4
	return cx - x


func _ancho_px(s):
	return s.length() * 4 - 1


# Hexágono con las puntas a los lados, como el marco de la imagen.
func _hexagono(x, y, w, h, color):
	var mitad = (h - 1) / 2.0
	for r in range(h):
		var ins = int(absf(r - mitad))
		_r(x + ins, y + r, w - 2 * ins, 1, color)


func _barra(x, y, w, h, fraccion, colores, pista, segmentos, texto, etiqueta, brillo_borde):
	# marco: hueso, con la fila de abajo en sombra para dar volumen
	_hexagono(x, y, w, h, HUESO)
	_r(x + floori(h / 2.0), y + h - 1, w - 2 * floori(h / 2.0), 1, HUESO_SOMBRA)
	if brillo_borde > 0.0:
		var c = HUESO.lerp(colores[0], brillo_borde)
		_hexagono(x, y, w, h, c)
	_hexagono(x + 1, y + 1, w - 2, h - 2, NEGRO)
	# pista y relleno
	var ix = x + floori(h / 2.0) + 1
	var iw = w - 2 * (floori(h / 2.0) + 1)
	var iy = y + 3
	var filas = h - 6
	_r(ix, iy, iw, filas, pista)
	var lleno = int(round(iw * clampf(fraccion, 0.0, 1.0)))
	for f in range(filas):
		_r(ix, iy + f, lleno, 1, colores[mini(f, colores.size() - 1)])
	# rayitas de luz sobre la primera fila, como en la imagen
	var k = 5
	while k < lleno - 2:
		_r(ix + k, iy, 2, 1, HUESO.lerp(colores[0], 0.35))
		k += 9
	# una marca por cada segmento (cada vida)
	if segmentos > 1:
		for s in range(1, segmentos):
			_r(ix + int(iw * s / float(segmentos)), iy, 1, filas, NEGRO)
	# placa con el número y la etiqueta
	var py = y + h
	for r in range(8):
		_r(x + 8, py + r, 46 - r, 1, FONDO)
	_r(x + 8, py + 7, 39, 1, HUESO_SOMBRA)
	var ancho = _texto_px(texto, x + 11, py + 1, HUESO)
	_texto_px(etiqueta, x + 11 + ancho + 4, py + 1, HUESO_SOMBRA)
	# alas y orbe a la izquierda
	_alas(x, y, h)


func _alas(x, y, h):
	var cx = x + 1.0
	var cy = y + h / 2.0
	var plumas = [[-1.0, -1.7, 7], [-1.5, -1.0, 8], [-2.0, -0.35, 8], [-2.0, 0.35, 8], [-1.7, 1.0, 7], [-1.2, 1.6, 6]]
	for pl in plumas:
		for s in range(pl[2]):
			var px = int(round(cx + pl[0] * s * 0.7))
			var py = int(round(cy + pl[1] * s * 0.7))
			_r(px, py, 1, 1, HUESO if s < pl[2] - 2 else HUESO_SOMBRA)
	# orbe oscuro con aro de hueso, abajo a la izquierda del marco
	var ox = x + 4
	var oy = y + h + 3
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var d = sqrt(dx * dx + dy * dy)
			if d <= 4.3:
				_r(ox + dx, oy + dy, 1, 1, HUESO if d >= 3.1 else NEGRO)


func _dibujar():
	if partida == null:
		return
	var vp = get_viewport().get_visible_rect().size
	var wu = int(vp.x / p)
	var fuente = ThemeDB.fallback_font

	# --- vida y fervor (arriba a la izquierda) -------------------------------
	var vida = 0
	var vida_max = 3
	if salud != null and is_instance_valid(salud):
		vida = int(salud.vida)
		vida_max = maxi(int(partida.vida_maxima), 1)
	var pulso_vida = 0.0
	if vida == 1:
		pulso_vida = 0.5 + 0.5 * sin(t * 8.0)
	_barra(12, 8, 80, 11, vida_mostrada / float(vida_max), ROJO, PISTA_ROJA, vida_max,
		str(vida) + "/" + str(vida_max), "VIDA", pulso_vida * 0.6)
	var fervor = 0
	if parry != null and is_instance_valid(parry):
		fervor = int(parry.fervor)
	var lleno = fervor >= 100
	var pulso = 0.0
	if lleno:
		pulso = 0.5 + 0.5 * sin(t * 7.0)
	_barra(12, 31, 66, 9, fervor_mostrado / 100.0, VIOLETA, PISTA_VIOLETA, 1,
		str(fervor) + "/100", "LISTA" if lleno else "FERVOR", pulso)

	# --- ceniza (arriba a la derecha) ---------------------------------------
	var puntos = int(partida.puntos)
	var texto_c = str(puntos)
	var wc = 14 + _ancho_px("CENIZA") + 4 + _ancho_px(texto_c) + 6
	var cx = wu - wc - 10
	_r(cx, 8, wc, 12, HUESO)
	_r(cx + 1, 9, wc - 2, 10, FONDO)
	_r(cx + 1, 18, wc - 2, 1, NEGRO)
	# montículo dorado
	_r(cx + 4, 15, 7, 2, ORO)
	_r(cx + 5, 13, 5, 2, ORO)
	_r(cx + 6, 12, 3, 1, ORO_CLARO)
	_texto_px("CENIZA", cx + 14, 11, HUESO_SOMBRA)
	_texto_px(texto_c, cx + 14 + _ancho_px("CENIZA") + 4, 11, ORO_CLARO)
	if partida.es_la_peor():
		_texto_px("PEOR", cx + 4, 22, Color("#D63A3A"))

	# --- flecha hacia la ceniza caída ---------------------------------------
	_flecha_ceniza(vp)

	# --- objetivo (arriba al centro) ----------------------------------------
	if objetivo != "":
		var a = 0.85 if objetivo_flash <= 0.0 else 1.0
		var col = HUESO if objetivo_flash <= 0.0 else ORO_CLARO
		var tam = 17
		var ancho = fuente.get_string_size(objetivo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var bx = vp.x / 2.0 - ancho / 2.0 - 12
		lienzo.draw_rect(Rect2(bx, 6, ancho + 24, 28), Color(FONDO.r, FONDO.g, FONDO.b, 0.72))
		lienzo.draw_rect(Rect2(bx, 6, ancho + 24, 2), Color(ORO.r, ORO.g, ORO.b, 0.9))
		lienzo.draw_string(fuente, Vector2(bx + 12, 27), objetivo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(col.r, col.g, col.b, a))

	# --- aviso de interacción (mantener E) ----------------------------------
	_aviso_interactuar(vp, fuente)

	# --- mensaje temporal (abajo al centro) ---------------------------------
	if mensaje_t > 0.0:
		var a = clampf(mensaje_t / 0.6, 0.0, 1.0) * clampf((mensaje_total - mensaje_t) / 0.2 + 0.0, 0.0, 1.0)
		var tam = 22
		var ancho = fuente.get_string_size(mensaje_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var bx = vp.x / 2.0 - ancho / 2.0 - 16
		var by = vp.y - 104
		lienzo.draw_rect(Rect2(bx, by, ancho + 32, 38), Color(FONDO.r, FONDO.g, FONDO.b, 0.8 * a))
		lienzo.draw_rect(Rect2(bx, by + 36, ancho + 32, 2), Color(ORO.r, ORO.g, ORO.b, a))
		lienzo.draw_string(fuente, Vector2(bx + 16, by + 26), mensaje_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(HUESO.r, HUESO.g, HUESO.b, a))

	# --- victoria sobre el jefe ---------------------------------------------
	if victoria_t > 0.0 and not fin_visible:
		var a = clampf(victoria_t / 1.0, 0.0, 1.0) * clampf((6.0 - victoria_t) / 0.6, 0.0, 1.0)
		var cy = vp.y * 0.30
		lienzo.draw_rect(Rect2(0, cy - 46, vp.x, 112), Color(NEGRO.r, NEGRO.g, NEGRO.b, 0.72 * a))
		lienzo.draw_rect(Rect2(0, cy - 46, vp.x, 3), Color(ORO.r, ORO.g, ORO.b, a))
		lienzo.draw_rect(Rect2(0, cy + 63, vp.x, 3), Color(ORO.r, ORO.g, ORO.b, a))
		lienzo.draw_string(fuente, Vector2(0, cy + 8), "EL JEFE HA CAÍDO", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 46, Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, a))
		lienzo.draw_string(fuente, Vector2(0, cy + 44), "La luz del templo vuelve a respirar", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, Color(HUESO.r, HUESO.g, HUESO.b, a))

	# --- "has caído" ----------------------------------------------------------
	if fade > 0.001:
		lienzo.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.88 * fade))
		var tc = Color(0.84, 0.23, 0.23, fade)
		lienzo.draw_string(fuente, Vector2(0, vp.y / 2.0), "HAS CAÍDO", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 54, tc)
		if cayo_con_ceniza:
			lienzo.draw_string(fuente, Vector2(0, vp.y / 2.0 + 40), "Tu ceniza queda en el lugar donde caíste", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, Color(HUESO.r, HUESO.g, HUESO.b, fade))

	# --- fin de la zona -----------------------------------------------------
	if fin_visible:
		_pantalla_fin(vp, fuente)

	# --- aviso de parry -----------------------------------------------------
	if aviso_t > 0.0 and not inicio_visible and not fin_visible and not pausa_visible:
		_aviso_parry(vp, fuente)

	# --- flechas hacia las puertas abiertas ---------------------------------
	if not inicio_visible and not fin_visible and not pausa_visible:
		for d in puertas:
			_flecha_puerta(vp, d)

	# --- pausa ----------------------------------------------------------------
	if pausa_visible:
		_pantalla_inicio(vp, fuente, true)

	# --- inicio del juego ---------------------------------------------------
	if inicio_visible:
		_pantalla_inicio(vp, fuente)


func _flecha_ceniza(vp):
	var nodo = partida.ceniza_actual
	if nodo == null or not is_instance_valid(nodo) or nodo.usada:
		return
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var punto = cam.unproject_position(nodo.global_position + Vector3(0, 0.5, 0))
	var margen = 44.0
	var area = Rect2(margen, margen, maxf(vp.x - 2 * margen, 1.0), maxf(vp.y - 2 * margen, 1.0))
	if area.has_point(punto):
		return
	var centro = vp / 2.0
	var dir = (punto - centro).normalized()
	# punto sobre el borde de la zona segura, en la dirección de la ceniza
	var esc = 100000.0
	if absf(dir.x) > 0.001:
		esc = minf(esc, (area.size.x / 2.0) / absf(dir.x))
	if absf(dir.y) > 0.001:
		esc = minf(esc, (area.size.y / 2.0) / absf(dir.y))
	var pos = centro + dir * esc
	var perp = Vector2(-dir.y, dir.x)
	var oro = Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, 0.7 + 0.3 * sin(t * 5.0))
	lienzo.draw_colored_polygon(PackedVector2Array([pos + dir * 16, pos - dir * 8 + perp * 12, pos - dir * 8 - perp * 12]), oro)
	lienzo.draw_circle(pos - dir * 22, 3.0, oro)


func _aviso_interactuar(vp, fuente):
	if interactuar == null or not is_instance_valid(interactuar) or partida.estado == partida.Estado.PERDIO:
		return
	var obj = interactuar.mas_cercano()
	if obj == null or not obj.has_method("usar"):
		return
	var que = "la ceniza"
	var cant = 0
	var vida = 1
	if "cantidad" in obj:
		cant = obj.cantidad
	if "vida_recuperada" in obj:
		vida = obj.vida_recuperada
	if vida > 0:
		que = "la ceniza curativa"
	var texto = "Mantén E: absorber " + que + "  +" + str(cant) + " puntos"
	if vida > 0:
		texto += ", +" + str(vida) + " vida"
	var tam = 20
	var ancho = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var bx = vp.x / 2.0 - ancho / 2.0 - 14
	var by = vp.y - 176
	lienzo.draw_rect(Rect2(bx, by, ancho + 28, 34), Color(FONDO.r, FONDO.g, FONDO.b, 0.85))
	lienzo.draw_string(fuente, Vector2(bx + 14, by + 24), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, HUESO)
	var prog = 0.0
	if interactuar.actual == obj:
		prog = clampf(interactuar.progreso, 0.0, 1.0)
	lienzo.draw_rect(Rect2(bx, by + 34, ancho + 28, 6), PISTA_VIOLETA)
	lienzo.draw_rect(Rect2(bx, by + 34, (ancho + 28) * prog, 6), ORO)


func _tiempo_texto(s):
	var m = floori(s / 60.0)
	var seg = int(s) % 60
	return str(m).pad_zeros(2) + ":" + str(seg).pad_zeros(2)


func _pantalla_fin(vp, fuente):
	var a = clampf(fin_t / 0.8, 0.0, 1.0)
	lienzo.draw_rect(Rect2(Vector2.ZERO, vp), Color(NEGRO.r, NEGRO.g, NEGRO.b, 0.86 * a))
	var cx = vp.x / 2.0
	var y = vp.y * 0.2
	var dorado = Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, a)
	var hueso = Color(HUESO.r, HUESO.g, HUESO.b, a)
	lienzo.draw_string(fuente, Vector2(0, y), "FIN DE LA ZONA ABISMAL", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 46, dorado)
	lienzo.draw_rect(Rect2(cx - 220, y + 14, 440, 3), Color(ORO.r, ORO.g, ORO.b, a))
	lienzo.draw_string(fuente, Vector2(0, y + 52), "El penitente cruzó el templo y llegó al bosque", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, hueso)
	var filas = []
	filas.append(["Tiempo", _tiempo_texto(partida.tiempo_ganado) + "   (mejor " + _tiempo_texto(partida.mejor) + ")"])
	if partida.es_la_peor():
		filas.append(["Puntuación", "PEOR POSIBLE (perdiste la ceniza " + str(partida.cenizas_perdidas) + " veces)"])
	else:
		filas.append(["Puntuación", str(partida.puntaje_final()) + " puntos"])
	filas.append(["Veces que caíste", str(partida.muertes)])
	filas.append(["Ceniza perdida", str(partida.cenizas_perdidas)])
	filas.append(["Intento", str(partida.intentos)])
	var fy = y + 110
	for f in filas:
		lienzo.draw_string(fuente, Vector2(cx - 250, fy), f[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(HUESO_SOMBRA.r, HUESO_SOMBRA.g, HUESO_SOMBRA.b, a))
		lienzo.draw_string(fuente, Vector2(cx + 10, fy), f[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, hueso)
		fy += 36
	if fin_t > 1.0:
		var parpadeo = 0.55 + 0.45 * sin(t * 4.0)
		lienzo.draw_string(fuente, Vector2(0, fy + 40), "ENTER para volver a empezar", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 24, Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, parpadeo))


# Una tecla dibujada como botón: fondo oscuro, borde dorado y base más gruesa.
# Devuelve el ancho que ocupó, para poder poner otra tecla al lado.
func _tecla(fuente, texto, x, y, tam, a, ancho_min = 0.0):
	var ancho = maxf(fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + tam * 1.1, maxf(ancho_min, tam * 2.0))
	var alto = tam * 1.9
	var oro = Color(ORO.r, ORO.g, ORO.b, a)
	lienzo.draw_rect(Rect2(x, y, ancho, alto), Color(FONDO.r, FONDO.g, FONDO.b, a))
	lienzo.draw_rect(Rect2(x, y, ancho, alto), oro, false, 1.5)
	lienzo.draw_rect(Rect2(x, y + alto - 4, ancho, 4), oro)
	lienzo.draw_string(fuente, Vector2(x, y + alto * 0.62), texto, HORIZONTAL_ALIGNMENT_CENTER, ancho, tam, Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, a))
	return ancho


# Tecla de flecha (se dibuja el triángulo: así no depende de la letra del sistema).
func _tecla_flecha(fuente, derecha, x, y, tam, a):
	var ancho = _tecla(fuente, "", x, y, tam, a)
	var alto = tam * 1.9
	var cx = x + ancho / 2.0
	var cy = y + (alto - 4) / 2.0
	var r = tam * 0.45
	var d = 1.0 if derecha else -1.0
	var puntos = PackedVector2Array([Vector2(cx + d * r, cy), Vector2(cx - d * r * 0.7, cy - r), Vector2(cx - d * r * 0.7, cy + r)])
	lienzo.draw_colored_polygon(puntos, Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, a))
	return ancho


func _pantalla_inicio(vp, fuente, pausa = false):
	var tt = pausa_t if pausa else inicio_t
	var a = clampf(tt / 0.5, 0.0, 1.0)
	var e = clampf(vp.y / 648.0, 0.8, 1.6)
	var hueso = Color(HUESO.r, HUESO.g, HUESO.b, a)
	var sombra = Color(HUESO_SOMBRA.r, HUESO_SOMBRA.g, HUESO_SOMBRA.b, a)
	var dorado = Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, a)
	var oro = Color(ORO.r, ORO.g, ORO.b, a)

	# Un velo suave para que el recuadro destaque, sin tapar el juego.
	lienzo.draw_rect(Rect2(Vector2.ZERO, vp), Color(NEGRO.r, NEGRO.g, NEGRO.b, 0.35 * a))

	var w = 540.0 * e
	var h = 400.0 * e
	var x0 = (vp.x - w) / 2.0
	var y0 = (vp.y - h) / 2.0
	lienzo.draw_rect(Rect2(x0, y0, w, h), Color(NEGRO.r, NEGRO.g, NEGRO.b, 0.93 * a))
	lienzo.draw_rect(Rect2(x0, y0, w, h), oro, false, 2.0)

	var cx = vp.x / 2.0
	var y = y0 + 52.0 * e
	lienzo.draw_string(fuente, Vector2(x0, y), "PAUSA" if pausa else "ZONA ABISMAL", HORIZONTAL_ALIGNMENT_CENTER, w, int(34 * e), dorado)
	lienzo.draw_rect(Rect2(cx - 110.0 * e, y + 12.0 * e, 220.0 * e, 3), oro)
	var subtitulo = "Cruza el templo, mata a los enemigos y consigue tu redención."
	if pausa:
		subtitulo = ("Objetivo: " + objetivo) if objetivo != "" else "Juego en pausa"
	lienzo.draw_string(fuente, Vector2(x0, y + 46.0 * e), subtitulo, HORIZONTAL_ALIGNMENT_CENTER, w, int(16 * e), hueso)

	var tam = int(15 * e)
	var fila = 38.0 * e
	var ty = y + 78.0 * e
	var tx = x0 + 44.0 * e
	var dx = x0 + 270.0 * e
	var desc = int(16 * e)
	var alto_tecla = tam * 1.9
	var base = alto_tecla * 0.62 + (alto_tecla - desc) / 2.0 - 2.0 * e

	# Moverte: A D o flechas
	var x = tx
	x += _tecla(fuente, "A", x, ty, tam, a) + 6.0 * e
	x += _tecla(fuente, "D", x, ty, tam, a) + 10.0 * e
	lienzo.draw_string(fuente, Vector2(x, ty + base), "o", HORIZONTAL_ALIGNMENT_LEFT, -1, desc, sombra)
	x += 22.0 * e
	x += _tecla_flecha(fuente, false, x, ty, tam, a) + 6.0 * e
	_tecla_flecha(fuente, true, x, ty, tam, a)
	lienzo.draw_string(fuente, Vector2(dx, ty + base), "Moverte", HORIZONTAL_ALIGNMENT_LEFT, -1, desc, hueso)
	ty += fila

	var teclas = [
		["Espacio", "Saltar"],
		["J", "Atacar"],
		["K", "Parry, justo antes del golpe"],
		["E", "Mantén para absorber ceniza"],
	]
	for t_ in teclas:
		_tecla(fuente, t_[0], tx, ty, tam, a, 84.0 * e if t_[0] == "Espacio" else 0.0)
		lienzo.draw_string(fuente, Vector2(dx, ty + base), t_[1], HORIZONTAL_ALIGNMENT_LEFT, -1, desc, hueso)
		ty += fila

	lienzo.draw_string(fuente, Vector2(x0, ty + 12.0 * e), "El Jefe solo recibe daño justo después de un parry.", HORIZONTAL_ALIGNMENT_CENTER, w, int(14 * e), sombra)

	var parpadeo = 0.6 + 0.4 * sin(t * 4.0)
	var a2 = a * parpadeo
	var gran = int(17 * e)
	var by = y0 + h - 58.0 * e
	if pausa:
		# [P] o [ESC]  para continuar
		var texto_p = "para continuar"
		var wp = fuente.get_string_size("P", HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + tam * 1.1
		wp = maxf(wp, tam * 2.0)
		var we = fuente.get_string_size("ESC", HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + tam * 1.1
		var wo = fuente.get_string_size("o", HORIZONTAL_ALIGNMENT_LEFT, -1, desc).x
		var wt = fuente.get_string_size(texto_p, HORIZONTAL_ALIGNMENT_LEFT, -1, gran).x
		var total = wp + 10.0 * e + wo + 10.0 * e + we + 12.0 * e + wt
		var bx = cx - total / 2.0
		bx += _tecla(fuente, "P", bx, by, tam, a2) + 10.0 * e
		lienzo.draw_string(fuente, Vector2(bx, by + base), "o", HORIZONTAL_ALIGNMENT_LEFT, -1, desc, Color(HUESO_SOMBRA.r, HUESO_SOMBRA.g, HUESO_SOMBRA.b, a2))
		bx += wo + 10.0 * e
		bx += _tecla(fuente, "ESC", bx, by, tam, a2) + 12.0 * e
		lienzo.draw_string(fuente, Vector2(bx, by + base), texto_p, HORIZONTAL_ALIGNMENT_LEFT, -1, gran, Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, a2))
		return
	var texto_e = "para empezar"
	var ancho_t = fuente.get_string_size(texto_e, HORIZONTAL_ALIGNMENT_LEFT, -1, gran).x
	var ancho_k = fuente.get_string_size("ENTER", HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + tam * 1.1
	var bx = cx - (ancho_k + 10.0 * e + ancho_t) / 2.0
	var kw = _tecla(fuente, "ENTER", bx, by, tam, a2)
	lienzo.draw_string(fuente, Vector2(bx + kw + 10.0 * e, by + base), texto_e, HORIZONTAL_ALIGNMENT_LEFT, -1, gran, Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, a2))


# Recuadro corto abajo al centro con una tecla y una frase.
func _aviso_parry(vp, fuente):
	var total = 7.0 if aviso_tipo == 1 else (8.0 if aviso_tipo == 3 else 6.0)
	var a = clampf((total - aviso_t) / 0.4, 0.0, 1.0) * clampf(aviso_t / 0.6, 0.0, 1.0)
	var e = clampf(vp.y / 648.0, 0.8, 1.6)
	var tecla_txt = "K"
	var linea1 = "Parry: aprieta K justo antes de que te golpeen"
	var linea2 = "Si sale bien, el enemigo queda aturdido"
	if aviso_tipo == 2:
		tecla_txt = "J"
		linea1 = "¡Parry! Ataca ahora con J"
		linea2 = "El siguiente golpe hace daño doble"
	elif aviso_tipo == 3:
		linea1 = "El Jefe solo recibe daño después de un parry"
		linea2 = "Desvía su golpe con K y ataca enseguida con J"
	var tam = int(15 * e)
	var t1 = int(17 * e)
	var t2 = int(14 * e)
	var ancho_txt = maxf(fuente.get_string_size(linea1, HORIZONTAL_ALIGNMENT_LEFT, -1, t1).x, fuente.get_string_size(linea2, HORIZONTAL_ALIGNMENT_LEFT, -1, t2).x)
	var w = ancho_txt + 110.0 * e
	var h = 70.0 * e
	var x0 = (vp.x - w) / 2.0
	var y0 = vp.y - h - 70.0 * e
	lienzo.draw_rect(Rect2(x0, y0, w, h), Color(NEGRO.r, NEGRO.g, NEGRO.b, 0.9 * a))
	lienzo.draw_rect(Rect2(x0, y0, w, h), Color(ORO.r, ORO.g, ORO.b, a), false, 2.0)
	var kw = _tecla(fuente, tecla_txt, x0 + 22.0 * e, y0 + (h - tam * 1.9) / 2.0, tam, a)
	var tx = x0 + 22.0 * e + kw + 18.0 * e
	lienzo.draw_string(fuente, Vector2(tx, y0 + h * 0.43), linea1, HORIZONTAL_ALIGNMENT_LEFT, -1, t1, Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, a))
	lienzo.draw_string(fuente, Vector2(tx, y0 + h * 0.75), linea2, HORIZONTAL_ALIGNMENT_LEFT, -1, t2, Color(HUESO.r, HUESO.g, HUESO.b, a))


# Flecha dorada hacia una puerta que ya se abrió y todavía no se cruzó.
# Fuera de pantalla: sale en el borde, apuntando hacia ella (como la de la ceniza).
# En pantalla: una flecha que rebota encima de la puerta durante los primeros 10 s.
func _flecha_puerta(vp, d):
	var nodo = d.nodo
	if not is_instance_valid(nodo) or not nodo.abierta or d.cruzada:
		return
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var punto = cam.unproject_position(nodo.global_position + Vector3(0, 1.0, 0))
	var margen = 44.0
	var area = Rect2(margen, margen, maxf(vp.x - 2 * margen, 1.0), maxf(vp.y - 2 * margen, 1.0))
	var oro = Color(ORO_CLARO.r, ORO_CLARO.g, ORO_CLARO.b, 0.7 + 0.3 * sin(t * 5.0))
	if area.has_point(punto):
		if d.abierta_t > 10.0:
			return
		var rebote = 6.0 * sin(t * 6.0)
		var b = Vector2(punto.x, punto.y - 70.0 + rebote)
		lienzo.draw_colored_polygon(PackedVector2Array([b + Vector2(0, 22), b + Vector2(-14, -2), b + Vector2(14, -2)]), oro)
		lienzo.draw_rect(Rect2(b.x - 5, b.y - 22, 10, 22), oro)
		return
	var centro = vp / 2.0
	var dir = (punto - centro).normalized()
	var esc = 100000.0
	if absf(dir.x) > 0.001:
		esc = minf(esc, (area.size.x / 2.0) / absf(dir.x))
	if absf(dir.y) > 0.001:
		esc = minf(esc, (area.size.y / 2.0) / absf(dir.y))
	var pos = centro + dir * esc
	var perp = Vector2(-dir.y, dir.x)
	lienzo.draw_colored_polygon(PackedVector2Array([pos + dir * 18, pos - dir * 8 + perp * 13, pos - dir * 8 - perp * 13]), oro)
	lienzo.draw_circle(pos - dir * 24, 3.5, oro)
