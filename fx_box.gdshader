// Attack zone ("le cube rouge") drawn with ONE unit box mesh: a faint translucent
// fill plus crisp edges computed from the distance to the box edges (fwidth AA).
// The node scale is the box size, so edges keep a constant world thickness.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

instance uniform vec4 color : source_color = vec4(1.0, 0.16, 0.3, 1.0);
instance uniform float fade = 1.0;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	// Distance (world units) from this fragment to each pair of faces.
	vec3 d = (0.5 - abs(local_position)) * size;
	float smallest = min(d.x, min(d.y, d.z));
	float largest = max(d.x, max(d.y, d.z));
	// On a face the smallest distance is ~0; the middle one is the distance to the nearest edge.
	float edge_distance = d.x + d.y + d.z - smallest - largest;
	float aa = max(fwidth(edge_distance), 0.0008);
	float width = max(0.022, aa * 1.4);
	float edge = 1.0 - smoothstep(width - aa, width + aa, edge_distance);
	// Soft glow hugging the edges keeps the volume readable without a heavy fill.
	float glow = 1.0 - smoothstep(0.0, 0.32, edge_distance);
	// Slightly stronger at the floor so the zone reads on the ground.
	float floor_hint = 1.0 - smoothstep(0.0, 0.5, local_position.y + 0.5);
	ALBEDO = mix(color.rgb, vec3(1.0, 0.78, 0.82), edge * 0.45);
	ALPHA = fade * color.a * clamp(0.055 + glow * 0.09 + floor_hint * 0.05 + edge * 0.85, 0.0, 1.0);
}
