shader_type spatial;
render_mode cull_disabled;
// Lame d'erba (D-068, restyling 2026-10-11): quad incrociati con i ciuffi dipinti dello
// strato 0 dell'array `plants` (tre colonne di ciuffi diversi, scelte dall'id di istanza),
// ritagliati con alpha scissor (passata opaca), colore per istanza dal MultiMesh, stesso
// vento di foliage.gdshader.

#include "res://resources/materials/noise.gdshaderinc"

uniform sampler2DArray plants_albedo : source_color, filter_linear_mipmap, repeat_disable;
// Colonne di varianti nello strato dei ciuffi.
uniform float variant_columns = 3.0;
uniform float sway = 0.06;
uniform float sway_speed = 1.4;

varying vec3 world_pos;
varying float variant;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	variant = float(INSTANCE_ID % 3);
	float phase = TIME * sway_speed + origin.x * 0.35 + origin.z * 0.27;
	float bend = max(VERTEX.y, 0.0) * sway;
	VERTEX.x += sin(phase) * bend;
	VERTEX.z += cos(phase * 0.8) * bend * 0.6;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// UV.y = 0 in punta, 1 al piede; la tile ha la punta in alto.
	vec2 uv = vec2((UV.x + variant) / variant_columns, UV.y);
	vec4 tex = texture(plants_albedo, vec3(uv, 0.0));
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Il colore di istanza e scuro (LEAF_TINTS): modula solo la tonalita.
	vec3 hue = COLOR.rgb / max(max(COLOR.r, COLOR.g), max(COLOR.b, 0.001));
	vec3 col = tex.rgb * mix(vec3(1.0), hue, 0.6) * 1.1 * (0.85 + 0.3 * value_noise(world_pos.xz * 1.3));
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = col * 0.3;
}
