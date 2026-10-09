extends Node3D














const SHADER: Shader = preload("res://fx_comic.gdshader")


const BURST: int = 0
const LINES: int = 1
const CRESCENT: int = 2
const SPARKLE: int = 3
const HEART: int = 4
const BOLT: int = 5
const PUFF: int = 6
const DROP: int = 7
const VEIN: int = 8
const SWIRL: int = 9
const STAR: int = 10
const DASHES: int = 11
const STREAK: int = 12
const CRACK: int = 13
const EXCLAIM: int = 14
const PLUS: int = 15
const PUDDLE: int = 16
const NOTE: int = 17
const SMEAR: int = 18
const RAYS: int = 19


const FACE_MIX: int = 0
const FACE_ADD: int = 1
const WORLD_MIX: int = 2
const WORLD_ADD: int = 3
const POOLS: Array[int] = [64, 48, 28, 24]


const KIT_SCRAP: int = 0
const KIT_INK: int = 1
const KIT_SMOKE: int = 2
const KIT_CONFETTI: int = 3
const KIT_SPARK: int = 4
const KIT_EMBER: int = 5

const TRAILS: int = 16
const TRAIL_POINTS: int = 14
const WORDS: int = 6

const RANGE: float = 46.0


const INK_PALETTE: Array[Color] = [
	Color("17101e"), Color("b3304f"), Color("1c0f24"), Color("7a4a10"), Color("1f6a52"), Color("8a2a4a"), Color("ff9a4d"), Color("9db4c4"), 
	Color("7a2a10"), Color("9fb6e0"), Color("2f6a5c"), Color("d4722a"), Color("8a7d68"), Color("6f6a66"), Color("2b1736"), Color("ffffff"), 
]
const INK: Color = Color("17101e")
const PAPER: Color = Color("fff6e4")
const GOLD: Color = Color("ffd24a")
const MINT: Color = Color("8ff0c8")
const BLOOD_INK: Color = Color("b3304f")
const SHADOW: Color = Color("1c0f24")
const TINT: Dictionary = {
	"Ashura": Color("9fe0ee"), "Usayuko": Color("ffd98a"), "Simon": Color("dccbff"), "Lysia": Color("a6f0d8"), 
	"Elly": Color("b9f3f5"), "Bleuette": Color("a9c8ff"), "Alice": Color("ff5a78"), "TrueForm": Color("ff3355"), 
}
const HIT_TINT: Dictionary = {
	"slash": Color("ff5a78"), "shadow": Color("b06cff"), "spike": Color("d86ad0"), "shotgun": Color("ffe6a0"), 
	"pounce": Color("ff3355"), "execution": Color("ff3355"), 
}
const HIT_WORD: Dictionary = {"slash": "slash", "shadow": "slash", "spike": "spike", "shotgun": "gun", "pounce": "slash"}
const DUST: Dictionary = {"school": Color("d9cdb8"), "forest": Color("b8a67c"), "snow": Color("eef4fb")}

const MELEE: Array[String] = ["slash", "punch", "contre", "flash punch", "consommation"]
const CONTACT_TIME: float = 0.1

const WORDS_TEXT: Dictionary = {
	"slash": ["SHLAK !", "SLASH!"], "spike": ["TCHAC !", "STAB!"], "stun": ["BAM !", "BAM!"], "punch": ["PAF !", "POW!"], 
	"block": ["CLANG !", "CLANG!"], "counter": ["VLAN !", "WHAM!"], "miss": ["RATÉ !", "MISS!"], "wall": ["BOUM !", "CRASH!"], 
	"flash": ["FLASH !", "FLASH!"], "boom": ["BOUM !", "BOOM!"], "gun": ["PAN !", "BANG!"], "dash": ["FWOOSH !", "WHOOSH!"], 
	"up": ["DEBOUT !", "GET UP!"], "roar": ["GRRAAH !", "GRRAAH!"], "grab": ["CHOPÉE !", "GOTCHA!"], "zap": ["BZZT !", "BZZT!"], 
	"yum": ["MIAM !", "YUM!"], "go": ["ALLEZ !", "GO!"], "free": ["LIBRE !", "FREE!"], "ouch": ["AÏE !", "OUCH!"], 
	"push": ["DÉGAGE !", "BACK OFF!"], "hot": ["PSHHH !", "TSSSS!"], "break": ["CRAC !", "CRACK!"], "seal": ["SCELLÉE !", "SEALED!"], 
	"down": ["À TERRE !", "DOWN!"], "thorn": ["KRRR !", "KRRR!"], 
}

class Mark:
	var active: bool = false

	var code: float = 0.0
	var seed: float = 0.0
	var age: float = 0.0
	var life: float = 1.0
	var delay: float = 0.0
	var origin: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var gravity: float = 0.0
	var drag: float = 0.0
	var follow: WeakRef = null
	var socket: String = ""
	var offset: Vector3 = Vector3.ZERO
	var size_from: float = 1.0
	var size_to: float = 1.0
	var pop: float = 0.0
	var aspect: Vector2 = Vector2.ONE
	var angle: float = 0.0
	var spin: float = 0.0
	var color: Color = Color.WHITE
	var fade_start: float = 0.6
	var basis: Basis = Basis.IDENTITY
	var world_space: bool = false
	var axis: Vector3 = Vector3.ZERO

class Trail:
	var node: MeshInstance3D
	var mesh: ImmediateMesh
	var active: bool = false
	var source: WeakRef = null
	var socket: String = ""
	var points: Array[Vector3] = []
	var born: Array[float] = []
	var clock: float = 0.0
	var emit_left: float = 0.0
	var span: float = 0.16
	var width: float = 0.14
	var color: Color = Color.WHITE

class Word:
	var node: Label3D
	var active: bool = false
	var age: float = 0.0
	var life: float = 0.7
	var origin: Vector3 = Vector3.ZERO
	var rise: float = 0.5
	var tilt: float = 0.0
	var size: float = 1.0

	var pinned: bool = false
	var pin: Vector3 = Vector3.ZERO

var host: Node3D
var world: Node3D
var _quad: QuadMesh
var _materials: Array[ShaderMaterial] = []
var _meshes: Array[MultiMesh] = []
var _mesh_nodes: Array[MultiMeshInstance3D] = []
var _ink_cache: Dictionary = {}
var _trail_material: StandardMaterial3D
var _pools: Array = [[], [], [], []]
var _trails: Array[Trail] = []
var _words: Array[Word] = []

var frame_guard: bool = false
var _camera_at: Vector3 = Vector3.ZERO
var _camera_ok: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _word_clock: float = 0.0
var _clock: float = 0.0

var _later: Array = []

var _memory: Dictionary = {}

var _casts: Dictionary = {}
var _zone_clock: float = 0.0
var _exit_clock: float = 0.0
var _exit_open: bool = false

func setup(effects: Node3D, owner_world: Node3D) -> void :
	host = effects
	world = owner_world
	_rng.seed = 20261002
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	var flat_code: String = _strip_billboard(SHADER.code)
	for variant: int in range(4):
		var shader: Shader = Shader.new()
		var code: String = SHADER.code if variant < 2 else flat_code
		if variant % 2 == 1: code = code.replace("blend_mix", "blend_add")
		shader.code = code
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		material.render_priority = 3 + variant % 2
		_materials.append(material)
		var pool: Array[Mark] = []
		for i: int in range(POOLS[variant]): pool.append(Mark.new())
		_pools[variant] = pool
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.mesh = _quad
		multimesh.instance_count = POOLS[variant]
		multimesh.visible_instance_count = 0

		multimesh.custom_aabb = AABB(Vector3(-2000, -500, -2000), Vector3(4000, 1500, 4000))
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.name = "ComicMarks"
		node.multimesh = multimesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		node.custom_aabb = multimesh.custom_aabb
		node.visible = false
		add_child(node)
		_meshes.append(multimesh)
		_mesh_nodes.append(node)
	_trail_material = StandardMaterial3D.new()
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_material.disable_fog = true
	_trail_material.render_priority = 2
	for i: int in range(TRAILS):
		var item: Trail = Trail.new()
		item.mesh = ImmediateMesh.new()
		item.node = MeshInstance3D.new()
		item.node.name = "ComicTrail"
		item.node.mesh = item.mesh
		item.node.material_override = _trail_material
		item.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		item.node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		item.node.extra_cull_margin = 4.0
		item.node.visible = false
		add_child(item.node)
		_trails.append(item)
	var font: Font = load("res://ui/fonts/Anton-Regular.ttf") if ResourceLoader.exists("res://ui/fonts/Anton-Regular.ttf") else ThemeDB.fallback_font
	for i: int in range(WORDS):
		var item: Word = Word.new()
		item.node = Label3D.new()
		item.node.name = "ComicWord"
		item.node.font = font
		item.node.font_size = 96
		item.node.outline_size = 28
		item.node.outline_modulate = INK
		item.node.pixel_size = 0.0042
		item.node.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		item.node.shaded = false
		item.node.double_sided = true
		item.node.no_depth_test = false
		item.node.render_priority = 6
		item.node.outline_render_priority = 5
		item.node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		item.node.visible = false
		add_child(item.node)
		_words.append(item)

func _strip_billboard(code: String) -> String:
	var from: int = code.find("// BILLBOARD_BEGIN")
	var to: int = code.find("// BILLBOARD_END")
	if from < 0 or to < 0: return code
	return code.substr(0, from) + code.substr(to)


func warm_samples() -> Array:
	return [[_quad, _trail_material]]




func warm(at: Vector3) -> void :
	var faint: Color = Color(1.0, 1.0, 1.0, 0.012)
	mark(BURST, at, faint, 0.05, 0.05, 0.12)
	mark(BURST, at, faint, 0.05, 0.05, 0.12, {"add": true})
	mark(BURST, at, faint, 0.05, 0.05, 0.12, {"normal": Vector3.UP})
	mark(BURST, at, faint, 0.05, 0.05, 0.12, {"normal": Vector3.UP, "add": true})
	var item: Word = _words[0]
	var letters: String = ""
	for texts: Array in WORDS_TEXT.values(): letters += str(texts[0]) + str(texts[1])
	item.node.text = letters
	item.node.modulate = faint
	item.node.outline_modulate = faint
	item.active = true
	item.age = 0.0
	item.life = 0.12
	item.origin = at
	item.rise = 0.0
	item.tilt = 0.0
	item.size = 0.02
	item.node.visible = true

func clear() -> void :
	for pool: Array in _pools:
		for item: Mark in pool: _retire(item)
	for index: int in range(_meshes.size()):
		_meshes[index].visible_instance_count = 0
		_mesh_nodes[index].visible = false
	for item: Trail in _trails:
		item.active = false
		item.node.visible = false
	for item: Word in _words:
		item.active = false
		item.node.visible = false
	_later.clear()
	_memory.clear()
	_casts.clear()
	_exit_open = false





func update(delta: float) -> void :
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	_camera_ok = camera != null
	if _camera_ok: _camera_at = camera.global_position
	_clock += delta
	_word_clock = maxf(0.0, _word_clock - delta)
	if not _later.is_empty(): _run_later(delta)
	for variant: int in range(4):
		var multimesh: MultiMesh = _meshes[variant]
		var count: int = 0
		for item: Mark in _pools[variant]:
			if not item.active: continue
			if item.delay > 0.0:
				item.delay -= delta
				if item.delay > 0.0: continue
			item.age += delta
			if item.age >= item.life:
				_retire(item)
				continue
			if item.follow == null:
				item.velocity.y -= item.gravity * delta
				if item.drag > 0.0: item.velocity *= maxf(0.0, 1.0 - item.drag * delta)
				item.origin += item.velocity * delta

			if _place(item, multimesh, count): count += 1
		multimesh.visible_instance_count = count
		if _mesh_nodes[variant].visible != (count > 0): _mesh_nodes[variant].visible = count > 0
	for item: Trail in _trails:
		if item.active: _update_trail(item, delta)
	for item: Word in _words:
		if item.active: _update_word(item, delta)

func _run_later(delta: float) -> void :
	var index: int = 0
	while index < _later.size():
		var entry: Array = _later[index]
		entry[0] = float(entry[0]) - delta
		if float(entry[0]) > 0.0:
			index += 1
			continue
		_later.remove_at(index)
		var action: Callable = entry[1]
		if action.is_valid(): action.call()


func _defer(delay: float, action: Callable) -> void :
	if delay <= 0.001: action.call()
	else: _later.append([delay, action])

func _retire(item: Mark) -> void :
	item.active = false
	item.follow = null


func _place(item: Mark, multimesh: MultiMesh, slot: int) -> bool:
	var t: float = item.age / item.life
	var at: Vector3 = item.origin
	if item.follow != null:
		var source: Variant = item.follow.get_ref()
		if source == null or not (source as Node3D).is_inside_tree():
			_retire(item)
			return false
		at = _follow_point(source as Node3D, item.socket) + item.offset

	var grow: float = 1.0 - pow(1.0 - t, 3.0)
	var size: float = lerpf(item.size_from, item.size_to, grow)
	if item.pop > 0.0:
		var u: float = clampf(t / 0.3, 0.0, 1.0) - 1.0
		size = item.size_to * (1.0 + (item.pop * 3.0 + 1.0) * u * u * u + item.pop * 3.0 * u * u)
	size = maxf(size, 0.001)
	var scale_basis: Basis = Basis.from_scale(Vector3(size * item.aspect.x, size * item.aspect.y, size))
	if item.world_space:
		var basis: Basis = item.basis
		if item.axis != Vector3.ZERO and _camera_ok:

			var to_camera: Vector3 = _camera_at - at
			var side: Vector3 = item.axis.cross(to_camera)
			if side.length_squared() > 0.0001:
				side = side.normalized()
				basis = Basis(side, item.axis, side.cross(item.axis).normalized())
		multimesh.set_instance_transform(slot, Transform3D(basis * scale_basis, at))
	else:
		multimesh.set_instance_transform(slot, Transform3D(scale_basis, at))
	var fade_in: float = clampf(item.age / 0.025, 0.0, 1.0)
	var fade_out: float = 1.0 - smoothstep(item.fade_start, 1.0, t)
	multimesh.set_instance_color(slot, Color(item.color, item.color.a * fade_in * fade_out))

	multimesh.set_instance_custom_data(slot, Color(t, wrapf(item.angle + item.spin * item.age, - PI, PI), item.seed, item.code))
	return true

func _acquire(variant: int) -> Mark:
	var pool: Array = _pools[variant]
	var oldest: Mark = null
	var oldest_ratio: float = -1.0
	for item: Mark in pool:
		if not item.active: return item
		var ratio: float = item.age / maxf(0.001, item.life)
		if ratio > oldest_ratio:
			oldest = item
			oldest_ratio = ratio
	return oldest

func in_range(at: Vector3) -> bool:
	return at.is_finite() and ( not _camera_ok or at.distance_squared_to(_camera_at) < RANGE * RANGE)


func _calm() -> bool:
	return is_instance_valid(world) and bool(world.options.get("reduce_flashes", false))


func _light() -> bool:
	return is_instance_valid(world) and bool(world.get("mobile_mode")) and str(world.get("mobile_profile")) in ["performance", "battery"]

func _words_on() -> bool:
	return not is_instance_valid(world) or bool(world.options.get("fx_words", true))

func _dust_color() -> Color:
	return DUST.get(str(world.get("selected_map")) if is_instance_valid(world) else "school", DUST.school)

func tint_of(visual: PaperVisual) -> Color:
	return TINT.get(visual.character_name, PAPER)


func _lag(node: Node3D) -> Vector3:
	if not node.is_physics_interpolated_and_enabled(): return Vector3.ZERO
	return node.get_global_transform_interpolated().origin - node.global_position

func _follow_point(source: Node3D, socket: String) -> Vector3:
	if source is PaperVisual and not socket.is_empty(): return (source as PaperVisual).socket_position(socket) + _lag(source)
	return source.global_position










func mark(shape: int, at: Vector3, color: Color, size_from: float, size_to: float, life: float, options: Dictionary = {}) -> void :
	if not at.is_finite(): return
	var world_space: bool = options.has("normal") or options.has("axis")
	var variant: int = (WORLD_MIX if world_space else FACE_MIX) + (1 if bool(options.get("add", false)) else 0)
	var item: Mark = _acquire(variant)
	item.active = true
	item.age = 0.0
	item.life = maxf(0.04, life)
	item.delay = float(options.get("delay", 0.0))
	item.origin = at
	item.velocity = options.get("vel", Vector3.ZERO)
	item.gravity = float(options.get("gravity", 0.0))
	item.drag = float(options.get("drag", 0.0))
	item.size_from = size_from
	item.size_to = size_to
	item.pop = float(options.get("pop", 0.0))
	item.aspect = options.get("aspect", Vector2.ONE)
	item.angle = float(options.get("angle", 0.0))
	item.spin = float(options.get("spin", 0.0))
	item.color = color
	item.fade_start = float(options.get("fade", 0.6))
	item.world_space = world_space
	item.axis = Vector3.ZERO
	item.follow = null
	if options.has("follow") and is_instance_valid(options.follow):
		item.follow = weakref(options.follow)
		item.socket = str(options.get("socket", "chest"))
		item.offset = options.get("offset", Vector3.ZERO)
	if options.has("axis"):
		var axis: Vector3 = options.axis
		item.axis = axis.normalized() if axis.length_squared() > 0.0001 else Vector3.UP
		item.basis = Basis.IDENTITY
	elif options.has("normal"):

		var normal: Vector3 = options.normal
		normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP

		var x_axis: Vector3 = Vector3.FORWARD.cross(normal) if absf(normal.y) > 0.7 else Vector3.UP.cross(normal)
		x_axis = x_axis.normalized() if x_axis.length_squared() > 0.0001 else Vector3.RIGHT
		item.basis = Basis(x_axis, normal.cross(x_axis).normalized(), normal)
	item.seed = _rng.randf() * 10.0
	var rim: Color = options.get("ink", INK)
	item.code = float(shape + 32 * _ink_index(rim) + (512 if rim.a < 0.5 else 0))


func _ink_index(rim: Color) -> int:
	var key: int = Color(rim, 1.0).to_rgba32()
	if _ink_cache.has(key): return _ink_cache[key]
	var best: int = 0
	var best_distance: float = INF
	for index: int in range(INK_PALETTE.size()):
		var entry: Color = INK_PALETTE[index]
		var distance: float = (entry.r - rim.r) * (entry.r - rim.r) + (entry.g - rim.g) * (entry.g - rim.g) + (entry.b - rim.b) * (entry.b - rim.b)
		if distance < best_distance:
			best = index
			best_distance = distance
	_ink_cache[key] = best
	return best



func trail(source: Node3D, socket: String, color: Color, seconds: float = 0.26, width: float = 0.15, span: float = 0.15) -> void :
	if not is_instance_valid(source): return
	var chosen: Trail = null
	for candidate: Trail in _trails:
		if candidate.active and candidate.socket == socket and candidate.source != null and candidate.source.get_ref() == source:
			chosen = candidate
			break
	if chosen == null:
		for candidate: Trail in _trails:
			if not candidate.active:
				chosen = candidate
				break
	if chosen == null: return
	if not chosen.active:
		chosen.points.clear()
		chosen.born.clear()
		chosen.clock = 0.0
	chosen.active = true
	chosen.source = weakref(source)
	chosen.socket = socket
	chosen.emit_left = seconds
	chosen.span = span
	chosen.width = width
	chosen.color = Color(color, color.a * (0.6 if _calm() else 1.0))
	chosen.node.visible = true

func _update_trail(item: Trail, delta: float) -> void :
	item.clock += delta
	var source: Variant = item.source.get_ref() if item.source != null else null
	if item.emit_left > 0.0 and source != null and (source as Node3D).is_inside_tree() and (source as Node3D).is_visible_in_tree():
		item.emit_left -= delta
		var at: Vector3 = _follow_point(source as Node3D, item.socket)
		if item.points.is_empty() or at.distance_squared_to(item.points[item.points.size() - 1]) > 0.0004:
			item.points.append(at)
			item.born.append(item.clock)
			if item.points.size() > TRAIL_POINTS:
				item.points.remove_at(0)
				item.born.remove_at(0)
	else:
		item.emit_left = 0.0
	while not item.born.is_empty() and item.clock - item.born[0] > item.span:
		item.points.remove_at(0)
		item.born.remove_at(0)
	item.mesh.clear_surfaces()
	var count: int = item.points.size()
	if count < 2:
		if item.emit_left <= 0.0:
			item.active = false
			item.node.visible = false
		return
	item.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in range(count):
		var point: Vector3 = item.points[i]
		var along: Vector3 = (item.points[mini(i + 1, count - 1)] - item.points[maxi(i - 1, 0)])
		var side: Vector3 = along.cross(_camera_at - point)
		side = side.normalized() if side.length_squared() > 1e-06 else Vector3.UP
		var k: float = float(i) / float(count - 1)
		var fresh: float = 1.0 - clampf((item.clock - item.born[i]) / item.span, 0.0, 1.0)
		var half: float = item.width * 0.5 * sin(k * PI * 0.5 + 0.2) * (0.35 + 0.65 * fresh)
		var tint: Color = Color(item.color.lerp(Color.WHITE, 0.55 * k), item.color.a * fresh * k)
		item.mesh.surface_set_color(tint)
		item.mesh.surface_add_vertex(point + side * half)
		item.mesh.surface_set_color(tint)
		item.mesh.surface_add_vertex(point - side * half)
	item.mesh.surface_end()


func word(key: String, at: Vector3, color: Color, size: float = 1.0) -> void :
	if not in_range(at) or _word_clock > 0.0 or not WORDS_TEXT.has(key) or not _words_on(): return

	_word_clock = 0.3
	var chosen: Word = null
	for candidate: Word in _words:
		if not candidate.active:
			chosen = candidate
			break
	if chosen == null: chosen = _words[0]
	var texts: Array = WORDS_TEXT[key]
	chosen.node.text = str(texts[1] if PaperLanguage.language == "en" else texts[0])
	chosen.node.modulate = color
	chosen.active = true
	chosen.age = 0.0
	chosen.life = 0.8
	chosen.origin = at + Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.0, 0.2), _rng.randf_range(-0.2, 0.2))
	chosen.rise = 0.55
	chosen.tilt = _rng.randf_range(-0.28, 0.28)
	chosen.size = size
	chosen.pinned = false
	var camera: Camera3D = _film_camera() if frame_guard else null
	if camera != null:


		chosen.rise = 0.3
		chosen.pin = _framed(camera, camera.global_transform.affine_inverse() * chosen.origin, size, chosen.rise)
		chosen.pinned = true
	chosen.node.no_depth_test = chosen.pinned
	chosen.node.visible = true
	_update_word(chosen, 0.0)

func _film_camera() -> Camera3D:
	var camera: Camera3D = (world.get("camera") as Camera3D) if is_instance_valid(world) else null
	return camera if camera != null and camera.is_inside_tree() else null





func _framed(camera: Camera3D, local: Vector3, size: float, rise: float) -> Vector3:
	var depth: float = - local.z
	if depth < 0.5: return local
	var half_y: float = depth * tan(deg_to_rad(camera.fov) * 0.5)
	var view: Vector2 = camera.get_viewport().get_visible_rect().size
	var half_x: float = half_y * view.x / maxf(1.0, view.y)
	var grow: float = size * clampf(local.length() / 7.0, 0.7, 2.2)
	var tall: float = 0.42 * grow
	var wide: float = 1.0 * grow
	var bottom: float = - half_y * 0.76 + tall
	var top: float = half_y * 0.76 - tall - rise
	var before: float = local.y
	local.y = clampf(local.y, bottom, maxf(bottom, top))
	if before - local.y > 0.25: local.x += (wide * 0.8 + 0.25) * (1.0 if local.x >= 0.0 else -1.0)
	if half_x > wide + 0.1: local.x = clampf(local.x, - half_x + wide + 0.1, half_x - wide - 0.1)
	else: local.x = 0.0
	return local

func _update_word(item: Word, delta: float) -> void :
	item.age += delta
	if item.age >= item.life:
		item.active = false
		item.node.visible = false
		return
	var t: float = item.age / item.life
	var u: float = clampf(t / 0.22, 0.0, 1.0) - 1.0
	var swell: float = 1.0 + 2.6 * u * u * u + 1.6 * u * u
	var at: Vector3 = item.origin + Vector3.UP * item.rise * (1.0 - pow(1.0 - t, 2.0))
	if item.pinned:
		var camera: Camera3D = _film_camera()
		if camera != null: at = camera.global_transform * (item.pin + Vector3.UP * item.rise * (1.0 - pow(1.0 - t, 2.0)))
	var facing: Basis = Basis.IDENTITY
	if _camera_ok:
		var to_camera: Vector3 = _camera_at - at
		if to_camera.length_squared() > 0.01:

			facing = Basis.looking_at( - to_camera.normalized(), Vector3.UP) * Basis(Vector3.BACK, item.tilt * (1.0 - 0.5 * t))

			swell *= clampf(to_camera.length() / 7.0, 0.7, 2.2)
	item.node.transform = Transform3D(facing * Basis.from_scale(Vector3.ONE * maxf(0.01, swell * item.size)), at)
	var alpha: float = 1.0 - smoothstep(0.62, 1.0, t)
	item.node.modulate.a = alpha
	item.node.outline_modulate = Color(INK, alpha)



func _emit(kit: int, at: Vector3, direction: Vector3, color: Color, reduced: bool = false, power: float = 1.0, spread: float = -1.0) -> void :
	host.call("_emit", kit, at, direction, color, reduced, power, spread)

func _ring(at: Vector3, normal: Vector3, color: Color, radius_from: float, radius_to: float, life: float, thickness: float = 0.06, fill: float = 0.0, wobble: float = 0.0) -> void :
	host.call("_ring", at, normal, color, radius_from, radius_to, life, thickness, fill, wobble)


func _glow(at: Vector3, color: Color, size_from: float, size_to: float, life: float) -> void :
	if _calm(): return
	host.call("_sprite", 1, at, 0, color, size_from, size_to, life)


func _rumble(at: Vector3, amount: float, radius: float = 16.0) -> void :
	if not _camera_ok or not is_instance_valid(world) or not world.has_method("add_camera_trauma"): return
	var distance: float = at.distance_to(_camera_at)
	if distance < radius: world.call("add_camera_trauma", amount * (1.0 - distance / radius))

func _actor(id: int) -> PaperActor:
	if not is_instance_valid(world) or id < 0: return null
	var actors: Dictionary = world.actors
	return actors.get(id)

func _render(actor: PaperActor) -> Vector3:
	return host.call("_render_position", actor)

func _body(actor: PaperActor) -> PaperVisual:
	if actor == null or not is_instance_valid(actor.visual): return null
	return actor.visual.fx_source()

func _flat(direction: Vector3, fallback: Vector3 = Vector3.FORWARD) -> Vector3:
	direction.y = 0.0
	if direction.length_squared() > 0.0001: return direction.normalized()
	fallback.y = 0.0
	return fallback.normalized() if fallback.length_squared() > 0.0001 else Vector3.FORWARD

func _around(radius: float, height: float = 0.0) -> Vector3:
	var angle: float = _rng.randf() * TAU
	var reach: float = radius * sqrt(_rng.randf())
	return Vector3(cos(angle) * reach, height, sin(angle) * reach)

func _socket(visual: PaperVisual, socket: String) -> Vector3:
	return visual.socket_position(socket)


func _wall_ahead(from: Vector3, direction: Vector3, reach: float) -> Dictionary:
	if not is_instance_valid(world) or not world.is_inside_tree(): return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + direction * reach, 1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.6: return {}
	return {"position": hit.position, "normal": hit.normal}

func _forward(visual: PaperVisual) -> Vector3:
	var forward: Vector3 = - visual.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD






func pop(at: Vector3, direction: Vector3, color: Color, scale: float = 1.0) -> void :
	if not in_range(at): return
	var calm: bool = _calm()
	mark(BURST, at, Color(color.lerp(PAPER, 0.45), 0.95), 0.3 * scale, 1.05 * scale, 0.2, {"pop": 0.55, "angle": _rng.randf() * TAU, "fade": 0.55})
	if not calm: mark(LINES, at, Color(PAPER, 0.9), 1.3 * scale, 2.4 * scale, 0.24, {"add": true, "angle": _rng.randf() * TAU, "fade": 0.3})
	mark(DASHES, at, Color(color, 0.8), 0.5 * scale, 1.9 * scale, 0.26, {"add": not calm, "fade": 0.3})
	_emit(KIT_SPARK, at, direction + Vector3.UP * 0.3, color.lerp(Color.WHITE, 0.5), calm, 1.0 * scale, 70.0)


func dust(at: Vector3, amount: int = 2, spread: float = 0.5, size: float = 0.5) -> void :
	if not in_range(at): return
	var color: Color = _dust_color()
	for i: int in range(amount):
		var angle: float = _rng.randf() * TAU
		var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		mark(PUFF, at + out * spread * 0.3 + Vector3.UP * 0.12, Color(color, 0.72), size * 0.45, size * _rng.randf_range(0.9, 1.3), _rng.randf_range(0.38, 0.6), 
			{"vel": out * spread * 1.6 + Vector3.UP * _rng.randf_range(0.3, 0.8), "drag": 3.0, "angle": _rng.randf() * TAU, "spin": _rng.randf_range(-1.5, 1.5), "fade": 0.35, "ink": color.darkened(0.45)})


func dust_ring(at: Vector3, radius: float = 1.0) -> void :
	if not in_range(at): return
	var color: Color = _dust_color()
	for i: int in range(7):
		var angle: float = float(i) / 7.0 * TAU + _rng.randf() * 0.4
		var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		mark(PUFF, at + out * 0.2 + Vector3.UP * 0.14, Color(color, 0.8), 0.25, 0.55 * radius + 0.2, _rng.randf_range(0.4, 0.6), 
			{"vel": out * (2.6 * radius) + Vector3.UP * 0.5, "drag": 4.5, "angle": _rng.randf() * TAU, "fade": 0.3, "ink": color.darkened(0.45)})
	mark(DASHES, at + Vector3.UP * 0.05, Color(color.lightened(0.2), 0.8), 0.4, 2.6 * radius, 0.32, {"normal": Vector3.UP, "fade": 0.25})


func skid(at: Vector3, direction: Vector3) -> void :
	if not in_range(at): return
	var flat: Vector3 = _flat(direction)
	var side: Vector3 = flat.cross(Vector3.UP)
	for k: int in [-1, 1]:
		mark(STREAK, at + side * 0.18 * float(k) + Vector3.UP * 0.04 - flat * 0.3, Color(_dust_color().darkened(0.25), 0.7), 0.9, 1.4, 0.5, 
			{"normal": Vector3.UP, "angle": atan2(flat.x, flat.z) + PI, "aspect": Vector2(0.25, 1.0), "fade": 0.4})
	dust(at - flat * 0.2, 3, 0.7, 0.55)


func crack(at: Vector3, size: float = 1.6, normal: Vector3 = Vector3.UP) -> void :
	if not in_range(at): return
	mark(CRACK, at + normal * 0.035, Color(INK, 0.88), size, size * 1.08, 2.6, {"normal": normal, "angle": _rng.randf() * TAU, "fade": 0.72})
	_emit(KIT_SCRAP, at + normal * 0.1, normal, _dust_color().darkened(0.2), true, 0.8, 75.0)


func whoosh(at: Vector3, direction: Vector3, color: Color, count: int = 5, length: float = 1.5) -> void :
	if not in_range(at) or direction.length_squared() < 0.0001: return
	var along: Vector3 = direction.normalized()
	var side: Vector3 = along.cross(Vector3.UP)
	if side.length_squared() < 0.01: side = Vector3.RIGHT
	side = side.normalized()
	for i: int in range(count):
		var offset: Vector3 = side * _rng.randf_range(-0.5, 0.5) + Vector3.UP * _rng.randf_range(-0.55, 0.6) - along * _rng.randf_range(0.2, 0.9)
		mark(STREAK, at + offset, Color(color.lerp(Color.WHITE, 0.6), 0.85), length * 0.5, length * _rng.randf_range(0.8, 1.3), _rng.randf_range(0.16, 0.28), 
			{"add": true, "axis": along, "aspect": Vector2(0.14, 1.0), "vel": - along * 2.0, "fade": 0.3, "delay": _rng.randf() * 0.05})


func stars(at: Vector3, count: int = 4) -> void :
	if not in_range(at): return
	for k: int in range(count):
		var angle: float = float(k) / float(count) * TAU + _rng.randf()
		var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		mark(STAR, at + out * 0.15, Color("ffe066", 0.98), 0.14, 0.3, 0.62, {"vel": out * 1.7 + Vector3.UP * 2.2, "gravity": 6.5, "spin": _rng.randf_range(-9.0, 9.0), "fade": 0.6, "ink": Color("7a4a10")})


func sweat(at: Vector3, count: int = 3) -> void :
	if not in_range(at): return
	for k: int in range(count):
		var out: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized()
		mark(DROP, at + out * 0.25, Color("bfe9ff", 0.95), 0.1, 0.19, 0.5, {"vel": out * 1.4 + Vector3.UP * 2.0, "gravity": 7.0, "angle": _rng.randf_range(-0.4, 0.4), "fade": 0.6})


func sparkles(at: Vector3, color: Color, count: int = 5, radius: float = 0.7, rise: float = 0.4) -> void :
	if not in_range(at): return
	for k: int in range(count):
		var offset: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.7, 1.0), _rng.randf_range(-1.0, 1.0)) * radius
		mark(SPARKLE, at + offset, Color(color.lerp(Color.WHITE, 0.6), 0.95), 0.25, 0.42, _rng.randf_range(0.3, 0.5), {"add": true, "delay": 0.05 * float(k), "vel": Vector3.UP * rise, "fade": 0.7})


func pillars(at: Vector3, color: Color, count: int = 6, radius: float = 0.6, height: float = 1.9, additive: bool = true) -> void :
	if not in_range(at): return
	for k: int in range(count):
		var angle: float = float(k) / float(count) * TAU + _rng.randf() * 0.5
		var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * radius * _rng.randf_range(0.7, 1.2)
		mark(STREAK, at + out + Vector3.UP * 0.15, Color(color, 0.82), height * 0.4, height, _rng.randf_range(0.36, 0.5), 
			{"add": additive, "axis": Vector3.UP, "aspect": Vector2(0.2, 1.0), "vel": Vector3.UP * 2.6, "fade": 0.3, "delay": 0.02 * float(k)})


func pluses(at: Vector3, count: int = 3, radius: float = 0.45, speed: float = 1.2) -> void :
	if not in_range(at): return
	for k: int in range(count):
		var offset: Vector3 = _around(radius)
		mark(PLUS, at + offset, Color(MINT, 0.95), 0.1, 0.24, _rng.randf_range(0.6, 0.85), {"vel": offset * 0.6 + Vector3.UP * speed * _rng.randf_range(0.8, 1.3), "drag": 1.2, "fade": 0.55, "ink": Color("1f6a52"), "delay": 0.05 * float(k)})


func ink_puffs(at: Vector3, count: int = 6, speed: float = 3.0, rim: Color = BLOOD_INK) -> void :
	if not in_range(at): return
	for k: int in range(count):
		var angle: float = float(k) / float(count) * TAU + _rng.randf() * 0.5
		var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		mark(PUFF, at + out * 0.3, Color("2a1535", 0.88), 0.35, 0.95, _rng.randf_range(0.4, 0.62), {"vel": out * speed + Vector3.UP * _rng.randf_range(0.6, 2.2), "drag": 3.5, "angle": _rng.randf() * TAU, "fade": 0.35, "ink": rim})


func bolts(at: Vector3, color: Color, count: int = 3, radius: float = 0.6, size: float = 0.8) -> void :
	if not in_range(at): return
	for k: int in range(count):
		var offset: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.8, 0.9), _rng.randf_range(-1.0, 1.0)) * radius
		mark(BOLT, at + offset, Color(color, 0.95), size * 0.6, size * _rng.randf_range(0.9, 1.3), _rng.randf_range(0.12, 0.2), {"add": true, "angle": _rng.randf() * TAU, "delay": 0.035 * float(k), "fade": 0.4})





func cue(visual: PaperVisual, cue_name: String) -> void :
	if not is_instance_valid(visual) or not visual.is_inside_tree(): return
	var at: Vector3 = visual.global_position
	if not in_range(at): return
	var tint: Color = tint_of(visual)
	var forward: Vector3 = _forward(visual)
	var calm: bool = _calm()
	var big: float = visual.visual_height() / 1.75
	match cue_name:
		"step_l", "step_r":
			var speed: float = visual.ground_speed()
			var heavy: bool = visual.character_name == "TrueForm"
			if speed < 5.0 and not heavy: return
			var foot: Vector3 = _socket(visual, "foot_l" if cue_name == "step_l" else "foot_r")
			foot.y = at.y
			if heavy:

				dust(foot, 2, 0.7, 0.6)
				mark(DASHES, foot + Vector3.UP * 0.04, Color(BLOOD_INK, 0.6), 0.3, 1.5, 0.3, {"normal": Vector3.UP, "fade": 0.3})
				_rumble(foot, 0.1, 12.0)
				return
			mark(PUFF, foot + Vector3.UP * 0.12, Color(_dust_color(), 0.7), 0.2, 0.42 + 0.03 * speed, 0.36, {"vel": - forward * 0.9 + Vector3.UP * 0.6, "drag": 3.0, "angle": _rng.randf() * TAU, "fade": 0.3, "ink": _dust_color().darkened(0.4)})
			if speed > 11.0: whoosh(at + Vector3.UP * 0.9, forward, tint, 2, 1.3)
		"trail_r": trail(visual, "hand_r", Color(tint, 0.9))
		"trail_l": trail(visual, "hand_l", Color(tint, 0.9))
		"trail_both":
			trail(visual, "hand_r", Color(tint, 0.9))
			trail(visual, "hand_l", Color(tint, 0.9))
		"trail_foot_r": trail(visual, "foot_r", Color(tint, 0.9), 0.3, 0.2)
		"trail_foot_l": trail(visual, "foot_l", Color(tint, 0.9), 0.3, 0.2)
		"pop_r": pop(_socket(visual, "hand_r") + forward * 0.2, forward, tint, 0.85)
		"pop_l": pop(_socket(visual, "hand_l") + forward * 0.2, forward, tint, 0.85)
		"pop_foot_r": pop(_socket(visual, "foot_r") + forward * 0.2, forward, tint, 0.95)
		"pop_foot_l": pop(_socket(visual, "foot_l") + forward * 0.2, forward, tint, 0.95)
		"pop_front": pop(_socket(visual, "front"), forward, tint, 1.25)
		"dust": dust(at, 2)
		"dust_ring": dust_ring(at, 1.0 * big)
		"land": dust_ring(at, 0.8 * big)
		"land_hard":
			dust_ring(at, 1.3 * big)
			crack(at, 1.3 * big)
			_rumble(at, 0.3)
		"jump": dust(at, 3, 0.8, 0.45)
		"skid": skid(at, forward)
		"crack":
			crack(at, 1.7 * big)
			_rumble(at, 0.28 * big)
		"whoosh": whoosh(_socket(visual, "chest"), forward, tint)
		"afterimage": _afterimage(visual, tint)
		"spin":
			mark(DASHES, _socket(visual, "hips"), Color(tint.lerp(Color.WHITE, 0.5), 0.85), 0.8, 2.6, 0.3, {"add": true, "normal": Vector3.UP, "spin": 9.0, "fade": 0.3})
		"sweat": sweat(_socket(visual, "head"))
		"anger":
			mark(VEIN, Vector3.ZERO, Color("ff4a4a", 0.95), 0.2, 0.34, 0.9, {"follow": visual, "socket": "over", "offset": Vector3(0.22, -0.1, 0.0), "pop": 0.6, "fade": 0.75})
		"sparkle": sparkles(_socket(visual, "chest"), tint, 5, 0.6)
		"stars": stars(_socket(visual, "over"), 4)
		"glint":
			var hand: Vector3 = _socket(visual, "hand_r")
			mark(SPARKLE, hand, Color(1.0, 1.0, 1.0, 0.98), 0.3, 0.75, 0.34, {"add": true, "spin": 2.0, "fade": 0.6})
			if not calm: mark(RAYS, hand, Color(tint.lerp(Color.WHITE, 0.6), 0.55), 0.5, 1.1, 0.26, {"add": true, "fade": 0.2})
		"flex":
			var chest: Vector3 = _socket(visual, "chest")
			mark(LINES, chest, Color(tint.lerp(Color.WHITE, 0.5), 0.9), 1.8, 3.4, 0.42, {"add": true, "fade": 0.3})
			mark(DASHES, at + Vector3.UP * 0.05, Color(tint, 0.85), 0.5, 3.0, 0.4, {"normal": Vector3.UP, "add": true, "fade": 0.3})
			pillars(at, tint.lerp(Color.WHITE, 0.4), 6, 0.55, 1.9)
			_emit(KIT_EMBER, chest, Vector3.UP, tint.lerp(Color.WHITE, 0.3), calm, 1.4)

		"claw_r", "claw_l": _claw(visual, cue_name == "claw_r", tint)
		"ink":
			mark(PUDDLE, at + Vector3.UP * 0.03, Color(SHADOW, 0.9), 1.0, 1.7, 1.5, {"normal": Vector3.UP, "angle": _rng.randf() * TAU, "fade": 0.6})
			_emit(KIT_INK, at + Vector3.UP * 0.25, Vector3.UP, Color("2b1736"), true, 0.8, 70.0)
		"ink_burst":
			mark(PUDDLE, at + Vector3.UP * 0.03, Color(SHADOW, 0.92), 1.4, 3.0, 1.8, {"normal": Vector3.UP, "angle": _rng.randf() * TAU, "fade": 0.6})
			ink_puffs(at + Vector3.UP * 0.5, 7, 3.0)
			mark(BURST, at + Vector3.UP * 0.9, Color("3a1838", 0.7), 0.5, 1.5, 0.2, {"pop": 0.4, "fade": 0.4, "ink": Color(BLOOD_INK, 0.15)})
			_emit(KIT_INK, at + Vector3.UP * 0.5, Vector3.UP, Color("3a1030"), false, 1.3, 85.0)
		"shadow_rise":
			for k: int in range(5):
				var angle: float = float(k) / 5.0 * TAU + _rng.randf() * 0.6
				var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(0.5, 1.3)
				mark(STREAK, at + out + Vector3.UP * 0.2, Color(SHADOW, 0.85), 0.8, 3.0, _rng.randf_range(0.5, 0.75), {"axis": Vector3.UP, "aspect": Vector2(0.16, 1.0), "vel": Vector3.UP * 2.4, "fade": 0.35, "delay": 0.04 * float(k)})
			mark(DASHES, at + Vector3.UP * 0.05, Color(BLOOD_INK, 0.8), 0.6, 3.6, 0.6, {"normal": Vector3.UP, "add": not calm, "fade": 0.3})

		"spark_r", "spark_l":
			var hand: Vector3 = _socket(visual, "hand_r" if cue_name == "spark_r" else "hand_l")
			_emit(KIT_SPARK, hand, Vector3.UP, Color("fff2a8"), true, 0.9, 80.0)
			mark(BOLT, hand, Color("bff6ff", 0.95), 0.3, 0.55, 0.16, {"add": true, "angle": _rng.randf() * TAU, "fade": 0.4})
		"volt":
			var chest: Vector3 = _socket(visual, "chest")
			bolts(chest, Color("bff6ff"), 4, 0.55, 0.8)
			_emit(KIT_SPARK, chest, Vector3.UP, Color("d9fbff"), calm, 1.1, 180.0)
		"steam":

			if visual.ground_speed() > 4.0: _steam(visual, 2, 0.5)
			else: _steam(visual, 4)

		"heal_r", "heal_l":
			var hand: Vector3 = _socket(visual, "hand_r" if cue_name == "heal_r" else "hand_l")
			for k: int in range(2):
				mark(PLUS, hand + Vector3(_rng.randf_range(-0.15, 0.15), 0.0, _rng.randf_range(-0.15, 0.15)), Color(MINT, 0.95), 0.1, 0.22, 0.6, {"vel": forward * 0.9 + Vector3.UP * _rng.randf_range(0.8, 1.4), "drag": 1.5, "fade": 0.55, "ink": Color("1f6a52"), "delay": 0.08 * float(k)})
			mark(SPARKLE, hand, Color("d6fff0", 0.9), 0.2, 0.45, 0.3, {"add": true})
		"heal_ring":
			_ring(at + Vector3.UP * 0.07, Vector3.UP, Color("8ff0d2", 0.85), 0.2, 2.4, 0.6, 0.09)
			for k: int in range(7):
				var angle: float = float(k) / 7.0 * TAU
				var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
				mark(PLUS, at + out * 0.9 + Vector3.UP * 0.2, Color(MINT, 0.95), 0.12, 0.26, 0.8, {"vel": out * 0.6 + Vector3.UP * 1.5, "drag": 1.2, "fade": 0.55, "ink": Color("1f6a52"), "delay": 0.03 * float(k)})
		"muzzle":
			var muzzle: Vector3 = visual.attachment_position("shotgun_muzzle")
			mark(RAYS, muzzle + forward * 0.2, Color("ffe6a0", 0.98), 0.7, 2.0, 0.16, {"add": not calm, "fade": 0.2})
			mark(BURST, muzzle + forward * 0.15, Color("fff1c4", 0.95), 0.4, 1.3, 0.14, {"pop": 0.5, "ink": Color("d4722a")})
			for k: int in range(4):
				mark(PUFF, muzzle + forward * 0.3, Color("d9d4cc", 0.7), 0.2, 0.7, _rng.randf_range(0.5, 0.8), {"vel": forward * _rng.randf_range(1.0, 3.0) + Vector3.UP * _rng.randf_range(0.3, 1.2), "drag": 2.5, "fade": 0.3, "ink": Color("6f6a66"), "delay": 0.04 * float(k)})
			_emit(KIT_SPARK, muzzle, forward, Color("ffd27a"), false, 1.6, 22.0)
			whoosh(muzzle + forward * 1.5, forward, Color("ffe6a0"), 4, 2.2)
			word("gun", muzzle + Vector3.UP * 0.6, Color("ffe6a0"), 1.0)
			_rumble(muzzle, 0.3, 14.0)

		"cheer":
			var head: Vector3 = _socket(visual, "head")
			for k: int in range(7):
				var angle: float = float(k) / 7.0 * TAU + _rng.randf() * 0.4
				var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
				var heart: bool = k % 2 == 0
				mark(HEART if heart else STAR, head + out * 0.2, Color("ff8fb1" if heart else "ffe066", 0.98), 0.14, 0.32, 0.8, {"vel": out * 1.8 + Vector3.UP * _rng.randf_range(2.2, 3.4), "gravity": 5.0, "spin": 0.0 if heart else _rng.randf_range(-6.0, 6.0), "fade": 0.65, "ink": Color("8a2a4a" if heart else "7a4a10"), "delay": 0.02 * float(k)})
		"notes":
			var hand: Vector3 = _socket(visual, "chest") + forward * 0.4
			for k: int in range(4):
				mark(HEART if k % 2 == 0 else NOTE, hand + Vector3.UP * 0.1 * float(k % 2), Color("ff8fb1", 0.98), 0.16, 0.34, 0.9, {"vel": forward * (3.2 + 0.6 * float(k)) + Vector3.UP * _rng.randf_range(0.2, 1.0), "drag": 1.2, "fade": 0.6, "ink": Color("8a2a4a"), "delay": 0.07 * float(k)})
			mark(SPARKLE, hand, Color("fff0f6", 0.95), 0.3, 0.6, 0.3, {"add": true})
		"crumbs":
			var mouth: Vector3 = _socket(visual, "mouth")
			_emit(KIT_SCRAP, mouth, forward + Vector3.UP, Color("6b4630"), true, 0.5, 60.0)
			mark(HEART, mouth + Vector3.UP * 0.3, Color("ff8fb1", 0.95), 0.1, 0.2, 0.6, {"vel": Vector3.UP * 0.9, "fade": 0.6, "ink": Color("8a2a4a")})

		"flash_pin":
			mark(SPARKLE, _socket(visual, "hand_l"), Color(1, 1, 1, 0.95), 0.2, 0.5, 0.25, {"add": true})
			mark(DASHES, _socket(visual, "hand_r"), Color("dfefff", 0.8), 0.15, 0.6, 0.22, {"add": true})
		"fuse": _emit(KIT_SPARK, _socket(visual, "hand_r"), Vector3.UP, Color("fff2a8"), true, 0.5, 60.0)

		"skate_sparks":
			for socket: String in ["foot_l", "foot_r"]:
				var foot: Vector3 = _socket(visual, socket)
				foot.y = at.y + 0.05
				_emit(KIT_SPARK, foot, - forward + Vector3.UP * 0.5, Color("ffc46b"), true, 1.0, 35.0)
			mark(STREAK, at + Vector3.UP * 0.04 - forward * 0.6, Color("ffe2a8", 0.75), 0.8, 1.7, 0.3, {"add": true, "normal": Vector3.UP, "angle": atan2(forward.x, forward.z) + PI, "aspect": Vector2(0.16, 1.0), "fade": 0.3})
		"drone_up":
			var hand: Vector3 = _socket(visual, "hand_r")
			mark(DASHES, hand, Color("c6b5f9", 0.9), 0.2, 1.1, 0.3, {"add": true, "normal": Vector3.UP, "fade": 0.3})
			for k: int in range(3):
				mark(STREAK, hand + Vector3(_rng.randf_range(-0.15, 0.15), 0.1, _rng.randf_range(-0.15, 0.15)), Color("e6dcff", 0.85), 0.4, 1.1, 0.28, {"add": true, "axis": Vector3.UP, "aspect": Vector2(0.1, 1.0), "vel": Vector3.UP * 3.0, "delay": 0.03 * float(k)})
		"scan":
			var eyes: Vector3 = _socket(visual, "eyes")
			_ring(eyes, Vector3.UP, Color("84dace", 0.75), 0.15, 2.6, 0.4, 0.035)
			mark(SPARKLE, eyes + forward * 0.1, Color("c9fff4", 0.95), 0.15, 0.4, 0.25, {"add": true})



func _claw(visual: PaperVisual, right_hand: bool, tint: Color) -> void :
	var forward: Vector3 = _forward(visual)
	var right: Vector3 = forward.cross(Vector3.UP)
	var side: float = 1.0 if right_hand else -1.0
	var size: float = 2.5 * lerpf(1.0, visual.visual_height() / 1.75, 0.6)
	var centre: Vector3 = _socket(visual, "front") + Vector3.UP * 0.15

	var origin: Vector3 = centre + (right * side * 0.707 - Vector3.UP * 0.707) * 0.68 * size * 0.5
	var options: Dictionary = {"normal": - forward, "angle": -2.356, "aspect": Vector2(side, 1.0), "fade": 0.5}
	mark(CRESCENT, origin, Color(tint, 0.96), size * 0.9, size, 0.27, options)
	if not _calm():
		var glow: Dictionary = options.duplicate()
		glow["add"] = true
		glow["fade"] = 0.3
		mark(CRESCENT, origin + forward * 0.06, Color(tint.lerp(Color.WHITE, 0.25), 0.4), size * 0.95, size * 1.12, 0.32, glow)
	_emit(KIT_INK, centre, forward, Color("3a1030"), _calm(), 1.1, 50.0)

func _afterimage(visual: PaperVisual, tint: Color) -> void :
	var chest: Vector3 = _socket(visual, "hips")
	var forward: Vector3 = _forward(visual)
	var tall: float = visual.visual_height()
	chest.y = visual.global_position.y + tall * 0.5
	mark(SMEAR, chest, Color(tint, 0.5), tall * 1.02, tall * 1.08, 0.3, {"axis": Vector3.UP, "fade": 0.15})
	mark(SMEAR, chest - forward * 0.4, Color(tint.lerp(Color.WHITE, 0.4), 0.3), tall, tall * 1.1, 0.4, {"add": not _calm(), "axis": Vector3.UP, "fade": 0.15, "delay": 0.05})

func _steam(visual: PaperVisual, count: int, scale: float = 1.0) -> void :
	var back: Vector3 = _socket(visual, "back")
	var forward: Vector3 = _forward(visual)
	var light: bool = scale < 0.99
	for k: int in range(count):
		var side: Vector3 = forward.cross(Vector3.UP) * (0.3 if k % 2 == 0 else -0.3)
		mark(PUFF, back + side, Color(1.0, 1.0, 1.0, 0.5 if light else 0.75), 0.2 * scale, 0.75 * scale, _rng.randf_range(0.45, 0.7) * (0.7 if light else 1.0), {"vel": side * 2.2 + Vector3.UP * _rng.randf_range(1.6, 2.6) - forward * 0.6, "drag": 2.2, "angle": _rng.randf() * TAU, "fade": 0.3, "ink": Color("9db4c4"), "delay": 0.03 * float(k)})





func _event_position(data: Dictionary, actor: PaperActor) -> Vector3:
	var position: Variant = data.get("position")
	if position is Vector3 and (position as Vector3).is_finite(): return position
	if actor != null: return _render(actor)
	return Vector3(INF, INF, INF)



func _contact_delay(source: PaperActor) -> float:
	if source == null or not _casts.has(source.id): return 0.0
	var cast: Array = _casts[source.id]
	var elapsed: float = _clock - float(cast[0])
	if elapsed > CONTACT_TIME or str(cast[1]) not in MELEE: return 0.0
	return CONTACT_TIME - elapsed

func _hit_stop(actor: PaperActor, seconds: float) -> void :
	if is_instance_valid(actor) and is_instance_valid(actor.visual): actor.visual.fx_source().hit_stop(seconds)

func on_event(kind: String, data: Dictionary) -> void :
	if not is_instance_valid(world) or not is_inside_tree(): return
	var actor: PaperActor = _actor(int(data.get("actor", -1)))
	var at: Vector3 = _event_position(data, actor)
	var calm: bool = _calm()
	match kind:
		"ability":
			if actor: _casts[actor.id] = [_clock, str(data.get("name", "")).to_lower()]
		"hit": _on_hit(data, actor)
		"stun": _on_stun(data, actor)
		"block": _on_block(data, actor)
		"dodge":
			if not in_range(at): return
			var body: PaperVisual = _body(actor)
			if body: _afterimage(body, tint_of(body))
			var side: Vector3 = _flat(actor.aim if actor else Vector3.FORWARD).cross(Vector3.UP)
			whoosh(at + Vector3.UP * 1.0, side, PAPER, 4, 1.2)
			word("miss", at + Vector3.UP * 2.1, PAPER, 0.85)
		"protection":
			if not in_range(at): return
			mark(DASHES, at + Vector3.UP * 1.1, Color("84dace", 0.85), 0.5, 2.0, 0.34, {"add": not calm, "fade": 0.3})
			sparkles(at + Vector3.UP * 1.1, Color("84dace"), 4, 0.6)
			word("block", at + Vector3.UP * 2.0, Color("9fe3d4"), 0.9)
		"grab": _on_grab(data, actor, at)
		"downed":
			if not in_range(at): return
			dust_ring(at, 0.9)
			stars(at + Vector3.UP * 0.9, 3)
			sweat(at + Vector3.UP * 0.8, 3)
			word("down", at + Vector3.UP * 1.5, Color("ff8aa0"), 0.9)
		"death_start": _on_death(data, at)
		"eliminated":
			if not in_range(at): return

			pillars(at, SHADOW, 6, 0.6, 2.4, false)
			mark(DASHES, at + Vector3.UP * 0.05, Color(BLOOD_INK, 0.7), 0.4, 2.6, 0.7, {"normal": Vector3.UP, "fade": 0.3})
			_emit(KIT_EMBER, at + Vector3.UP * 0.6, Vector3.UP, Color("7a2f52"), calm, 1.0)
		"revive_start":
			var target: PaperActor = _actor(int(data.get("target", -1)))
			var spot: Vector3 = _render(target) if target else at
			if not in_range(spot): return
			pluses(spot + Vector3.UP * 0.5, 5, 0.6, 1.0)
			mark(DASHES, spot + Vector3.UP * 0.06, Color(MINT, 0.7), 0.4, 1.8, 0.5, {"normal": Vector3.UP, "add": not calm, "fade": 0.3})
		"revived":
			if not in_range(at): return
			if not calm: mark(RAYS, at + Vector3.UP * 1.0, Color("d6fff0", 0.75), 1.2, 4.2, 0.5, {"add": true, "fade": 0.25})
			sparkles(at + Vector3.UP * 1.0, MINT, 8, 0.8, 0.8)
			pluses(at + Vector3.UP * 0.6, 7, 0.7, 1.6)
			pillars(at, MINT, 6, 0.6, 2.0)
			_emit(KIT_EMBER, at + Vector3.UP * 0.8, Vector3.UP, MINT, calm, 1.3)
			word("up", at + Vector3.UP * 2.3, Color("b5ffe0"), 1.0)
		"heal":
			if float(data.get("amount", 0.0)) <= 0.0 or actor == null or not in_range(at): return
			var memory: Dictionary = _memory_of(actor.id)
			if _clock - float(memory.get("heal_at", -10.0)) < 0.45: return
			memory["heal_at"] = _clock
			pluses(at + Vector3.UP * 1.0, 3, 0.4, 1.3)
			mark(SPARKLE, at + Vector3.UP * 1.3, Color("d6fff0", 0.9), 0.3, 0.6, 0.35, {"add": true})
		"boost": _on_boost(data, actor, at)
		"boost_charge":
			if not in_range(at): return
			mark(DASHES, at + Vector3.UP * 0.05, Color("a4a0cf", 0.85), 3.2, 0.7, 0.4, {"normal": Vector3.UP, "add": not calm, "fade": 0.5})
			_emit(KIT_SPARK, at + Vector3.UP * 0.1, Vector3.UP, Color("dccbff"), true, 0.7, 80.0)
		"boost_release":
			if not in_range(at): return
			var level: int = clampi(int(data.get("level", 1)), 1, 3)
			var heading: Vector3 = _flat(actor.velocity if actor else Vector3.FORWARD, actor.aim if actor else Vector3.FORWARD)
			dust_ring(at, 0.8 + 0.3 * float(level))
			skid(at, heading)
			whoosh(at + Vector3.UP * 1.0, heading, Color("dccbff"), 3 + 2 * level, 1.8)
			mark(LINES, at + Vector3.UP * 1.0, Color("dccbff", 0.85), 1.5, 3.2 + 0.4 * float(level), 0.3, {"add": true, "fade": 0.3})
			if level >= 2: word("dash", at + Vector3.UP * 2.1, Color("dccbff"), 0.8 + 0.1 * float(level))
		"dash":
			if not in_range(at): return
			var direction: Vector3 = _flat(data.get("direction", Vector3.FORWARD))
			var body: PaperVisual = _body(actor)
			var tint: Color = tint_of(body) if body else PAPER
			whoosh(at + Vector3.UP * 1.0 + direction * 0.6, direction, tint, 6, 2.0)
			dust(at, 3, 0.8, 0.55)
			if body: _afterimage(body, tint)
		"knockback":
			if not in_range(at): return
			var direction: Vector3 = _flat(data.get("direction", Vector3.FORWARD))
			var distance: float = float(data.get("distance", 2.0))

			for k: int in range(3):
				var spot: Vector3 = at + direction * distance * (float(k) + 0.6) / 3.0
				_defer(0.14 * float(k), func() -> void : skid(spot, - direction))
		"true_form_pounce":
			if not in_range(at): return
			dust_ring(at, 1.5)
			crack(at, 2.0)
			mark(LINES, at + Vector3.UP * 1.6, Color("ff5566", 0.85), 2.2, 4.6, 0.3, {"add": not calm, "fade": 0.3})
			_rumble(at, 0.4)
		"phase6": _on_phase(data, at)
		"shadow":
			if not in_range(at) or not bool(data.get("active", false)): return

			var seconds: float = clampf(float(data.get("duration", 1.2)), 0.5, 2.0)
			mark(PUDDLE, at + Vector3.UP * 0.03, Color(SHADOW, 0.85), 0.6, 2.4, seconds, {"normal": Vector3.UP, "angle": _rng.randf() * TAU, "fade": 0.8})
			mark(DASHES, at + Vector3.UP * 0.05, Color(BLOOD_INK, 0.7), 2.6, 0.5, seconds * 0.9, {"normal": Vector3.UP, "spin": 2.0, "fade": 0.7})
		"shadow_decoys":
			var decoys: Array = data.get("decoys", [])
			for entry: Variant in decoys:
				if not entry is Dictionary: continue
				var point: Variant = (entry as Dictionary).get("position")
				if not point is Vector3 or not in_range(point): continue
				pillars(point, SHADOW, 3, 0.4, 2.2, false)
				mark(PUDDLE, (point as Vector3) + Vector3.UP * 0.03, Color(SHADOW, 0.85), 0.5, 1.6, 1.3, {"normal": Vector3.UP, "angle": _rng.randf() * TAU, "fade": 0.6})
		"minion": _on_minion(data, at)
		"spike": _on_spike(data)
		"grenade": _on_grenade(data, at)
		"flash":
			if actor == null or bool(data.get("world_only", false)) or not in_range(at): return
			var body: PaperVisual = _body(actor)
			if body == null: return
			stars(body.socket_position("over"), 3)
			mark(SWIRL, Vector3.ZERO, Color("fff6c4", 0.9), 0.3, 0.42, clampf(float(data.get("duration", 1.5)), 0.6, 2.0), {"follow": body, "socket": "over", "spin": 7.0, "fade": 0.8})
		"drone": _on_drone(data, at)
		"drone_eaten":
			if not in_range(at): return
			_emit(KIT_SPARK, at + Vector3.UP * 1.2, Vector3.UP, Color("c6b5f9"), calm, 0.9, 120.0)
			pluses(at + Vector3.UP * 1.1, 3, 0.35, 1.2)
			word("yum", at + Vector3.UP * 2.1, Color("a6f0d8"), 0.85)
		"chocolate":
			if not in_range(at): return
			for k: int in range(3):
				mark(HEART, at + Vector3.UP * 1.5 + _around(0.3), Color("ff8fb1", 0.95), 0.12, 0.26, 0.8, {"vel": Vector3.UP * _rng.randf_range(0.8, 1.4), "fade": 0.6, "ink": Color("8a2a4a"), "delay": 0.25 * float(k)})
			_defer(1.25, func() -> void : word("yum", at + Vector3.UP * 2.0, Color("ffb7cf"), 0.85))
		"overheat_charge":
			if not in_range(at): return
			mark(DASHES, at + Vector3.UP * 0.05, Color("ff9a4d", 0.85), 3.4, 0.6, 0.55, {"normal": Vector3.UP, "add": not calm, "fade": 0.6})
			mark(LINES, at + Vector3.UP * 1.0, Color("ffb46b", 0.8), 3.4, 1.4, 0.5, {"add": not calm, "fade": 0.5})
			_emit(KIT_EMBER, at + Vector3.UP * 0.8, Vector3.UP, Color("ff9a4d"), calm, 1.5)
		"overheat":
			if not in_range(at): return
			if bool(data.get("active", false)):
				mark(BURST, at + Vector3.UP * 1.0, Color("ff9a4d", 0.9), 0.6, 2.2, 0.26, {"pop": 0.5, "ink": Color("7a2a10")})
				if not calm: mark(RAYS, at + Vector3.UP * 1.0, Color("ffd2a0", 0.5), 1.0, 3.4, 0.36, {"add": true, "fade": 0.2})
				_emit(KIT_EMBER, at + Vector3.UP * 1.0, Vector3.UP, Color("ff9a4d"), calm, 1.8)
				word("hot", at + Vector3.UP * 2.2, Color("ffb46b"), 0.95)
			else:
				for k: int in range(5):
					var out: Vector3 = _around(1.0).normalized()
					mark(PUFF, at + Vector3.UP * 1.0 + out * 0.2, Color(1.0, 1.0, 1.0, 0.7), 0.25, 0.9, _rng.randf_range(0.5, 0.8), {"vel": out * 1.6 + Vector3.UP * _rng.randf_range(1.2, 2.2), "drag": 2.0, "angle": _rng.randf() * TAU, "fade": 0.3, "ink": Color("9db4c4")})
		"lysia_explosion":
			if not in_range(at): return
			var centre: Vector3 = at + Vector3.UP * 1.0
			mark(BURST, centre, Color("ffb46b", 0.92), 1.2, 4.4, 0.34, {"pop": 0.4, "ink": Color("7a2a10"), "fade": 0.5})
			if not calm: mark(RAYS, centre, Color("ffe2b5", 0.5), 3.0, 9.0, 0.45, {"add": true, "fade": 0.2})
			mark(LINES, centre, Color(PAPER, 0.8), 4.0, 8.0, 0.4, {"add": not calm, "fade": 0.3})
			for k: int in range(10):
				var angle: float = float(k) / 10.0 * TAU + _rng.randf() * 0.3
				var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
				mark(PUFF, centre + out * 0.6, Color("6a5a66", 0.85), 0.6, 1.9, _rng.randf_range(0.6, 0.95), {"vel": out * 7.0 + Vector3.UP * _rng.randf_range(0.5, 2.5), "drag": 3.2, "angle": _rng.randf() * TAU, "fade": 0.35, "ink": Color("ff9a4d")})
			crack(at, 3.6)
			dust_ring(at, 2.6)
			_emit(KIT_EMBER, centre, Vector3.UP, Color("ff9a4d"), calm, 2.4)
			_emit(KIT_SPARK, centre, Vector3.UP, Color("ffe2b5"), calm, 1.6, 180.0)
			word("boom", centre + Vector3.UP * 1.6, Color("ffcf8a"), 1.6)
			_rumble(at, 0.75, 26.0)
		"reveal": _on_reveal(data, actor, at)
		"stun_immunity":
			var body: PaperVisual = _body(actor)
			if body == null or not in_range(at): return
			mark(VEIN, Vector3.ZERO, Color("ff4a4a", 0.95), 0.24, 0.42, 1.4, {"follow": body, "socket": "over", "offset": Vector3(0.25, -0.05, 0.0), "pop": 0.6, "fade": 0.8})
			mark(BURST, at + Vector3.UP * 1.1, Color("c3344e", 0.85), 0.6, 2.0, 0.26, {"pop": 0.4, "ink": SHADOW})
			pillars(at, Color("ff4a5e"), 6, 0.6, 2.2)
		"carry":
			if not in_range(at): return
			dust(at, 3, 0.6, 0.45)
			if bool(data.get("active", false)): mark(SPARKLE, at + Vector3.UP * 1.4, Color("dccbff", 0.9), 0.3, 0.6, 0.3, {"add": true})
		"outlet_heal":
			if not in_range(at): return
			var plug: Vector3 = at + Vector3.UP * 0.8
			if actor and actor.effects.get("outlet_position") is Vector3: plug = actor.effects.get("outlet_position")
			if bool(data.get("active", false)):
				bolts(plug, Color("bff6ff"), 4, 0.35, 0.7)
				_emit(KIT_SPARK, plug, Vector3.UP, Color("d9fbff"), calm, 1.0, 150.0)
				word("zap", plug + Vector3.UP * 0.9, Color("bff6ff"), 0.8)
			else:
				sparkles(at + Vector3.UP * 1.0, Color("a6f0d8"), 4, 0.5)
		"zone":
			if not in_range(at): return
			var radius: float = float(data.get("radius", 5.0))
			for k: int in range(10):
				var angle: float = float(k) / 10.0 * TAU
				var out: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
				mark(PLUS, at + out * radius * 0.25 + Vector3.UP * 0.25, Color(MINT, 0.95), 0.14, 0.3, 0.9, {"vel": out * radius * 1.1 + Vector3.UP * 1.2, "drag": 2.2, "fade": 0.55, "ink": Color("1f6a52"), "delay": 0.02 * float(k)})
			mark(SPARKLE, at + Vector3.UP * 0.8, Color("d6fff0", 0.95), 0.5, 1.3, 0.4, {"add": true})
		"heal_channel":
			if actor == null or not in_range(at): return
			var body: PaperVisual = _body(actor)
			if body == null: return
			if bool(data.get("cancelled", false)): mark(PUFF, body.socket_position("hand_r"), Color(MINT, 0.5), 0.15, 0.5, 0.35, {"ink": Color("1f6a52")})
			else: sparkles(body.socket_position("hand_r"), MINT, 3, 0.25)
		"tracer": _on_tracer(data)
		"archive_alarm":
			if not in_range(at): return
			mark(EXCLAIM, at + Vector3.UP * 2.3, Color("ff5a4a", 0.98), 0.5, 0.95, 1.3, {"pop": 0.7, "fade": 0.75})
			if not calm: mark(RAYS, at + Vector3.UP * 1.2, Color("ff8a61", 0.6), 1.0, 4.0, 0.5, {"add": true, "fade": 0.2})
			mark(DASHES, at + Vector3.UP * 0.08, Color("f28b61", 0.85), 0.5, 3.4, 0.6, {"normal": Vector3.UP, "add": not calm, "fade": 0.3})
		"archive_qte":
			if bool(data.get("ready", false)) or actor == null: return
			var spot: Vector3 = _render(actor) + Vector3.UP * 1.2
			if not in_range(spot): return
			if bool(data.get("success", false)):
				sparkles(spot, Color("99d5bf"), 4, 0.5)
				mark(STAR, spot + Vector3.UP * 0.7, Color("ffe066", 0.98), 0.2, 0.42, 0.7, {"pop": 0.6, "vel": Vector3.UP * 0.6, "ink": Color("7a4a10")})
			else:
				sweat(spot + Vector3.UP * 0.4, 3)
				mark(EXCLAIM, spot + Vector3.UP * 0.9, Color("ff5a4a", 0.98), 0.25, 0.5, 0.9, {"pop": 0.7, "fade": 0.7})
		"objective":
			if not in_range(at): return
			var centre: Vector3 = at + Vector3.UP * 1.1
			sparkles(centre, GOLD, 8, 0.9, 0.7)
			for k: int in range(5):
				var out: Vector3 = _around(1.0).normalized()
				mark(STAR, centre, Color("ffe066", 0.98), 0.18, 0.38, 0.9, {"vel": out * 2.2 + Vector3.UP * _rng.randf_range(2.4, 3.6), "gravity": 5.5, "spin": _rng.randf_range(-7.0, 7.0), "fade": 0.65, "ink": Color("7a4a10"), "delay": 0.03 * float(k)})
			mark(DASHES, at + Vector3.UP * 0.08, Color(GOLD, 0.85), 0.4, 3.2, 0.6, {"normal": Vector3.UP, "add": not calm, "fade": 0.3})
			_emit(KIT_CONFETTI, centre, Vector3.UP, Color.WHITE, true)
			word("seal", centre + Vector3.UP * 1.3, Color("ffe9a8"), 1.0)
		"exit_state":
			var state: Variant = data.get("state")
			var open: bool = state is Dictionary and bool((state as Dictionary).get("open", false))
			var opening: bool = open and not _exit_open
			_exit_open = open
			if not opening or not at.is_finite(): return
			if not calm: mark(RAYS, at + Vector3.UP * 1.5, Color("ffe6a8", 0.7), 3.0, 11.0, 0.9, {"add": true, "fade": 0.25})
			sparkles(at + Vector3.UP * 1.4, GOLD, 10, 2.2, 1.0)
			dust_ring(at, 2.2)
			mark(LINES, at + Vector3.UP * 1.5, Color("ffe6a8", 0.8), 3.0, 7.0, 0.5, {"add": not calm, "fade": 0.3})
		"escaped":
			if not in_range(at): return
			var centre: Vector3 = at + Vector3.UP * 1.3
			for k: int in range(8):
				var out: Vector3 = _around(1.0).normalized()
				var heart: bool = k % 3 == 0
				mark(HEART if heart else STAR, centre, Color("ff8fb1" if heart else "ffe066", 0.98), 0.16, 0.36, 1.0, {"vel": out * 2.0 + Vector3.UP * _rng.randf_range(2.4, 3.8), "gravity": 5.0, "spin": 0.0 if heart else _rng.randf_range(-6.0, 6.0), "fade": 0.65, "ink": Color("8a2a4a" if heart else "7a4a10"), "delay": 0.02 * float(k)})
			sparkles(centre, GOLD, 6, 0.8, 0.8)
			word("free", centre + Vector3.UP * 1.0, Color("ffe9a8"), 1.1)
		"lms":
			if not in_range(at): return
			var centre: Vector3 = at + Vector3.UP * 1.0
			if not calm: mark(RAYS, centre, Color("ffe6a8", 0.75), 1.5, 6.0, 0.7, {"add": true, "fade": 0.25})
			mark(LINES, centre, Color(GOLD, 0.85), 2.0, 5.0, 0.5, {"add": not calm, "fade": 0.3})
			pillars(at, GOLD, 8, 0.7, 2.6)
			mark(DASHES, at + Vector3.UP * 0.06, Color(GOLD, 0.85), 0.5, 4.0, 0.7, {"normal": Vector3.UP, "add": not calm, "fade": 0.3})
			_emit(KIT_EMBER, centre, Vector3.UP, GOLD, calm, 1.8)
		"aura_unlock":
			if not in_range(at): return
			sparkles(at + Vector3.UP * 1.0, Color("ddc6ff"), 8, 0.8, 0.8)
			pillars(at, Color("ddc6ff"), 6, 0.6, 2.2)
			mark(DASHES, at + Vector3.UP * 0.06, Color("ddc6ff", 0.85), 0.4, 3.0, 0.6, {"normal": Vector3.UP, "add": not calm, "fade": 0.3})
		"door":
			if not in_range(at): return
			dust(at, 5, 1.2, 0.7)
			mark(DASHES, at + Vector3.UP * 0.08, Color("ff8a61", 0.8), 0.5, 2.8, 0.5, {"normal": Vector3.UP, "fade": 0.3})
			word("break", at + Vector3.UP * 2.2, Color("ffb46b"), 0.9)
		"land_roll":
			if not in_range(at): return
			dust_ring(at, 0.9)
			skid(at, _flat(actor.velocity if actor else Vector3.FORWARD, actor.aim if actor else Vector3.FORWARD))
		"qte":
			if bool(data.get("ready", false)) or not bool(data.get("success", false)) or not in_range(at): return
			sparkles(at + Vector3.UP * 1.0, MINT, 5, 0.6)

func _on_hit(data: Dictionary, victim: PaperActor) -> void :
	var attack: String = str(data.get("attack", "slash"))
	var at: Vector3 = _render(victim) if victim else _event_position(data, null)
	if not in_range(at): return
	var source: PaperActor = _actor(int(data.get("source", -1)))
	var from: Vector3 = data.get("source_position", _render(source) if source else at + Vector3.FORWARD)
	var toward: Vector3 = _flat(from - at, victim.aim if victim else Vector3.FORWARD)
	var low: bool = victim != null and bool(victim.effects.get("downed", false))
	var point: Vector3 = at + Vector3.UP * (0.55 if low else 1.1) + toward * 0.4
	var amount: float = float(data.get("amount", 20.0))
	var weight: float = clampf(amount / 28.0, 0.75, 1.5)
	var color: Color = HIT_TINT.get(attack, Color("ff5a78"))
	var delay: float = 0.0 if bool(data.get("indirect", false)) else _contact_delay(source)
	_defer(delay, func() -> void :
		pop(point, toward, color, weight)
		word(str(HIT_WORD.get(attack, "ouch")), point + Vector3.UP * 0.6, color.lerp(PAPER, 0.35), 0.9 * weight)
		if amount >= 25.0: stars(point + Vector3.UP * 0.7, 3)
		_hit_stop(victim, 0.05)
		if not bool(data.get("indirect", false)): _hit_stop(source, 0.07))

func _on_stun(data: Dictionary, victim: PaperActor) -> void :
	var at: Vector3 = _render(victim) if victim else _event_position(data, null)
	if not in_range(at): return
	var source: PaperActor = _actor(int(data.get("source", -1)))
	var from: Vector3 = _render(source) if source else at + Vector3.FORWARD
	var toward: Vector3 = _flat(from - at, Vector3.FORWARD)
	var body: PaperVisual = _body(victim)
	var height: float = body.visual_height() if body else 1.75
	var point: Vector3 = at + Vector3.UP * 0.62 * height + toward * 0.45
	var big: bool = victim != null and victim.killer
	var cast: String = str((_casts.get(source.id, [0.0, ""]) as Array)[1]) if source else ""
	_defer(_contact_delay(source), func() -> void :
		pop(point, toward, GOLD, 1.3 if big else 1.0)
		word("counter" if cast == "contre" else "punch" if cast in ["punch", "flash punch", "dropkick"] else "stun", point + Vector3.UP * 0.6, Color("ffe27a"), 1.1 if big else 0.95)
		stars(at + Vector3.UP * (height + 0.1), 5 if big else 4)
		_hit_stop(victim, 0.06)
		_hit_stop(source, 0.09)
		_rumble(at, 0.3 if big else 0.2, 12.0))

func _on_block(data: Dictionary, victim: PaperActor) -> void :
	var at: Vector3 = _render(victim) if victim else _event_position(data, null)
	if not in_range(at): return
	var source: PaperActor = _actor(int(data.get("source", -1)))
	var from: Vector3 = _render(source) if source else at + Vector3.FORWARD
	var toward: Vector3 = _flat(from - at, Vector3.FORWARD)
	var point: Vector3 = at + Vector3.UP * 1.2 + toward * 0.6
	var calm: bool = _calm()
	_defer(_contact_delay(source), func() -> void :
		_emit(KIT_SPARK, point, toward + Vector3.UP * 0.4, Color("fff2c4"), calm, 1.4, 75.0)
		mark(BURST, point, Color("d9f2e6", 0.95), 0.3, 1.2, 0.2, {"pop": 0.6, "ink": Color("2f6a5c")})
		mark(DASHES, point, Color("9fe3d4", 0.85), 0.5, 2.2, 0.28, {"add": not calm, "fade": 0.3})
		mark(SPARKLE, point, Color(1.0, 1.0, 1.0, 0.95), 0.4, 0.9, 0.3, {"add": true, "spin": 2.0})
		word("block", point + Vector3.UP * 0.7, Color("c8fff0"), 1.0)

		_hit_stop(source, 0.12)
		_hit_stop(victim, 0.08)
		_rumble(at, 0.22, 12.0))

func _on_grab(data: Dictionary, actor: PaperActor, at: Vector3) -> void :
	if not in_range(at): return
	var aim: Vector3 = _flat(actor.aim if actor else Vector3.FORWARD)
	if bool(data.get("charging", false)):
		dust(at, 3, 0.8, 0.5)
		whoosh(at + Vector3.UP * 1.0 + aim * 0.5, aim, Color("ffd98a"), 5, 1.6)
	elif bool(data.get("caught", false)):
		var target: PaperActor = _actor(int(data.get("target", -1)))
		var point: Vector3 = (_render(target) if target else at + aim) + Vector3.UP * 1.2
		pop(point, - aim, Color("ffd98a"), 0.9)
		word("grab", point + Vector3.UP * 0.8, Color("ffe7b0"), 0.95)
		_hit_stop(actor, 0.08)
	elif bool(data.get("released", false)):
		if bool(data.get("wall", false)):
			var wall: Vector3 = at + aim * 1.25 + Vector3.UP * 1.15
			var face: Vector3 = - aim
			var found: Dictionary = _wall_ahead(at + Vector3.UP * 1.15, aim, 2.6)
			if not found.is_empty():
				wall = found.position
				face = found.normal
			crack(wall, 2.2, face)
			pop(wall + face * 0.15, face, Color("ffd98a"), 1.4)
			stars(wall + Vector3.UP * 0.5, 4)
			dust_ring(at + aim * 0.9, 1.1)
			word("wall", wall + Vector3.UP * 0.9, Color("ffe7b0"), 1.25)
			_rumble(at, 0.5)
		else:
			dust(at + aim * 0.8, 3, 0.7, 0.5)

func _on_death(data: Dictionary, at: Vector3) -> void :
	if not in_range(at): return
	var calm: bool = _calm()
	var cause: String = str(data.get("death_kind", data.get("attack", "slash")))
	ink_puffs(at + Vector3.UP * 0.7, 7, 2.6)
	mark(BURST, at + Vector3.UP * 1.0, Color(BLOOD_INK, 0.9), 0.6, 2.3, 0.28, {"pop": 0.45, "ink": Color(SHADOW, 0.3), "fade": 0.45})
	mark(LINES, at + Vector3.UP * 1.0, Color("ff8aa0", 0.8), 1.8, 4.2, 0.36, {"add": not calm, "fade": 0.3})
	_emit(KIT_INK, at + Vector3.UP * 0.8, Vector3.UP, Color("3a1030"), false, 1.4, 90.0)

	mark(PUDDLE, at + Vector3.UP * 0.03, Color(SHADOW, 0.85), 1.3, 2.7, 4.5, {"normal": Vector3.UP, "angle": _rng.randf() * TAU, "fade": 0.75, "delay": 0.9})
	if cause == "spike": crack(at, 1.6)
	if bool(data.get("execution", false)):
		pillars(at, BLOOD_INK, 7, 0.8, 2.8, false)
		_rumble(at, 0.4)

func _on_boost(data: Dictionary, actor: PaperActor, at: Vector3) -> void :
	if not in_range(at): return
	var calm: bool = _calm()
	var caster: PaperVisual = _body(actor)
	var tint: Color = tint_of(caster) if caster else Color("83d1c8")
	mark(DASHES, at + Vector3.UP * 0.06, Color(tint, 0.9), 0.4, 2.6, 0.5, {"normal": Vector3.UP, "add": not calm, "fade": 0.3})
	pillars(at, tint.lerp(Color.WHITE, 0.4), 6, 0.55, 2.0)
	sparkles(at + Vector3.UP * 1.1, tint, 4, 0.6)
	var target_id: int = int(data.get("target", -1))
	if actor == null or target_id == actor.id or target_id < 0: return

	var from: Vector3 = _render(actor) + Vector3.UP * 1.3
	var span: Vector3 = at + Vector3.UP * 1.2 - from
	if span.length() > 0.5 and span.length() < 40.0:
		for k: int in range(4):
			mark(HEART if actor.character == "Bleuette" else SPARKLE, from + _around(0.2), Color("ff8fb1" if actor.character == "Bleuette" else "ffffff", 0.98), 0.18, 0.34, 0.5, 
				{"vel": span / 0.45 + Vector3.UP * 1.2, "gravity": 5.0, "fade": 0.75, "ink": Color("8a2a4a"), "delay": 0.05 * float(k), "add": actor.character != "Bleuette"})
	word("go", at + Vector3.UP * 2.2, tint.lerp(Color.WHITE, 0.4), 0.9)

func _on_phase(data: Dictionary, at: Vector3) -> void :
	if not at.is_finite(): return
	var calm: bool = _calm()
	var centre: Vector3 = at + Vector3.UP * 1.6
	if bool(data.get("active", false)):

		crack(at, 3.4)
		dust_ring(at, 2.2)
		mark(PUDDLE, at + Vector3.UP * 0.03, Color(SHADOW, 0.9), 1.6, 4.6, 3.2, {"normal": Vector3.UP, "angle": _rng.randf() * TAU, "fade": 0.7})
		mark(BURST, centre, Color("e0203f", 0.9), 1.0, 3.8, 0.4, {"pop": 0.4, "ink": SHADOW, "fade": 0.45})
		if not calm: mark(RAYS, centre, Color("ff6677", 0.55), 2.0, 7.0, 0.6, {"add": true, "fade": 0.2})
		mark(LINES, centre, Color("ff8a98", 0.8), 3.0, 6.5, 0.5, {"add": not calm, "fade": 0.3})
		for k: int in range(7):
			var offset: Vector3 = _around(1.6) + Vector3.UP * _rng.randf_range(0.4, 2.8)
			mark(BOLT, at + offset, Color("ff5566", 0.95), 0.7, 1.4, _rng.randf_range(0.14, 0.24), {"add": true, "angle": _rng.randf() * TAU, "delay": 0.07 * float(k), "fade": 0.4})
		pillars(at, Color("5a1024"), 8, 1.0, 3.4, false)
		_emit(KIT_EMBER, centre, Vector3.UP, Color("ff3b4f"), calm, 2.2)
		_defer(0.25, func() -> void : _emit(KIT_EMBER, centre, Vector3.UP, Color("ff3b4f"), calm, 1.6))
		_emit(KIT_INK, centre, Vector3.UP, Color("3a1030"), false, 1.6, 120.0)
		word("roar", at + Vector3.UP * 3.6, Color("ff4466"), 1.6)
		_rumble(at, 0.8, 30.0)
	else:
		ink_puffs(at + Vector3.UP * 1.0, 8, 3.2)
		mark(PUDDLE, at + Vector3.UP * 0.03, Color(SHADOW, 0.85), 1.0, 3.0, 2.4, {"normal": Vector3.UP, "angle": _rng.randf() * TAU, "fade": 0.7})
		_emit(KIT_EMBER, centre, Vector3.DOWN, Color("7a2f52"), calm, 1.0)

func _on_minion(data: Dictionary, at: Vector3) -> void :
	if not in_range(at): return
	match str(data.get("action", "")):
		"spawn":
			pillars(at, SHADOW, 4, 0.4, 2.0, false)
			mark(PUDDLE, at + Vector3.UP * 0.03, Color(SHADOW, 0.85), 0.4, 1.5, 1.2, {"normal": Vector3.UP, "angle": _rng.randf() * TAU, "fade": 0.6})
		"disperse":
			ink_puffs(at + Vector3.UP * 0.9, 6, 2.4)
			mark(PUDDLE, at + Vector3.UP * 0.03, Color(SHADOW, 0.8), 0.5, 1.5, 1.4, {"normal": Vector3.UP, "angle": _rng.randf() * TAU, "fade": 0.6})

func _on_spike(data: Dictionary) -> void :
	if bool(data.get("telegraph", false)): return
	var from: Variant = data.get("from")
	var to: Variant = data.get("to")
	if not from is Vector3 or not to is Vector3: return
	var start: Vector3 = from
	var finish: Vector3 = to
	if not in_range(finish) and not in_range(start): return
	var span: Vector3 = finish - start
	var length: float = span.length()
	if length < 0.3: return
	var along: Vector3 = span / length

	var count: int = clampi(int(length / 2.4), 1, 6)
	for k: int in range(count):
		var spot: Vector3 = start + along * length * (float(k) + 0.5) / float(count)
		spot.y = minf(start.y, finish.y)
		mark(CRACK, spot + Vector3.UP * 0.035, Color(INK, 0.85), 1.6, 1.8, 2.2, {"normal": Vector3.UP, "angle": _rng.randf() * TAU, "fade": 0.7, "delay": 0.03 * float(k)})
		mark(PUFF, spot + Vector3.UP * 0.3, Color("3a2438", 0.8), 0.4, 1.1, 0.5, {"vel": Vector3.UP * 1.6 + _around(1.0), "drag": 3.0, "angle": _rng.randf() * TAU, "fade": 0.3, "ink": BLOOD_INK, "delay": 0.03 * float(k)})
	_emit(KIT_SCRAP, finish + Vector3.UP * 0.2, Vector3.UP, _dust_color().darkened(0.3), true, 1.0, 70.0)
	if not bool(data.get("segment", false)) or _rng.randf() < 0.35:
		word("thorn", start + span * 0.5 + Vector3.UP * 2.4, Color("e58ad0"), 1.0)
	_rumble(finish, 0.16, 14.0)

func _on_grenade(data: Dictionary, at: Vector3) -> void :
	if not in_range(at): return
	var calm: bool = _calm()
	match str(data.get("action", "")):
		"bounce":
			mark(DASHES, at + Vector3.UP * 0.05, Color("dfefff", 0.8), 0.15, 0.9, 0.24, {"normal": Vector3.UP, "fade": 0.3})
			dust(at, 1, 0.4, 0.35)
			_emit(KIT_SPARK, at + Vector3.UP * 0.05, Vector3.UP, Color("fff2a8"), true, 0.5, 70.0)
		"explode":
			var centre: Vector3 = at + Vector3.UP * 0.4
			if calm:
				mark(BURST, centre, Color("3a4152", 0.8), 0.8, 3.6, 0.3, {"pop": 0.4})
			else:
				mark(RAYS, centre, Color("f2f7ff", 0.7), 2.0, 9.0, 0.4, {"add": true, "fade": 0.15})
				mark(BURST, centre, Color("ffffff", 0.9), 0.8, 2.8, 0.2, {"pop": 0.4, "ink": Color("9fb6e0")})
			mark(LINES, centre, Color("dfefff", 0.9), 3.0, 8.0, 0.4, {"add": not calm, "fade": 0.3})
			for k: int in range(8):
				var out: Vector3 = _around(1.0).normalized()
				mark(SPARKLE, centre + out * 0.4, Color("ffffff", 0.95), 0.25, 0.5, _rng.randf_range(0.5, 0.9), {"add": true, "vel": out * 3.2 + Vector3.UP * _rng.randf_range(1.0, 3.0), "gravity": 4.0, "drag": 1.5, "fade": 0.6, "delay": 0.03 * float(k)})
			dust_ring(at, 1.4)
			_emit(KIT_SPARK, centre, Vector3.UP, Color("f2f7ff"), calm, 1.5, 180.0)
			word("flash", centre + Vector3.UP * 1.4, Color("f2f7ff"), 1.3)
			_rumble(at, 0.4, 20.0)

func _on_drone(data: Dictionary, at: Vector3) -> void :
	if not in_range(at): return
	var calm: bool = _calm()
	match str(data.get("action", "")):
		"launch":
			mark(DASHES, at, Color("c6b5f9", 0.9), 0.2, 1.3, 0.3, {"add": not calm, "normal": Vector3.UP, "fade": 0.3})
			sparkles(at, Color("c6b5f9"), 3, 0.3)
		"impact":
			pop(at, Vector3.UP, Color("c6b5f9"), 0.95)
			bolts(at, Color("e6dcff"), 3, 0.45, 0.7)
			word("zap", at + Vector3.UP * 0.8, Color("e6dcff"), 0.9)
			_rumble(at, 0.2, 10.0)
		"recycled":
			sparkles(at, Color("c6b5f9"), 4, 0.4)
			pluses(at, 2, 0.3, 1.0)
		"depleted":
			mark(PUFF, at, Color("6a6478", 0.8), 0.25, 0.8, 0.6, {"vel": Vector3.UP * 0.8, "drag": 2.0, "ink": Color("2e2a3a")})
			_emit(KIT_SPARK, at, Vector3.DOWN, Color("fff2a8"), true, 0.6, 90.0)

func _on_reveal(data: Dictionary, actor: PaperActor, at: Vector3) -> void :
	if bool(data.get("killer_only", false)):

		var body: PaperVisual = _body(actor)
		if body and in_range(at): sparkles(body.socket_position("eyes"), Color("84dace"), 3, 0.25)
		return
	if not is_instance_valid(world): return

	var excluded: String = str(data.get("exclude", ""))
	var calm: bool = _calm()
	for other: PaperActor in world.actors.values():
		if other.killer or not other.alive or other.character == excluded or bool(other.effects.get("escaped", false)): continue
		var spot: Vector3 = _render(other)
		if not in_range(spot): continue
		var body: PaperVisual = _body(other)
		if body: mark(EXCLAIM, Vector3.ZERO, Color("ff5a78", 0.98), 0.3, 0.55, 1.4, {"follow": body, "socket": "over", "offset": Vector3(0.0, 0.15, 0.0), "pop": 0.7, "fade": 0.8})
		mark(DASHES, spot + Vector3.UP * 0.06, Color("c3344e", 0.85), 2.4, 0.6, 0.7, {"normal": Vector3.UP, "add": not calm, "fade": 0.6})

func _on_tracer(data: Dictionary) -> void :
	var from: Variant = data.get("from")
	var to: Variant = data.get("to")
	if not from is Vector3 or not to is Vector3: return
	var start: Vector3 = from
	var finish: Vector3 = to
	var span: Vector3 = finish - start
	var length: float = span.length()
	if length < 0.5: return
	var along: Vector3 = span / length
	var color: Color = Color("ffe6a0")

	var steps: int = clampi(int(length / 4.0), 1, 5)
	for k: int in range(steps):
		var spot: Vector3 = start + along * length * (float(k) + 0.5) / float(steps)
		if not in_range(spot): continue
		mark(STREAK, spot, Color(color, 0.85), 2.2, 3.2, 0.2, {"add": true, "axis": along, "aspect": Vector2(0.06, 1.0), "fade": 0.3, "delay": 0.012 * float(k)})
	if in_range(finish):
		pop(finish, - along, color, 0.8)
		dust(finish - Vector3.UP * 0.9, 2, 0.5, 0.5)





func _memory_of(id: int) -> Dictionary:
	if not _memory.has(id): _memory[id] = {}
	return _memory[id]


func _every(memory: Dictionary, key: String, delta: float, period: float) -> bool:
	var left: float = float(memory.get(key, 0.0)) - delta
	if left > 0.0:
		memory[key] = left
		return false
	memory[key] = period * _rng.randf_range(0.8, 1.2)
	return true


func _rising(memory: Dictionary, key: String, value: bool) -> bool:
	var before: bool = bool(memory.get(key, false))
	if before != value: memory[key] = value
	return value and not before

func update_actors(delta: float) -> void :
	if not is_instance_valid(world): return
	var light: bool = _light()
	var actors: Dictionary = world.actors
	for actor: PaperActor in actors.values():
		if not is_instance_valid(actor) or not is_instance_valid(actor.visual): continue
		var memory: Dictionary = _memory_of(actor.id)
		var at: Vector3 = _render(actor)
		var seen: bool = actor.visible and actor.visual.visible and in_range(at)
		_actor_edges(actor, memory, at, seen)
		if seen and not light: _actor_streams(actor, memory, at, delta)
	if _memory.size() > actors.size() + 4:
		for id: Variant in _memory.keys():
			if not actors.has(id): _memory.erase(id)
	if light: return
	_entity_streams(delta)


func _actor_edges(actor: PaperActor, memory: Dictionary, at: Vector3, seen: bool) -> void :
	var effects: Dictionary = actor.effects
	var alive: bool = actor.alive and not bool(effects.get("escaped", false))
	var chased: bool = _rising(memory, "chased", alive and not actor.killer and float(effects.get("chased", 0.0)) > 0.0)
	var boosted: bool = _rising(memory, "boosted", alive and float(effects.get("speed_boost", 0.0)) > 0.0)
	var blind: bool = _rising(memory, "blind", alive and float(effects.get("blind", 0.0)) > 0.0)

	if chased: actor.visual.trigger("startle")
	if not seen: return
	var body: PaperVisual = actor.visual.fx_source()
	if chased:

		mark(EXCLAIM, Vector3.ZERO, Color("ff5a4a", 0.98), 0.3, 0.55, 0.9, {"follow": body, "socket": "over", "offset": Vector3(0.0, 0.12, 0.0), "pop": 0.8, "fade": 0.75})
		sweat(body.socket_position("head"), 2)
	if boosted:
		var tint: Color = tint_of(body)
		mark(DASHES, at + Vector3.UP * 0.06, Color(tint, 0.85), 0.4, 2.2, 0.4, {"normal": Vector3.UP, "add": not _calm(), "fade": 0.3})
		pillars(at, tint.lerp(Color.WHITE, 0.4), 4, 0.5, 1.7)
	if blind: stars(body.socket_position("over"), 3)

func _actor_streams(actor: PaperActor, memory: Dictionary, at: Vector3, delta: float) -> void :
	var effects: Dictionary = actor.effects
	if not actor.alive or bool(effects.get("escaped", false)) or bool(effects.get("shadow_hide", false)): return
	var body: PaperVisual = actor.visual.fx_source()
	var calm: bool = _calm()
	var tint: Color = tint_of(body)
	var velocity: Vector3 = actor.velocity
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var heading: Vector3 = _flat(velocity, actor.aim)
	var downed: bool = bool(effects.get("downed", false))
	var chest: Vector3 = at + Vector3.UP * 1.1

	if float(effects.get("phase6", 0.0)) > 0.0:
		if _every(memory, "ember", delta, 0.2): _emit(KIT_EMBER, at + Vector3.UP * 1.5, Vector3.UP, Color("ff3b4f"), calm, 1.3)
		if _every(memory, "murk", delta, 0.4):
			mark(PUFF, at + _around(0.9, 0.3), Color("2a0f1c", 0.6), 0.4, 1.3, 0.9, {"vel": Vector3.UP * 1.3, "drag": 1.2, "angle": _rng.randf() * TAU, "fade": 0.3, "ink": Color("7a1830")})
		if speed > 6.0 and _every(memory, "streak", delta, 0.09): whoosh(at + Vector3.UP * 1.6, heading, Color("ff3355"), 2, 2.2)
		return

	if float(effects.get("overheat_time", 0.0)) > 0.0 or float(effects.get("overheat_hold", 0.0)) > 0.0 or float(effects.get("overheat_charge", 0.0)) > 0.0:
		if _every(memory, "steam", delta, 0.16): _steam(body, 2)
		if _every(memory, "ember", delta, 0.3): _emit(KIT_EMBER, chest, Vector3.UP, Color("ff9a4d"), true, 1.2)
		if _every(memory, "arc", delta, 0.42): bolts(chest, Color("ffd2a0"), 1, 0.5, 0.6)

	var boosted: bool = float(effects.get("speed_boost", 0.0)) > 0.0 or float(effects.get("boost_time", 0.0)) > 0.0
	if not downed and speed > 5.0:
		if boosted:
			if _every(memory, "streak", delta, 0.075): whoosh(chest, heading, tint, 1, 1.6)
			if _every(memory, "ghost", delta, 0.24): _afterimage(body, tint)
		elif speed > 9.5:
			if _every(memory, "streak", delta, 0.15): whoosh(chest, heading, tint, 1, 1.2)
	if actor.character == "Ashura" and float(effects.get("boost_time", 0.0)) > 0.0 and speed > 4.0:
		if _every(memory, "ribbon", delta, 0.16):
			trail(body, "foot_l", Color(tint, 0.85), 0.24, 0.16, 0.3)
			trail(body, "foot_r", Color(tint, 0.85), 0.24, 0.16, 0.3)
	if bool(effects.get("grinding", false)):
		if _every(memory, "grind", delta, 0.07): _emit(KIT_SPARK, at + Vector3.UP * 0.08, - heading + Vector3.UP * 0.6, Color("ffc46b"), true, 1.0, 32.0)

	if bool(effects.get("boost_charging", false)):
		if _every(memory, "charge", delta, 0.34):
			mark(DASHES, at + Vector3.UP * 0.05, Color(tint, 0.8), 2.6, 0.6, 0.3, {"normal": Vector3.UP, "add": not calm, "fade": 0.6})
			if int(effects.get("boost_level", 0)) >= 1: _emit(KIT_SPARK, at + Vector3.UP * 0.1, Vector3.UP, tint.lerp(Color.WHITE, 0.4), true, 0.6 + 0.25 * float(int(effects.get("boost_level", 0))), 60.0)

	if not actor.killer:
		if float(effects.get("chased", 0.0)) > 0.0 and not downed:
			if _every(memory, "sweat", delta, 1.1): sweat(body.socket_position("head"), 2)
		elif actor.max_hp > 0.0 and actor.hp / actor.max_hp < 0.35 and not downed:
			if _every(memory, "sweat", delta, 1.9): sweat(body.socket_position("head"), 1)
		if downed and _every(memory, "daze", delta, 1.7):
			mark(SWIRL, Vector3.ZERO, Color("fff6c4", 0.85), 0.24, 0.34, 1.5, {"follow": body, "socket": "over", "offset": Vector3(0.0, -0.1, 0.0), "spin": 5.0, "fade": 0.7})
		if int(effects.get("grabbed_by", -1)) >= 0 and _every(memory, "sweat", delta, 0.5): sweat(body.socket_position("head"), 2)
	if float(effects.get("blind", 0.0)) > 0.0 and _every(memory, "blind", delta, 0.5):
		mark(SPARKLE, body.socket_position("eyes") + _around(0.2), Color("fff6c4", 0.9), 0.15, 0.32, 0.4, {"add": true})

	if float(effects.get("heal_time", 0.0)) > 0.0 and _every(memory, "heal", delta, 0.17):
		var hand: Vector3 = body.socket_position("hand_r")
		var patient: PaperActor = _actor(int(effects.get("heal_target", -1)))
		var to: Vector3 = (_render(patient) + Vector3.UP * 1.0) if patient else hand + heading
		mark(PLUS, hand + _around(0.12), Color(MINT, 0.95), 0.1, 0.2, 0.5, {"vel": (to - hand) / 0.5 + Vector3.UP * 0.6, "drag": 0.5, "fade": 0.7, "ink": Color("1f6a52")})
		if patient and _every(memory, "heal_glow", delta, 0.5): mark(SPARKLE, to + _around(0.4), Color("d6fff0", 0.9), 0.25, 0.5, 0.4, {"add": true})
	if float(effects.get("outlet_healing", 0.0)) > 0.0 and _every(memory, "arc", delta, 0.24):
		bolts(chest, Color("bff6ff"), 1, 0.5, 0.6)
		var plug: Variant = effects.get("outlet_position")
		if plug is Vector3: _emit(KIT_SPARK, plug, Vector3.UP, Color("d9fbff"), true, 0.6, 120.0)

	if actor.character == "Usayuko" and float(effects.get("block", 0.0)) > 0.0 and _every(memory, "guard", delta, 0.42):
		mark(DASHES, chest + _flat(actor.aim) * 0.6, Color("9fe3d4", 0.7), 0.5, 1.5, 0.36, {"add": not calm, "fade": 0.3})

	if actor.lms and not actor.killer and not downed and _every(memory, "aura", delta, 0.36):
		mark(STREAK, at + _around(0.5, 0.15), Color(GOLD, 0.8), 0.6, 1.6, 0.45, {"add": true, "axis": Vector3.UP, "aspect": Vector2(0.1, 1.0), "vel": Vector3.UP * 2.4, "fade": 0.3})
	if actor.killer and float(effects.get("stun_immunity", 0.0)) > 0.0 and _every(memory, "aura", delta, 0.22):
		mark(STREAK, at + _around(0.6, 0.15), Color("ff4a5e", 0.8), 0.7, 1.9, 0.42, {"add": true, "axis": Vector3.UP, "aspect": Vector2(0.1, 1.0), "vel": Vector3.UP * 2.6, "fade": 0.3})

	if bool(effects.get("spike_aiming", false)) and _every(memory, "drip", delta, 0.16):
		mark(PUFF, body.socket_position("hand_r"), Color("2a1535", 0.8), 0.12, 0.42, 0.45, {"vel": Vector3.UP * 0.9 + _around(0.4), "drag": 2.0, "angle": _rng.randf() * TAU, "fade": 0.3, "ink": BLOOD_INK})


func _entity_streams(delta: float) -> void :

	var drones: Variant = host.get("drone_nodes")
	if drones is Dictionary:
		for record: Variant in (drones as Dictionary).values():
			if not record is Dictionary: continue
			var node: Variant = (record as Dictionary).get("root")
			if is_instance_valid(node) and (node as Node3D).visible and str((record as Dictionary).get("state", "")) in ["seeking", "piloted", "launch"]:
				trail(node, "", Color("b49cfb", 0.7), 0.2, 0.16, 0.34)
	var grenades: Variant = host.get("grenades")
	if grenades is Dictionary:
		for node: Variant in (grenades as Dictionary).values():
			if is_instance_valid(node) and (node as Node3D).visible: trail(node, "", Color("dfefff", 0.8), 0.2, 0.12, 0.3)

	var doubles: Variant = host.get("shadows")
	if doubles is Dictionary:
		for id: Variant in (doubles as Dictionary).keys():
			var model: Variant = (doubles as Dictionary)[id]
			if not is_instance_valid(model) or not (model as Node3D).visible: continue
			var memory: Dictionary = _memory_of(-1000 - int(id))
			if _every(memory, "drip", delta, 0.4) and in_range((model as Node3D).global_position):
				mark(PUFF, (model as Node3D).global_position + _around(0.3, 0.4), Color("2a1535", 0.7), 0.2, 0.6, 0.6, {"vel": Vector3.UP * 0.7, "drag": 1.5, "angle": _rng.randf() * TAU, "fade": 0.3, "ink": BLOOD_INK})

	_zone_clock -= delta
	if _zone_clock <= 0.0:
		_zone_clock = 0.22
		var zones: Variant = world.get("zones")
		if zones is Array:
			for entry: Variant in zones:
				if not entry is Dictionary: continue
				var position: Variant = (entry as Dictionary).get("position")
				if not position is Vector3 or not in_range(position): continue
				var radius: float = clampf(float((entry as Dictionary).get("radius", 5.0)), 0.5, 30.0)
				mark(PLUS, (position as Vector3) + _around(radius * 0.92, 0.2), Color(MINT, 0.9), 0.1, 0.24, 1.1, {"vel": Vector3.UP * _rng.randf_range(0.7, 1.2), "fade": 0.5, "ink": Color("1f6a52")})

	_exit_clock -= delta
	if _exit_clock <= 0.0:
		_exit_clock = 0.16
		var flow: Variant = world.get("exit_flow")
		var school: Variant = world.get("school")
		if flow != null and bool(flow.opened) and is_instance_valid(school):
			var base: Vector3 = school.escape_position
			if in_range(base):
				mark(SPARKLE, base + _around(2.6, _rng.randf_range(0.2, 3.2)), Color("ffe6a8", 0.95), 0.2, 0.46, _rng.randf_range(0.5, 0.9), {"add": true, "vel": Vector3.UP * 0.9, "fade": 0.6})
