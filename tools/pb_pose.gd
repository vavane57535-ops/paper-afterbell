extends Node

# Banc d'essai des clips du film (prologue, partie B) : joue UN clip sur UN personnage, hors du film,
# sur un sol quadrillé (pour juger les pieds qui glissent), et assemble une planche d'images serrées.
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --tool pb_pose \
#       --pb-who Simon --pb-clip pb_simon_chase --pb-from 0 --pb-to 2 --pb-step 0.1 [--pb-view side|front|back|three|top]
#       [--pb-path] [--pb-cols 6] [--pb-size 260x300] [--pb-zoom 2.4] [--pb-out DIR] [--pb-name planche]
# --pb-path : le personnage suit le trajet "pb_path" écrit dans la source du clip ([t, Vector3 local], -Z = avant),
#             la caméra le suit (le sol quadrillé, lui, ne bouge pas : un pied posé doit y rester immobile).
# --pb-with Nom:clip:dx:dz:yaw : un second personnage (partenaire de combat, de soin) placé à côté.

const DT: float = 1.0 / 120.0
const AnimLibrary = preload("res://anim_library.gd")

var who: String = "Simon"
var clip_name: String = ""
var from_t: float = 0.0
var to_t: float = 2.0
var step: float = 0.1
var view: String = "side"
var use_path: bool = false
var cols: int = 6
var cell: Vector2i = Vector2i(260, 300)
var zoom: float = 2.4
var out_dir: String = "/tmp/pb_pose"
var sheet_name: String = ""
var partners: Array = []
var look_height: float = 0.75
var elevation: float = 2.0
var feet_check: bool = false
var _contact: Dictionary = {}
var _slides: Array = []
var viewport: SubViewport
var camera: Camera3D

func setup(_w: Node) -> void :
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--pb-who": who = next
			"--pb-clip": clip_name = next
			"--pb-from": from_t = float(next)
			"--pb-to": to_t = float(next)
			"--pb-step": step = float(next)
			"--pb-view": view = next
			"--pb-path": use_path = true
			"--pb-cols": cols = int(next)
			"--pb-zoom": zoom = float(next)
			"--pb-look": look_height = float(next)
			"--pb-elev": elevation = float(next)
			"--pb-feet": feet_check = true
			"--pb-out": out_dir = next
			"--pb-name": sheet_name = next
			"--pb-size":
				var parts: PackedStringArray = next.split("x")
				if parts.size() == 2: cell = Vector2i(int(parts[0]), int(parts[1]))
			"--pb-with": partners.append(next.split(":"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _grid_texture() -> ImageTexture:
	var image: Image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	image.fill(Color(0.6, 0.62, 0.66))
	for y: int in range(256):
		for x: int in range(256):
			if x % 64 < 3 or y % 64 < 3: image.set_pixel(x, y, Color(0.18, 0.2, 0.26))
			elif x % 16 == 0 or y % 16 == 0: image.set_pixel(x, y, Color(0.45, 0.47, 0.52))
	return ImageTexture.create_from_image(image)

func _stage() -> Node3D:
	get_viewport().disable_3d = true
	viewport = SubViewport.new()
	viewport.size = cell
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var stage: Node3D = Node3D.new()
	viewport.add_child(stage)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.33, 0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.55
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(130.0), 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(600, 600)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = _grid_texture()
	mat.uv1_scale = Vector3(150, 150, 1)
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	return stage

func _path_at(path: Array, t: float) -> Vector3:
	if path.is_empty(): return Vector3.ZERO
	if t <= float(path[0][0]): return path[0][1]
	for k: int in range(1, path.size()):
		if t <= float(path[k][0]):
			var a: Array = path[k - 1]
			var b: Array = path[k]
			var u: float = (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			return (a[1] as Vector3).lerp(b[1], u)
	return path[path.size() - 1][1]

# Orientation écrite dans la trajectoire ([t, position, lacet]) ; NAN si la trajectoire n'en a pas.
func _yaw_at(path: Array, t: float) -> float:
	if path.is_empty() or (path[0] as Array).size() < 3: return NAN
	if t <= float(path[0][0]): return float(path[0][2])
	for k: int in range(1, path.size()):
		if t <= float(path[k][0]):
			var a: Array = path[k - 1]
			var b: Array = path[k]
			var u: float = (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			return lerp_angle(float(a[2]), float(b[2]), u)
	return float(path[path.size() - 1][2])

# Glissement des pieds : un pied est « posé » quand sa cheville est à moins de 3 cm au-dessus de sa
# hauteur de repos ; on mesure de combien il bouge (dans le plan du sol) pendant cet appui.
func _check_feet(visual: PaperVisual, t: float) -> void :
	var rest: float = 0.156 * visual._model_scale
	for socket: String in ["foot_l", "foot_r"]:
		var at: Vector3 = visual.socket_position(socket)
		var down: bool = at.y < rest + 0.03
		if down and not _contact.has(socket): _contact[socket] = [t, Vector2(at.x, at.z), 0.0]
		elif down:
			var row: Array = _contact[socket]
			row[2] = maxf(float(row[2]), Vector2(at.x, at.z).distance_to(row[1]))
		elif _contact.has(socket):
			var row: Array = _contact[socket]
			_slides.append([socket, float(row[0]), t - float(row[0]), float(row[2])])
			_contact.erase(socket)

func _actor(stage: Node3D, person: String) -> PaperVisual:
	var visual: PaperVisual = PaperVisual.new()
	visual.lod_enabled = false
	visual.fidgets = false
	stage.add_child(visual)
	visual.setup(person)
	return visual

func _run() -> void :
	var stage: Node3D = _stage()
	for i: int in range(3): await get_tree().process_frame
	var source: Dictionary = AnimLibrary.source(clip_name + "@" + who)
	if source.is_empty(): source = AnimLibrary.source(clip_name)
	if source.is_empty():
		print("PB_POSE clip introuvable : ", clip_name)
		get_tree().quit()
		return
	var path: Array = source.get("pb_path", []) if use_path else []
	var main: PaperVisual = _actor(stage, who)
	var others: Array = []
	for spec: PackedStringArray in partners:
		var other: PaperVisual = _actor(stage, spec[0])
		other.position = Vector3(float(spec[2]) if spec.size() > 2 else 1.0, 0.0, float(spec[3]) if spec.size() > 3 else 0.0)
		other.rotation.y = deg_to_rad(float(spec[4])) if spec.size() > 4 else 0.0
		var other_clip: String = spec[1] if spec.size() > 1 else ""
		var other_source: Dictionary = AnimLibrary.source(other_clip) if not other_clip.is_empty() else {}
		# Avec --pb-path, le partenaire suit aussi sa trajectoire écrite (même repère que le personnage).
		var other_path: Array = other_source.get("pb_path", []) if use_path else []
		others.append([other, other_clip, other_path])
	var times: Array[float] = []
	var at: float = from_t
	while at <= to_t + 0.0001:
		times.append(at)
		at += step
	var rows: int = ceili(float(times.size()) / float(cols))
	var sheet: Image = Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	var t: float = 0.0
	var started: bool = false
	var previous: Vector3 = _path_at(path, 0.0)
	main.position = previous
	for k: int in range(times.size()):
		var target: float = times[k]
		while t < target - 0.00001 or not started:
			if not started:
				started = true
				main.set_combat_state({})
				main.play(clip_name)
				for row: Array in others:
					(row[0] as PaperVisual).set_combat_state({})
					if not str(row[1]).is_empty(): (row[0] as PaperVisual).play(str(row[1]))
			var next: Vector3 = _path_at(path, t + DT)
			var velocity: Vector3 = (next - previous) / DT
			var written: float = _yaw_at(path, t + DT)
			if not is_nan(written): main.rotation.y = written
			elif not path.is_empty() and Vector2(velocity.x, velocity.z).length() > 0.3:
				main.rotation.y = atan2( - velocity.x, - velocity.z)
			main.position = next
			main.animate(DT, velocity, false, false)
			for row: Array in others:
				var partner: PaperVisual = row[0]
				var partner_path: Array = row[2]
				var partner_velocity: Vector3 = Vector3.ZERO
				if not partner_path.is_empty():
					var was: Vector3 = partner.position
					partner.position = _path_at(partner_path, t + DT)
					partner_velocity = (partner.position - was) / DT
					var partner_yaw: float = _yaw_at(partner_path, t + DT)
					if not is_nan(partner_yaw): partner.rotation.y = partner_yaw
				partner.animate(DT, partner_velocity, false, false)
			previous = next
			t += DT
			if feet_check: _check_feet(main, t)
		var focus: Vector3 = main.position + Vector3(0, look_height, 0)
		var basis_yaw: float = main.rotation.y
		var side_dir: Vector3 = Vector3(cos(basis_yaw), 0, - sin(basis_yaw))
		var front_dir: Vector3 = Vector3( - sin(basis_yaw), 0, - cos(basis_yaw))
		var eye: Vector3 = focus + side_dir * 8.0 + Vector3.UP * elevation
		match view:
			"front": eye = focus + front_dir * 8.0 + Vector3.UP * elevation
			"back": eye = focus - front_dir * 8.0 + Vector3.UP * elevation
			"three": eye = focus + (front_dir + side_dir).normalized() * 8.0 + Vector3.UP * elevation
			"top": eye = focus + Vector3.UP * 8.0 + front_dir * 0.01
			"left": eye = focus - side_dir * 8.0 + Vector3.UP * elevation
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = zoom
		camera.position = eye
		camera.look_at(focus)
		for warm: int in range(4 if k == 0 else 1):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, cell), Vector2i((k % cols) * cell.x, (k / cols) * cell.y))
	if feet_check:
		var worst: float = 0.0
		for row: Array in _slides:
			worst = maxf(worst, float(row[3]))
			print("PB_FOOT %s t=%.3f appui=%.3f s glisse=%.3f m" % [row[0], row[1], row[2], row[3]])
		print("PB_FEET appuis=%d glissement_max=%.3f m" % [_slides.size(), worst])
	var label: String = sheet_name if not sheet_name.is_empty() else "%s_%s_%s" % [who, clip_name, view]
	var file: String = out_dir.path_join(label + ".png")
	sheet.save_png(file)
	print("PB_POSE ", file, " images=", times.size())
	get_tree().quit()
