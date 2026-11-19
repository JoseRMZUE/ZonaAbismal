shader_type spatial;
// Destello del golpe (Taller 5, Tarea B): se pone ENCIMA del material del
// modelo (material_overlay), así no se pierden sus texturas ni su normal map.
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

// El color del destello y cuánto se ve (0 = nada, 1 = todo el color).
uniform vec4 color_flash : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float intensidad : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Los bordes de la silueta brillan un poco más que el centro.
	float borde = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = color_flash.rgb;
	ALPHA = intensidad * mix(0.55, 1.0, borde);
}