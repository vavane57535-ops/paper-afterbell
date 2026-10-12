// 0.16 · Écran de la vieille télé cathodique des films de victoire LMS.
// Neige, lignes de balayage, image du survivant en aplat coloré qui « accroche »
// le signal, lavage rouge du glitch, puis extinction (l'image s'écrase en une
// ligne puis en un point). Piloté par film_victories.gd.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

uniform sampler2D art : source_color, filter_linear_mipmap;
uniform vec4 emblem : source_color = vec4(0.4, 0.5, 1.0, 1.0);
uniform float power = 1.0;
uniform float collapse = 0.0;
uniform float art_amount = 0.0;
uniform float red = 0.0;
uniform float snow = 1.0;
uniform float clock = 0.0;
uniform float energy = 1.35;
uniform float roll = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 cc = UV - 0.5;
	float r2 = dot(cc, cc);
	vec2 uv = 0.5 + cc * (1.0 + 0.16 * r2);
	float frame = floor(clock * 24.0);
	// rolling sync band and line jitter
	float line = floor(uv.y * 150.0);
	float jitter = (hash12(vec2(line, frame)) - 0.5) * 0.012 * (0.4 + snow);
	float band = smoothstep(0.0, 0.08, abs(fract(uv.y * 0.7 - clock * 0.35 - roll) - 0.5) - 0.38);
	uv.x += jitter + band * 0.01;
	float n = hash12(floor(uv * vec2(190.0, 140.0)) + vec2(frame * 3.1, frame * 1.7));
	float n2 = hash12(floor(uv * vec2(95.0, 300.0)) + vec2(frame * 5.3, 2.0));
	vec3 static_col = vec3(0.70 + 0.22 * n) - vec3(0.10) * step(0.92, n2);
	// survivor emblem (bust art, flat tinted, slightly ghosted)
	vec2 art_uv = vec2(0.5 + (uv.x - 0.5) * 1.05 + jitter * 2.0, 0.08 + uv.y * 0.98);
	vec4 a = texture(art, art_uv);
	float in_art = step(0.0, art_uv.x) * step(art_uv.x, 1.0) * step(0.0, art_uv.y) * step(art_uv.y, 1.0);
	float mask = smoothstep(0.35, 0.75, a.a) * in_art;
	float detail = dot(a.rgb, vec3(0.333));
	vec3 tinted = emblem.rgb * (0.62 + 0.55 * detail);
	float ghost = art_amount * (0.78 + 0.22 * hash12(vec2(line, frame + 9.0)));
	vec3 col = mix(static_col, tinted, mask * ghost);
	// scanlines and soft corners
	col *= 0.86 + 0.14 * sin(uv.y * 460.0);
	col *= 1.0 - band * 0.18;
	float corner = smoothstep(0.52, 0.42, max(abs(cc.x) * 1.02, abs(cc.y) * 1.06) + r2 * 0.25);
	// red wash (the glitch before the cut)
	vec3 red_col = vec3(0.95, 0.14, 0.12) * (0.55 + 0.6 * n) * (0.4 + 0.6 * mask * art_amount + 0.4 * (1.0 - mask));
	col = mix(col, red_col, red);
	// switch-off: squash to a line, then to a dot
	float squash_y = mix(0.5, 0.004, smoothstep(0.0, 0.55, collapse));
	float squash_x = mix(0.5, 0.004, smoothstep(0.5, 1.0, collapse));
	float on = (1.0 - smoothstep(squash_y * 0.85, squash_y, abs(cc.y))) * (1.0 - smoothstep(squash_x * 0.85, squash_x, abs(cc.x)));
	float boost = 1.0 + 3.0 * smoothstep(0.2, 0.9, collapse) * (1.0 - smoothstep(0.92, 1.0, collapse));
	vec3 lit = col * on * boost * power * corner;
	vec3 glass = vec3(0.025, 0.03, 0.04) * corner + vec3(0.05) * (1.0 - corner);
	ALBEDO = glass + lit * energy;
}
