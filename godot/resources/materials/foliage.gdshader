shader_type spatial;
render_mode cull_disabled;
// Vegetazione: colore per vertice o per istanza (MultiMesh), tinta per istanza,
// leggero ondeggiare dal vento proporzionale all'altezza locale del vertice.

#include "res://resources/materials/noise.gdshaderinc"

instance uniform vec4 tint : source_color = vec4(1.0);
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
	col *= 0.8 + 0.35 * value_noise(world_pos.xz * 1.3 + world_pos.y * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = col * 0.25;
}
