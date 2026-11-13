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
