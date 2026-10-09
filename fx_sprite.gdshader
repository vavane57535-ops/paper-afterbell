// Camera-facing procedural sprites for combat feedback. One QuadMesh + one
// material per blend variant; the look is chosen per instance:
// 0 glow, 1 claw streaks, 2 paper star, 3 shield, 4 paper sheet (fold),
// 5 draining arc, 6 ink splat.
// effects.gd derives a blend_mix variant and a no-depth-test variant from this
// code at runtime (string replace of the render_mode line).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;

instance uniform vec4 color : source_color = vec4(1.0);
instance uniform float progress = 0.0;
instance uniform float angle = 0.0;
instance uniform float seed = 0.0;
instance uniform int shape = 0;

void vertex() {
	// Billboard that keeps the node scale (same as BILLBOARD_ENABLED + keep scale).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

float streak(vec2 p, float offset, float along_limit, float width) {
	// Distance to a segment along +y, tapered at both ends.
	vec2 q = vec2(p.x - offset, p.y);
	float t = clamp(q.y / along_limit, -1.0, 1.0);
	float taper = 1.0 - t * t;
	float d = abs(q.x) - width * taper;
	float ends = abs(q.y) - along_limit;
	return max(d, ends);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float c = cos(angle);
	float s = sin(angle);
	p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	float r = length(p);
	float theta = atan(p.y, p.x);
	float aa = max(fwidth(r), 0.002);
	float a = 0.0;
	vec3 tint = color.rgb;
	if (shape == 0) {
		// Soft glow with a hotter core.
		float fall = clamp(1.0 - r, 0.0, 1.0);
		a = fall * fall * (0.6 + 0.4 * fall);
		tint = mix(color.rgb, vec3(1.0), fall * fall * 0.35);
	} else if (shape == 1) {
		// Three claw streaks wiping in along their length, then thinning out.
		vec2 q = vec2(p.x * 0.94 + p.y * 0.34, -p.x * 0.34 + p.y * 0.94);
		float reveal = clamp(progress * 1.8, 0.0, 1.0);
		float thin = 1.0 - smoothstep(0.45, 1.0, progress);
		float best = 10.0;
		for (int i = -1; i <= 1; i++) {
			float offset = float(i) * 0.3;
			float length_scale = 0.8 - abs(float(i)) * 0.12;
			float d = streak(q, offset, length_scale, 0.07 * thin + 0.012);
			// Only the part already swept by the claw is drawn.
			float head = -length_scale + 2.0 * length_scale * reveal;
			d = max(d, q.y - head);
			best = min(best, d);
		}
		float daa = max(fwidth(best), 0.002);
		a = 1.0 - smoothstep(-daa, daa, best);
		float core = 1.0 - smoothstep(-0.05, 0.0, best);
		tint = mix(color.rgb, vec3(1.0, 0.93, 0.95), core * 0.55);
	} else if (shape == 2) {
		// Five-point paper star with a dark ink rim.
		float wave = pow(abs(cos(theta * 2.5 + seed)), 2.2);
		float boundary = 0.46 + 0.44 * wave;
		float inside = 1.0 - smoothstep(boundary - aa * 1.5, boundary + aa * 1.5, r);
		float rim = smoothstep(boundary - 0.16, boundary - 0.08, r);
		a = inside;
		tint = mix(color.rgb, color.rgb * 0.28, rim * 0.85);
	} else if (shape == 3) {
		// Hexagonal shield outline that grows with progress.
		float hex = max(abs(p.y), abs(p.x) * 0.866 + abs(p.y) * 0.5);
		float size = mix(0.55, 0.92, clamp(progress * 2.0, 0.0, 1.0));
		float haa = max(fwidth(hex), 0.002);
		float band = (1.0 - smoothstep(size - haa, size + haa, hex)) * smoothstep(size - 0.1 - haa, size - 0.1 + haa, hex);
		float body = (1.0 - smoothstep(size - haa, size + haa, hex)) * 0.22;
		a = max(band, body);
		tint = mix(color.rgb, vec3(1.0), band * 0.3);
	} else if (shape == 4) {
		// A sheet of paper folding along its crease (progress 0 flat -> 1 folded).
		float fold = clamp(progress, 0.0, 1.0);
		float half_width = 0.62 * (1.0 - fold * 0.92);
		float inside = (1.0 - smoothstep(half_width - aa, half_width + aa, abs(p.x))) * (1.0 - smoothstep(0.82 - aa, 0.82 + aa, abs(p.y)));
		float crease = 1.0 - smoothstep(0.0, 0.03 + aa, abs(p.x));
		float shade = 0.82 + 0.18 * sign(p.x) * (1.0 - fold * 2.0);
		a = inside;
		tint = color.rgb * shade * (1.0 - crease * 0.35);
	} else if (shape == 5) {
		// Draining arc: bright part = remaining time (progress), dark track behind.
		float band = smoothstep(0.7 - aa, 0.7 + aa, r) * (1.0 - smoothstep(0.92 - aa, 0.92 + aa, r));
		float turn = fract(0.25 - theta / 6.2831853);
		float taa = clamp(fwidth(turn), 0.001, 0.02);
		float lit = 1.0 - smoothstep(progress - taa, progress + taa, turn);
		a = band * mix(0.28, 1.0, lit);
		tint = mix(color.rgb * 0.25, color.rgb, lit);
	} else {
		// Ink splat: lumpy blob with a few satellite drops.
		float blob = 0.52 + 0.14 * sin(theta * 5.0 + seed * 3.0) + 0.08 * sin(theta * 11.0 - seed * 5.0);
		float body = 1.0 - smoothstep(blob - aa * 1.5, blob + aa * 1.5, r);
		float drops = 0.0;
		for (int i = 0; i < 4; i++) {
			float k = float(i) * 1.7 + seed;
			vec2 center = vec2(cos(k * 2.3), sin(k * 2.3)) * (0.72 + 0.12 * sin(k * 4.1));
			float dr = length(p - center) - (0.07 + 0.03 * sin(k * 3.7));
			drops = max(drops, 1.0 - smoothstep(-aa, aa, dr));
		}
		a = max(body, drops);
	}
	ALBEDO = tint;
	ALPHA = clamp(a * color.a, 0.0, 1.0);
}
