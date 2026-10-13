shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.0025;
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = vec3(0.025, 0.022, 0.036); }
