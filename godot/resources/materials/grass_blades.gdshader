shader_type spatial;
render_mode cull_disabled;
// Lame d'erba (D-068): quad incrociati con la texture delle lame ritagliata
// (alpha scissor, passata opaca), piu scure al piede e chiare in punta, colore
// per istanza dal MultiMesh, stesso vento di foliage.gdshader.

#include "res://resources/materials/noise.gdshaderinc"

uniform sampler2D blade_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float sway = 0.06;
uniform float sway_speed = 1.4;

varying vec3 world_pos;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = TIME * sway_speed + origin.x * 0.35 + origin.z * 0.27;
	float bend = max(VERTEX.y, 0.0) * sway;
	VERTEX.x += sin(phase) * bend;
	VERTEX.z += cos(phase * 0.8) * bend * 0.6;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// UV.y = 0 in punta, 1 al piede.
	ALPHA = texture(blade_texture, UV).a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 col = COLOR.rgb * (0.8 + 0.35 * value_noise(world_pos.xz * 1.3));
	col *= mix(1.15, 0.62, UV.y);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = col * 0.25;
}
