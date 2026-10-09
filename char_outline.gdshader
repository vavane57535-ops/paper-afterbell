shader_type spatial;
// Character ink outline: inverted hull extruded in SCREEN space (constant pixel
// width, thinner with distance). depth_draw_never moves it to the transparent
// pass: drawn after all opaque geometry, never in the depth/shadow passes.
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;

uniform float width_px = 2.1;
uniform float far_width_px = 1.0;
uniform float fade_start = 6.0;
uniform float fade_end = 38.0;
// Pushes the hull back (metres) so open double-sided cloth never z-fights with it.
uniform float depth_push = 0.012;
uniform vec4 ink_color : source_color = vec4(0.035, 0.028, 0.055, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool textured = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
// How much of the (darkened) surface colour tints the ink.
uniform float albedo_mix : hint_range(0.0, 1.0) = 0.22;

void vertex() {
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	float distance = -view_position.z;
	view_position.z -= depth_push;
	vec4 clip = PROJECTION_MATRIX * view_position;
	vec2 clip_normal = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	float normal_length = length(clip_normal);
	vec2 direction = normal_length > 0.0001 ? clip_normal / normal_length : vec2(0.0);
	float pixels = mix(width_px, far_width_px, smoothstep(fade_start, fade_end, distance));
	// Keep a similar look from 720p to 4K.
	pixels *= clamp(VIEWPORT_SIZE.y / 1080.0, 0.7, 2.0);
	clip.xy += direction * pixels * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	vec3 surface = albedo_color.rgb;
	if (textured) {
		surface *= textureLod(albedo_tex, UV, 4.0).rgb;
	}
	ALBEDO = mix(ink_color.rgb, surface * 0.28, albedo_mix);
}
