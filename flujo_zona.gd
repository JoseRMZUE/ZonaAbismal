extends Node
# El hilo de la zona (plan de trabajo, Sesión 5 · lo conecta José David).
# Sin editar los archivos de nadie, enchufa las piezas que ya existen:
#
#   Hermano y Verdugo caídos (2 metas)  ->  se abre PuertaAlSalon
#   Jefe vencido (señal jefe_vencido)   ->  GANA la partida (+100 puntos)
#                                           y se abre PuertaAlBosque
#   El jugador cruza PuertaAlBosque     ->  fin de la zona (el bosque)
#
# Solo vencer al último enemigo gana el juego: matar a los dos primeros
# únicamente abre el paso al salón de las gárgolas.

@export var ruta_partida: NodePath = ^"../Partida"
@export var ruta_puerta_salon: NodePath = ^"../Puertas/PuertaAlSalon"
@export var ruta_puerta_bosque: NodePath = ^"../Puertas/PuertaAlBosque"
@export var ruta_jefe: NodePath = ^"../Jefe"

var partida = null
var puerta_salon = null
var puerta_bosque = null
var jefe = null
var jefe_aturdido_antes = false


func _ready():
	partida = get_node_or_null(ruta_partida)
	puerta_salon = get_node_or_null(ruta_puerta_salon)
	puerta_bosque = get_node_or_null(ruta_puerta_bosque)
	jefe = get_node_or_null(ruta_jefe)
	if partida == null:
		push_warning("FlujoZona: no encuentro la Partida")
		return
	partida.metas_cumplidas.connect(_guardianes_caidos)
	if puerta_salon != null:
		puerta_salon.cruzada.connect(_llego_al_salon)
	if puerta_bosque != null:
		puerta_bosque.cruzada.connect(_llego_al_bosque)
	if jefe != null:
		jefe.jefe_vencido.connect(_jefe_vencido)
		partida.registrar_enemigo(jefe)
	call_deferred("_objetivo_inicial")


func _objetivo_inicial():
	get_tree().call_group("hud", "poner_objetivo",
		"Vence al Hermano y al Verdugo para abrir el paso")


func _physics_process(_delta):
	# Un parry que sale bien contra el jefe lo deja aturdido: son 5 puntos.
	if jefe == null or not is_instance_valid(jefe) or partida == null:
		return
	if "aturdido" in jefe:
		if jefe.aturdido and not jefe_aturdido_antes:
			partida.sumar_puntos(partida.puntos_parry, "parry exitoso")
		jefe_aturdido_antes = jefe.aturdido


func _guardianes_caidos():
	print("flujo: los dos guardianes cayeron, se abre PuertaAlSalon")
	if puerta_salon != null:
		puerta_salon.abrir()
	get_tree().call_group("hud", "mensaje", "La puerta al salón se abrió", 3.5)
	get_tree().call_group("hud", "poner_objetivo", "Cruza la puerta brillante y sube al salón")


func _llego_al_salon():
	get_tree().call_group("hud", "poner_objetivo", "Derrota al Jefe: solo recibe daño tras un parry")


func _jefe_vencido():
	if partida.estado != partida.Estado.JUGANDO:
		return
	print("flujo: el jefe cayó, la partida se gana")
	partida.sumar_puntos(partida.puntos_jefe, "jefe vencido")
	partida.ganar()
	if puerta_bosque != null:
		puerta_bosque.abrir()
	get_tree().call_group("hud", "poner_objetivo", "Cruza la puerta hacia el bosque")


func _llego_al_bosque():
	partida.terminar_zona()
