shader_type spatial;
// Suolo dell'arena: lastre di piazza e strada spaccate, riconquistate da erba e terra.
// Tutto in coordinate mondo: pezzi diversi del suolo si raccordano senza cuciture, e le
// celle del terreno (terrain_cell.gdshader) leggono la stessa maschera e le stesse tile
// dipinte (restyling 2026-10-11).

#include "res://resources/materials/noise.gdshaderinc"
#include "res://resources/materials/ruins_ground.gdshaderinc"
#include "res://resources/materials/surface_tiles.gdshaderinc"

// Oltre questa distanza dal centro la natura prevale sul costruito.
uniform float plaza_radius = 20.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float road;
	float dirt;
	float green;
	ruins_ground_layers(world_pos.xz, plaza_radius, road, dirt, green);
	vec3 normal_ts;
	vec3 orm;
	vec3 albedo = sample_ground_with_grass(world_pos.xz * tile_scale, ground_layer_from_mask(road, dirt),
		green, road, normal_ts, orm);
	// Leggera variazione di tono a grande scala, come una velatura.
	albedo *= 0.92 + 0.16 * value_noise(world_pos.xz * 0.35);
	ALBEDO = albedo;
	NORMAL_MAP = normal_ts * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.4;
	ROUGHNESS = mix(0.7, 1.0, orm.g);
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.6;
}
