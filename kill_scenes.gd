class_name PaperKillScenes
extends Node

# Exécutions d'Alice (« kill animations ») et bonus de temps par élimination.
#
# Hôte : begin() remplace la mort normale quand un survivant en dernière vie
# reçoit le coup fatal d'Alice. Les deux acteurs sont verrouillés ensemble
# (positions pilotées, Alice « kill_lock », victime « dying ») puis la victime
# est éliminée par _tick_lives à la fin de death_time.
# Tous les pairs : l'événement « kill_scene » lance la mise en scène locale
# (clips, IK de contact, accessoires, effets BD, caméra cinématique).

const CharProps = preload("res://char_props.gd")
const CharMaterials = preload("res://char_materials.gd")
const G = preload("res://model_geometry.gd")
const T = preload("res://ui_theme.gd")

const KILL_BONUS: float = 45.0
const MAX_REACH: float = 16.0
const LYSIA_RADIUS: float = 7.0
const LYSIA_STUN: float = 5.0
const BLEND_BACK: float = 0.75
# Onomatopées : fondu d'une ancienne quand une nouvelle apparaît ; hauteur
# maximale d'une lettre à l'écran (fraction de l'image) dans les plans serrés.
const WORD_CUT: float = 0.12
const WORD_MAX_SCREEN: float = 0.2
# Calque de rendu des acteurs et accessoires d'une exécution : l'éclairage film
# ne touche qu'eux, pas le décor (le menu fait de même avec le bit 10).
const KILL_LAYER: int = 1 << 11
# Panneau de jeu « SORTIE · … » (Label3D en billboard de map_interactables) : retiré des plans de
# l'exécution par le masque de la caméra (les films de fin le cachent eux-mêmes par visible).
const SIGN_LAYER: int = 1 << 12

# gap : distance entre les deux acteurs ; length : durée des clips (la victime
# meurt à lead + length) ; lock : fin du verrou d'Alice ; blast : explosion.
const VARIANTS: Dictionary = {
	"Usayuko": {"gap": 1.12, "length": 3.9, "lock": 3.5},
	"Elly": {"gap": 1.3, "length": 4.2, "lock": 3.75},
	"Lysia": {"gap": 0.8, "length": 4.6, "lock": 3.3, "blast": 3.3},
	"Simon": {"gap": 0.95, "length": 4.7, "lock": 4.25},
	"Ashura": {"gap": 1.0, "length": 3.9, "lock": 3.4},
	"Bleuette": {"gap": 0.85, "length": 3.9, "lock": 3.35},
	"slam": {"gap": 1.35, "length": 3.3, "lock": 2.95},
}

const KILL_SFX: Dictionary = {"kill_punch": 2, "kill_stab": 2, "kill_clang": 2, "kill_rip": 2, "kill_zap": 2, "kill_beep": 1, "kill_boom": 1, "kill_crunch": 2, "kill_slam": 2}

const WORDS: Dictionary = {
	"punch": ["PAF !", "POW!"], "slash": ["SHLAK !", "SLASH!"], "stab": ["TCHAC !", "STAB!"],
	"clang": ["CLANG !", "CLANG!"], "rip": ["CRRRAC !", "RIIIP!"], "zap": ["BZZT !", "BZZT!"],
	"boom": ["BOUM !", "BOOM!"], "catch": ["CHOPÉ !", "GOTCHA!"], "crunch": ["KRAAK !", "CRUNCH!"],
	"slam": ["BRAOUM !", "KA-BOOM!"], "slam2": ["KRAAAK !", "SMASH!"], "beep": ["BIP… BIP…", "BEEP… BEEP…"],
	"roar": ["GRRAAH !", "GRRAAH!"], "doubt": ["… !?", "… !?"], "gasp": ["HII !", "EEK!"],
}

var world: Node
var _scenes: Dictionary = {}
var _next_scene: int = 1
var _pending_bonus: int = 0
var _pending_stamp: float = 0.0
var bonus_total: float = 0.0
# Hôte : la dernière élimination était une exécution (plan joué chez tous) ; main._finish choisit
# alors l'épilogue d'Alice (PaperFilmExecutionEnd) au lieu du film où elle rattrape la victime.
var last_executed: bool = false
var camera_enabled: bool = true

var _shows: Dictionary = {}
var _camera_id: int = -1
var _camera_from: Transform3D = Transform3D.IDENTITY
var _camera_blend: float = 0.0
var _camera_fov: float = 60.0
var _shake: float = 0.0
var _shake_clock: float = 0.0
var _props_root: Node3D
var _debris: Array[Dictionary] = []
var _wrecked: Dictionary = {}
var _words: Array[Dictionary] = []
var _layer: CanvasLayer
var _bars: Array[ColorRect] = []
var _bars_amount: float = 0.0
var _bonus_label: Label
var _bonus_time: float = -1.0
var _bonus_bell: bool = false
var _font: Font
var _limb_cache: Dictionary = {}
var _materials: Dictionary = {}
var _ray: PhysicsRayQueryParameters3D
# Éclairage « film » du plan d'exécution (comme les films du jeu) : contre-jour
# froid derrière les deux acteurs, remplissage chaud côté caméra.
var _rim: OmniLight3D
var _fill: OmniLight3D
var _light_amount: float = 0.0

func setup(owner: Node) -> void :
	world = owner
	name = "KillScenes"
	_ray = PhysicsRayQueryParameters3D.new()
	_ray.collision_mask = 1
	_props_root = Node3D.new()
	_props_root.name = "KillProps"
	_props_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_child(_props_root)
	_rim = _film_light("KillRim", Color("9caee4"), 7.5)
	_fill = _film_light("KillFill", Color("eddfd3"), 6.5)
	_font = load("res://ui/fonts/Anton-Regular.ttf") if ResourceLoader.exists("res://ui/fonts/Anton-Regular.ttf") else ThemeDB.fallback_font
	for i in range(6):
		var label: Label3D = Label3D.new()
		label.font = _font
		label.font_size = 96
		label.outline_size = 30
		label.outline_modulate = Color("17101e")
		label.pixel_size = 0.0042
		label.shaded = false
		label.double_sided = true
		label.no_depth_test = true
		label.render_priority = 7
		label.outline_render_priority = 6
		label.visible = false
		# Replacées à chaque image (face caméra) : pas d'interpolation physique.
		label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_props_root.add_child(label)
		_words.append({"node": label, "age": 0.0, "life": 0.0, "origin": Vector3.ZERO, "size": 1.0, "tilt": 0.0, "cut": 0.0})
	_layer = CanvasLayer.new()
	_layer.layer = 11
	add_child(_layer)
	for i in range(2):
		var bar: ColorRect = ColorRect.new()
		bar.color = Color(0.02, 0.01, 0.03, 1.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		_layer.add_child(bar)
		_bars.append(bar)
	_bonus_label = Label.new()
	_bonus_label.add_theme_font_override("font", T.font("digits"))
	_bonus_label.add_theme_font_size_override("font_size", 46)
	_bonus_label.add_theme_color_override("font_color", T.GOLD)
	_bonus_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.05, 1.0))
	_bonus_label.add_theme_constant_override("outline_size", 10)
	_bonus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus_label.visible = false
	_layer.add_child(_bonus_label)
	# Serveur dédié : seule la simulation sert (begin/tick, appelés par le combat), pas la mise en scène.
	if bool(world.get("dedicated")):
		set_process(false)
		set_physics_process(false)


func _film_light(light_name: String, color: Color, reach: float) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = light_name
	light.light_color = color
	light.omni_range = reach
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.light_cull_mask = KILL_LAYER
	light.visible = false
	# Placée à chaque image avec la caméra : pas d'interpolation physique.
	light.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_props_root.add_child(light)
	return light


func _tag(node: Node, on: bool) -> void :
	if not is_instance_valid(node): return
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node
		geometry.layers = (geometry.layers | KILL_LAYER) if on else (geometry.layers & ~KILL_LAYER)
	for child: Node in node.get_children(): _tag(child, on)


func clear() -> void :
	for id: Variant in _shows.keys(): _end_show(int(id), true)
	_shows.clear()
	_scenes.clear()
	_pending_bonus = 0
	bonus_total = 0.0
	last_executed = false
	for entry: Dictionary in _debris:
		if is_instance_valid(entry.node): entry.node.queue_free()
	_debris.clear()
	_restore_wrecks(true)
	for word: Dictionary in _words: (word.node as Label3D).visible = false
	_camera_id = -1
	_drop_camera()
	_camera_blend = 0.0
	_bars_amount = 0.0
	for bar: ColorRect in _bars: bar.visible = false
	_bonus_time = -1.0
	_bonus_bell = false
	_bonus_label.visible = false
	_hud_alpha(1.0)
	_light_amount = 0.0
	_update_lights(0.0)
	_comic_guard(false)




# Vrai pendant un plan d'exécution sur ce poste (bandes noires, caméra de cinéma).
func cinematic() -> bool:
	return _camera_id >= 0


# Rend la caméra sans fondu (fin de manche, nettoyage) : le film ou la vue de jeu reprennent la main.
func _drop_camera() -> void:
	var rig = world.get("camera_rig") if world != null else null
	if rig != null: rig.release_control(self, 0.0)


func busy(actor) -> bool:
	if actor == null: return false
	for scene: Dictionary in _scenes.values():
		if (int(scene.killer) == int(actor.id) and not bool(scene.released)) or int(scene.victim) == int(actor.id): return true
	return false


func input_locked(actor) -> bool:
	if actor == null: return false
	if float(actor.effects.get("kill_lock", 0.0)) > 0.0: return true
	for show: Dictionary in _shows.values():
		if int(show.killer) == int(actor.id) and float(show.t) < float(show.lead) + float(show.lock): return true
	return false


func begin(victim, source_id: int, cause: String) -> bool:
	if world == null or not world.authoritative() or str(world.phase) != "playing": return false
	if victim == null or victim.killer or not victim.alive or bool(victim.effects.get("dying", false)): return false
	var alice = world.actors.get(source_id)
	if alice == null or not alice.killer or not alice.alive or busy(alice) or busy(victim): return false
	if float(alice.effects.get("stun", 0.0)) > 0.0 or bool(alice.effects.get("shadow_hide", false)) or int(alice.effects.get("grabbed_by", -1)) >= 0: return _skip(victim, "alice_busy")
	var phase6: bool = float(alice.effects.get("phase6", 0.0)) > 0.0
	var variant: String = "slam" if phase6 else str(victim.character)
	if not VARIANTS.has(variant): return false
	var spec: Dictionary = VARIANTS[variant]
	var spot: Vector3 = _floor_point(victim.global_position, 2.6)
	if not spot.is_finite(): return _skip(victim, "no_floor")
	var offset: Vector3 = alice.global_position - spot
	offset.y = 0.0
	if offset.length() > MAX_REACH or absf(alice.global_position.y - spot.y) > 2.5: return _skip(victim, "too_far")
	if not world.combat._los(alice.global_position, victim.global_position): return _skip(victim, "no_sight")
	var toward: Vector3 = offset.normalized() if offset.length_squared() > 0.0004 else -_flat(victim.aim)
	var stand: Vector3 = _stand_point(alice, spot, toward, float(spec.gap))
	if not stand.is_finite(): return _skip(victim, "no_room")
	var distance: float = alice.global_position.distance_to(stand)
	var lead: float = 0.2 if distance < 1.2 else clampf(0.24 + distance * 0.022, 0.26, 0.6)
	var length: float = float(spec.length)
	var lock: float = float(spec.lock)
	var combat = world.combat
	combat._cancel_revive_for(victim)
	combat._interrupt_life_actions(victim)
	victim.effects["downed"] = false
	victim.effects["bleedout"] = 0.0
	victim.effects["help_aura"] = 0.0
	victim.effects["dying"] = true
	victim.effects["death_time"] = lead + length
	victim.effects["death_kind"] = "execution"
	victim.effects["death_source"] = alice.id
	combat._reward("elimination", alice)
	combat.cancel_aim(alice)
	combat._cancel_charge(alice)
	for index in range(combat._attacks.size() - 1, -1, -1):
		if int(combat._attacks[index].actor) == int(alice.id):
			combat._end_box(alice, int(combat._attacks[index].cast_id), float(world.clock) + float(combat._attacks[index].left))
			combat._attacks.remove_at(index)
	_release_holds(alice)
	alice.effects["forced_time"] = 0.0
	alice.effects["kill_lock"] = lead + lock
	alice.effects["attack_lock"] = maxf(float(alice.effects.get("attack_lock", 0.0)), 0.2)
	alice.velocity = Vector3.ZERO
	alice.move_input = Vector3.ZERO
	var id: int = _next_scene
	_next_scene += 1
	var scene: Dictionary = {"id": id, "variant": variant, "killer": alice.id, "victim": victim.id, "start": float(world.clock), "lead": lead, "length": length, "lock": lock, "spot": spot, "stand": stand, "from": alice.global_position, "released": false, "blasted": false, "character": victim.character}
	if spec.has("blast"): scene["blast"] = float(spec.blast)
	_scenes[id] = scene
	world.event("kill_scene", {"id": id, "actor": victim.id, "source": alice.id, "variant": variant, "character": victim.character, "position": spot, "killer_position": stand, "killer_from": alice.global_position, "lead": lead, "length": length, "lock": lock, "cause": cause})
	return true


func _skip(victim, reason: String) -> bool:
	if bool(world.get("test_mode")): print("KILL_SCENE_SKIP ", victim.character, " ", reason)
	return false


func tick(delta: float) -> void :
	if _pending_bonus > 0 and float(world.clock) > _pending_stamp:
		var count: int = _pending_bonus
		_pending_bonus = 0
		if not world.lms and not world.training and str(world.phase) == "playing":
			for k in range(count):
				world.time_left = float(world.time_left) + KILL_BONUS
				bonus_total += KILL_BONUS
				world.event("kill_bonus", {"seconds": KILL_BONUS, "remaining": world.time_left})
			print("KILL_BONUS +", KILL_BONUS * float(count), " time_left=", snappedf(float(world.time_left), 0.01), " total=", bonus_total)
	for id: Variant in _scenes.keys():
		var scene: Dictionary = _scenes[id]
		var t: float = float(world.clock) - float(scene.start)
		var alice = world.actors.get(int(scene.killer))
		var victim = world.actors.get(int(scene.victim))
		var lead: float = float(scene.lead)
		var spot: Vector3 = scene.spot
		var stand: Vector3 = scene.stand
		# Victime remise sur pied entre-temps (réinitialisation du terrain d'essai) :
		# on rend la main à tout le monde.
		if victim != null and victim.alive and not bool(victim.effects.get("dying", false)):
			if alice != null and not bool(scene.released): _release(scene, alice)
			_scenes.erase(id)
			continue
		# Le chrono ne tombe pas à zéro au milieu d'une exécution : elle va à son terme
		# (puis le bonus de l'élimination s'applique).
		# (Pas en entraînement : il n'y a pas de chrono, time_left reste à 0.)
		if not world.training and victim != null and victim.alive and float(world.time_left) < 0.6: world.time_left = 0.6
		if victim != null and victim.alive:
			victim.global_position = spot
			victim.velocity = Vector3.ZERO
			victim.move_input = Vector3.ZERO
			victim.effects["motion_owned"] = true
			victim.aim = _flat(stand - spot)
		var locked: bool = not bool(scene.released) and t < lead + float(scene.lock)
		if alice != null and alice.alive and locked:
			var u: float = smoothstep(0.0, 1.0, clampf(t / maxf(lead, 0.01), 0.0, 1.0))
			alice.global_position = Vector3(scene.from).lerp(stand, u)
			alice.velocity = Vector3.ZERO
			alice.move_input = Vector3.ZERO
			alice.sprint = false
			alice.effects["motion_owned"] = true
			alice.effects["forced_time"] = 0.0
			alice.effects["blind"] = 0.0
			alice.effects["root"] = maxf(float(alice.effects.get("root", 0.0)), 0.12)
			alice.effects["attack_lock"] = maxf(float(alice.effects.get("attack_lock", 0.0)), 0.12)
			alice.effects["kill_lock"] = maxf(0.001, lead + float(scene.lock) - t)
			# La True Form ne s'achève pas au milieu de son fracas (le visuel d'Alice
			# changerait de corps et lâcherait la victime) : elle tient jusqu'au relâchement.
			if str(scene.variant) == "slam" and float(alice.effects.get("phase6", 0.0)) > 0.0:
				alice.effects["phase6"] = maxf(float(alice.effects.phase6), lead + float(scene.lock) - t + 0.1)
			alice.aim = _flat(spot - stand)
			_release_holds(alice)
			if alice.bot:
				alice.bot_state["progress_at"] = world.clock
				alice.bot_state["progress_position"] = alice.global_position
				alice.bot_state["stuck_for"] = 0.0
		elif alice != null and not bool(scene.released):
			_release(scene, alice)
		if scene.has("blast") and not bool(scene.blasted) and t >= lead + float(scene.blast):
			_lysia_blast(scene, alice, victim, true)
		if str(scene.variant) == "slam" and str(scene.character) == "Lysia" and bool(scene.released) and not bool(scene.blasted):
			_lysia_blast(scene, alice, victim, false)
		if t > lead + float(scene.length) + 0.4 and (victim == null or not victim.alive):
			if alice != null and not bool(scene.released): _release(scene, alice)
			_scenes.erase(id)
	# Verrou orphelin (Alice reprise par l'IA après une déconnexion : son id change) :
	# kill_lock n'est pas un effet minuté, on le lève ici.
	for actor in world.actors.values():
		if float(actor.effects.get("kill_lock", 0.0)) > 0.0 and not _holds_lock(actor): actor.effects["kill_lock"] = 0.0


func _holds_lock(actor) -> bool:
	for scene: Dictionary in _scenes.values():
		if int(scene.killer) == int(actor.id) and not bool(scene.released): return true
	return false


func _release(scene: Dictionary, alice) -> void :
	scene["released"] = true
	alice.effects["kill_lock"] = 0.0
	alice.effects["root"] = 0.0
	alice.effects["attack_lock"] = maxf(float(alice.effects.get("attack_lock", 0.0)), 0.1)
	alice.velocity = Vector3.ZERO


func _release_holds(alice) -> void :
	var combat = world.combat
	for other in world.actors.values():
		if other == alice: continue
		if int(other.effects.get("grab_target", -1)) == int(alice.id) or (float(other.effects.get("grab_time", 0.0)) > 0.0 and int(alice.effects.get("grabbed_by", -1)) == int(other.id)): combat._release_grab(other, false)
		if int(other.effects.get("overheat_target", -1)) == int(alice.id): combat._release_overheat(other)
	alice.effects["grabbed_by"] = -1


# Lysia : l'explosion qui étourdit Alice 5 s. forced = exécution normale
# (traverse l'aura anti-stun) ; sinon règle habituelle de son passif.
func _lysia_blast(scene: Dictionary, alice, victim, forced: bool) -> void :
	scene["blasted"] = true
	var combat = world.combat
	var at: Vector3 = scene.spot
	if alice != null and not bool(scene.released): _release(scene, alice)
	if alice != null and combat._can_act(alice) and alice.global_position.distance_to(at) <= LYSIA_RADIUS:
		if forced:
			alice.effects["stun_immunity"] = 0.0
			alice.effects["stun"] = 0.0
		combat.stun(alice, LYSIA_STUN, victim)
		if forced:
			var away: Vector3 = _flat(alice.global_position - at)
			combat._start_motion(alice, away, 2.4, 0.42, "knock")
	combat._dispel_radius(at, LYSIA_RADIUS, int(scene.victim))
	# Événement propre aux exécutions : la mise en scène locale fait toute l'explosion
	# à son instant (le ralenti local peut la décaler) au lieu de doubler celle du jeu.
	world.event("kill_blast", {"actor": int(scene.victim), "position": at, "radius": LYSIA_RADIUS, "execution": int(scene.id)})


func on_eliminated(actor) -> void :
	if world == null or not world.authoritative() or world.training or actor == null or actor.killer: return
	last_executed = str(actor.effects.get("death_kind", "")) == "execution"
	var killer = null
	for other in world.actors.values():
		if other.killer: killer = other
	if killer == null or int(actor.effects.get("death_source", -1)) != int(killer.id): return
	_pending_bonus += 1
	_pending_stamp = float(world.clock)




func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length_squared() > 0.000001 else Vector3.FORWARD


func _floor_point(at: Vector3, depth: float) -> Vector3:
	if not world.is_inside_tree(): return at
	_ray.from = at + Vector3.UP * 0.6
	_ray.to = at - Vector3.UP * depth
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty() or Vector3(hit.normal).y < 0.6: return Vector3.INF
	return Vector3(at.x, Vector3(hit.position).y + 0.02, at.z)


func _stand_point(alice, spot: Vector3, toward: Vector3, gap: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for angle: float in [0.0, 0.45, -0.45, 0.9, -0.9, 1.4, -1.4, 1.9, -1.9, 2.5, -2.5, PI]:
		var direction: Vector3 = toward.rotated(Vector3.UP, angle)
		for scale: float in [1.0, 0.85, 0.72]:
			var point: Vector3 = _floor_point(spot + direction * gap * scale, 1.4)
			if not point.is_finite() or absf(point.y - spot.y) > 0.45: continue
			point.y = maxf(point.y, spot.y)
			if not world.combat._los(spot, point): continue
			if not space.intersect_shape(world.combat._body_query(alice, point + Vector3.UP * 0.06), 1).is_empty(): continue
			return Vector3(spot.x, spot.y, spot.z) + direction * gap * scale + Vector3.UP * (point.y - spot.y)
	return Vector3.INF




func on_event(kind: String, data: Dictionary) -> void :
	match kind:
		"kill_scene": _start_show(data)
		"kill_bonus": _show_bonus(float(data.get("seconds", KILL_BONUS)))
		"kill_blast":
			var id: int = int(data.get("execution", 0))
			if _shows.has(id): _wreck_when_due(_shows[id])
			elif world.has_method("_event_local"):
				# Pas de mise en scène ici (serveur dédié, visuel absent) : explosion habituelle.
				var plain: Dictionary = data.duplicate()
				plain.erase("execution")
				world.call("_event_local", "lysia_explosion", plain)


# Le ralenti local peut mettre la mise en scène en retard sur l'hôte :
# l'explosion de Lysia attend alors son instant dans la chorégraphie.
func _wreck_when_due(show: Dictionary) -> void :
	if float(show.t) - float(show.lead) < _blast_time(show) - 0.02: show["wreck_pending"] = true
	else: _wreck_lysia(show)


func _blast_time(show: Dictionary) -> float:
	var spec: Dictionary = VARIANTS.get(str(show.variant), {})
	return float(spec.get("blast", show.lock))


# Ralenti visuel pour les joueurs impliqués (victime, Alice, ou leur spectateur) :
# la chorégraphie et les clips des deux acteurs avancent moins vite, puis
# rattrapent le retard (accéléré léger) ; l'hôte garde son horloge (positions,
# verrous et mort restent synchronisés).
func _slow_rate(show: Dictionary, local: float, delta: float) -> float:
	var rate: float = 1.0
	var slowed: bool = false
	if _involved(show):
		for track: Dictionary in show.tracks:
			if str(track.k) == "slow" and local >= float(track.t0) and local <= float(track.t1):
				slowed = true
				rate = minf(rate, float(track.get("rate", 0.5)))
	var lag: float = float(show.get("lag", 0.0))
	if not slowed and lag > 0.0: rate = 1.0 + minf(0.6, lag / maxf(delta, 0.001))
	return rate


func _slow_clips(victim, alice, amount: float) -> void :
	var visuals: Array = []
	if victim != null and is_instance_valid(victim.visual): visuals.append(victim.visual)
	if alice != null and is_instance_valid(alice.visual):
		visuals.append(alice.visual)
		var form: PaperVisual = alice.visual.fx_source()
		if form != alice.visual: visuals.append(form)
	for visual: PaperVisual in visuals:
		var left: float = float(visual._action_time)
		if left > 0.0 and float(visual._hold_left) <= 0.0:
			visual._action_time = clampf(left + amount, 0.0, float(visual._action_duration))


func _start_show(data: Dictionary) -> void :
	var id: int = int(data.get("id", 0))
	if _shows.has(id) or bool(world.get("dedicated")): return
	var victim: PaperActor = world.actors.get(int(data.get("actor", -1)))
	var alice: PaperActor = world.actors.get(int(data.get("source", -1)))
	if victim == null or alice == null or not is_instance_valid(victim.visual) or not is_instance_valid(alice.visual): return
	var spot: Vector3 = data.get("position", victim.global_position)
	var stand: Vector3 = data.get("killer_position", alice.global_position)
	var forward: Vector3 = _flat(stand - spot)
	var show: Dictionary = {
		"id": id, "variant": str(data.get("variant", victim.character)), "victim": victim.id, "killer": alice.id,
		"spot": spot, "stand": stand, "from": data.get("killer_from", alice.global_position),
		"lead": float(data.get("lead", 0.2)), "length": float(data.get("length", 3.5)), "lock": float(data.get("lock", 3.2)),
		"t": 0.0, "started": false, "cue": 0, "cues": [], "tracks": [], "shots": [], "props": {}, "ended": false,
		"o": (spot + stand) * 0.5, "f": forward, "r": forward.cross(Vector3.UP).normalized(), "gap": spot.distance_to(stand),
		"character": str(victim.character), "bones": [], "camera": false,
	}
	match str(show.variant):
		"Usayuko": _script_usayuko(show)
		"Elly": _script_elly(show)
		"Lysia": _script_lysia(show)
		"Simon": _script_simon(show)
		"Ashura": _script_ashura(show)
		"Bleuette": _script_bleuette(show)
		_: _script_slam(show)
	(show.cues as Array).sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	(show.shots as Array).sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	_shows[id] = show
	_tag(victim.visual, true)
	_tag(alice.visual, true)
	victim.visual.react_to_hit(1.0, Vector3(show.stand))
	if Vector3(show.from).distance_to(Vector3(show.stand)) > 2.4:
		_comic_cue(alice, "afterimage")
		_comic_cue(alice, "ink_burst")
		_sound("shadow", Vector3(show.from), 0.7, 0.8)
	_sound("hit", spot, 0.8, 0.82)


func _end_show(id: int, immediate: bool = false) -> void :
	if not _shows.has(id): return
	var show: Dictionary = _shows[id]
	show.ended = true
	var victim: PaperActor = world.actors.get(int(show.victim))
	if victim != null and is_instance_valid(victim.visual):
		victim.visual.position = Vector3.ZERO
		_tag(victim.visual, false)
	var alice: PaperActor = world.actors.get(int(show.killer))
	var shared: bool = false
	for other: Dictionary in _shows.values():
		if other != show and int(other.killer) == int(show.killer): shared = true
	if alice != null and is_instance_valid(alice.visual) and not shared: _tag(alice.visual, false)
	for key: Variant in (show.props as Dictionary).keys():
		var node: Variant = show.props[key]
		if is_instance_valid(node): (node as Node).queue_free()
	(show.props as Dictionary).clear()
	if immediate or not world.is_inside_tree(): _restore_bones(show)
	_shows.erase(id)


func _restore_bones(show: Dictionary) -> void :
	var victim: PaperActor = world.actors.get(int(show.victim))
	if victim == null or not is_instance_valid(victim.visual) or not is_instance_valid(victim.visual._imported): return
	var skeleton: Skeleton3D = victim.visual._imported.skeleton
	for bone: Variant in show.bones:
		if int(bone) >= 0 and int(bone) < skeleton.get_bone_count(): skeleton.set_bone_pose_scale(int(bone), Vector3.ONE)
	(show.bones as Array).clear()




func _process(delta: float) -> void :
	if world == null: return
	# Pause en solo : la simulation est arrêtée, la mise en scène aussi (sinon elle
	# se déroulerait derrière le menu, sons compris).
	if _paused():
		_update_bars(delta)
		_update_lights(delta)
		# « +0:45 » est sur un calque au-dessus de l'interface : il ne doit pas rester figé sur le menu pause.
		if _bonus_label.visible: _bonus_label.visible = false
		return
	# Débris et accessoires restent dans la partie : ni dans le film de fin, ni sur l'écran des résultats.
	var in_round: bool = str(world.phase) == "playing"
	if _props_root.visible != in_round: _props_root.visible = in_round
	if not in_round:
		for id: Variant in _shows.keys(): _end_show(int(id), true)
		# Manche finie pendant une exécution (dernière victime) : les bandes noires
		# et le HUD estompé ne doivent pas rester sur le film de fin.
		if _camera_id >= 0:
			_camera_id = -1
			_bars_amount = 0.0
			_comic_guard(false)
			_drop_camera()
	for id: Variant in _shows.keys():
		var show: Dictionary = _shows[id]
		var hold: float = float(show.get("hold", 0.0))
		var victim: PaperActor = world.actors.get(int(show.victim))
		var alice: PaperActor = world.actors.get(int(show.killer))
		if hold > 0.0:
			show["hold"] = maxf(0.0, hold - delta)
			show["lag"] = float(show.get("lag", 0.0)) + delta
		else:
			var rate: float = _slow_rate(show, float(show.t) - float(show.lead), delta)
			show.t = float(show.t) + delta * rate
			show["lag"] = maxf(0.0, float(show.get("lag", 0.0)) + delta * (1.0 - rate))
			if rate != 1.0: _slow_clips(victim, alice, delta * (1.0 - rate))
		var local: float = float(show.t) - float(show.lead)
		if not bool(show.started) and local >= 0.0:
			show.started = true
			if victim != null and is_instance_valid(victim.visual):
				victim.visual.trigger("death_kill_" + str(show.variant).to_lower())
				if str(show.variant) == "Simon": victim.visual.set("_dead_clip", "dead_spike")
			if alice != null and is_instance_valid(alice.visual):
				alice.visual.trigger("kill_" + str(show.variant).to_lower())
		for track: Dictionary in show.tracks:
			if str(track.k) == "slow" and local >= float(track.t0) and local <= float(track.t1) and _involved(show):
				var screen: Node = _screen()
				if screen != null: screen.impact(float(track.get("w", 0.34)), true)
		var cues: Array = show.cues
		while int(show.cue) < cues.size() and float(cues[int(show.cue)][0]) <= local:
			_run_cue(show, cues[int(show.cue)])
			show.cue = int(show.cue) + 1
		if bool(show.get("wreck_pending", false)) and local >= _blast_time(show):
			show.wreck_pending = false
			_wreck_lysia(show)
		if local > float(show.length) + 1.1: _end_show(int(id))
	_update_words(delta)
	_update_bars(delta)
	_update_lights(delta)
	_update_bonus(delta)
	_restore_wrecks(false)


func _paused() -> bool:
	return bool(world.get("pause_open")) and not bool(world.get("networked"))


func _physics_process(delta: float) -> void :
	if world == null or _paused(): return
	for show: Dictionary in _shows.values():
		var local: float = float(show.t) - float(show.lead)
		var victim: PaperActor = world.actors.get(int(show.victim))
		var alice: PaperActor = world.actors.get(int(show.killer))
		if victim == null or alice == null or not is_instance_valid(victim.visual) or not is_instance_valid(alice.visual): continue
		var holder: PaperVisual = alice.visual.fx_source()
		var body: PaperVisual = victim.visual
		for track: Dictionary in show.tracks:
			if str(track.k) != "reach" or str(track.who) != "a": continue
			var w: float = _window(track, local)
			if w > 0.0: _reach(holder, int(track.side), _track_point(show, track, holder, body, victim), w * float(track.get("w", 1.0)))
		var attach: float = 0.0
		for track: Dictionary in show.tracks:
			if str(track.k) != "attach": continue
			var w: float = _window(track, local)
			if w <= 0.0: continue
			attach = w
			var point: Vector3 = holder.socket_position(str(track.get("from", "hand_r"))) + _frame_vec(show, track.get("offset", Vector3.ZERO))
			var rel: Vector3 = body.socket_position(str(track.get("socket", "chest"))) - body.global_position
			body.global_position = victim.global_position.lerp(point - rel, w)
		if attach <= 0.0 and body.position.length_squared() > 0.0:
			body.position = Vector3.ZERO
		for track: Dictionary in show.tracks:
			if str(track.k) != "reach" or str(track.who) == "a": continue
			var w: float = _window(track, local)
			if w > 0.0: _reach(body, int(track.side), _track_point(show, track, holder, body, victim), w * float(track.get("w", 1.0)))
		_place_props(show, local, holder, body)
	_update_debris(delta)


func _window(track: Dictionary, t: float) -> float:
	var t0: float = float(track.t0)
	var t1: float = float(track.t1)
	if t < t0 or t > t1: return 0.0
	var fade_in: float = float(track.get("in", 0.12))
	var fade_out: float = float(track.get("out", 0.12))
	var a: float = 1.0 if fade_in <= 0.0 else smoothstep(t0, t0 + fade_in, t)
	var b: float = 1.0 if fade_out <= 0.0 else 1.0 - smoothstep(t1 - fade_out, t1, t)
	return a * b


func _frame_vec(show: Dictionary, local: Variant) -> Vector3:
	if not local is Vector3: return Vector3.ZERO
	var v: Vector3 = local
	return Vector3(show.r) * v.x + Vector3.UP * v.y + Vector3(show.f) * v.z


func _frame_point(show: Dictionary, local: Vector3) -> Vector3:
	return Vector3(show.o) + _frame_vec(show, local)


func _track_point(show: Dictionary, track: Dictionary, holder: PaperVisual, body: PaperVisual, victim: PaperActor) -> Vector3:
	var offset: Vector3 = _frame_vec(show, track.get("offset", Vector3.ZERO))
	var target: String = str(track.get("to", "v"))
	if target == "point": return _frame_point(show, track.get("point", Vector3.ZERO)) + offset
	if target == "rest":
		var rel: Vector3 = body.socket_position(str(track.get("socket", "chest"))) - body.global_position
		return victim.global_position + rel + offset
	var source: PaperVisual = holder if target == "a" else body
	return source.socket_position(str(track.get("socket", "chest"))) + offset


func _reach(visual: PaperVisual, side: int, target: Vector3, weight: float) -> void :
	if weight <= 0.001 or not is_instance_valid(visual) or not is_instance_valid(visual._body) or not target.is_finite(): return
	var hand: Node3D = visual._right_hand if side > 0 else visual._left_hand
	var local: Vector3 = visual._body.global_transform.affine_inverse() * target
	visual._hand_target_weighted(side, local, clampf(weight, 0.0, 1.0), hand.quaternion, 1.0)
	visual._sync_now()




func _run_cue(show: Dictionary, cue: Array) -> void :
	var victim: PaperActor = world.actors.get(int(show.victim))
	var alice: PaperActor = world.actors.get(int(show.killer))
	if victim == null or alice == null: return
	var holder: PaperVisual = alice.visual.fx_source()
	var body: PaperVisual = victim.visual
	var comic: Node = _comic()
	var involved: bool = _involved(show)
	var op: String = str(cue[1])
	match op:
		"word":
			var who: PaperVisual = holder if str(cue[3]) == "a" else body
			var at: Vector3 = who.socket_position(str(cue[4])) + _frame_vec(show, cue[5] if cue.size() > 5 else Vector3.ZERO)
			_word(str(cue[2]), at, cue[6] if cue.size() > 6 else Color("fff6e4"), float(cue[7]) if cue.size() > 7 else 1.0)
		"fx":
			var who: PaperVisual = holder if str(cue[2]) == "a" else body
			for name: String in str(cue[3]).split(" ", false): _comic_visual(who, name)
		"pop":
			if comic == null: return
			var who: PaperVisual = holder if str(cue[2]) == "a" else body
			var at: Vector3 = who.socket_position(str(cue[3])) + _frame_vec(show, cue[4] if cue.size() > 4 else Vector3.ZERO)
			comic.pop(at, _frame_vec(show, cue[5]) if cue.size() > 5 else Vector3.UP, cue[6] if cue.size() > 6 else Color("fff6e4"), float(cue[7]) if cue.size() > 7 else 1.0)
		"sfx":
			_sound(str(cue[2]), Vector3(show.o) + Vector3.UP, float(cue[3]) if cue.size() > 3 else 1.0, float(cue[4]) if cue.size() > 4 else 1.0)
		"shake":
			if involved: _shake = clampf(_shake + float(cue[2]), 0.0, 1.0)
			elif world.has_method("add_camera_trauma") and world.camera.is_inside_tree():
				var distance: float = world.camera.global_position.distance_to(Vector3(show.o))
				if distance < 18.0: world.add_camera_trauma(float(cue[2]) * 0.6 * (1.0 - distance / 18.0))
		"screen":
			var screen: Node = _screen()
			if screen == null or not involved: return
			match str(cue[2]):
				"impact": screen.impact(float(cue[3]), cue.size() <= 4 or bool(cue[4]))
				"pulse": screen.pulse(cue[3], float(cue[4]) if cue.size() > 4 else 0.6)
				"frame": screen.frame(cue[3], float(cue[4]) if cue.size() > 4 else 0.07)
				"rush": screen.rush(float(cue[3]))
				"splash": screen.splash(float(cue[3]) if cue.size() > 3 else 1.4)
		"hitstop":
			holder.hit_stop(float(cue[2]))
			body.hit_stop(float(cue[2]))
			show["hold"] = maxf(float(show.get("hold", 0.0)), minf(float(cue[2]), 0.25))
		"claw":
			if comic == null: return
			var at: Vector3 = body.socket_position(str(cue[2])) - Vector3(show.f) * 0.12
			world.presentation.impact(at, Vector3(show.f), "execution")
			comic.mark(comic.CRESCENT, at, Color("ff6a86", 0.95), 0.5, 1.5, 0.3, {"add": true, "angle": float(cue[3]) if cue.size() > 3 else 0.8, "fade": 0.4})
			comic.mark(comic.SMEAR, at, Color("b3304f", 0.9), 0.4, 1.2, 0.45, {"angle": float(cue[3]) if cue.size() > 3 else 0.8, "fade": 0.5})
			comic.ink_puffs(at, 3, 1.8)
		"stab":
			if comic == null: return
			var at: Vector3 = body.socket_position(str(cue[2])) - Vector3(show.f) * 0.05
			world.presentation.impact(at, Vector3(show.f), "execution")
			comic.mark(comic.BURST, at, Color("ff4a68", 0.95), 0.3, 1.0, 0.2, {"pop": 0.5, "ink": Color("1c0f24")})
			comic.mark(comic.RAYS, at, Color("ffd2da", 0.7), 0.5, 1.5, 0.28, {"add": true, "fade": 0.25})
			world.presentation._emit(world.presentation.KIT_INK, at, -Vector3(show.f) + Vector3.UP * 0.3, Color("3a1030"), true, 0.8, 50.0)
		"tear":
			if comic == null: return
			var eyes: Vector3 = body.socket_position("eyes")
			for k: int in range(int(cue[2]) if cue.size() > 2 else 2):
				var side: Vector3 = Vector3(show.r) * (0.06 if k % 2 == 0 else -0.06)
				comic.mark(comic.DROP, eyes + side - Vector3.UP * 0.03, Color("bfe9ff", 0.98), 0.07, 0.13, 0.9, {"vel": Vector3.DOWN * 0.35 - Vector3(show.f) * 0.15, "gravity": 1.6, "fade": 0.7, "delay": 0.22 * float(k), "ink": Color("2d5a78")})
		"sweat":
			if comic == null: return
			var who: PaperVisual = holder if str(cue[2]) == "a" else body
			comic.sweat(who.socket_position("head"), int(cue[3]) if cue.size() > 3 else 3)
		"exclaim":
			if comic == null: return
			var who: PaperVisual = holder if str(cue[2]) == "a" else body
			comic.mark(comic.EXCLAIM, Vector3.ZERO, Color(cue[3] if cue.size() > 3 else Color("ffe066"), 0.98), 0.25, 0.42, 0.75, {"follow": who, "socket": "over", "offset": _frame_vec(show, Vector3(0.18, 0.05, 0.0)), "pop": 0.6, "fade": 0.75})
		"sparks":
			var who: PaperVisual = holder if str(cue[2]) == "a" else body
			var at: Vector3 = who.socket_position(str(cue[3]))
			world.presentation._emit(world.presentation.KIT_SPARK, at, Vector3.UP + _frame_vec(show, cue[4] if cue.size() > 4 else Vector3.ZERO), Color("ffe9a8"), false, float(cue[5]) if cue.size() > 5 else 1.2, 120.0)
			if comic: comic.bolts(at, Color("bff6ff"), 3, 0.35, 0.6)
		"glow":
			var who: PaperVisual = holder if str(cue[2]) == "a" else body
			if not world.presentation._flashes_reduced():
				world.presentation._sprite(world.presentation.BLEND_ADD, who.socket_position(str(cue[3])) - Vector3(show.f) * 0.1, world.presentation.SHAPE_GLOW, cue[4], float(cue[5]), float(cue[6]), float(cue[7]))
		"crack":
			if comic == null: return
			var at: Vector3 = _frame_point(show, cue[2])
			at.y = Vector3(show.spot).y
			comic.crack(at, float(cue[3]) if cue.size() > 3 else 1.8)
			comic.dust_ring(at, float(cue[4]) if cue.size() > 4 else 1.2)
		"ink":
			if comic == null: return
			var at: Vector3 = _frame_point(show, cue[2])
			at.y = Vector3(show.spot).y
			if cue.size() <= 3: comic.cue(body, "ink_burst")
			else: comic.ink_puffs(at + Vector3.UP * 0.4, int(cue[3]), 3.0)
		"rip":
			_rip_limb(show, victim, str(cue[2]), _frame_vec(show, cue[3]))
		"drop_gun":
			_drop_gun(show, victim)
		"drop_photo":
			_drop_photo(show)
		"drone_burst":
			_burst_drone(show, holder)
		"flash":
			var screen: Node = _screen()
			if screen != null and (involved or Vector3(show.o).distance_to(world.camera.global_position) < 14.0): screen.frame(cue[2], float(cue[3]) if cue.size() > 3 else 0.12)
		"camera":
			show.camera = bool(cue[2])




func _comic() -> Node:
	var effects: Variant = world.get("presentation")
	if not is_instance_valid(effects): return null
	var layer: Variant = effects.get("comic")
	return layer if is_instance_valid(layer) else null


func _screen() -> Node:
	var ui: Variant = world.get("ui")
	if not is_instance_valid(ui): return null
	var layer: Variant = ui.get("screen_fx")
	return layer if is_instance_valid(layer) else null


func _comic_cue(actor: PaperActor, cue: String) -> void :
	if actor != null and is_instance_valid(actor.visual): _comic_visual(actor.visual.fx_source(), cue)


func _comic_visual(visual: PaperVisual, cue: String) -> void :
	var comic: Node = _comic()
	if comic != null and is_instance_valid(visual): comic.cue(visual, cue)


func _sound(kind: String, at: Vector3, gain: float = 1.0, pitch: float = 1.0) -> void :
	if world.audio == null or not world.audio.has_method("sfx"): return
	if KILL_SFX.has(kind): _ensure_sfx(kind)
	world.audio.sfx(kind, at, world._listener_position(), gain, pitch)


# Bruitages propres aux exécutions (audio/sfx/kill_*.wav), ajoutés à la banque
# de PaperAudio au premier usage sans toucher à audio.gd.
func _ensure_sfx(kind: String) -> void :
	var bank: Variant = world.audio.get("effects")
	if not bank is Dictionary or (bank as Dictionary).has(kind) or bool(world.audio.get("_silent")): return
	var variants: Array[AudioStream] = []
	for index in range(int(KILL_SFX[kind])):
		var path: String = "res://audio/sfx/%s_%02d.wav" % [kind, index]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			if stream: variants.append(stream)
	(bank as Dictionary)[kind] = variants


func _involved(show: Dictionary) -> bool:
	var view: PaperActor = world._view_actor()
	var me: PaperActor = world.local_actor()
	var ids: Array = [int(show.victim), int(show.killer)]
	if me != null and int(me.id) in ids and not me.bot: return true
	if view != null and int(view.id) in ids: return true
	return false




func _word(key: String, at: Vector3, color: Color, size: float = 1.0) -> void :
	if not bool(world.options.get("fx_words", true)) or not at.is_finite(): return
	var texts: Array = WORDS.get(key, [key, key])
	var chosen: Dictionary = _words[0]
	for entry: Dictionary in _words:
		if not (entry.node as Label3D).visible:
			chosen = entry
			break
	var label: Label3D = chosen.node
	label.text = str(texts[1] if PaperLanguage.language == "en" else texts[0])
	label.modulate = color
	chosen.age = 0.0
	chosen.life = 0.95
	chosen.origin = at
	chosen.size = size
	chosen.tilt = randf_range(-0.22, 0.22)
	chosen.cut = 0.0
	label.visible = true
	# Une onomatopée à la fois : la précédente s'efface vite au lieu de se superposer.
	for entry: Dictionary in _words:
		if entry.node != label and (entry.node as Label3D).visible and float(entry.get("cut", 0.0)) <= 0.0: entry.cut = WORD_CUT


func _update_words(delta: float) -> void :
	var camera: Camera3D = world.camera
	if camera == null or not camera.is_inside_tree(): return
	for entry: Dictionary in _words:
		var label: Label3D = entry.node
		if not label.visible: continue
		entry.age = float(entry.age) + delta
		var t: float = float(entry.age) / float(entry.life)
		if t >= 1.0:
			label.visible = false
			continue
		var cut: float = float(entry.get("cut", 0.0))
		if cut > 0.0:
			cut = maxf(0.0, cut - delta)
			entry.cut = cut
			if cut <= 0.0:
				label.visible = false
				continue
		var u: float = clampf(t / 0.2, 0.0, 1.0) - 1.0
		var swell: float = 1.0 + 2.4 * u * u * u + 1.5 * u * u
		var at: Vector3 = Vector3(entry.origin) + Vector3.UP * 0.35 * (1.0 - pow(1.0 - t, 2.0))
		var to_camera: Vector3 = camera.global_position - at
		var distance: float = maxf(0.5, to_camera.length())
		var base: float = float(entry.size) * clampf(distance / 4.0, 0.55, 2.4)
		# Gros plan : la lettre ne dépasse pas WORD_MAX_SCREEN de la hauteur de l'image
		# (sinon « TCHAC ! » couvre toute l'action).
		var depth: float = -(camera.global_transform.affine_inverse() * at).z
		if depth > 0.05:
			var view_h: float = 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5)
			var glyph: float = float(label.font_size) * label.pixel_size * base
			if glyph > WORD_MAX_SCREEN * view_h: base *= WORD_MAX_SCREEN * view_h / glyph
		var scale: float = maxf(0.01, swell * base)
		if _camera_id >= 0: at = _keep_in_frame(camera, at, label, scale)
		to_camera = camera.global_position - at
		var facing: Basis = Basis.looking_at(-to_camera.normalized(), Vector3.UP) * Basis(Vector3.BACK, float(entry.tilt))
		label.transform = Transform3D(facing.scaled(Vector3.ONE * scale), at)
		var alpha: float = 1.0 - smoothstep(0.7, 1.0, t)
		if cut > 0.0: alpha *= cut / WORD_CUT
		label.modulate.a = alpha
		label.outline_modulate = Color(0.09, 0.06, 0.12, alpha)


# Plans serrés : l'onomatopée reste lisible entre les bandes noires au lieu
# d'être coupée par le bord de l'image.
func _keep_in_frame(camera: Camera3D, at: Vector3, label: Label3D, scale: float) -> Vector3:
	if camera.is_position_behind(at): return at
	var view: Vector2 = get_viewport().get_visible_rect().size
	var depth: float = -(camera.global_transform.affine_inverse() * at).z
	if depth <= 0.05 or view.y <= 0.0: return at
	var per_px: float = 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5) / view.y
	var glyph: float = float(label.font_size) * label.pixel_size * scale / per_px
	# Largeur d'Anton en capitales (~0,52 em par signe) plus le contour épais et
	# l'inclinaison : sinon le bord du mot sortait encore du cadre.
	var half: Vector2 = Vector2(0.5 * glyph * (0.52 * float(label.text.length()) + 0.8), 0.7 * glyph)
	var bar: float = view.y * 0.095 * smoothstep(0.0, 1.0, _bars_amount)
	var screen: Vector2 = camera.unproject_position(at)
	var low: Vector2 = Vector2(half.x + 12.0, bar + half.y + 8.0)
	var high: Vector2 = Vector2(view.x - half.x - 12.0, view.y - bar - half.y - 8.0)
	var target: Vector2 = Vector2(clampf(screen.x, low.x, maxf(low.x, high.x)), clampf(screen.y, low.y, maxf(low.y, high.y)))
	var shift: Vector2 = target - screen
	if shift.length_squared() < 0.25: return at
	return at + camera.global_basis.x * shift.x * per_px - camera.global_basis.y * shift.y * per_px




func camera_override(delta: float) -> bool:
	if not camera_enabled: return false
	var show: Dictionary = {}
	for candidate: Dictionary in _shows.values():
		# Acteur disparu (déconnexion : son id change) : pas de plan sur lui.
		if world.actors.get(int(candidate.victim)) == null or world.actors.get(int(candidate.killer)) == null: continue
		if (candidate.shots as Array).is_empty(): continue
		if _involved(candidate) and float(candidate.t) < float(candidate.lead) + float(candidate.length) + 0.25:
			show = candidate
			break
	var camera: Camera3D = world.camera
	if show.is_empty():
		if _camera_id >= 0:
			_camera_id = -1
			_comic_guard(false)
			var rig = world.get("camera_rig")
			if rig != null:
				# Retour à la vue de jeu en fondu (position et champ de vision).
				rig.release_control(self, BLEND_BACK)
				rig._following = true
			world.camera_anchor_ready = false
		return false
	if _camera_id != int(show.id):
		_camera_id = int(show.id)
		_camera_from = camera.global_transform
		_camera_fov = camera.fov
		_camera_blend = 1.0
		if is_instance_valid(world.camera_obscured_actor): world.camera_obscured_actor.visual.visible = true
		world.camera_obscured_actor = null
		_mute_comic_words(true)
		_comic_guard(true)
		# Le plan prend la caméra comme les autres plans en jeu : souris, stick, tactile et touche C
		# (bandeau « CAMÉRA », recentrage) restent bloqués jusqu'à la fin du plan.
		var holder = world.get("camera_rig")
		if holder != null: holder.take_control(self)
	_mute_comic_words(false)
	var victim: PaperActor = world.actors.get(int(show.victim))
	var alice: PaperActor = world.actors.get(int(show.killer))
	var local: float = float(show.t) - float(show.lead)
	var shots: Array = show.shots
	var index: int = 0
	for k: int in range(shots.size()):
		if float(shots[k][0]) <= local: index = k
	var spec: Dictionary = shots[index][1]
	var start: float = float(shots[index][0])
	var end: float = float(shots[index + 1][0]) if index + 1 < shots.size() else float(show.length) + 0.3
	var u: float = clampf((local - start) / maxf(0.01, end - start), 0.0, 1.0)
	match str(spec.get("ease", "smooth")):
		"smooth": u = smoothstep(0.0, 1.0, u)
		"out": u = 1.0 - pow(1.0 - u, 2.5)
		"in": u = u * u
	var holder: PaperVisual = alice.visual.fx_source()
	var body: PaperVisual = victim.visual
	var eye: Vector3 = _shot_point(show, spec.get("eye", Vector3(2.5, 1.4, 0.0)), u, holder, body)
	var look: Vector3 = _shot_point(show, spec.get("look", Vector3(0, 1.2, 0)), u, holder, body)
	var fov_value: Variant = spec.get("fov", 50.0)
	var fov: float = lerpf(float(fov_value[0]), float(fov_value[1]), u) if fov_value is Array else float(fov_value)
	var t_hand: float = float(show.t)
	eye += Vector3(show.r) * sin(t_hand * 1.3) * 0.03 + Vector3.UP * sin(t_hand * 1.7 + 1.3) * 0.025
	eye = _avoid_bodies(eye, holder, null if bool(spec.get("pov", false)) else body)
	eye = _safe_eye(look, eye)
	var goal: Transform3D = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye) if eye.distance_squared_to(look) > 0.0004 else camera.global_transform
	_place_lights(eye, look)
	var roll_value: Variant = spec.get("roll", 0.0)
	var roll: float = lerpf(float(roll_value[0]), float(roll_value[1]), u) if roll_value is Array else float(roll_value)
	if absf(roll) > 0.01: goal.basis = goal.basis * Basis(Vector3.BACK, deg_to_rad(roll))
	if _camera_blend > 0.0:
		_camera_blend = maxf(0.0, _camera_blend - delta / 0.32)
		var w: float = smoothstep(0.0, 1.0, 1.0 - _camera_blend)
		var blended: Transform3D = _camera_from.interpolate_with(goal, w)
		# Raccord en arc autour de la scène (et non en ligne droite) : depuis la vue de jeu, derrière
		# Alice, la ligne droite traversait ses cheveux et son dos pendant 2 ou 3 images.
		var pivot: Vector3 = Vector3(show.o) + Vector3.UP * 1.1
		var from_offset: Vector3 = _camera_from.origin - pivot
		var to_offset: Vector3 = goal.origin - pivot
		if from_offset.length() > 0.5 and to_offset.length() > 0.5:
			var direction: Vector3 = from_offset.normalized().slerp(to_offset.normalized(), w)
			blended.origin = pivot + direction * lerpf(from_offset.length(), to_offset.length(), w)
			blended.origin.y = maxf(blended.origin.y, Vector3(show.o).y + 0.25)
		camera.global_transform = blended
		camera.fov = lerpf(_camera_fov, fov, w)
	else:
		camera.global_transform = goal
		camera.fov = fov
	var rig = world.get("camera_rig")
	if rig != null and float(rig.trauma) > 0.0:
		_shake = clampf(_shake + float(rig.trauma) * 0.5, 0.0, 1.0)
		rig.trauma = 0.0
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.9)
		var amount: float = _shake * _shake * float(world.shake_scale())
		_shake_clock += delta
		var c: float = _shake_clock
		camera.rotate_object_local(Vector3.RIGHT, 0.034 * amount * (sin(c * 41.0) * 0.7 + sin(c * 97.0 + 1.7) * 0.3))
		camera.rotate_object_local(Vector3.UP, 0.026 * amount * (sin(c * 37.0 + 0.5) * 0.7 + sin(c * 83.0 + 2.9) * 0.3))
		camera.rotate_object_local(Vector3.BACK, 0.05 * amount * (sin(c * 29.0 + 1.1) * 0.7 + sin(c * 71.0 + 0.3) * 0.3))
	return true


func _shot_point(show: Dictionary, value: Variant, u: float, holder: PaperVisual, body: PaperVisual) -> Vector3:
	if value is Array and (value as Array).size() == 2 and not (value[0] is String):
		return _shot_point(show, value[0], u, holder, body).lerp(_shot_point(show, value[1], u, holder, body), u)
	if value is Vector3: return _frame_point(show, value)
	if value is Dictionary:
		var spec: Dictionary = value
		var who: PaperVisual = holder if str(spec.get("who", "v")) == "a" else body
		var at: Vector3 = who.socket_position(str(spec.get("s", "chest")))
		if spec.has("mix"):
			var other: PaperVisual = body if who == holder else holder
			at = at.lerp(other.socket_position(str(spec.get("s2", spec.get("s", "chest")))), float(spec.mix))
		if spec.has("with"): at = at.lerp(who.socket_position(str(spec.with)), 0.5)
		return at + _frame_vec(show, spec.get("o", Vector3.ZERO))
	return Vector3(show.o)


# Garde la caméra hors des têtes (cheveux volumineux) et des torses.
func _avoid_bodies(eye: Vector3, holder: PaperVisual, body: PaperVisual) -> Vector3:
	for visual: PaperVisual in [holder, body]:
		if visual == null: continue
		var big: float = visual.visual_height() / 1.75
		for entry: Array in [["head", 0.62], ["chest", 0.42], ["hips", 0.36]]:
			var center: Vector3 = visual.socket_position(str(entry[0]))
			var radius: float = float(entry[1]) * big
			var away: Vector3 = eye - center
			if away.length() < radius:
				eye = center + (away.normalized() if away.length_squared() > 0.0001 else Vector3.UP) * radius
	return eye


func _safe_eye(target: Vector3, desired: Vector3) -> Vector3:
	var rig = world.get("camera_rig")
	if rig == null: return desired
	var fraction: float = float(rig.cast_fraction(target, desired))
	if fraction >= 0.999: return desired
	var motion: Vector3 = desired - target
	return target + motion * maxf(0.08, fraction - 0.04 / maxf(motion.length(), 0.01))


# Le plan suit les deux acteurs : contre-jour derrière eux par rapport à la
# caméra, remplissage chaud de son côté, décalés pour modeler les visages.
func _place_lights(eye: Vector3, look: Vector3) -> void :
	var toward: Vector3 = look - eye
	toward.y = 0.0
	toward = toward.normalized() if toward.length_squared() > 0.0001 else Vector3.FORWARD
	var side: Vector3 = toward.cross(Vector3.UP).normalized()
	_rim.global_position = look + toward * 1.9 - side * 1.5 + Vector3.UP * 1.7
	_fill.global_position = look - toward * 2.1 + side * 1.4 + Vector3.UP * 1.0


func _update_lights(delta: float) -> void :
	var wanted: bool = _camera_id >= 0 and not _paused()
	_light_amount = move_toward(_light_amount, 1.0 if wanted else 0.0, delta * 2.6)
	var on: bool = _light_amount > 0.002
	for light: OmniLight3D in [_rim, _fill]:
		if light.visible != on: light.visible = on
	if not on: return
	var k: float = smoothstep(0.0, 1.0, _light_amount)
	_rim.light_energy = 1.35 * k
	_fill.light_energy = 0.7 * k


# Plan d'exécution : les onomatopées génériques du jeu (coup fatal, étourdissement)
# laissent la place à celles de la mise en scène.
func _mute_comic_words(cut: bool) -> void :
	var comic: Node = _comic()
	if comic == null: return
	if float(comic.get("_word_clock")) < 0.1: comic.set("_word_clock", 0.1)
	if not cut: return
	var list: Variant = comic.get("_words")
	if not list is Array: return
	for item: Variant in list:
		if item == null or not bool(item.get("active")): continue
		item.set("active", false)
		var node: Variant = item.get("node")
		if node is Node3D and is_instance_valid(node): (node as Node3D).visible = false


var _guarding: bool = false

# Les effets BD posés pendant le plan restent dans le cadre (comme pendant les films).
func _comic_guard(on: bool) -> void :
	if on == _guarding: return
	_guarding = on
	var comic: Node = _comic()
	if comic == null: return
	# Un film (fin de manche) a pu démarrer entre-temps : il garde la main.
	var film: Variant = world.get("film")
	if not on and film != null and is_instance_valid(film) and not str(film.get("kind")).is_empty(): return
	comic.set("frame_guard", on)


func _update_bars(delta: float) -> void :
	var wanted: bool = _camera_id >= 0 and not bool(world.get("pause_open"))
	_bars_amount = move_toward(_bars_amount, 1.0 if wanted else 0.0, delta * 3.2)
	var visible_now: bool = _bars_amount > 0.002
	var size: Vector2 = get_viewport().get_visible_rect().size
	var height: float = size.y * 0.095 * smoothstep(0.0, 1.0, _bars_amount)
	for i in range(_bars.size()):
		var bar: ColorRect = _bars[i]
		bar.visible = visible_now
		if not visible_now: continue
		bar.position = Vector2(0.0, 0.0 if i == 0 else size.y - height)
		bar.size = Vector2(size.x, height)
	_hud_alpha(1.0 - smoothstep(0.0, 1.0, _bars_amount))
	_mask_game_sign(_camera_id >= 0)


var _hud_dimmed: bool = false
var _sign_masked: bool = false

func _mask_game_sign(on: bool) -> void :
	if on == _sign_masked: return
	var camera: Camera3D = world.camera if world != null else null
	if camera == null: return
	_sign_masked = on
	if on:
		var items: Variant = world.get("map_interactables")
		var sign: Variant = items.get("exit_sign") if is_instance_valid(items) else null
		if sign is VisualInstance3D and is_instance_valid(sign): (sign as VisualInstance3D).layers = SIGN_LAYER
		camera.cull_mask &= ~SIGN_LAYER
	else: camera.cull_mask |= SIGN_LAYER

# Estompe le HUD et les bulles d'info pendant le plan cinématique. N'écrit rien
# hors exécution, pour ne pas contrarier un autre système qui réglerait le HUD.
func _hud_alpha(alpha: float) -> void :
	if alpha >= 1.0 and not _hud_dimmed: return
	_hud_dimmed = alpha < 1.0
	var ui: Variant = world.get("ui") if world != null else null
	if ui == null or not is_instance_valid(ui) or ui.get("hud") == null: return
	var hud: Control = ui.hud
	if not is_equal_approx(hud.modulate.a, alpha): hud.modulate.a = alpha
	var toasts: Variant = ui.get("_toast_box")
	if toasts is Control and is_instance_valid(toasts): (toasts as Control).modulate.a = alpha
	# Mobile : les commandes tactiles s'estompent avec le HUD (sinon joystick et boutons restent par-dessus le plan).
	var touch: Variant = world.get("mobile_controls")
	if touch is Control and is_instance_valid(touch): (touch as Control).modulate.a = alpha




func _show_bonus(seconds: float) -> void :
	if _bonus_time >= 0.0 and _bonus_time < 0.6: seconds += float(_bonus_label.get_meta("seconds", 0.0))
	_bonus_label.set_meta("seconds", seconds)
	var total: int = int(round(seconds))
	_bonus_label.text = "+%d:%02d" % [total / 60, total % 60]
	_bonus_time = 0.0
	_bonus_bell = true
	_bonus_label.visible = _bars_amount <= 0.05
	if _bonus_label.visible: _ring_bonus()


func _ring_bonus() -> void :
	_bonus_bell = false
	if world.audio and world.audio.has_method("sfx") and world.camera.is_inside_tree():
		world.audio.sfx("bell", world.camera.global_position, world.camera.global_position, 0.3, 1.32)


func _update_bonus(delta: float) -> void :
	if _bonus_time < 0.0: return
	# Plan d'exécution sur ce poste : le chrono est masqué avec le HUD. « +0:45 » (et sa cloche) attend
	# la fin des bandes noires pour apparaître près du chrono, au lieu de flotter seul sur la bande du plan.
	if _bonus_bell and str(world.phase) == "playing":
		if _bars_amount > 0.05:
			_bonus_label.visible = false
			return
		_ring_bonus()
	_bonus_time += delta
	var life: float = 2.6
	if _bonus_time >= life or str(world.phase) != "playing":
		_bonus_time = -1.0
		_bonus_bell = false
		_bonus_label.visible = false
		return
	var anchor: Vector2 = Vector2(get_viewport().get_visible_rect().size.x * 0.5 + 92.0, 18.0)
	var ui: Variant = world.get("ui")
	if ui != null and ui.get("_hud") != null and is_instance_valid(ui._hud) and is_instance_valid(ui._hud.timer_label):
		var rect: Rect2 = ui._hud.timer_label.get_global_rect()
		anchor = Vector2(rect.position.x + rect.size.x * 0.5 + 96.0, rect.position.y + 4.0)
	var pop: float = 1.0 + 0.45 * (1.0 - smoothstep(0.0, 0.22, _bonus_time))
	_bonus_label.reset_size()
	_bonus_label.pivot_offset = _bonus_label.size * 0.5
	_bonus_label.scale = Vector2.ONE * pop
	_bonus_label.position = anchor + Vector2(0.0, -14.0 * smoothstep(0.4, life, _bonus_time)) - Vector2(0.0, _bonus_label.size.y * 0.1)
	_bonus_label.modulate.a = smoothstep(0.0, 0.08, _bonus_time) * (1.0 - smoothstep(life - 0.6, life, _bonus_time))
	# en réseau la partie continue derrière le menu pause : le chiffre reste caché tant qu'il est ouvert
	var hidden: bool = bool(world.get("pause_open"))
	if _bonus_label.visible == hidden: _bonus_label.visible = not hidden




func _material(key: String, color: Color) -> Material:
	if not _materials.has(key): _materials[key] = CharMaterials.flat(color)
	return _materials[key]


func _prop(show: Dictionary, key: String) -> Node3D:
	if (show.props as Dictionary).has(key) and is_instance_valid(show.props[key]): return show.props[key]
	var node: Node3D = null
	match key:
		"photo": node = _make_photo()
		"drone": node = _make_drone()
	if node == null: return null
	_props_root.add_child(node)
	_tag(node, true)
	node.visible = false
	show.props[key] = node
	return node


func _place_props(show: Dictionary, t: float, holder: PaperVisual, body: PaperVisual) -> void :
	for track: Dictionary in show.tracks:
		if str(track.k) != "prop": continue
		var node: Node3D = _prop(show, str(track.prop))
		if node == null: continue
		var inside: bool = t >= float(track.t0) and t <= float(track.t1)
		if not inside:
			if bool(track.get("last", false)) and t > float(track.t1): node.visible = false
			continue
		var who: PaperVisual = holder if str(track.who) == "a" else body
		var at: Vector3 = who.socket_position(str(track.socket))
		if track.has("socket2"): at = at.lerp(who.socket_position(str(track.socket2)), 0.5)
		if track.has("blend_to"):
			var other: PaperVisual = holder if str(track.blend_to) == "a" else body
			var mix: float = smoothstep(float(track.t0), float(track.t1), t)
			at = at.lerp(other.socket_position(str(track.get("socket_to", "head"))) + _frame_vec(show, track.get("offset_to", Vector3.ZERO)), mix)
		at += _frame_vec(show, track.get("offset", Vector3.ZERO))
		var basis: Basis
		match str(track.get("face", "eyes")):
			"eyes":
				var normal: Vector3 = (who.socket_position("eyes") - at)
				if normal.length_squared() < 0.0001: normal = -Vector3(show.f)
				basis = Basis.looking_at(normal.normalized(), Vector3.UP)
				basis = basis * Basis(Vector3.RIGHT, deg_to_rad(float(track.get("tilt", 0.0))))
			"forward":
				var direction: Vector3 = Vector3(show.f) if str(track.who) == "v" else -Vector3(show.f)
				basis = Basis.looking_at(direction, Vector3.UP)
			_:
				basis = Basis.IDENTITY
		var spin: float = float(track.get("spin", 0.0))
		if spin != 0.0: basis = basis * Basis(Vector3.FORWARD, spin * t)
		var scale: float = float(track.get("scale", 1.0))
		if not node.visible:
			node.visible = true
			node.global_transform = Transform3D(basis.scaled(Vector3.ONE * scale), at)
			node.reset_physics_interpolation()
		else:
			node.global_transform = Transform3D(basis.scaled(Vector3.ONE * scale), at)
		if node.has_meta("rotors"):
			for rotor: Node3D in node.get_meta("rotors"): rotor.rotation.y += 0.9 * float(track.get("rotor", 1.0))


func _make_photo() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "KillPhoto"
	var image: Image = Image.create(96, 72, false, Image.FORMAT_RGBA8)
	image.fill(Color("f6f1e6"))
	var sky_top: Color = Color("f2b77c")
	var sky_low: Color = Color("ffe2b0")
	for y in range(6, 50):
		var tint: Color = sky_top.lerp(sky_low, float(y - 6) / 44.0)
		for x in range(6, 90): image.set_pixel(x, y, tint)
	for y in range(50, 62):
		for x in range(6, 90): image.set_pixel(x, y, Color("8d6a8c").lerp(Color("5d4466"), float(y - 50) / 12.0))
	image.fill_rect(Rect2i(14, 22, 26, 28), Color("cdb79a"))
	image.fill_rect(Rect2i(18, 16, 18, 8), Color("a3434f"))
	for i in range(4): image.fill_rect(Rect2i(17 + i * 6, 28, 3, 4), Color("4a3b52"))
	_disc(image, Vector2i(74, 16), 6, Color("fff6d8"))
	var people: Array = [[44, Color("f0f0f2"), Color("1a1820")], [56, Color("272231"), Color("1a1820")], [67, Color("efe9f6"), Color("6b4f9a")], [79, Color("2e2a3c"), Color("101015")]]
	for p: Array in people:
		var x: int = int(p[0])
		_disc(image, Vector2i(x, 35), 4, Color("f3d7c0"))
		image.fill_rect(Rect2i(x - 4, 31, 9, 3), p[2])
		image.fill_rect(Rect2i(x - 4, 40, 9, 12), p[1])
		image.fill_rect(Rect2i(x - 3, 52, 3, 8), Color("2a2533"))
		image.fill_rect(Rect2i(x + 1, 52, 3, 8), Color("2a2533"))
	image.fill_rect(Rect2i(55, 31, 3, 2), Color("1a1820"))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var front: StandardMaterial3D = StandardMaterial3D.new()
	front.albedo_texture = texture
	front.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	front.roughness = 0.85
	var back: StandardMaterial3D = StandardMaterial3D.new()
	back.albedo_color = Color("e9e2d2")
	back.roughness = 0.9
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.12, 0.09)
	var face: MeshInstance3D = MeshInstance3D.new()
	face.mesh = quad
	face.material_override = front
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.position = Vector3(0, 0, -0.001)
	face.rotation.y = PI
	root.add_child(face)
	var rear: MeshInstance3D = MeshInstance3D.new()
	rear.mesh = quad
	rear.material_override = back
	rear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rear.position = Vector3(0, 0, 0.001)
	root.add_child(rear)
	return root


func _disc(image: Image, center: Vector2i, radius: int, color: Color) -> void :
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				var p: Vector2i = center + Vector2i(x, y)
				if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height(): image.set_pixelv(p, color)


func _make_drone() -> Node3D:
	var effects: Node = world.presentation
	effects._ensure_entity_meshes()
	var root: Node3D = Node3D.new()
	root.name = "KillDrone"
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = effects._drone_body_mesh
	root.add_child(body)
	var rotors: Array[Node3D] = []
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var rotor: MeshInstance3D = MeshInstance3D.new()
			rotor.mesh = effects._rotor_mesh
			rotor.position = Vector3(x * 0.29, 0.067, z * 0.29)
			root.add_child(rotor)
			rotors.append(rotor)
	root.set_meta("rotors", rotors)
	return root




func _spawn_debris(mesh: Mesh, material: Material, at: Transform3D, velocity: Vector3, spin: Vector3, ground: float, life: float = 24.0, paper: bool = false) -> Node3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	if material != null: node.material_override = material
	_props_root.add_child(node)
	node.layers |= KILL_LAYER
	node.global_transform = at
	node.reset_physics_interpolation()
	_debris.append({"node": node, "vel": velocity, "spin": spin, "ground": ground, "life": life, "age": 0.0, "rest": false, "paper": paper, "scale": at.basis.get_scale()})
	return node


func _update_debris(delta: float) -> void :
	for i in range(_debris.size() - 1, -1, -1):
		var entry: Dictionary = _debris[i]
		var node: Node3D = entry.node
		if not is_instance_valid(node):
			_debris.remove_at(i)
			continue
		entry.age = float(entry.age) + delta
		if float(entry.age) > float(entry.life):
			var shrink: float = clampf(1.0 - (float(entry.age) - float(entry.life)) / 0.6, 0.0, 1.0)
			if shrink <= 0.0:
				node.queue_free()
				_debris.remove_at(i)
				continue
			node.scale = Vector3(entry.scale) * shrink
		if bool(entry.rest): continue
		var velocity: Vector3 = entry.vel
		var paper: bool = bool(entry.paper)
		if paper:
			velocity.y = maxf(velocity.y - 3.0 * delta, -0.75)
			velocity.x += sin(float(entry.age) * 7.0) * 1.4 * delta
			velocity.x *= 1.0 - delta * 1.5
			velocity.z *= 1.0 - delta * 1.5
		else:
			velocity.y -= 11.0 * delta
		var position: Vector3 = node.global_position + velocity * delta
		var floor_y: float = float(entry.ground) + (0.006 if paper else 0.03)
		var spin: Vector3 = entry.spin
		if position.y <= floor_y:
			position.y = floor_y
			if paper or absf(velocity.y) < 1.2:
				velocity = Vector3.ZERO
				entry.rest = true
				var flat: Basis = Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, -PI * 0.5)
				if paper: node.global_transform = Transform3D(flat.scaled(Vector3(entry.scale)), position)
			else:
				velocity = Vector3(velocity.x * 0.55, -velocity.y * 0.32, velocity.z * 0.55)
				spin *= 0.5
		entry.vel = velocity
		entry.spin = spin
		if not bool(entry.rest) or not paper:
			node.global_position = position
			if not bool(entry.rest): node.rotate(spin.normalized() if spin.length_squared() > 0.0001 else Vector3.UP, spin.length() * delta)




func _rip_limb(show: Dictionary, victim: PaperActor, bone_name: String, throw: Vector3) -> void :
	if victim == null or not is_instance_valid(victim.visual) or not is_instance_valid(victim.visual._imported): return
	var imported: PaperImportedCharacter = victim.visual._imported
	var skeleton: Skeleton3D = imported.skeleton
	var bone: int = skeleton.find_bone(bone_name)
	if bone < 0: return
	var limb: Dictionary = _limb_mesh(victim.character, imported, bone)
	if not limb.is_empty():
		var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone) * Transform3D(limb.bind)
		var piece: Node3D = _spawn_debris(limb.mesh, limb.material, pose, throw + Vector3.UP * 2.2, Vector3(randf_range(-6, 6), randf_range(-9, 9), randf_range(-6, 6)), Vector3(show.spot).y, 26.0)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var trail_comic: Node = _comic()
		if trail_comic: trail_comic.trail(piece, "", Color("c9b6ff", 0.85), 0.55, 0.16, 0.22)
	skeleton.set_bone_pose_scale(bone, Vector3.ONE * 0.001)
	(show.bones as Array).append(bone)
	_wrecked[victim.id] = {"actor": victim, "bones": (show.bones as Array).duplicate(), "hidden": false}
	var socket: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	var comic: Node = _comic()
	world.presentation._emit(world.presentation.KIT_SPARK, socket, Vector3.UP + throw.normalized(), Color("ffe9a8"), false, 1.6, 140.0)
	world.presentation._emit(world.presentation.KIT_SCRAP, socket, throw.normalized() + Vector3.UP, Color("9a8ab0"), false, 1.0, 80.0)
	if comic:
		comic.bolts(socket, Color("bff6ff"), 4, 0.35, 0.7)
		comic.pop(socket, throw.normalized(), Color("c9b6ff"), 0.5)


func _limb_mesh(person: String, imported: PaperImportedCharacter, bone: int) -> Dictionary:
	var key: String = person + "#" + str(bone)
	if _limb_cache.has(key): return _limb_cache[key]
	var result: Dictionary = {}
	var skeleton: Skeleton3D = imported.skeleton
	var source: MeshInstance3D = null
	for mesh_node: MeshInstance3D in imported.meshes:
		if mesh_node.skin != null and mesh_node.mesh != null:
			source = mesh_node
			break
	if source == null:
		_limb_cache[key] = result
		return result
	var inside: Dictionary = {}
	for i in range(skeleton.get_bone_count()):
		var walk: int = i
		while walk >= 0:
			if walk == bone:
				inside[i] = true
				break
			walk = skeleton.get_bone_parent(walk)
	var skin: Skin = source.skin
	var bind_inside: PackedByteArray = PackedByteArray()
	bind_inside.resize(skin.get_bind_count())
	var bind_of_bone: int = -1
	for b in range(skin.get_bind_count()):
		var bone_index: int = skin.get_bind_bone(b)
		if bone_index < 0: bone_index = skeleton.find_bone(skin.get_bind_name(b))
		bind_inside[b] = 1 if inside.has(bone_index) else 0
		if bone_index == bone: bind_of_bone = b
	if bind_of_bone < 0:
		_limb_cache[key] = result
		return result
	var arrays: Array = source.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var per: int = 8 if bones.size() >= verts.size() * 8 else 4
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(verts.size())
	for v in range(verts.size()):
		var share: float = 0.0
		for k in range(per):
			var b: int = bones[v * per + k]
			if b >= 0 and b < bind_inside.size() and bind_inside[b] == 1: share += weights[v * per + k]
		keep[v] = 1 if share >= 0.5 else 0
	var bind: Transform3D = skin.get_bind_pose(bind_of_bone)
	var inverse_bind: Transform3D = bind
	var remap: Dictionary = {}
	var out_v: PackedVector3Array = PackedVector3Array()
	var out_n: PackedVector3Array = PackedVector3Array()
	var out_uv: PackedVector2Array = PackedVector2Array()
	var out_i: PackedInt32Array = PackedInt32Array()
	var count: int = indices.size() if not indices.is_empty() else verts.size()
	for tri in range(0, count - 2, 3):
		var a: int = indices[tri] if not indices.is_empty() else tri
		var b2: int = indices[tri + 1] if not indices.is_empty() else tri + 1
		var c: int = indices[tri + 2] if not indices.is_empty() else tri + 2
		if keep[a] == 0 or keep[b2] == 0 or keep[c] == 0: continue
		for v: int in [a, b2, c]:
			if not remap.has(v):
				remap[v] = out_v.size()
				out_v.append(inverse_bind * verts[v])
				if not normals.is_empty(): out_n.append((inverse_bind.basis * normals[v]).normalized())
				if not uvs.is_empty(): out_uv.append(uvs[v])
			out_i.append(int(remap[v]))
	if out_i.size() < 12:
		_limb_cache[key] = result
		return result
	var new_arrays: Array = []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX] = out_v
	if out_n.size() == out_v.size(): new_arrays[Mesh.ARRAY_NORMAL] = out_n
	if out_uv.size() == out_v.size(): new_arrays[Mesh.ARRAY_TEX_UV] = out_uv
	new_arrays[Mesh.ARRAY_INDEX] = out_i
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
	var material: Material = source.material_override if source.material_override != null else source.get_active_material(0)
	result = {"mesh": mesh, "material": material, "bind": Transform3D.IDENTITY}
	_limb_cache[key] = result
	return result


func _wreck_lysia(show: Dictionary) -> void :
	var victim: PaperActor = world.actors.get(int(show.victim))
	if victim == null or not is_instance_valid(victim.visual): return
	var visual: PaperVisual = victim.visual
	var at: Vector3 = visual.socket_position("chest")
	var ground: float = Vector3(show.spot).y
	if is_instance_valid(visual._imported): visual._imported.visible = false
	if is_instance_valid(visual._plug_tail): visual._plug_tail.visible = false
	if is_instance_valid(visual._blob): visual._blob.visible = false
	var entry: Dictionary = _wrecked.get(victim.id, {"actor": victim, "bones": []})
	entry["hidden"] = true
	_wrecked[victim.id] = entry
	var plate: BoxMesh = BoxMesh.new()
	plate.size = Vector3(0.16, 0.025, 0.11)
	var gear: CylinderMesh = CylinderMesh.new()
	gear.top_radius = 0.06
	gear.bottom_radius = 0.06
	gear.height = 0.022
	gear.radial_segments = 8
	gear.rings = 1
	var spring: TorusMesh = TorusMesh.new()
	spring.inner_radius = 0.03
	spring.outer_radius = 0.045
	var cloth: BoxMesh = BoxMesh.new()
	cloth.size = Vector3(0.2, 0.01, 0.16)
	var parts: Array = [[plate, _material("lysia_plate", Color("2b2238"))], [plate, _material("lysia_white", Color("e8e2f0"))], [gear, _material("lysia_metal", Color("a9aebb"))], [spring, _material("lysia_brass", Color("d1a35c"))], [cloth, _material("lysia_cloth", Color("3a2b55"))], [gear, _material("lysia_dark", Color("4b4458"))]]
	var count: int = 9 if world.presentation._low_profile() else 18
	for k in range(count):
		var part: Array = parts[k % parts.size()]
		var direction: Vector3 = Vector3(randf_range(-1, 1), randf_range(0.3, 1.2), randf_range(-1, 1)).normalized()
		var basis: Basis = Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
		_spawn_debris(part[0], part[1], Transform3D(basis, at + direction * 0.15), direction * randf_range(3.0, 6.5), Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12)), ground, randf_range(18.0, 26.0))
	var comic: Node = _comic()
	if comic:
		comic.mark(comic.BURST, at, Color("ffd68a", 0.95), 1.0, 4.2, 0.36, {"pop": 0.4, "ink": Color("5a2a12"), "fade": 0.4})
		if not world.presentation._flashes_reduced(): comic.mark(comic.RAYS, at, Color("fff1c4", 0.75), 2.0, 7.0, 0.5, {"add": true, "fade": 0.25})
		comic.ink_puffs(at, 7, 4.0, Color("7a3a1a"))
		comic.crack(Vector3(at.x, ground, at.z), 2.6)
		comic.dust_ring(Vector3(at.x, ground, at.z), 2.2)
		comic.mark(comic.PUDDLE, Vector3(at.x, ground + 0.03, at.z), Color("1c0f24", 0.85), 1.4, 2.8, 6.0, {"normal": Vector3.UP, "angle": randf() * TAU, "fade": 0.8})
	world.presentation._emit(world.presentation.KIT_EMBER, at, Vector3.UP, Color("ffb35c"), false, 2.0)
	world.presentation._emit(world.presentation.KIT_SPARK, at, Vector3.UP, Color("fff2a8"), false, 2.2, 180.0)
	world.presentation._emit(world.presentation.KIT_SMOKE, at + Vector3.UP * 0.3, Vector3.UP, Color("796879"), false)
	# Repère de jeu de l'explosion habituelle : l'onde montre la portée de l'étourdissement.
	world.presentation.shock_ring(Vector3(at.x, ground + 0.12, at.z), Color("c99b79"), Vector3.UP, LYSIA_RADIUS)
	if not _involved(show):
		var screen: Node = _screen()
		if screen != null and world.camera.is_inside_tree() and world.camera.global_position.distance_to(at) < 16.0:
			screen.impact(0.8, false)
			screen.pulse(Color(1.0, 0.55, 0.2, 0.34), 0.6)
	_word("boom", at + Vector3.UP * 0.6, Color("ffd68a"), 1.6)
	_sound("kill_boom", at, 1.1, 1.0)
	_sound("ground_impact", at, 0.6, 0.7)


func _restore_wrecks(force: bool) -> void :
	for id: Variant in _wrecked.keys():
		var entry: Dictionary = _wrecked[id]
		var actor: PaperActor = entry.get("actor")
		var gone: bool = not is_instance_valid(actor)
		if not gone and not force and (not actor.alive or bool(actor.effects.get("dying", false))): continue
		if not gone and is_instance_valid(actor.visual):
			var visual: PaperVisual = actor.visual
			if is_instance_valid(visual._imported):
				visual._imported.visible = true
				var skeleton: Skeleton3D = visual._imported.skeleton
				for bone: Variant in entry.get("bones", []):
					if int(bone) >= 0 and int(bone) < skeleton.get_bone_count(): skeleton.set_bone_pose_scale(int(bone), Vector3.ONE)
			if is_instance_valid(visual._plug_tail): visual._plug_tail.visible = true
		_wrecked.erase(id)


func _drop_gun(show: Dictionary, victim: PaperActor) -> void :
	if victim == null or not is_instance_valid(victim.visual): return
	var info: Dictionary = CharProps.prop("shotgun")
	if info.is_empty(): return
	var visual: PaperVisual = victim.visual
	var at: Transform3D = Transform3D(Basis.looking_at(-Vector3(show.f) + Vector3(show.r) * 0.4, Vector3.UP).scaled(Vector3.ONE * visual._model_scale), visual.socket_position("hand_r"))
	var props: Dictionary = visual.get("_props")
	if props.has("shotgun") and is_instance_valid(props.shotgun) and (props.shotgun as Node3D).is_inside_tree(): at = (props.shotgun as Node3D).global_transform
	var gun: Node3D = _spawn_debris(info.mesh, null, at, -Vector3(show.r) * 3.2 + Vector3.UP * 2.6 - Vector3(show.f) * 0.6, Vector3(2.0, 11.0, 4.0), Vector3(show.spot).y, 30.0)
	gun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _drop_photo(show: Dictionary) -> void :
	var node: Node3D = (show.props as Dictionary).get("photo")
	if not is_instance_valid(node) or not node.visible: return
	var transform: Transform3D = node.global_transform
	node.visible = false
	var copy: Node3D = _make_photo()
	_props_root.add_child(copy)
	_tag(copy, true)
	copy.global_transform = transform
	copy.reset_physics_interpolation()
	_debris.append({"node": copy, "vel": -Vector3(show.f) * 0.35 + Vector3(show.r) * 0.25 + Vector3.UP * 0.4, "spin": Vector3(1.5, 2.5, 0.8), "ground": Vector3(show.spot).y, "life": 40.0, "age": 0.0, "rest": false, "paper": true, "scale": transform.basis.get_scale()})


func _burst_drone(show: Dictionary, holder: PaperVisual) -> void :
	var node: Node3D = (show.props as Dictionary).get("drone")
	var at: Vector3 = node.global_position if is_instance_valid(node) else holder.socket_position("hand_r")
	var ground: float = Vector3(show.spot).y
	if is_instance_valid(node): node.visible = false
	var effects: Node = world.presentation
	effects._ensure_entity_meshes()
	var shell: Material = null
	for k in range(5):
		var direction: Vector3 = (Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)) - Vector3(show.f) * 0.8).normalized()
		_spawn_debris(effects._rotor_mesh, shell, Transform3D(Basis.from_euler(Vector3(randf(), randf(), randf()) * TAU), at), direction * randf_range(2.5, 5.5), Vector3(randf_range(-20, 20), randf_range(-30, 30), randf_range(-20, 20)), ground, 22.0)
	var hull: Node3D = _spawn_debris(effects._drone_body_mesh, null, Transform3D(Basis.from_euler(Vector3(0.6, 0.3, 1.1)).scaled(Vector3.ONE * 0.5), at), -Vector3(show.f) * 1.6 + Vector3(show.r) * 1.2 + Vector3.UP * 2.2, Vector3(6.0, 4.0, 9.0), ground, 22.0)
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	effects._emit(effects.KIT_SPARK, at, Vector3.UP - Vector3(show.f), Color("fff2a8"), false, 2.0, 150.0)
	effects._emit(effects.KIT_SCRAP, at, Vector3.UP, Color("8f7ad6"), false, 1.2, 120.0)
	var comic: Node = _comic()
	if comic:
		comic.bolts(at, Color("c6b5f9"), 5, 0.4, 0.8)
		comic.mark(comic.BURST, at, Color("d9c8ff", 0.95), 0.4, 1.9, 0.24, {"pop": 0.5, "ink": Color("2a1f4a")})
		comic.mark(comic.LINES, at, Color("fff6e4", 0.9), 1.2, 2.8, 0.3, {"add": true, "fade": 0.3})




func _script_usayuko(show: Dictionary) -> void :
	var cues: Array = show.cues
	var tracks: Array = show.tracks
	tracks.append({"k": "slow", "t0": 0.6, "t1": 1.2, "w": 0.34, "rate": 0.5})
	var shots: Array = show.shots
	var half: float = float(show.gap) * 0.5
	tracks.append({"k": "reach", "who": "v", "side": 1, "to": "a", "socket": "eyes", "offset": Vector3(0.09, -0.05, -0.04), "t0": 0.38, "t1": 0.7, "in": 0.06, "out": 0.14})
	tracks.append({"k": "reach", "who": "a", "side": -1, "to": "v", "socket": "chest", "offset": Vector3(0.0, 0.13, 0.11), "t0": 1.24, "t1": 1.95, "in": 0.14, "out": 0.12})
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "v", "socket": "chest", "offset": Vector3(0.0, 0.05, 0.12), "t0": 1.75, "t1": 1.95, "in": 0.05, "out": 0.1, "w": 0.65})
	cues.append([0.48, "word", "punch", "a", "head", Vector3(0.32, 0.12, 0.0), Color("ffe7b0"), 1.15])
	cues.append([0.48, "pop", "a", "eyes", Vector3(0.1, 0.0, -0.05), Vector3(-0.4, 0.2, 1.0), Color("ffd98a"), 1.2])
	cues.append([0.48, "sfx", "kill_punch", 1.0, 1.0])
	cues.append([0.48, "sfx", "hit", 0.55, 0.8])
	cues.append([0.48, "shake", 0.55])
	cues.append([0.48, "screen", "impact", 0.75])
	cues.append([0.48, "hitstop", 0.12])
	cues.append([1.06, "exclaim", "v", Color("ffe066")])
	cues.append([1.2, "sweat", "v", 3])
	cues.append([1.3, "sfx", "grab", 0.8, 0.9])
	cues.append([1.6, "sfx", "slash", 0.35, 1.3])
	cues.append([1.82, "claw", "chest", 0.9])
	cues.append([1.82, "word", "slash", "v", "chest", Vector3(-0.3, 0.45, 0.0), Color("ff8aa0"), 1.3])
	cues.append([1.82, "sfx", "kill_stab", 1.0, 0.95])
	cues.append([1.82, "sfx", "slash", 0.6, 0.82])
	cues.append([1.82, "shake", 0.75])
	cues.append([1.82, "screen", "impact", 1.0])
	cues.append([1.82, "screen", "frame", Color(1.0, 0.25, 0.35, 0.22), 0.09])
	cues.append([1.82, "hitstop", 0.1])
	cues.append([2.62, "sfx", "ground_impact", 0.45, 1.1])
	cues.append([3.16, "sfx", "ground_impact", 0.85, 0.8])
	cues.append([3.16, "shake", 0.25])
	shots.append([-1.0, {"eye": [Vector3(2.0, 1.45, -half - 0.85), Vector3(1.85, 1.45, -half - 0.7)], "look": {"who": "a", "s": "eyes", "o": Vector3(0, -0.12, 0)}, "fov": [44.0, 40.0]}])
	shots.append([0.42, {"eye": [Vector3(2.25, 1.4, 0.2), Vector3(2.1, 1.42, 0.25)], "look": {"who": "a", "s": "eyes", "mix": 0.5, "o": Vector3(0, -0.1, 0)}, "fov": [38.0, 35.0], "ease": "out"}])
	shots.append([0.66, {"eye": [Vector3(-1.05, 1.55, 0.05), Vector3(-0.85, 1.6, -0.1)], "look": {"who": "a", "s": "eyes", "o": Vector3(0, -0.08, 0)}, "fov": [36.0, 32.0]}])
	shots.append([1.25, {"eye": [Vector3(2.3, 0.6, 0.15), Vector3(2.15, 0.65, 0.35)], "look": Vector3(0, 1.25, 0.05), "fov": 50.0}])
	shots.append([1.9, {"eye": [Vector3(-0.75, 1.75, half + 1.1), Vector3(-0.85, 1.85, half + 1.3)], "look": {"who": "v", "s": "chest"}, "fov": 46.0}])
	shots.append([2.55, {"eye": [Vector3(1.8, 2.6, -half - 1.3), Vector3(1.5, 3.0, -half - 1.8)], "look": {"who": "v", "s": "hips"}, "fov": 48.0}])


func _script_elly(show: Dictionary) -> void :
	var cues: Array = show.cues
	var tracks: Array = show.tracks
	tracks.append({"k": "slow", "t0": 0.55, "t1": 1.55, "w": 0.32, "rate": 0.65})
	var shots: Array = show.shots
	var half: float = float(show.gap) * 0.5
	tracks.append({"k": "reach", "who": "a", "side": -1, "to": "v", "socket": "hand_l", "offset": Vector3(0.0, 0.03, 0.3), "t0": 1.48, "t1": 1.66, "in": 0.06, "out": 0.06})
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "v", "socket": "hips", "offset": Vector3(0.0, 0.24, 0.12), "t0": 1.9, "t1": 2.5, "in": 0.07, "out": 0.12})
	tracks.append({"k": "reach", "who": "v", "side": 1, "to": "a", "socket": "hand_r", "offset": Vector3(0.0, 0.02, 0.1), "t0": 2.0, "t1": 2.46, "in": 0.08, "out": 0.12, "w": 0.7})
	tracks.append({"k": "reach", "who": "v", "side": -1, "to": "a", "socket": "hand_r", "offset": Vector3(0.05, 0.06, 0.18), "t0": 2.02, "t1": 2.46, "in": 0.08, "out": 0.12, "w": 0.7})
	cues.append([0.36, "sfx", "camera_switch", 0.8, 0.75])
	cues.append([0.9, "sweat", "v", 3])
	# Devant elle, côté Alice : en gros plan, le mot ne doit pas masquer son visage.
	cues.append([1.05, "word", "doubt", "v", "over", Vector3(0.0, 0.12, 0.42), Color("bfe9ff"), 0.7])
	cues.append([1.2, "tear", 1])
	cues.append([1.4, "sweat", "v", 2])
	cues.append([1.6, "word", "clang", "v", "hand_l", Vector3(0.2, 0.35, 0.25), Color("e9eef7"), 1.1])
	cues.append([1.6, "pop", "v", "hand_l", Vector3(0.0, 0.05, 0.3), Vector3(1.0, 0.3, 0.0), Color("e9eef7"), 1.0])
	cues.append([1.6, "sfx", "kill_clang", 1.0, 1.0])
	cues.append([1.6, "shake", 0.35])
	cues.append([1.61, "drop_gun"])
	cues.append([1.62, "exclaim", "v", Color("ffe066")])
	cues.append([1.97, "stab", "hips"])
	cues.append([1.97, "word", "stab", "v", "chest", Vector3(-0.35, 0.4, 0.0), Color("ff8aa0"), 1.3])
	cues.append([1.97, "sfx", "kill_stab", 1.0, 0.9])
	cues.append([1.97, "sfx", "slash", 0.6, 0.7])
	cues.append([1.97, "shake", 0.7])
	cues.append([1.97, "screen", "impact", 1.0])
	cues.append([1.97, "screen", "frame", Color(1.0, 0.25, 0.35, 0.22), 0.09])
	cues.append([1.97, "hitstop", 0.14])
	cues.append([2.25, "tear", 2])
	cues.append([2.46, "fx", "a", "ink_burst"])
	cues.append([2.46, "sfx", "slash", 0.5, 1.2])
	cues.append([2.9, "sfx", "ground_impact", 0.45, 1.15])
	cues.append([3.5, "sfx", "ground_impact", 0.85, 0.8])
	cues.append([3.5, "shake", 0.25])
	shots.append([-1.0, {"eye": [Vector3(-0.55, 1.65, half + 0.95), Vector3(-0.5, 1.6, half + 0.8)], "look": {"who": "v", "s": "eyes", "o": Vector3(0, -0.1, 0)}, "fov": [42.0, 38.0]}])
	shots.append([0.5, {"eye": [Vector3(-1.15, 1.55, -0.05), Vector3(-1.0, 1.55, -0.15)], "look": {"who": "v", "s": "eyes", "o": Vector3(0, -0.1, 0.05)}, "fov": [38.0, 33.0]}])
	shots.append([1.5, {"eye": [Vector3(2.4, 1.1, 0.0), Vector3(2.2, 1.05, 0.1)], "look": Vector3(0, 1.1, 0.0), "fov": 46.0}])
	shots.append([2.38, {"eye": [Vector3(-1.45, 1.15, -0.55), Vector3(-1.35, 1.1, -0.45)], "look": {"who": "v", "s": "chest", "o": Vector3(0, 0.0, 0.15)}, "fov": 42.0}])
	shots.append([3.0, {"eye": [Vector3(1.6, 2.6, -half - 1.3), Vector3(1.3, 3.0, -half - 1.7)], "look": {"who": "v", "s": "hips"}, "fov": 48.0}])


func _script_lysia(show: Dictionary) -> void :
	var cues: Array = show.cues
	var tracks: Array = show.tracks
	tracks.append({"k": "slow", "t0": 0.62, "t1": 1.1, "w": 0.3, "rate": 0.5})
	tracks.append({"k": "slow", "t0": 2.3, "t1": 3.25, "w": 0.3, "rate": 1.0})
	var shots: Array = show.shots
	var half: float = float(show.gap) * 0.5
	tracks.append({"k": "reach", "who": "a", "side": -1, "to": "v", "socket": "hand_r", "t0": 0.08, "t1": 0.78, "in": 0.1, "out": 0.04})
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "v", "socket": "chest", "offset": Vector3(0.12, 0.02, 0.08), "t0": 0.3, "t1": 0.8, "in": 0.12, "out": 0.1, "w": 0.75})
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "v", "socket": "hand_l", "t0": 1.2, "t1": 1.88, "in": 0.12, "out": 0.04})
	tracks.append({"k": "reach", "who": "a", "side": -1, "to": "v", "socket": "chest", "offset": Vector3(-0.12, 0.02, 0.08), "t0": 1.35, "t1": 1.9, "in": 0.12, "out": 0.1, "w": 0.75})
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "v", "socket": "chest", "offset": Vector3(-0.16, 0.12, 0.1), "t0": 2.5, "t1": 3.3, "in": 0.12, "out": 0.0, "w": 0.85})
	tracks.append({"k": "reach", "who": "a", "side": -1, "to": "v", "socket": "chest", "offset": Vector3(0.16, 0.12, 0.1), "t0": 2.5, "t1": 3.3, "in": 0.12, "out": 0.0, "w": 0.85})
	cues.append([0.1, "sfx", "grab", 0.9, 0.85])
	cues.append([0.45, "sparks", "v", "chest", Vector3(0.6, 0.2, 0.0), 0.6])
	cues.append([0.6, "sparks", "v", "chest", Vector3(0.6, 0.2, 0.0), 0.8])
	cues.append([0.6, "sfx", "kill_zap", 0.45, 1.15])
	cues.append([0.76, "rip", "R_Upperarm", Vector3(2.4, 0.0, 1.4)])
	cues.append([0.76, "word", "rip", "v", "chest", Vector3(0.45, 0.45, 0.0), Color("c9b6ff"), 1.3])
	cues.append([0.46, "sfx", "kill_rip", 1.0, 1.0])
	cues.append([0.76, "sfx", "hit", 0.5, 1.2])
	cues.append([0.76, "shake", 0.5])
	cues.append([0.76, "screen", "impact", 0.65, false])
	cues.append([0.76, "hitstop", 0.1])
	cues.append([0.95, "sparks", "v", "chest", Vector3(0.6, 0.1, 0.0), 0.7])
	cues.append([1.1, "sparks", "v", "chest", Vector3(0.6, 0.1, 0.0), 0.5])
	cues.append([1.05, "word", "zap", "v", "head", Vector3(0.35, 0.15, 0.0), Color("bff6ff"), 0.9])
	cues.append([1.02, "sfx", "kill_zap", 0.9, 1.0])
	cues.append([1.22, "sfx", "grab", 0.8, 0.9])
	cues.append([1.86, "rip", "L_Upperarm", Vector3(-2.4, 0.0, 1.4)])
	cues.append([1.86, "word", "rip", "v", "chest", Vector3(-0.45, 0.45, 0.0), Color("c9b6ff"), 1.3])
	cues.append([1.53, "sfx", "kill_rip", 1.0, 0.95])
	cues.append([1.86, "sfx", "hit", 0.5, 1.15])
	cues.append([2.05, "sfx", "kill_zap", 0.7, 0.9])
	cues.append([1.86, "shake", 0.55])
	cues.append([1.86, "screen", "impact", 0.7, false])
	cues.append([1.86, "hitstop", 0.1])
	cues.append([2.02, "sparks", "v", "chest", Vector3(-0.6, 0.1, 0.0), 0.8])
	cues.append([2.1, "sparks", "v", "chest", Vector3(0.6, 0.1, 0.0), 0.6])
	cues.append([2.3, "glow", "v", "chest", Color("ffb35c", 0.55), 0.3, 0.9, 0.5])
	cues.append([2.3, "fx", "v", "steam"])
	cues.append([2.5, "sfx", "kill_beep", 0.8, 1.0])
	cues.append([2.55, "word", "beep", "v", "over", Vector3(0.3, 0.1, 0.0), Color("ffd68a"), 0.95])
	cues.append([2.6, "glow", "v", "chest", Color("ffb35c", 0.7), 0.4, 1.3, 0.4])
	cues.append([2.75, "sfx", "kill_beep", 0.85, 1.06])
	cues.append([2.85, "glow", "v", "chest", Color("ffc070", 0.8), 0.6, 1.6, 0.3])
	cues.append([2.95, "sfx", "kill_beep", 0.9, 1.12])
	cues.append([3.0, "flash", Color(1.0, 0.9, 0.7, 0.16), 0.06])
	cues.append([3.05, "glow", "v", "chest", Color("ffd08a", 0.9), 0.8, 2.0, 0.25])
	cues.append([3.08, "sfx", "kill_beep", 0.95, 1.18])
	cues.append([3.15, "flash", Color(1.0, 0.92, 0.75, 0.22), 0.06])
	cues.append([3.18, "sfx", "kill_beep", 1.0, 1.24])
	cues.append([3.22, "glow", "v", "chest", Color("fff0c0", 1.0), 1.0, 3.0, 0.2])
	cues.append([3.25, "sfx", "kill_beep", 1.05, 1.3])
	cues.append([2.5, "shake", 0.15])
	cues.append([2.9, "shake", 0.2])
	cues.append([3.3, "shake", 1.0])
	cues.append([3.3, "flash", Color(1.0, 0.95, 0.85, 0.65), 0.22])
	cues.append([3.3, "screen", "impact", 1.0, false])
	cues.append([3.3, "screen", "pulse", Color(1.0, 0.55, 0.2, 0.42), 1.0])
	shots.append([-1.0, {"eye": [Vector3(2.1, 1.45, -0.75), Vector3(1.9, 1.4, -0.6)], "look": {"who": "v", "s": "chest", "mix": 0.45, "o": Vector3(0, 0.1, 0)}, "fov": 44.0}])
	shots.append([0.68, {"eye": [Vector3(2.3, 0.75, 0.65), Vector3(2.4, 0.85, 0.85)], "look": Vector3(0.35, 1.15, -0.1), "fov": 50.0, "ease": "out"}])
	shots.append([1.2, {"eye": [Vector3(-0.88, 1.55, half + 0.85), Vector3(-0.8, 1.5, half + 0.74)], "look": {"who": "v", "s": "eyes", "o": Vector3(0, -0.12, 0)}, "fov": 40.0}])
	shots.append([2.0, {"eye": [Vector3(-1.2, 1.35, 0.1), Vector3(-1.05, 1.35, 0.05)], "look": {"who": "v", "s": "eyes", "o": Vector3(0, -0.12, 0)}, "fov": [40.0, 36.0]}])
	shots.append([2.5, {"eye": [Vector3(2.0, 1.2, 0.0), Vector3(1.45, 1.25, 0.0)], "look": Vector3(0, 1.15, 0.0), "fov": [44.0, 38.0]}])
	shots.append([3.3, {"eye": [Vector3(3.2, 2.0, -1.0), Vector3(4.1, 2.7, -1.7)], "look": Vector3(0, 0.9, 0.0), "fov": 55.0, "ease": "out"}])


func _script_simon(show: Dictionary) -> void :
	var cues: Array = show.cues
	var tracks: Array = show.tracks
	tracks.append({"k": "slow", "t0": 1.45, "t1": 2.92, "w": 0.38, "rate": 0.75})
	var shots: Array = show.shots
	var half: float = float(show.gap) * 0.5
	tracks.append({"k": "prop", "prop": "photo", "who": "v", "socket": "hand_r", "offset": Vector3(0.0, 0.05, 0.04), "t0": 1.08, "t1": 1.42, "face": "eyes", "scale": 1.0})
	tracks.append({"k": "prop", "prop": "photo", "who": "v", "socket": "hand_r", "socket2": "hand_l", "offset": Vector3(0.0, 0.06, 0.02), "t0": 1.42, "t1": 2.99, "face": "eyes", "tilt": -12.0, "scale": 1.0, "last": true})
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "v", "socket": "back", "offset": Vector3(0.0, 0.05, 0.0), "t0": 2.9, "t1": 3.08, "in": 0.05, "out": 0.08, "w": 0.6})
	cues.append([0.52, "fx", "v", "dust"])
	cues.append([0.52, "sfx", "ground_impact", 0.45, 1.2])
	cues.append([1.08, "sfx", "grab", 0.45, 1.35])
	cues.append([1.6, "sfx", "presence", 0.55, 0.9])
	cues.append([1.85, "tear", 2])
	cues.append([2.35, "tear", 1])
	cues.append([2.72, "sfx", "slash", 0.3, 1.4])
	cues.append([2.99, "claw", "back", 1.1])
	cues.append([2.99, "word", "slash", "v", "head", Vector3(0.4, 0.35, 0.0), Color("ff8aa0"), 1.3])
	cues.append([2.99, "sfx", "kill_stab", 1.0, 0.85])
	cues.append([2.99, "sfx", "slash", 0.6, 0.75])
	cues.append([2.99, "shake", 0.7])
	cues.append([2.99, "screen", "impact", 1.0])
	cues.append([2.99, "screen", "frame", Color(1.0, 0.25, 0.35, 0.22), 0.09])
	cues.append([2.99, "hitstop", 0.12])
	cues.append([3.0, "drop_photo"])
	cues.append([3.42, "sfx", "ground_impact", 0.8, 0.85])
	cues.append([3.42, "shake", 0.2])
	shots.append([-1.0, {"eye": [Vector3(1.6, 1.3, -0.45), Vector3(1.45, 1.2, -0.35)], "look": Vector3(0, 1.0, 0.0), "fov": 44.0}])
	shots.append([0.6, {"eye": [Vector3(-1.55, 1.1, 0.25), Vector3(-1.4, 1.05, 0.2)], "look": {"who": "v", "s": "head", "o": Vector3(0, -0.15, 0)}, "fov": 40.0}])
	shots.append([1.35, {"eye": [{"who": "v", "s": "head", "o": Vector3(0.6, -0.55, 0.75)}, {"who": "v", "s": "head", "o": Vector3(0.52, -0.52, 0.68)}], "look": {"who": "v", "s": "eyes", "o": Vector3(0.0, -0.12, 0.0)}, "fov": [38.0, 35.0]}])
	# Plan subjectif : la photo vue par Simon.
	shots.append([1.95, {"pov": true, "eye": [{"who": "v", "s": "eyes", "o": Vector3(0.0, 0.0, 0.12)}, {"who": "v", "s": "eyes", "o": Vector3(0.0, -0.01, 0.1)}], "look": {"who": "v", "s": "hand_r", "with": "hand_l", "o": Vector3(0.0, 0.06, 0.02)}, "fov": [44.0, 39.0]}])
	shots.append([2.45, {"eye": [Vector3(1.4, 0.45, -half + 0.05), Vector3(1.3, 0.42, -half + 0.1)], "look": {"who": "a", "s": "head", "o": Vector3(0, 0.05, 0)}, "fov": [46.0, 43.0]}])
	shots.append([2.9, {"eye": [Vector3(2.2, 0.9, 0.1), Vector3(2.1, 0.95, 0.2)], "look": Vector3(0, 0.75, -0.2), "fov": 46.0}])
	shots.append([3.5, {"eye": [Vector3(1.6, 2.0, -half - 1.6), Vector3(1.7, 2.3, -half - 1.9)], "look": {"who": "v", "s": "hips"}, "fov": 44.0}])


func _script_ashura(show: Dictionary) -> void :
	var cues: Array = show.cues
	var tracks: Array = show.tracks
	tracks.append({"k": "slow", "t0": 0.66, "t1": 1.34, "w": 0.3, "rate": 0.5})
	var shots: Array = show.shots
	var half: float = float(show.gap) * 0.5
	tracks.append({"k": "reach", "who": "v", "side": 1, "to": "a", "socket": "hand_r", "offset": Vector3(0.0, 0.0, -0.06), "t0": 0.44, "t1": 0.7, "in": 0.06, "out": 0.1})
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "v", "socket": "eyes", "offset": Vector3(0.0, -0.03, 0.16), "t0": 1.36, "t1": 1.62, "in": 0.08, "out": 0.12})
	tracks.append({"k": "prop", "prop": "drone", "who": "v", "socket": "hand_r", "offset": Vector3(0.0, 0.04, 0.06), "t0": -1.0, "t1": 0.62, "face": "forward", "scale": 0.75, "rotor": 1.0})
	tracks.append({"k": "prop", "prop": "drone", "who": "a", "socket": "hand_r", "offset": Vector3(0.0, 0.05, -0.08), "t0": 0.62, "t1": 1.52, "face": "forward", "scale": 0.75, "rotor": 0.35, "last": true})
	cues.append([0.0, "sfx", "camera_place", 0.6, 1.0])
	cues.append([0.46, "sfx", "boost", 0.6, 1.2])
	cues.append([0.62, "word", "catch", "a", "hand_r", Vector3(-0.3, 0.3, 0.0), Color("e6dcff"), 1.1])
	cues.append([0.62, "pop", "a", "hand_r", Vector3(0.0, 0.0, -0.08), Vector3(0.0, 0.3, -1.0), Color("c6b5f9"), 0.9])
	cues.append([0.62, "sfx", "grab", 0.9, 0.85])
	cues.append([0.62, "sfx", "grenade_bounce", 0.7, 0.8])
	cues.append([0.62, "shake", 0.35])
	cues.append([0.62, "hitstop", 0.1])
	cues.append([0.9, "sparks", "a", "hand_r", Vector3.ZERO, 0.8])
	cues.append([1.0, "sfx", "camera_switch", 0.5, 0.7])
	cues.append([1.12, "sparks", "a", "hand_r", Vector3.ZERO, 0.6])
	cues.append([1.15, "exclaim", "v", Color("ffe066")])
	cues.append([1.25, "sweat", "v", 3])
	cues.append([1.52, "drone_burst"])
	cues.append([1.52, "word", "crunch", "v", "head", Vector3(0.35, 0.3, 0.0), Color("e6dcff"), 1.35])
	cues.append([1.52, "sfx", "kill_crunch", 1.0, 1.0])
	cues.append([1.52, "sfx", "punch", 0.6, 0.75])
	cues.append([1.52, "shake", 0.85])
	cues.append([1.52, "screen", "impact", 1.0, false])
	cues.append([1.52, "screen", "frame", Color(1.0, 1.0, 1.0, 0.25), 0.07])
	cues.append([1.52, "hitstop", 0.12])
	cues.append([2.16, "sfx", "ground_impact", 0.9, 0.8])
	cues.append([2.16, "shake", 0.3])
	shots.append([-1.0, {"eye": [Vector3(0.6, 1.6, half + 0.9), Vector3(0.55, 1.55, half + 0.8)], "look": {"who": "v", "s": "chest", "o": Vector3(0, 0.1, 0)}, "fov": 44.0}])
	shots.append([0.55, {"eye": [Vector3(1.5, 1.45, 0.15), Vector3(1.3, 1.45, 0.1)], "look": {"who": "a", "s": "hand_r"}, "fov": [36.0, 32.0], "ease": "out"}])
	shots.append([1.35, {"eye": [Vector3(1.15, 1.3, half + 0.05), Vector3(1.2, 1.28, half + 0.15)], "look": {"who": "v", "s": "eyes", "o": Vector3(0, -0.1, 0)}, "fov": 44.0}])
	shots.append([1.9, {"eye": [Vector3(1.7, 2.6, -half - 1.4), Vector3(1.4, 3.0, -half - 1.8)], "look": {"who": "v", "s": "hips"}, "fov": 50.0}])


func _script_bleuette(show: Dictionary) -> void :
	var cues: Array = show.cues
	var tracks: Array = show.tracks
	tracks.append({"k": "slow", "t0": 0.45, "t1": 1.95, "w": 0.34, "rate": 0.75})
	var shots: Array = show.shots
	tracks.append({"k": "reach", "who": "a", "side": -1, "to": "v", "socket": "chest", "offset": Vector3(0.0, 0.1, 0.1), "t0": 0.0, "t1": 0.34, "in": 0.08, "out": 0.12})
	tracks.append({"k": "attach", "socket": "chest", "from": "hand_l", "offset": Vector3(0.0, -0.13, -0.15), "t0": 0.22, "t1": 2.42, "in": 0.15, "out": 0.2})
	tracks.append({"k": "reach", "who": "v", "side": 1, "to": "a", "socket": "hand_l", "offset": Vector3(0.03, -0.06, 0.0), "t0": 0.3, "t1": 2.2, "in": 0.12, "out": 0.12, "w": 0.8})
	tracks.append({"k": "reach", "who": "v", "side": -1, "to": "a", "socket": "hand_l", "offset": Vector3(-0.03, -0.1, 0.0), "t0": 0.32, "t1": 2.2, "in": 0.12, "out": 0.12, "w": 0.8})
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "v", "socket": "chest", "offset": Vector3(0.0, 0.0, 0.05), "t0": 1.96, "t1": 2.25, "in": 0.06, "out": 0.1})
	cues.append([0.02, "word", "gasp", "v", "head", Vector3(-0.3, 0.25, 0.0), Color("bfe9ff"), 0.9])
	cues.append([0.05, "sfx", "grab", 0.6, 1.2])
	cues.append([0.25, "sfx", "grab", 0.9, 0.9])
	cues.append([0.25, "shake", 0.3])
	cues.append([0.6, "sweat", "v", 3])
	cues.append([0.9, "tear", 2])
	cues.append([1.3, "sweat", "v", 2])
	cues.append([1.5, "tear", 2])
	cues.append([1.85, "sfx", "slash", 0.3, 1.4])
	cues.append([2.05, "stab", "chest"])
	cues.append([2.05, "word", "stab", "v", "head", Vector3(0.35, 0.35, 0.0), Color("ff8aa0"), 1.3])
	cues.append([2.05, "sfx", "kill_stab", 1.0, 1.0])
	cues.append([2.05, "sfx", "slash", 0.6, 0.7])
	cues.append([2.05, "shake", 0.7])
	cues.append([2.05, "screen", "impact", 1.0])
	cues.append([2.05, "screen", "frame", Color(1.0, 0.25, 0.35, 0.22), 0.09])
	cues.append([2.05, "hitstop", 0.12])
	cues.append([2.5, "sfx", "ground_impact", 0.45, 1.2])
	cues.append([3.1, "sfx", "ground_impact", 0.75, 0.85])
	cues.append([3.1, "shake", 0.2])
	shots.append([-1.0, {"eye": [Vector3(1.9, 1.3, 0.1), Vector3(1.75, 1.3, 0.15)], "look": Vector3(0, 1.25, 0.0), "fov": 44.0}])
	# Terreur : son visage de trois-quarts face, un peu en contre-plongée (par-dessus
	# l'épaule d'Alice, sa frange et les cheveux d'Alice le cachaient), puis plus bas,
	# la larme et la main d'Alice qui la tient.
	shots.append([0.35, {"eye": [{"who": "v", "s": "eyes", "o": Vector3(0.6, -0.1, 0.55)}, {"who": "v", "s": "eyes", "o": Vector3(0.5, -0.08, 0.48)}], "look": {"who": "v", "s": "eyes", "o": Vector3(0, -0.03, 0)}, "fov": [36.0, 32.0]}])
	shots.append([1.25, {"eye": [{"who": "v", "s": "eyes", "o": Vector3(0.3, -0.5, 0.35)}, {"who": "v", "s": "eyes", "o": Vector3(0.38, -0.46, 0.42)}], "look": {"who": "v", "s": "eyes", "o": Vector3(0, -0.02, 0)}, "fov": [40.0, 37.0]}])
	# Plan large dès 1,58 s (et non 1,95) : ses mains, crispées sur le poignet d'Alice, montaient ensuite
	# devant l'objectif du gros plan et couvraient son visage d'un grand aplat. Le large montre l'élan d'Alice.
	shots.append([1.58, {"eye": [Vector3(1.45, 0.55, -0.75), Vector3(1.35, 0.6, -0.85)], "look": Vector3(0, 1.35, 0.0), "fov": 52.0}])
	shots.append([2.6, {"eye": [Vector3(1.4, 2.5, -1.4), Vector3(1.2, 2.9, -1.8)], "look": {"who": "v", "s": "hips"}, "fov": 48.0}])


func _script_slam(show: Dictionary) -> void :
	var cues: Array = show.cues
	var tracks: Array = show.tracks
	tracks.append({"k": "slow", "t0": 0.6, "t1": 1.0, "w": 0.3, "rate": 0.4})
	var shots: Array = show.shots
	var half: float = float(show.gap) * 0.5
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "v", "socket": "chest", "offset": Vector3(0.0, 0.0, 0.08), "t0": 0.0, "t1": 0.26, "in": 0.1, "out": 0.08})
	tracks.append({"k": "attach", "socket": "chest", "from": "hand_r", "offset": Vector3(0.0, -0.06, 0.0), "t0": 0.16, "t1": 2.3, "in": 0.08, "out": 0.2})
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "rest", "socket": "chest", "offset": Vector3(0.0, 0.1, 0.0), "t0": 1.0, "t1": 1.24, "in": 0.08, "out": 0.08})
	tracks.append({"k": "reach", "who": "a", "side": 1, "to": "rest", "socket": "chest", "offset": Vector3(0.0, 0.1, 0.0), "t0": 1.62, "t1": 2.3, "in": 0.08, "out": 0.18})
	tracks.append({"k": "reach", "who": "v", "side": 1, "to": "a", "socket": "hand_r", "offset": Vector3(0.06, 0.04, 0.0), "t0": 0.25, "t1": 0.95, "in": 0.1, "out": 0.1, "w": 0.7})
	tracks.append({"k": "reach", "who": "v", "side": -1, "to": "a", "socket": "hand_r", "offset": Vector3(-0.06, 0.04, 0.0), "t0": 0.27, "t1": 0.95, "in": 0.1, "out": 0.1, "w": 0.7})
	cues.append([0.18, "sfx", "grab", 1.0, 0.7])
	cues.append([0.18, "shake", 0.3])
	cues.append([0.4, "sweat", "v", 3])
	cues.append([0.78, "word", "roar", "a", "head", Vector3(0.6, 0.3, 0.0), Color("ff4466"), 1.4])
	cues.append([0.78, "sfx", "shadow", 0.9, 0.6])
	cues.append([0.78, "shake", 0.3])
	cues.append([1.14, "crack", Vector3(0.0, 0.0, -half), 2.2, 1.6])
	cues.append([1.14, "word", "slam", "v", "chest", Vector3(0.5, 0.6, 0.0), Color("ffe7b0"), 1.5])
	cues.append([1.14, "sfx", "kill_slam", 1.0, 1.0])
	cues.append([1.14, "sfx", "punch", 0.7, 0.7])
	cues.append([1.14, "shake", 1.0])
	cues.append([1.14, "screen", "impact", 1.0])
	cues.append([1.14, "screen", "frame", Color(1.0, 0.25, 0.35, 0.25), 0.1])
	cues.append([1.14, "hitstop", 0.14])
	cues.append([1.14, "ink", Vector3(0.0, 0.0, -half), 7])
	cues.append([1.77, "crack", Vector3(0.0, 0.0, -half), 3.0, 2.2])
	cues.append([1.77, "word", "slam2", "v", "chest", Vector3(-0.5, 0.7, 0.0), Color("ff8aa0"), 1.6])
	cues.append([1.77, "sfx", "kill_slam", 1.1, 0.88])
	cues.append([1.77, "sfx", "kill_stab", 0.7, 0.75])
	cues.append([1.77, "shake", 1.0])
	cues.append([1.77, "screen", "impact", 1.0])
	cues.append([1.77, "screen", "splash", 2.2])
	cues.append([1.77, "hitstop", 0.16])
	cues.append([1.77, "ink", Vector3(0.0, 0.0, -half)])
	cues.append([2.42, "sfx", "shadow", 0.7, 0.7])
	shots.append([-1.0, {"eye": [Vector3(1.9, 0.8, -half - 1.6), Vector3(1.7, 0.7, -half - 1.4)], "look": {"who": "a", "s": "chest"}, "fov": 52.0}])
	shots.append([0.55, {"eye": [Vector3(1.45, 0.4, -0.2), Vector3(1.5, 0.45, -0.35)], "look": {"who": "a", "s": "hand_r"}, "fov": 54.0, "roll": [4.0, 7.0]}])
	shots.append([1.0, {"eye": [Vector3(2.9, 1.0, -0.25), Vector3(2.7, 1.1, -0.3)], "look": Vector3(0, 0.65, -half * 0.6), "fov": 50.0}])
	shots.append([1.6, {"eye": [Vector3(1.0, 3.6, -1.7), Vector3(1.1, 3.9, -1.9)], "look": Vector3(0, 0.25, -half), "fov": 46.0}])
	shots.append([2.3, {"eye": [Vector3(0.95, 0.6, -half - 1.45), Vector3(1.1, 0.55, -half - 1.6)], "look": {"who": "a", "s": "head"}, "fov": 56.0}])
