// Screen-space layer of the effects (0.14), drawn under the HUD: speed lines
// streaming in from the borders, inked focus lines on a heavy blow, ink
// spattered on the glass, a coloured vignette for the state of the viewed
// character and one-frame impact tints. fx_screen.gd drives every uniform and
// hides the node when nothing is active.
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float speed = 0.0;
uniform float focus = 0.0;
uniform vec4 focus_color : source_color = vec4(0.06, 0.03, 0.09, 1.0);
uniform vec4 edge : source_color = vec4(0.0);
uniform vec4 flash : source_color = vec4(0.0);
uniform float splat = 0.0;
uniform float splat_seed = 0.0;
uniform float clock = 0.0;
uniform float aspect = 1.78;
uniform float flicker = 14.0;
// 0.15: permanent dread in a round (dark red-black vignette and film grain).
uniform float dread = 0.0;

float hash11(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

// Premultiplied "top over bottom".
vec4 over(vec4 top, vec4 bottom) {
	float a = top.a + bottom.a * (1.0 - top.a);
	vec3 c = (top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a)) / max(a, 0.0001);
	return vec4(c, a);
}

// Wedges pointing at the centre: 0 outside, 1 inside a line.
float lines(float r, float theta, float density, float tick, float inner) {
	float k = theta / 6.2831853 * density;
	float id = floor(k) + tick * 17.0;
	float f = abs(fract(k) - 0.5) * 2.0;
	float on = step(0.5, hash11(id));
	float start = inner + 0.3 * hash11(id + 3.1);
	float along = smoothstep(start, start + 0.4, r);
	float width = mix(0.1, 0.5, hash11(id + 7.7)) * along;
	return (1.0 - smoothstep(width * 0.55, width, f)) * on * along;
}

// Signed distance to one ink blot (a core, satellites and a drip), in aspect-corrected space.
float blot(vec2 q, vec2 centre, float radius, float sd, float run) {
	float d = length(q - centre) - radius;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float a = hash11(sd + fi * 3.7) * 6.2831853;
		vec2 o = vec2(cos(a), sin(a)) * radius * (0.75 + 0.55 * hash11(sd + fi * 5.3));
		d = min(d, length(q - centre - o) - radius * (0.3 + 0.32 * hash11(sd + fi * 9.1)));
	}
	// A drip running down the glass.
	vec2 dq = q - vec2(centre.x + (hash11(sd + 21.0) - 0.5) * radius, centre.y);
	float reach = radius * (0.6 + 2.6 * hash11(sd + 33.0)) * run;
	float drip = max(abs(dq.x) - radius * 0.11, max(-dq.y, dq.y - reach));
	d = min(d, drip);
	d = min(d, length(dq - vec2(0.0, reach)) - radius * 0.16);
	return d;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	vec2 q = vec2(p.x * aspect, p.y);
	float r = length(p);
	float theta = atan(q.y, q.x);
	// State vignette.
	vec4 result = vec4(edge.rgb, edge.a * smoothstep(0.5, 1.3, r));
	// Ink on the glass: blots along the border that run, then fade.
	if (splat > 0.003) {
		float d = 10.0;
		float run = 1.0 - splat * 0.6;
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float sd = splat_seed + fi * 13.0;
			float a = (fi + hash11(sd)) / 5.0 * 6.2831853;
			// Half out of the frame: the ink never covers the action.
			vec2 centre = vec2(cos(a) * aspect, sin(a)) * (0.98 + 0.12 * hash11(sd + 2.0));
			d = min(d, blot(q, centre, 0.05 + 0.06 * hash11(sd + 4.0), sd, run));
		}
		float inside = 1.0 - smoothstep(-0.006, 0.006, d);
		float rim = smoothstep(-0.03, -0.006, d);
		vec3 ink = mix(vec3(0.09, 0.04, 0.12), vec3(0.45, 0.1, 0.22), rim * 0.7);
		result = over(vec4(ink, inside * min(1.0, splat * 2.5) * 0.8), result);
	}
	// Speed lines (pale) and focus lines (inked), re-rolled a few times a second.
	if (speed > 0.003) {
		float tick = floor(clock * flicker);
		float amount = lines(r, theta, 84.0, tick, mix(0.95, 0.55, speed));
		result = over(vec4(vec3(1.0), amount * min(1.0, speed * 1.4) * 0.5), result);
	}
	if (focus > 0.003) {
		float tick = floor(clock * (flicker + 10.0));
		float amount = lines(r, theta, 70.0, tick + 5.0, mix(0.95, 0.6, focus));
		result = over(vec4(focus_color.rgb, amount * min(1.0, focus * 1.6) * 0.82), result);
	}
	// Impact frame.
	if (dread > 0.001) {
		float vig = smoothstep(0.42, 1.45, r);
		result = over(vec4(0.07, 0.0, 0.025, vig * 0.72 * dread), result);
		float g = hash11(dot(floor(UV * vec2(960.0, 540.0)), vec2(1.0, 157.0)) * 0.013 + floor(clock * 24.0) * 3.1);
		result = over(vec4(vec3(g), 0.06 * dread), result);
	}
	result = over(flash, result);
	COLOR = result;
}
