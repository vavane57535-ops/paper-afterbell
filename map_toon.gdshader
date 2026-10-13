shader_type spatial;
// Toon shading for map architecture and props ("night at a paper school").
// Colour and paper grain are sampled in world space, so texel density no longer depends
// on the size of each box. Light is split into two crisp bands on max(N.L, 0) * attenuation
// with no per-light floor: the fill comes from the (blue-violet) ambient light.
// The double-sided variant is generated at runtime by PaperToon (cull_back -> cull_disabled).
render_mode specular_disabled, cull_back;

uniform vec4 paper_color : source_color = vec4(1.0);
uniform bool textured = false;
uniform sampler2D paper_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Texture repeats per metre.
uniform float texture_scale = 0.25;
uniform float grain = 1.0;
uniform bool use_vertex_color = false;
uniform vec3 glow_color : source_color = vec3(0.0);
uniform float glow_energy = 0.0;

// Band thresholds for lamps (omni: attenuation includes the distance falloff) and the moon.
uniform float band_low = 0.03;
uniform float band_high = 0.12;
uniform float sun_band_low = 0.05;
uniform float sun_band_high = 0.34;
// Brightness of the first band, and the warm tint of that half-lit band for lamps.
uniform float band_mid = 0.55;
uniform vec3 half_tone : source_color = vec3(1.0, 0.95, 0.84);
// Scales how far lamp pools reach on this surface (ceilings right above lamps use less).
uniform float light_gain = 1.0;
// Cap of one light's contribution: strong character/stage/flash lights (energy 4-8, tuned
// for physical falloff) would otherwise paint flat over-exposed pools on the map.
uniform float light_clamp = 1.25;
// Light-aware rim on vertical faces only (floors seen at grazing angles stay clean).
uniform float rim_amount = 0.06;
// Face shading baked into the albedo so boxes keep their volume in pure ambient light.
uniform float face_contrast = 0.12;

// Contact darkening at the base of vertical faces (fake ambient occlusion).
uniform float base_shade = 0.3;
uniform float base_height = 1.25;
// Per-object brightness variation (seed stored in UV2.y by the static batcher).
uniform float variation = 0.08;

// Large-scale colour patches (forest floor, snow drifts).
uniform float macro_scale = 0.0;
uniform vec3 macro_tint = vec3(1.0);

// Procedural floor grid (replaces the thin grid boxes of the school).
uniform float grid_spacing = 0.0;
uniform float grid_width = 0.05;
uniform vec4 grid_color : source_color = vec4(0.1, 0.1, 0.13, 0.55);
uniform float grid_level = 0.0;

// Per-zone floor tint map (rgb = tint, a = strength), covering zone_rect (x, z, width, depth).
uniform bool zoned = false;
uniform sampler2D zone_map : source_color, filter_linear, repeat_disable;
uniform vec4 zone_rect = vec4(0.0, 0.0, 1.0, 1.0);

varying vec2 contact;

void vertex() {
	// The static batcher stores (base height + 1000, seed) in UV2; other meshes read (0, 0).
	contact = UV2.x > 500.0 ? vec2(UV2.x - 1000.0, UV2.y) : vec2(0.0, 0.5);
}

float grid_lines(vec2 p) {
	vec2 coord = p / grid_spacing;
	vec2 fw = max(fwidth(coord), vec2(1e-5));
	vec2 width = vec2(grid_width / grid_spacing);
	vec2 drawn = max(width, fw);
	vec2 distance_to_line = abs(fract(coord + 0.5) - 0.5) * 2.0;
	vec2 line = 1.0 - smoothstep(drawn - fw, drawn + fw, distance_to_line);
	// Lines thinner than a pixel fade to their coverage instead of shimmering.
	line *= clamp(width / drawn, 0.0, 1.0);
	line = mix(line, width, clamp(fw * 2.5 - 1.0, 0.0, 1.0));
	return max(line.x, line.y);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 axis = abs(world_normal);
	bool facing_up = axis.y > 0.7 && world_normal.y > 0.0;
	vec3 base = paper_color.rgb;
	if (zoned && facing_up) {
		vec4 tint = texture(zone_map, (world_pos.xz - zone_rect.xy) / zone_rect.zw);
		base = mix(base, tint.rgb, tint.a);
	}
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	if (textured) {
		vec2 uv = axis.y >= max(axis.x, axis.z) ? world_pos.xz : (axis.x >= axis.z ? world_pos.zy : world_pos.xy);
		base *= mix(vec3(1.0), texture(paper_texture, uv * texture_scale).rgb, grain);
		if (macro_scale > 0.0) {
			float patch = texture(paper_texture, world_pos.xz * macro_scale).r;
			base = mix(base, base * macro_tint, smoothstep(0.87, 0.97, patch));
		}
	}
	if (facing_up && grid_spacing > 0.0 && abs(world_pos.y - grid_level) < 0.25) {
		base = mix(base, grid_color.rgb, grid_lines(world_pos.xz) * grid_color.a);
	}
	base *= 1.0 + (contact.y - 0.5) * variation;
	float face = 1.0 - face_contrast * (0.5 - 0.5 * world_normal.y) - face_contrast * 0.35 * axis.x;
	float vertical = 1.0 - axis.y;
	float ground = smoothstep(0.0, base_height, world_pos.y - contact.x);
	float occlusion = 1.0 - base_shade * vertical * (1.0 - ground);
	ALBEDO = base * face * occlusion;
	ROUGHNESS = 1.0;
	EMISSION = glow_color * glow_energy;
}

void light() {
	float lit = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * (LIGHT_IS_DIRECTIONAL ? 1.0 : light_gain);
	float low = LIGHT_IS_DIRECTIONAL ? sun_band_low : band_low;
	float high = LIGHT_IS_DIRECTIONAL ? sun_band_high : band_high;
	float aa = fwidth(lit) * 0.8 + 0.0015;
	float first = smoothstep(low - aa, low + aa, lit);
	float second = smoothstep(high - aa, high + aa, lit);
	vec3 tone = LIGHT_IS_DIRECTIONAL ? vec3(1.0) : mix(half_tone, vec3(1.0), second);
	float value = first * band_mid + second * (1.0 - band_mid);
	float rim = 0.0;
	if (rim_amount > 0.0) {
		float upright = 1.0 - abs((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
		rim = smoothstep(0.66, 0.72, 1.0 - max(dot(NORMAL, VIEW), 0.0)) * first * upright * rim_amount;
	}
	DIFFUSE_LIGHT += min(LIGHT_COLOR / PI * (value * tone + rim), vec3(light_clamp));
}
