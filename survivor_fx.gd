class_name PaperSurvivorFx
extends Node3D

# Effets locaux (jamais simulés) des mécaniques 0.16 des survivants, lus dans les effets synchronisés :
# - X-ray de Lysia : les prises électriques apparaissent à travers les murs, pour Lysia seulement ;
# - prise + Ashura : arc électrique entre eux, « ASHURA ×1,5 » au-dessus de Lysia, pouce levé d'Ashura.

const Icons = preload("res://ui_icons.gd")
const T = preload("res://ui_theme.gd")
const CharMaterials = preload("res://char_materials.gd")

const OUTLET_COLOR: Color = Color("7ff2dc")
const OUTLET_WAIT_COLOR: Color = Color("f2c46d")
const LINK_COLOR: Color = Color("bff6ff")
const LINK_CORE: Color = Color("f4feff")
const XRAY_FADE_IN: float = 0.18
const XRAY_FADE_OUT: float = 0.3
const ARC_SEGMENTS: int = 11
const ARC_REFRESH: float = 0.05

var world: Node
var _markers: Array[Dictionary] = []
var _marker_key: String = ""
var _xray_alpha: float = 0.0
var _links: Dictionary = {}
var _glow_texture: GradientTexture2D
var _disc_texture: Texture2D
var _ring_texture: GradientTexture2D
var _label_clock: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(owner: Node) -> void :
	world = owner
	name = "SurvivorFx"
	_glow_texture = _radial([[0.0, Color(1, 1, 1, 1)], [0.35, Color(1, 1, 1, 0.55)], [1.0, Color(1, 1, 1, 0)]], 64)
	_disc_texture = _badge_texture()
	_ring_texture = _radial([[0.0, Color(1, 1, 1, 0)], [0.8, Color(1, 1, 1, 0)], [0.86, Color(1, 1, 1, 1)], [0.92, Color(1, 1, 1, 1)], [0.98, Color(1, 1, 1, 0)], [1.0, Color(1, 1, 1, 0)]], 128)
	set_process(not bool(world.get("dedicated")))


# Pastille unique (fond sombre, anneau clair, icône de prise) : un seul sprite, donc aucun souci de tri.
func _badge_texture() -> Texture2D:
	var size_px: int = 128
	var image: Image = Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size_px, size_px) * 0.5
	var dark: Color = Color(0.035, 0.075, 0.09, 0.9)
	for y: int in range(size_px):
		for x: int in range(size_px):
			var r: float = (Vector2(x + 0.5, y + 0.5) - center).length() / (float(size_px) * 0.5)
			var color: Color = Color(1, 1, 1, 0)
			if r < 0.72: color = dark
			elif r < 0.76: color = dark.lerp(Color.WHITE, (r - 0.72) / 0.04)
			elif r < 0.88: color = Color.WHITE
			elif r < 0.93: color = Color(1, 1, 1, 1.0 - (r - 0.88) / 0.05)
			image.set_pixel(x, y, color)
	var source: Texture2D = Icons.icon("outlet")
	if source != null:
		var icon: Image = source.get_image()
		if icon != null and not icon.is_empty():
			if icon.is_compressed(): icon.decompress()
			icon.convert(Image.FORMAT_RGBA8)
			icon.resize(66, 66, Image.INTERPOLATE_LANCZOS)
			image.blend_rect(icon, Rect2i(0, 0, 66, 66), Vector2i(31, 31))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _radial(stops: Array, size_px: int) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array(stops.map(func(stop: Array) -> float: return float(stop[0])))
	gradient.colors = PackedColorArray(stops.map(func(stop: Array) -> Color: return stop[1]))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = size_px
	texture.height = size_px
	return texture


func _process(delta: float) -> void :
	if not is_instance_valid(world): return
	var playing: bool = str(world.phase) == "playing"
	_update_xray(delta, playing)
	_update_links(delta, playing)


# Nombre de prises actuellement affichées par le X-ray (utilisé par les outils de test).
func visible_outlets() -> int:
	var count: int = 0
	for marker: Dictionary in _markers:
		if (marker.root as Node3D).visible: count += 1
	return count


func link_active(lysia_id: int) -> bool:
	return _links.has(lysia_id) and (_links[lysia_id].root as Node3D).visible




func _update_xray(delta: float, playing: bool) -> void :
	var local: PaperActor = world.local_actor() if playing else null
	var lysia: bool = local != null and local.character == "Lysia" and local.alive and not bool(local.effects.get("downed", false))
	var xray: float = float(local.effects.get("xray", 0.0)) if lysia else 0.0
	var goal: float = 1.0 if xray > 0.0 else 0.0
	if xray > 0.0 and xray < XRAY_FADE_OUT: goal = xray / XRAY_FADE_OUT
	_xray_alpha = move_toward(_xray_alpha, goal, delta / (XRAY_FADE_IN if goal > _xray_alpha else XRAY_FADE_OUT))
	if _xray_alpha <= 0.001:
		for marker: Dictionary in _markers: (marker.root as Node3D).visible = false
		return
	_ensure_markers()
	var camera: Camera3D = get_viewport().get_camera_3d()
	_label_clock -= delta
	var refresh_label: bool = _label_clock <= 0.0
	if refresh_label: _label_clock = 0.2
	var ready: bool = float(local.cooldowns.get(3, 0.0)) <= 0.0
	var tint: Color = OUTLET_COLOR if ready else OUTLET_WAIT_COLOR
	var now: float = Time.get_ticks_msec() * 0.001
	var pulse: float = 0.88 + 0.12 * sin(now * 6.0)
	for index: int in range(_markers.size()):
		var marker: Dictionary = _markers[index]
		var root: Node3D = marker.root
		root.visible = true
		var badge: Node3D = marker.badge
		var distance: float = 6.0 if camera == null else camera.global_position.distance_to(root.global_position)
		var size: float = clampf(distance * 0.12, 0.5, 6.0)
		badge.scale = Vector3.ONE * size
		badge.position.y = 0.45 + 0.8 * size
		var alpha: float = _xray_alpha * pulse
		(marker.plate_material as ShaderMaterial).set_shader_parameter("tint", Color(tint, 0.8 * _xray_alpha))
		(marker.glow as Sprite3D).modulate = Color(tint, 0.42 * alpha)
		(marker.disc as Sprite3D).modulate = Color(tint.lerp(Color.WHITE, 0.3), _xray_alpha)
		var wave: float = fmod(now / 1.4 + float(index) * 0.23, 1.0)
		var ring: Sprite3D = marker.ring
		ring.scale = Vector3.ONE * (1.0 + wave * 1.1)
		ring.modulate = Color(tint, 0.7 * (1.0 - wave) * _xray_alpha)
		var label: Label3D = marker.label
		label.modulate = Color(tint.lerp(Color.WHITE, 0.55), _xray_alpha)
		label.outline_modulate = Color(0.02, 0.05, 0.07, 0.9 * _xray_alpha)
		if refresh_label:
			var meters: int = int(round(local.global_position.distance_to(root.global_position)))
			var text: String = _tr("PRISE · %d m") % meters
			var rise: float = root.global_position.y - 0.85 - local.global_position.y
			if rise > 2.5: text += " · " + _tr("EN HAUT")
			elif rise < -2.5: text += " · " + _tr("EN BAS")
			var wait: float = float(local.cooldowns.get(3, 0.0))
			if wait > 0.0: text += " · %d s" % int(ceil(wait))
			if label.text != text: label.text = text


func _tr(text: String) -> String:
	return PaperLanguage.t(text) if PaperLanguage.language == "en" else text


func _ensure_markers() -> void :
	var school: Node = world.school
	if school == null: return
	var points: Variant = school.get("healing_outlets")
	if not points is Array: return
	var key: String = str(school.get_instance_id()) + ":" + str((points as Array).size())
	if key == _marker_key: return
	_marker_key = key
	for marker: Dictionary in _markers: (marker.root as Node3D).queue_free()
	_markers.clear()
	var offset: Vector3 = Vector3(0, 0.85, -0.8) if str(school.get("map_id")) == "school" else Vector3(0, 0.55, -0.66)
	for point: Vector3 in points: _markers.append(_make_marker(point + offset))


func _make_marker(socket: Vector3) -> Dictionary:
	var root: Node3D = Node3D.new()
	root.name = "XrayOutlet"
	add_child(root)
	root.global_position = socket
	var plate: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.46, 0.52, 0.14)
	plate.mesh = box
	var material: ShaderMaterial = CharMaterials.reveal(OUTLET_COLOR)
	material.set_shader_parameter("occluded_hint", 1.0)
	# Priorités négatives : la silhouette X-ray d'Alice (priorité 0) reste toujours dessinée par-dessus les prises.
	material.render_priority = -14
	plate.material_override = material
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate.ignore_occlusion_culling = true
	root.add_child(plate)
	var badge: Node3D = Node3D.new()
	badge.position = Vector3(0, 0.85, 0.12)
	root.add_child(badge)
	var glow: Sprite3D = _sprite(_glow_texture, 0.025, -13)
	badge.add_child(glow)
	var ring: Sprite3D = _sprite(_ring_texture, 0.0078, -12)
	badge.add_child(ring)
	var disc: Sprite3D = _sprite(_disc_texture, 0.007, -11)
	badge.add_child(disc)
	var label: Label3D = Label3D.new()
	label.text = "PRISE"
	label.font = T.font("caps")
	label.font_size = 44
	label.outline_size = 12
	label.pixel_size = 0.0062
	label.position = Vector3(0, -0.66, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.render_priority = -9
	label.outline_render_priority = -10
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.ignore_occlusion_culling = true
	badge.add_child(label)
	root.visible = false
	return {"root": root, "badge": badge, "plate_material": material, "glow": glow, "ring": ring, "disc": disc, "label": label}


func _sprite(texture: Texture2D, pixel: float, priority: int, no_depth: bool = true) -> Sprite3D:
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = pixel
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = no_depth
	sprite.shaded = false
	sprite.transparent = true
	sprite.double_sided = true
	sprite.render_priority = priority
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Les murs portent des BoxOccluder3D : sans ceci, un repère entièrement caché serait éliminé.
	sprite.ignore_occlusion_culling = no_depth
	return sprite




func _update_links(delta: float, playing: bool) -> void :
	var seen: Dictionary = {}
	if playing:
		for actor: PaperActor in world.actors.values():
			if actor.character != "Lysia" or not actor.alive or float(actor.effects.get("outlet_healing", 0.0)) <= 0.0: continue
			var partner: PaperActor = world.actors.get(int(actor.effects.get("outlet_ashura", -1)))
			if partner == null or not partner.alive: continue
			seen[actor.id] = true
			if not _links.has(actor.id): _links[actor.id] = _make_link()
			_tick_link(_links[actor.id], actor, partner, delta)
	for id: Variant in _links:
		if seen.has(id): continue
		var link: Dictionary = _links[id]
		(link.root as Node3D).visible = false
		link.partner = -1


# Poitrine animée (Lysia est agenouillée quand elle est branchée), sinon hauteur fixe.
func _chest(actor: PaperActor, fallback: float) -> Vector3:
	if is_instance_valid(actor.visual) and actor.visual.visible:
		var point: Vector3 = actor.visual.fx_source().socket_position("chest")
		if point.is_finite(): return point
	return world.actor_render_position(actor) + Vector3.UP * fallback


func _make_link() -> Dictionary:
	var root: Node3D = Node3D.new()
	root.name = "AshuraLink"
	add_child(root)
	var arc: MeshInstance3D = MeshInstance3D.new()
	var mesh: ImmediateMesh = ImmediateMesh.new()
	arc.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.disable_receive_shadows = true
	arc.material_override = material
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(arc)
	var ends: Array[Sprite3D] = []
	for i: int in range(2):
		var glow: Sprite3D = _sprite(_glow_texture, 0.012, 2, false)
		glow.modulate = Color(LINK_COLOR, 0.75)
		root.add_child(glow)
		ends.append(glow)
	var label: Label3D = Label3D.new()
	label.text = "ASHURA ×1,5"
	label.font = T.font("title")
	label.font_size = 54
	label.outline_size = 12
	label.pixel_size = 0.0046
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = LINK_COLOR
	label.outline_modulate = Color(0.03, 0.09, 0.12, 0.92)
	label.shaded = false
	label.render_priority = 4
	label.outline_render_priority = 3
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(label)
	return {"root": root, "mesh": mesh, "ends": ends, "label": label, "partner": -1, "refresh": 0.0, "age": 0.0}


func _tick_link(link: Dictionary, lysia: PaperActor, partner: PaperActor, delta: float) -> void :
	var root: Node3D = link.root
	root.visible = true
	var from: Vector3 = _chest(lysia, 1.12)
	var to: Vector3 = _chest(partner, 1.08)
	if int(link.partner) != int(partner.id):
		link.partner = int(partner.id)
		link.age = 0.0
		_link_started(lysia, partner, from, to)
	link.age = float(link.age) + delta
	var label: Label3D = link.label
	label.text = _tr("ASHURA ×1,5")
	label.global_position = world.actor_render_position(lysia) + Vector3.UP * (2.25 + 0.05 * sin(float(link.age) * 3.2))
	var appear: float = clampf(float(link.age) / 0.25, 0.0, 1.0)
	label.modulate.a = appear
	label.outline_modulate.a = 0.92 * appear
	var ends: Array[Sprite3D] = link.ends
	ends[0].global_position = from
	ends[1].global_position = to
	link.refresh = float(link.refresh) - delta
	if float(link.refresh) > 0.0: return
	link.refresh = ARC_REFRESH
	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera else from + Vector3.BACK * 4.0
	var mesh: ImmediateMesh = link.mesh
	mesh.clear_surfaces()
	if from.distance_to(to) < 0.05: return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_bolt(mesh, from, to, eye, 0.055, 0.16, Color(LINK_COLOR, 0.95 * appear))
	_bolt(mesh, from, to, eye, 0.022, 0.1, Color(LINK_CORE, 0.9 * appear))
	_bolt(mesh, from, to, eye, 0.03, 0.24, Color(LINK_COLOR, 0.45 * appear))
	mesh.surface_end()


# Ruban en zigzag tourné vers la caméra, plus large au centre, pour un arc électrique « BD ».
func _bolt(mesh: ImmediateMesh, from: Vector3, to: Vector3, eye: Vector3, width: float, jitter: float, color: Color) -> void :
	var span: Vector3 = to - from
	if span.length() < 0.05: return
	var points: Array[Vector3] = []
	for i: int in range(ARC_SEGMENTS + 1):
		var t: float = float(i) / float(ARC_SEGMENTS)
		var point: Vector3 = from + span * t + Vector3.UP * sin(t * PI) * 0.22
		if i > 0 and i < ARC_SEGMENTS:
			var side: Vector3 = span.cross(eye - point).normalized()
			point += side * _rng.randf_range(-jitter, jitter) * sin(t * PI) + Vector3.UP * _rng.randf_range(-jitter, jitter) * 0.6
		points.append(point)
	for i: int in range(ARC_SEGMENTS):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var side_a: Vector3 = (b - a).cross(eye - a).normalized() * width
		var side_b: Vector3 = (b - a).cross(eye - b).normalized() * width
		var tail: Color = Color(color, color.a * (0.55 if i == 0 or i == ARC_SEGMENTS - 1 else 1.0))
		for vertex: Vector3 in [a - side_a, a + side_a, b + side_b, a - side_a, b + side_b, b - side_b]:
			mesh.surface_set_color(tail)
			mesh.surface_add_vertex(vertex)


func _link_started(lysia: PaperActor, partner: PaperActor, from: Vector3, to: Vector3) -> void :
	var middle: Vector3 = from.lerp(to, 0.5) + Vector3.UP * 0.2
	var presentation: Variant = world.get("presentation")
	var comic: Variant = presentation.get("comic") if presentation != null else null
	if comic != null:
		comic.bolts(middle, LINK_COLOR, 3, 0.45, 0.6)
		comic.word("zap", middle + Vector3.UP * 0.7, LINK_COLOR, 0.75)
	var audio: Variant = world.get("audio")
	if audio != null and world.has_method("_listener_position"):
		audio.sfx("camera_switch", middle, world._listener_position(), 0.4, 1.3)
	var speed: float = Vector2(partner.velocity.x, partner.velocity.z).length()
	var busy: bool = bool(partner.effects.get("drone_piloting", false)) or bool(partner.effects.get("boost_charging", false)) or bool(partner.effects.get("grinding", false))
	if is_instance_valid(partner.visual) and speed < 1.2 and not busy and not partner.visual.is_performing_action():
		partner.visual.trigger("thumbsup")
