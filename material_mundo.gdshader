shader_type spatial;

// Velos del altar movidos por el viento del atardecer.
// Nivel 1: vertex() sube o baja cada vertice con un seno de x y del tiempo.

uniform vec3 color_bajo : source_color = vec3(0.106, 0.122, 0.169); // #1B1F2B
uniform float amplitud = 0.1;   // metros que sube la cresta
uniform float longitud = 2.0;   // metros entre cresta y cresta
uniform float periodo = 2.0;    // segundos en repetirse

// La misma cuenta de Onda.altura() en GDScript.
float onda(float x, float t, float a, float l, float p) {
	return a * sin(TAU / l * x - TAU / p * t);
}

void vertex() {
	float h = onda(VERTEX.x, TIME, amplitud, longitud, periodo);
	VERTEX.y += h;
}

void fragment() {
	ALBEDO = color_bajo;
	ROUGHNESS = 0.4;
}
