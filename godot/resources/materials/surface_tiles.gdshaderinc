// Tile dipinte del mondo (restyling 2026-10-11, build_surface_tiles.py): array a strati
// campionati in spazio mondo, cosi piano del suolo e celle del terreno si raccordano.
// Strati di `ground`: 0 terra, 1 lastre, 2 asfalto, 3 terra scavata, 4 fango, 5 erba.
// Chi include questo file deve ricevere le tre texture da TerrainGrid.apply_ground_tiles().

uniform sampler2DArray ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray ground_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Ripetizioni per metro: 0,25 = una tile ogni 4 m.
uniform float tile_scale = 0.25;

const float TILE_DIRT = 0.0;
const float TILE_SLABS = 1.0;
const float TILE_ASPHALT = 2.0;
const float TILE_DUG = 3.0;
const float TILE_MUD = 4.0;
const float TILE_GRASS = 5.0;

// Strato del suolo dalle maschere di ruins_ground_layers(): strada > terra > lastre.
float ground_layer_from_mask(float road, float dirt) {
	if (road > 0.5) {
		return TILE_ASPHALT;
	}
	return dirt > 0.5 ? TILE_DIRT : TILE_SLABS;
}

void sample_ground(vec2 uv, float layer, out vec3 albedo, out vec3 normal_ts, out vec3 orm) {
	albedo = texture(ground_albedo, vec3(uv, layer)).rgb;
	normal_ts = texture(ground_normal, vec3(uv, layer)).rgb * 2.0 - 1.0;
	orm = texture(ground_orm, vec3(uv, layer)).rgb;
}

// Triplanare per i fianchi dei terrapieni: pesa i tre assi con la normale.
vec3 sample_ground_triplanar(vec3 p, vec3 n, float layer, out vec3 orm) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 ax = texture(ground_albedo, vec3(p.zy * tile_scale, layer)).rgb;
	vec3 ay = texture(ground_albedo, vec3(p.xz * tile_scale, layer)).rgb;
	vec3 az = texture(ground_albedo, vec3(p.xy * tile_scale, layer)).rgb;
	vec3 ox = texture(ground_orm, vec3(p.zy * tile_scale, layer)).rgb;
	vec3 oy = texture(ground_orm, vec3(p.xz * tile_scale, layer)).rgb;
	vec3 oz = texture(ground_orm, vec3(p.xy * tile_scale, layer)).rgb;
	orm = ox * w.x + oy * w.y + oz * w.z;
	return ax * w.x + ay * w.y + az * w.z;
}

// Suolo con l'erba dipinta sopra dove `green` lo chiede (mai sull'asfalto): campiona la
// tile di base e la tile d'erba e le fonde; restituisce anche normal e ORM fusi.
vec3 sample_ground_with_grass(vec2 uv, float layer, float green, float road, out vec3 normal_ts, out vec3 orm) {
	vec3 albedo;
	sample_ground(uv, layer, albedo, normal_ts, orm);
	float g = green * (1.0 - road);
	if (g > 0.001) {
		vec3 grass_albedo;
		vec3 grass_normal;
		vec3 grass_orm;
		sample_ground(uv, TILE_GRASS, grass_albedo, grass_normal, grass_orm);
		albedo = mix(albedo, grass_albedo, g);
		normal_ts = normalize(mix(normal_ts, grass_normal, g));
		orm = mix(orm, grass_orm, g);
	}
	return albedo;
}
