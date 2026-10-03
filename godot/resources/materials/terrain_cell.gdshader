shader_type spatial;
// Materiale unico per tutte le celle: il colore e per istanza
// (set_instance_shader_parameter), come i material instance dinamici Unreal.

instance uniform vec4 cell_color : source_color = vec4(1.0);

void fragment() {
	ALBEDO = cell_color.rgb;
	ROUGHNESS = 0.8;
}
