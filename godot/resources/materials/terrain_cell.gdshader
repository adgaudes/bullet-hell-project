shader_type spatial;
// Materiale unico per tutte le celle. Con `batched` il colore viene dal MultiMesh
// (COLOR = colore di istanza, INSTANCE_CUSTOM.xy = naturale e tinta di stato);
// altrimenti dagli instance uniform, come per l'anteprima e i material instance Unreal.
// Con `natural` = 1 la cella mostra il suolo dell'arena in rovina (sopra) o terra
// (fianchi), tinto dal colore di stato in proporzione a `state_tint`.

#include "res://resources/materials/noise.gdshaderinc"
#include "res://resources/materials/ruins_ground.gdshaderinc"

instance uniform vec4 cell_color : source_color = vec4(1.0);
instance uniform float natural = 0.0;
instance uniform float state_tint = 1.0;
uniform bool batched = false;
uniform float plaza_radius = 20.4; // = OvergrownArena.plaza_radius()
// Quota mondo della cima di una cella Raised: da li scende la frangia d'erba.
uniform float raised_top = 1.2;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 instance_custom;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	instance_custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 col = batched ? COLOR.rgb : cell_color.rgb;
	float is_natural = batched ? instance_custom.x : natural;
	float tint_amount = batched ? instance_custom.y : state_tint;
	if (is_natural > 0.5) {
		float green;
		vec3 ground = ruins_ground_albedo(world_pos.xz, plaza_radius, green);
		// Fianchi: terra a strati, sassi, piu scura al piede, con l'erba che deborda dalla cima.
		vec3 n = normalize(world_normal);
		vec2 side_uv = abs(n.x) > abs(n.z) ? world_pos.zy : world_pos.xy;
		vec3 soil = RG_EARTH * (0.7 + 0.4 * value_noise(world_pos.xy * 3.0 + world_pos.zy * 3.0));
		float strata = fract(side_uv.y * 3.2 + value_noise(side_uv * vec2(0.7, 0.2)) * 1.4);
		soil *= 0.82 + 0.22 * smoothstep(0.0, 0.25, strata) * (1.0 - smoothstep(0.75, 1.0, strata));
		float stone = smoothstep(0.80, 0.86, value_noise(side_uv * vec2(4.0, 6.5) + 11.0));
		soil = mix(soil, RG_CONCRETE * (0.7 + 0.3 * hash12(floor(side_uv * 3.0))), stone * 0.8);
		soil *= mix(0.62, 1.0, smoothstep(0.0, 0.45, world_pos.y));
		float fringe_line = raised_top - 0.08 - 0.3 * value_noise(vec2(side_uv.x * 5.0, 3.0));
		float fringe = smoothstep(fringe_line - 0.04, fringe_line + 0.04, world_pos.y) * max(green, 0.35);
		vec3 turf = mix(RG_GRASS_A, RG_GRASS_B, value_noise(side_uv * vec2(6.0, 1.0)));
		soil = mix(soil, turf, fringe * step(raised_top * 0.5, world_pos.y));
		vec3 base = n.y > 0.5 ? ground : soil;
		vec3 tinted = mix(base, col, 0.55) * (0.75 + 0.5 * value_noise(world_pos.xz * 1.5));
		col = mix(base, tinted, tint_amount);
	}
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
