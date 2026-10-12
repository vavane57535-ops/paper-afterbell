extends Node3D
class_name PaperVisual




const G = preload("res://model_geometry.gd")
const AnimFace = preload("res://anim_face.gd")
const AnimStyle = preload("res://anim_style.gd")
const AnimClip = preload("res://anim_clip.gd")
const AnimLibrary = preload("res://anim_library.gd")
const AnimGait = preload("res://anim_gait.gd")



signal anim_cue(cue: String, strength: float)



signal anim_fx(cue: String)
const CharMaterials = preload("res://char_materials.gd")
const CharProps = preload("res://char_props.gd")

const CHARACTER_HEIGHTS: Dictionary = {"Usayuko": 1.87, "Simon": 1.75, "Ashura": 1.7, "Lysia": 1.75, "Elly": 1.9, "Bleuette": 1.65, "Alice": 1.75, "TrueForm": 3.0}
const EMOTES: Array[String] = ["wave", "thumbsup", "cheer", "laugh", "point", "shrug", "sad", "fear", "clap", "facepalm", "sulk", "heart", "taunt", "salute", "selfie", "bow", "beg", "sit"]

const MODEL_HEIGHT: float = 2.28

const FAR_DISTANCE: float = 15.0
const TRANSITION_TIME: float = 0.22



const ACTION_CLIPS: Dictionary = {

	"slash": "slash", "shadow reveal": "reveal", "shadow spike": "spike", "ombres / bond": "shadow", 
	"doubles d'ombre": "clones", "doubles d’ombre": "clones", "true form": "transform", 

	"drone": "drone", "roller boost": "", "drone mode": "mode_switch", "rapide / précis": "mode_switch", 

	"grab": "", "block / contre": "", "contre": "counter", "punch": "punch", "dropkick": "dropkick", 

	"flashbang": "flash_throw", "flashbang / poing": "flash_throw", "flash punch": "flash_punch", 
	"flash mode": "mode_switch", "lancer / poing": "mode_switch", "boost de vitesse": "", "course éclair": "", 

	"surchauffe": "", "consommation": "push", "xray": "xray", "recharge électrique": "", 

	"soin": "", "zone de soin": "heal_zone", "shotgun": "shotgun", 

	"boost": "encourage", "encourager": "encourage", "je crois en toi": "believe", "chocolat": "", 
	"je peux le faire !": "power_up", "je peux le faire": "power_up", 
}



var lightweight: bool = false

var blob_shadow: bool = true

var lod_enabled: bool = true

var character_name: String = "Ashura"

var mood_override: String = ""
var _move_blend: float = 0.0
var _stun_blend: float = 0.0
var _ankles: Dictionary = {}
var _toes: Dictionary = {}
var _body: Node3D
var _spine: Node3D
var _chest: Node3D
var _neck: Node3D
var _head: Node3D
var _left_clav: Node3D
var _right_clav: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_elbow: Node3D
var _right_elbow: Node3D
var _left_hand: Node3D
var _right_hand: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_knee: Node3D
var _right_knee: Node3D
var _aura: MeshInstance3D
var _aura_material: ShaderMaterial
var _aura_color: Color = Color(0, 0, 0, 0)
var _phase_body: Node3D
var _secondary: Array[Dictionary] = []
var _props: Dictionary = {}
var _prop_hands: Dictionary = {}
var _prop_wanted: Dictionary = {}
var _clock: float = 0.0
var _animation_delta: float = 1.0 / 60.0
var _gait: float = 0.0
var _gait_phase: float = 0.0
var _action: String = ""
var _action_time: float = 0.0
var _action_duration: float = 0.9
var _combat_state: Dictionary = {}
var _base_height: float = 0.89
var _is_alice: bool = false
var _clone: bool = false
var _last_velocity: Vector3 = Vector3.ZERO
var _last_yaw: float = 0.0
var _imported: PaperImportedCharacter
var _true_form: Node3D
var _host: Node3D
var _plug_tail: Node3D
var _plug_segments: Array[Node3D] = []
var _life_state: String = "alive"
var _life_clock: float = 0.0
var _hit_time: float = 0.0
var _hit_strength: float = 1.0
var _hit_push: Vector3 = Vector3.BACK
var _air_blend: float = 0.0
var _land_clock: float = 0.0
var _land_strength: float = 0.5
var _was_grounded: bool = true
var _last_vertical_speed: float = 0.0
var _crawl_cycle: float = 0.0
var _run_blend: float = 0.0
var _model_scale: float = 1.0
var _injury_blend: float = 0.0
var _injury_marks: Array[Node3D] = []
var _temperament: float = 0.0
var _blink_offset: float = 0.0
var _blink_period: float = 4.3

var _reveal_material: ShaderMaterial
var _outline_on: bool = false
var _outline_color: Color = Color(0, 0, 0, 0)
var _occluded: float = -1.0

var _local_velocity: Vector3 = Vector3.ZERO
var _accel_smooth: Vector3 = Vector3.ZERO
var _yaw_rate: float = 0.0
var _move_dir: Vector3 = Vector3.FORWARD
var _motion_primed: bool = false
var _lean_pitch: float = 0.0
var _lean_roll: float = 0.0

var _g_cadence: float = 0.0
var _g_stance: float = 0.6
var _g_sweep: float = 0.0
var _g_lift: float = 0.0
var _g_run: float = 0.0
var _g_sprint: float = 0.0
var _g_move: float = 0.0
var _g_boost: float = 0.0
var _g_flight: float = 0.0
var _g_pocket: float = 0.0
var _g_lift_off: Dictionary = {}
var _g_weights: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
var _g_par: PackedFloat32Array = PackedFloat32Array()
var _g_thigh: PackedFloat32Array = PackedFloat32Array()
var _g_knee: PackedFloat32Array = PackedFloat32Array()
var _g_ankle: PackedFloat32Array = PackedFloat32Array()
var _stride_factor: float = 1.0
var _arm_weight: float = 1.0

var _thigh_height: float = 0.9
var _ankle_height: float = 0.1
var _hip_half_width: float = 0.13
var _foot_rest_x: float = 0.22
var _toe_length: float = 0.06
var _leg_reach: float = 0.85

var _foot_rest: Dictionary = {-1: Vector3.ZERO, 1: Vector3.ZERO}
var _leg_length: Dictionary = {-1: 0.85, 1: 0.85}
var _hip_rest: Dictionary = {-1: Vector3.ZERO, 1: Vector3.ZERO}

var _foot_target: Dictionary = {}
var _foot_pitch: Dictionary = {}
var _plant_weight: float = 1.0
var _ik_legs: bool = false
var _ik_hand_left: bool = false
var _ik_hand_right: bool = false
var _ik_body: Transform3D = Transform3D.IDENTITY

var _signature: int = -1
var _transition_left: float = 0.0
var _transition_from: Array[Quaternion] = []
var _transition_body: Vector3 = Vector3.ZERO
var _joints: Array[Node3D] = []
var _split_done: bool = false

var _curl: float = 0.12
var _curl_override: float = -1.0

var _notifier: VisibleOnScreenNotifier3D
var _lod_counter: int = 0
var _lod_slot: int = 0
var _pending_dt: float = 0.0
var _sync_queued: bool = false
var _detail: int = 1

var _blob: MeshInstance3D
var _blob_timer: float = 0.0
var _blob_floor: float = 0.0
var _blob_normal: Vector3 = Vector3.UP
var _blob_found: bool = false
var _blob_strength: float = -1.0

var _st_grounded: bool = true
var _st_vertical: float = 0.0
var _st_emote: String = ""
var _st_emote_time: float = 0.0
var _st_roll: float = 0.0
var _st_spike: bool = false
var _st_grab: bool = false
var _st_grabbed: bool = false
var _st_forced: bool = false
var _st_heal: bool = false
var _st_grenade: float = 0.0
var _st_drone: float = 0.0
var _st_overheat: bool = false
var _st_overheat_hold: bool = false
var _st_boost_time: bool = false
var _st_view: bool = false
var _st_piloting: bool = false
var _st_grinding: bool = false
var _st_charge: float = 0.0
var _st_speed_boost: bool = false
var _st_sprinting: bool = false
var _st_carrying: bool = false
var _st_carried: bool = false
var _st_eating: float = 0.0
var _st_outlet: bool = false
var _st_chased: bool = false
var _st_lms: bool = false
var _st_om: bool = false
var _st_injured: bool = false
var _injury_side: float = 1.0
var _thigh_forward: Dictionary = {-1: 0.0, 1: 0.0}
var _props_attached: int = 0

var _style: Dictionary = {}
var _face_ctrl: AnimFace = AnimFace.new()
var _face_dt: float = 1.0 / 60.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _weight_side: float = 0.0
var _weight_target: float = 1.0
var _shift_timer: float = 3.0
var _look: Vector2 = Vector2.ZERO
var _look_speed: Vector2 = Vector2.ZERO
var _look_target: Vector2 = Vector2.ZERO
var _look_timer: float = 1.0
var _fatigue: float = 0.0
var _breath_phase: float = 0.0
var _idle_hips: Vector3 = Vector3.ZERO
var _idle_body: Vector3 = Vector3.ZERO
var _idle_chest: Vector3 = Vector3.ZERO
var _idle_head: Vector3 = Vector3.ZERO
var _idle_arm: Dictionary = {-1: Vector3(0, 0, -0.1), 1: Vector3(0, 0, 0.1)}
var _idle_elbow: Dictionary = {-1: 0.2, 1: 0.2}
var _idle_clav: float = 0.0
var _idle_feet: Dictionary = {}
var _idle_foot_yaw: Dictionary = {-1: 0.0, 1: 0.0}
var _feet_dirty: bool = false
var _clav_manual: bool = false
var _air_lead: int = 1
var _land_offset: float = 0.0
var _land_speed: float = 0.0
var _glance_back: float = 0.0
var _glance_timer: float = 2.0
var _glance_side: float = 1.0

var _hit_rot: Vector3 = Vector3.ZERO
var _hit_vel: Vector3 = Vector3.ZERO
var _hit_head: Vector3 = Vector3.ZERO
var _hit_head_vel: Vector3 = Vector3.ZERO
var _hit_arm: float = 0.0
var _hit_arm_vel: float = 0.0
var _hit_drop: float = 0.0
var _hit_drop_vel: float = 0.0

var _clip_turn: float = 0.0
var _clip_squash: float = 1.0
var _clip_flare: Dictionary = {-1: 0.0, 1: 0.0}
var _hold_left: float = 0.0
var _alert_blend: float = 0.0
var _step_beat: int = 0
var _st_block: bool = false
var _st_grab_hold: bool = false
var _st_knocked: bool = false
var _st_aim_flash: bool = false
var _st_overheat_dash: bool = false
var _st_blind: bool = false
var _st_shadow_hide: bool = false
var _boost_blend: float = 0.0
var _death_hold: float = 0.0
var _transition_time: float = TRANSITION_TIME
var _stun_snap: bool = false
var _was_shadow_hidden: bool = false
var _gait_previous: float = -1.0
var _combo: int = 0
var _combo_clock: float = -10.0

var _state_clocks: Dictionary = {}
var _tick_stamp: int = 0
var _tick_dt: float = 1.0 / 60.0
var _curl_left_override: float = -1.0
var _curl_left: float = 0.12
var _clip_shake: float = 0.0
var _clip_jaw: float = 0.0
var _clip_chatter: float = 0.0
var _clip_lid: float = 0.0
var _action_clip_time: float = 0.0
var _emote_clip_time: float = -1.0
var _emote_seen: String = ""
var _emote_seen_time: float = 0.0
var _shoulder_rest: Dictionary = {-1: Vector3(-0.2, 0.6, 0.0), 1: Vector3(0.2, 0.6, 0.0)}
var _arm_length: Dictionary = {-1: 0.55, 1: 0.55}
var _dead_clip: String = "dead"
var _fidget_time: float = -1.0
var _fidget_timer: float = 6.0
var _fidget_weight: float = 0.0
var _overlay_name: String = ""
var _overlay_time: float = 0.0
var _overlay_previous: float = -1.0
var _speak_left: float = 0.0
var _speak_intensity: float = 1.0

var _calm: bool = false

var last_cue: String = ""
var last_cue_time: float = 0.0
static var _camera_frame: int = -1
static var _camera_viewport: int = 0
static var _camera_position: Vector3 = Vector3.ZERO
static var _camera_valid: bool = false



func setup(person_name: String) -> void :
	character_name = person_name
	scale = Vector3.ONE
	_model_scale = 1.0
	_is_alice = person_name == "Alice"
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_clear_state()
	_temperament = float(absi(person_name.hash()) % 19) * 0.17
	_blink_offset = float(absi(person_name.hash()) % 100) * 0.067
	_blink_period = 4.3 + person_name.length() * 0.12
	_lod_slot = int(get_instance_id() % 4)
	_stride_factor = 0.87 if person_name == "Elly" else (1.08 if _is_alice else 1.0)
	_arm_weight = 0.74 if _is_alice else (0.82 if person_name == "Ashura" else 1.0)
	_injury_side = -1.0 if person_name in ["Ashura", "Elly", "Bleuette"] else 1.0
	_style = AnimStyle.for_character(person_name)
	_rng.seed = absi(person_name.hash()) + int(get_instance_id() % 997)
	_face_ctrl = AnimFace.new()
	_face_ctrl.setup(int(_rng.randi()))
	_shift_timer = _rng.randf_range(1.0, 5.0)
	_weight_target = 1.0 if _rng.randf() < 0.5 else -1.0
	_weight_side = _weight_target
	_fidget_timer = _rng.randf_range(3.0, 12.0)
	if not ResourceLoader.exists("res://models/supplied/" + person_name + ".glb"):
		push_error("PaperVisual: no supplied model for " + person_name)
		return
	_setup_supplied_model()
	_finish_model()

func _clear_state() -> void :
	_free_detached_props()
	_props_attached = 0
	_secondary.clear();_props.clear();_prop_hands.clear();_prop_wanted.clear();_injury_marks.clear()
	_ankles.clear();_toes.clear();_foot_target.clear();_foot_pitch.clear();_joints.clear();_transition_from.clear()
	_imported = null;_true_form = null;_phase_body = null;_plug_tail = null;_plug_segments.clear()
	_aura = null;_aura_material = null;_aura_color = Color(0, 0, 0, 0);_blob = null;_notifier = null
	_reveal_material = null;_outline_on = false;_outline_color = Color(0, 0, 0, 0);_occluded = -1.0
	_clone = false;_action = "";_action_time = 0;_combat_state = {};_life_state = "alive";_life_clock = 0.0
	_run_blend = 0.0;_injury_blend = 0.0;_signature = -1;_transition_left = 0.0
	_reset_motion_state()

func _reset_motion_state() -> void :
	_move_blend = 0.0;_stun_blend = 0.0;_last_velocity = Vector3.ZERO;_last_yaw = rotation.y
	_air_blend = 0.0;_land_clock = 0.0;_was_grounded = true;_crawl_cycle = 0.0;_last_vertical_speed = 0.0
	_gait = 0.0;_gait_phase = 0.0;_clock = 0.0;_hit_time = 0.0;_pending_dt = 0.0
	_local_velocity = Vector3.ZERO;_accel_smooth = Vector3.ZERO;_yaw_rate = 0.0;_move_dir = Vector3.FORWARD
	_lean_pitch = 0.0;_lean_roll = 0.0;_curl = 0.12;_curl_override = -1.0;_blob_timer = 0.0
	_motion_primed = false
	_land_offset = 0.0;_land_speed = 0.0;_air_blend = 0.0;_calm = false
	_overlay_name = "";_speak_left = 0.0;_fidget_time = -1.0;_hold_left = 0.0;_clip_turn = 0.0;_clip_squash = 1.0
	_state_clocks.clear();_boost_blend = 0.0;_alert_blend = 0.0;_gait_previous = -1.0;_death_hold = 0.0
	_hit_rot = Vector3.ZERO;_hit_vel = Vector3.ZERO;_hit_head = Vector3.ZERO;_hit_head_vel = Vector3.ZERO
	_hit_arm = 0.0;_hit_arm_vel = 0.0;_hit_drop = 0.0;_hit_drop_vel = 0.0
	_look = Vector2.ZERO;_look_speed = Vector2.ZERO;_glance_back = 0.0;_fatigue = 0.0
	if _face_ctrl: _face_ctrl.reset()


func _free_detached_props() -> void :
	for node: Variant in _props.values():
		if is_instance_valid(node) and (node as Node).get_parent() == null: (node as Node).free()

func _notification(what: int) -> void :
	if what == NOTIFICATION_PREDELETE: _free_detached_props()

func _joint(names: Array, fallback: Vector3) -> Vector3:
	for bone: String in names:
		if _imported.has_joint(bone): return _imported.joint_position(bone)
	return fallback

func _setup_supplied_model() -> void :
	_imported = PaperImportedCharacter.new();_imported.name = "UserSuppliedModel";add_child(_imported)
	_imported.eyelids = not lightweight
	_imported.setup(character_name)
	var hip: Vector3 = _imported.joint_position("Hip")
	_base_height = hip.y
	_body = G.pivot(self, hip);_body.name = "ArticulatedBody"
	var spine_at: Vector3 = _joint(["Spine01", "Waist"], hip + Vector3(0, 0.12, 0))
	var chest_at: Vector3 = _joint(["Spine02"], spine_at + Vector3(0, 0.2, 0))
	var head_at: Vector3 = _joint(["Head"], chest_at + Vector3(0, 0.4, 0))
	var neck_at: Vector3 = _joint(["Neck", "NeckTwist01"], head_at)
	_spine = G.pivot(_body, spine_at - hip);_spine.name = "Spine"
	_chest = G.pivot(_spine, chest_at - spine_at);_chest.name = "Chest"
	_neck = G.pivot(_chest, neck_at - chest_at);_neck.name = "Neck"
	_head = G.pivot(_neck, head_at - neck_at);_head.name = "ExpressiveHead"


	var left_clav_at: Vector3 = _joint(["L_Clavicle"], _imported.joint_position("L_Upperarm"))
	var right_clav_at: Vector3 = _joint(["R_Clavicle"], _imported.joint_position("R_Upperarm"))
	_left_clav = G.pivot(_chest, left_clav_at - chest_at);_left_clav.name = "LeftClavicle"
	_right_clav = G.pivot(_chest, right_clav_at - chest_at);_right_clav.name = "RightClavicle"
	_left_arm = G.pivot(_left_clav, _imported.joint_position("L_Upperarm") - left_clav_at)
	_right_arm = G.pivot(_right_clav, _imported.joint_position("R_Upperarm") - right_clav_at)
	_left_elbow = G.pivot(_left_arm, _imported.joint_position("L_Forearm") - _imported.joint_position("L_Upperarm"))
	_right_elbow = G.pivot(_right_arm, _imported.joint_position("R_Forearm") - _imported.joint_position("R_Upperarm"))
	_left_hand = G.pivot(_left_elbow, _imported.joint_position("L_Hand") - _imported.joint_position("L_Forearm"))
	_right_hand = G.pivot(_right_elbow, _imported.joint_position("R_Hand") - _imported.joint_position("R_Forearm"))
	_left_leg = G.pivot(_body, _imported.joint_position("L_Thigh") - hip)
	_right_leg = G.pivot(_body, _imported.joint_position("R_Thigh") - hip)
	_left_knee = G.pivot(_left_leg, _imported.joint_position("L_Calf") - _imported.joint_position("L_Thigh"))
	_right_knee = G.pivot(_right_leg, _imported.joint_position("R_Calf") - _imported.joint_position("R_Thigh"))
	_ankles[-1] = G.pivot(_left_knee, _imported.joint_position("L_Foot") - _imported.joint_position("L_Calf"))
	_ankles[1] = G.pivot(_right_knee, _imported.joint_position("R_Foot") - _imported.joint_position("R_Calf"))
	_toes[-1] = G.pivot(_ankles[-1], _joint(["L_ToeBase"], _imported.joint_position("L_Foot")) - _imported.joint_position("L_Foot"))
	_toes[1] = G.pivot(_ankles[1], _joint(["R_ToeBase"], _imported.joint_position("R_Foot")) - _imported.joint_position("R_Foot"))
	_imported.bind({"body": _body, "spine": _spine, "chest": _chest, "neck": _neck, "head": _head, "left_arm": _left_arm, "right_arm": _right_arm, "left_elbow": _left_elbow, "right_elbow": _right_elbow, "left_hand": _left_hand, "right_hand": _right_hand, "left_leg": _left_leg, "right_leg": _right_leg, "left_knee": _left_knee, "right_knee": _right_knee, "left_ankle": _ankles[-1], "right_ankle": _ankles[1], "left_toe": _toes[-1], "right_toe": _toes[1], "left_clav": _left_clav, "right_clav": _right_clav})
	_joints = [_body, _chest, _head, _left_clav, _right_clav, _left_arm, _right_arm, _left_elbow, _right_elbow, _left_hand, _right_hand, _left_leg, _right_leg, _left_knee, _right_knee, _ankles[-1], _ankles[1], _toes[-1], _toes[1]]
	_measure_rig()
	if not lightweight:
		_make_props()
		if _is_alice: _make_phase6()
		if character_name == "Lysia": _make_plug_tail()
		_make_aura()
	_last_yaw = rotation.y

func _measure_rig() -> void :
	_thigh_height = (_imported.joint_position("L_Thigh").y + _imported.joint_position("R_Thigh").y) * 0.5
	_ankle_height = (_imported.joint_position("L_Foot").y + _imported.joint_position("R_Foot").y) * 0.5
	_hip_half_width = absf(_imported.joint_position("R_Thigh").x - _imported.joint_position("L_Thigh").x) * 0.5
	_foot_rest_x = absf(_imported.joint_position("R_Foot").x - _imported.joint_position("L_Foot").x) * 0.5
	var foot: Vector3 = _imported.joint_position("L_Foot")
	var toe: Vector3 = _joint(["L_ToeBase"], foot)
	_toe_length = Vector2(toe.x - foot.x, toe.z - foot.z).length()
	_leg_reach = minf(_left_knee.position.length() + _ankles[-1].position.length(), _right_knee.position.length() + _ankles[1].position.length())


	for side in [-1, 1]:
		var leg: Node3D = _left_leg if side < 0 else _right_leg
		var knee: Node3D = _left_knee if side < 0 else _right_knee
		var hip_point: Vector3 = Vector3(0, _base_height, 0) + leg.position
		_hip_rest[side] = hip_point
		_foot_rest[side] = hip_point + knee.position + _ankles[side].position
		_leg_length[side] = knee.position.length() + _ankles[side].position.length()

	for side in [-1, 1]:
		var clav: Node3D = _right_clav if side > 0 else _left_clav
		var arm: Node3D = _right_arm if side > 0 else _left_arm
		var elbow: Node3D = _right_elbow if side > 0 else _left_elbow
		var hand: Node3D = _right_hand if side > 0 else _left_hand
		_shoulder_rest[side] = _spine.position + _chest.position + clav.position + arm.position
		_arm_length[side] = elbow.position.length() + hand.position.length()

	_hip_half_width = maxf(_hip_half_width, 0.05)

func _finish_model() -> void :
	_model_scale = float(CHARACTER_HEIGHTS.get(character_name, 1.75)) / MODEL_HEIGHT
	scale = Vector3.ONE * _model_scale
	if is_instance_valid(_phase_body): _phase_body.scale = Vector3.ONE / _model_scale
	if not _is_alice and not lightweight and character_name != "TrueForm":
		var arm: Node3D = _left_elbow if character_name in ["Ashura", "Elly", "Bleuette"] else _right_elbow
		var mark: MeshInstance3D = MeshInstance3D.new();mark.name = "SecondLifeTornSleeve"
		mark.mesh = CharProps.injury_mesh();mark.position = Vector3(0, - 0.12, - 0.058)
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm.add_child(mark);mark.visible = false;_injury_marks.append(mark)
	_notifier = VisibleOnScreenNotifier3D.new();_notifier.name = "ScreenCheck"
	var reach: float = 1.9 if _is_alice else 1.0
	_notifier.aabb = AABB(Vector3( - reach, -0.3, - reach), Vector3(reach * 2.0, MODEL_HEIGHT * (1.8 if _is_alice else 1.15), reach * 2.0))
	add_child(_notifier)
	if blob_shadow:
		_blob = MeshInstance3D.new();_blob.name = "BlobShadow"
		_blob.mesh = CharMaterials.blob_mesh();_blob.material_override = CharMaterials.blob_material()
		_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_blob.top_level = true;_blob.visible = false
		add_child(_blob)
	_reset_pose()
	_split_joints()
	_sync_now()

func _make_props() -> void :
	for prop_name: String in CharProps.PROP_NAMES:
		var info: Dictionary = CharProps.prop(prop_name)
		if info.is_empty(): continue
		var node: MeshInstance3D = MeshInstance3D.new();node.name = "Held_" + prop_name
		node.mesh = info.mesh;node.position = info.offset
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_props[prop_name] = node
		_prop_hands[prop_name] = _right_hand if info.hand == "right" else _left_hand

func _make_phase6() -> void :
	_phase_body = G.pivot(self);_phase_body.name = "AliceTrueForm";_phase_body.visible = false
	_true_form = get_script().new()
	_true_form.set("lightweight", true)
	_true_form.set("lod_enabled", false)
	_phase_body.add_child(_true_form);_true_form.setup("TrueForm")
	_true_form.set("_host", self)

	_true_form.anim_fx.connect(_relay_fx)

func _relay_fx(cue: String) -> void :
	anim_fx.emit(cue)

func _make_plug_tail() -> void :
	_plug_tail = G.pivot(_body, Vector3(0, - 0.1, 0.15));_plug_tail.name = "ArticulatedPowerTail"
	var parent: Node3D = _plug_tail
	for i in range(5):
		var section: Node3D = G.pivot(parent, Vector3(0, 0, 0.12) if i > 0 else Vector3.ZERO)
		section.rotation = Vector3( - 0.08 + i * 0.035, 0.08, 0)
		_plug_segments.append(section)
		var piece: MeshInstance3D = MeshInstance3D.new();piece.mesh = CharProps.cable_segment();section.add_child(piece)
		_secondary.append({"node": section, "rest": section.rotation, "offset": Vector3.ZERO, "speed": Vector3.ZERO, "weight": 0.24, "phase": i * 0.5})
		parent = section
	var plug: MeshInstance3D = MeshInstance3D.new();plug.mesh = CharProps.cable_plug();parent.add_child(plug)

func _make_aura() -> void :
	_aura = MeshInstance3D.new();_aura.name = "Aura";_aura.mesh = CharProps.aura_mesh()
	_aura.position = Vector3(0, 0.038, 0);_aura.visible = false
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura_material = CharMaterials.glow(Color("ddc6ff"), 1.5)
	_aura.material_override = _aura_material
	add_child(_aura)



func hand_position() -> Vector3:
	return _right_hand.global_position if is_instance_valid(_right_hand) else global_position + Vector3.UP * 1.1

func attachment_position(socket: String) -> Vector3:
	if socket == "shotgun_muzzle" and _props.has("shotgun") and is_instance_valid(_right_hand):
		var gun: Node3D = _props.shotgun
		return _right_hand.global_transform * (gun.transform * CharProps.shotgun_muzzle())
	if socket == "left_hand" and is_instance_valid(_left_hand): return _left_hand.global_position
	return hand_position()

func get_render_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if is_instance_valid(_imported): result.append_array(_imported.meshes)
	return result

func is_performing_action() -> bool:
	return _action_time > 0.0 or float(_combat_state.get("grab_time", 0)) > 0.0 or bool(_combat_state.get("spike_aiming", false)) or float(_combat_state.get("grenade_windup", 0)) > 0.0

func cinematic_focus_height() -> float:
	if is_instance_valid(_phase_body) and _phase_body.visible: return 1.55
	if is_instance_valid(_imported): return _imported.joint_position("Head").y * _model_scale
	return 1.4

func visual_height() -> float:
	if is_instance_valid(_phase_body) and _phase_body.visible: return 3.0
	if is_instance_valid(_imported): return MODEL_HEIGHT * _model_scale
	return 1.75



func set_shadow_clone(enabled: bool) -> void :
	_clone = enabled
	if not enabled: return
	if is_instance_valid(_imported): _imported.shadow_tint()
	_hide_props()

func set_combat_state(state: Dictionary) -> void :
	_combat_state = state

func set_life_state(state: String) -> void :
	if state == _life_state: return
	_calm = false
	_life_state = state;_life_clock = 0.65 if state == "dead" and _action.begins_with("death_") else 0.0
	_death_hold = 0.0

	if state in ["downed", "dead"]: _hide_props()


func react_to_hit(strength: float = 1.0, source_position: Vector3 = Vector3.INF) -> void :
	_calm = false
	var push: Vector3 = Vector3.BACK
	if source_position.is_finite() and is_inside_tree():
		var away: Vector3 = global_position - source_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			var local: Vector3 = away.normalized().rotated(Vector3.UP, - _facing_yaw())
			local.y = 0.0
			if local.length_squared() > 0.0001: push = local.normalized()
	var s: float = clampf(strength, 0.25, 1.5)
	_hit_time = 0.3
	_kick_hit(s, push)
	_face_ctrl.hurt(s)
	_cue("hurt", s)




func trigger(action: String) -> void :
	_calm = false

	if is_instance_valid(_true_form) and (_phase_body.visible or action.to_lower() == "true form"): _true_form.trigger(action)
	match action:
		"grunt":
			_face_ctrl.grunt(0.55, 0.14)
			return
		"gasp":
			_face_ctrl.gasp()
			return
		"hurt":
			_face_ctrl.hurt(0.8)
			return
	if action == "revive_cancel":
		if _action == "revive": _action_time = 0.0
		return
	var key: String = action.to_lower().split("·")[0].strip_edges()
	if key == "stun":

		react_to_hit(0.8)
		return
	var clip_name: String = str(ACTION_CLIPS.get(key, key))
	if clip_name.is_empty(): return
	if character_name == "TrueForm" and clip_name == "shadow": clip_name = "leap"
	if clip_name.begins_with("death_"):

		if _life_state == "downed": clip_name = "death_downed"

		_dead_clip = "dead_spike" if clip_name in ["death_spike", "death_downed"] else "dead"
		_death_hold = 1.0
	elif clip_name == "slash":

		_combo = (_combo + 1) % 2 if _clock - _combo_clock < 4.5 else 0
		_combo_clock = _clock
		if _combo == 1 and AnimLibrary.has_clip("slash_b", character_name): clip_name = "slash_b"
	play(clip_name)




func play(clip_name: String) -> void :
	var clip: Dictionary = _get_clip(clip_name)
	if clip.is_empty(): return
	_calm = false
	if clip.add:
		if _life_state != "alive": return
		_overlay_name = clip_name
		_overlay_time = 0.0
		_overlay_previous = 0.0
		return
	_action = clip_name
	if float(clip["in"]) <= 0.05: _transition_left = minf(_transition_left, 0.05)

	_action_duration = 4.0 if clip_name == "revive" else float(clip.len)
	_action_time = _action_duration
	_action_clip_time = 0.0
	_hold_left = 0.0



func reset_motion() -> void :
	_reset_motion_state()
	_action = "";_action_time = 0.0;_life_clock = 0.0;_signature = -1;_transition_left = 0.0
	_stun_blend = 0.0;_injury_blend = 0.0
	for item in _secondary:
		item.offset = Vector3.ZERO;item.speed = Vector3.ZERO;item.node.rotation = item.rest
	if is_instance_valid(_imported): _imported.reset_motion()
	if not is_instance_valid(_body): return
	_hide_props()
	_reset_pose()
	_split_joints()
	_request_sync()

func set_outline(active: bool, color: Color = Color("80e1ea")) -> void :
	if active == _outline_on and color == _outline_color: return
	if not is_instance_valid(_imported): return
	if active and _reveal_material == null: _reveal_material = CharMaterials.reveal(color)
	if active and color != _outline_color: _reveal_material.set_shader_parameter("tint", color)
	_outline_color = color
	if active != _outline_on:
		_outline_on = active
		for mesh in _imported.meshes: mesh.material_overlay = _reveal_material if active else null
	if is_instance_valid(_true_form): _true_form.set_outline(active, color)

func set_outline_occluded(hidden: bool) -> void :
	var value: float = 1.0 if hidden else 0.0
	if value == _occluded: return
	_occluded = value
	if _reveal_material == null: _reveal_material = CharMaterials.reveal(Color("80e1ea"))
	_reveal_material.set_shader_parameter("occluded_hint", value)
	if is_instance_valid(_true_form): _true_form.set_outline_occluded(hidden)

func set_aura(active: bool, color: Color = Color("e8d68d")) -> void :
	if not is_instance_valid(_aura): return
	if _aura.visible != active: _aura.visible = active
	if color != _aura_color:
		_aura_color = color
		_aura_material.set_shader_parameter("albedo_color", color)
		_aura_material.set_shader_parameter("glow_color", color)


static func set_ink_outlines(enabled: bool) -> void :
	CharMaterials.set_outlines_enabled(enabled)



func animate(delta: float, velocity: Vector3, stunned: bool, phase: bool) -> void :
	if not is_instance_valid(_body): return
	_animation_delta = delta

	if _hold_left > 0.0: _hold_left = maxf(0.0, _hold_left - delta)
	else: _action_time = maxf(0, _action_time - delta)
	_lod_counter += 1
	if _calm and (velocity.length_squared() > 0.01 or stunned or _action_time > 0.0): _calm = false
	var detail: int = _lod_detail()
	if detail < 0:

		_pending_dt += delta
		if _is_alice and is_instance_valid(_phase_body): _set_phase_visible(phase)
		return
	var dt: float = minf(delta + _pending_dt, 0.25)
	_pending_dt = 0.0
	_detail = detail
	_clock += dt
	_life_clock += dt
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if is_instance_valid(_imported): _imported.set_hand_gesture("", 0)
	if _is_alice and is_instance_valid(_phase_body):
		_set_phase_visible(phase)
		if phase:
			_phase_pose(dt, velocity, stunned)
			_update_aura(dt)
			return
	_tick_stamp += 1
	_tick_dt = dt
	_read_motion(dt, velocity)
	_read_state(velocity)
	_crawl_cycle += dt * TAU * 0.56 * clampf(speed / 0.7, 0.0, 1.0)
	_update_air_contact()
	_step_land_spring(dt)
	_step_hit_springs(dt)
	_air_blend = lerpf(_air_blend, 0.0 if _st_grounded else 1.0, 1.0 - exp( - dt * 14.0))
	_move_blend = lerpf(_move_blend, speed, 1.0 - exp( - dt * 11.0))
	_run_blend = smoothstep(2.2, 5.2, _move_blend)
	_update_glance(dt, speed)
	_check_transition(stunned)
	_check_emote_jump(dt)
	_prop_wanted.clear()
	_curl_override = -1.0
	_curl_left_override = -1.0
	_clip_shake = 0.0;_clip_jaw = 0.0;_clip_chatter = 0.0;_clip_lid = 0.0
	_clip_turn = 0.0;_clip_squash = 1.0
	_reset_pose(false)
	_locomotion(dt)
	_air_pose()
	var mood: String = _base_mood()
	_stun_blend = lerpf(_stun_blend, 1.0 if stunned else 0.0, 1.0 - exp( - dt * (40.0 if stunned else 7.0)))
	if not stunned and _action_time > 0 and not _life_action():
		mood = _play_action(1.0 - _action_time / _action_duration, mood)
	if not stunned:
		mood = _state_poses(mood)
	if _stun_blend > 0.005:

		_state_clip("stunned", mood, _stun_blend)
		if stunned: mood = "dazed"
	_apply_injury_pose(dt, speed)
	if _injury_blend > 0.3 and mood == _base_mood(): mood = "hurt"
	if _st_chased and _action_time <= 0 and _life_state == "alive" and not _is_alice: mood = "panic" if speed > 4.0 else "fear"
	if _st_lms and _action_time <= 0 and not stunned: mood = "determined"
	if character_name == "TrueForm" and not stunned: mood = "angry"
	if not _st_emote.is_empty() and _is_emote(_st_emote) and _life_state == "alive" and not stunned and speed < 0.35 and _action_time <= 0:
		mood = _emote_pose(_st_emote, _st_emote_time)
		_fidget_time = -1.0
	else:
		mood = _idle_fidget(dt, speed, stunned, mood)
	if _st_roll > 0 and _life_state == "alive" and not stunned: _apply_clip(_get_clip("land_roll"), clampf(0.65 - _st_roll, 0.0, 0.65), 1.0)
	if not _overlay_name.is_empty(): mood = _apply_overlay(dt, mood)
	if _life_state == "alive": _apply_hit_springs()
	mood = _apply_life_pose(mood)
	if _curl_override < 0.0:
		var relaxed: float = float(_style.idle_curl) + sin(_clock * 0.8 + _temperament) * 0.04
		_curl_override = lerpf(relaxed, float(_style.fist), _g_run * _g_move)
	_finish_tick(dt, mood)
	_calm = speed < 0.05 and _move_blend < 0.05 and _action_time <= 0.0 and _life_state == "alive" and _st_grounded and _air_blend < 0.01 and _stun_blend < 0.01 and _transition_left <= 0.0 and _fidget_time < 0.0 and _st_emote.is_empty() and absf(_land_offset) < 0.001 and _hit_rot.length_squared() + _hit_head.length_squared() + _hit_arm * _hit_arm < 0.0001 and not _st_heal and not _st_view and _st_eating <= 0.0 and _overlay_name.is_empty() and _speak_left <= 0.0 and not _st_block and not _st_blind and _alert_blend < 0.01



func _idle_fidget(dt: float, speed: float, stunned: bool, mood: String) -> String:
	var calm: bool = _life_state == "alive" and not stunned and speed < 0.2 and _action_time <= 0.0 and _st_grounded and not _st_chased and not _st_lms and _combat_state.get("emote_id", "") == "" and not _st_grab and not _st_heal and not _st_view and _st_eating <= 0.0 and _st_charge <= 0.0
	if _fidget_time < 0.0:
		_fidget_weight = 0.0
		if not calm or lightweight:
			_fidget_timer = maxf(_fidget_timer, 3.0)
			return mood
		_fidget_timer -= dt
		if _fidget_timer > 0.0: return mood
		_fidget_timer = _rng.randf_range(8.0, 17.0)
		_fidget_time = 0.0
	var clip: Dictionary = _get_clip("fidget")
	if clip.is_empty():
		_fidget_time = -1.0
		return mood
	var previous: float = _fidget_time
	_fidget_time += dt

	_fidget_weight = move_toward(_fidget_weight, 1.0 if calm else 0.0, dt * (3.0 if calm else 6.0))
	if _fidget_time > float(clip.len) or ( not calm and _fidget_weight <= 0.0):
		_fidget_time = -1.0
		return mood
	var clip_mood: String = _apply_clip(clip, _fidget_time, AnimClip.envelope(clip, _fidget_time) * _fidget_weight, previous)
	return clip_mood if not clip_mood.is_empty() else mood

func _apply_overlay(dt: float, mood: String) -> String:
	var clip: Dictionary = _get_clip(_overlay_name)
	_overlay_time += dt
	if clip.is_empty() or _overlay_time > float(clip.len) or _life_state != "alive":
		_overlay_name = ""
		return mood
	var clip_mood: String = _apply_clip(clip, _overlay_time, AnimClip.envelope(clip, _overlay_time), _overlay_previous)
	_overlay_previous = _overlay_time
	return clip_mood if not clip_mood.is_empty() else mood


func speak(seconds: float, intensity: float = 1.0) -> void :
	_speak_left = maxf(_speak_left, seconds)
	_speak_intensity = clampf(intensity, 0.2, 1.5)


func _update_air_contact() -> void :
	if _st_grounded and not _was_grounded:
		var impact: float = - _last_vertical_speed
		if impact > 1.5:
			var strength: float = clampf(impact / 14.0, 0.2, 1.2)
			_land_speed -= strength * 1.8
			if impact > 10.0: _face_ctrl.grunt(0.3 * strength, 0.08)
			_cue("land", strength)
			if impact > 4.0: anim_fx.emit("land_hard" if impact > 12.5 else "land")
	elif not _st_grounded and _was_grounded and _st_vertical > 2.0:

		_air_lead = 1 if _gait_phase < 0.5 else -1
		_face_ctrl.grunt(0.22, 0.08)
		_cue("jump", 0.6)
		anim_fx.emit("jump")
	_was_grounded = _st_grounded
	if not _st_grounded: _last_vertical_speed = _st_vertical

func _set_phase_visible(phase: bool) -> void :
	_body.visible = not phase;_phase_body.visible = phase
	if is_instance_valid(_imported): _imported.visible = not phase
	if is_instance_valid(_blob) and phase: _blob.visible = false


func _lod_detail() -> int:
	if not lod_enabled: return 1
	if not is_visible_in_tree(): return -1

	if _life_state == "dead" and _life_clock > 2.0 and _action_time <= 0.0:
		return 0 if (_lod_counter + _lod_slot) % 4 == 0 else -1
	var on_screen: bool = _notifier == null or _notifier.is_on_screen()
	if not on_screen: return 0 if (_lod_counter + _lod_slot) % 4 == 0 else -1
	if _camera_distance() > FAR_DISTANCE: return 0 if (_lod_counter + _lod_slot) % 2 == 0 else -1

	if _calm and _camera_distance() > 7.0: return 1 if (_lod_counter + _lod_slot) % 2 == 0 else -1
	return 1

func _camera_distance() -> float:
	var viewport: Viewport = get_viewport()
	var frame: int = Engine.get_process_frames()
	if frame != _camera_frame or viewport.get_instance_id() != _camera_viewport:
		_camera_frame = frame
		_camera_viewport = viewport.get_instance_id()
		var camera: Camera3D = viewport.get_camera_3d()
		_camera_valid = camera != null
		if _camera_valid: _camera_position = camera.global_position
	if not _camera_valid: return 0.0
	return global_position.distance_to(_camera_position)

func _facing_yaw() -> float:
	if is_instance_valid(_host): return _host.rotation.y + rotation.y
	return rotation.y


func _read_motion(dt: float, velocity: Vector3) -> void :
	var yaw: float = _facing_yaw()
	if not _motion_primed:

		_motion_primed = true
		_last_velocity = velocity
		_last_yaw = yaw
	_local_velocity = velocity.rotated(Vector3.UP, - yaw)
	var accel: Vector3 = ((velocity - _last_velocity) / maxf(dt, 0.001)).rotated(Vector3.UP, - yaw)
	accel = accel.limit_length(45.0)
	_accel_smooth = _accel_smooth.lerp(accel, 1.0 - exp( - dt * 9.0))
	var turn: float = clampf(angle_difference(_last_yaw, yaw) / maxf(dt, 0.001), -12.0, 12.0)
	_yaw_rate = lerpf(_yaw_rate, turn, 1.0 - exp( - dt * 10.0))
	var flat: Vector3 = Vector3(_local_velocity.x, 0.0, _local_velocity.z)
	if flat.length_squared() > 0.09:
		_move_dir = _move_dir.lerp(flat.normalized(), 1.0 - exp( - dt * 12.0))
		if _move_dir.length_squared() < 0.0001: _move_dir = Vector3.FORWARD
		_move_dir = _move_dir.normalized()
	var grounded_life: float = (1.0 - _air_blend) * (1.0 if _life_state == "alive" else 0.0)

	_lean_pitch = clampf(_accel_smooth.z * 0.011, -0.15, 0.13) * grounded_life
	_lean_roll = clampf( - _accel_smooth.x * 0.014, -0.26, 0.26) * grounded_life
	_last_velocity = velocity
	_last_yaw = yaw


func _read_state(velocity: Vector3) -> void :
	var s: Dictionary = _combat_state
	if s.is_empty():
		_st_grounded = true;_st_vertical = velocity.y;_st_emote = "";_st_emote_time = 0.0;_st_roll = 0.0
		_st_spike = false;_st_grab = false;_st_grabbed = false;_st_forced = false;_st_heal = false
		_st_grenade = 0.0;_st_drone = 0.0;_st_overheat = false;_st_overheat_hold = false;_st_boost_time = false
		_st_view = false;_st_piloting = false;_st_grinding = false;_st_charge = 0.0;_st_speed_boost = false
		_st_carrying = false;_st_carried = false;_st_eating = 0.0;_st_outlet = false
		_st_chased = false;_st_lms = false;_st_om = false;_st_injured = false
		_st_block = false;_st_grab_hold = false;_st_knocked = false;_st_aim_flash = false
		_st_overheat_dash = false;_st_blind = false;_st_shadow_hide = false;_was_shadow_hidden = false
		_st_sprinting = false
		return
	_st_grounded = bool(s.get("grounded", true))
	_st_vertical = float(s.get("vertical_speed", velocity.y))
	_st_emote = str(s.get("emote_id", ""))
	_st_emote_time = float(s.get("emote_time", 0))
	_st_roll = float(s.get("landing_roll", s.get("land_roll_time", 0)))
	_st_spike = bool(s.get("spike_aiming", false))
	_st_grab = float(s.get("grab_time", 0)) > 0
	_st_grabbed = int(s.get("grabbed_by", -1)) >= 0
	_st_forced = float(s.get("forced_time", 0)) > 0
	_st_heal = float(s.get("heal_time", 0)) > 0 or float(s.get("channel", 0)) > 0
	_st_grenade = float(s.get("grenade_windup", 0))
	_st_drone = float(s.get("drone_windup", 0))
	_st_piloting = bool(s.get("drone_piloting", false))
	_st_view = _st_piloting or bool(s.get("camera_view", false))
	_st_charge = float(s.get("charging_boost", s.get("boost_charge", 0))) if bool(s.get("boost_charging", true)) else 0.0

	var boosted: bool = float(s.get("boost_time", 0)) > 0 or float(s.get("speed_boost", s.get("speed_boost_time", 0))) > 0
	_st_carrying = int(s.get("carrying_id", -1)) >= 0
	_st_carried = int(s.get("carried_by", -1)) >= 0

	var lysia: bool = character_name == "Lysia"
	_st_overheat = lysia and float(s.get("overheat_time", 0)) > 0
	_st_overheat_hold = lysia and float(s.get("overheat_hold", 0)) > 0
	_st_outlet = lysia and (float(s.get("outlet_healing", 0)) > 0 or float(s.get("outlet_time", 0)) > 0)
	var ashura: bool = character_name == "Ashura"

	_st_boost_time = ashura and boosted
	_st_sprinting = bool(s.get("sprinting", false))
	_st_speed_boost = boosted and not ashura
	_st_grinding = ashura and bool(s.get("grinding", false))
	_st_eating = float(s.get("chocolate_eating", 0)) if character_name == "Bleuette" else 0.0
	_st_block = character_name == "Usayuko" and float(s.get("block", 0)) > 0
	_st_grab_hold = _st_grab and bool(s.get("grab_holding", false))
	_st_knocked = _st_forced and str(s.get("force_name", "knock")) == "knock"
	_st_aim_flash = character_name == "Simon" and bool(s.get("grenade_aiming", false))
	_st_overheat_dash = lysia and float(s.get("overheat_charge", 0)) > 0
	_st_blind = float(s.get("blind", 0)) > 0
	_st_shadow_hide = bool(s.get("shadow_hide", false))

	if _was_shadow_hidden and not _st_shadow_hide and _life_state == "alive": play("emerge")
	_was_shadow_hidden = _st_shadow_hide
	_st_chased = bool(s.get("chased", false))
	_st_lms = bool(s.get("lms", false))
	_st_om = bool(s.get("ruleset_om", false))
	_st_injured = bool(s.get("second_life", s.get("revived", false))) and not _is_alice


func _pose_signature(stunned: bool) -> int:
	var sig: int = 0
	if stunned: sig |= 1
	if _st_spike: sig |= 2
	if _st_grab: sig |= 4
	if _st_grabbed: sig |= 8
	if _st_forced: sig |= 16
	if _st_heal: sig |= 32
	if _st_carrying: sig |= 64
	if _st_carried: sig |= 128
	if _st_eating > 0.0: sig |= 256
	if _st_outlet: sig |= 512
	if _st_overheat or _st_overheat_hold: sig |= 1024
	if _st_view: sig |= 2048
	if _st_grinding: sig |= 4096
	if _st_charge > 0.0: sig |= 8192
	if not _st_emote.is_empty() and _is_emote(_st_emote): sig |= 16384
	if _st_roll > 0: sig |= 32768
	if _st_speed_boost or _st_boost_time: sig |= 65536
	if _st_block: sig |= 1 << 30
	if _st_grab_hold: sig |= 1 << 31
	if _st_knocked: sig |= 1 << 32
	if _st_aim_flash: sig |= 1 << 33
	if _st_overheat_dash: sig |= 1 << 34
	if _st_blind: sig |= 1 << 35
	if _life_state == "downed": sig |= 1 << 17
	elif _life_state == "dead": sig |= 1 << 18
	if _action_time > 0.0 and (_action == "shotgun" or _action == "revive" or _action == "revive_help" or _action == "recover" or _action.begins_with("death_") or _action.begins_with("execution_")):
		sig |= (1 << 19) | ((absi(_action.hash()) & 1023) << 20)
	return sig

func _check_transition(stunned: bool) -> void :
	var sig: int = _pose_signature(stunned)
	_stun_snap = stunned and (_signature & 1) == 0
	if sig == _signature: return
	var first: bool = _signature < 0
	_signature = sig
	if first: return
	_begin_transition()

func _begin_transition() -> void :
	_transition_from.resize(_joints.size())
	for i in range(_joints.size()):
		var joint: Node3D = _joints[i]
		var q: Quaternion = joint.quaternion
		if joint == _chest: q = _spine.quaternion * _chest.quaternion
		elif joint == _head: q = _neck.quaternion * _head.quaternion
		_transition_from[i] = q
	_transition_body = _body.position

	var sudden: bool = _stun_snap or (_action_time > 0.0 and _action_duration - _action_time < 0.1 and float(_get_clip(_action).get("in", 0.12)) <= 0.05)
	_transition_time = 0.07 if sudden else TRANSITION_TIME
	_transition_left = _transition_time

func _apply_transition(dt: float) -> void :
	if _transition_left <= 0.0 or _transition_from.size() != _joints.size(): return
	var w: float = smoothstep(0.0, 1.0, 1.0 - _transition_left / _transition_time)
	_transition_left -= dt
	for i in range(_joints.size()):
		var joint: Node3D = _joints[i]
		joint.quaternion = _transition_from[i].slerp(joint.quaternion, w)
	_body.position = _transition_body.lerp(_body.position, w)



func _finish_tick(dt: float, mood: String) -> void :
	_apply_turn()
	_replant_feet()
	_apply_transition(dt)
	_limit_anatomical_joints()
	_apply_squash()
	_apply_shake()
	_auto_clavicles()
	_face_dt += dt

	if _detail >= 1 and _face_dt >= 0.03:
		_face(mood)
		_face_dt = 0.0
	_curl = lerpf(_curl, _curl_override, 1.0 - exp( - dt * 14.0))
	_curl_left = lerpf(_curl_left, _curl_left_override if _curl_left_override >= 0.0 else _curl_override, 1.0 - exp( - dt * 14.0))
	if is_instance_valid(_imported):
		_imported.secondary_detail = _detail >= 1
		_imported.set_finger_curl(_curl, _curl_left)
		_imported.set_motion(_accel_smooth, _local_velocity, _yaw_rate, dt, _clock, Vector2(_thigh_forward[-1], _thigh_forward[1]))
	_step_node_springs(dt)
	if not _pose_finite():

		_reset_motion_state()
		_reset_pose()
		if is_instance_valid(_imported): _imported.reset_motion()
	_split_joints()
	_update_plug_tail()
	_apply_props()
	_sync_now()
	_update_blob(dt)
	_update_aura(dt)



func _apply_turn() -> void :
	if absf(_clip_turn) < 0.0005: return
	var spin: Quaternion = Quaternion(Vector3.UP, _clip_turn)
	_body.position = spin * _body.position
	_body.quaternion = spin * _body.quaternion
	for side in [-1, 1]:
		if _foot_target.has(side): _foot_target[side] = spin * (_foot_target[side] as Vector3)
	_feet_dirty = true


func hit_stop(seconds: float) -> void :
	_hold_left = maxf(_hold_left, clampf(seconds, 0.0, 0.25))




func socket_position(socket: String) -> Vector3:
	if not is_instance_valid(_body) or not is_inside_tree(): return global_position + Vector3.UP
	match socket:
		"hand_r": return _right_hand.global_position
		"hand_l": return _left_hand.global_position
		"foot_r": return _ankles[1].global_position
		"foot_l": return _ankles[-1].global_position
		"head": return _head.global_transform * Vector3(0.0, 0.22, 0.0)
		"over": return _head.global_transform * Vector3(0.0, 0.22, 0.0) + Vector3.UP * (0.42 * visual_height() / 1.75)
		"eyes": return _head.global_transform * Vector3(0.0, 0.25, -0.2)
		"mouth": return _head.global_transform * Vector3(0.0, 0.1, -0.2)
		"chest": return _chest.global_position
		"back": return _chest.global_transform * Vector3(0.0, 0.12, 0.24)
		"hips": return _body.global_position
		"ground": return global_position
		"front": return global_transform * Vector3(0.0, _base_height * 1.1, -0.9)
	return _chest.global_position


func ground_speed() -> float:
	return _move_blend


func fx_source() -> PaperVisual:
	if is_instance_valid(_true_form) and is_instance_valid(_phase_body) and _phase_body.visible: return _true_form
	return self

func _pose_finite() -> bool:

	return _body.transform.is_finite() and _chest.transform.is_finite() and _head.transform.is_finite() and _left_arm.transform.is_finite() and _right_arm.transform.is_finite() and _left_leg.transform.is_finite() and _right_leg.transform.is_finite() and _left_hand.transform.is_finite() and _right_hand.transform.is_finite()



func _auto_clavicles() -> void :
	for side in [-1, 1]:
		var clav: Node3D = _right_clav if side > 0 else _left_clav
		var arm: Node3D = _right_arm if side > 0 else _left_arm
		var elbow: Node3D = _right_elbow if side > 0 else _left_elbow
		var direction: Vector3 = clav.quaternion * (arm.quaternion * elbow.position.normalized())
		var raise: float = smoothstep(-0.35, 1.0, direction.y) * 0.34
		var reach: float = clampf( - direction.z, 0.0, 1.0) * 0.12
		var auto_q: Quaternion = Quaternion.from_euler(Vector3(0.0, side * reach, side * raise))
		var arm_world: Quaternion = clav.quaternion * arm.quaternion
		clav.quaternion = clav.quaternion * auto_q
		arm.quaternion = clav.quaternion.inverse() * arm_world



func _split_joints() -> void :
	if _split_done: return
	_split_done = true
	var chest: Quaternion = _chest.quaternion
	if not chest.is_equal_approx(Quaternion.IDENTITY):
		var half: Quaternion = Quaternion.IDENTITY.slerp(chest, 0.5)
		_spine.quaternion = half
		_chest.quaternion = half
	var head: Quaternion = _head.quaternion
	if not head.is_equal_approx(Quaternion.IDENTITY):
		var neck: Quaternion = Quaternion.IDENTITY.slerp(head, 0.35)
		_neck.quaternion = neck
		_head.quaternion = neck.inverse() * head
	if is_instance_valid(_imported): _imported.set_forearm_twist(_twist_of(_left_hand), _twist_of(_right_hand))

func _twist_of(hand: Node3D) -> float:
	var q: Quaternion = hand.quaternion
	if q.w > 0.99995: return 0.0
	var axis: Vector3 = hand.position.normalized()
	var along: float = q.x * axis.x + q.y * axis.y + q.z * axis.z
	var angle: float = 2.0 * atan2(along, q.w)
	if angle > PI: angle -= TAU
	elif angle < - PI: angle += TAU
	return angle

func _sync_now() -> void :
	_sync_queued = false
	if is_instance_valid(_imported): _imported.sync(_clock, _move_blend)



func _request_sync() -> void :
	if _sync_queued: return
	_sync_queued = true
	_flush_sync.call_deferred()

func _flush_sync() -> void :
	if not _sync_queued: return
	_sync_queued = false
	if not is_instance_valid(_body) or not is_inside_tree(): return
	if not _pose_finite():
		_reset_motion_state()
		_reset_pose()
	if not _split_done: _auto_clavicles()
	_split_joints()
	_apply_props()
	if is_instance_valid(_imported): _imported.sync(_clock, _move_blend)


func _sync_surface_pose() -> void :
	_request_sync()

func _apply_squash() -> void :
	var target: Vector3 = Vector3.ONE * _model_scale
	if _life_state == "alive" and _st_roll <= 0.0:

		var squash: float = clampf( - _land_offset * 2.5, 0.0, 0.5)
		var stretch: float = clampf(_st_vertical / 12.4, 0.0, 1.0) * _air_blend * 0.04
		var vertical: float = 1.0 - 0.06 * squash + stretch
		var across: float = 1.0 + 0.03 * squash - stretch * 0.45
		target = Vector3(across, vertical, across) * _model_scale
	if absf(_clip_squash - 1.0) > 0.002:

		var k: float = clampf(_clip_squash, 0.6, 1.5)
		target *= Vector3(1.0 / sqrt(k), k, 1.0 / sqrt(k))
	if not scale.is_equal_approx(target): scale = target



func _face(mood: String, blink: bool = true) -> void :
	if not is_instance_valid(_imported): return
	_face_ctrl.fatigue = _fatigue
	_face_ctrl.lid = _clip_lid
	_face_ctrl.chatter = _clip_chatter
	if _speak_left > 0.0:
		_speak_left = maxf(0.0, _speak_left - _face_dt)

		_face_ctrl.chatter = maxf(_face_ctrl.chatter, _speak_intensity * 0.6 * (0.55 + 0.45 * sin(_clock * 7.3)) * minf(1.0, _speak_left * 4.0))
	_face_ctrl.jaw_min = _clip_jaw
	var weights: PackedFloat32Array = _face_ctrl.update(_face_dt, mood, blink)
	_imported.set_face_weights(weights)
	var lids: Vector3 = _face_ctrl.lids

	if _life_state == "dead": lids = Vector3(1.0, 0.0, 0.0)
	_imported.set_eyelids(lids.x, lids.y, lids.z)



func _show_prop(prop_name: String) -> void :
	if not _clone and _props.has(prop_name): _prop_wanted[prop_name] = true


func _apply_props() -> void :
	if _prop_wanted.is_empty() and _props_attached == 0: return
	for prop_name: String in _props:
		var node: MeshInstance3D = _props[prop_name]
		var wanted: bool = _prop_wanted.has(prop_name)
		var attached: bool = node.get_parent() != null
		if wanted and not attached:
			_prop_hands[prop_name].add_child(node)
			_props_attached += 1
		elif not wanted and attached:
			node.get_parent().remove_child(node)
			_props_attached -= 1

func _hide_props() -> void :
	_prop_wanted.clear()
	_apply_props()



func _update_blob(dt: float) -> void :
	if not is_instance_valid(_blob): return
	if not blob_shadow or not is_inside_tree():
		if _blob.visible: _blob.visible = false
		return
	var center: Vector3 = _body.global_position
	var feet: Vector3 = (_ankles[-1].global_position + _ankles[1].global_position) * 0.5
	center.x = lerpf(center.x, feet.x, 0.5)
	center.z = lerpf(center.z, feet.z, 0.5)
	_blob_timer -= dt
	if _blob_timer <= 0.0:

		_blob_timer = (0.12 if _st_grounded else 0.05) * (1.0 if _detail >= 1 else 2.0)
		var origin: Vector3 = global_position
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(center.x, maxf(origin.y, feet.y) + 0.5, center.z), Vector3(center.x, origin.y - 4.5, center.z), 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			if not _st_grounded: _blob_found = false
			else:
				_blob_found = true
				_blob_floor = origin.y
				_blob_normal = Vector3.UP
		else:
			var floor_y: float = float(hit.position.y)
			_blob_floor = floor_y if not _blob_found or absf(floor_y - _blob_floor) > 0.6 else lerpf(_blob_floor, floor_y, 0.6)
			_blob_normal = hit.normal
			_blob_found = true
	var strength: float = 0.0
	var height: float = 0.0
	if _blob_found:
		height = maxf(0.0, feet.y - _ankle_height * _model_scale - _blob_floor)
		strength = 1.0 - smoothstep(0.05, 2.6, height)

		if _st_grounded and absf(global_position.y - _blob_floor) > 0.12: strength *= 0.55
		if _blob_normal.y < 0.55: strength = 0.0
	var show: bool = strength > 0.02
	var appearing: bool = show and not _blob.visible
	if _blob.visible != show: _blob.visible = show
	if not show: return
	var radius: float = (0.46 if not _is_alice else 0.54) * (_model_scale / 0.75) * (1.0 - 0.3 * smoothstep(0.0, 2.6, height))
	if _life_state != "alive": radius *= 1.35
	var up: Vector3 = _blob_normal.normalized()
	var basis: Basis = Basis(Quaternion(Vector3.UP, up)) if up.dot(Vector3.UP) < 0.9999 else Basis.IDENTITY
	_blob.global_transform = Transform3D(basis * Basis.from_scale(Vector3(radius * 2.0, 1.0, radius * 2.0)), Vector3(center.x, _blob_floor + 0.025, center.z))

	if appearing: _blob.reset_physics_interpolation()
	if absf(strength - _blob_strength) > 0.03:
		_blob_strength = strength
		_blob.set_instance_shader_parameter("strength", strength)

func _update_aura(dt: float) -> void :
	if not is_instance_valid(_aura) or not _aura.visible: return
	_aura.rotation.y += dt * 0.6
	_aura.position.y = 0.04 + sin(_clock * 2.4) * 0.01




func _reset_pose(legs: bool = true) -> void :
	_split_done = false
	_ik_legs = false;_ik_hand_left = false;_ik_hand_right = false
	_plant_weight = 1.0
	_feet_dirty = false
	_body.position = Vector3(0, _base_height, 0);_body.rotation = Vector3.ZERO
	_spine.quaternion = Quaternion.IDENTITY;_chest.rotation = Vector3.ZERO
	_neck.quaternion = Quaternion.IDENTITY;_head.rotation = Vector3.ZERO
	_left_clav.rotation = Vector3.ZERO;_right_clav.rotation = Vector3.ZERO
	_left_elbow.rotation = Vector3.ZERO;_right_elbow.rotation = Vector3.ZERO
	_left_hand.rotation = Vector3.ZERO;_right_hand.rotation = Vector3.ZERO
	_left_arm.rotation = Vector3(0, 0, -0.14);_right_arm.rotation = Vector3(0, 0, 0.14)
	_clav_manual = false
	if not legs: return
	_left_leg.rotation = Vector3.ZERO;_right_leg.rotation = Vector3.ZERO
	_left_knee.rotation = Vector3.ZERO;_right_knee.rotation = Vector3.ZERO
	_ankles[-1].rotation = Vector3.ZERO;_ankles[1].rotation = Vector3.ZERO
	_toes[-1].quaternion = Quaternion.IDENTITY;_toes[1].quaternion = Quaternion.IDENTITY
	for side in [-1, 1]:
		_foot_target[side] = _foot_rest[side]
		_foot_pitch[side] = 0.0





func _update_gait(speed: float) -> void :
	var leg_m: float = maxf(_leg_reach * _model_scale, 0.3)
	_g_move = smoothstep(0.08, 0.6, speed)
	_g_run = smoothstep(2.0, 3.6, speed)
	_g_sprint = smoothstep(6.6, 10.0, speed)
	_g_boost = smoothstep(12.0, 19.0, speed)
	_g_weights[AnimGait.WALK] = 1.0 - _g_run
	_g_weights[AnimGait.RUN] = _g_run * (1.0 - _g_sprint)
	_g_weights[AnimGait.SPRINT] = _g_run * _g_sprint * (1.0 - _g_boost)
	_g_weights[AnimGait.BOOST] = _g_run * _g_sprint * _g_boost
	AnimGait.mix(_g_weights, _g_par, _g_thigh, _g_knee, _g_ankle, float(_style.knee_lift), float(_style.heel_kick))

	# Cadence réelle selon la vitesse (jambes courtes = pas plus rapides), puis course du pied d'appui :
	# le pied posé recule exactement à la vitesse du sol, la part d'appui en découle (pas de glissement).
	var cadence: float = AnimGait.cadence(speed) * sqrt(AnimGait.REFERENCE_LEG / leg_m) * float(_style.cadence)
	var sweep_max: float = leg_m * _g_par[AnimGait.P_SWEEP] * float(_style.stride)
	var duty_goal: float = _g_par[AnimGait.P_DUTY]
	var sweep_m: float = minf(sweep_max, duty_goal * speed / maxf(cadence, 0.1))

	var walk_cadence: float = 0.56 * speed / maxf(sweep_max, 0.05)
	cadence = lerpf(cadence, maxf(cadence, walk_cadence), _g_weights[AnimGait.WALK])
	sweep_m = minf(sweep_max, duty_goal * speed / maxf(cadence, 0.1))
	var stance: float = clampf(sweep_m * cadence / maxf(speed, 0.001), 0.08, 0.66)
	_g_cadence = cadence if speed > 0.02 else 0.0
	_g_stance = stance
	_g_sweep = sweep_m / _model_scale

	var flight: float = maxf(0.0, 0.5 - stance) / maxf(cadence, 0.1)
	_g_flight = 9.8 * flight * flight / 8.0 / _model_scale
	_g_lift = float(_style.knee_lift)

func _locomotion(dt: float) -> void :
	_update_gait(_move_blend)
	_gait_phase = fposmod(_gait_phase + dt * _g_cadence, 1.0)
	_gait = _gait_phase * TAU
	var direction: Vector3 = Vector3.FORWARD.lerp(_move_dir, _g_move)
	if direction.length_squared() < 0.0001: direction = Vector3.FORWARD
	_idle_pose(dt)
	_gait_pose(_gait_phase, direction.normalized())
	_style_overlays(dt)







func _style_overlays(dt: float) -> void :
	var tense: bool = (_st_chased or _st_lms) and _life_state == "alive"
	_alert_blend = move_toward(_alert_blend, 1.0 if tense else 0.0, dt * (5.0 if tense else 1.6))
	_boost_blend = move_toward(_boost_blend, 1.0 if _st_speed_boost else 0.0, dt * 6.0)
	var still: float = 1.0 - smoothstep(0.05, 0.75, _g_move)
	if still > 0.01:
		var alert: Dictionary = _get_clip("alert")
		var alert_weight: float = _alert_blend if not alert.is_empty() else 0.0
		if alert_weight < 0.99: _apply_clip(_get_clip("stance"), _clock, still * (1.0 - alert_weight), _clock - dt)
		if alert_weight > 0.01: _apply_clip(alert, _clock, still * alert_weight, _clock - dt)

	var before: float = _gait_previous
	_gait_previous = _gait_phase
	var walking: float = _g_move * (1.0 - _g_run)
	if walking > 0.01:
		var walk: Dictionary = _get_clip("walk")
		if not walk.is_empty(): _apply_clip(walk, _gait_phase * float(walk.len), walking, before * float(walk.len))
	var pocket: Dictionary = _get_clip("pocket")
	if not pocket.is_empty():


		var keep: bool = not _st_sprinting and not _st_speed_boost and not _st_boost_time and _move_blend < 8.6 and _life_state == "alive"
		_g_pocket = move_toward(_g_pocket, (1.0 - 0.6 * _air_blend) if keep else 0.0, dt * (3.5 if keep else 5.0))
		if _g_pocket * _g_move > 0.01: _apply_clip(pocket, _gait_phase * float(pocket.len), _g_pocket * _g_move, before * float(pocket.len))
	var running: float = _g_run * _g_move
	if running > 0.01:
		var boost: Dictionary = _get_clip("boost") if _boost_blend > 0.01 else {}
		var boost_weight: float = _boost_blend if not boost.is_empty() else 0.0
		var sprint: Dictionary = _get_clip("sprint")
		var sprint_weight: float = (_g_sprint if not sprint.is_empty() else 0.0) * (1.0 - boost_weight)
		var run: Dictionary = _get_clip("run")
		var run_weight: float = (1.0 - sprint_weight) * (1.0 - boost_weight) if not run.is_empty() else 0.0
		if run_weight > 0.01: _apply_clip(run, _gait_phase * float(run.len), running * run_weight, before * float(run.len))
		if sprint_weight > 0.01: _apply_clip(sprint, _gait_phase * float(sprint.len), running * sprint_weight, before * float(sprint.len))
		if boost_weight > 0.01: _apply_clip(boost, _gait_phase * float(boost.len), running * boost_weight, before * float(boost.len))

	if _g_move > 0.6 and _st_grounded and _life_state == "alive" and not _st_boost_time and not _st_grinding:
		var beat: int = int(_gait_phase * 2.0)
		if beat != _step_beat:
			_step_beat = beat
			anim_fx.emit("step_l" if beat == 0 else "step_r")



func _update_idle_state(dt: float) -> void :

	_shift_timer -= dt * float(_style.shift_rate)
	if _shift_timer <= 0.0:
		_shift_timer = _rng.randf_range(4.5, 11.0)
		_weight_target = - signf(_weight_target) if absf(_weight_target) > 0.1 else (1.0 if _rng.randf() < 0.5 else -1.0)
		if _rng.randf() < 0.18: _weight_target *= 0.3
	_weight_side = move_toward(_weight_side, _weight_target, dt * 0.9)

	_look_timer -= dt * float(_style.look_rate)
	if _look_timer <= 0.0:
		_look_timer = _rng.randf_range(1.4, 4.2)
		var reach: float = float(_style.look_range)
		if _rng.randf() < 0.35: _look_target = Vector2.ZERO
		else: _look_target = Vector2(_rng.randf_range(-0.55, 0.55) * reach, _rng.randf_range(-0.12, 0.1))

	var omega: float = 13.0 if float(_style.snappy) > 0.5 else 5.5
	var zeta: float = 1.0 if float(_style.snappy) > 0.5 else 0.8
	var steps: int = ceili(dt / 0.02)
	var h: float = dt / float(steps)
	for i in range(steps):
		_look_speed += ((_look_target - _look) * omega * omega - _look_speed * 2.0 * zeta * omega) * h
		_look += _look_speed * h

	var running: float = smoothstep(7.0, 10.0, _move_blend)
	_fatigue = clampf(_fatigue + dt * (running * 0.09 - 0.06), 0.0, 1.0)
	_breath_phase += dt * TAU * (0.24 + 0.4 * _fatigue) * (1.0 + 0.3 * _g_run)


func _idle_pose(dt: float) -> void :
	_update_idle_state(dt)

	if _g_move >= 0.999 and not _idle_feet.is_empty(): return
	var leg: float = _leg_reach
	var contra: float = float(_style.contra)
	var ws: float = _weight_side * contra
	var breath: float = sin(_breath_phase) * float(_style.breath) * (1.0 + 1.6 * _fatigue)
	var bounce: float = float(_style.idle_bounce)
	var sway_style: float = float(_style.idle_sway)
	var slow: float = _clock * 0.9 + _temperament
	var hips: Vector3 = Vector3(_weight_side * 0.032 * leg * minf(contra, 1.2), -0.012 * leg * absf(ws) - 0.006 * leg, 0.0)
	hips.x += sway_style * 0.018 * leg * sin(slow * 1.35)
	hips.y += bounce * 0.01 * leg * (0.5 + 0.5 * sin(_clock * 7.4)) * (0.6 + 0.4 * sin(_clock * 0.7))
	hips.y -= 0.003 * leg * breath
	_idle_hips = hips
	_idle_body = Vector3(-0.012 - float(_style.slouch) * 0.3, ws * 0.018, ws * 0.05 + sway_style * 0.025 * sin(slow * 1.35 + 0.4))
	_idle_chest = Vector3(0.012 * breath - float(_style.slouch), - ws * 0.03, - ws * 0.04 - sway_style * 0.02 * sin(slow * 1.35 + 0.9))
	var tilt: float = float(_style.head_tilt)
	_idle_head = Vector3(_look.y + float(_style.slouch) * 0.9 - float(_style.head_fwd) * 0.3 - 0.004 * breath, _look.x, ws * 0.035 + tilt * sin(_clock * 0.31 + _temperament) + sway_style * 0.07 * sin(slow * 1.35 + 1.4))
	var arm_x: float = float(_style.idle_arm_x)
	var arm_z: float = 0.1 + float(_style.idle_arm_z)
	var elbow: float = float(_style.idle_elbow)
	for side in [-1, 1]:

		var loaded: float = maxf(0.0, _weight_side * side)
		var drift: float = sin(_clock * 0.53 + side * 1.3 + _temperament) * 0.02
		_idle_arm[side] = Vector3(arm_x + drift + 0.01 * breath, 0.0, side * (arm_z + 0.012 * breath - 0.02 * loaded))
		_idle_elbow[side] = elbow + 0.06 * (1.0 - loaded) + 0.015 * breath
	_idle_clav = 0.018 * breath

	var width: float = float(_style.stance)
	for side in [-1, 1]:
		var rest: Vector3 = _foot_rest[side]
		var free: float = maxf(0.0, - _weight_side * side) * contra
		var target: Vector3 = rest
		target.x = rest.x * width + side * 0.035 * leg * free
		target.z = rest.z - 0.07 * leg * free
		_idle_feet[side] = target
		_idle_foot_yaw[side] = side * 0.12 * free






func _gait_pose(phase: float, direction: Vector3) -> void :
	var move: float = _g_move
	var run: float = _g_run * move
	var par: PackedFloat32Array = _g_par
	var stance: float = _g_stance
	var leg: float = _leg_reach
	var cycle: float = TAU * phase
	var forward: float = clampf( - direction.z, -1.0, 1.0)
	var ahead: float = maxf(forward, 0.0)
	var glide: float = float(_style.glide)
	var snappy: float = float(_style.snappy)
	var pocket: float = _g_pocket



	var step: float = fposmod(phase * 2.0, 1.0)
	var step_stance: float = minf(stance * 2.0, 1.0)
	var lead: float = _g_sweep * par[AnimGait.P_LEAD]
	var rest_drop: float = (float(_hip_rest[-1].y) + float(_hip_rest[1].y) - float(_foot_rest[-1].y) - float(_foot_rest[1].y)) * 0.5
	var reach: float = leg * 0.97
	var touchdown: float = maxf(0.0, rest_drop - sqrt(maxf(reach * reach - lead * lead, 0.0)))
	var crouch: float = (par[AnimGait.P_CROUCH] * leg + touchdown * _g_run) * move * (1.0 - 0.5 * glide)
	var walk_bob: float = - 0.6 * touchdown * (0.5 + 0.5 * cos(TAU * step)) + 0.006 * leg
	var run_bob: float = 0.0
	if step < step_stance: run_bob = - par[AnimGait.P_PRESS] * float(_style.press) * leg * sin(PI * step / maxf(step_stance, 0.01))
	else: run_bob = _g_flight * (1.0 + 0.5 * float(_style.hop)) * sin(PI * (step - step_stance) / maxf(1.0 - step_stance, 0.01))
	var bob: float = lerpf(walk_bob, run_bob, _g_run) * float(_style.bob) * move * (1.0 - 0.6 * glide)
	var sway: float = - par[AnimGait.P_SWAY] * leg * float(_style.sway) * move * sin(cycle)

	var list: float = 0.0
	for side in [-1, 1]:
		var p: float = phase if side < 0 else fposmod(phase + 0.5, 1.0)
		if p < stance: list += float(side) * sin(PI * p / maxf(stance, 0.01))
	var roll: float = list * par[AnimGait.P_ROLL] * float(_style.sway) * move * (1.0 - 0.5 * glide)
	var pelvis_yaw: float = - par[AnimGait.P_YAW] * move * cos(cycle + 0.12) * (1.0 - 0.5 * glide) * lerpf(1.0, 0.45, snappy)
	var lean: float = par[AnimGait.P_LEAN] * float(_style.lean) * move * lerpf(0.4, 1.0, ahead)
	var dip: float = - 0.025 * run * cos(TAU * step - 0.9)
	var pitch: float = - lean * 0.45 + dip + 0.05 * move * maxf( - forward, 0.0) + _lean_pitch
	var body_roll: float = roll + _lean_roll
	var hips: Vector3 = Vector3(sway, bob - crouch, 0.0)
	var body_rot: Vector3 = Vector3(pitch, pelvis_yaw, body_roll)


	var twist: float = par[AnimGait.P_TWIST] * float(_style.twist) * (1.0 + 0.7 * pocket)
	var chest_yaw: float = - pelvis_yaw * (1.0 + twist) * (1.0 - 0.75 * snappy)
	var chest_rot: Vector3 = Vector3( - float(_style.slouch) * 0.6 - lean * 0.55 - dip * 0.5, chest_yaw, - body_roll * 0.6)
	var turn_look: float = clampf(_yaw_rate * 0.12, -0.45, 0.45)
	var nod: float = 0.0
	if snappy < 0.5: nod = par[AnimGait.P_NOD] * run * sin(TAU * step - 0.6)
	var head_rot: Vector3 = Vector3( - (pitch + chest_rot.x) * 0.68 + nod - float(_style.head_fwd) * 0.4 * move, - (pelvis_yaw + chest_yaw) * 0.85 + turn_look, - body_roll * 0.55)
	_blend_body(hips, body_rot, chest_rot, head_rot, move)



	var swing_amount: float = float(_style.arm_swing)
	for side in [-1, 1]:
		var sign_side: float = 1.0 if side > 0 else -1.0

		var arm_phase: float = cycle + 0.15 + (PI if side < 0 else 0.0)
		var swing: float = cos(arm_phase)
		var swing_elbow: float = cos(arm_phase - float(_style.elbow_lag))
		if snappy > 0.5:
			swing = tanh(2.4 * swing) / tanh(2.4)
			swing_elbow = swing
		var front: float = maxf(0.0, swing)
		var back: float = maxf(0.0, - swing)
		var arm_x: float = (par[AnimGait.P_ARM_F] * front - par[AnimGait.P_ARM_B] * back) * swing_amount + 0.06 * run
		var elbow: float = par[AnimGait.P_ELB] + par[AnimGait.P_ELB_F] * maxf(0.0, swing_elbow) - par[AnimGait.P_ELB_B] * maxf(0.0, - swing_elbow) + float(_style.elbow) * _g_run

		if snappy > 0.5: elbow = lerpf(elbow, par[AnimGait.P_ELB] + 0.1 * _g_run + float(_style.elbow) * _g_run, snappy)
		var arm_z: float = sign_side * (par[AnimGait.P_ABD] + float(_style.arm_out) + 0.05 * back * _g_run)
		var arm_y: float = sign_side * par[AnimGait.P_CROSS] * front * float(_style.cross) - (pelvis_yaw + chest_yaw) * front * 0.8
		var arm_node: Node3D = _right_arm if side > 0 else _left_arm
		var elbow_node: Node3D = _right_elbow if side > 0 else _left_elbow
		var hand_node: Node3D = _right_hand if side > 0 else _left_hand
		arm_node.rotation = _idle_arm[side].lerp(Vector3(arm_x, arm_y, arm_z), move)
		elbow_node.rotation = Vector3(lerpf(_idle_elbow[side], clampf(elbow, 0.0, 2.3), move), 0.0, 0.0)

		hand_node.rotation = Vector3(-0.16 * back * run + 0.1 * front * run, 0.0, sign_side * 0.05 * (1.0 - move) - sign_side * 0.08 * run)
	var breath_clav: float = _idle_clav * (1.0 - move) + 0.012 * sin(_breath_phase) * run
	_left_clav.rotation = Vector3(0.0, 0.0, - breath_clav)
	_right_clav.rotation = Vector3(0.0, 0.0, breath_clav)



	var foot_x: float = _hip_half_width * par[AnimGait.P_WIDTH] * float(_style.stance)
	var stagger: float = smoothstep(0.0, 0.35, _move_blend)
	var last: int = AnimGait.KNOTS.size() - 1
	var shank_start: float = _g_thigh[0] - _g_knee[0]
	var shank_end: float = _g_thigh[last] - _g_knee[last]
	var height_scale: float = 1.0 if forward >= 0.5 else lerpf(0.35, 1.0, ahead * 2.0)
	for side in [-1, 1]:
		var p: float = phase if side < 0 else fposmod(phase + 0.5, 1.0)
		var base: Vector3 = Vector3(side * foot_x, _foot_rest[side].y, _foot_rest[side].z)
		var target: Vector3 = Vector3.ZERO
		var foot_pitch: float = 0.0
		if p < stance:
			var s: float = p / stance
			target = base + direction * lerpf(lead, lead - _g_sweep, s) * stagger
			foot_pitch = _stance_pitch(s)
		else:
			var s: float = (p - stance) / (1.0 - stance)
			var knee_node: Node3D = _left_knee if side < 0 else _right_knee
			var leg_node: Node3D = _left_leg if side < 0 else _right_leg
			var upper: float = knee_node.position.length()
			var lower: float = _ankles[side].position.length()
			var hip: Vector3 = _body.position + _body.quaternion * leg_node.position
			var hip_along: float = (hip - _hip_rest[side]).dot(direction)
			var thigh: float = AnimGait.sample(_g_thigh, s)
			var shank: float = thigh - AnimGait.sample(_g_knee, s)
			var path: Vector2 = Vector2(upper * sin(thigh) + lower * sin(shank), upper * cos(thigh) + lower * cos(shank))
			var path_start: Vector2 = Vector2(upper * sin(_g_thigh[0]) + lower * sin(shank_start), upper * cos(_g_thigh[0]) + lower * cos(shank_start))
			var path_end: Vector2 = Vector2(upper * sin(_g_thigh[last]) + lower * sin(shank_end), upper * cos(_g_thigh[last]) + lower * cos(shank_end))


			var lift_off: Vector3 = base + direction * (lead - _g_sweep) * stagger
			var toe_pitch: float = par[AnimGait.P_TOE]
			lift_off.y += _toe_length * sin( - toe_pitch)
			if _g_lift_off.has(side):
				var left: Array = _g_lift_off[side]
				lift_off = left[0]
				toe_pitch = float(left[1])
			var landing: Vector3 = base + direction * lead * stagger
			landing.y += _toe_length * maxf(0.0, sin( - par[AnimGait.P_C0]))
			# Trajectoire du pied par la cinématique directe (cuisse, genou), recalée sur le point de décollage au début
			# et sur le point de pose à la fin ; au milieu, le pied suit le rebond du bassin.
			var fk: Vector3 = base + direction * ((hip_along + path.x) * stagger)
			fk.y = hip.y - bob - path.y + bob * sin(PI * s)
			var fk_start: Vector3 = base + direction * ((hip_along + path_start.x) * stagger)
			fk_start.y = hip.y - bob - path_start.y
			var fk_end: Vector3 = base + direction * ((hip_along + path_end.x) * stagger)
			fk_end.y = hip.y - bob - path_end.y
			var early: float = 1.0 - smoothstep(0.0, 0.5, s)
			var late: float = smoothstep(0.45, 1.0, s)
			target = fk + (lift_off - fk_start) * early + (landing - fk_end) * late
			target.y = _foot_rest[side].y + (target.y - _foot_rest[side].y) * height_scale
			var ankle: float = AnimGait.sample(_g_ankle, s)
			foot_pitch = shank + ankle
			foot_pitch += (toe_pitch - (shank_start + _g_ankle[0])) * (1.0 - smoothstep(0.0, 0.4, s))
			foot_pitch += (par[AnimGait.P_C0] - (shank_end + _g_ankle[last])) * smoothstep(0.6, 1.0, s)
			var clearance: float = _foot_rest[side].y + _toe_length * maxf(0.0, sin( - foot_pitch)) * 0.8
			target.y = maxf(target.y, clearance)

		var idle_foot: Vector3 = _idle_feet.get(side, _foot_rest[side])
		target = idle_foot.lerp(target, move)
		foot_pitch *= move

		var hip_rest: Vector3 = _hip_rest[side]
		var leg_reach: float = float(_leg_length[side]) * 0.985
		var offset: Vector2 = Vector2(target.x - hip_rest.x, target.z - hip_rest.z)
		var reach_height: float = sqrt(maxf(leg_reach * leg_reach - offset.length_squared(), 0.0))
		var peel: float = maxf(0.0, (hip_rest.y + _body.position.y - _base_height) - reach_height - target.y)

		if p < stance and foot_pitch < 0.0:
			var toe_rest: Vector3 = (_toes[side] as Node3D).position
			target += toe_rest - Quaternion(Vector3.RIGHT, foot_pitch) * toe_rest
		if peel > 0.0:
			target.y += peel
			if p < stance: foot_pitch = minf(foot_pitch, - clampf(peel / maxf(_toe_length, 0.06), 0.0, 0.7))
		_foot_target[side] = target
		_foot_pitch[side] = foot_pitch
		if p < stance and move > 0.999: _g_lift_off[side] = [target, foot_pitch]
		elif p < stance: _g_lift_off.erase(side)
		_leg_ik(side, target, foot_pitch, 1.0)
	_ik_body = _body.transform


func _stance_pitch(s: float) -> float:
	var par: PackedFloat32Array = _g_par
	var flat: float = par[AnimGait.P_FLAT]
	if s < 0.3: return lerpf(par[AnimGait.P_C0], flat, smoothstep(0.0, 0.3, s))
	var rise: float = par[AnimGait.P_RISE]
	if s < rise: return flat
	var u: float = (s - rise) / maxf(1.0 - rise, 0.01)
	return lerpf(flat, par[AnimGait.P_TOE], u * u)


func _blend_body(hips: Vector3, body_rot: Vector3, chest_rot: Vector3, head_rot: Vector3, move: float) -> void :
	_body.position = Vector3(0.0, _base_height, 0.0) + _idle_hips.lerp(hips, move)
	_body.rotation = _idle_body.lerp(body_rot, move)
	_chest.rotation = _idle_chest.lerp(chest_rot, move)
	_head.rotation = _idle_head.lerp(head_rot, move)
	if move > 0.001:

		_head.rotation.y += _look.x * 0.4 * (1.0 - _g_run) * move

	if _glance_back > 0.0:
		var glance: float = sin(PI * clampf(_glance_back / 0.75, 0.0, 1.0))
		_head.rotation.y += _glance_side * 1.05 * glance
		_chest.rotation.y += _glance_side * 0.28 * glance
		_head.rotation.x += 0.08 * glance


func _leg_ik(side: int, target: Vector3, foot_pitch: float, weight: float) -> void :
	var leg: Node3D = _left_leg if side < 0 else _right_leg
	var knee: Node3D = _left_knee if side < 0 else _right_knee
	var ankle: Node3D = _ankles[side]
	var body_q: Quaternion = _body.quaternion
	var hip: Vector3 = _body.position + body_q * leg.position
	var upper: float = knee.position.length()
	var lower: float = ankle.position.length()
	var to_target: Vector3 = target - hip
	var distance: float = clampf(to_target.length(), 0.05, (upper + lower) * 0.999)
	var direction: Vector3 = to_target.normalized() if to_target.length_squared() > 1e-06 else Vector3.DOWN
	var along: float = (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, upper * upper - along * along))

	var pole: Vector3 = body_q * Vector3(side * (0.12 + 0.15 * (float(_style.stance) - 1.0)), 0.0, -1.0)

	var facing: Vector3 = body_q * Vector3.FORWARD
	if facing.y < -0.4:
		var flat: Vector3 = Vector3(facing.x, 0.0, facing.z)
		if flat.length_squared() > 0.0001: pole = Quaternion(facing.normalized(), flat.normalized() * 0.9165 + Vector3(0.0, -0.4, 0.0)) * pole
	var bend: Vector3 = pole - direction * pole.dot(direction)
	if bend.length_squared() < 1e-06: bend = body_q * Vector3.FORWARD
	bend = bend.normalized()
	var knee_point: Vector3 = hip + direction * along + bend * height
	var foot_point: Vector3 = hip + direction * distance
	var thigh_global: Quaternion = Quaternion(knee.position.normalized(), (knee_point - hip).normalized())
	var shin_rest: Vector3 = thigh_global * ankle.position.normalized()
	var shin_global: Quaternion = Quaternion(shin_rest, (foot_point - knee_point).normalized()) * thigh_global
	_thigh_forward[side] = clampf( - (knee_point - hip).normalized().z, -1.0, 1.0)
	var foot_yaw: float = float(_idle_foot_yaw.get(side, 0.0)) * (1.0 - _g_move) + _clip_turn
	var foot_global: Quaternion = Quaternion(Vector3.UP, foot_yaw) * Quaternion(Vector3.RIGHT, foot_pitch)
	var leg_q: Quaternion = body_q.inverse() * thigh_global
	var knee_q: Quaternion = thigh_global.inverse() * shin_global
	var ankle_q: Quaternion = shin_global.inverse() * foot_global
	var toe_q: Quaternion = Quaternion(Vector3.RIGHT, - foot_pitch) if foot_pitch < 0.0 else Quaternion.IDENTITY
	if weight >= 0.999:
		leg.quaternion = leg_q;knee.quaternion = knee_q;ankle.quaternion = ankle_q;_toes[side].quaternion = toe_q
	else:
		leg.quaternion = leg.quaternion.slerp(leg_q, weight)
		knee.quaternion = knee.quaternion.slerp(knee_q, weight)
		ankle.quaternion = ankle.quaternion.slerp(ankle_q, weight)
		_toes[side].quaternion = _toes[side].quaternion.slerp(toe_q, weight)
	_ik_legs = true




func _replant_feet() -> void :
	if _plant_weight <= 0.001 or _foot_target.is_empty(): return
	if not _feet_dirty and _body.transform.is_equal_approx(_ik_body): return
	var w: float = clampf(_plant_weight, 0.0, 1.0)
	for side in [-1, 1]: _leg_ik(side, _foot_target[side], _foot_pitch[side], w)


func _walk_pose(speed: float, time: float) -> void :
	_move_blend = speed
	_update_gait(speed)
	_gait_pose(fposmod(time / TAU, 1.0), Vector3.FORWARD)





func _air_pose() -> void :
	if _life_state != "alive": return
	if _air_blend > 0.001:
		var clip: Dictionary = _get_clip("air")
		if not clip.is_empty():
			var phase: float = clampf(0.5 - _st_vertical / 15.0, 0.0, 1.0)
			_apply_clip(clip, phase * float(clip.len), _air_blend)
	var compression: float = _land_offset
	if absf(compression) > 0.0005:
		_body.position.y += compression * _leg_reach * 1.25
		_body.rotation.x += compression * 1.3
		_chest.rotation.x += compression * 0.7
		_head.rotation.x -= compression * 1.0
		_left_arm.rotation.x += compression * 0.9;_right_arm.rotation.x += compression * 0.9
		_left_arm.rotation.z += compression * 1.1;_right_arm.rotation.z -= compression * 1.1
		_left_elbow.rotation.x -= compression * 0.8;_right_elbow.rotation.x -= compression * 0.8

func _step_land_spring(dt: float) -> void :
	var total: float = minf(dt, 0.25)
	var steps: int = maxi(1, ceili(total / 0.02))
	var step: float = total / float(steps)
	var omega: float = 15.0
	var zeta: float = 0.5
	for i in range(steps):
		_land_speed += ( - _land_offset * omega * omega - _land_speed * 2.0 * zeta * omega) * step
		_land_offset = clampf(_land_offset + _land_speed * step, -0.2, 0.06)






func _kick_hit(strength: float, push: Vector3) -> void :
	var s: float = clampf(strength, 0.25, 1.5)
	_hit_vel += Vector3(push.z * 5.2, - push.x * 1.6, - push.x * 5.2) * s
	_hit_head_vel += Vector3(push.z * 8.0, - push.x * 2.5, - push.x * 6.0) * s
	_hit_arm_vel += 7.5 * s
	_hit_drop_vel -= 1.2 * s

func _step_hit_springs(dt: float) -> void :
	var steps: int = ceili(minf(dt, 0.25) / 0.02)
	var h: float = minf(dt, 0.25) / float(maxi(steps, 1))
	for i in range(maxi(steps, 1)): _hit_spring_step(h)

func _hit_spring_step(step: float) -> void :

	_hit_vel += ( - _hit_rot * 169.0 - _hit_vel * 2.0 * 0.4 * 13.0) * step
	_hit_rot += _hit_vel * step

	var head_goal: Vector3 = _hit_rot * 0.6
	_hit_head_vel += ((head_goal - _hit_head) * 81.0 - _hit_head_vel * 2.0 * 0.32 * 9.0) * step
	_hit_head += _hit_head_vel * step
	_hit_arm_vel += ( - _hit_arm * 100.0 - _hit_arm_vel * 2.0 * 0.45 * 10.0) * step
	_hit_arm += _hit_arm_vel * step
	_hit_drop_vel += ( - _hit_drop * 144.0 - _hit_drop_vel * 2.0 * 0.6 * 12.0) * step
	_hit_drop += _hit_drop_vel * step
	_hit_rot = _hit_rot.limit_length(0.6)
	_hit_head = _hit_head.limit_length(0.8)

func _apply_hit_springs() -> void :
	if _hit_rot.length_squared() + _hit_head.length_squared() + _hit_arm * _hit_arm + _hit_drop * _hit_drop < 2e-05: return
	_body.rotation += _hit_rot * Vector3(1.0, 1.0, 1.0)
	_chest.rotation += _hit_rot * 0.45
	_head.rotation += _hit_head
	_body.position.y += minf(_hit_drop, 0.0) * 0.06 * _leg_reach
	var arm: float = _hit_arm
	_left_arm.rotation += Vector3(0.3 * arm, 0.0, -0.45 * arm)
	_right_arm.rotation += Vector3(0.3 * arm, 0.0, 0.45 * arm)
	_left_elbow.rotation.x += 0.5 * absf(arm)
	_right_elbow.rotation.x += 0.5 * absf(arm)
	_left_clav.rotation.z -= 0.12 * absf(arm)
	_right_clav.rotation.z += 0.12 * absf(arm)

	if absf(arm) > 0.15: _curl_override = lerpf(_curl_override if _curl_override >= 0.0 else 0.3, 0.0, clampf(absf(arm) * 1.5, 0.0, 1.0))

func _update_glance(dt: float, speed: float) -> void :
	_glance_back = maxf(0.0, _glance_back - dt)
	if not _st_chased or _life_state != "alive" or speed < 4.0 or _is_alice:
		_glance_timer = minf(_glance_timer, 0.8)
		return
	_glance_timer -= dt
	if _glance_timer <= 0.0:
		_glance_timer = _rng.randf_range(1.6, 3.4)
		_glance_back = 0.75
		_glance_side = 1.0 if _rng.randf() < 0.5 else -1.0


func _base_mood() -> String:
	if not mood_override.is_empty(): return mood_override
	match character_name:
		"Alice": return "focus"
		"Elly": return "calm"
		"Bleuette": return "calm"
		"TrueForm": return "angry"
	return "neutral"


func _cue(cue_name: String, strength: float = 1.0) -> void :
	last_cue = cue_name
	last_cue_time = _clock
	anim_cue.emit(cue_name, strength)





func _state_poses(mood: String) -> String:
	if _life_state != "alive": return mood
	if _st_blind: mood = _state_clip("blinded", mood)
	if _st_spike: mood = _state_clip("spike_aim", mood)
	if _st_block and not (_action_time > 0.0 and _action == "counter"): mood = _state_clip("block", mood)
	if _st_grab: mood = _state_clip("grab_hold" if _st_grab_hold else "tackle", mood)
	elif _st_grabbed: mood = _state_clip("held", mood)
	elif _st_knocked: mood = _state_clip("knocked", mood)
	if _st_heal: mood = _state_clip("heal_channel", mood)
	if _st_aim_flash: mood = _state_clip("flash_aim", mood)
	if _st_overheat_dash: mood = _state_clip("overheat_dash", mood)
	elif _st_overheat or _st_overheat_hold: mood = _state_clip("overheat_hold", mood)
	if _st_charge > 0.0: mood = _state_clip("charge", mood)
	elif _st_grinding: mood = _state_clip("grind", mood)
	elif _st_boost_time: mood = _state_clip("skate", mood, smoothstep(0.6, 3.0, _move_blend))
	if _st_carrying: mood = _state_clip("carry", mood)
	if _st_carried: mood = _state_clip("carried", mood)
	if _st_eating > 0.0: mood = _state_clip("eat", mood)
	if _st_outlet: mood = _state_clip("plugged", mood)
	if is_instance_valid(_plug_tail): _plug_tail.rotation.x = -0.4 if _st_outlet else 0.0
	if _st_view: mood = _state_clip("device", mood)
	return mood




func _state_clip(clip_name: String, mood: String, weight: float = 1.0) -> String:
	var clip: Dictionary = _get_clip(clip_name)
	if clip.is_empty(): return mood
	var elapsed: float = 0.0
	var previous: float = -1.0
	if _state_clocks.has(clip_name):
		var entry: Array = _state_clocks[clip_name]
		if int(entry[1]) == _tick_stamp - 1:
			previous = float(entry[0])
			elapsed = previous + _tick_dt
		entry[0] = elapsed
		entry[1] = _tick_stamp
	else:
		_state_clocks[clip_name] = [0.0, _tick_stamp]
	var clip_mood: String = _apply_clip(clip, elapsed, weight, previous)
	return clip_mood if not clip_mood.is_empty() and weight > 0.5 else mood



func _apply_injury_pose(delta: float, speed: float) -> void :
	var injured: bool = _st_injured
	_injury_blend = lerpf(_injury_blend, 1.0 if injured else 0.0, 1.0 - exp( - delta * 5.0))
	var show: bool = injured and _life_state != "dead"
	for mark in _injury_marks:
		if mark.visible != show: mark.visible = show
	if _injury_blend < 0.001 or _life_state != "alive": return
	var side: float = _injury_side
	var busy: bool = _action_time > 0.0 or _st_grab or _st_spike or _st_heal or _st_piloting or _st_block or _st_charge > 0.0 or _stun_blend > 0.2
	var w: float = _injury_blend * (1.0 - _air_blend) * (0.3 if busy else 1.0)
	var limp: float = maxf(0.0, sin(_gait + side * 1.4)) * clampf(speed / 2.0, 0.0, 1.0)
	_body.rotation.z += side * (0.04 + limp * 0.07) * w
	_body.position.y -= limp * 0.035 * _leg_reach * w
	_body.rotation.x -= 0.05 * w
	_head.rotation.x -= 0.06 * w
	if not busy: _apply_clip(_get_clip("injured"), _clock, w * (1.0 - 0.45 * _g_run * _g_move))


func _is_emote(id: String) -> bool:
	return id in EMOTES or id.begins_with("dance_")

# Changement d'émote ou saut de temps (synchronisation de groupe) : fondu depuis la pose actuelle.
func _check_emote_jump(dt: float) -> void :
	var id: String = _st_emote if _is_emote(_st_emote) else ""
	var jumped: bool = id != _emote_seen or absf(_st_emote_time - (_emote_seen_time + dt)) > 0.3
	# Nouveau départ : pas de repères sonores rejoués entre l'ancien temps et le nouveau.
	if jumped: _emote_clip_time = -1.0
	if jumped and not id.is_empty() and not _emote_seen.is_empty() and _transition_left <= 0.0 and _signature >= 0: _begin_transition()
	_emote_seen = id
	_emote_seen_time = _st_emote_time

func _emote_pose(id: String, time: float) -> String:
	var clip: Dictionary = _get_clip(id)
	if clip.is_empty(): return "neutral"
	var previous: float = _emote_clip_time if _emote_clip_time >= 0.0 and _emote_clip_time <= time else -1.0
	_emote_clip_time = time
	var mood: String = _apply_clip(clip, time, AnimClip.envelope(clip, time), previous)
	return mood if not mood.is_empty() else "neutral"



const CLIP_JOINTS: Array[String] = ["body", "chest", "head", "l_clav", "r_clav", "l_arm", "r_arm", "l_elb", "r_elb", "l_hand", "r_hand", "l_leg", "r_leg", "l_knee", "r_knee", "l_ank", "r_ank"]

func _clip_node(channel: String) -> Node3D:
	match channel:
		"body": return _body
		"chest": return _chest
		"head": return _head
		"l_clav": return _left_clav
		"r_clav": return _right_clav
		"l_arm": return _left_arm
		"r_arm": return _right_arm
		"l_elb": return _left_elbow
		"r_elb": return _right_elbow
		"l_hand": return _left_hand
		"r_hand": return _right_hand
		"l_leg": return _left_leg
		"r_leg": return _right_leg
		"l_knee": return _left_knee
		"r_knee": return _right_knee
		"l_ank": return _ankles[-1]
		"r_ank": return _ankles[1]
	return null

func _get_clip(clip_name: String) -> Dictionary:
	return AnimLibrary.clip(clip_name, character_name)





func _apply_clip(clip: Dictionary, time: float, w: float, previous: float = -1.0) -> String:
	if clip.is_empty() or w <= 0.001: return ""
	var length: float = clip.len


	var loop: bool = clip.loop and float(clip.loop_from) <= 0.0
	var t: float = AnimClip.wrap_time(clip, time)
	var channels: Dictionary = clip.channels
	var weight: float = clampf(w, 0.0, 1.0)



	var additive: bool = clip.add
	for channel: String in CLIP_JOINTS:
		if not channels.has(channel): continue
		var value: Vector3 = AnimClip.sample(channels[channel], t, loop, length)
		var node: Node3D = _clip_node(channel)
		if additive and (channel == "body" or channel == "chest" or channel == "head"):
			node.quaternion = node.quaternion * Quaternion.IDENTITY.slerp(Quaternion.from_euler(value), weight)
		else:
			node.quaternion = node.quaternion.slerp(Quaternion.from_euler(value), weight)
	if clip.legs and not channels.has("plant"): _plant_weight *= 1.0 - weight
	if channels.has("plant"): _plant_weight = lerpf(_plant_weight, float(AnimClip.sample(channels.plant, t, loop, length)), weight)



	var gait_keep: float = 1.0
	if channels.has("gait"):
		gait_keep = lerpf(1.0, clampf(float(AnimClip.sample(channels.gait, t, loop, length)), 0.0, 1.0), weight)
		if gait_keep < 0.999: _body.position = (Vector3(0.0, _base_height, 0.0) + _idle_hips).lerp(_body.position, gait_keep)
	if channels.has("hips"): _body.position += (AnimClip.sample(channels.hips, t, loop, length) as Vector3) * _leg_reach * weight
	if channels.has("hy"): _body.position.y = lerpf(_body.position.y, float(AnimClip.sample(channels.hy, t, loop, length)), weight)
	if channels.has("turn"): _clip_turn += float(AnimClip.sample(channels.turn, t, loop, length)) * weight
	if channels.has("sq"): _clip_squash = lerpf(_clip_squash, float(AnimClip.sample(channels.sq, t, loop, length)), weight)
	var step_weight: float = weight * (1.0 - 0.8 * _g_move * gait_keep)
	var both: Vector3 = Vector3.ZERO
	if channels.has("feet"): both = AnimClip.sample(channels.feet, t, loop, length)
	for side in [-1, 1]:
		if not _foot_target.has(side): continue
		if gait_keep < 0.999:
			_foot_target[side] = (_idle_feet.get(side, _foot_rest[side]) as Vector3).lerp(_foot_target[side], gait_keep)
			_foot_pitch[side] = float(_foot_pitch[side]) * gait_keep
			_feet_dirty = true
		var foot_channel: String = "foot_l" if side < 0 else "foot_r"
		if channels.has(foot_channel) or channels.has("feet"):
			var offset: Vector3 = both * weight
			if channels.has(foot_channel): offset += (AnimClip.sample(channels[foot_channel], t, loop, length) as Vector3) * step_weight
			_foot_target[side] = (_foot_target[side] as Vector3) + offset * _leg_reach
			_feet_dirty = true
		var pitch_channel: String = "fp_l" if side < 0 else "fp_r"
		if channels.has(pitch_channel):
			_foot_pitch[side] = lerpf(float(_foot_pitch[side]), float(AnimClip.sample(channels[pitch_channel], t, loop, length)), weight)
			_feet_dirty = true


	if channels.has("gsnap"):
		var snap: float = float(AnimClip.sample(channels.gsnap, t, loop, length))
		if snap > 0.001: _ground_clamp(weight * clampf(snap, 0.0, 1.0), true)
	if channels.has("gclamp"):
		var clamp_weight: float = float(AnimClip.sample(channels.gclamp, t, loop, length))
		if clamp_weight > 0.001: _ground_clamp(weight * clampf(clamp_weight, 0.0, 1.0), false)



	for side in [-1, 1]:
		var ik_channel: String = "ik_l" if side < 0 else "ik_r"
		if not channels.has(ik_channel): continue
		var ik_weight: float = weight
		var weight_channel: String = "ikw_l" if side < 0 else "ikw_r"
		if channels.has(weight_channel): ik_weight *= clampf(float(AnimClip.sample(channels[weight_channel], t, loop, length)), 0.0, 1.0)
		if ik_weight <= 0.001: continue
		var offset: Vector3 = AnimClip.sample(channels[ik_channel], t, loop, length)
		var flare_channel: String = "el_l" if side < 0 else "el_r"
		_clip_flare[side] = float(AnimClip.sample(channels[flare_channel], t, loop, length)) if channels.has(flare_channel) else 0.0
		var frame_channel: String = "tf_l" if side < 0 else "tf_r"
		var torso: float = clampf(float(AnimClip.sample(channels[frame_channel], t, loop, length)), 0.0, 1.0) if channels.has(frame_channel) else 0.0
		var ground_channel: String = "gr_l" if side < 0 else "gr_r"
		var ground: float = clampf(float(AnimClip.sample(channels[ground_channel], t, loop, length)), 0.0, 1.0) if channels.has(ground_channel) else 0.0
		var wrist_channel: String = "l_hand" if side < 0 else "r_hand"
		var wrist: Quaternion = Quaternion.from_euler(AnimClip.sample(channels[wrist_channel], t, loop, length)) if channels.has(wrist_channel) else Quaternion.IDENTITY
		_hand_target_weighted(side, _reach_target(side, offset, torso, ground), ik_weight, wrist, torso)
		_clip_flare[side] = 0.0
	if channels.has("curl"): _curl_override = lerpf(_curl_override if _curl_override >= 0.0 else float(_style.idle_curl), float(AnimClip.sample(channels.curl, t, loop, length)), weight)
	if channels.has("curl_l"): _curl_left_override = lerpf(_curl_left_override if _curl_left_override >= 0.0 else (_curl_override if _curl_override >= 0.0 else float(_style.idle_curl)), float(AnimClip.sample(channels.curl_l, t, loop, length)), weight)
	if channels.has("shake"): _clip_shake = maxf(_clip_shake, float(AnimClip.sample(channels.shake, t, loop, length)) * weight)
	if channels.has("jaw"): _clip_jaw = maxf(_clip_jaw, float(AnimClip.sample(channels.jaw, t, loop, length)) * weight)
	if channels.has("chatter"): _clip_chatter = maxf(_clip_chatter, float(AnimClip.sample(channels.chatter, t, loop, length)) * weight)
	if float(clip.lid) > 0.0: _clip_lid = maxf(_clip_lid, float(clip.lid) * weight)
	var strings: Dictionary = clip.strings
	if strings.has("prop"):
		var prop_name: String = AnimClip.sample_string(strings.prop, t)
		if not prop_name.is_empty() and weight > 0.3: _show_prop(prop_name)
	if strings.has("gesture") and is_instance_valid(_imported):
		var gesture: String = AnimClip.sample_string(strings.gesture, t)
		if not gesture.is_empty(): _imported.set_hand_gesture(gesture, weight)
	if previous >= 0.0 and (time > previous or (clip.loop and time < previous)) and (strings.has("ev") or strings.has("fx")):
		var from: float = AnimClip.wrap_time(clip, previous)
		if strings.has("ev"):
			for entry: Array in strings.ev:
				if _cue_between(float(entry[0]), from, t): _clip_event(str(entry[1]))
		if strings.has("fx") and weight > 0.25:
			for entry: Array in strings.fx:
				if _cue_between(float(entry[0]), from, t):
					for cue: String in str(entry[1]).split(" ", false): anim_fx.emit(cue)
	var mood: String = str(clip.face)
	if strings.has("face"):
		var keyed: String = AnimClip.sample_string(strings.face, t)
		if not keyed.is_empty(): mood = keyed
	return mood if weight > 0.35 else ""


static func _cue_between(at: float, from: float, to: float) -> bool:
	if to >= from: return (at > from or (from <= 0.0 and at <= 0.0)) and at <= to
	return at > from or at <= to








func _reach_target(side: int, offset: Vector3, torso: float = 0.0, ground: float = 0.0) -> Vector3:
	var clav: Node3D = _right_clav if side > 0 else _left_clav
	var arm: Node3D = _right_arm if side > 0 else _left_arm
	var chest_q: Quaternion = _spine.quaternion * _chest.quaternion
	var shoulder: Vector3 = _spine.transform * (_chest.transform * (clav.transform * arm.position))
	var reach: Vector3 = offset * float(_arm_length[side])
	var outside: Vector3 = _body.quaternion.inverse() * reach
	var target: Vector3 = shoulder + (outside if torso <= 0.001 else outside.lerp(chest_q * reach, torso))
	if ground <= 0.001: return target
	var floor_point: Vector3 = _body.transform * shoulder + Vector3(reach.x, 0.0, reach.z)
	floor_point.y = 0.05 + reach.y
	return target.lerp(_body.transform.affine_inverse() * floor_point, ground)

func _clip_event(event_name: String) -> void :
	match event_name:
		"grunt", "effort", "roar":
			_face_ctrl.grunt(0.75 if event_name == "roar" else 0.5, 0.35 if event_name == "roar" else 0.14)
		"death":
			_face_ctrl.hurt(1.2)
		"hurt":
			_face_ctrl.hurt(0.8)
		"gasp":
			_face_ctrl.gasp()
	_cue(event_name, 1.0)

func _hand_target_weighted(side: int, target: Vector3, weight: float, wrist: Quaternion = Quaternion.IDENTITY, torso: float = 1.0) -> void :
	var arm: Node3D = _right_arm if side > 0 else _left_arm
	var elbow: Node3D = _right_elbow if side > 0 else _left_elbow
	var hand: Node3D = _right_hand if side > 0 else _left_hand
	if weight >= 0.999:
		_hand_target(side, target, wrist, torso)
		return
	var arm_q: Quaternion = arm.quaternion
	var elbow_q: Quaternion = elbow.quaternion
	var hand_q: Quaternion = hand.quaternion
	_hand_target(side, target, wrist, torso)
	arm.quaternion = arm_q.slerp(arm.quaternion, weight)
	elbow.quaternion = elbow_q.slerp(elbow.quaternion, weight)
	hand.quaternion = hand_q.slerp(hand.quaternion, weight)


func _life_action() -> bool:
	return _action.begins_with("death_") or _action == "recover" or _action == "revive"


func _play_action(t: float, mood: String) -> String:
	var clip: Dictionary = _get_clip(_action)
	if clip.is_empty(): return mood
	var time: float = t * float(clip.len)
	var previous: float = _action_clip_time
	_action_clip_time = time
	var clip_mood: String = _apply_clip(clip, time, AnimClip.envelope(clip, time), previous)
	return clip_mood if not clip_mood.is_empty() else mood


func _apply_shake() -> void :
	if _clip_shake <= 0.001: return
	var t: float = _clock
	var s: float = _clip_shake
	_chest.rotation += Vector3(sin(t * 47.0) * 0.012, sin(t * 39.0) * 0.01, sin(t * 43.0) * 0.012) * s
	_head.rotation += Vector3(sin(t * 53.0 + 1.0) * 0.015, sin(t * 41.0 + 2.0) * 0.012, 0.0) * s
	_left_clav.rotation.z += sin(t * 37.0) * 0.02 * s
	_right_clav.rotation.z -= sin(t * 37.0 + 0.7) * 0.02 * s








func _hand_target(side: int, target: Vector3, wrist: Quaternion = Quaternion.IDENTITY, torso: float = 1.0) -> void :
	var arm: Node3D = _right_arm if side > 0 else _left_arm
	var elbow: Node3D = _right_elbow if side > 0 else _left_elbow
	var hand: Node3D = _right_hand if side > 0 else _left_hand
	var clav: Node3D = _right_clav if side > 0 else _left_clav
	var chest_frame: Transform3D = _spine.transform * _chest.transform * clav.transform
	var local_target: Vector3 = chest_frame.affine_inverse() * target
	var delta: Vector3 = local_target - arm.position
	var upper_length: float = elbow.position.length()
	var lower_length: float = hand.position.length()
	var upper_rest: Vector3 = elbow.position.normalized()
	var lower_rest: Vector3 = hand.position.normalized()
	var distance: float = clampf(delta.length(), 0.05, (upper_length + lower_length) * 0.995)
	var direction: Vector3 = delta.normalized()
	var along: float = (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2 * distance)
	var height: float = sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var flare: float = float(_clip_flare[side])
	var pole_body: Vector3 = Vector3(side * (0.65 + 0.6 * flare), -1.0 + 1.7 * flare, 0.16 - 0.3 * flare)
	if torso < 0.999: pole_body = (_body.quaternion.inverse() * pole_body).lerp(pole_body, clampf(torso, 0.0, 1.0))
	var pole: Vector3 = chest_frame.basis.inverse() * pole_body
	var bend: Vector3 = pole - direction * pole.dot(direction)
	bend = bend.normalized() if bend.length_squared() > 1e-06 else Vector3(side, 0.0, 0.0)
	var upper: Vector3 = direction * along + bend * height
	var lower: Vector3 = direction * distance - upper

	if upper.length_squared() < 1e-06 or lower.length_squared() < 1e-06 or not upper.is_finite(): return
	arm.quaternion = Quaternion(upper_rest, upper.normalized())
	elbow.quaternion = arm.quaternion.inverse() * Quaternion(lower_rest, lower.normalized())
	hand.quaternion = wrist
	if side > 0: _ik_hand_right = true
	else: _ik_hand_left = true

func _phase_pose(dt: float, velocity: Vector3, stunned: bool) -> void :
	if is_instance_valid(_true_form):
		_true_form.set_combat_state(_combat_state)
		_true_form.animate(dt, velocity, stunned, false)


func _update_plug_tail() -> void :
	if not is_instance_valid(_plug_tail): return
	var charging: bool = float(_combat_state.get("outlet_healing", _combat_state.get("outlet_time", 0))) > 0
	var endpoint: Variant = _combat_state.get("outlet_position", null)
	if charging and endpoint is Vector3:
		var start: Vector3 = _plug_tail.global_position
		var finish: Vector3 = endpoint
		for i in range(_plug_segments.size()):
			var t: float = float(i) / 5.0; var next_t: float = float(i + 1) / 5.0
			var point: Vector3 = start.lerp(finish, t) + Vector3.DOWN * sin(t * PI) * 0.14
			var next_point: Vector3 = start.lerp(finish, next_t) + Vector3.DOWN * sin(next_t * PI) * 0.14
			var segment: Node3D = _plug_segments[i]
			segment.global_transform = Transform3D(Basis.looking_at(next_point - point, Vector3.UP, true), point)
			segment.scale.z *= point.distance_to(next_point) / (0.25 if i == _plug_segments.size() - 1 else 0.13)
	else:
		for i in range(_plug_segments.size()):
			_plug_segments[i].position = Vector3(0, 0, 0.12) if i > 0 else Vector3.ZERO
			_plug_segments[i].scale = Vector3.ONE

func _step_node_springs(delta: float) -> void :
	if _secondary.is_empty(): return
	var step: float = minf(delta, 0.035)
	for item in _secondary:
		var p: Node3D = item.node
		var weight: float = item.weight
		var target: = Vector3(clampf( - _local_velocity.z * 0.025 + _accel_smooth.z * 0.0009, -0.23, 0.23), clampf( - _yaw_rate * 0.04, -0.24, 0.24), clampf(_local_velocity.x * 0.023, -0.2, 0.2)) * weight
		target += Vector3(sin(_clock * 2.7 + item.phase) * 0.022, sin(_clock * 1.9 + item.phase) * 0.027, cos(_clock * 2.1 + item.phase) * 0.016) * weight
		var offset: Vector3 = item.offset; var spring_speed: Vector3 = item.speed
		spring_speed += (target - offset) * 55.0 * step - spring_speed * 9.0 * step
		offset += spring_speed * step
		p.rotation = item.rest + offset
		item.offset = offset;item.speed = spring_speed



func _apply_life_pose(mood: String = "neutral") -> String:
	var p: float = 1.0 - _action_time / maxf(_action_duration, 0.001)
	var acting: bool = _action_time > 0.0
	if _action.begins_with("death_") and _life_state != "dead" and (acting or _death_hold > 0.0):



		var clip: Dictionary = _get_clip(_action)
		if not acting: _death_hold -= _tick_dt
		var time: float = (p if acting else 1.0) * float(clip.len)
		var previous: float = _action_clip_time
		_action_clip_time = time
		var clip_mood: String = _apply_clip(clip, time, 1.0, previous)
		return clip_mood if not clip_mood.is_empty() else "pain"
	if acting and _action == "recover":
		var clip: Dictionary = _get_clip("recover")
		var time: float = p * float(clip.len)
		var previous: float = _action_clip_time
		_action_clip_time = time
		_apply_clip(clip, time, AnimClip.envelope(clip, time), previous)
		return "hurt"
	if _life_state == "dead":

		var settle: float = 1.0 if _action.begins_with("death_") else smoothstep(0.0, 0.5, _life_clock)
		_apply_clip(_get_clip(_dead_clip), _life_clock, settle)
		return "dead"
	if _life_state == "downed":

		var amount: float = smoothstep(0.0, 0.45, _life_clock)
		var moving: float = clampf(_move_blend / 0.5, 0.0, 1.0)
		var still: Dictionary = _get_clip("downed")
		var crawl: Dictionary = _get_clip("crawl")
		if moving < 0.999: _apply_clip(still, _life_clock, amount)
		if moving > 0.001: _apply_clip(crawl, _crawl_cycle / TAU * float(crawl.get("len", 1.0)), amount * moving)
		return "hurt"
	if acting and _action == "revive":
		var clip: Dictionary = _get_clip("revive")
		var elapsed: float = p * _action_duration
		var previous: float = _action_clip_time
		_action_clip_time = elapsed
		var clip_mood: String = _apply_clip(clip, elapsed, smoothstep(0.0, 0.2, elapsed) * (1.0 - smoothstep(0.92, 1.0, p)), previous)
		return clip_mood if not clip_mood.is_empty() else mood
	return mood





func _ground_clamp(weight: float, snap: bool) -> void :
	if weight <= 0.001 or not is_inside_tree(): return
	var inverse: Transform3D = global_transform.affine_inverse()
	var lowest: float = INF
	var head: Vector3 = inverse * (_head.global_transform * Vector3(0.0, 0.2, 0.0))
	lowest = minf(lowest, head.y - 0.22)
	for item: Array in [[_body, 0.16], [_chest, 0.17], [_left_arm, 0.1], [_right_arm, 0.1], [_left_elbow, 0.06], [_right_elbow, 0.06], [_left_hand, 0.045], [_right_hand, 0.045], [_left_knee, 0.07], [_right_knee, 0.07], [_ankles[-1], 0.06], [_ankles[1], 0.06], [_toes[-1], 0.03], [_toes[1], 0.03]]:
		var node: Node3D = item[0]
		var point: Vector3 = inverse * node.global_position
		lowest = minf(lowest, point.y - float(item[1]))
	if lowest == INF: return
	var shift: float = - lowest if snap else maxf(0.0, - lowest)
	if absf(shift) > 0.0005: _body.position.y += shift * weight



func _limit_anatomical_joints() -> void :
	if not _ik_legs:
		_left_knee.rotation.x = clampf(_left_knee.rotation.x, -2.05, 0.035)
		_right_knee.rotation.x = clampf(_right_knee.rotation.x, -2.05, 0.035)
	if not _ik_hand_left:
		_left_elbow.rotation.x = clampf(_left_elbow.rotation.x, - 0.025, 2.4)
		_left_hand.rotation.x = clampf(_left_hand.rotation.x, -1.4, 1.4)
		_left_hand.rotation.z = clampf(_left_hand.rotation.z, - 0.55, 0.55)
	if not _ik_hand_right:
		_right_elbow.rotation.x = clampf(_right_elbow.rotation.x, - 0.025, 2.4)
		_right_hand.rotation.x = clampf(_right_hand.rotation.x, -1.4, 1.4)
		_right_hand.rotation.z = clampf(_right_hand.rotation.z, - 0.55, 0.55)





const RESULT_GOOD: Dictionary = {"Bleuette": "cheer", "Simon": "thumbsup", "Usayuko": "laugh", "Ashura": "thumbsup", "Lysia": "cheer", "Elly": "wave", "Alice": "gloat"}
const RESULT_MIDDLE: Dictionary = {"Bleuette": "wave", "Simon": "point", "Usayuko": "thumbsup", "Ashura": "point", "Lysia": "wave", "Elly": "shrug", "Alice": "reveal"}
const RESULT_POOR: Dictionary = {"Bleuette": "fear", "Simon": "sad", "Usayuko": "shrug", "Ashura": "sad", "Lysia": "sad", "Elly": "sad", "Alice": "fury"}
const RESULT_CYCLE: float = 4.2
var _result_time: float = -1.0
var _result_round: int = -1

func set_result_reaction(grade: String, elapsed: float) -> void :
	if not is_instance_valid(_body): return
	var delta: float = clampf(elapsed - _result_time, 0.0, 0.1) if _result_time >= 0.0 and elapsed >= _result_time else 1.0 / 60.0
	if elapsed < _result_time: _result_round = -1
	_result_time = elapsed
	var good: bool = grade in ["S", "A"]
	var poor: bool = grade in ["D", "E", "F"]
	var id: String = str(RESULT_GOOD.get(character_name, "cheer")) if good else (str(RESULT_POOR.get(character_name, "sad")) if poor else str(RESULT_MIDDLE.get(character_name, "wave")))
	mood_override = "hurt" if grade == "F" else ("grin" if good else ("sad" if poor else "calm"))

	var state: Dictionary = {}
	if elapsed > 0.25:
		var turn: int = int((elapsed - 0.25) / RESULT_CYCLE)
		var local_time: float = elapsed - 0.25 - float(turn) * RESULT_CYCLE
		if id in EMOTES:
			if local_time < 2.5: state = {"emote_id": id, "emote_time": local_time}
		elif turn != _result_round:
			play(id)
		_result_round = turn
	set_combat_state(state)
	animate(delta, Vector3.ZERO, false, false)
