shader_type spatial;
render_mode diffuse_toon;
uniform vec4 skin_color : source_color;
uniform vec4 cloth_color : source_color;
uniform vec4 pants_color : source_color;
uniform vec4 sleeve_color : source_color;
uniform vec4 band_color : source_color;
uniform float shoulder_width = 0.225;
uniform float arm_scale = 1.0;
uniform bool bare_legs = false;
uniform bool alice = false;
void fragment() {
	// Material seams are sampled continuously on the welded A-pose surface.
	// Triangle tessellation no longer makes jagged patches at collar / cuffs.
	vec3 c = cloth_color.rgb;
	float hips = 1.0-smoothstep(-0.085,-0.055,UV2.y);
	c = mix(c, bare_legs ? skin_color.rgb : pants_color.rgb, hips);
	c = mix(c,skin_color.rgb,smoothstep(0.514,0.536,UV2.y));
	float arm_x = abs(UV2.x)-shoulder_width*1.12;
	float arm_y = UV2.y-0.44;
	float along = (arm_x*sin(0.55)-arm_y*cos(0.55))/arm_scale;
	float across = abs(arm_x*cos(0.55)+arm_y*sin(0.55));
	if (along > -0.07 && across < 0.18 && UV2.y > -0.22) {
		vec3 sleeve = alice ? mix(sleeve_color.rgb,skin_color.rgb,smoothstep(0.255,0.29,along)) : sleeve_color.rgb;
		c = mix(c,sleeve,smoothstep(shoulder_width*0.92,shoulder_width*1.035,abs(UV2.x)));
	}

	if (alice) {
		if (along > 0.30 && along < 0.525 && across < 0.14 && abs(UV2.x) > shoulder_width*1.15) {
			float stripe = fract((along-0.29)*13.333 + arm_x*0.8);
			c=mix(c,cloth_color.rgb,1.0-smoothstep(0.28,0.32,stripe));
		}
		if (UV2.y < -0.23 && UV2.y > -0.93) {
			float stripe = fract(UV2.y*11.1+abs(UV2.x)*1.8);
			c=mix(c,band_color.rgb,1.0-smoothstep(0.29,0.33,stripe));
		}
	}
	// Object-locked fine pencil grain: no screen-space shimmer or flashing.
	float pencil = sin((UV2.x + UV2.y * 0.72) * 240.0);
	float crossing = sin((UV2.x - UV2.y * 0.53) * 181.0);
	float hatch = smoothstep(0.90, 1.0, pencil) * 0.07 + smoothstep(0.94, 1.0, crossing) * 0.025;
	ALBEDO = c * (1.0 - hatch);
	ROUGHNESS = 0.83;
	SPECULAR = 0.0;
}
