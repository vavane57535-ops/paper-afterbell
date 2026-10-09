shader_type sky;
// Night sky for the maps: vertical gradient, soft horizon band, moon disc with halo and a
// sparse static star field. No TIME: the radiance cubemap is only rebuilt when the
// uniforms change (map rebuild / graphics profile).

uniform vec3 zenith_color : source_color = vec3(0.02, 0.03, 0.07);
uniform vec3 horizon_color : source_color = vec3(0.09, 0.11, 0.2);
uniform vec3 ground_color : source_color = vec3(0.03, 0.035, 0.06);
uniform vec3 moon_color : source_color = vec3(0.85, 0.9, 1.0);
uniform vec3 moon_direction = vec3(0.3, 0.64, 0.7);
uniform float moon_size = 0.03;
uniform float moon_energy = 2.2;
uniform float halo_energy = 0.35;
uniform float star_density = 0.012;
uniform float star_energy = 0.9;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = dir.y;
	vec3 color = mix(horizon_color, zenith_color, smoothstep(0.0, 0.6, height));
	color = mix(color, ground_color, smoothstep(0.0, -0.12, height));
	vec3 moon = normalize(moon_direction);
	float facing = max(dot(dir, moon), 0.0);
	float disc = smoothstep(cos(moon_size), cos(moon_size * 0.8), facing);
	float halo = pow(facing, 90.0) * halo_energy + pow(facing, 10.0) * halo_energy * 0.18;
	color += moon_color * (disc * moon_energy + halo);
	if (star_density > 0.0 && height > 0.04 && !AT_CUBEMAP_PASS) {
		vec3 grid = dir * 150.0;
		vec3 cell = floor(grid);
		float chance = hash(cell);
		if (chance > 1.0 - star_density) {
			vec3 offset = vec3(hash(cell + 1.7), hash(cell + 3.1), hash(cell + 5.3)) * 0.5 + 0.25;
			float star = smoothstep(0.28, 0.0, length(fract(grid) - offset));
			float twinkle = 0.5 + 0.5 * hash(cell + 9.2);
			color += vec3(0.85, 0.9, 1.0) * star * twinkle * star_energy * smoothstep(0.04, 0.3, height) * (1.0 - disc);
		}
	}
	COLOR = color;
}
