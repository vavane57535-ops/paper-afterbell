class_name PaperActor
extends CharacterBody3D

signal movement_event(kind: String, payload: Dictionary)


const JUMP_BUFFER_TIME: float = 0.15

const COYOTE_TIME: float = 0.12

const TELEPORT_DISTANCE: float = 3.0

const REMOTE_SNAP_DISTANCE: float = 4.0
const NET_RULE_VALUE: int = 0
const NET_RULE_ID: int = 1




const NET_EFFECT_RULES: Dictionary = {
	"boost_charging": NET_RULE_VALUE, "boost_charge": NET_RULE_VALUE, "charging_boost": NET_RULE_VALUE, 
	"speed_boost": NET_RULE_VALUE, "carrying_id": NET_RULE_ID, "carried_by": NET_RULE_ID, "drone_precise": NET_RULE_VALUE, 
	"grenade_aiming": NET_RULE_VALUE, "overheat_hold": NET_RULE_VALUE, "overheat_charge": NET_RULE_VALUE, "chocolate_eating": NET_RULE_VALUE, 
	"chocolate_uses": NET_RULE_VALUE, "chocolate_hot": NET_RULE_VALUE, "outlet_healing": NET_RULE_VALUE, "outlet_index": NET_RULE_ID, 
	"stun_immunity": NET_RULE_VALUE, "stun_count": NET_RULE_VALUE, "true_form_used": NET_RULE_VALUE, "grinding": NET_RULE_VALUE, 
	"running": NET_RULE_VALUE, "airborne": NET_RULE_VALUE, "air_time": NET_RULE_VALUE, "air_peak_delta": NET_RULE_VALUE, 
	"land_roll_time": NET_RULE_VALUE, "landing_boost_time": NET_RULE_VALUE, "revive_invuln": NET_RULE_VALUE, "flash_melee": NET_RULE_VALUE, 
	"aura_charge": NET_RULE_VALUE, "lms_buff_unlocked": NET_RULE_VALUE, "emote_id": NET_RULE_VALUE, "score_points": NET_RULE_VALUE, 
	"emote_time": NET_RULE_VALUE, "jump_cd": NET_RULE_VALUE, "drone_piloting": NET_RULE_VALUE, "downed": NET_RULE_VALUE, 
	"dying": NET_RULE_VALUE, "revived": NET_RULE_VALUE, "death_time": NET_RULE_VALUE, "death_kind": NET_RULE_VALUE, 
	"death_source": NET_RULE_ID, "recover": NET_RULE_VALUE, "revive_progress": NET_RULE_VALUE, "revive_target": NET_RULE_ID, 
	"revive_helper": NET_RULE_ID, "archive_lock": NET_RULE_VALUE, "archive_alarm": NET_RULE_VALUE, "chased": NET_RULE_VALUE, 
	"lms_reveal": NET_RULE_VALUE, "stun": NET_RULE_VALUE, "root": NET_RULE_VALUE, "slow_time": NET_RULE_VALUE, 
	"boost_time": NET_RULE_VALUE, "phase6": NET_RULE_VALUE, "rage": NET_RULE_VALUE, "shadow_hide": NET_RULE_VALUE, 
	"shadow_time": NET_RULE_VALUE, "shadow_mark": NET_RULE_VALUE, "spike_aiming": NET_RULE_VALUE, "grenade_windup": NET_RULE_VALUE, 
	"forced_time": NET_RULE_VALUE, "grab_time": NET_RULE_VALUE, "grabbed_by": NET_RULE_ID, "overheat_time": NET_RULE_VALUE, 
	"reveal": NET_RULE_VALUE, "xray": NET_RULE_VALUE, "blind": NET_RULE_VALUE, "adrenaline": NET_RULE_VALUE, 
	"help_aura": NET_RULE_VALUE, "block": NET_RULE_VALUE, "counter": NET_RULE_VALUE, "drone_active": NET_RULE_VALUE, 
	"drone_battery": NET_RULE_VALUE, "drone_bonus": NET_RULE_VALUE, "next_stun": NET_RULE_VALUE, "next_heal": NET_RULE_VALUE, 
	"cooldown_discount": NET_RULE_VALUE, "heal_time": NET_RULE_VALUE, "heal_target": NET_RULE_ID, "overheat_target": NET_RULE_ID, 
	"training_dummy": NET_RULE_VALUE, "dropkick_used": NET_RULE_VALUE, "shotgun_used": NET_RULE_VALUE, "aura_used": NET_RULE_VALUE, 
	"kill_lock": NET_RULE_VALUE, 
	"outlet_ashura": NET_RULE_ID, "sprint_bonus": NET_RULE_VALUE, "lms_hp_cap": NET_RULE_VALUE, 
	"cam_facing": NET_RULE_VALUE, 
}


const NET_QTE_KEYS: Array[String] = ["archive_qte_id", "archive_qte_key", "archive_qte_remaining", "archive_qte_duration", "archive_index"]

var _air_peak: float = 0.0
var _air_time: float = 0.0
var _takeoff_y: float = 0.0
var _jump_buffer: float = 0.0
var _coyote: float = 0.0
var _last_tick_position: Vector3 = Vector3.ZERO

var ruleset: String = "om"
var id: int = 0
var character: String = "Ashura"
var killer: bool = false
var bot: bool = false
var alive: bool = true
var lms: bool = false
var hp: float = 90.0
var max_hp: float = 90.0
var stamina: float = 90.0
var max_stamina: float = 90.0
var cooldowns: Dictionary = {}
var effects: Dictionary = {}
var move_input: Vector3 = Vector3.ZERO
var aim: Vector3 = Vector3.FORWARD
var sprint: bool = false
var visual: PaperVisual
var display_name: String = ""
var bot_state: Dictionary = {}
var regen_wait: float = 0.0
var net_position: Vector3
var net_velocity: Vector3
var foot_clock: float = 0.0
var collider: CollisionShape3D

func setup(actor_id: int, character_name: String, is_bot: bool) -> void :
	id = actor_id
	character = character_name
	bot = is_bot
	killer = character == "Alice"
	display_name = character
	var stats: Array = PaperData.STATS[character]
	max_hp = float(stats[0]);hp = max_hp
	max_stamina = float(stats[1]);stamina = max_stamina
	name = "Actor_" + str(id)

	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	collision_layer = 4
	collision_mask = 1 if killer else 3
	floor_snap_length = 0.4
	collider = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.38;shape.height = 1.8
	collider.shape = shape;collider.position.y = 0.91
	add_child(collider)
	visual = PaperVisual.new()
	add_child(visual);visual.setup(character)
	for i in range(6): cooldowns[i] = 0.0
	if killer: effects["rage"] = 0.0
	net_position = position

func configure_ruleset(value: String) -> void :
	ruleset = PaperRules.normalize(value)
	if ruleset == "om":
		max_stamina = -1.0;stamina = -1.0
		floor_snap_length = 0.55
		floor_max_angle = deg_to_rad(48.0)
	else:
		max_stamina = float(PaperData.STATS[character][1]);stamina = max_stamina
		floor_snap_length = 0.4
		floor_max_angle = deg_to_rad(45.0)
	effects["jump_cd"] = 0.0
	effects["jump_pending"] = false
	_air_peak = position.y;_air_time = 0.0




func request_jump(assisted: bool = false) -> bool:
	if _try_jump(assisted):
		return true
	if assisted and ruleset == "om" and active():
		_jump_buffer = JUMP_BUFFER_TIME
	return false

func _try_jump(assisted: bool) -> bool:
	if ruleset != "om" or not active() or float(effects.get("jump_cd", 0.0)) > 0: return false
	var coyote: bool = assisted and _coyote > 0.0 and velocity.y <= 0.5
	if not is_on_floor() and not bool(effects.get("grinding", false)) and not coyote: return false
	for key in ["stun", "root", "recover", "forced_time", "grab_time", "overheat_time", "heal_time"]:
		if float(effects.get(key, 0.0)) > 0: return false
	if bool(effects.get("drone_piloting", false)) or bool(effects.get("boost_charging", false)) or float(effects.get("outlet_healing", 0)) > 0 or int(effects.get("carried_by", -1)) >= 0 or bool(effects.get("shadow_hide", false)) or int(effects.get("grabbed_by", -1)) >= 0: return false
	effects["jump_cd"] = PaperRules.OM_JUMP_COOLDOWN
	effects["jump_pending"] = true
	_jump_buffer = 0.0
	_coyote = 0.0
	if bool(effects.get("grinding", false)): effects["grind_jump"] = 0.5;effects["grinding"] = false
	return true

func tick(delta: float, authoritative: bool) -> void :
	if not alive:

		visual.animate(delta, Vector3.ZERO, false, false)
		_track_teleport()
		return
	if authoritative:
		var om: bool = ruleset == "om"
		var crawling: bool = om and bool(effects.get("downed", false)) and not bool(effects.get("dying", false))
		if om:
			max_stamina = -1.0;stamina = -1.0
			effects["jump_cd"] = maxf(0.0, float(effects.get("jump_cd", 0.0)) - delta)
			for timer in ["land_roll_time", "landing_boost_time", "roll_dash_time", "grind_jump"]:
				effects[timer] = maxf(0.0, float(effects.get(timer, 0)) - delta)
			var capsule: CapsuleShape3D = collider.shape
			capsule.height = 0.76 if crawling else float(PaperData.HEIGHTS.get(character, 1.75))
			collider.position.y = 0.39 if crawling else capsule.height * 0.5 + 0.01
		var scripted_motion: bool = bool(effects.get("motion_owned", false)) or float(effects.get("forced_time", 0.0)) > 0 or float(effects.get("grab_time", 0.0)) > 0 or float(effects.get("overheat_time", 0.0)) > 0 or int(effects.get("grabbed_by", -1)) >= 0 or bool(effects.get("shadow_hide", false))
		effects["motion_owned"] = false
		var held: bool = scripted_motion or bool(effects.get("boost_charging", false)) or float(effects.get("outlet_healing", 0)) > 0 or int(effects.get("carried_by", -1)) >= 0 or ( not active() and not crawling) or bool(effects.get("drone_piloting", false)) or float(effects.get("stun", 0.0)) > 0 or float(effects.get("root", 0.0)) > 0 or float(effects.get("recover", 0.0)) > 0
		if om and (held or not active()): effects["jump_pending"] = false
		if om and _jump_buffer > 0.0:
			_jump_buffer = maxf(0.0, _jump_buffer - delta)
			if not held:
				_try_jump(true)
		var direction: Vector3 = move_input.limit_length(1.0) if not held else Vector3.ZERO
		if not held and float(effects.get("roll_dash_time", 0)) > 0: direction = effects.get("roll_direction", aim)
		var running: bool = sprint and direction.length() > 0.01 and (max_stamina < 0 or stamina > 0.5)
		var speed: float = (8.1 if killer else 7.2) if running else (5.0 if killer else 4.5)
		if om:
			speed = (PaperRules.OM_KILLER_SPRINT if killer else PaperRules.OM_SURVIVOR_SPRINT) if running else (7.0 if killer else 6.3)
		if float(effects.get("slow_time", 0.0)) > 0: speed *= float(effects.get("slow_factor", 0.85))
		if float(effects.get("boost_time", 0.0)) > 0: speed *= float(effects.get("boost_factor", 2.0))
		elif float(effects.get("adrenaline", 0.0)) > 0: speed *= 2.0 if character == "Bleuette" else 1.3
		if om and float(effects.get("landing_boost_time", 0)) > 0 and float(effects.get("boost_factor", 1)) < 1.25: speed *= 1.25
		if float(effects.get("speed_boost", 0)) > 0: speed = PaperRules.OM_SURVIVOR_SPRINT * PaperRules.OM_BOOST_FACTOR * float(effects.get("carry_speed_factor", 1.0))
		if float(effects.get("phase6", 0.0)) > 0: speed *= PaperRules.TRUE_FORM_SPEED_FACTOR
		if not held and float(effects.get("roll_dash_time", 0)) > 0: speed = maxf(speed, 13.0)
		if crawling:
			speed = PaperRules.OM_CRAWL_SPEED
			running = false
		if running:
			regen_wait = 1.2
			if max_stamina >= 0: stamina = maxf(0.0, stamina - 18.0 * delta)
		else:
			regen_wait = maxf(0.0, regen_wait - delta)
			if regen_wait <= 0 and max_stamina >= 0:
				stamina = minf(max_stamina, stamina + delta * (16.5 if killer else 15.0))
		if not scripted_motion:
			var was_grounded: bool = is_on_floor()
			if was_grounded: _air_peak = position.y;_takeoff_y = position.y
			var acceleration: float = (2000.0 if was_grounded else 90.0) if om else 55.0
			if held or crawling: acceleration = 82.0 if om else 55.0
			velocity.x = move_toward(velocity.x, direction.x * speed, delta * acceleration)
			velocity.z = move_toward(velocity.z, direction.z * speed, delta * acceleration)
			if om and bool(effects.get("jump_pending", false)) and not held:
				velocity.y = PaperRules.OM_JUMP_VELOCITY
				effects["jump_pending"] = false
				_air_peak = position.y;_air_time = 0.0
				movement_event.emit("jump", {"actor": id, "position": position, "velocity": velocity})
			elif not is_on_floor(): velocity.y -= (PaperRules.OM_GRAVITY if om else 20.0) * delta
			else: velocity.y = -0.2
			var impact_speed: float = velocity.y
			move_and_slide()
			if om:
				if is_on_floor():
					_coyote = COYOTE_TIME
				else:
					_coyote = maxf(0.0, _coyote - delta)
				if not is_on_floor():
					if was_grounded: _air_peak = maxf(_air_peak, position.y)
					_air_peak = maxf(_air_peak, position.y);_air_time += delta
				elif not was_grounded:
					var drop: float = _takeoff_y - position.y
					if not killer and active() and not held and drop >= 0.65 and impact_speed <= -4.0:
						effects["land_roll_time"] = 0.55;effects["landing_boost_time"] = 0.8
						var roll_direction: Vector3 = direction if direction.length_squared() > 0.1 else Vector3(aim.x, 0, aim.z).normalized()
						effects["roll_direction"] = roll_direction;effects["roll_dash_time"] = 0.16
						velocity.x = roll_direction.x * 13.0;velocity.z = roll_direction.z * 13.0
						movement_event.emit("land_roll", {"actor": id, "position": position, "duration": 0.65, "boost_duration": 1.0, "height": drop})
					_air_peak = position.y;_air_time = 0.0
				effects["airborne"] = not is_on_floor();effects["air_time"] = _air_time;effects["air_peak_delta"] = maxf(0, _air_peak - position.y)
		effects["running"] = running and not held and not crawling
	else:

		if global_position.distance_squared_to(net_position) > REMOTE_SNAP_DISTANCE * REMOTE_SNAP_DISTANCE:
			global_position = net_position
		else:
			global_position = global_position.lerp(net_position, minf(1.0, delta * 18.0))
		velocity = net_velocity

	visual.visible = not bool(effects.get("shadow_hide", false)) or float(effects.get("shadow_time", 0.0)) > 0.85
	var action_facing: bool = visual.is_performing_action()
	var facing: Vector3 = aim if killer or action_facing or velocity.length() < 0.4 else Vector3(velocity.x, 0, velocity.z).normalized()
	facing = _camera_facing(facing, action_facing)

	var driven: bool = int(effects.get("grabbed_by", -1)) >= 0 or (float(effects.get("forced_time", 0.0)) > 0.0 and str(effects.get("force_name", "")) == "knock")
	if driven and Vector2(velocity.x, velocity.z).length() > 0.4:
		facing = - Vector3(velocity.x, 0, velocity.z).normalized()
		action_facing = false
	if facing.length() > 0.01:
		var desired_yaw: float = atan2( - facing.x, - facing.z)



		visual.rotation.y = desired_yaw if action_facing else lerp_angle(visual.rotation.y, desired_yaw, minf(1.0, delta * 14.0))
	visual.animate(delta, velocity, float(effects.get("stun", 0)) > 0, float(effects.get("phase6", 0)) > 0)
	_track_teleport()



# Orientation choisie par le mode de caméra du joueur (effet « cam_facing », synchronisé) :
# 1 = Derrière : le perso regarde où regarde la caméra ; 2 = Libre 360° : il regarde où il va et garde
# son orientation à l'arrêt (on peut tourner autour et voir son visage). 0 = bots / ancien comportement.
func _camera_facing(facing: Vector3, action_facing: bool) -> Vector3:
	var view_mode: int = int(effects.get("cam_facing", 0))
	if view_mode == 0 or bot or action_facing or bool(effects.get("downed", false)): return facing
	# Exécution : la mise en scène tourne Alice et sa victime l'une vers l'autre pendant l'approche
	# (sinon, en Libre 360°, elles gardaient leur orientation puis pivotaient d'un coup au début du clip).
	if float(effects.get("kill_lock", 0.0)) > 0.0 or str(effects.get("death_kind", "")) == "execution": return facing
	var aiming: bool = bool(effects.get("grenade_aiming", false)) or bool(effects.get("spike_aiming", false)) or bool(effects.get("boost_charging", false)) or bool(effects.get("drone_piloting", false))
	var flat: Vector3 = Vector3(velocity.x, 0, velocity.z)
	if view_mode == 1:
		var emoting: bool = not str(effects.get("emote_id", "")).is_empty()
		var rolling: bool = float(effects.get("land_roll_time", 0.0)) > 0.0 or float(effects.get("roll_dash_time", 0.0)) > 0.0 or bool(effects.get("grinding", false))
		if rolling and flat.length() > 0.4: return flat.normalized()
		return Vector3.ZERO if emoting and not aiming else Vector3(aim.x, 0, aim.z)
	if aiming: return Vector3(aim.x, 0, aim.z)
	return flat.normalized() if flat.length() > 0.4 else Vector3.ZERO

func _track_teleport() -> void :
	if global_position.distance_squared_to(_last_tick_position) > TELEPORT_DISTANCE * TELEPORT_DISTANCE:
		reset_physics_interpolation()
	_last_tick_position = global_position

func active() -> bool:
	return alive and not bool(effects.get("downed", false)) and not bool(effects.get("dying", false))

func life_state() -> String:
	if not alive or bool(effects.get("dying", false)): return "dead"
	if bool(effects.get("downed", false)): return "downed"
	return "second_life" if bool(effects.get("revived", false)) else "alive"

func pack() -> Dictionary:
	return {"ruleset": ruleset, "id": id, "character": character, "bot": bot, "alive": alive, "lms": lms, "hp": hp, "max_hp": max_hp, "stamina": stamina, "max_stamina": max_stamina, "cooldowns": cooldowns.duplicate(), "effects": network_effects(), "position": global_position, "velocity": velocity, "aim": aim, "display_name": display_name}




func network_effects() -> Dictionary:
	var result: Dictionary = {}
	if not is_on_floor():
		result["grounded"] = false

	for key: Variant in effects:
		var rule: Variant = NET_EFFECT_RULES.get(key)
		if rule == null:
			continue
		var value: Variant = effects[key]
		if int(rule) == NET_RULE_ID:
			if (value is int or value is float) and value >= 0:
				result[key] = value
		elif value is bool:
			if value:
				result[key] = true
		elif value is int or value is float:
			if value != 0:
				result[key] = value
		elif value is String or value is StringName:
			if not str(value).is_empty():
				result[key] = value

	if bool(effects.get("escaped", false)):
		result["escaped"] = true
	if float(effects.get("outlet_healing", 0.0)) > 0.0 and effects.has("outlet_position"):
		result["outlet_position"] = effects["outlet_position"]
	if bool(effects.get("grinding", false)) and effects.has("grind_direction"):
		result["grind_direction"] = effects["grind_direction"]
	if bool(effects.get("downed", false)) and effects.has("bleedout"):
		result["bleedout"] = effects["bleedout"]
	if int(effects.get("archive_qte_id", 0)) > 0 or float(effects.get("archive_qte_remaining", 0.0)) > 0.0:
		for key: String in NET_QTE_KEYS:
			if effects.has(key): result[key] = effects[key]

	if (bool(effects.get("boost_charging", false)) or float(effects.get("speed_boost", 0.0)) > 0.0) and effects.has("boost_level"):
		result["boost_level"] = effects["boost_level"]
	if float(effects.get("slow_time", 0.0)) > 0.0 and effects.has("slow_factor"):
		result["slow_factor"] = effects["slow_factor"]
	if float(effects.get("boost_time", 0.0)) > 0.0 and effects.has("boost_factor"):
		result["boost_factor"] = effects["boost_factor"]
	var carry: float = float(effects.get("carry_speed_factor", 1.0))
	if carry != 1.0 and float(effects.get("speed_boost", 0.0)) > 0.0:
		result["carry_speed_factor"] = carry
	return result

func pack_motion() -> Array:
	return [id, global_position, velocity, aim, hp, stamina, max_hp, max_stamina, alive, lms, PackedFloat32Array([cooldowns.get(0, 0), cooldowns.get(1, 0), cooldowns.get(2, 0), cooldowns.get(3, 0), cooldowns.get(4, 0), cooldowns.get(5, 0)]), network_effects()]

func unpack_motion(d: Array) -> void :
	net_position = d[1];net_velocity = d[2];aim = d[3];hp = float(d[4]);stamina = float(d[5]);max_hp = float(d[6]);max_stamina = float(d[7]);alive = bool(d[8]);lms = bool(d[9])
	for i in range(6): cooldowns[i] = d[10][i] if i < d[10].size() else 0.0
	effects = d[11]

func unpack(d: Dictionary) -> void :
	ruleset = PaperRules.normalize(str(d.get("ruleset", ruleset)))
	alive = bool(d.alive);lms = bool(d.lms)
	hp = float(d.hp);max_hp = float(d.max_hp);stamina = float(d.stamina);max_stamina = float(d.max_stamina)
	cooldowns = d.cooldowns;effects = d.effects
	net_position = d.position;net_velocity = d.velocity;aim = d.aim;display_name = d.display_name
