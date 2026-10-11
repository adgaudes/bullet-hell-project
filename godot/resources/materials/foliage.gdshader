shader_type spatial;
render_mode cull_disabled;
// Vegetazione: colore per vertice o per istanza (MultiMesh), tinta per istanza,
// leggero ondeggiare dal vento proporzionale all'altezza locale del vertice.
// Con `textured` (restyling 2026-10-11) la superficie e una cartella di foglie dipinte:
// lo strato `leaf_layer` dell'array `plants`, ritagliato con alpha scissor (cespugli,
// chiome). Senza, resta il colore pieno (fiori, rampicanti).

#include "res://resources/materials/noise.gdshaderinc"

instance uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2DArray plants_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform bool textured = false;
uniform float leaf_layer = 1.0;
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
	vec3 col = COLOR.rgb * tint.rgb;
	if (textured) {
		vec4 tex = texture(plants_albedo, vec3(UV, leaf_layer));
		ALPHA = tex.a;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		// La tinta per istanza e scura (LEAF_TINTS): qui modula solo la tonalita,
		// la luminosita viene dalla texture dipinta.
		vec3 hue = tint.rgb / max(max(tint.r, tint.g), max(tint.b, 0.001));
		col = tex.rgb * mix(vec3(1.0), hue, 0.6) * mix(vec3(1.0), COLOR.rgb, 0.5) * 1.15;
	}
	col *= 0.8 + 0.35 * value_noise(world_pos.xz * 1.3 + world_pos.y * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = col * 0.25;
}
