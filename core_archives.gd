extends RefCounted








const STATE_IDLE: int = 0
const STATE_PROGRESS: int = 1
const STATE_DONE: int = 2
const STATE_LOCKED: int = 3
const TEAL: Color = Color("8ed2ce")
const GOLD: Color = Color("e6c77a")
const RED: Color = Color("ff6272")
const LABEL_RANGE: float = 28.0
const RING_SIZE: float = 2.9

const SEAL_SHADER: String = "\nshader_type spatial;\nrender_mode unshaded, shadows_disabled, cull_back;\n\nuniform vec4 tint : source_color = vec4(0.37, 0.95, 0.87, 1.0);\nuniform float pulse_speed = 0.5;\nuniform float pulse_depth = 0.25;\nuniform float spin = 0.8;\nuniform float bob = 0.035;\n\nvoid vertex() {\n\t// Each archive gets its own phase from its world position.\n\tfloat phase = dot(MODEL_MATRIX[3].xz, vec2(0.37, 0.61));\n\tfloat a = TIME * spin + phase;\n\tfloat c = cos(a);\n\tfloat s = sin(a);\n\tVERTEX.xz = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xz;\n\tNORMAL.xz = mat2(vec2(c, s), vec2(-s, c)) * NORMAL.xz;\n\tVERTEX.y += sin(TIME * 1.3 + phase) * bob;\n}\n\nvoid fragment() {\n\tfloat phase = dot(MODEL_MATRIX[3].xz, vec2(0.37, 0.61));\n\tfloat wave = 0.5 + 0.5 * sin(TIME * pulse_speed * 6.2831853 + phase);\n\tfloat facing = abs(dot(NORMAL, VIEW));\n\tALBEDO = tint.rgb * (1.0 - pulse_depth + 2.0 * pulse_depth * wave) * (0.62 + 0.38 * facing);\n}\n"




























const RING_SHADER: String = "\nshader_type spatial;\nrender_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;\n\nuniform float progress = 0.0;\nuniform vec4 track_color : source_color = vec4(0.36, 0.84, 0.8, 0.2);\nuniform vec4 fill_color : source_color = vec4(0.5, 1.0, 0.93, 0.85);\nuniform float flash = 0.0;\n\nvoid fragment() {\n\tvec2 p = UV * 2.0 - 1.0;\n\tfloat r = length(p);\n\tfloat w = max(fwidth(r), 0.001) * 1.2;\n\tfloat band = smoothstep(0.8 - w, 0.8, r) * (1.0 - smoothstep(0.96 - w, 0.96, r));\n\tfloat guide = smoothstep(0.69 - w, 0.69, r) * (1.0 - smoothstep(0.71 - w, 0.71, r)) * 0.45;\n\tfloat mask = max(band, guide);\n\tif (mask < 0.004) {\n\t\tdiscard;\n\t}\n\tfloat angle = fract(atan(p.x, -p.y) / 6.2831853 + 1.0);\n\tfloat filled = step(angle, progress) * band;\n\tfloat tick = (1.0 - smoothstep(0.0, 0.01, abs(fract(angle * 5.0 + 0.5) - 0.5))) * band;\n\tfloat blink = 1.0 - flash * 0.45 * (1.0 + sin(TIME * 9.0));\n\tvec4 color = mix(track_color, fill_color, filled);\n\tALBEDO = color.rgb + vec3(tick * 0.2);\n\tALPHA = clamp(color.a * mask * blink + tick * 0.2, 0.0, 1.0);\n}\n"




























static var _cabinet_mesh: ArrayMesh
static var _cabinet_material: Material
static var _trim_materials: Array[StandardMaterial3D] = []
static var _seal_mesh: ArrayMesh
static var _seal_materials: Array[ShaderMaterial] = []
static var _ring_shader: Shader
static var _ring_mesh: PlaneMesh

var nodes: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _seals: Array[MeshInstance3D] = []
var _cabinets: Array[MeshInstance3D] = []
var _rings: Array[ShaderMaterial] = []
var _signatures: PackedInt64Array = PackedInt64Array()

func build(parent: Node, positions: Array[Vector3], map_center: Vector3) -> Array[Node3D]:
	_ensure_shared()
	clear()
	for index: int in range(positions.size()):
		var node: Node3D = Node3D.new()
		node.name = "Archive_" + str(index + 1)
		parent.add_child(node)
		node.position = positions[index]

		var to_center: Vector3 = map_center - positions[index]
		to_center.y = 0.0
		if to_center.length_squared() > 0.01:
			node.rotation.y = atan2(to_center.x, to_center.z)
		var cabinet: MeshInstance3D = MeshInstance3D.new()
		cabinet.name = "Cabinet"
		cabinet.mesh = _cabinet_mesh
		cabinet.set_surface_override_material(0, _cabinet_material)
		cabinet.set_surface_override_material(1, _trim_materials[STATE_IDLE])
		node.add_child(cabinet)
		var seal: MeshInstance3D = MeshInstance3D.new()
		seal.name = "Seal"
		seal.mesh = _seal_mesh
		seal.material_override = _seal_materials[STATE_IDLE]
		seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seal.position = Vector3(0.0, 1.78, 0.0)
		node.add_child(seal)
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.name = "ProgressRing"
		ring.mesh = _ring_mesh
		var ring_material: ShaderMaterial = ShaderMaterial.new()
		ring_material.shader = _ring_shader
		ring.material_override = ring_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = Vector3(0.0, 0.03, 0.0)
		node.add_child(ring)
		var label: Label3D = Label3D.new()
		label.name = "Label"
		label.text = "◈ ARCHIVE " + str(index + 1)
		label.font_size = 30
		label.outline_size = 9
		label.outline_modulate = Color(0.03, 0.04, 0.07, 0.85)
		label.fixed_size = true
		label.pixel_size = 0.0011
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = TEAL
		label.position = Vector3(0.0, 2.3, 0.0)
		label.visibility_range_end = LABEL_RANGE
		label.visibility_range_end_margin = 3.0
		label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.add_child(label)
		nodes.append(node)
		_labels.append(label)
		_seals.append(seal)
		_cabinets.append(cabinet)
		_rings.append(ring_material)
		_signatures.append(-1)
	return nodes

func clear() -> void :
	for node: Node3D in nodes:
		if is_instance_valid(node):
			var parent: Node = node.get_parent()
			if parent:
				parent.remove_child(node)
			node.queue_free()
	nodes.clear()
	_labels.clear()
	_seals.clear()
	_cabinets.clear()
	_rings.clear()
	_signatures.clear()


func sync(progress: Dictionary, done: Array[int], world: Node) -> void :
	for index: int in range(nodes.size()):
		var state: int = STATE_IDLE
		var value: int = 0
		var locked: float = float(world.archive_lock_remaining(index)) if world else 0.0
		var amount: float = clampf(float(progress.get(index, 0.0)), 0.0, 1.0)
		if done.has(index):
			state = STATE_DONE
		elif locked > 0.0:
			state = STATE_LOCKED
			value = int(ceil(locked * 10.0))
		elif amount > 0.0:
			state = STATE_PROGRESS
			value = int(amount * 1000.0)
		var signature: int = state * 100000 + value
		if signature == _signatures[index]:
			continue
		_signatures[index] = signature
		_apply(index, state, amount, locked)

func _apply(index: int, state: int, amount: float, locked: float) -> void :
	var label: Label3D = _labels[index]
	var ring: ShaderMaterial = _rings[index]
	_seals[index].material_override = _seal_materials[state]
	_cabinets[index].set_surface_override_material(1, _trim_materials[state])
	var text: String = "◈ ARCHIVE " + str(index + 1)
	var color: Color = TEAL
	var fill: Color = Color(0.5, 1.0, 0.93, 0.85)
	var track: Color = Color(0.36, 0.84, 0.8, 0.2)
	var shown: float = amount
	var flash: float = 0.0
	match state:
		STATE_PROGRESS:
			text += " · " + str(int(amount * 100.0)) + " %"
		STATE_DONE:
			text = "✓ ARCHIVE SCELLÉE"
			color = GOLD
			fill = Color(0.95, 0.8, 0.45, 0.55)
			track = fill
			shown = 1.0
		STATE_LOCKED:
			text = "ARCHIVE BLOQUÉE · %.1f s" % locked
			color = RED
			fill = Color(1.0, 0.3, 0.38, 0.9)
			track = Color(1.0, 0.3, 0.38, 0.3)
			flash = 1.0

	if label.get_meta("core_source", "") != text:
		label.set_meta("core_source", text)
		label.text = text
	label.modulate = color
	ring.set_shader_parameter("progress", shown)
	ring.set_shader_parameter("fill_color", fill)
	ring.set_shader_parameter("track_color", track)
	ring.set_shader_parameter("flash", flash)

static func _ensure_shared() -> void :
	if _cabinet_mesh != null:
		return
	_cabinet_mesh = _build_cabinet()
	var base_material: StandardMaterial3D = StandardMaterial3D.new()
	base_material.vertex_color_use_as_albedo = true
	base_material.albedo_color = Color.WHITE
	base_material.roughness = 0.95
	_cabinet_material = PaperToon.material(base_material, false)

	_trim_materials.clear()
	for trim_color: Color in [Color("4fcfc2"), Color("8afbee"), Color("f0c96a"), Color("ff5064")]:
		var trim: StandardMaterial3D = StandardMaterial3D.new()
		trim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		trim.albedo_color = trim_color
		_trim_materials.append(trim)
	_seal_mesh = _build_seal()
	var seal_shader: Shader = Shader.new()
	seal_shader.code = SEAL_SHADER
	_seal_materials.clear()

	for spec: Array in [[Color("5ff0da"), 0.45, 0.22, 0.8], [Color("7dfbe8"), 1.1, 0.3, 1.6], [Color("f2cf6b"), 0.2, 0.06, 0.25], [Color("ff4a5e"), 2.2, 0.4, 0.0]]:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = seal_shader
		material.set_shader_parameter("tint", spec[0])
		material.set_shader_parameter("pulse_speed", spec[1])
		material.set_shader_parameter("pulse_depth", spec[2])
		material.set_shader_parameter("spin", spec[3])
		_seal_materials.append(material)
	_ring_shader = Shader.new()
	_ring_shader.code = RING_SHADER
	_ring_mesh = PlaneMesh.new()
	_ring_mesh.size = Vector2(RING_SIZE, RING_SIZE)



static func _build_cabinet() -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow: SurfaceTool = SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ink: Color = Color("20262f")
	var body: Color = Color("4a6469")
	var cream: Color = Color("d2c7aa")
	var card: Color = Color("f0e9d6")
	_box(tool, Vector3(0.88, 0.07, 0.54), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.035, 0.0)), ink)
	_box(tool, Vector3(0.8, 1.06, 0.46), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.6, 0.0)), body)
	_box(tool, Vector3(0.88, 0.05, 0.54), Transform3D(Basis.IDENTITY, Vector3(0.0, 1.155, 0.0)), ink)
	for drawer_y: float in [0.3, 0.62, 0.94]:
		_box(tool, Vector3(0.68, 0.27, 0.03), Transform3D(Basis.IDENTITY, Vector3(0.0, drawer_y, 0.245)), cream)
		_box(tool, Vector3(0.2, 0.04, 0.04), Transform3D(Basis.IDENTITY, Vector3(0.0, drawer_y + 0.065, 0.275)), ink)
		_box(glow, Vector3(0.15, 0.07, 0.012), Transform3D(Basis.IDENTITY, Vector3(-0.21, drawer_y - 0.04, 0.265)), card)

	_box(glow, Vector3(0.9, 0.022, 0.02), Transform3D(Basis.IDENTITY, Vector3(0.0, 1.13, 0.275)), card)
	_box(glow, Vector3(0.02, 0.022, 0.56), Transform3D(Basis.IDENTITY, Vector3(0.445, 1.13, 0.0)), card)
	_box(glow, Vector3(0.02, 0.022, 0.56), Transform3D(Basis.IDENTITY, Vector3(-0.445, 1.13, 0.0)), card)
	var box_a: Basis = Basis(Vector3.UP, 0.13)
	_box(tool, Vector3(0.44, 0.24, 0.34), Transform3D(box_a, Vector3(-0.14, 1.3, 0.02)), Color("b08e5c"))
	_box(tool, Vector3(0.46, 0.035, 0.36), Transform3D(box_a, Vector3(-0.14, 1.43, 0.02)), Color("8f7147"))
	var box_b: Basis = Basis(Vector3.UP, -0.22)
	_box(tool, Vector3(0.3, 0.17, 0.27), Transform3D(box_b, Vector3(0.21, 1.265, -0.05)), Color("c4a674"))
	_box(tool, Vector3(0.25, 0.05, 0.2), Transform3D(Basis(Vector3.UP, 0.1), Vector3(0.2, 1.375, -0.03)), card)
	tool.index()
	var mesh: ArrayMesh = tool.commit()
	glow.index()
	return glow.commit(mesh)


static func _box(tool: SurfaceTool, size: Vector3, xform: Transform3D, color: Color) -> void :
	var half: Vector3 = size * 0.5
	var linear: Color = color.srgb_to_linear()


	var faces: Array[Array] = [
		[Vector3.RIGHT, Vector3.UP, Vector3.FORWARD], [Vector3.LEFT, Vector3.UP, Vector3.BACK], 
		[Vector3.UP, Vector3.FORWARD, Vector3.RIGHT], [Vector3.DOWN, Vector3.BACK, Vector3.RIGHT], 
		[Vector3.BACK, Vector3.UP, Vector3.RIGHT], [Vector3.FORWARD, Vector3.UP, Vector3.LEFT], 
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var up: Vector3 = face[1]
		var side: Vector3 = face[2]
		var center: Vector3 = normal * half
		var extent_up: Vector3 = up * half
		var extent_side: Vector3 = side * half
		var corners: Array[Vector3] = [center - extent_side - extent_up, center + extent_side - extent_up, center + extent_side + extent_up, center - extent_side + extent_up]
		var world_normal: Vector3 = (xform.basis * normal).normalized()
		for corner_index: int in [0, 2, 1, 0, 3, 2]:
			tool.set_color(linear)
			tool.set_normal(world_normal)
			tool.add_vertex(xform * corners[corner_index])


static func _build_seal() -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: Vector3 = Vector3(0.0, 0.19, 0.0)
	var bottom: Vector3 = Vector3(0.0, -0.19, 0.0)
	var ring: Array[Vector3] = [Vector3(0.13, 0.0, 0.0), Vector3(0.0, 0.0, 0.13), Vector3(-0.13, 0.0, 0.0), Vector3(0.0, 0.0, -0.13)]
	for index: int in range(4):
		var a: Vector3 = ring[index]
		var b: Vector3 = ring[(index + 1) % 4]
		_outward_triangle(tool, top, a, b)
		_outward_triangle(tool, bottom, a, b)
	return tool.commit()



static func _outward_triangle(tool: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void :
	var normal: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
	var order: Array[Vector3] = [p0, p1, p2]
	if normal.dot(p0 + p1 + p2) > 0.0:

		order = [p0, p2, p1]
	else:
		normal = - normal
	for point: Vector3 in order:
		tool.set_normal(normal)
		tool.add_vertex(point)
