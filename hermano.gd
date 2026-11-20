extends CharacterBody3D

enum Estado { PATRULLAR, ESPERAR, PERSEGUIR, ATACAR, BUSCAR, ATURDIDO, MUERTO }

@export var rapidez = 2.0
# PARASITE: al perseguir corre (animación run), un poco más rápido.
@export var rapidez_correr = 3.0
@export var espera = 1.0
@export var rango_vision = 6.0
@export var rango_ataque = 1.2
@export var rango_perder = 8.0
@export var tiempo_busqueda = 2.0
@export var vida = 4
# Golpe real (agregado por el equipo): ataca cada 1.5 s como el Acólito
# del concepto y pega solo cuando el brazo llega, no al tocarlo.
@export var cadencia_golpe = 1.5
@export var danio = 1
@export var alcance_golpe = 1.6
@export var alto_golpe = 1.0
# PARASITE: segundo de la animación "ataque" (dura 3.2 s) en que el golpe
# llega (medido en Godot). El daño se aplica justo ahí.
@export var impacto = 1.76
# PARASITE: cuánto de la preparación del golpe se alcanza a ver antes del
# impacto (el aviso para esquivar o hacer parry).
@export var aviso_golpe = 0.9
# PARASITE: segundos de transición entre animaciones.
@export var mezcla = 0.2
# PARRY: si el jugador desvía el golpe, queda aturdido (concepto: 1.5 s).
@export var tiempo_aturdido = 1.5
# MUERTE: segundos que el cuerpo queda en el piso después de la animación.
@export var espera_cuerpo = 1.0
# Desplazamientos desde donde se colocó el NPC, no posiciones absolutas.
@export var ruta: Array[Vector3] = [Vector3.ZERO, Vector3(4, 0, 0)]

var estado = Estado.PATRULLAR
var puntos: Array[Vector3] = []
var indice = 0
var reloj = 0.0
var jugador = null
var ultimo_visto = Vector3.ZERO
var busca = 0.0
var espera_golpe = 0.0
var golpe_en_curso = false
var tiempo_golpe = 0.0
var aturdido_restante = 0.0   # PARRY
var muerto = false            # MUERTE: la Partida lo lee para no revivirlo
# PARASITE: el AnimationPlayer está dentro de Modelo > Idle.
@onready var anim = $"Modelo/Idle/AnimationPlayer"
@onready var vision = $Vision
# DESTELLO: el nodo hijo con control_efectos.gd (si no está, no pasa nada).
@onready var efectos = get_node_or_null("ControlEfectos")


func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")
	vision.collision_mask = 0xFFFFFFFF
	for d in ruta:
		puntos.append(global_position + d)


func _physics_process(delta):
	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador")
	if jugador == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	velocity += get_gravity() * delta
	reloj = maxf(reloj - delta, 0.0)
	busca = maxf(busca - delta, 0.0)
	aturdido_restante = maxf(aturdido_restante - delta, 0.0)
	# 1. MEDIR
	var d = distancia_a(jugador.global_position)
	var ve = lo_ve()
	if ve:
		ultimo_visto = jugador.global_position
	# 2. DECIDIR
	var nuevo = decidir(d, ve)
	if nuevo != estado:
		estado = nuevo
		print(name, " -> ", Estado.keys()[estado], " cuadro ",
			Engine.get_physics_frames(), " a ", snappedf(d, 0.01), " m")
		if estado == Estado.ATACAR:
			# El primer golpe arranca de una: su preparación ya es el aviso.
			espera_golpe = 0.0
			golpe_en_curso = false
		elif estado == Estado.MUERTO:
			# MUERTE: ya no choca ni recibe disparos (sigue en el piso por su máscara).
			collision_layer = 0
			anim.play("hermano/morir", mezcla)
			reloj = anim.get_animation("hermano/morir").length + espera_cuerpo
	# 3. ACTUAR
	match estado:
		Estado.PATRULLAR:
			patrullar()
		Estado.ESPERAR:
			frenar()
		Estado.PERSEGUIR:
			ir_a(jugador.global_position, "hermano/run", rapidez_correr)
		Estado.ATACAR:
			velocity.x = 0.0
			velocity.z = 0.0
			mirar_a(jugador.global_position)
			atacar(delta)
		Estado.BUSCAR:
			if distancia_a(ultimo_visto) > 0.1:
				ir_a(ultimo_visto, "hermano/walk", rapidez)
			else:
				frenar()
		Estado.ATURDIDO:   # PARRY
			velocity.x = 0.0
			velocity.z = 0.0
			if anim.has_animation("hermano/aturdido"):
				anim.play("hermano/aturdido", mezcla)
			else:
				anim.play("hermano/idle", mezcla)
		Estado.MUERTO:   # MUERTE
			velocity.x = 0.0
			velocity.z = 0.0
			if reloj <= 0.001 and not is_queued_for_deletion():
				queue_free()
	# Un cuerpo caído ya en el piso no se mueve: si siguiera deslizándose, el
	# jugador que camina contra él lo arrastraría.
	if estado == Estado.MUERTO and is_on_floor():
		return
	move_and_slide()


# El orden ES la regla: el primer if que se cumple gana.
func decidir(d, ve):
	# MUERTE y PARRY van primero: le ganan a todo lo demás.
	if muerto:
		return Estado.MUERTO
	if aturdido_restante > 0.001:
		return Estado.ATURDIDO
	var alerta = estado == Estado.PERSEGUIR or estado == Estado.ATACAR
	# Ya alerta, necesita más distancia para soltarlo: histéresis.
	var limite = rango_perder if alerta else rango_vision
	if ve and d <= rango_ataque:
		return Estado.ATACAR
	if ve and d <= limite:
		return Estado.PERSEGUIR
	if alerta:
		busca = tiempo_busqueda
		return Estado.BUSCAR
	if busca > 0.001:
		return Estado.BUSCAR
	if reloj > 0.001:
		return Estado.ESPERAR
	return Estado.PATRULLAR


func lo_ve():
	if not is_instance_valid(jugador):
		return false
	# Se apunta al pecho: el origen del jugador está en los pies.
	var pecho = jugador.global_position + Vector3(0, 0.9, 0)
	vision.target_position = vision.to_local(pecho)
	vision.force_raycast_update()
	if vision.is_colliding():
		# ¿Lo primero que tocó fue el jugador, o una pared?
		var collider = vision.get_collider() as Node
		return collider == jugador or (collider != null and collider.is_in_group("jugador"))
	return true


func patrullar():
	var destino = puntos[indice]
	if distancia_a(destino) < 0.1:
		indice = (indice + 1) % puntos.size()
		reloj = espera
		frenar()
		return
	ir_a(destino, "hermano/walk", rapidez)


# PARASITE: recibe qué animación poner y a qué velocidad (caminar o correr).
func ir_a(destino, animacion, velocidad):
	var hacia = destino - global_position
	hacia.y = 0.0
	# Justo encima o debajo: no hay hacia dónde girar (evita el error de
	# looking_at con dirección cero).
	if hacia.length() < 0.05:
		frenar()
		return
	var dir = hacia.normalized()
	velocity.x = dir.x * velocidad
	velocity.z = dir.z * velocidad
	basis = Basis.looking_at(dir)
	anim.play(animacion, mezcla)


func frenar():
	velocity.x = 0.0
	velocity.z = 0.0
	anim.play("hermano/idle", mezcla)


# Distancia en el suelo: si el otro salta, no "se aleja".
func distancia_a(p):
	var o = global_position
	return Vector2(p.x - o.x, p.z - o.z).length()


# Agregado por el equipo (no lo da el esqueleto del taller): Hermano
# necesita vida y recibir_golpe para ser el enemigo real de Sala A,
# copiando el mismo patrón que enemigo.gd (Taller 7).
func recibir_golpe(cuanto):
	# MUERTE: a un cuerpo que ya cayó no se le resta más.
	if muerto:
		return
	vida -= cuanto
	print(name, ": vida ", vida)
	# DESTELLO: pulso blanco cuando le pegan.
	if efectos != null:
		efectos.destello(efectos.color_golpe)
	if vida <= 0:
		# MUERTE: ya no desaparece de una: primero la animación de morir.
		print(name, " destruida")
		muerto = true


# Cada cadencia_golpe s arranca un golpe. La animación arranca aviso_golpe s
# antes de su impacto, así el daño cae justo cuando el golpe se ve llegar.
func atacar(delta):
	espera_golpe = maxf(espera_golpe - delta, 0.0)
	if not golpe_en_curso and espera_golpe <= 0.001:
		golpe_en_curso = true
		tiempo_golpe = 0.0
		espera_golpe = cadencia_golpe
		anim.play("hermano/ataque", mezcla)
		anim.seek(impacto - aviso_golpe, true)
	if golpe_en_curso:
		tiempo_golpe += delta
		# DESTELLO: brilla en rojo mientras prepara el golpe (el aviso).
		if efectos != null:
			efectos.mantener(efectos.color_aviso)
		if tiempo_golpe >= aviso_golpe:
			golpe_en_curso = false
			golpear()
	elif anim.current_animation != "hermano/ataque":
		# Si la recuperación del golpe ya terminó, queda en idle.
		anim.play("hermano/idle", mezcla)


# El golpe mira dónde está el jugador AHORA: si se alejó, saltó o está en
# otra plataforma, falla. Si el parry está activo, lo desvía.
func golpear():
	if not lo_ve():
		print(name, " no alcanza al jugador: una pared bloquea la visión")
		return
	var dif = jugador.global_position - global_position
	if Vector2(dif.x, dif.z).length() > alcance_golpe or absf(dif.y) > alto_golpe:
		print(name, " falla el golpe")
		return
	var parry = jugador.get_node_or_null("Parry")
	if parry != null and parry.has_method("esta_activa") and parry.esta_activa():
		# PARRY: igual que el Verdugo: queda aturdido y el jugador gana el doble daño.
		print(name, " golpe desviado por el parry")
		aturdido_restante = tiempo_aturdido
		parry.exito(tiempo_aturdido)
		return
	var salud = jugador.get_node_or_null("Salud")
	if salud != null:
		salud.recibir_golpe(danio)


# Gira hacia el jugador mientras ataca, para no pegarle de espaldas.
func mirar_a(p):
	var hacia = p - global_position
	hacia.y = 0.0
	if hacia.length() > 0.05:
		basis = Basis.looking_at(hacia.normalized())
