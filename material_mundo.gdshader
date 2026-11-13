shader_type spatial;

// Colgaduras del altar movidas por el viento del atardecer.
// Nivel 1: vertex() sube o baja cada vertice con un seno de x y del tiempo.
// Nivel 2: vertex() tambien inclina la normal, para que cada ola tenga su lado claro y su lado oscuro.

uniform vec3 color_bajo : source_color = vec3(0.106, 0.122, 0.169); // #1B1F2B
uniform float amplitud = 0.1;   // metros que sube la cresta
uniform float longitud = 2.0;   // metros entre cresta y cresta
uniform float periodo = 2.0;    // segundos en repetirse

// La misma cuenta de Onda.altura() en GDScript.
float onda(float x, float t, float a, float l, float p) {
	return a * sin(TAU / l * x - TAU / p * t);
}

// La misma cuenta de Onda.pendiente() en GDScript (la derivada de la onda).
float pendiente(float x, float t, float a, float l, float p) {
	return a * (TAU / l) * cos(TAU / l * x - TAU / p * t);
}

void vertex() {
	float h = onda(VERTEX.x, TIME, amplitud, longitud, periodo);
	VERTEX.y += h;
	float s = pendiente(VERTEX.x, TIME, amplitud, longitud, periodo);
	// Mi malla esta de frente (QuadMesh, mira a +Z): la normal parte de (0, 0, 1).
	NORMAL = normalize(vec3(-s, 0.0, 1.0));
}

void fragment() {
	ALBEDO = color_bajo;
	ROUGHNESS = 0.4;
}
