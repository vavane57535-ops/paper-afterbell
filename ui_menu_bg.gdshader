shader_type canvas_item;
// Animated menu background: dark notebook paper at night. Ruled lines and a
// red margin, drifting film grain, faint chalk doodles, a slow light sweep, a
// warm lamp pool that can flicker and a vignette. One quad, one draw call.

uniform vec2 rect_size = vec2(1600.0, 900.0);
// Mouse parallax offset in pixels (script driven, eased).
uniform vec2 parallax = vec2(0.0);
// 0 = survivor night (warm lamp), 1 = Alice (crimson).
uniform float alice = 0.0;
// Lamp intensity (flicker is driven by the script).
uniform float lamp = 1.0;
// Overall motion amount (0 with reduced motion).
uniform float motion = 1.0;
// Extra darkening (settings / forms).
uniform float dim = 0.0;
uniform vec4 accent : source_color = vec4(0.53, 0.79, 0.77, 1.0);
uniform sampler2D doodles : repeat_enable, filter_linear;
uniform sampler2D grain : repeat_enable, filter_linear;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 n = UV;
	float t = TIME * motion;
	// Base: deep ink blue-violet, a little lighter at the top.
	vec3 top = mix(vec3(0.085, 0.095, 0.155), vec3(0.13, 0.05, 0.075), alice);
	vec3 bottom = mix(vec3(0.035, 0.04, 0.065), vec3(0.05, 0.02, 0.03), alice);
	vec3 col = mix(top, bottom, smoothstep(0.0, 1.0, n.y));
	// Notebook ruling (moves slightly with the parallax: far layer).
	vec2 q = p + parallax * 0.35;
	float line_d = abs(fract(q.y / 34.0 + 0.5) - 0.5) * 34.0;
	float ruling = 1.0 - smoothstep(0.4, 1.4, line_d);
	col += vec3(0.16, 0.24, 0.42) * ruling * 0.07 * (1.0 - alice * 0.5);
	// Double red margin.
	float mx = q.x - 46.0;
	float margin = (1.0 - smoothstep(0.5, 1.6, abs(mx))) + (1.0 - smoothstep(0.5, 1.4, abs(mx - 6.0))) * 0.6;
	col += vec3(0.55, 0.1, 0.16) * margin * 0.22;
	// Chalk doodles, drifting very slowly.
	vec2 dq = (p + parallax * 0.6 + vec2(t * 4.0, -t * 1.5)) / 980.0;
	float chalk = texture(doodles, dq).r;
	vec3 chalk_col = mix(vec3(0.75, 0.82, 0.95), vec3(1.0, 0.55, 0.6), alice);
	col += chalk_col * chalk * 0.085;
	// Warm lamp pool, top right (crimson for Alice).
	vec2 lamp_pos = vec2(0.7, -0.08) * rect_size;
	float ld = length((p - lamp_pos) / rect_size.y);
	float pool = exp(-ld * ld * 2.4) * lamp;
	vec3 lamp_col = mix(vec3(1.0, 0.72, 0.42), vec3(0.95, 0.12, 0.2), alice);
	col += lamp_col * pool * 0.16;
	// Cool moonlight from the left edge.
	col += vec3(0.25, 0.35, 0.75) * exp(-n.x * 5.0) * 0.035;
	// Slow diagonal light sweep.
	float sweep_d = dot(n - vec2(0.0, 0.0), normalize(vec2(1.0, 0.45))) - (fract(t / 13.0) * 2.4 - 0.5);
	col += mix(vec3(1.0, 0.85, 0.65), vec3(1.0, 0.3, 0.35), alice) * exp(-sweep_d * sweep_d * 90.0) * 0.035 * motion;
	// Accent glow behind the characters (right side, low).
	vec2 glow_pos = vec2(0.7, 0.72) * rect_size;
	float gd = length((p - glow_pos) / rect_size.y);
	col += accent.rgb * exp(-gd * gd * 3.2) * 0.07;
	// Film grain: stepped offsets so it jitters like projected film.
	float step_t = floor(t * 12.0);
	vec2 goff = vec2(hash(vec2(step_t, 1.0)), hash(vec2(step_t, 7.0))) * 256.0 * motion;
	float g = texture(grain, (p + goff) / 256.0).r;
	col *= 0.93 + 0.1 * g;
	// Vignette + dim.
	vec2 v = n - 0.5;
	float vig = 1.0 - dot(v, v) * 1.25;
	col *= clamp(vig, 0.0, 1.0);
	col *= 1.0 - dim;
	COLOR = vec4(col, 1.0);
}
