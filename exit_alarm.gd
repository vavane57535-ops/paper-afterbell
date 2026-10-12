class_name PaperExitAlarm
extends Node

# 0.16 : l'ouverture de la sortie devient une alerte générale.
# Tout est déduit de l'état réseau déjà répliqué (exit_flow.opened, time_left, lms),
# donc chaque client joue la même séquence : sirène + sonnerie, annonce au HUD,
# filtre rouge qui pulse sur la musique, lumières d'urgence dans toute la carte,
# gyrophares à la sortie, secousse, cœur, et la musique de course (audio.set_rush).

const T = preload("res://ui_theme.gd")

const ALARM_PATHS: Array[String] = ["res://audio/sfx/exit_alarm_00.wav", "res://audio/sfx/exit_alarm_01.wav"]
const RUSH_SPAN: float = 80.0
const RUSH_LEAD: float = 3.0
const FINAL_CALL: float = 59.97
const BANNER_SECONDS: float = 3.9
const LAMP_RED: Color = Color(1.0, 0.13, 0.1)
const AMBIENT_RED: Color = Color(0.95, 0.3, 0.3)
const FOG_RED: Color = Color(0.32, 0.03, 0.05)
const EXIT_GLOW: Color = Color(1.0, 0.86, 0.58)
const BEACON_RED: Color = Color(1.0, 0.22, 0.08)
const DOME_RED: Color = Color(1.0, 0.03, 0.02)
# panneau « SORTIE » de la carte : vert d'issue de secours, cerné de noir (lisible sous la lumière de la sortie)
const SIGN_GREEN: Color = Color(0.42, 1.0, 0.56)
const SIGN_INK: Color = Color(0.0, 0.07, 0.03)

const GRADE_SHADER: String = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float level = 0.0;
uniform float pulse = 0.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float edge = smoothstep(0.3, 1.45, length((UV - 0.5) * 2.0));
	vec3 red = vec3(lum * 1.5 + 0.015, lum * 0.3, lum * 0.28);
	float k = level * clamp(0.36 + 0.3 * edge + pulse * (0.1 + 0.24 * edge), 0.0, 0.9);
	// les hautes lumières (la sortie éclairée, la colonne dorée) gardent leur couleur
	k *= 1.0 - 0.75 * smoothstep(0.5, 0.92, max(c.r, max(c.g, c.b)));
	COLOR = vec4(mix(c, red, k), 1.0);
}
"""

const GLOW_SHADER: String = """
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float level = 0.0;
uniform float pulse = 0.0;
uniform float sweep = 0.0;
uniform float sweep_amount = 1.0;
uniform float aspect = 1.78;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	vec2 q = vec2(p.x * aspect, p.y);
	float r = length(p);
	float edge = smoothstep(0.55, 1.42, r);
	float angle = atan(q.y, q.x);
	float d = abs(mod(angle - sweep + 3.14159265, 6.2831853) - 3.14159265);
	float beam = exp(-d * d * 4.0) * smoothstep(0.2, 1.25, r) * 0.2 * sweep_amount;
	float a = level * (pulse * edge * 0.5 + beam + edge * 0.06);
	COLOR = vec4(1.0, 0.1, 0.07, clamp(a, 0.0, 1.0));
}
"""

var world: Node
var _open: bool = false
var _since: float = 0.0
var _level: float = 0.0
var _rush: float = 0.0
var _clock: float = 0.0
var _pulse: float = 0.0
var _beat_index: int = 0
var _last_beat: int = -1
var _round_seen: int = -1
var _final_done: bool = false
var _alarm: AudioStreamPlayer
var _streams: Array[AudioStream] = []
var _grade: ColorRect
var _grade_material: ShaderMaterial
var _glow: ColorRect
var _glow_material: ShaderMaterial
var _banner: Control
var _compass: Control
var _banner_title: String = ""
var _banner_time: float = 0.0
var _banner_clock: float = 0.0
var _compass_alpha: float = 0.0
var _lamps: Array = []
var _lamp_colors: Array[Color] = []
var _lamp_energies: Array[float] = []
var _lamps_touched: bool = false
var _environment_touched: bool = false
var _environment_base: Array = []
var _rig: Node3D
var _rig_light: OmniLight3D
var _beacons: Array[Node3D] = []
var _beacon_lights: Array[SpotLight3D] = []
var _beacon_domes: Array[StandardMaterial3D] = []
var _beam_material: StandardMaterial3D
var _timer_touched: bool = false
var _signs: Array[Label3D] = []
var _sign_looks: Array = []
var _signs_touched: bool = false


func setup(game_world: Node) -> void :
	world = game_world
	name = "ExitAlarm"
	for path: String in ALARM_PATHS:
		_streams.append(load(path) as AudioStream if ResourceLoader.exists(path) else null)
	_alarm = AudioStreamPlayer.new()
	_alarm.bus = &"PaperFeedback"
	add_child(_alarm)
	var root: Control = world.ui.root
	_grade = _overlay(GRADE_SHADER)
	_grade_material = _grade.material
	_glow = _overlay(GLOW_SHADER)
	_glow_material = _glow.material
	var anchor: int = world.ui.screen_fx.get_index() + 1 if is_instance_valid(world.ui.screen_fx) else 0
	root.add_child(_grade)
	root.move_child(_grade, anchor)
	root.add_child(_glow)
	root.move_child(_glow, anchor + 1)
	_banner = Control.new()
	_banner.name = "ExitBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	_banner.draw.connect(_draw_banner)
	world.ui.hud.add_child(_banner)
	# au-dessus de la liste des élèves (sinon les cartes mordent sur le bandeau), sous la carte du perso et les capacités
	var roster: Control = world.ui.hud.get("roster")
	world.ui.hud.move_child(_banner, roster.get_index() + 1 if roster and roster.get_parent() == world.ui.hud else 0)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_compass = Control.new()
	_compass.name = "ExitCompass"
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.custom_minimum_size = Vector2(250, 36)
	_compass.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_compass.visible = false
	_compass.draw.connect(_draw_compass)
	var top: Control = world.ui.hud.get("top_box")
	if top:
		top.add_child(_compass)
		var objective: Control = world.ui.hud.get("objective_panel")
		if objective: top.move_child(_compass, objective.get_index() + 1)
	else: world.ui.hud.add_child(_compass)

func _exit_tree() -> void :
	if is_instance_valid(_alarm):
		_alarm.stop()
		_alarm.stream = null
	_streams.clear()

func _overlay(code: String) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = Color.WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader: Shader = Shader.new()
	shader.code = code
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	rect.visible = false
	return rect




func calm() -> bool:
	return bool(world.options.get("reduce_flashes", false))

func screen_effects() -> bool:
	return bool(world.options.get("screen_fx", true))

func light_profile() -> bool:
	return bool(world.get("mobile_mode")) and str(world.get("mobile_profile")) in ["performance", "battery"]

func is_open() -> bool:
	return _open

func level() -> float:
	return _level

func rush() -> float:
	return _rush

func pulse() -> float:
	return _pulse

func final_stretch() -> bool:
	return _open and float(world.time_left) <= RUSH_SPAN - RUSH_LEAD - FINAL_CALL

func viewer_is_killer() -> bool:
	var me: PaperActor = world.local_actor()
	return me != null and me.killer


func exit_bearing() -> Vector2:
	var school: Node = world.school
	var view: PaperActor = world.call("_view_actor")
	var camera: Camera3D = world.camera
	if not is_instance_valid(school) or view == null or camera == null: return Vector2(0.0, -1.0)
	var target: Vector3 = school.escape_position
	var offset: Vector3 = target - view.position
	offset.y = 0.0
	var distance: float = offset.length()
	if distance < 0.01: return Vector2(0.0, 0.0)
	var forward: Vector3 = - camera.global_basis.z
	forward.y = 0.0
	var right: Vector3 = camera.global_basis.x
	right.y = 0.0
	if forward.length_squared() < 0.0001: return Vector2(0.0, distance)
	var direction: Vector3 = offset / distance
	return Vector2(atan2(direction.dot(right.normalized()), direction.dot(forward.normalized())), distance)




func _process(delta: float) -> void :
	if not is_instance_valid(world): return
	_clock += delta
	var phase: String = str(world.phase)
	var playing: bool = phase == "playing" and not bool(world.training)
	var flow: PaperEscapeFlow = world.exit_flow
	var open: bool = playing and flow != null and flow.opened
	if open and not _open: _on_open()
	elif not open and _open: _on_close()
	_open = open
	if open: _since += delta
	_rush = clampf((RUSH_SPAN - float(world.time_left)) / RUSH_SPAN, 0.0, 1.0) if open else 0.0
	var audio: PaperAudio = world.audio
	var music: bool = open and not bool(world.lms)
	if audio and audio.has_method("set_rush"):
		var frozen: bool = bool(world.pause_open) and not bool(world.networked)
		audio.set_rush(_rush if music else 0.0, RUSH_SPAN - float(world.time_left) - RUSH_LEAD if music else -1.0, frozen)
		audio.heartbeat_floor = _heart_floor() if open else 0.0
	if open and not _final_done and final_stretch():
		_final_done = true
		_final_call()
	var cinematic: bool = world.ui.film_layer.visible if is_instance_valid(world.ui) and world.ui.get("film_layer") else false
	var goal: float = 1.0 if open and not cinematic else 0.0
	_level = move_toward(_level, goal, delta * (2.6 if goal > _level else (0.9 if playing else 2.5)))
	_update_pulse(delta)
	_update_screen()
	_update_lamps()
	_update_environment()
	_update_rig(delta)
	_update_signs()
	_update_timer()
	_update_hud(delta)
	if phase in ["menu", "lobby", "loading"]:
		_round_seen = -1
		_final_done = false
		# partie quittée pendant l'alerte : la sirène ne suit pas le joueur au menu
		if _alarm.playing: _alarm.stop()

func _heart_floor() -> float:
	var me: PaperActor = world.local_actor()
	if bool(world.lms) or me == null or me.killer or not me.alive or bool(me.effects.get("escaped", false)): return 0.0
	if _since < RUSH_LEAD: return 0.6
	return 0.38 + 0.37 * smoothstep(0.62, 0.8, _rush)

func _on_open() -> void :
	_since = 0.0
	var serial: int = int(world.round_serial)
	var first: bool = _round_seen != serial
	_round_seen = serial
	_final_done = final_stretch()
	_play_alarm(0, -7.0 if bool(world.lms) or not first else -4.0)
	if not calm():
		world.add_camera_trauma(0.8)
		if is_instance_valid(world.ui.screen_fx):
			world.ui.screen_fx.pulse(Color(1.0, 0.08, 0.1, 0.62), 1.6)
			world.ui.screen_fx.frame(Color(1.0, 0.25, 0.2, 0.22), 0.12)
	else:
		world.add_camera_trauma(0.4)
		if is_instance_valid(world.ui.screen_fx): world.ui.screen_fx.pulse(Color(0.9, 0.08, 0.1, 0.4), 2.0)
	if world.bindings and world.local_actor() != null: world.bindings.rumble(0.7)
	show_banner("LA SORTIE EST OUVERTE" if first else "LA SORTIE SE ROUVRE", BANNER_SECONDS if first else 2.8)

func _on_close() -> void :
	_banner_time = minf(_banner_time, 0.3)

func _final_call() -> void :
	_play_alarm(1, -9.0 if bool(world.lms) else -4.5)
	world.add_camera_trauma(0.35 if calm() else 0.6)
	if is_instance_valid(world.ui.screen_fx) and not calm(): world.ui.screen_fx.pulse(Color(1.0, 0.1, 0.1, 0.5), 1.0)
	show_banner("DERNIÈRES SECONDES", 2.4)

func _play_alarm(index: int, gain_db: float) -> void :
	var audio: PaperAudio = world.audio
	if audio == null or audio.muted or index >= _streams.size() or _streams[index] == null: return
	if audio.effects_volume <= 0.001: return
	_alarm.stream = _streams[index]
	_alarm.volume_db = gain_db + audio.volume_to_db(audio.effects_volume)
	_alarm.play()



func _update_pulse(delta: float) -> void :
	if _level <= 0.0:
		_pulse = 0.0
		return
	if calm():
		_pulse = 0.5 + 0.5 * sin(_clock * TAU / 3.2)
		_pulse *= 0.35
		return
	if bool(world.lms):
		# la musique de LMS garde la priorité : pas de pulsation calée sur un autre tempo
		_pulse = 0.25 + 0.4 * pow(0.5 + 0.5 * sin(_clock * TAU / 1.6), 2.0)
		if _since < 0.8: _pulse = maxf(_pulse, 1.0 - _since / 0.8)
		return
	var step: int = 1 if final_stretch() else 2
	var beat: float = world.audio.rush_beat() if world.audio and world.audio.has_method("rush_beat") else -1.0
	if beat < 0.0: beat = _clock / (60.0 / 128.0)
	var index: int = floori(beat / float(step))
	if index != _last_beat:
		_last_beat = index
		_beat_index += 1
	var since: float = fposmod(beat, float(step)) * (60.0 / 128.0)
	var strength: float = lerpf(0.55, 1.0, _rush)
	_pulse = exp( - since / (0.16 if step == 1 else 0.24)) * strength
	if _since < 0.8: _pulse = maxf(_pulse, 1.0 - _since / 0.8)

func _update_screen() -> void :
	var shown: bool = _level > 0.002 and screen_effects()
	# profils mobiles légers : pas de copie de l'écran, seulement le halo additif
	var grade_shown: bool = shown and not light_profile()
	if _grade.visible != grade_shown: _grade.visible = grade_shown
	if _glow.visible != shown: _glow.visible = shown
	if not shown: return
	var amount: float = _level * (0.55 if calm() else 1.0)
	if grade_shown:
		_grade_material.set_shader_parameter("level", amount)
		_grade_material.set_shader_parameter("pulse", _pulse)
	if shown:
		_glow_material.set_shader_parameter("level", amount * (0.5 if calm() else 1.0))
		_glow_material.set_shader_parameter("pulse", _pulse)
		_glow_material.set_shader_parameter("sweep", _clock * (1.2 if calm() else 3.4))
		_glow_material.set_shader_parameter("sweep_amount", 0.4 if calm() else 1.0)
		_glow_material.set_shader_parameter("aspect", _glow.size.x / maxf(1.0, _glow.size.y))



func _update_lamps() -> void :
	if _level <= 0.001:
		if _lamps_touched: _restore_lamps()
		return
	if not _lamps_touched or (not _lamps.is_empty() and not is_instance_valid(_lamps[0])): _collect_lamps()
	var flicker_owned: bool = float(world.teleport_warning) > 0.0
	for index: int in range(_lamps.size()):
		if not is_instance_valid(_lamps[index]): continue
		var lamp: Light3D = _lamps[index]
		lamp.light_color = _lamp_colors[index].lerp(LAMP_RED, 0.9 * _level)
		if flicker_owned and lamp is OmniLight3D: continue
		var factor: float
		if calm(): factor = 0.85 + 0.15 * _pulse
		else:
			var lit: bool = (_beat_index + index) % 2 == 0 or final_stretch()
			factor = 0.42 + (1.1 * _pulse if lit else 0.12 * _pulse)
		lamp.light_energy = _lamp_energies[index] * lerpf(1.0, factor * 1.25, _level)

func _collect_lamps() -> void :
	if _lamps_touched: _restore_lamps()
	_lamps.clear()
	_lamp_colors.clear()
	_lamp_energies.clear()
	if not is_instance_valid(world.school): return
	for node: Node in world.school.find_children("*", "Light3D", true, false):
		if not (node is OmniLight3D or node is SpotLight3D): continue
		if is_instance_valid(_rig) and _rig.is_ancestor_of(node): continue
		var lamp: Light3D = node
		_lamps.append(lamp)
		_lamp_colors.append(lamp.light_color)
		var at: int = world.warning_lamps.find(lamp)
		_lamp_energies.append(float(world.warning_energies[at]) if at >= 0 and at < world.warning_energies.size() else lamp.light_energy)
	_lamps_touched = true

func _restore_lamps() -> void :
	for index: int in range(_lamps.size()):
		if not is_instance_valid(_lamps[index]): continue
		var lamp: Light3D = _lamps[index]
		lamp.light_color = _lamp_colors[index]
		if not (float(world.teleport_warning) > 0.0 and lamp is OmniLight3D): lamp.light_energy = _lamp_energies[index]
	_lamps.clear()
	_lamp_colors.clear()
	_lamp_energies.clear()
	_lamps_touched = false

func _update_environment() -> void :
	var environment: Environment = world.environment
	if environment == null: return
	if _level <= 0.001:
		if _environment_touched:
			_environment_touched = false
			environment.ambient_light_color = _environment_base[0]
			environment.ambient_light_energy = _environment_base[1]
			environment.fog_light_color = _environment_base[2]
		return
	if not _environment_touched:
		_environment_touched = true
		_environment_base = [environment.ambient_light_color, environment.ambient_light_energy, environment.fog_light_color]
	var breathe: float = 0.12 * _pulse
	environment.ambient_light_color = (_environment_base[0] as Color).lerp(AMBIENT_RED, (0.5 + breathe) * _level)
	environment.ambient_light_energy = float(_environment_base[1]) * (1.0 + (0.12 + breathe) * _level)
	environment.fog_light_color = (_environment_base[2] as Color).lerp(FOG_RED, 0.55 * _level)



func _update_rig(delta: float) -> void :
	if _level <= 0.001:
		if is_instance_valid(_rig) and _rig.visible: _rig.hide()
		return
	if not is_instance_valid(_rig) or _rig.get_parent() != world.school: _build_rig()
	if not _rig.visible: _rig.show()
	var calm_mode: bool = calm()
	_rig_light.light_energy = _level * (2.3 + (0.4 if calm_mode else 1.5) * _pulse)
	var spin: float = TAU * (0.35 if calm_mode else 0.95)
	for index: int in range(_beacons.size()):
		var pivot: Node3D = _beacons[index]
		pivot.rotation.y += delta * spin * (1.0 if index == 0 else -1.0)
		var light: SpotLight3D = _beacon_lights[index]
		light.visible = not light_profile()
		light.light_energy = _level * (4.0 if calm_mode else 7.5)
		_beacon_domes[index].emission_energy_multiplier = 1.2 + 2.6 * _level * (0.6 if calm_mode else 0.4 + 0.6 * _pulse)
	_beam_material.albedo_color = Color(BEACON_RED, 0.24 * _level * (0.6 if calm_mode else 1.0))

func _build_rig() -> void :
	if is_instance_valid(_rig): _rig.queue_free()
	_beacons.clear()
	_beacon_lights.clear()
	_beacon_domes.clear()
	var school: Node3D = world.school
	_rig = Node3D.new()
	_rig.name = "ExitAlarmRig"
	school.add_child(_rig)
	var base: Vector3 = school.escape_position
	_rig.position = base
	var outward: Vector3 = Vector3(base.x, 0.0, base.z)
	outward = outward.normalized() if outward.length_squared() > 1.0 else Vector3.BACK
	var side: Vector3 = Vector3.UP.cross(outward).normalized()
	_rig_light = OmniLight3D.new()
	_rig_light.light_color = EXIT_GLOW
	_rig_light.omni_range = 15.0
	_rig_light.omni_attenuation = 0.8
	_rig_light.shadow_enabled = false
	_rig_light.position = Vector3.UP * 2.6 - outward * 1.2
	_rig.add_child(_rig_light)
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_material.no_depth_test = false
	_beam_material.disable_receive_shadows = true
	var fade: GradientTexture2D = GradientTexture2D.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.0))
	gradient.set_color(1, Color(1, 1, 1, 1.0))
	fade.gradient = gradient
	fade.fill_from = Vector2(0.5, 1.0)
	fade.fill_to = Vector2(0.5, 0.0)
	_beam_material.albedo_texture = fade
	var pole_material: StandardMaterial3D = StandardMaterial3D.new()
	pole_material.albedo_color = Color("2a2730")
	for sign_value: float in [-1.0, 1.0]:
		var post: Vector3 = side * 2.75 * sign_value - outward * 0.4
		var pole: MeshInstance3D = MeshInstance3D.new()
		var pole_mesh: BoxMesh = BoxMesh.new()
		pole_mesh.size = Vector3(0.12, 3.3, 0.12)
		pole.mesh = pole_mesh
		pole.material_override = pole_material
		pole.position = post + Vector3.UP * 1.65
		_rig.add_child(pole)
		var pivot: Node3D = Node3D.new()
		pivot.position = post + Vector3.UP * 3.42
		pivot.rotation.y = 0.0 if sign_value < 0.0 else PI
		_rig.add_child(pivot)
		var socket: MeshInstance3D = MeshInstance3D.new()
		var socket_mesh: CylinderMesh = CylinderMesh.new()
		socket_mesh.top_radius = 0.24
		socket_mesh.bottom_radius = 0.28
		socket_mesh.height = 0.14
		socket_mesh.radial_segments = 16
		socket.mesh = socket_mesh
		socket.material_override = pole_material
		socket.position = post + Vector3.UP * 3.3
		_rig.add_child(socket)
		var dome: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.42
		dome.mesh = sphere
		var dome_material: StandardMaterial3D = StandardMaterial3D.new()
		dome_material.albedo_color = BEACON_RED
		dome_material.emission_enabled = true
		# rouge profond : multiplié par l'émission, le rouge clair virait au jaune (lampadaire)
		dome_material.emission = DOME_RED
		dome_material.emission_energy_multiplier = 2.0
		dome.material_override = dome_material
		pivot.add_child(dome)
		var light: SpotLight3D = SpotLight3D.new()
		light.light_color = BEACON_RED
		light.spot_range = 24.0
		light.spot_angle = 20.0
		light.spot_attenuation = 0.7
		light.shadow_enabled = false
		light.rotation.x = -0.12
		pivot.add_child(light)
		var beam: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.08
		cone.bottom_radius = 2.4
		cone.height = 9.0
		cone.radial_segments = 14
		cone.cap_top = false
		cone.cap_bottom = false
		beam.mesh = cone
		beam.material_override = _beam_material
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.rotation.x = -PI * 0.5 - 0.12
		beam.position = Vector3(0.0, -0.55, -4.5)
		pivot.add_child(beam)
		_beacons.append(pivot)
		_beacon_lights.append(light)
		_beacon_domes.append(dome_material)


func _update_signs() -> void :
	if _level <= 0.001:
		if _signs_touched: _restore_signs()
		return
	if not _signs_touched or (not _signs.is_empty() and not is_instance_valid(_signs[0])): _collect_signs()
	for index: int in range(_signs.size()):
		if not is_instance_valid(_signs[index]): continue
		var label: Label3D = _signs[index]
		var look: Array = _sign_looks[index]
		label.modulate = (look[0] as Color).lerp(SIGN_GREEN, _level)
		label.outline_modulate = (look[1] as Color).lerp(SIGN_INK, _level)
		label.outline_size = int(round(lerpf(float(look[2]), 14.0, _level)))

# Seuls les panneaux posés par la carte (enfants directs de school, près de l'issue) :
# celui de map_interactables est déjà recoloré chaque image par update_exit.
func _collect_signs() -> void :
	if _signs_touched: _restore_signs()
	_signs_touched = true
	if not is_instance_valid(world.school): return
	var exit_at: Vector3 = world.school.escape_position
	for node: Node in world.school.get_children():
		if not node is Label3D: continue
		var label: Label3D = node
		var offset: Vector3 = label.position - exit_at
		if Vector2(offset.x, offset.z).length() > 9.0 or offset.y < 2.0: continue
		_signs.append(label)
		_sign_looks.append([label.modulate, label.outline_modulate, label.outline_size])

func _restore_signs() -> void :
	for index: int in range(_signs.size()):
		if not is_instance_valid(_signs[index]): continue
		var label: Label3D = _signs[index]
		var look: Array = _sign_looks[index]
		label.modulate = look[0]
		label.outline_modulate = look[1]
		label.outline_size = int(look[2])
	_signs.clear()
	_sign_looks.clear()
	_signs_touched = false



func _update_timer() -> void :
	var label: Label = world.ui.hud.get("timer_label") if is_instance_valid(world.ui) else null
	if label == null: return
	if _level <= 0.001:
		if _timer_touched:
			_timer_touched = false
			label.modulate = Color.WHITE
			label.scale = Vector2.ONE
		return
	_timer_touched = true
	var heat: float = _level * lerpf(0.35, 1.0, _rush)
	var red: Color = Color(1.0, 0.36, 0.36).lerp(Color(1.0, 0.18, 0.2), _pulse)
	label.modulate = Color.WHITE.lerp(red, heat)
	label.pivot_offset = label.size * 0.5
	var bump: float = 0.0 if calm() or not final_stretch() else 0.1 * _pulse
	label.scale = Vector2.ONE * (1.0 + bump)


func show_banner(title: String, seconds: float) -> void :
	_banner_title = title
	_banner_time = maxf(0.5, seconds)
	_banner_clock = 0.0
	_banner.visible = true
	_banner.queue_redraw()

func _update_hud(delta: float) -> void :
	if _banner.visible:
		_banner_time -= delta
		_banner_clock += delta
		if _banner_time <= 0.0 or str(world.phase) != "playing": _banner.visible = false
		else: _banner.queue_redraw()
	var view: PaperActor = world.call("_view_actor")
	var wanted: bool = _open and view != null and view.alive
	_compass_alpha = move_toward(_compass_alpha, 1.0 if wanted else 0.0, delta * 3.0)
	var shown: bool = _compass_alpha > 0.01
	if _compass.visible != shown: _compass.visible = shown
	if shown: _compass.queue_redraw()




func draw_arrow(item: CanvasItem, center: Vector2, angle: float, length: float, color: Color) -> void :
	var shape: Array[Vector2] = [Vector2(0.0, -0.5), Vector2(0.4, -0.04), Vector2(0.14, -0.04), Vector2(0.14, 0.5), Vector2(-0.14, 0.5), Vector2(-0.14, -0.04), Vector2(-0.4, -0.04)]
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in shape: points.append(center + (point * length).rotated(angle))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	item.draw_polyline(outline, Color(0.08, 0.0, 0.02, color.a), 3.0, true)
	item.draw_colored_polygon(points, color)




func _draw_banner() -> void :
	var canvas: Control = _banner
	var quiet: bool = calm()
	var viewport: Vector2 = canvas.size
	var enter: float = clampf(_banner_clock / 0.22, 0.0, 1.0)
	var leave: float = clampf(_banner_time / 0.35, 0.0, 1.0)
	var shown: float = minf(enter, leave)
	var ease_in: float = 1.0 - pow(1.0 - enter, 3.0)
	var center: Vector2 = Vector2(viewport.x * 0.5, viewport.y * 0.3)
	var shake: Vector2 = Vector2.ZERO
	if not quiet and _banner_clock < 0.6:
		var k: float = (1.0 - _banner_clock / 0.6) * 9.0
		shake = Vector2(sin(_banner_clock * 91.0) * k, cos(_banner_clock * 77.0) * k * 0.6)
	var band_height: float = clampf(viewport.y * 0.17, 96.0, 150.0)
	var slide: float = (1.0 - ease_in) * viewport.x * (0.0 if quiet else -1.0)
	var exit_slide: float = (1.0 - leave) * viewport.x * (0.0 if quiet else 0.6)
	var skew: float = -0.07
	var glow: float = _pulse
	var alpha: float = shown if quiet else 1.0
	var origin: Vector2 = center + shake + Vector2(slide + exit_slide, 0.0)
	canvas.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(skew, 1), origin))
	var half: float = band_height * 0.5
	var width: float = viewport.x * 1.4
	canvas.draw_rect(Rect2(Vector2(-width * 0.5, -half - 10.0), Vector2(width, band_height + 20.0)), Color(0.02, 0.0, 0.01, 0.82 * alpha))
	var red: Color = Color(0.74, 0.04, 0.1).lerp(Color(0.95, 0.12, 0.16), glow * (0.3 if quiet else 1.0))
	canvas.draw_rect(Rect2(Vector2(-width * 0.5, -half), Vector2(width, band_height)), Color(red, 0.94 * alpha))
	var stripe: float = 26.0
	var offset: float = fposmod(_banner_clock * (20.0 if quiet else 90.0), stripe * 2.0)
	for edge_y: float in [-half - 10.0, half]:
		var x: float = -width * 0.5 - stripe * 2.0 + offset
		while x < width * 0.5:
			var points: PackedVector2Array = PackedVector2Array([Vector2(x, edge_y), Vector2(x + stripe, edge_y), Vector2(x + stripe + 10.0, edge_y + 10.0), Vector2(x + 10.0, edge_y + 10.0)])
			canvas.draw_colored_polygon(points, Color(0.98, 0.84, 0.3, 0.9 * alpha))
			x += stripe * 2.0
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var title: String = T.tr_text(_banner_title)
	var font: Font = T.font("display")
	var font_size: int = int(clampf(viewport.y * 0.085, 44.0, 96.0))
	var pop: float = 1.0 if quiet else 1.0 + 0.35 * pow(1.0 - ease_in, 2.0)
	var text_size: Vector2 = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var scale_fit: float = minf(pop, viewport.x * 0.9 / maxf(1.0, text_size.x))
	canvas.draw_set_transform(origin + Vector2(0.0, band_height * 0.08), 0.0, Vector2.ONE * scale_fit)
	var baseline: Vector2 = Vector2(-text_size.x * 0.5, font_size * 0.32)
	canvas.draw_string(font, baseline + Vector2(5, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.05, 0.0, 0.02, 0.75 * alpha))
	canvas.draw_string_outline(font, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 10, Color(0.12, 0.0, 0.03, alpha))
	canvas.draw_string(font, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.97, 0.9, alpha))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var bearing: Vector2 = exit_bearing()
	var killer: bool = viewer_is_killer()
	var order: String = T.tr_text("EMPÊCHEZ LEUR FUITE") if killer else T.tr_text("FUYEZ !")
	var line: String = "%s   ·   %s %d m" % [order, T.tr_text("SORTIE"), int(round(bearing.y))]
	var small: Font = T.font("caps_wide")
	var small_size: int = int(clampf(viewport.y * 0.03, 17.0, 30.0))
	var line_size: Vector2 = small.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size)
	var arrow_size: float = small_size * 1.25
	var row_width: float = line_size.x + arrow_size + 16.0
	var row: Vector2 = Vector2(center.x + shake.x * 0.5 - row_width * 0.5 + (slide + exit_slide) * 0.6, center.y + band_height * 0.5 + 18.0 + small_size)
	var panel: Rect2 = Rect2(row + Vector2(-18.0, -small_size - 10.0), Vector2(row_width + 36.0, small_size + 24.0))
	canvas.draw_rect(panel, Color(0.03, 0.0, 0.02, 0.86 * alpha))
	canvas.draw_rect(panel, Color(0.98, 0.84, 0.3, 0.9 * alpha), false, 2.0)
	draw_arrow(canvas, row + Vector2(arrow_size * 0.5, -small_size * 0.36), bearing.x, arrow_size, Color(0.98, 0.84, 0.3, alpha))
	canvas.draw_string(small, row + Vector2(arrow_size + 16.0, 0.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size, Color(1.0, 0.95, 0.86, alpha))

func _draw_compass() -> void :
	var canvas: Control = _compass
	var bearing: Vector2 = exit_bearing()
	var glow: float = _pulse
	var closing: bool = final_stretch()
	var font: Font = T.font("caps_wide")
	var font_size: int = 17
	var text: String = "%s · %d m" % [T.tr_text("SORTIE"), int(round(bearing.y))]
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width: float = text_width + 62.0
	var origin: Vector2 = Vector2((canvas.size.x - width) * 0.5, 0.0)
	var rect: Rect2 = Rect2(origin, Vector2(width, 34.0))
	var red: Color = Color(0.55, 0.03, 0.08).lerp(Color(0.9, 0.08, 0.14), glow if closing else glow * 0.4)
	canvas.draw_rect(rect, Color(red, 0.88 * _compass_alpha))
	canvas.draw_rect(rect, Color(0.98, 0.84, 0.3, 0.85 * _compass_alpha), false, 2.0)
	draw_arrow(canvas, origin + Vector2(22.0, 17.0), bearing.x, 24.0, Color(0.98, 0.84, 0.3, _compass_alpha))
	canvas.draw_string(font, origin + Vector2(42.0, 24.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.95, 0.88, _compass_alpha))
