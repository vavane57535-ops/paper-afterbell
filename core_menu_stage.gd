extends RefCounted










const LINEUP_ORDER: Array[String] = ["Bleuette", "Usayuko", "Ashura", "Simon", "Elly", "Lysia"]
const ARC_RADIUS: float = 6.0
const SPACING: float = 0.88
const CENTER_GAP: float = 0.5
const ALICE_DEPTH: float = 2.2


const STAGE_FORWARD: float = 1.2

const ALICE_SCALE: float = 1.3

const LINEUP_FOV: float = 31.0
const LINEUP_WIDTH: float = 5.5
const LINEUP_SCREEN_SHARE: float = 0.5
const LINEUP_YAW: float = 0.16
const LINEUP_PITCH: float = -0.12
const LINEUP_AIM_HEIGHT: float = 1.02

const FOCUS_FOV: float = 30.0

const FOCUS_EYES_AT: float = 0.34
const FOCUS_FEET_AT: float = 0.9

const EYE_ABOVE_HEAD_JOINT: float = 0.12
const FOCUS_YAW: float = 0.2
const FOCUS_LOW_ANGLE: float = 0.07
const CAMERA_EASE: float = 3.2


const STAGE_LAYER: int = 1 << 10
const IDLE_EMOTES: Array[String] = ["wave", "thumbsup", "shrug", "laugh", "point"]

const PERSONAL_EMOTES: Dictionary = {
	"Bleuette": ["cheer", "wave", "laugh"], "Usayuko": ["laugh", "thumbsup", "point"], 
	"Ashura": ["thumbsup", "shrug", "point"], "Simon": ["point", "wave", "thumbsup"], 
	"Elly": ["wave", "shrug"], "Lysia": ["point", "shrug", "wave"], 
}
const GREETINGS: Dictionary = {"Bleuette": "cheer", "Usayuko": "thumbsup", "Ashura": "wave", "Simon": "wave", "Elly": "wave", "Lysia": "wave"}
const EMOTE_LENGTH: float = 2.5

var world: Node
var root: Node3D
var models: Array[PaperVisual] = []
var base: Vector3 = Vector3.ZERO
var key_light: SpotLight3D
var rim_light: SpotLight3D
var alice_light: OmniLight3D
var _states: Array[Dictionary] = []
var _base_yaw: PackedFloat32Array = PackedFloat32Array()
var _tempo: PackedFloat32Array = PackedFloat32Array()
var _emote_model: int = -1
var _emote_time: float = 0.0
var _emote_wait: float = 5.0
var _focus_name: String = ""
var _camera_ready: bool = false
var _clock: float = 0.0
var _layers_tagged: bool = false


func build(owner: Node, spawn: Vector3, detailed_lights: bool) -> Node3D:
	world = owner
	base = spawn + Vector3(0.0, 0.0, STAGE_FORWARD)
	root = Node3D.new()
	root.name = "MenuStage"
	owner.add_child(root)
	models.clear()
	_states.clear()
	_base_yaw.clear()
	_tempo.clear()
	var focal: Vector3 = Vector3(0.0, 0.0, 9.0)
	for index: int in range(LINEUP_ORDER.size()):
		var side: float = -1.0 if index < 3 else 1.0
		var along: float = (float(index) - 2.5) * SPACING + side * CENTER_GAP * 0.5
		var angle: float = along / ARC_RADIUS
		var local: Vector3 = Vector3(sin(angle) * ARC_RADIUS, 0.0, (1.0 - cos(angle)) * ARC_RADIUS)

		local.z += 0.18 if index % 2 == 0 else -0.08
		_add_model(LINEUP_ORDER[index], local, focal, index)
	_add_model("Alice", Vector3(0.0, 0.0, - ALICE_DEPTH), focal, LINEUP_ORDER.size(), ALICE_SCALE)
	_build_lights(detailed_lights)
	_camera_ready = false
	return root

func _add_model(person: String, local: Vector3, focal: Vector3, index: int, size: float = 1.0) -> void :

	var holder: Node3D = root
	if not is_equal_approx(size, 1.0):
		holder = Node3D.new()
		holder.name = person + "Pivot"
		root.add_child(holder)
		holder.position = base + local
		holder.scale = Vector3.ONE * size
	var visual: PaperVisual = PaperVisual.new()
	holder.add_child(visual)
	visual.setup(person)
	_tag_layers(visual)

	var effects: Variant = world.get("presentation")
	if is_instance_valid(effects) and effects.has_method("visual_fx"): visual.anim_fx.connect(effects.visual_fx.bind(visual))
	if holder == root:
		visual.position = base + local

	var yaw: float = atan2(local.x - focal.x, local.z - focal.z)
	visual.rotation.y = yaw
	models.append(visual)
	_base_yaw.append(yaw)
	_tempo.append(0.9 + 0.045 * float((index * 5) % 7))
	_states.append({})

func _build_lights(detailed: bool) -> void :

	key_light = SpotLight3D.new()
	key_light.name = "MenuKey"
	key_light.light_color = Color("ffcf98")
	key_light.light_energy = 4.6
	key_light.spot_range = 17.0
	key_light.spot_angle = 34.0
	key_light.spot_attenuation = 0.9


	key_light.shadow_enabled = false
	key_light.light_cull_mask = STAGE_LAYER
	root.add_child(key_light)
	key_light.transform = _aimed(base + Vector3(-4.2, 5.4, 8.0), base + Vector3(0.3, 0.9, 0.0))

	rim_light = SpotLight3D.new()
	rim_light.name = "MenuRim"
	rim_light.light_color = Color("7f9dff")
	rim_light.light_energy = 6.5 if detailed else 4.5
	rim_light.spot_range = 13.0
	rim_light.spot_angle = 40.0
	rim_light.shadow_enabled = false
	rim_light.light_cull_mask = STAGE_LAYER
	root.add_child(rim_light)
	rim_light.transform = _aimed(base + Vector3(4.6, 4.2, -5.2), base + Vector3(-0.4, 1.1, 0.4))

	alice_light = OmniLight3D.new()
	alice_light.name = "MenuAliceRim"
	alice_light.light_color = Color("ff2f4b")
	alice_light.light_energy = 7.5
	alice_light.omni_range = 5.0
	alice_light.omni_attenuation = 1.3
	alice_light.shadow_enabled = false
	alice_light.light_cull_mask = STAGE_LAYER

	alice_light.position = base + Vector3(0.9, 3.0, - ALICE_DEPTH - 0.8)
	root.add_child(alice_light)


static func _aimed(from: Vector3, to: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


func _tag_layers(node: Node) -> void :
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node
		geometry.layers |= STAGE_LAYER
	for child: Node in node.get_children():
		_tag_layers(child)


func animate(delta: float, preview: String) -> void :
	_clock += delta
	if not _layers_tagged and _clock > 0.5:

		_layers_tagged = true
		for visual: PaperVisual in models:
			if is_instance_valid(visual): _tag_layers(visual)
	if preview != _focus_name:
		_focus_name = preview
		_emote_model = -1
		_emote_wait = 0.35 if not preview.is_empty() else 3.5
	_update_emotes(delta, preview)
	for index: int in range(models.size()):
		var visual: PaperVisual = models[index]
		if not is_instance_valid(visual):
			continue
		var shown: bool = preview.is_empty() or visual.character_name == preview
		visual.visible = shown
		if not shown:
			continue
		var state: Dictionary = _states[index]
		if index == _emote_model:
			state["emote_time"] = _emote_time
		elif state.has("emote_id"):
			state.erase("emote_id")
			state.erase("emote_time")
		visual.set_combat_state(state)
		visual.animate(delta * _tempo[index], Vector3.ZERO, false, false)



func _update_emotes(delta: float, preview: String) -> void :
	if _emote_model >= 0:
		_emote_time += delta
		if _emote_time >= EMOTE_LENGTH:
			_emote_model = -1
			_emote_wait = randf_range(6.0, 10.0) if preview.is_empty() else 1000.0
		return
	_emote_wait -= delta
	if _emote_wait > 0.0:
		return
	var candidate: int = -1
	if preview.is_empty():
		candidate = randi() % LINEUP_ORDER.size()
	elif preview != "Alice":
		candidate = LINEUP_ORDER.find(preview)
	if candidate < 0:
		_emote_wait = 1000.0
		return
	_emote_model = candidate
	_emote_time = 0.0
	var person: String = LINEUP_ORDER[candidate]
	var choices: Array = PERSONAL_EMOTES.get(person, IDLE_EMOTES)
	_states[candidate]["emote_id"] = str(GREETINGS.get(person, "wave")) if not preview.is_empty() else str(choices[randi() % choices.size()])
	_states[candidate]["emote_time"] = 0.0


func _eye_height(visual: PaperVisual, person: String) -> float:
	var height: float = float(PaperData.HEIGHTS.get(person, 1.75)) * 0.88
	if visual.has_method("cinematic_focus_height"):
		height = float(visual.cinematic_focus_height()) + EYE_ABOVE_HEAD_JOINT
	var holder: Node3D = visual.get_parent() as Node3D
	if holder and holder != root:
		height *= holder.scale.y
	return clampf(height, 0.8, 3.2)

func model_for(person: String) -> PaperVisual:
	for visual: PaperVisual in models:
		if is_instance_valid(visual) and visual.character_name == person:
			return visual
	return null


func frame_camera(camera: Camera3D, delta: float, preview: String, preview_angle: float, focus_x: float) -> void :
	if not is_instance_valid(camera):
		return
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(1.0, viewport_size.y)
	var goal: Transform3D
	var fov: float = LINEUP_FOV
	var focused: PaperVisual = model_for(preview) if not preview.is_empty() else null
	if focused:
		fov = FOCUS_FOV
		goal = _focus_transform(focused, preview, preview_angle, focus_x, aspect, delta)
	else:
		goal = _lineup_transform(focus_x, aspect)
		for index: int in range(models.size()):
			if is_instance_valid(models[index]):
				models[index].rotation.y = lerp_angle(models[index].rotation.y, _base_yaw[index], minf(1.0, delta * 6.0))
	if not _camera_ready:
		_camera_ready = true
		camera.global_transform = goal
		camera.fov = fov
		return
	var weight: float = 1.0 - exp( - delta * CAMERA_EASE)
	camera.global_transform = camera.global_transform.interpolate_with(goal, weight)
	camera.fov = lerpf(camera.fov, fov, weight)

func reset_camera() -> void :
	_camera_ready = false



static func lateral_offset(focus_x: float, depth: float, fov_degrees: float, aspect: float) -> float:
	var tan_half_width: float = tan(deg_to_rad(fov_degrees) * 0.5) * aspect
	return (2.0 * clampf(focus_x, 0.05, 0.95) - 1.0) * depth * tan_half_width

func _lineup_transform(focus_x: float, aspect: float) -> Transform3D:
	var tan_half_width: float = tan(deg_to_rad(LINEUP_FOV) * 0.5) * aspect
	var distance: float = LINEUP_WIDTH / (LINEUP_SCREEN_SHARE * 2.0 * tan_half_width)

	var sway: float = sin(_clock * 0.083) * 0.035 + sin(_clock * 0.041) * 0.02
	var rise: float = sin(_clock * 0.061) * 0.06
	var dolly: float = sin(_clock * 0.052) * 0.3
	var yaw: float = LINEUP_YAW + sway
	var forward: Vector3 = Vector3(0.0, sin(LINEUP_PITCH), - cos(LINEUP_PITCH)).rotated(Vector3.UP, yaw)
	var subject: Vector3 = base + Vector3(0.0, LINEUP_AIM_HEIGHT, 0.2)
	var eye: Vector3 = subject - forward * (distance + dolly) + Vector3.UP * rise
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	eye -= right * lateral_offset(focus_x, distance, LINEUP_FOV, aspect)
	return Transform3D(Basis.looking_at(forward, Vector3.UP), eye)

func _focus_transform(visual: PaperVisual, person: String, preview_angle: float, focus_x: float, aspect: float, delta: float) -> Transform3D:
	var index: int = models.find(visual)
	var base_yaw: float = _base_yaw[index] if index >= 0 else PI
	visual.rotation.y = lerp_angle(visual.rotation.y, base_yaw + preview_angle, minf(1.0, delta * 7.0))
	var eyes: float = _eye_height(visual, person)
	var half_tan: float = tan(deg_to_rad(FOCUS_FOV) * 0.5)


	var eyes_ndc: float = 1.0 - 2.0 * FOCUS_EYES_AT
	var feet_ndc: float = 1.0 - 2.0 * FOCUS_FEET_AT
	var span: float = eyes / (eyes_ndc - feet_ndc)
	var distance: float = span / half_tan
	var aim_height: float = - feet_ndc * span
	var facing: Vector3 = Vector3( - sin(base_yaw), 0.0, - cos(base_yaw))
	var view_dir: Vector3 = ( - facing).rotated(Vector3.UP, FOCUS_YAW)
	var forward: Vector3 = Vector3(view_dir.x * cos(FOCUS_LOW_ANGLE), sin(FOCUS_LOW_ANGLE), view_dir.z * cos(FOCUS_LOW_ANGLE))
	var subject: Vector3 = visual.global_position + Vector3.UP * aim_height
	var eye: Vector3 = subject - forward * distance
	eye.y += sin(_clock * 0.07) * 0.025
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	eye -= right * lateral_offset(focus_x, distance, FOCUS_FOV, aspect)
	return Transform3D(Basis.looking_at(forward, Vector3.UP), eye)
