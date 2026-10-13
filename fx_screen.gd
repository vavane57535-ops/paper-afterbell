extends ColorRect









const SHADER: Shader = preload("res://fx_screen.gdshader")
const INK: Color = Color("0f0817")
const PALE: Color = Color("fff6e4")
const CLEAR: Color = Color(0, 0, 0, 0)

var world: Node
var _material: ShaderMaterial
var _clock: float = 0.0
var _speed: float = 0.0
var _rush: float = 0.0
var _focus: float = 0.0
var _focus_color: Color = INK
var _edge: Color = CLEAR
var _pulse: Color = CLEAR
var _pulse_left: float = 0.0
var _pulse_total: float = 1.0
var _flash: Color = CLEAR
var _flash_left: float = 0.0
var _flash_total: float = 0.1
var _splat: float = 0.0
var _splat_total: float = 1.5
var _heal_clock: float = 0.0
var _exit_open: bool = false

func setup(game_world: Node) -> void :
	world = game_world
	name = "ScreenFx"
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	visible = false

func clear() -> void :
	_speed = 0.0
	_rush = 0.0
	_focus = 0.0
	_edge = CLEAR
	_pulse_left = 0.0
	_flash_left = 0.0
	_splat = 0.0
	_exit_open = false
	visible = false







func impact(strength: float, inked: bool = true) -> void :
	if _calm(): return
	var amount: float = clampf(strength, 0.0, 1.0)
	if amount < _focus: return
	_focus = amount
	_focus_color = INK if inked else PALE


func frame(tint: Color, seconds: float = 0.07) -> void :
	if _calm(): return
	_flash = tint
	_flash_left = seconds
	_flash_total = maxf(0.02, seconds)


func pulse(tint: Color, seconds: float = 0.6) -> void :
	if _calm(): tint.a *= 0.5
	if _pulse_left > 0.0 and _pulse.a * (_pulse_left / _pulse_total) > tint.a: return
	_pulse = tint
	_pulse_left = seconds
	_pulse_total = maxf(0.05, seconds)


func rush(amount: float = 1.0) -> void :
	_rush = maxf(_rush, clampf(amount, 0.0, 1.0))


func splash(seconds: float = 1.5) -> void :
	if _light(): return
	_splat = 1.0
	_splat_total = maxf(0.3, seconds)
	_material.set_shader_parameter("splat_seed", randf() * 50.0)

func _calm() -> bool:
	return is_instance_valid(world) and bool(world.options.get("reduce_flashes", false))

func _light() -> bool:
	return is_instance_valid(world) and bool(world.get("mobile_mode")) and str(world.get("mobile_profile")) in ["performance", "battery"]





var _dread: float = 0.0
var _last_phase: String = ""

func _process(delta: float) -> void :
	if not is_instance_valid(world): return
	if not bool(world.options.get("screen_fx", true)):
		if visible: clear()
		return
	# Sortie de la partie (film de fin de manche…) : coupe nette des effets du jeu (pulsation de
	# l'alerte de sortie, vignette, bord d'état, vitesse) ; le film déclenche ensuite les siens.
	var phase_now: String = str(world.phase)
	if phase_now != _last_phase:
		if _last_phase == "playing": _cut_gameplay()
		_last_phase = phase_now
	_clock += delta
	_heal_clock = maxf(0.0, _heal_clock - delta)
	var target_speed: float = 0.0
	var target_edge: Color = CLEAR
	var shadows: float = 0.0
	if str(world.phase) == "playing":
		var view: PaperActor = world.call("_view_actor")
		if view != null and view.alive and not bool(view.effects.get("escaped", false)):
			var effects: Dictionary = view.effects
			var speed: float = Vector2(view.velocity.x, view.velocity.z).length()
			target_speed = smoothstep(9.2, 15.0, speed) * 0.75
			if speed > 5.0 and (float(effects.get("speed_boost", 0.0)) > 0.0 or float(effects.get("boost_time", 0.0)) > 0.0): target_speed = maxf(target_speed, 0.45)
			if speed > 6.0 and float(effects.get("forced_time", 0.0)) > 0.0: target_speed = maxf(target_speed, 0.9)
			if speed > 6.0 and float(effects.get("phase6", 0.0)) > 0.0: target_speed = maxf(target_speed, 0.55)
			if bool(effects.get("shadow_hide", false)): shadows = 0.6
			target_edge = _state_edge(view)
	elif str(world.phase) not in ["ending", "gallery", "lab", "prologue"]:

		_pulse_left = 0.0
		_splat = 0.0
		_focus = 0.0
		_rush = 0.0
	_rush = maxf(0.0, _rush - delta * 1.8)
	target_speed = maxf(target_speed, _rush)
	if _calm() or _light(): target_speed = 0.0
	_speed = lerpf(_speed, target_speed, 1.0 - exp( - delta * (9.0 if target_speed > _speed else 4.0)))
	_focus = maxf(0.0, _focus - delta * 3.6)
	_edge = _edge.lerp(target_edge, 1.0 - exp( - delta * 5.0)) if target_edge.a > 0.0 or _edge.a > 0.004 else CLEAR
	if target_edge.a <= 0.0: _edge.a = move_toward(_edge.a, 0.0, delta * 0.8)
	var edge: Color = _edge
	if _pulse_left > 0.0:
		_pulse_left = maxf(0.0, _pulse_left - delta)
		var level: float = _pulse.a * pow(_pulse_left / _pulse_total, 1.4)
		var share: float = level / maxf(level + edge.a, 0.001)
		edge = Color(lerpf(edge.r, _pulse.r, share), lerpf(edge.g, _pulse.g, share), lerpf(edge.b, _pulse.b, share), maxf(edge.a, level))
	var flash: Color = CLEAR
	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
		flash = Color(_flash, _flash.a * _flash_left / _flash_total)
	if _splat > 0.0: _splat = maxf(0.0, _splat - delta / _splat_total)

	var focus: float = maxf(_focus, shadows)
	var focus_color: Color = INK if shadows > _focus else _focus_color
	_dread = move_toward(_dread, 1.0 if str(world.phase) == "playing" and not _light() else 0.0, delta * 0.8)
	var active: bool = _speed > 0.004 or focus > 0.004 or edge.a > 0.004 or flash.a > 0.004 or _splat > 0.004 or _dread > 0.004
	if visible != active: visible = active
	if not active: return
	_material.set_shader_parameter("dread", _dread)
	_material.set_shader_parameter("speed", _speed)
	_material.set_shader_parameter("focus", focus)
	_material.set_shader_parameter("focus_color", focus_color)
	_material.set_shader_parameter("edge", edge)
	_material.set_shader_parameter("flash", flash)
	_material.set_shader_parameter("splat", _splat)
	_material.set_shader_parameter("clock", _clock)
	_material.set_shader_parameter("aspect", size.x / maxf(1.0, size.y))


func _cut_gameplay() -> void :
	_pulse_left = 0.0
	_flash_left = 0.0
	_focus = 0.0
	_splat = 0.0
	_rush = 0.0
	_speed = 0.0
	_edge = CLEAR
	_dread = 0.0


func _state_edge(view: PaperActor) -> Color:
	var effects: Dictionary = view.effects

	var beat: float = pow(maxf(0.0, sin(_clock * 8.6)), 8.0) + 0.6 * pow(maxf(0.0, sin(_clock * 8.6 - 1.1)), 8.0)
	if bool(effects.get("downed", false)): return Color(0.1, 0.0, 0.05, 0.56 + 0.16 * beat)
	if bool(effects.get("shadow_hide", false)): return Color(0.1, 0.02, 0.2, 0.62)
	if float(effects.get("phase6", 0.0)) > 0.0: return Color(0.75, 0.04, 0.14, 0.3 + 0.05 * sin(_clock * 3.0))
	if float(effects.get("overheat_time", 0.0)) > 0.0 or float(effects.get("overheat_hold", 0.0)) > 0.0 or float(effects.get("overheat_charge", 0.0)) > 0.0:
		return Color(1.0, 0.45, 0.1, 0.28 + 0.06 * sin(_clock * 9.0))
	if float(effects.get("stun", 0.0)) > 0.0: return Color(1.0, 0.85, 0.3, 0.2)
	if not view.killer:
		var danger: float = 0.0
		if float(effects.get("chased", 0.0)) > 0.0: danger = 0.16
		if view.max_hp > 0.0: danger += clampf((0.4 - view.hp / view.max_hp) / 0.4, 0.0, 1.0) * 0.26
		if danger > 0.0: return Color(0.6, 0.02, 0.08, danger * (0.75 + 0.45 * beat))
		if view.lms: return Color(1.0, 0.82, 0.3, 0.14)
	elif float(effects.get("stun_immunity", 0.0)) > 0.0:
		return Color(0.8, 0.1, 0.2, 0.2)
	if float(effects.get("speed_boost", 0.0)) > 0.0 or float(effects.get("boost_time", 0.0)) > 0.0: return Color(0.55, 0.9, 1.0, 0.13)
	return CLEAR





func on_event(kind: String, data: Dictionary) -> void :
	if not is_instance_valid(world) or str(world.phase) != "playing" or not bool(world.options.get("screen_fx", true)): return
	var view: PaperActor = world.call("_view_actor")
	var view_id: int = view.id if view != null else -1
	var mine: int = int(world.call("local_id"))
	var actor_id: int = int(data.get("actor", -1))
	var source_id: int = int(data.get("source", -1))
	match kind:
		"hit":
			if actor_id == view_id:
				impact(0.55)
				if str(data.get("attack", "slash")) != "shotgun": splash(1.1)
			elif source_id == mine and not bool(data.get("indirect", false)):
				impact(0.5, false)
		"stun":
			if actor_id == view_id:
				impact(0.7)
				pulse(Color(1.0, 0.85, 0.3, 0.3), 0.5)
			elif source_id == mine:
				impact(0.75, false)
				frame(Color(1.0, 1.0, 1.0, 0.14))
		"block":
			if actor_id == view_id or source_id == mine: impact(0.6, false)
		"dodge":
			if actor_id == view_id: rush(0.6)
		"grab":
			if bool(data.get("caught", false)) and int(data.get("target", -1)) == view_id: impact(0.65)
			elif bool(data.get("released", false)) and bool(data.get("wall", false)) and (actor_id == mine or _near(data, 10.0)): impact(0.7, actor_id != mine)
		"heal":
			if actor_id == view_id and float(data.get("amount", 0.0)) > 0.0 and _heal_clock <= 0.0:
				_heal_clock = 0.9
				pulse(Color(0.45, 1.0, 0.75, 0.2), 0.7)
		"revived":
			if actor_id == view_id: pulse(Color(0.6, 1.0, 0.85, 0.36), 1.0)
		"boost":
			if int(data.get("target", -1)) == view_id:
				pulse(Color(0.55, 0.9, 1.0, 0.26), 0.7)
				rush(0.8)
		"boost_release", "dash", "true_form_pounce":
			if actor_id == view_id: rush(1.0)
		"knockback":
			if actor_id == view_id:
				rush(0.7)
				impact(0.5)
		"downed":
			if actor_id == view_id:
				splash(2.2)
				pulse(Color(0.5, 0.0, 0.08, 0.5), 1.2)
		"death_start":
			if actor_id == view_id: splash(2.6)
			elif source_id == mine: impact(1.0)
		"phase6":
			if bool(data.get("active", false)):
				pulse(Color(0.85, 0.05, 0.15, 0.42), 1.3)
				impact(0.9)
		"lms": pulse(Color(1.0, 0.82, 0.3, 0.3), 1.0)
		"aura_unlock":
			if actor_id == view_id: pulse(Color(0.85, 0.75, 1.0, 0.3), 0.9)
		"escaped":
			if actor_id == view_id: pulse(Color(1.0, 0.92, 0.6, 0.45), 1.4)
		"exit_state":
			var state: Variant = data.get("state")
			var open: bool = state is Dictionary and bool((state as Dictionary).get("open", false))
			if open and not _exit_open: pulse(Color(1.0, 0.86, 0.45, 0.26), 1.0)
			_exit_open = open
		"lysia_explosion":
			if _near(data, 16.0):
				impact(0.8, false)
				pulse(Color(1.0, 0.55, 0.2, 0.34), 0.6)
		"grenade":
			if str(data.get("action", "")) == "explode" and _near(data, 12.0): impact(0.45, false)
		"overheat":
			if actor_id == view_id and bool(data.get("active", false)): pulse(Color(1.0, 0.5, 0.15, 0.3), 0.6)
		"objective": pulse(Color(1.0, 0.86, 0.4, 0.14), 0.5)
		"reveal":

			if not bool(data.get("killer_only", false)) and view != null and not view.killer and view.character != str(data.get("exclude", "")):
				impact(0.45)
				pulse(Color(0.7, 0.05, 0.2, 0.3), 0.8)
		"archive_alarm":
			if actor_id == view_id: pulse(Color(1.0, 0.3, 0.2, 0.32), 0.8)
		"stun_immunity":
			if actor_id == view_id: pulse(Color(0.9, 0.1, 0.2, 0.3), 0.7)

func _near(data: Dictionary, radius: float) -> bool:
	var position: Variant = data.get("position")
	if not position is Vector3: return false
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera != null and camera.global_position.distance_to(position) < radius
