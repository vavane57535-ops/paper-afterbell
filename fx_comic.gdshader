// Comic-book marks for combat and motion (0.14): impact bursts, speed lines,
// claw slashes, sparkles, hearts, bolts, dust puffs, sweat, anger marks,
// dizzy swirls, stars, shock rings, streaks, floor cracks, "!", "+", ink
// puddles, notes, afterimages and flash rays.
// Every mark of one blend variant is an instance of the same MultiMesh (one
// draw call): the look comes with the instance, COLOR = tint and
// INSTANCE_CUSTOM = (progress, angle, seed, code) with
// code = shape + 32 * ink index + 512 * flat core (see fx_comic.gd).
// fx_comic.gd derives the additive and the flat (no billboard) variants from
// this code at runtime (string replaces of the marked lines).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// Rim colours (linear): 0 ink, 1 blood, 2 shadow, 3 old gold, 4 deep green,
// 5 wine, 6 orange, 7 steel, 8 rust, 9 pale blue, 10 teal, 11 amber,
// 12 dust, 13 smoke, 14 plum, 15 white.
const vec3 INKS[16] = vec3[16](
	vec3(0.0086, 0.0052, 0.0131), vec3(0.4508, 0.0296, 0.0781), vec3(0.0116, 0.0048, 0.0176), vec3(0.1946, 0.0685, 0.0052),
	vec3(0.0137, 0.1441, 0.0844), vec3(0.2542, 0.0232, 0.0685), vec3(1.0, 0.3231, 0.0742), vec3(0.3372, 0.4564, 0.5520),
	vec3(0.1946, 0.0232, 0.0052), vec3(0.3467, 0.4678, 0.7454), vec3(0.0284, 0.1441, 0.1070), vec3(0.6584, 0.1651, 0.0232),
	vec3(0.2623, 0.2140, 0.1500), vec3(0.1620, 0.1441, 0.1329), vec3(0.0232, 0.0080, 0.0356), vec3(1.0, 1.0, 1.0));

varying vec4 v_color;
varying flat vec4 v_custom;

void vertex() {
	// Instance colours come in sRGB.
	v_color = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);
	v_custom = INSTANCE_CUSTOM;
	// BILLBOARD_BEGIN
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	// BILLBOARD_END
}

float hash(float n, float seed) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

// Filled shape with an ink rim: x = coverage, y = rim amount.
vec2 fill_rim(float d, float rim, float aa) {
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float edge = smoothstep(-rim - aa, -rim + aa, d);
	return vec2(inside, edge);
}

void fragment() {
	vec4 color = v_color;
	float progress = v_custom.x;
	float angle = v_custom.y;
	float seed = v_custom.z;
	int code = int(v_custom.w + 0.5);
	int shape = code % 32;
	vec4 ink = vec4(INKS[(code / 32) % 16], (code >= 512) ? 0.2 : 1.0);
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float c = cos(angle);
	float s = sin(angle);
	p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	float r = length(p);
	float theta = atan(p.y, p.x);
	float aa = max(fwidth(r), 0.004);
	float a = 0.0;
	vec3 tint = color.rgb;
	if (shape == 0) {
		// Impact burst: a jagged star with an ink rim and a pale core.
		float n = 9.0;
		float k = theta * n / 6.2831853 + seed;
		float tri = abs(fract(k) - 0.5) * 2.0;
		float jitter = 0.12 * (hash(floor(k), seed) - 0.5);
		float boundary = mix(0.92 + jitter, 0.5, tri);
		vec2 fr = fill_rim(r - boundary, 0.09, aa * 1.5);
		a = fr.x;
		float core = 1.0 - smoothstep(0.0, 0.55, r);
		tint = mix(mix(color.rgb, vec3(1.0), core * 0.75 * ink.a), ink.rgb, fr.y);
	} else if (shape == 1) {
		// Speed lines flying outward from the centre.
		float n = 22.0;
		float k = theta * n / 6.2831853 + 11.0;
		float id = floor(k);
		float f = fract(k) - 0.5;
		float start = 0.18 + 0.3 * hash(id, seed) + progress * 0.5;
		float len = 0.22 + 0.3 * hash(id + 7.0, seed);
		float along = (r - start) / len;
		float body = step(0.0, along) * step(along, 1.0);
		float width = (0.05 + 0.1 * hash(id + 3.0, seed)) * (1.0 - abs(along * 2.0 - 1.0));
		float line = 1.0 - smoothstep(width - 0.03, width + 0.03, abs(f));
		a = line * body * step(0.35, hash(id + 5.0, seed) + 0.25) * (1.0 - smoothstep(0.92, 1.0, r));
	} else if (shape == 2) {
		// Claw slash: three thin crescents wiping in along their arc, sharp at the
		// tips, with a pale core and coloured edges.
		float span = 1.2;
		float t = clamp(theta / span, -1.0, 1.0);
		float head = mix(-1.25, 1.25, clamp(progress * 2.8, 0.0, 1.0));
		float tail = mix(-1.25, 1.25, clamp(progress * 2.8 - 1.45, 0.0, 1.0));
		float taper = max(0.0, 1.0 - t * t);
		float d = 10.0;
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float radius = 0.5 + 0.18 * fi;
			float half_width = (0.058 - 0.012 * abs(fi - 1.0)) * taper + 0.002;
			d = min(d, abs(r - radius) - half_width);
		}
		float band = 1.0 - smoothstep(-aa, aa, d);
		float swept = step(t, head) * step(tail, t) * step(abs(theta), span);
		a = band * swept;
		float core = 1.0 - smoothstep(-0.035, -0.012, d);
		tint = mix(color.rgb, vec3(1.0), core * 0.9);
	} else if (shape == 3) {
		// Four-point sparkle that swells and shrinks.
		float twinkle = sin(clamp(progress, 0.0, 1.0) * 3.14159);
		vec2 q = abs(p) / max(0.2 + 0.8 * twinkle, 0.05);
		float d = pow(q.x, 0.55) + pow(q.y, 0.55) - 0.95;
		a = 1.0 - smoothstep(-0.06, 0.06, d);
		float core = 1.0 - smoothstep(0.0, 0.35, length(q));
		tint = mix(color.rgb, vec3(1.0), core);
	} else if (shape == 4) {
		// Heart with an ink rim.
		vec2 q = p * 1.25;
		q.y += 0.25;
		float x2 = q.x * q.x;
		float heart = pow(x2 + q.y * q.y - 1.0, 3.0) - x2 * q.y * q.y * q.y;
		float haa = max(fwidth(heart), 0.01);
		float inside = 1.0 - smoothstep(-haa, haa, heart);
		float rim = smoothstep(-0.35, -0.12, heart);
		a = inside;
		float shine = 1.0 - smoothstep(0.0, 0.22, length(q - vec2(-0.42, 0.45)));
		tint = mix(mix(color.rgb, vec3(1.0), shine * 0.8), ink.rgb, rim * 0.85);
	} else if (shape == 5) {
		// Lightning bolt: a zigzag that flickers.
		float d = 10.0;
		vec2 prev = vec2((hash(1.0, seed) - 0.5) * 0.3, 0.92);
		for (int i = 1; i <= 5; i++) {
			float fi = float(i);
			vec2 next = vec2((hash(fi * 3.0 + floor(progress * 9.0), seed) - 0.5) * 0.75, 0.92 - fi * 0.37);
			d = min(d, seg(p, prev, next));
			prev = next;
		}
		float width = 0.03 * (1.0 - 0.5 * progress);
		float body = 1.0 - smoothstep(width - aa, width + aa, d);
		float glow = (1.0 - smoothstep(width, width + 0.16, d)) * 0.3;
		a = max(body, glow);
		tint = mix(color.rgb, vec3(1.0), body * 0.85);
	} else if (shape == 6) {
		// Cartoon dust cloud: a cluster of lobes that swells, then breaks up.
		float d = length(p) - 0.42;
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float ang = fi * 1.047 + seed;
			vec2 centre = vec2(cos(ang), sin(ang)) * (0.38 + 0.08 * hash(fi, seed));
			d = min(d, length(p - centre) - (0.26 + 0.1 * hash(fi + 9.0, seed)));
		}
		float eaten = smoothstep(0.45, 1.0, progress) * 0.5;
		d += eaten;
		vec2 fr = fill_rim(d, 0.07, aa * 1.5);
		a = fr.x;
		tint = mix(color.rgb, ink.rgb, fr.y * 0.8);
	} else if (shape == 7) {
		// Sweat drop: round at the bottom, pointed at the top.
		vec2 q = p * 1.3;
		float body = length(q - vec2(0.0, -0.25)) - 0.45;
		float tip = max(abs(q.x) - (0.45 * (1.0 - smoothstep(-0.25, 0.85, q.y))), q.y - 0.85);
		tip = max(tip, -0.25 - q.y);
		float d = min(body, tip);
		vec2 fr = fill_rim(d, 0.1, aa * 1.5);
		a = fr.x;
		float shine = 1.0 - smoothstep(0.0, 0.14, length(q - vec2(-0.16, -0.2)));
		tint = mix(mix(color.rgb, vec3(1.0), shine), ink.rgb, fr.y * 0.8);
	} else if (shape == 8) {
		// Anger mark: four curved strokes around a gap.
		float d = 10.0;
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			vec2 corner = vec2((mod(fi, 2.0) < 0.5) ? 1.0 : -1.0, (fi < 2.0) ? 1.0 : -1.0);
			vec2 centre = corner * 0.62;
			vec2 q = p - centre;
			float facing = dot(normalize(q + vec2(0.0001)), -normalize(corner));
			float arc = abs(length(q) - 0.42);
			d = min(d, facing > 0.35 ? arc : 10.0);
		}
		float pulse = 0.1 + 0.03 * sin(progress * 25.0);
		a = 1.0 - smoothstep(pulse - aa, pulse + aa, d);
	} else if (shape == 9) {
		// Dizzy swirl.
		float turns = r * 2.6 - theta / 6.2831853 + seed;
		float d = abs(fract(turns) - 0.5);
		float stroke = smoothstep(0.3, 0.38, d);
		a = stroke * (1.0 - smoothstep(0.86, 0.95, r)) * smoothstep(0.05, 0.12, r);
	} else if (shape == 10) {
		// Five-point star with an ink rim.
		float k = (theta + 1.5708) * 5.0 / 6.2831853;
		float tri = abs(fract(k) - 0.5) * 2.0;
		float boundary = mix(0.92, 0.42, pow(tri, 0.85));
		vec2 fr = fill_rim(r - boundary, 0.1, aa * 1.5);
		a = fr.x;
		tint = mix(color.rgb, ink.rgb, fr.y * 0.9);
	} else if (shape == 11) {
		// Shock ring made of dashes.
		float band = abs(r - 0.82) - 0.05 * (1.0 - progress * 0.6);
		float dash = step(0.38, abs(fract(theta * 9.0 / 6.2831853 + seed) - 0.5) * 2.0);
		a = (1.0 - smoothstep(-aa, aa, band)) * dash;
	} else if (shape == 12) {
		// One tapered streak along +y.
		float t = clamp(p.y, -1.0, 1.0);
		float taper = (1.0 - t * t) * (0.4 + 0.6 * smoothstep(-1.0, 1.0, t));
		float d = abs(p.x) - 0.2 * taper;
		a = (1.0 - smoothstep(-aa * 2.0, aa * 2.0, d)) * step(abs(p.y), 0.98);
		float core = 1.0 - smoothstep(0.0, 0.12 * taper + 0.001, abs(p.x));
		tint = mix(color.rgb, vec3(1.0), core * 0.7);
	} else if (shape == 13) {
		// Cracks running out from the centre (floor decal).
		float d = 10.0;
		float grow = clamp(progress * 7.0, 0.0, 1.0);
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float ang = fi * 0.8976 + (hash(fi, seed) - 0.5) * 0.5 + seed;
			vec2 dir = vec2(cos(ang), sin(ang));
			float len = (0.5 + 0.45 * hash(fi + 4.0, seed)) * grow;
			float along = dot(p, dir);
			vec2 normal = vec2(-dir.y, dir.x);
			float side = dot(p, normal) + 0.06 * sin(along * 14.0 + fi * 3.0) * smoothstep(0.0, 0.3, along);
			float width = 0.045 * (1.0 - clamp(along / max(len, 0.001), 0.0, 1.0)) + 0.004;
			float line = (along > 0.0 && along < len) ? abs(side) - width : 10.0;
			d = min(d, line);
			// One side branch per crack.
			float branch_at = len * (0.35 + 0.3 * hash(fi + 8.0, seed));
			vec2 from = dir * branch_at;
			float turn = ang + (hash(fi + 12.0, seed) > 0.5 ? 0.7 : -0.7);
			vec2 to = from + vec2(cos(turn), sin(turn)) * len * 0.35;
			d = min(d, seg(p, from, to) - 0.012);
		}
		float hole = length(p) - 0.1 * grow;
		d = min(d, hole);
		a = 1.0 - smoothstep(-aa, aa, d);
	} else if (shape == 14) {
		// "!"
		float bar = max(abs(p.x) - mix(0.1, 0.2, smoothstep(-0.25, 0.9, p.y)), max(-0.25 - p.y, p.y - 0.9));
		float dot_d = length(p - vec2(0.0, -0.62)) - 0.17;
		float d = min(bar, dot_d);
		vec2 fr = fill_rim(d, 0.07, aa * 1.5);
		a = fr.x;
		tint = mix(color.rgb, ink.rgb, fr.y * 0.9);
	} else if (shape == 15) {
		// "+" with round ends.
		float d = min(seg(p, vec2(-0.6, 0.0), vec2(0.6, 0.0)), seg(p, vec2(0.0, -0.6), vec2(0.0, 0.6))) - 0.2;
		vec2 fr = fill_rim(d, 0.08, aa * 1.5);
		a = fr.x;
		tint = mix(mix(color.rgb, vec3(1.0), 0.25), ink.rgb, fr.y * 0.85);
	} else if (shape == 16) {
		// Ink puddle spreading, with satellite drops.
		float grow = 1.0 - pow(1.0 - clamp(progress * 3.0, 0.0, 1.0), 2.0);
		float blob = (0.5 + 0.14 * sin(theta * 5.0 + seed * 3.0) + 0.09 * sin(theta * 9.0 - seed * 5.0)) * grow;
		float body = 1.0 - smoothstep(blob - aa * 1.5, blob + aa * 1.5, r);
		float drops = 0.0;
		for (int i = 0; i < 5; i++) {
			float kk = float(i) * 1.7 + seed;
			vec2 centre = vec2(cos(kk * 2.3), sin(kk * 2.3)) * (0.7 + 0.14 * sin(kk * 4.1)) * grow;
			float dr = length(p - centre) - (0.06 + 0.035 * sin(kk * 3.7));
			drops = max(drops, 1.0 - smoothstep(-aa, aa, dr));
		}
		a = max(body, drops);
	} else if (shape == 17) {
		// Musical note.
		float head = length((p - vec2(-0.18, -0.5)) * vec2(1.0, 1.35)) - 0.3;
		float stem = max(abs(p.x - 0.08) - 0.055, max(-0.5 - p.y, p.y - 0.75));
		float flag = seg(p, vec2(0.08, 0.75), vec2(0.5, 0.35)) - 0.07;
		float d = min(head, min(stem, flag));
		vec2 fr = fill_rim(d, 0.06, aa * 1.5);
		a = fr.x;
		tint = mix(color.rgb, ink.rgb, fr.y * 0.9);
	} else if (shape == 18) {
		// Afterimage: a soft upright ghost torn into speed streaks.
		vec2 q = vec2(p.x / 0.5, p.y / 0.96);
		float body = 1.0 - smoothstep(0.55, 1.0, length(q));
		float rows = 0.55 + 0.45 * sin(p.y * 21.0 + seed * 9.0);
		float tear = smoothstep(0.0, 0.9, abs(p.x) * 1.6 + (1.0 - rows) * 0.6);
		a = body * mix(1.0, rows, tear) * 0.85;
		tint = mix(color.rgb, vec3(1.0), body * body * 0.35);
	} else {
		// Flash rays: long thin wedges from the centre.
		float n = 12.0;
		float k = theta * n / 6.2831853 + seed + progress * 0.6;
		float id = floor(k);
		float f = abs(fract(k) - 0.5) * 2.0;
		float reach = 0.55 + 0.42 * hash(id, seed);
		float wedge = 1.0 - smoothstep(0.0, max(0.3 * (1.0 - r / reach), 0.001), f);
		a = wedge * step(r, reach) * (1.0 - smoothstep(0.0, 1.0, progress)) * step(0.3, hash(id + 2.0, seed) + 0.25);
		float core = (1.0 - smoothstep(0.0, 0.16, r)) * 0.8;
		a = max(a, core);
		tint = mix(color.rgb, vec3(1.0), core * 0.8);
	}
	ALBEDO = tint;
	ALPHA = clamp(a * color.a, 0.0, 1.0);
}
