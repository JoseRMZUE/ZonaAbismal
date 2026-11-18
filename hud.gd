extends CanvasLayer
# HUD de Zona Abismal (plan de trabajo, Sesión 5 · parte de Johan).
# El estilo sale de la imagen de referencia del equipo: barra de pixel art con
# marco de hueso, relleno rojo, ornamento de alas a la izquierda y el número
# ("3/3", "100/100") en una placa oscura debajo. Todo se dibuja con código:
# no necesita imágenes ni escenas, solo este nodo en main.tscn.
#
#   VIDA     barra roja partida en 3 (una por vida), lee Salud.vida
#   FERVOR   barra violeta, lee Parry.fervor; pulsa al llegar a 100
#   CENIZA   los puntos que lleva el jugador; flecha hacia la ceniza caída
#   Mensajes, objetivo, aviso de "Mantén E", pantalla de caída, de victoria
#   y de fin de la zona (ENTER para volver a empezar).
#
# Los demás scripts le hablan por grupo, sin conocerlo:
#   get_tree().call_group("hud", "mensaje", "texto", segundos)
#   get_tree().call_group("hud", "poner_objetivo", "texto")

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
	fade_objetivo = 1.0


func _al_revivir():
	fade_objetivo = 0.0
	if cayo_con_ceniza:
		mensaje("Tu ceniza quedó donde caíste: vuelve por ella", 4.0)


func _ceniza_recuperada(cantidad):
	mensaje("Ceniza recuperada  +" + str(cantidad), 3.0)


func _ceniza_perdida():
	mensaje("Tu ceniza se perdió para siempre", 4.0)


func _zona_terminada():
	fin_visible = true
	fin_t = 0.0


func _input(event):
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
				_r(cx + (i % 3), y + int(i / 3), 1, 1, color)
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
	_r(x + int(h / 2) , y + h - 1, w - 2 * int(h / 2), 1, HUESO_SOMBRA)
	if brillo_borde > 0.0:
		var c = HUESO.lerp(colores[0], brillo_borde)
		_hexagono(x, y, w, h, c)
	_hexagono(x + 1, y + 1, w - 2, h - 2, NEGRO)
	# pista y relleno
	var ix = x + int(h / 2) + 1
	var iw = w - 2 * (int(h / 2) + 1)
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
	var hu = int(vp.y / p)
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
	var que = "la ceniza caída"
	var cant = 0
	if "cantidad" in obj:
		cant = obj.cantidad
	if "es_rastro" in obj and obj.es_rastro:
		que = "el rastro de otro penitente"
	var texto = "Mantén E: recoger " + que + "  +" + str(cant)
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
