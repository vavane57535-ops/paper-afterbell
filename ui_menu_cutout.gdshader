shader_type canvas_item;
// Ink reveal for the big character art of the play setup: the cut-out is
// "inked in" through a noise mask with a coloured scribble edge, and can
// glitch (RGB split + slice offsets) for Alice.

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform vec4 edge_color : source_color = vec4(0.84, 0.27, 0.36, 1.0);
uniform float glitch = 0.0;
uniform float seed = 0.0;
uniform sampler2D mask : repeat_enable, filter_linear;

// In fragment(), COLOR already holds texture * vertex colour: keep the vertex
// colour (modulate) apart so the texture is not applied twice.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float hash(float x) {
	return fract(sin(x * 91.7 + seed) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec4 base;
	if (glitch > 0.001) {
		// Horizontal slices jump sideways; colour channels split.
		float band = floor(uv.y * 38.0);
		float jump = (hash(band + floor(TIME * 24.0)) - 0.5) * 0.06 * glitch * step(0.72, hash(band * 1.7 + floor(TIME * 18.0)));
		uv.x += jump;
		float split = 0.012 * glitch;
		vec4 c = texture(TEXTURE, uv);
		float r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
		float b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
		float a = max(c.a, max(texture(TEXTURE, uv + vec2(split, 0.0)).a, texture(TEXTURE, uv - vec2(split, 0.0)).a) * 0.6);
		base = vec4(r, c.g, b, a);
	} else {
		base = texture(TEXTURE, uv);
	}
	if (reveal < 0.999) {
		// Noise threshold sweeps bottom-left to top-right with an ink edge.
		float n = texture(mask, UV * vec2(1.6, 2.4)).r * 0.55 + (1.0 - UV.y) * 0.3 + UV.x * 0.15;
		float r = reveal * 1.25 - 0.1;
		float shown = smoothstep(n - 0.03, n, r);
		float edge = smoothstep(n - 0.075, n - 0.03, r) - shown;
		// Ink core with a coloured rim (the rim is the outer, freshest part).
		float rim = smoothstep(n - 0.075, n - 0.05, r) - smoothstep(n - 0.05, n - 0.03, r);
		vec3 ink = mix(vec3(0.04, 0.035, 0.06), edge_color.rgb, clamp(rim * 1.4, 0.0, 1.0));
		base.rgb = mix(base.rgb, ink, clamp(edge * 1.6, 0.0, 1.0));
		base.a *= max(shown, edge * 0.95);
	}
	COLOR = base * tint;
}
