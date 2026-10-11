// Albedo del suolo dell'arena in rovina, in coordinate mondo (piano XZ).
// Condiviso fra il suolo (ruins_ground.gdshader) e le celle del terreno in modalita
// naturale (terrain_cell.gdshader). Richiede noise.gdshaderinc.
// La formula della copertura verde e replicata in OvergrownArena.ground_cover_at().

const vec3 RG_CONCRETE = vec3(0.60, 0.56, 0.48);
const vec3 RG_ASPHALT = vec3(0.25, 0.24, 0.23);
const vec3 RG_LINE = vec3(0.80, 0.62, 0.16);
const vec3 RG_GRASS_A = vec3(0.19, 0.35, 0.08);
const vec3 RG_GRASS_B = vec3(0.40, 0.49, 0.12);
const vec3 RG_EARTH = vec3(0.44, 0.33, 0.21);
const float RG_SLAB = 3.0;
const float RG_ROAD_HALF = 4.5;

// Maschere del suolo (restyling 2026-10-11): `road` (strada est-ovest), `dirt` (terra al
// posto delle lastre) e `green` (copertura d'erba, stessa formula della copertura
// vegetale). Le leggono ruins_ground.gdshader e terrain_cell.gdshader per scegliere la
// tile dipinta, cosi piano e celle coincidono.
void ruins_ground_layers(vec2 p, float plaza_radius, out float road, out float dirt, out float green) {
	float road_d = abs(p.y);
	road = 1.0 - smoothstep(RG_ROAD_HALF - 0.25, RG_ROAD_HALF + 0.25, road_d);
	float crack = 1.0 - smoothstep(0.0, 0.018, abs(fbm(p * 0.35) - 0.5));
	float edge = smoothstep(plaza_radius * 0.55, plaza_radius * 1.25, length(p));
	float cover = fbm(p * 0.09 + vec2(3.7, 1.3)) + edge * 0.45 - 0.08
		+ (value_noise(p * 2.7) - 0.5) * 0.08;
	green = smoothstep(0.50, 0.56, cover);
	green = max(green, crack * smoothstep(0.32, 0.5, cover));
	dirt = smoothstep(0.42, 0.48, cover) * (1.0 - road);
}

vec3 ruins_ground_albedo(vec2 p, float plaza_radius, out float green) {
	vec2 slab_id = floor(p / RG_SLAB);
	vec2 slab_f = fract(p / RG_SLAB);
	float joint = 1.0 - step(0.035, min(min(slab_f.x, slab_f.y), min(1.0 - slab_f.x, 1.0 - slab_f.y)));
	vec3 paving = RG_CONCRETE * (0.82 + 0.3 * hash12(slab_id)) * (0.9 + 0.2 * value_noise(p * 2.1));

	// Strada est-ovest (z = 0) con mezzeria tratteggiata e sbiadita.
	float road_d = abs(p.y);
	float road = 1.0 - smoothstep(RG_ROAD_HALF - 0.25, RG_ROAD_HALF + 0.25, road_d);
	float dash = step(0.45, fract(p.x / 4.0)) * (1.0 - step(0.13, road_d));
	vec3 road_col = RG_ASPHALT * (0.8 + 0.4 * value_noise(p * 1.3));
	road_col = mix(road_col, RG_LINE, dash * smoothstep(0.35, 0.5, value_noise(p * 0.7)));
	vec3 built = mix(paving, road_col, road);
	built = mix(built, built * 0.55, joint * (1.0 - road));

	float crack = 1.0 - smoothstep(0.0, 0.018, abs(fbm(p * 0.35) - 0.5));

	float edge = smoothstep(plaza_radius * 0.55, plaza_radius * 1.25, length(p));
	float cover = fbm(p * 0.09 + vec2(3.7, 1.3)) + edge * 0.45 - 0.08
		+ (value_noise(p * 2.7) - 0.5) * 0.08;
	green = smoothstep(0.50, 0.56, cover);
	green = max(green, (crack + joint * 0.6) * smoothstep(0.32, 0.5, cover));
	float dirt = smoothstep(0.42, 0.48, cover) * (1.0 - green);

	vec3 grass = mix(RG_GRASS_A, RG_GRASS_B, fbm(p * 0.25 + vec2(8.0)));
	grass *= (0.8 + 0.35 * value_noise(p * 3.0)) * (0.8 + 0.4 * hash12(floor(p * 14.0)));
	vec3 col = mix(built, RG_EARTH * (0.85 + 0.3 * value_noise(p * 1.7)), dirt * 0.8);
	col = mix(col, built * 0.45, crack * (1.0 - green));
	return mix(col, grass, green);
}
