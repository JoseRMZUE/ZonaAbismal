class_name Sonido
extends RefCounted
# Cada llamada crea un AudioStreamPlayer3D suelto en la escena, lo suena en esa

const CARPETA = "res://Audio/"

# Cada sonido del juego: qué archivos usa y qué tan fuerte suena (dB).
#  - Si hay varios archivos, elige uno al azar: un golpe repetido no suena
#    siempre idéntico.
const BANCO = {
	"rugido_verdugo": {"archivos": ["rugido_verdugo"], "db": 0.0},
	"rugido_hermano": {"archivos": ["rugido_hermano"], "db": 0.0},
	"ataque_verdugo": {"archivos": ["ataque_verdugo"], "db": -1.0},
	"ataque_hermano": {"archivos": ["ataque_hermano"], "db": -1.0},
	"golpe_recibido": {"archivos": ["golpe_recibido"], "db": 0.0},
	"espada_aire": {"archivos": ["espada_aire_1", "espada_aire_2", "espada_aire_3"], "db": -4.0},
	"espada_golpe": {"archivos": ["espada_golpe_1", "espada_golpe_2", "espada_golpe_3"], "db": 0.0},
	"espada_contragolpe": {"archivos": ["espada_contragolpe"], "db": 1.0},
	"parry": {"archivos": ["espada_contragolpe"], "db": 1.0},
}

# Qué tanto varía el tono de una vez a otra (0.05 = ±5 %).
const VARIACION_TONO = 0.05
# La cámara está a ~20 m del plano de juego: con este tamaño de unidad un
# sonido sobre el plano suena a volumen "normal" y se nota si está a un lado.
const TAMANO_UNIDAD = 20.0

# Los archivos ya cargados (se cargan una sola vez).
static var cache: Dictionary = {}


# desde:    cualquier nodo del árbol (sirve para llegar a la escena).
# nombre:   una llave de BANCO.
# posicion: dónde suena (Vector3). Si no se da, en la posición de "desde".
# retraso:  segundos de espera antes de sonar (para cuadrar con la animación).
static func reproducir(desde: Node, nombre: String, posicion = null, retraso: float = 0.0) -> void:
	if not BANCO.has(nombre):
		push_warning("Sonido: '" + nombre + "' no está en el BANCO")
		return
	if desde == null or not desde.is_inside_tree():
		return
	var arbol = desde.get_tree()
	var punto = Vector3.ZERO
	if posicion != null:
		punto = posicion
	elif desde is Node3D:
		punto = (desde as Node3D).global_position

	var datos = BANCO[nombre]
	var flujo = _cargar(datos.archivos.pick_random())
	if flujo == null:
		return

	if retraso > 0.001:
		# false = el reloj se detiene con la pausa del juego.
		await arbol.create_timer(retraso, false).timeout
	var escena = arbol.current_scene
	if escena == null:
		return

	var p = AudioStreamPlayer3D.new()
	p.stream = flujo
	p.volume_db = datos.db
	p.pitch_scale = randf_range(1.0 - VARIACION_TONO, 1.0 + VARIACION_TONO)
	p.unit_size = TAMANO_UNIDAD
	p.max_db = 0.0   # de cerca no se amplifica
	p.finished.connect(p.queue_free)
	escena.add_child(p)
	p.global_position = punto
	p.play()


# Busca el archivo con cualquiera de estas extensiones, en este orden.
const EXTENSIONES = ["wav", "ogg", "mp3"]

static func _cargar(archivo: String):
	if cache.has(archivo):
		return cache[archivo]
	for ext in EXTENSIONES:
		var ruta = CARPETA + archivo + "." + ext
		if ResourceLoader.exists(ruta):
			cache[archivo] = load(ruta)
			return cache[archivo]
	push_warning("Sonido: no encuentro " + archivo + " en " + CARPETA)
	return null
