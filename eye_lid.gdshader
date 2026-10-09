// Drawn eyelids (0.15): a patch lying on the painted eye of a supplied model.
// The upper lid comes down from the top (blink, anger, sadness, sleep), the
// lower lid comes up (smile, squint); each ends on a dark lash line. Only the
// ellipse of the eye is ever painted, in the cheek's colour.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 skin : source_color = vec3(0.9);
uniform vec3 lash : source_color = vec3(0.08);
uniform float top = 0.0;        // 0 open .. 1 closed
uniform float bottom = 0.0;     // 0 .. 1 raised lower lid
uniform float tilt = 0.0;       // + inner corner down (anger), - outer corner down (sadness)
uniform float inner = 1.0;      // 1: the inner corner is at u = 1, -1: at u = 0
uniform float pull = 0.998;     // drawn a hair in front of the face (0.2 % of the distance)

varying vec2 lid_uv;
// Same light bands as char_toon.gdshader, so the lid matches the cheek.
uniform float band_low = 0.035;
uniform float band_high = 0.44;
uniform float band_mid = 0.5;
uniform vec4 shade_tint : source_color = vec4(0.66, 0.6, 0.9, 1.0);
uniform vec4 fill_color : source_color = vec4(0.46, 0.44, 0.66, 1.0);
uniform float fill_energy = 0.16;

void vertex() {
	lid_uv = UV;
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz *= pull;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	vec2 q = lid_uv * 2.0 - 1.0;
	if (dot(q, q) > 1.0) discard;
	float u = lid_uv.x;
	float v = lid_uv.y;
	float inward = inner > 0.0 ? u : 1.0 - u;
	float arch = 1.0 - q.x * q.x;
	float closed = smoothstep(0.96, 1.0, top);
	// Upper lid edge: comes down to 0.82 (the closed line), arched, tilted.
	float edge = top * 0.86 + 0.1 * top * arch + tilt * 0.38 * (inward - 0.5) * smoothstep(0.0, 0.25, top + abs(tilt) * 0.3);
	// Lower lid edge: rises, arched upwards in the middle (a happy squint).
	float low = 1.0 - bottom * 0.62 - 0.22 * bottom * arch;
	bool lid_top = v < edge || closed > 0.5;
	bool lid_low = v > low && bottom > 0.02;
	if (!lid_top && !lid_low) discard;
	vec3 colour = skin;
	float line_top = 0.07 + 0.03 * top;
	float shown = closed > 0.5 ? 0.82 + 0.06 * arch - 0.06 : edge;
	if (top > 0.03 && abs(v - shown) < line_top * 0.5 + (closed > 0.5 ? 0.01 : 0.0) && (v < shown + 0.02 || closed > 0.5)) colour = lash;
	if (lid_low && abs(v - low) < 0.035) colour = lash;
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = colour * fill_color.rgb * fill_energy;
}

void light() {
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	float value = LIGHT_IS_DIRECTIONAL ? n_dot_l * ATTENUATION : n_dot_l;
	float energy = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	float low = smoothstep(band_low - 0.02, band_low + 0.02, value);
	float high = smoothstep(band_high - 0.02, band_high + 0.02, value);
	vec3 ramp = mix(vec3(0.0), band_mid * shade_tint.rgb, low);
	ramp = mix(ramp, vec3(1.0), high);
	DIFFUSE_LIGHT += LIGHT_COLOR * energy * ramp / PI;
}
