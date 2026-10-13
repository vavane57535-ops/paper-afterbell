shader_type spatial;
// Character toon surface (Paper Afterbell).
// - Crisp 2-3 light bands with derivative-based anti-aliasing, no per-light floor:
//   ambient + a small per-character fill keep the shadow side readable.
// - Double-sided (the supplied meshes have open hems/sleeves); Godot flips the
//   normal of back faces itself when cull is disabled.
// - Minification is clamped (max_lod) so the unpadded texture atlas does not
//   bleed colour seams at distance.
render_mode cull_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool textured = false;
uniform bool use_vertex_color = false;
// Highest mip level used for the texture atlas (2048 px atlas: 3.0 = 256 px level).
uniform float max_lod = 3.0;
// Light bands on N.L (omni/spot) or N.L * shadow (directional).
uniform float band_low : hint_range(0.0, 1.0) = 0.035;
uniform float band_high : hint_range(0.0, 1.0) = 0.44;
uniform float band_mid : hint_range(0.0, 1.0) = 0.5;
// Hue of the half-lit band (ink-violet by default).
uniform vec4 shade_tint : source_color = vec4(0.66, 0.6, 0.9, 1.0);
// Constant fill so characters never turn pitch black in dark maps.
uniform vec4 fill_color : source_color = vec4(0.46, 0.44, 0.66, 1.0);
uniform float fill_energy = 0.16;
// Light-aware rim on the silhouette side that faces each light.
uniform float rim_amount = 0.28;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
// Optional hard specular (0 = off).
uniform float spec_amount = 0.0;
uniform float spec_size : hint_range(0.0, 1.0) = 0.08;
uniform vec4 glow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_energy = 0.0;

varying float band_aa;

void fragment() {
	vec3 base = albedo_color.rgb;
	if (textured) {
		vec2 size = vec2(textureSize(albedo_tex, 0));
		vec2 uv_dx = dFdx(UV);
		vec2 uv_dy = dFdy(UV);
		float rho2 = max(dot(uv_dx * size, uv_dx * size), dot(uv_dy * size, uv_dy * size));
		// Shrink the gradients so the sampled mip never exceeds max_lod (keeps anisotropy).
		float shrink = min(1.0, exp2(max_lod) / sqrt(max(rho2, 1e-8)));
		base *= textureGrad(albedo_tex, UV, uv_dx * shrink, uv_dy * shrink).rgb;
	}
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	ALBEDO = base;
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = glow_color.rgb * glow_energy + base * fill_color.rgb * fill_energy;
	// Screen-space change of the normal: used as the band anti-aliasing width.
	band_aa = clamp(length(fwidth(NORMAL)) * 0.5, 0.012, 0.2);
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float lambert = max(n_dot_l, 0.0);
	float energy = ATTENUATION;
	float value = lambert;
	if (LIGHT_IS_DIRECTIONAL) {
		// Moon/sun: the shadow term is banded too, giving crisp cast shadows.
		value = lambert * ATTENUATION;
		energy = 1.0;
	}
	float low = smoothstep(band_low - band_aa, band_low + band_aa, value);
	float high = smoothstep(band_high - band_aa, band_high + band_aa, value);
	vec3 ramp = mix(vec3(0.0), band_mid * shade_tint.rgb, low);
	ramp = mix(ramp, vec3(1.0), high);
	DIFFUSE_LIGHT += LIGHT_COLOR * energy * ramp / PI;
	float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = 1.0 - n_dot_v;
	float rim = smoothstep(1.0 - rim_width - band_aa, 1.0 - rim_width + band_aa, edge);
	rim *= smoothstep(0.0, 0.25, n_dot_l) * low;
	SPECULAR_LIGHT += LIGHT_COLOR * energy * rim * rim_amount / PI;
	if (spec_amount > 0.0) {
		vec3 half_vector = normalize(LIGHT + VIEW);
		float blinn = pow(max(dot(NORMAL, half_vector), 0.0), 48.0);
		float hot = smoothstep(1.0 - spec_size - band_aa, 1.0 - spec_size + band_aa, blinn) * high;
		SPECULAR_LIGHT += LIGHT_COLOR * energy * hot * spec_amount / PI;
	}
}
