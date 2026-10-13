shader_type spatial;
render_mode specular_disabled;

uniform vec4 paper_color : source_color = vec4(1.0);
uniform sampler2D paper_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool textured = false;
uniform bool use_vertex_color = false;
uniform vec3 glow_color : source_color = vec3(0.0);
uniform float glow_energy = 0.0;
uniform float ink_shadow = 0.22;
uniform float rim_amount = 0.08;

void fragment() {
	vec3 base = paper_color.rgb;
	if (textured) base *= texture(paper_texture, UV).rgb;
	if (use_vertex_color) base *= COLOR.rgb;
	ALBEDO = base;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
	EMISSION = glow_color * glow_energy;
}

void light() {
	float lambert = max(dot(NORMAL, LIGHT), 0.0);
	// Three broad values, with softened borders so moving lamps do not shimmer.
	float band = ink_shadow + 0.36 * smoothstep(0.22, 0.28, lambert);
	band += 0.42 * smoothstep(0.64, 0.70, lambert);
	float rim = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0) * rim_amount;
	DIFFUSE_LIGHT += (band + rim) * ATTENUATION * LIGHT_COLOR / PI;
}
