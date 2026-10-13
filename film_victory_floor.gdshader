// 0.16 · Sol en damier sombre sous la vieille télé (films de victoire LMS).
// Carreaux noirs et carreaux bleutés pailletés, éclairés par une flaque de
// lumière autour de la télé ; la couleur glisse vers le rouge pendant le glitch.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 tile_color : source_color = vec4(0.30, 0.48, 0.95, 1.0);
uniform float tile_size = 0.62;
uniform vec2 light_center = vec2(0.0, 1.2);
uniform float light_radius = 4.3;
uniform float brightness = 1.0;
uniform float clock = 0.0;

varying vec3 local_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = local_pos.xz / tile_size;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float checker = mod(cell.x + cell.y, 2.0);
	float grout = 1.0 - smoothstep(0.035, 0.07, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	float glitter = hash12(floor(local_pos.xz * 52.0)) * 0.6 + hash12(cell * 1.7) * 0.4;
	float twinkle = step(0.985, hash12(floor(local_pos.xz * 40.0) + floor(clock * 6.0)));
	float d = length(local_pos.xz - light_center);
	float pool = exp(-(d * d) / (light_radius * light_radius));
	float near = smoothstep(11.5, 1.5, d);
	// fake sheen: brighter where the floor faces the viewer at a grazing angle
	float sheen = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 blue = tile_color.rgb * (0.18 + 0.82 * glitter) * (0.25 + 1.6 * pool) * (0.6 + 0.6 * sheen);
	vec3 dark = vec3(0.012, 0.014, 0.022) + tile_color.rgb * 0.05 * pool;
	vec3 col = mix(dark, blue, checker);
	col += tile_color.rgb * twinkle * checker * pool * 1.5;
	col = mix(col, vec3(0.004), grout * 0.85);
	col *= near * brightness;
	ALBEDO = col;
}
