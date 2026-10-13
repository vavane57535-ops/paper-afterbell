shader_type canvas_item;
// Composition des scènes de survol de l'écran titre (ui_menu_vignettes.gd).
// Le décor est rendu à part (bg, demi-résolution) puis flouté : faux flou de profondeur,
// le rendu Compatibility n'ayant pas de DoF. Les personnages (fg, fond transparent,
// couleurs prémultipliées) passent nets par-dessus. Étalonnage, grain, fondu au noir,
// éclair, puis masque doux qui laisse voir la bande d'encre du menu à gauche.
render_mode unshaded, blend_premul_alpha;

uniform sampler2D fg_tex : filter_linear, repeat_disable;
uniform sampler2D bg_tex : filter_linear, repeat_disable;
uniform bool has_bg = false;
uniform vec2 fg_px = vec2(0.001);
uniform vec2 bg_px = vec2(0.002);
// Rayons de flou en pixels de la texture concernée.
uniform float bg_blur = 1.5;
// Le haut de l'image est en général plus loin (murs du fond) : flou multiplié.
uniform float bg_blur_top = 1.4;
uniform float fg_blur = 0.0;
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
uniform bool masked = false;
// Bord gauche du masque (UV de la vignette) : u en haut, u en bas.
uniform vec2 edge_u = vec2(0.2, 0.05);
uniform float edge_soft = 0.14;
uniform float top_soft = 0.12;
uniform float bottom_soft = 0.06;
uniform float right_soft = 0.025;

const vec2 TAPS[12] = vec2[](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598)
);

vec4 blurred(sampler2D tex, vec2 uv, vec2 px, float radius) {
	vec4 center = texture(tex, uv);
	if (radius < 0.3) return center;
	vec4 sum = center * 1.5;
	float total = 1.5;
	for (int i = 0; i < 12; i++) {
		sum += texture(tex, uv + TAPS[i] * px * radius);
		total += 1.0;
	}
	return sum / total;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float wobble(float y) {
	// Bord légèrement irrégulier, façon papier déchiré très doux.
	return sin(y * 23.0) * 0.006 + sin(y * 61.0 + 1.3) * 0.004 + sin(y * 7.0 + 0.4) * 0.008;
}

void fragment() {
	vec2 uv = UV;
	vec4 fg = blurred(fg_tex, uv, fg_px, fg_blur);
	vec3 color;
	float alpha;
	if (has_bg) {
		float radius = bg_blur * mix(1.0, bg_blur_top, smoothstep(0.85, 0.1, uv.y));
		vec4 bg = blurred(bg_tex, uv, bg_px, radius);
		color = bg.rgb * (1.0 - fg.a) + fg.rgb;
		alpha = max(bg.a, fg.a);
		// Étalonnage (couleurs non prémultipliées : le décor est opaque).
		float luma = dot(color, vec3(0.299, 0.587, 0.114));
		color = mix(vec3(luma), color, saturation);
		color = (color - 0.5) * contrast + 0.5;
		color = lift + color * (gain - lift);
		vec2 centered = uv - vec2(0.56, 0.5);
		color *= 1.0 - vignette_amount * smoothstep(0.25, 0.85, length(centered * vec2(1.0, 1.15)));
		color += (hash(uv * 911.0 + fract(time * 7.13)) - 0.5) * grain;
		color = max(color, vec3(0.0));
	} else {
		color = fg.rgb;
		alpha = fg.a;
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
	float out_alpha = clamp(alpha * mask * fade, 0.0, 1.0);
	// Sortie prémultipliée : sans décor, la couleur de fg l'est déjà.
	if (has_bg) COLOR = vec4(color * out_alpha, out_alpha);
	else COLOR = vec4(color * mask * fade, out_alpha);
}
