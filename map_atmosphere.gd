extends RefCounted









const OmMaps = preload("res://om_maps.gd")
const SKY_SHADER = preload("res://map_sky.gdshader")

const LOOKS: Dictionary = {
	"school": {
		"zenith": Color("060913"), "horizon": Color("1c2442"), "ground": Color("0b0d18"), 
		"ambient": Color("857f9c"), "ambient_energy": 0.5, 
		"fog": Color("1d1f36"), "fog_density": 0.0075, "fog_sky": 0.25, "mist": 0.0, 
		"moon": Color("e4ecff"), "stars": 0.014, "exposure": 1.05, 
	}, 
	"forest": {
		"zenith": Color("04080d"), "horizon": Color("14263a"), "ground": Color("060b10"), 
		"ambient": Color("6a7690"), "ambient_energy": 0.38, 
		"fog": Color("101a26"), "fog_density": 0.0125, "fog_sky": 0.55, "mist": 0.05, 
		"moon": Color("dbe8ff"), "stars": 0.01, "exposure": 1.05, 
	}, 
	"snow": {
		"zenith": Color("0a1122"), "horizon": Color("2d4264"), "ground": Color("121a2a"), 
		"ambient": Color("8089a8"), "ambient_energy": 0.38, 
		"fog": Color("23324c"), "fog_density": 0.0115, "fog_sky": 0.5, "mist": 0.035, 
		"moon": Color("eef3ff"), "stars": 0.008, "exposure": 1.0, 
	}, 
}

static func apply(environment: Environment, map_id: String, quality: String = "high") -> void :
	if environment == null:
		return
	var look: Dictionary = LOOKS.get(map_id, LOOKS.school)
	var mobile: bool = _is_mobile()
	var light_profile: bool = quality in ["performance", "battery"]

	if mobile:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = look.horizon.lerp(look.zenith, 0.35)
	else:
		environment.background_mode = Environment.BG_SKY
		environment.sky = _sky(environment, look, map_id, light_profile)
		environment.background_energy_multiplier = 1.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = look.ambient
	environment.ambient_light_energy = float(look.ambient_energy)
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_light_color = look.fog
	environment.fog_light_energy = 1.0
	environment.fog_density = float(look.fog_density)
	environment.fog_sky_affect = float(look.fog_sky)
	environment.fog_sun_scatter = 0.0 if light_profile or mobile else 0.12
	environment.fog_aerial_perspective = 0.0

	var mist: float = 0.0 if light_profile or mobile else float(look.mist)
	environment.fog_height = 1.5
	environment.fog_height_density = mist


	environment.glow_enabled = not mobile and not light_profile
	environment.glow_normalized = false
	environment.glow_intensity = 0.7 if quality == "high" else 0.6
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.02
	environment.glow_hdr_threshold = 0.9
	environment.glow_hdr_scale = 2.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var levels: Array[float] = [0.0, 0.6, 1.0, 0.7, 0.35, 0.0, 0.0]
	for index in range(levels.size()):
		environment.set_glow_level(index, levels[index])
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = float(look.exposure)
	environment.tonemap_white = 1.0

	environment.adjustment_enabled = not mobile

	environment.adjustment_brightness = 0.93
	environment.adjustment_contrast = 1.16
	environment.adjustment_saturation = 0.8

static func _sky(environment: Environment, look: Dictionary, map_id: String, light_profile: bool) -> Sky:
	var sky: Sky = environment.sky
	var material: ShaderMaterial = null
	if sky != null and sky.sky_material is ShaderMaterial and (sky.sky_material as ShaderMaterial).shader == SKY_SHADER:
		material = sky.sky_material
	else:
		sky = Sky.new()
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		material = ShaderMaterial.new()
		material.shader = SKY_SHADER
		sky.sky_material = material
	var settings: Dictionary = OmMaps.MOON.get(map_id, OmMaps.MOON.school)
	var rotation: Vector3 = settings.rotation
	var moon_basis: Basis = Basis.from_euler(Vector3(deg_to_rad(rotation.x), deg_to_rad(rotation.y), deg_to_rad(rotation.z)))
	material.set_shader_parameter("zenith_color", look.zenith)
	material.set_shader_parameter("horizon_color", look.horizon)
	material.set_shader_parameter("ground_color", look.ground)
	material.set_shader_parameter("moon_color", look.moon)
	material.set_shader_parameter("moon_direction", moon_basis.z.normalized())
	material.set_shader_parameter("star_density", 0.0 if light_profile else float(look.stars))
	return sky

static func _is_mobile() -> bool:
	var flags: PackedStringArray = OS.get_cmdline_user_args()
	return OS.has_feature("android") or "--mobile-test" in flags or "--mobile-preview" in flags
