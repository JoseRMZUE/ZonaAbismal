class_name Onda
extends RefCounted

# Las cuentas del shader, escritas en GDScript para poder probarlas con print.
# El shader no tiene print: aqui comprobamos la cuenta, y en pantalla vemos
# que el shader hace la misma.

# k = vueltas por metro: la onda se repite cada "longitud" metros.
static func k(longitud: float) -> float:
	return TAU / longitud

# w = vueltas por segundo: la onda se repite cada "periodo" segundos.
static func w(periodo: float) -> float:
	return TAU / periodo

# y = A * sin(k * x - w * t). El menos hace que la onda viaje hacia +X.
static func altura(x: float, t: float, amplitud: float, longitud: float, periodo: float) -> float:
	return amplitud * sin(k(longitud) * x - w(periodo) * t)

# Pendiente de la onda = su derivada: s = A * k * cos(k * x - w * t).
static func pendiente(x: float, t: float, amplitud: float, longitud: float, periodo: float) -> float:
	return amplitud * k(longitud) * cos(k(longitud) * x - w(periodo) * t)

# Normal de una superficie ACOSTADA (como el agua): una recta de pendiente s
# avanza en (1, s, 0) y la perpendicular es (-s, 1, 0).
static func normal(s: float) -> Vector3:
	return Vector3(-s, 1.0, 0.0).normalized()

# Normal de MI malla, que esta de frente a la camara (un QuadMesh mira a +Z):
# parte de (0, 0, 1) y se inclina igual.
static func normal_frente(s: float) -> Vector3:
	return Vector3(-s, 0.0, 1.0).normalized()

# Lambert: cuanta luz recibe una superficie con esa normal. hacia_luz = hacia donde esta la luz.
static func lambert(n: Vector3, hacia_luz: Vector3) -> float:
	return maxf(0.0, n.normalized().dot(hacia_luz.normalized()))
