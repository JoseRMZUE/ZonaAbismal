extends CharacterBody3D

# DESTELLO: el Verdugo también es un "disparador" del Taller 4: al avisar el
# golpe emite esta señal y SistemaEventos (Sala B) hace el destello de luz.
signal evento(posicion: Vector3)

enum Estado { ACERCARSE, RUGIR, AVISO, GOLPE, RECARGA, HUIR, ATURDIDO, MUERTO }   # PARRY: ATURDIDO · MUERTE: MUERTO · SONIDO: RUGIR

@export var rapidez = 2.0
@export var rango_ataque = 1.0
@export var tiempo_aviso = 0.3
@export var tiempo_recarga = 1.2
@export var alcance_golpe = 1.3
@export var danio = 1
@export var vida = 4          # NUEVO N3
@export var vida_huida = 1    # NUEVO N3
@export var mezcla = 0.25     # MUTANTE: segundos de transición entre animaciones
# MUTANTE: segundo de la animación "ataque" en que la mano llega al frente
# (medido en ataque.fbx). El daño se aplica justo en ese momento.
@export var impacto = 1.27
# Diferencia de altura máxima para atacar y pegar (m): si el jugador está
# en otra plataforma o saltó por encima del golpe, no le pega.
@export var alto_golpe = 1.0
# PARRY: cuánto queda aturdido si el jugador desvía el golpe (concepto: 1.5 s).
@export var tiempo_aturdido = 1.5
# MUERTE: segundos que el cuerpo queda en el piso después de la animación.
@export var espera_cuerpo = 1.0
# RUGIDO: a qué distancia (m) lo ve, si no hay una pared en medio. Ya alerta,
# lo sigue viendo hasta 1.5 veces esa distancia (histéresis, como el Hermano).
@export var rango_vision = 12.0
# RUGIDO: cuánto dura el rugido antes de ir por el jugador (el aviso para él).
@export var tiempo_rugido = 2.6
# RUGIDO: segundos que espera el sonido desde que arranca la animación, para
# que el grito caiga cuando abre la boca (se ajusta mirando el juego).
@export var retraso_rugido = 0.5
# RUGIDO: si lo pierde de vista este tiempo, la próxima vez vuelve a rugir.
@export var tiempo_olvido = 4.0
# SONIDO: el archivo de ataque trae el golpe a 0.30 s de su inicio; arranca así
# de antes del impacto para que suene a la vez que llega la mano.
@export var adelanto_sonido = 0.3

var estado = Estado.ACERCARSE
var reloj = 0.0
var jugador = null
var parado = false            # PARRY: el último golpe fue desviado
var muerto = false            # MUERTE: la Partida lo lee para no revivirlo
var alerta = false            # RUGIDO: ya rugió y sigue pendiente del jugador
var sin_ver = 0.0             # RUGIDO: cuánto lleva sin verlo
var sonido_ataque = false     # SONIDO: el sonido de este golpe ya sonó
# MUTANTE: el AnimationPlayer está dentro de Modelo > Mutant Idle.
@onready var anim = $"Modelo/Mutant Idle/AnimationPlayer"
# DESTELLO: el nodo hijo con control_efectos.gd (si no está, no pasa nada).
@onready var efectos = get_node_or_null("ControlEfectos")


func _enter_tree():
	# DESTELLO: así SistemaEventos lo encuentra igual que a un Disparador.
	add_to_group("disparadores")


func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")


func _physics_process(delta):
	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador")
	if jugador == null and not muerto:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	velocity += get_gravity() * delta
	# Una pared corta su visión: se detiene y no avanza el ciclo de ataque.
	if not muerto and not _lo_ve():
		velocity.x = 0.0
		velocity.z = 0.0
		# RUGIDO: si lo pierde mucho tiempo, olvida que estaba alerta.
		sin_ver += delta
		if sin_ver >= tiempo_olvido:
			alerta = false
		if estado == Estado.RUGIR or estado == Estado.AVISO or estado == Estado.GOLPE:
			estado = Estado.ACERCARSE
			reloj = 0.0
			parado = false
		if anim.current_animation != "verdugo/idle":
			anim.play("verdugo/idle", mezcla)
		move_and_slide()
		return

	sin_ver = 0.0
	reloj = maxf(reloj - delta, 0.0)
	var nuevo = decidir()
	if nuevo != estado:
		cambiar_a(nuevo)
	# MUTANTE: animaciones de la biblioteca "verdugo".
	match estado:
		Estado.ACERCARSE:
			ir_a(jugador.global_position, "verdugo/walk")
		Estado.RUGIR:   # RUGIDO
			# Se planta, mira al jugador y ruge (el sonido lo arranca cambiar_a).
			mirar_jugador()
			frenar("verdugo/roaringaviso")
		Estado.AVISO:
			# El brazo ya viene bajando (lo arranca cambiar_a).
			frenar("verdugo/ataque")
			# SONIDO: el ataque suena justo antes de que llegue la mano.
			if not sonido_ataque and reloj <= adelanto_sonido:
				sonido_ataque = true
				Sonido.reproducir(self, "ataque_verdugo")
			# DESTELLO: brilla en rojo todo el aviso (0.3 s del concepto).
			if efectos != null:
				efectos.mantener(efectos.color_aviso)
		Estado.GOLPE:
			# La mano llega justo ahora: aquí se quita la vida (o se desvía).
			frenar("verdugo/ataque")
			golpear()
		Estado.RECARGA:
			# Deja terminar la recuperación del golpe antes de volver a idle.
			if anim.current_animation == "verdugo/ataque":
				frenar("verdugo/ataque")
			else:
				frenar("verdugo/idle")
		Estado.HUIR:   # NUEVO N3
			# Huir es perseguir con la flecha al revés.
			var lejos = global_position - jugador.global_position
			ir_a(global_position + lejos, "verdugo/injuredrun")
		Estado.ATURDIDO:   # PARRY
			frenar("verdugo/stunned")
		Estado.MUERTO:   # MUERTE
			# Quieto mientras se ve la animación; al terminar, desaparece.
			velocity.x = 0.0
			velocity.z = 0.0
			if reloj <= 0.001 and not is_queued_for_deletion():
				queue_free()
	# Un cuerpo caído ya en el piso no se mueve: si siguiera deslizándose, el
	# jugador que camina contra él lo arrastraría.
	if estado == Estado.MUERTO and is_on_floor():
		return
	move_and_slide()


func decidir():
	# MUERTE: si ya murió, nada más importa (ni siquiera huir).
	if muerto:
		return Estado.MUERTO
	# NUEVO N3. Va primero: le gana a cualquier estado, también al AVISO.
	if vida <= vida_huida:
		return Estado.HUIR
	match estado:
		Estado.ACERCARSE:
			# RUGIDO: la primera vez que lo ve, ruge antes de ir por él.
			if not alerta:
				return Estado.RUGIR
			# Cerca en el piso Y en el mismo nivel: si está en otra
			# plataforma, no empieza a atacar.
			if distancia() <= rango_ataque and altura() <= alto_golpe:
				return Estado.AVISO
		Estado.RUGIR:   # RUGIDO
			if reloj <= 0.001:
				return Estado.ACERCARSE
		Estado.AVISO:
			if reloj <= 0.001:
				return Estado.GOLPE
		Estado.GOLPE:
			# PARRY: si el jugador desvió el golpe, queda aturdido.
			if parado:
				return Estado.ATURDIDO
			return Estado.RECARGA
		Estado.RECARGA:
			if reloj <= 0.001:
				return Estado.ACERCARSE
		Estado.HUIR:
			# Si llega aquí es porque recuperó vida (al reaparecer el jugador,
			# la Partida se la devuelve): deja de huir y vuelve a pelear.
			return Estado.ACERCARSE
		Estado.ATURDIDO:   # PARRY
			if reloj <= 0.001:
				return Estado.ACERCARSE
	return estado


func cambiar_a(nuevo):
	estado = nuevo
	print(name, " -> ", Estado.keys()[estado], " cuadro ",
		Engine.get_physics_frames(), " a ",
		snappedf(distancia(), 0.01), " m")
	if estado == Estado.RUGIR:   # RUGIDO
		reloj = tiempo_rugido
		alerta = true
		anim.play("verdugo/roaringaviso", mezcla)
		# SONIDO: el grito arranca un poco después que la animación.
		Sonido.reproducir(self, "rugido_verdugo", null, retraso_rugido)
	elif estado == Estado.AVISO:
		reloj = tiempo_aviso
		sonido_ataque = false
		# MUTANTE: arranca el ataque con el brazo ya atrás, para que la mano
		# llegue (impacto) justo cuando termine el aviso y empiece GOLPE.
		anim.play("verdugo/ataque", mezcla)
		anim.seek(impacto - tiempo_aviso, true)
		# DESTELLO: la luz roja de la sala parpadea donde está el Verdugo.
		evento.emit(global_position)
	elif estado == Estado.RECARGA:
		reloj = tiempo_recarga
	elif estado == Estado.ATURDIDO:   # PARRY
		reloj = tiempo_aturdido
		parado = false
	elif estado == Estado.MUERTO:   # MUERTE
		# Ya no choca ni recibe disparos (sigue parado en el piso por su máscara).
		collision_layer = 0
		anim.play("verdugo/morir", mezcla)
		reloj = anim.get_animation("verdugo/morir").length + espera_cuerpo


# El aviso le da tiempo al jugador: el golpe mira DÓNDE ESTÁ AHORA,
# también en altura (si saltó o está en otra plataforma, falla).
func golpear():
	if not _hay_linea_de_vision():
		print(name, " falla el golpe: una pared bloquea la visión")
		return
	if distancia() > alcance_golpe or altura() > alto_golpe:
		print(name, " falla a ", snappedf(distancia(), 0.01), " m (altura ",
			snappedf(altura(), 0.01), " m)")
		return
	# PARRY: si el parry del jugador está activo justo cuando llega la mano,
	# el golpe se desvía: no quita vida y el Verdugo queda aturdido.
	var parry = jugador.get_node_or_null("Parry")
	if parry != null and parry.has_method("esta_activa") and parry.esta_activa():
		print(name, " golpe desviado por el parry")
		parado = true
		parry.exito(tiempo_aturdido, global_position)
		# DESTELLO: el Verdugo brilla dorado cuando le desvían el golpe.
		if efectos != null:
			efectos.destello(efectos.color_parry)
		return
	var salud = jugador.get_node_or_null("Salud")
	if salud != null:
		salud.recibir_golpe(danio)


# NUEVO N3. Se llama igual que la del Taller 8: el rayo de apuntar.gd ya la sabe usar.
func recibir_golpe(cuanto):
	# MUERTE: a un cuerpo que ya cayó no se le resta más.
	if muerto:
		return
	vida = maxi(vida - cuanto, 0)
	print(name, " vida ", vida)
	# DESTELLO: pulso blanco cuando le pegan.
	if efectos != null:
		efectos.destello(efectos.color_golpe)
	if vida <= 0:
		# MUERTE: ya no desaparece de una: primero la animación de morir.
		print(name, " vencido")
		muerto = true


# MUTANTE: recibe qué animación poner (caminar o huir).
func ir_a(destino, animacion):
	var hacia = destino - global_position
	hacia.y = 0.0
	# Si está justo encima o debajo del jugador no hay hacia dónde girar:
	# se queda quieto esperando (y evita el error de looking_at con cero).
	if hacia.length() < 0.05:
		frenar("verdugo/idle")
		return
	var dir = hacia.normalized()
	velocity.x = dir.x * rapidez
	velocity.z = dir.z * rapidez
	basis = Basis.looking_at(dir)
	anim.play(animacion, mezcla)


# RUGIDO: gira (solo en el piso) hacia donde está el jugador.
func mirar_jugador():
	var hacia = jugador.global_position - global_position
	hacia.y = 0.0
	if hacia.length() > 0.05:
		basis = Basis.looking_at(hacia.normalized())


func frenar(animacion):
	velocity.x = 0.0
	velocity.z = 0.0
	anim.play(animacion, mezcla)


# Distancia en el piso (X y Z), sin contar la altura.
func distancia():
	var p = jugador.global_position
	var o = global_position
	return Vector2(p.x - o.x, p.z - o.z).length()


# Diferencia de altura (los dos tienen el origen en los pies).
func altura():
	return absf(jugador.global_position.y - global_position.y)


# RUGIDO: lo "ve" si está lo bastante cerca Y no hay una pared en medio.
func _lo_ve() -> bool:
	var limite = rango_vision
	if alerta:
		limite = rango_vision * 1.5
	return distancia() <= limite and _hay_linea_de_vision()


func _hay_linea_de_vision() -> bool:
	var desde: Vector3 = global_position + Vector3(0, 0.9, 0)
	var hasta: Vector3 = jugador.global_position + Vector3(0, 0.9, 0)
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	consulta.collision_mask = 0xFFFFFFFF
	consulta.exclude = [get_rid()]
	var impacto_rayo = get_world_3d().direct_space_state.intersect_ray(consulta)
	if impacto_rayo.is_empty():
		return true
	var collider = impacto_rayo.get("collider") as Node
	return collider == jugador or (collider != null and collider.is_in_group("jugador"))
