shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0,0.35,0.47,1.0);
// 1.0 behind a wall, 0.0 in direct sight (physics rays from reveal_controller.gd,
// ~10 Hz). No depth-texture read: it forced a depth copy (resolve with MSAA) every
// frame, and the ray hint always overrode it anyway.
uniform float occluded_hint = -1.0;
void fragment() {
	float hidden = clamp(occluded_hint, 0.0, 1.0);
	float rim = pow(1.0-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),2.2);
	ALBEDO=tint.rgb;
	ALPHA=tint.a * mix(0.03 + rim * 0.34, 0.72 + rim * 0.22, hidden);
}
