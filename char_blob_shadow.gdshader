shader_type spatial;
// Soft contact shadow under a character: an unshaded radial quad lying on the
// floor. Shared material; per-character fade through an instance uniform.
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 shadow_color : source_color = vec4(0.045, 0.035, 0.085, 1.0);
uniform float opacity = 0.7;
instance uniform float strength = 1.0;

void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	// Dense contact core under the feet, soft penumbra towards the rim.
	float core = 1.0 - smoothstep(0.15, 1.0, radius);
	ALBEDO = shadow_color.rgb;
	ALPHA = core * sqrt(core) * opacity * strength;
}
