shader_type spatial;

// Colgaduras del altar movidas por el viento del atardecer.
// Nivel 1: vertex() sube o baja cada vertice con un seno de x y del tiempo.
// Nivel 2: vertex() tambien inclina la normal (cada ola, su lado claro y su lado oscuro).
// Nivel 3: dos ondas sumadas, y el color sale de la altura (valle oscuro, cresta dorada).

uniform vec3 color_bajo : source_color = vec3(0.106, 0.122, 0.169); // #1B1F2B, el valle
uniform vec3 color_alto : source_color = vec3(0.831, 0.627, 0.090); // #D4A017, la cresta

// Onda principal (el viento grande)
uniform float amplitud = 0.1;   // metros que sube la cresta
uniform float longitud = 2.0;   // metros entre cresta y cresta
uniform float periodo = 2.0;    // segundos en repetirse

// Onda fina (para que no se repita igual): menor amplitud, y longitud y periodo
// que no son multiplos de los de la principal.
uniform float amplitud2 = 0.04;
uniform float longitud2 = 1.3;
uniform float periodo2 = 1.7;

// vertex() le deja a fragment() que tan alto quedo este punto.
varying float altura;

// La misma cuenta de Onda.altura() en GDScript.
float onda(float x, float t, float a, float l, float p) {
	return a * sin(TAU / l * x - TAU / p * t);
}

// La misma cuenta de Onda.pendiente() en GDScript (la derivada de la onda).
float pendiente(float x, float t, float a, float l, float p) {
	return a * (TAU / l) * cos(TAU / l * x - TAU / p * t);
}

void vertex() {
	float h = onda(VERTEX.x, TIME, amplitud, longitud, periodo)
			+ onda(VERTEX.x, TIME, amplitud2, longitud2, periodo2);
	float s = pendiente(VERTEX.x, TIME, amplitud, longitud, periodo)
			+ pendiente(VERTEX.x, TIME, amplitud2, longitud2, periodo2);
	VERTEX.y += h;
	// Mi malla esta de frente (QuadMesh, mira a +Z): la normal parte de (0, 0, 1).
	NORMAL = normalize(vec3(-s, 0.0, 1.0));
	altura = h;
}

void fragment() {
	// h va de -(a1 + a2) a +(a1 + a2): lo llevo a 0..1 (0 = valle, 1 = cresta).
	float m = clamp(altura / (2.0 * (amplitud + amplitud2)) + 0.5, 0.0, 1.0);
	ALBEDO = mix(color_bajo, color_alto, m);
	ROUGHNESS = 0.4;
}
