shader_type canvas_item;
// Menu pause : la partie figée derrière le menu devient une impression en
// trame (demi-teintes d'encre) teintée de rouge, comme la partie qui se fige
// et vire au rouge à l'ouverture du menu de Persona 5, version papier.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.62, 0.1, 0.17, 1.0);
uniform vec4 ink : source_color = vec4(0.03, 0.03, 0.05, 1.0);
uniform float dot_size = 6.0;
uniform float scroll = 0.0;

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float g = smoothstep(0.03, 0.62, l);
	// Trame inclinée à 45° qui glisse lentement (rien n'est immobile).
	vec2 p = FRAGCOORD.xy + vec2(scroll, scroll * 0.5);
	vec2 r = vec2(p.x + p.y, p.x - p.y) * 0.7071 / dot_size;
	float d = length(fract(r) - 0.5);
	float radius = 0.55 * (1.0 - g) + 0.04;
	float dots = 1.0 - smoothstep(radius - 0.06, radius + 0.06, d);
	vec3 paper = mix(tint.rgb * (0.55 + 0.75 * g), ink.rgb, dots * 0.82);
	// Le passage au rouge commence par un gris dur (comme le gel de l'image).
	vec3 grey = vec3(smoothstep(0.0, 0.8, l));
	float k = clamp(amount * 1.6, 0.0, 1.0);
	vec3 mid = mix(c, grey, clamp(amount * 3.0, 0.0, 1.0));
	vec3 col = mix(mid, paper, smoothstep(0.25, 1.0, amount));
	COLOR = vec4(mix(c, col, k), 1.0);
}
