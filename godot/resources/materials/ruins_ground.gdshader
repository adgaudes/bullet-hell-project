shader_type spatial;
// Suolo dell'arena: lastre di piazza e strada spaccate, riconquistate da erba e terra.
// Tutto in coordinate mondo: pezzi diversi del suolo si raccordano senza cuciture.

#include "res://resources/materials/noise.gdshaderinc"
#include "res://resources/materials/ruins_ground.gdshaderinc"

// Oltre questa distanza dal centro la natura prevale sul costruito.
uniform float plaza_radius = 20.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float green;
	ALBEDO = ruins_ground_albedo(world_pos.xz, plaza_radius, green);
	ROUGHNESS = mix(0.88, 0.95, green);
}
