shader_type spatial;
// Convierte el acero gris de la textura del paladín en plata de armadura.
// El dorado, la tela y la piel (colores con tono) se conservan.

uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_enable;
uniform float claridad = 2.4;            // cuánto se aclara el metal
uniform float contraste = 0.7;           // < 1 levanta las zonas oscuras (más plata, menos grafito)
uniform vec3 plata : source_color = vec3(0.82, 0.88, 1.0);
uniform float brillo_propio = 0.25;      // luz propia para que no se apague en la oscuridad
uniform float borde = 0.9;               // brillo en el contorno (como el reflejo de un metal pulido)
uniform float pulido = 0.6;              // 0 = mate, 1 = muy brillante

void fragment() {
	vec3 c = texture(textura, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float tono = (mx - mn) / (mx + 0.0001);              // 0 = gris puro
	float es_metal = 1.0 - smoothstep(0.12, 0.35, tono);  // 1 en el acero, 0 en dorado, tela y piel
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 acero = plata * pow(clamp(l * 3.0, 0.0, 1.0), contraste) * claridad * 0.45;
	vec3 resto = c * claridad;
	vec3 base = mix(resto, acero, es_metal);
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	base += plata * f * borde * es_metal;
	ALBEDO = base;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.8, 0.3, pulido * es_metal);
	SPECULAR = mix(0.5, 1.0, pulido * es_metal);
	EMISSION = base * brillo_propio;
}
