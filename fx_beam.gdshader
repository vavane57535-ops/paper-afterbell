// Camera-facing ribbon on a unit QuadMesh: node origin = segment middle,
// node basis.y = the whole segment (from -> to). Used for telegraph lines,
// tracers (mode 0) and the exit beacon column (mode 1, fades with height).
// effects.gd derives a faint no-depth-test variant for the beacon at runtime.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add, world_vertex_coords, fog_disabled;

instance uniform vec4 color : source_color = vec4(1.0);
instance uniform float width = 0.1;
instance uniform float mode = 0.0;
instance uniform float progress = 0.0;

void vertex() {
	vec3 axis = MODEL_MATRIX[1].xyz;
	vec3 center = MODEL_MATRIX[3].xyz + axis * (0.5 - UV.y);
	vec3 to_camera = INV_VIEW_MATRIX[3].xyz - center;
	vec3 side = cross(axis, to_camera);
	float side_length = length(side);
	side = side_length > 0.0001 ? side / side_length : vec3(1.0, 0.0, 0.0);
	VERTEX = center + side * (UV.x - 0.5) * width;
}

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float along = 1.0 - UV.y;
	float core = 1.0 - smoothstep(0.0, 0.35, across);
	float soft = 1.0 - smoothstep(0.2, 1.0, across);
	float a = soft * 0.55 + core * 0.45;
	vec3 tint = mix(color.rgb, vec3(1.0), core * 0.3);
	if (mode < 0.5) {
		// Line: rounded ends and a travelling highlight.
		float ends = smoothstep(0.0, 0.04, along) * smoothstep(0.0, 0.04, 1.0 - along);
		float sweep = 1.0 - smoothstep(0.0, 0.2, abs(along - progress));
		a *= ends * (0.75 + 0.25 * sweep);
	} else {
		// Beacon column: bright at the ground, fading upward, slow rising bands.
		float height_fade = pow(1.0 - along, 1.6);
		float bands = 0.82 + 0.18 * sin(along * 38.0 - progress * 6.2831853);
		a *= height_fade * bands * smoothstep(0.0, 0.02, along);
	}
	ALBEDO = tint;
	ALPHA = clamp(a * color.a, 0.0, 1.0);
}
