shader_type spatial;
// Materiale unico per tutte le celle. Con `batched` il colore viene dal MultiMesh
// (COLOR = colore di istanza, INSTANCE_CUSTOM.xy = naturale e tinta di stato);
// altrimenti dagli instance uniform, come per l'anteprima e i material instance Unreal.
// Con `natural` = 1 la cella mostra le tile dipinte del suolo (restyling 2026-10-11):
// sopra lo stesso strato del piano (strada, terra o lastre dalla maschera mondo, erba
// dove il suolo e verde), sui fianchi terra scavata triplanare a strati, sulle cime dei
// terrapieni terra scavata con l'orlo chiaro; le celle Lowered mostrano fango.
// Il colore di stato tinge il tutto in proporzione a `state_tint`.

#include "res://resources/materials/noise.gdshaderinc"
#include "res://resources/materials/ruins_ground.gdshaderinc"
#include "res://resources/materials/surface_tiles.gdshaderinc"

instance uniform vec4 cell_color : source_color = vec4(1.0);
instance uniform float natural = 0.0;
instance uniform float state_tint = 1.0;
uniform bool batched = false;
uniform float plaza_radius = 20.4; // = OvergrownArena.plaza_radius()
// Quota mondo della cima di una cella Raised.
uniform float raised_top = 1.2;
// Passo della griglia in metri (le celle sono allineate all'origine): serve per
// l'orlo di terra sulla cima dei terrapieni (D-069).
uniform float cell_pitch = 2.4;

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
	float rough = 0.8;
	if (is_natural > 0.5) {
		vec3 n = normalize(world_normal);
		bool top_face = n.y > 0.5;
		bool raised_top_face = top_face && world_pos.y > raised_top * 0.5;
		// Lowered usa NATURAL_STATE_TINT 0.85, gli altri stati al massimo 0.75.
		bool lowered = tint_amount > 0.8 && !raised_top_face;
		float road;
		float dirt;
		float green;
		ruins_ground_layers(world_pos.xz, plaza_radius, road, dirt, green);
		vec2 uv = world_pos.xz * tile_scale;
		vec3 base;
		vec3 orm;
		if (top_face) {
			float layer = raised_top_face ? TILE_DUG : (lowered ? TILE_MUD : ground_layer_from_mask(road, dirt));
			vec3 normal_ts;
			float grass_amount = (raised_top_face || lowered) ? 0.0 : green;
			base = sample_ground_with_grass(uv, layer, grass_amount, road, normal_ts, orm);
			base *= 0.92 + 0.16 * value_noise(world_pos.xz * 0.35);
			NORMAL_MAP = normal_ts * 0.5 + 0.5;
			NORMAL_MAP_DEPTH = 0.8;
		} else {
			// Fianchi: terra scavata triplanare, a strati, piu scura verso il piede.
			base = sample_ground_triplanar(world_pos, n, TILE_DUG, orm);
			float strata = fract(world_pos.y * 3.2 + value_noise(world_pos.xz * 0.7) * 1.4);
			base *= 0.82 + 0.22 * smoothstep(0.0, 0.25, strata) * (1.0 - smoothstep(0.75, 1.0, strata));
			base *= mix(0.55, 1.05, smoothstep(0.0, raised_top, world_pos.y));
		}
		if (raised_top_face) {
			// Cima di un terrapieno: orlo chiaro dipinto verso il bordo, un po' piu chiara
			// o scura per cella (D-069).
			vec2 local = fract(world_pos.xz / cell_pitch + 0.5) - 0.5;
			float edge_d = (0.5 - max(abs(local.x), abs(local.y))) * cell_pitch;
			float rim = 1.0 - smoothstep(0.1, 0.45 + 0.15 * value_noise(world_pos.xz * 3.0), edge_d);
			base = mix(base, base * vec3(1.18, 1.10, 0.95), rim * 0.85);
			base *= 0.92 + 0.16 * hash12(floor(world_pos.xz / cell_pitch + 0.5));
		}
		vec3 tinted = mix(base, col, 0.55) * (0.75 + 0.5 * value_noise(world_pos.xz * 1.5));
		col = mix(base, tinted, tint_amount);
		rough = lowered ? 0.35 : mix(0.7, 1.0, orm.g);
		AO = orm.r;
		AO_LIGHT_AFFECT = 0.3;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
