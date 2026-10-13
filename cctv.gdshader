shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment(){
    vec3 scene=texture(screen_texture,SCREEN_UV).rgb;
    float luminance=dot(scene,vec3(.2126,.7152,.0722));
    vec3 monitor=mix(scene,vec3(luminance)*vec3(.90,1.04,1.00),.48);
    float scan=.985+.015*sin(FRAGCOORD.y*3.14159);
    float grain=fract(sin(dot(FRAGCOORD.xy+floor(TIME*24.),vec2(12.9898,78.233)))*43758.5453)-.5;
    float vignette=1.0-smoothstep(.23,.79,length(SCREEN_UV-.5));
    COLOR=vec4(monitor*scan*(.86+.14*vignette)+grain*.014,1.0);
}
