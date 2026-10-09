shader_type spatial;
// Edifici in rovina: facciate a finestre, colature, muschio sui piani orizzontali
// e rampicanti che scendono dal tetto e salgono da terra. Coordinate mondo.

#include "res://resources/materials/noise.gdshaderinc"

instance uniform vec4 base_tint : source_color = vec4(0.66, 0.62, 0.55, 1.0);
// Quota mondo del tetto del blocco: i rampicanti partono da qui.
instance uniform float top_y = 10.0;
// 0 = pulito, 1 = sommerso dal verde.
instance uniform float overgrowth = 0.5;
// 0 = muro pieno, 1 = facciata a finestre.
instance uniform float windows = 1.0;
// Quanto i rampicanti coprono le pareti vicino a tetto e terra: 1 per le torri,
// meno per le rovine basse (tutta la parete e vicina a entrambi e sarebbe solo verde).
instance uniform float vine_reach = 1.0;
// Con `batched` (corone dei muri in MultiMesh, D-068) tinta e verde vengono dal
// colore di istanza: RGB = tinta, A = overgrowth; niente finestre ne rampicanti dall'alto.
uniform bool batched = false;

uniform vec3 moss_a : source_color = vec3(0.15, 0.30, 0.07);
uniform vec3 moss_b : source_color = vec3(0.36, 0.48, 0.12);
uniform vec3 window_dark : source_color = vec3(0.07, 0.07, 0.06);
uniform float floor_height = 3.2;
uniform float bay_width = 2.6;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 instance_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	instance_color = COLOR;
}

void fragment() {
	vec3 n = normalize(world_normal);
	float up = n.y;
	float side = 1.0 - abs(up);
	vec2 uv = abs(n.x) > abs(n.z) ? world_pos.zy : world_pos.xy;
	if (up > 0.5 || up < -0.5) {
		uv = world_pos.xz;
	}

	vec3 tint_rgb = batched ? instance_color.rgb : base_tint.rgb;
	float growth = batched ? instance_color.a : overgrowth;
	float win_amount = batched ? 0.0 : windows;
	float roof_y = batched ? world_pos.y + 100.0 : top_y;
	vec3 col = tint_rgb * (0.78 + 0.32 * fbm(uv * 0.35));
	// Colature verticali.
	col *= 0.86 + 0.18 * value_noise(vec2(uv.x * 2.5, uv.y * 0.15));
	// Crepe sottili sulle pareti e sporco al piede (D-068).
	float crack = 1.0 - smoothstep(0.0, 0.014, abs(fbm(uv * 0.6 + 5.0) - 0.5));
	col *= 1.0 - 0.45 * crack * side;
	col *= mix(mix(0.72, 1.0, smoothstep(0.0, 0.7, world_pos.y)), 1.0, 1.0 - side);

	// Finestre: alcune murate, alcune sfondate (piu scure), nessuna al piano terra pieno.
	vec2 cell = vec2(uv.x / bay_width, uv.y / floor_height);
	vec2 f = fract(cell);
	float hole = step(0.22, f.x) * step(f.x, 0.78) * step(0.28, f.y) * step(f.y, 0.82);
	float frame = step(0.18, f.x) * step(f.x, 0.82) * step(0.25, f.y) * step(f.y, 0.86) - hole;
	float present = step(0.18, hash12(floor(cell) + vec2(3.0, 7.0)));
	float allowed = win_amount * side * step(0.9, world_pos.y);
	float win = hole * present * allowed;
	vec3 window_col = window_dark * (0.8 + 0.6 * hash12(floor(cell)));
	// Cornice e davanzale: il vano sembra incassato invece che dipinto (D-069).
	col = mix(col, col * 0.72, frame * present * allowed);
	col = mix(col, window_col, win);
	// Linea di solaio a ogni piano: la facciata si legge come edificio (D-070).
	float slab_line = step(fract(uv.y / floor_height + 0.04), 0.05) * win_amount * side * step(2.0, world_pos.y);
	col = mix(col, col * 0.78, slab_line);

	// Verde: muschio sopra, rampicanti dall'alto e dal basso sulle pareti.
	float vine_n = fbm(vec2(uv.x * 0.8, uv.y * 0.11));
	// Fili verticali e bordi sfrangiati invece di macchie piatte (D-068).
	float strands = value_noise(vec2(uv.x * 5.0, uv.y * 0.9)) * 0.14 + value_noise(uv * vec2(14.0, 3.0)) * 0.06;
	float from_top = 1.0 - smoothstep(0.0, 9.0, roof_y - world_pos.y);
	float from_ground = 1.0 - smoothstep(0.0, 6.0, world_pos.y);
	float vines = smoothstep(0.62, 0.72, vine_n + strands + growth * 0.35 + (from_top + from_ground) * 0.3 * vine_reach - 0.2);
	float moss_top = smoothstep(0.4, 0.8, up) * smoothstep(0.35, 0.45, fbm(world_pos.xz * 0.4) + growth * 0.3 - (1.0 - vine_reach) * 0.12);
	float green = clamp(max(vines * side * mix(0.4, 1.0, growth), moss_top), 0.0, 1.0);
	vec3 moss = mix(moss_a, moss_b, fbm(world_pos.xz * 0.3 + world_pos.y * 0.15));
	moss *= 0.7 + 0.5 * value_noise(uv * vec2(9.0, 2.5));

	ALBEDO = mix(col, moss, green);
	ROUGHNESS = mix(0.85, 0.95, green);
}
