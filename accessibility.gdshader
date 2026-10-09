shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform bool colorblind = false;
void fragment() {
	vec4 source=texture(screen_texture,SCREEN_UV);
	vec3 c=source.rgb;
	// Keep neutral paper and shadows. Separate saturated red/green into orange/blue.
	if(colorblind){
		float red=max(0.0,c.r-max(c.g,c.b));
		float green=max(0.0,c.g-max(c.r,c.b));
		c+=red*vec3(0.0,0.45,-0.08)+green*vec3(-0.1,-0.12,0.75);
	}
	COLOR=vec4(clamp(c,0.0,1.0),source.a);
}
