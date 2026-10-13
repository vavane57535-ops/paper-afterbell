shader_type canvas_item;
// Composition des scènes de survol de l'écran titre (ui_menu_vignettes.gd).
// Le rendu Compatibility n'a pas de flou de profondeur : la mise au point est simulée à
// l'écran. Net autour du sujet (focus_uv, ellipse focus_radius), de plus en plus flou
// vers les bords et vers le haut de l'image (le fond du décor). La scène règle le point
// de mise au point plan par plan (bascule de point d'un personnage à l'autre).
// Puis étalonnage, grain, fondu au noir, éclair et masque doux qui laisse voir la bande
// d'encre du menu à gauche. Sortie en alpha prémultiplié (le fond de la vue est transparent).
render_mode unshaded, blend_premul_alpha;

uniform sampler2D scene_tex : filter_linear, repeat_disable;
uniform vec2 px = vec2(0.001);
uniform bool styled = true;
uniform vec2 focus_uv = vec2(0.56, 0.5);
uniform float focus_radius = 0.3;
uniform float blur_max = 2.5;
uniform float blur_top = 1.0;
uniform float fade = 1.0;
uniform float dip = 0.0;
uniform float flash = 0.0;
uniform vec3 lift = vec3(0.0);
uniform vec3 gain = vec3(1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float vignette_amount = 0.0;
uniform float grain = 0.0;
uniform float time = 0.0;
uniform float aspect = 1.0;
uniform bool masked = false;
// Bord gauche du masque (UV de la vignette) : u en haut, u en bas.
uniform vec2 edge_u = vec2(0.2, 0.05);
uniform float edge_soft = 0.14;
uniform float top_soft = 0.12;
uniform float bottom_soft = 0.05;
uniform float right_soft = 0.02;

const vec2 TAPS[16] = vec2[](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598),
	vec2(-0.150, 0.150), vec2(0.250, 0.300), vec2(0.100, -0.300), vec2(-0.420, 0.050)
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float wobble(float y) {
	// Bord légèrement irrégulier, façon papier déchiré très doux.
	return sin(y * 23.0) * 0.006 + sin(y * 61.0 + 1.3) * 0.004 + sin(y * 7.0 + 0.4) * 0.008;
}

void fragment() {
	vec2 uv = UV;
	vec4 sharp = texture(scene_tex, uv);
	vec4 col = sharp;
	if (styled && blur_max > 0.05) {
		vec2 d = (uv - focus_uv) * vec2(aspect, 1.0);
		float away = smoothstep(focus_radius, focus_radius * 1.9 + 0.12, length(d));
		float upper = smoothstep(0.55, 0.0, uv.y) * blur_top;
		float radius = blur_max * clamp(away + upper * (0.4 + 0.6 * away), 0.0, 1.0);
		if (radius > 0.35) {
			float spin = hash(uv * 517.0) * 6.2831;
			mat2 turn = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin)));
			vec4 sum = sharp;
			for (int i = 0; i < 16; i++) sum += texture(scene_tex, uv + turn * TAPS[i] * px * radius);
			col = sum / 17.0;
		}
	}
	float alpha = col.a;
	vec3 color = col.rgb;
	if (styled) {
		// Étalonnage sur la couleur non prémultipliée.
		vec3 straight = alpha > 0.001 ? color / alpha : vec3(0.0);
		float luma = dot(straight, vec3(0.299, 0.587, 0.114));
		straight = mix(vec3(luma), straight, saturation);
		straight = (straight - 0.5) * contrast + 0.5;
		straight = lift + straight * (gain - lift);
		vec2 centered = (uv - vec2(0.58, 0.5)) * vec2(aspect, 1.0);
		straight *= 1.0 - vignette_amount * smoothstep(0.3, 0.95, length(centered));
		straight += (hash(uv * 911.0 + fract(time * 7.13)) - 0.5) * grain;
		straight = max(straight, vec3(0.0));
		color = straight * alpha;
	}
	color *= 1.0 - dip;
	color = mix(color, vec3(alpha), flash);
	float mask = 1.0;
	if (masked) {
		float line = mix(edge_u.x, edge_u.y, uv.y) + wobble(uv.y);
		mask = smoothstep(line, line + edge_soft, uv.x);
		mask *= smoothstep(0.0, top_soft, uv.y + wobble(uv.x + 3.0) * 0.5);
		mask *= smoothstep(1.0, 1.0 - bottom_soft, uv.y);
		mask *= smoothstep(1.0, 1.0 - right_soft, uv.x);
	}
	float k = clamp(mask * fade, 0.0, 1.0);
	COLOR = vec4(color * k, clamp(alpha * k, 0.0, 1.0));
}
