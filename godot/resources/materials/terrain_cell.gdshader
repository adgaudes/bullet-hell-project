shader_type spatial;
// Materiale unico per tutte le celle: il colore e per istanza
// (set_instance_shader_parameter), come i material instance dinamici Unreal.
// Con `natural` = 1 la cella mostra il suolo dell'arena in rovina (sopra) o terra
// (fianchi), tinto dal colore di stato in proporzione a `state_tint`.

#include "res://resources/materials/noise.gdshaderinc"
#include "res://resources/materials/ruins_ground.gdshaderinc"

instance uniform vec4 cell_color : source_color = vec4(1.0);
instance uniform float natural = 0.0;
instance uniform float state_tint = 1.0;
uniform float plaza_radius = 20.4; // = OvergrownArena.play_half_extent * 0.85

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 col = cell_color.rgb;
	if (natural > 0.5) {
		float green;
		vec3 ground = ruins_ground_albedo(world_pos.xz, plaza_radius, green);
		vec3 soil = RG_EARTH * (0.7 + 0.4 * value_noise(world_pos.xy * 3.0 + world_pos.zy * 3.0));
		vec3 base = normalize(world_normal).y > 0.5 ? ground : soil;
		vec3 tinted = mix(base, cell_color.rgb, 0.55) * (0.75 + 0.5 * value_noise(world_pos.xz * 1.5));
		col = mix(base, tinted, state_tint);
	}
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
