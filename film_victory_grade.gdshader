// 0.16 · Étalonnage plein écran des films de victoire LMS (film_victories.gd).
// Trois « looks » mélangés par film_victories.gd selon le temps du film :
//  - rain : nuit pluvieuse désaturée façon Outcome Memories (bleu froid, noirs
//    écrasés, vignette, pluie en traits, flou de mouvement, aberration) ;
//  - ink  : découpe de papier — tout ce qui n'est pas le fond magenta du
//    plateau des silhouettes devient de l'encre noire posée sur du papier, avec
//    une ombre portée de papier découpé ;
//  - tv   : la vieille télé dans le noir (grain et vignette seulement).
// Le grain, les flashs et le glitch s'appliquent par-dessus.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D paper_tex : repeat_enable, filter_linear_mipmap;

uniform float rain_mix = 0.0;
uniform float ink_mix = 0.0;
uniform float clock = 0.0;
uniform float aspect = 1.6;
uniform int taps = 8;

uniform float exposure = 1.0;
uniform float desaturate = 0.72;
uniform vec4 grade_tint : source_color = vec4(0.70, 0.78, 0.92, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.05, 0.07, 0.11, 1.0);
uniform float contrast = 1.18;
uniform float rain = 0.0;
uniform float rain_slant = 0.16;
uniform float flakes = 0.0;
uniform float rain_burst = 0.0;
uniform vec2 rain_center = vec2(0.5, 0.5);
uniform vec2 smear = vec2(0.0);
uniform float zoom_blur = 0.0;
uniform float aberration = 0.0;

uniform vec4 ink_bg : source_color = vec4(0.95, 0.93, 0.89, 1.0);
uniform vec4 ink_color : source_color = vec4(0.015, 0.012, 0.02, 1.0);
uniform float ink_shadow = 0.22;
uniform float ink_soft = 0.0;

uniform float grain = 0.07;
uniform float vignette = 0.45;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float glitch = 0.0;
uniform float lift = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// 1 on the magenta key of the silhouette stage, 0 on everything else. The key
// is a bright unshaded magenta (about 0.63 on screen): dark purples such as
// Usayuko's hair share its hue but not its brightness and must stay ink.
float keyness(vec3 s) {
	float top = max(s.r, s.b);
	float k = (min(s.r, s.b) - s.g) / max(top, 0.04);
	k *= smoothstep(0.34, 0.5, top);
	k *= 1.0 - smoothstep(0.18, 0.42, abs(s.r - s.b) / max(top, 0.04));
	return smoothstep(0.38, 0.78, k);
}

vec3 fetch(vec2 uv) {
	return textureLod(screen_tex, clamp(uv, vec2(0.001), vec2(0.999)), 0.0).rgb;
}

// Screen colour with motion smear, zoom blur and chromatic aberration.
vec3 blurred(vec2 uv) {
	vec3 sum = vec3(0.0);
	float weight = 0.0;
	vec2 toward = uv - vec2(0.5);
	int count = max(1, taps);
	for (int i = 0; i < 16; i++) {
		if (i >= count) break;
		float f = count > 1 ? float(i) / float(count - 1) - 0.5 : 0.0;
		vec2 offset = smear * f - toward * zoom_blur * (f + 0.5) * 0.18;
		float w = 1.0 - abs(f) * 0.9;
		sum += fetch(uv + offset) * w;
		weight += w;
	}
	vec3 c = sum / max(weight, 0.001);
	if (aberration > 0.0001) {
		vec2 shift = toward * aberration * (0.35 + length(toward));
		c.r = mix(c.r, fetch(uv + shift).r, 0.85);
		c.b = mix(c.b, fetch(uv - shift).b, 0.85);
	}
	return c;
}

// Thin falling streaks in three depths, deterministic in film time.
float rain_streaks(vec2 uv) {
	float total = 0.0;
	for (int layer = 0; layer < 3; layer++) {
		float fl = float(layer);
		float density = mix(38.0 + fl * 34.0, 16.0 + fl * 14.0, flakes);
		float speed = mix(2.6 + fl * 1.1, 0.18 + fl * 0.09, flakes);
		float stretch = mix(1.6 + fl * 1.4, 9.0 + fl * 5.0, flakes);
		vec2 q = uv;
		q.x += flakes * 0.012 * sin(q.y * 9.0 + clock * (1.3 + fl * 0.4) + fl * 2.1);
		// burst: drops thrown away from an impact point
		vec2 away = q - rain_center;
		q -= away * rain_burst * (0.12 + 0.05 * fl);
		vec2 p = vec2((q.x + q.y * rain_slant) * aspect * density, q.y * stretch + clock * speed + fl * 3.17);
		float column = floor(p.x);
		float h = hash12(vec2(column, fl * 13.1));
		if (h < 0.55) continue;
		float lane = abs(fract(p.x) - 0.5);
		float width = mix(0.08 + 0.05 * fl, 0.22 + 0.06 * fl, flakes);
		float head = fract(p.y + h * 7.13);
		float length_on = mix(0.16 + 0.22 * hash12(vec2(column, 5.7 + fl)), 0.05 + 0.03 * hash12(vec2(column, 5.7 + fl)), flakes);
		float body = smoothstep(0.0, length_on * 0.25, head) * (1.0 - smoothstep(length_on * 0.6, length_on, head));
		total += (1.0 - smoothstep(width * 0.4, width, lane)) * body * (0.45 + 0.3 * fl) * (0.6 + 0.4 * h);
	}
	return total;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// glitch: horizontal tearing bands
	if (glitch > 0.0001) {
		float band = floor(uv.y * 38.0 + floor(clock * 30.0) * 7.0);
		float tear = hash12(vec2(band, floor(clock * 24.0)));
		if (tear > 1.0 - glitch * 0.6) uv.x += (tear - 0.5) * 0.12 * glitch;
	}
	vec3 raw = fetch(uv);
	vec3 base = raw;
	vec3 col = base;

	if (rain_mix > 0.001) {
		vec3 c = blurred(uv);
		float l = luma(c);
		c = mix(c, vec3(l), desaturate);
		c *= grade_tint.rgb * exposure;
		c = pow(max(c, vec3(0.0)), vec3(1.32));
		c = (c - 0.32) * contrast + 0.32;
		c = max(c, vec3(0.0));
		c = mix(shadow_tint.rgb, c, smoothstep(-0.05, 0.3, luma(c)) * 0.8 + 0.2);
		float drops = rain_streaks(uv) * rain;
		c += vec3(0.78, 0.84, 0.95) * drops * 0.28;
		col = mix(col, c, rain_mix);
	}

	if (ink_mix > 0.001) {
		vec3 s = ink_soft > 0.001 ? blurred(uv) : raw;
		float key = keyness(s);
		vec2 shadow_uv = uv + vec2(-0.0045, -0.0072);
		float key_shadow = keyness(fetch(shadow_uv));
		float fibers = texture(paper_tex, uv * vec2(aspect, 1.0) * 2.2).r;
		float speck = hash12(floor(uv * vec2(aspect, 1.0) * 420.0));
		vec3 paper = ink_bg.rgb * (0.94 + 0.08 * fibers) - vec3(0.025) * step(0.985, speck);
		paper *= 1.0 - ink_shadow * (1.0 - key_shadow) * key;
		vec3 ink = ink_color.rgb + vec3(0.03) * fibers;
		vec3 c = mix(ink, paper, key);
		col = mix(col, c, ink_mix);
	}

	col = max(col + vec3(lift), vec3(0.0));
	vec2 centred = (uv - 0.5) * vec2(aspect / 1.6, 1.0);
	col *= 1.0 - vignette * smoothstep(0.35, 1.05, length(centred) * 1.25);
	float noise = hash12(floor(uv * vec2(960.0, 600.0)) + vec2(floor(clock * 24.0) * 17.0, 3.0)) - 0.5;
	col += noise * grain * (0.35 + 0.65 * (1.0 - luma(col)));
	col = mix(col, flash_color.rgb, clamp(flash_color.a, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
