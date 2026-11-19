extends CharacterBody3D

enum Estado { ACERCARSE, AVISO, GOLPE, RECARGA, HUIR }   # NUEVO N3: HUIR

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

var estado = Estado.ACERCARSE
var reloj = 0.0
var jugador = null
# MUTANTE: el AnimationPlayer está dentro de Modelo > Mutant Idle.
@onready var anim = $"Modelo/Mutant Idle/AnimationPlayer"


func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")


func _physics_process(delta):
	velocity += get_gravity() * delta
	reloj = maxf(reloj - delta, 0.0)
	var nuevo = decidir()
	if nuevo != estado:
		cambiar_a(nuevo)
	# MUTANTE: animaciones de la biblioteca "verdugo".
	match estado:
		Estado.ACERCARSE:
			ir_a(jugador.global_position, "verdugo/walk")
		Estado.AVISO:
			# El brazo ya viene bajando (lo arranca cambiar_a).
			frenar("verdugo/ataque")
		Estado.GOLPE:
			# La mano llega justo ahora: aquí se quita la vida.
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
	move_and_slide()


func decidir():
	# NUEVO N3. Va primero: le gana a cualquier estado, también al AVISO.
	if vida <= vida_huida:
		return Estado.HUIR
	match estado:
		Estado.ACERCARSE:
				# Cerca en el piso Y en el mismo nivel: si está en otra
			# plataforma, no empieza a atacar.
			if distancia() <= rango_ataque and altura() <= alto_golpe:
				return Estado.AVISO
		Estado.AVISO:
			if reloj <= 0.001:
				return Estado.GOLPE
		Estado.GOLPE:
			return Estado.RECARGA
		Estado.RECARGA:
			if reloj <= 0.001:
				return Estado.ACERCARSE
		Estado.HUIR:
			# Si llega aquí es porque recuperó vida (al reaparecer el jugador,
			# la Partida se la devuelve): deja de huir y vuelve a pelear.
			return Estado.ACERCARSE
	return estado


func cambiar_a(nuevo):
	estado = nuevo
	print(name, " -> ", Estado.keys()[estado], " cuadro ",
		Engine.get_physics_frames(), " a ",
		snappedf(distancia(), 0.01), " m")
	if estado == Estado.AVISO:
		reloj = tiempo_aviso
		# MUTANTE: arranca el ataque con el brazo ya atrás, para que la mano
		# llegue (impacto) justo cuando termine el aviso y empiece GOLPE.
		anim.play("verdugo/ataque", mezcla)
		anim.seek(impacto - tiempo_aviso, true)
	elif estado == Estado.RECARGA:
		reloj = tiempo_recarga


# El aviso le da tiempo al jugador: el golpe mira DÓNDE ESTÁ AHORA,
# también en altura (si saltó o está en otra plataforma, falla).
func golpear():
	if distancia() > alcance_golpe or altura() > alto_golpe:
		print(name, " falla a ", snappedf(distancia(), 0.01), " m (altura ",
			snappedf(altura(), 0.01), " m)")
		return
	var salud = jugador.get_node_or_null("Salud")
	if salud != null:
		salud.recibir_golpe(danio)


# NUEVO N3. Se llama igual que la del Taller 8: el rayo de apuntar.gd ya la sabe usar.
func recibir_golpe(cuanto):
	vida = maxi(vida - cuanto, 0)
	print(name, " vida ", vida)
	if vida <= 0:
		print(name, " vencido")
		queue_free()


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
