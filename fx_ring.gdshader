// Flat ring on a unit PlaneMesh (XZ). The node scale is the diameter, and the
// band thickness is in world units, so rings keep a constant tube width while
// they expand. Optional inner fill, arc (0..1, for draining timers) and ink noise.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

instance uniform vec4 color : source_color = vec4(1.0);
instance uniform float thickness = 0.08;
instance uniform float fill = 0.0;
instance uniform float arc = 1.0;
instance uniform float wobble = 0.0;

void fragment() {
	float radius = max(0.001, length(MODEL_MATRIX[0].xyz) * 0.5);
	vec2 p = (UV - 0.5) * 2.0;
	float angle = atan(p.x, p.y);
	// Ink rings get an uneven, hand-drawn edge.
	float edge_noise = wobble * (sin(angle * 7.0 + radius * 3.1) * 0.5 + sin(angle * 13.0 - radius * 1.7) * 0.3);
	float r = length(p) * radius;
	float outer_r = radius - thickness * 0.4 * wobble + edge_noise * thickness * 0.5;
	float aa = max(fwidth(r), 0.0006);
	float outer = 1.0 - smoothstep(outer_r - aa, outer_r + aa, r);
	float inner = smoothstep(outer_r - thickness - aa, outer_r - thickness + aa, r);
	float band = outer * inner;
	float disc = outer * fill * (0.25 + 0.75 * clamp(r / radius, 0.0, 1.0));
	float turn = angle / 6.2831853 + 0.5;
	float turn_aa = clamp(fwidth(turn), 0.0005, 0.01);
	float shown = arc >= 0.999 ? 1.0 : 1.0 - smoothstep(arc - turn_aa, arc + turn_aa, turn);
	ALBEDO = color.rgb;
	ALPHA = color.a * max(band, disc) * shown;
}
