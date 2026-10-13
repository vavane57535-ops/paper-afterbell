shader_type spatial;
// Reveal silhouette drawn as a material_overlay on the character's own skinned
// mesh (no duplicate shell meshes). Same look and uniforms as
// character_reveal.gdshader, but the wall test comes only from occluded_hint
// (set every frame by the reveal controller), so no depth-texture copy is needed.
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.35, 0.47, 1.0);
uniform float occluded_hint = 0.0;

void fragment() {
	float hidden = clamp(occluded_hint, 0.0, 1.0);
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.2);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * mix(0.03 + rim * 0.34, 0.72 + rim * 0.22, hidden);
}
