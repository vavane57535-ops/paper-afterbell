extends RefCounted
class_name PaperModelGeometry


static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

static func pivot(parent: Node3D, at: Vector3 = Vector3.ZERO) -> Node3D:
	var p: = Node3D.new()
	parent.add_child(p)
	p.position = at
	return p

static func instance(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var n: = MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	n.position = at
	return n


static var _unit_sphere: SphereMesh
static var _torus_cache: Dictionary = {}

static func oval(parent: Node3D, at: Vector3, radii: Vector3, mat: Material) -> MeshInstance3D:
	if _unit_sphere == null:
		_unit_sphere = SphereMesh.new()
		_unit_sphere.radius = 1.0
		_unit_sphere.height = 2.0
		_unit_sphere.radial_segments = 24
		_unit_sphere.rings = 12
	var n: = instance(parent, _unit_sphere, mat, at)
	n.scale = radii
	return n


static func loft(parent: Node3D, rings: Array, mat: Material, sides: int = 32) -> MeshInstance3D:
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings.size() - 1):
		for s in range(sides):
			var a: = float(s) / sides * TAU
			var b: = float(s + 1) / sides * TAU
			var low: Vector3 = rings[r]
			var hi: Vector3 = rings[r + 1]
			var p0: = Vector3(cos(a) * low.y, low.x, sin(a) * low.z)
			var p1: = Vector3(cos(b) * low.y, low.x, sin(b) * low.z)
			var p2: = Vector3(cos(a) * hi.y, hi.x, sin(a) * hi.z)
			var p3: = Vector3(cos(b) * hi.y, hi.x, sin(b) * hi.z)
			_triangle(st, p0, p2, p1)
			_triangle(st, p1, p2, p3)
	for end in [0, rings.size() - 1]:
		var ring: Vector3 = rings[end]
		for s in range(sides):
			var a: = float(s) / sides * TAU
			var b: = float(s + 1) / sides * TAU
			var p0: = Vector3(cos(a) * ring.y, ring.x, sin(a) * ring.z)
			var p1: = Vector3(cos(b) * ring.y, ring.x, sin(b) * ring.z)
			if end == 0: _triangle(st, Vector3(0, ring.x, 0), p0, p1)
			else: _triangle(st, Vector3(0, ring.x, 0), p1, p0)
	st.index()
	st.generate_normals()
	return instance(parent, st.commit(), mat)

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void :
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


static func tint_height(source: MeshInstance3D, low: float, high: float, shade: Color) -> void :
	var result: = ArrayMesh.new()
	for surface in range(source.mesh.get_surface_count()):
		var arrays: Array = source.mesh.surface_get_arrays(surface)
		var colors: = PackedColorArray()
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			colors.append(Color.WHITE.lerp(shade, smoothstep(low, high, vertex.y)))
		arrays[Mesh.ARRAY_COLOR] = colors
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	source.mesh = result
	var mat: StandardMaterial3D = source.material_override.duplicate()
	mat.vertex_color_use_as_albedo = true
	source.material_override = mat


static func strand(parent: Node3D, control: Array, radius: float, mat: Material, depth: float = 0.6, end_radius: float = 0.001, steps: int = 18, sides: int = 10) -> MeshInstance3D:
	var pts: Array[Vector3] = []
	var rr: Array[float] = []
	for i in range(steps + 1):
		var t: = float(i) / steps
		var u: = 1.0 - t
		pts.append(control[0] * u * u * u + control[1] * 3 * u * u * t + control[2] * 3 * u * t * t + control[3] * t * t * t)
		rr.append(lerpf(radius, end_radius, pow(t, 1.3)) * (0.78 + 0.22 * sin(t * PI)))
	return tube(parent, pts, rr, mat, depth, sides)



static func sculpted_lock(parent: Node3D, control: Array, width: float, mat: Material, depth: float = 0.62) -> MeshInstance3D:
	var points: Array = []; var centers: Array = []
	var steps: int = 20; var sides: int = 12
	for i in range(steps + 1):
		var t: float = float(i) / steps; var u: float = 1.0 - t
		var center: Vector3 = control[0] * u * u * u + control[1] * 3.0 * u * u * t + control[2] * 3.0 * u * t * t + control[3] * t * t * t
		var tangent: Vector3 = (3.0 * u * u * (control[1] - control[0]) + 6.0 * u * t * (control[2] - control[1]) + 3.0 * t * t * (control[3] - control[2])).normalized()
		var across: Vector3 = Vector3( - tangent.y, tangent.x, 0.0).normalized()
		if across.length_squared() < 0.1: across = Vector3.RIGHT
		var normal: Vector3 = tangent.cross(across).normalized()
		var size: float = width * (0.53 + 0.65 * sin(PI * pow(t, 0.66))) * pow(1.0 - t, 0.52) + 0.0005
		var ring: Array = []
		for j in range(sides):
			var a: float = TAU * j / sides; var x: float = cos(a)
			var ridge: float = sin(a) * (1.0 - 0.18 * absf(x))
			ring.append(center + across * x * size + normal * (ridge * depth + 0.1 * sin(PI * t)) * size)
		points.append(ring);centers.append(center)
	var st: = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(steps):
		for j in range(sides):
			var k: int = (j + 1) % sides
			_triangle(st, points[i][j], points[i][k], points[i + 1][j]);_triangle(st, points[i][k], points[i + 1][k], points[i + 1][j])
	for j in range(sides):
		_triangle(st, centers[0], points[0][(j + 1) % sides], points[0][j]);_triangle(st, centers[-1], points[-1][j], points[-1][(j + 1) % sides])
	st.index();st.generate_normals();return instance(parent, st.commit(), mat)


static func ribbon(parent: Node3D, centers: Array, half_width: float, thickness: float, mat: Material) -> MeshInstance3D:
	var st: = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for center: Vector3 in centers:
		rings.append([center + Vector3(0, - half_width, - thickness), center + Vector3(0, half_width, - thickness), center + Vector3(0, half_width, thickness), center + Vector3(0, - half_width, thickness)])
	for i in range(rings.size() - 1):
		for j in range(4):
			var k: int = (j + 1) % 4
			_triangle(st, rings[i][j], rings[i + 1][j], rings[i][k]);_triangle(st, rings[i][k], rings[i + 1][j], rings[i + 1][k])
	for end in [0, rings.size() - 1]:
		_triangle(st, rings[end][0], rings[end][1], rings[end][2]);_triangle(st, rings[end][0], rings[end][2], rings[end][3])
	st.index();st.generate_normals();return instance(parent, st.commit(), mat)

static func tube(parent: Node3D, points: Array, radii: Array, mat: Material, depth: float = 1.0, sides: int = 10) -> MeshInstance3D:
	var rings: Array = []
	for i in range(points.size()):
		var tangent: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side: = Vector3( - tangent.y, tangent.x, 0.0)
		if side.length_squared() < 0.01: side = Vector3.RIGHT
		side = side.normalized()
		var normal: = tangent.cross(side).normalized()
		var ring: Array[Vector3] = []
		for j in range(sides):
			var a: = float(j) / sides * TAU
			ring.append(points[i] + side * cos(a) * float(radii[i]) + normal * sin(a) * float(radii[i]) * depth)
		rings.append(ring)
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size() - 1):
		for j in range(sides):
			var k: = (j + 1) % sides
			_triangle(st, rings[i][j], rings[i][k], rings[i + 1][j])
			_triangle(st, rings[i][k], rings[i + 1][k], rings[i + 1][j])
	for j in range(sides):
		var k: = (j + 1) % sides
		_triangle(st, points[0], rings[0][k], rings[0][j])
		_triangle(st, points[-1], rings[-1][j], rings[-1][k])
	st.index()
	st.generate_normals()
	return instance(parent, st.commit(), mat)

static func line(parent: Node3D, points: Array, radius: float, mat: Material) -> MeshInstance3D:
	var radii: Array = []
	for _p in points: radii.append(radius)
	return tube(parent, points, radii, mat, 1.0, 8)

static func polygon(parent: Node3D, vertices: Array, mat: Material, thickness: float = 0.012) -> MeshInstance3D:
	var flat: = PackedVector2Array()
	for v in vertices: flat.append(Vector2(v.x, v.y))
	var indices: = Geometry2D.triangulate_polygon(flat)
	var st: = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[i]]
		var b: Vector3 = vertices[indices[i + 1]]
		var c: Vector3 = vertices[indices[i + 2]]
		_triangle(st, a, c, b)
		_triangle(st, a + Vector3(0, 0, thickness), b + Vector3(0, 0, thickness), c + Vector3(0, 0, thickness))
	for i in range(vertices.size()):
		var a: Vector3 = vertices[i]
		var b: Vector3 = vertices[(i + 1) % vertices.size()]
		_triangle(st, a, b, a + Vector3(0, 0, thickness))
		_triangle(st, b, b + Vector3(0, 0, thickness), a + Vector3(0, 0, thickness))
	st.index()
	st.generate_normals()
	var m: = instance(parent, st.commit(), mat)
	return m

static func ring(parent: Node3D, at: Vector3, radius: float, thickness: float, mat: Material) -> MeshInstance3D:
	var key: Vector2 = Vector2(radius, thickness)
	var m: TorusMesh = _torus_cache.get(key)
	if m == null:
		m = TorusMesh.new()
		m.inner_radius = radius - thickness
		m.outer_radius = radius + thickness
		m.rings = 32
		m.ring_segments = 8
		_torus_cache[key] = m
	return instance(parent, m, mat, at)



static func head(parent: Node3D, rings: Array, mat: Material) -> MeshInstance3D:
	var st: = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for r in range(rings.size() - 1):
		for k in range(5):
			var t: float = float(k) / 5.0
			var current: Vector3 = rings[r].cubic_interpolate(rings[r + 1], rings[maxi(0, r - 1)], rings[mini(rings.size() - 1, r + 2)], t)
			rows.append(current)
	rows.append(rings[-1])
	var points: Array = []
	for row: Vector3 in rows:
		var ring: Array = []
		for i in range(64):
			var a: float = TAU * i / 64.0
			var front: float = maxf(0.0, - sin(a)); var rear: float = maxf(0.0, sin(a))
			var x: float = cos(a) * row.y
			var z: float = sin(a) * row.z
			z += rear * 0.035 * smoothstep(-0.2, 0.06, row.x)

			z -= pow(front, 5.0) * 0.015 * exp( - pow((row.x + 0.12) / 0.1, 2))
			ring.append(Vector3(x, row.x, z))
		points.append(ring)
	for r in range(points.size() - 1):
		for i in range(64):
			var j: int = (i + 1) % 64
			_triangle(st, points[r][i], points[r + 1][i], points[r][j])
			_triangle(st, points[r][j], points[r + 1][i], points[r + 1][j])
	for i in range(64):
		_triangle(st, Vector3(0, rows[0].x, 0), points[0][i], points[0][(i + 1) % 64])
		_triangle(st, Vector3(0, rows[-1].x, 0), points[-1][(i + 1) % 64], points[-1][i])
	st.index();st.generate_normals();return instance(parent, st.commit(), mat)

static func scalp(parent: Node3D, mat: Material) -> MeshInstance3D:
	var st: = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for y in range(19):
		var row: Array = []; var t: float = float(y) / 18.0
		for i in range(64):
			var a: float = TAU * i / 64.0
			var edge: float = lerpf(-0.19, 0.14, pow(maxf(0.0, - sin(a)), 0.75))
			var polar: float = acos(clampf((edge - 0.04) / 0.29, -1, 1)) * (1.0 - t)
			row.append(Vector3(cos(a) * sin(polar) * 0.298, 0.04 + cos(polar) * 0.3, 0.002 + sin(a) * sin(polar) * 0.3))
		rows.append(row)
	for y in range(18):
		for i in range(64):
			var j: int = (i + 1) % 64
			_triangle(st, rows[y][i], rows[y + 1][i], rows[y][j]);_triangle(st, rows[y][j], rows[y + 1][i], rows[y + 1][j])
	st.index();st.generate_normals();return instance(parent, st.commit(), mat)

static func foot(parent: Node3D, mat: Material, sole: bool = false) -> MeshInstance3D:
	var st: = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array = [Vector3(-0.238, 0.004, 0.008), Vector3(-0.213, 0.073, 0.03), Vector3(-0.145, 0.108, 0.047), Vector3(-0.07, 0.114, 0.071), Vector3(0.015, 0.108, 0.099), Vector3(0.09, 0.081, 0.07), Vector3(0.118, 0.005, 0.016)]
	var rows: Array = []
	for p: Vector3 in profile:
		var row: Array = []
		for j in range(32):
			var a: float = TAU * j / 32.0
			var x: float = cos(a) * p.y * (1.035 if sole else 1.0)
			var y: float = -0.077 + sin(a) * 0.025 if sole else -0.034 + maxf(0, sin(a)) * p.z + minf(0, sin(a)) * 0.025
			row.append(Vector3(x, y, p.x))
		rows.append(row)
	for i in range(rows.size() - 1):
		for j in range(32):
			var k: int = (j + 1) % 32
			_triangle(st, rows[i][j], rows[i][k], rows[i + 1][j]);_triangle(st, rows[i][k], rows[i + 1][k], rows[i + 1][j])
	for j in range(32):
		var first: Vector3 = Vector3(0, -0.077 if sole else -0.034, profile[0].x)
		var last: Vector3 = Vector3(0, -0.077 if sole else -0.034, profile[-1].x)
		_triangle(st, first, rows[0][(j + 1) % 32], rows[0][j]);_triangle(st, last, rows[-1][j], rows[-1][(j + 1) % 32])
	st.index();st.generate_normals();return instance(parent, st.commit(), mat, Vector3(0, -0.36, 0))


static func batch(parent: Node3D) -> void :
	var groups: Dictionary = {}
	for child in parent.get_children():
		if child is MeshInstance3D:
			if child.get_child_count() > 0 or child.has_meta("dynamic"): continue
			var key: Material = child.material_override
			if not groups.has(key): groups[key] = []
			groups[key].append(child)
		elif child is Node3D:
			batch(child)
	for mat in groups:
		var meshes: Array = groups[mat]
		if meshes.size() < 2: continue
		var st: = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for n in meshes:
			var normal_transform: Basis = n.transform.basis.inverse().transposed()
			for surface in range(n.mesh.get_surface_count()):
				var arrays: Array = n.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var count: int = indices.size() if not indices.is_empty() else vertices.size()
				for vertex in range(count):
					var source: int = indices[vertex] if not indices.is_empty() else vertex
					st.set_normal((normal_transform * normals[source]).normalized())
					st.add_vertex(n.transform * vertices[source])
			parent.remove_child(n)
			n.queue_free()
		st.index()
		instance(parent, st.commit(), mat)





static func bake(root: Node3D) -> ArrayMesh:
	var groups: Dictionary = {}
	var order: Array[Material] = []
	_bake_collect(root, Transform3D.IDENTITY, groups, order, true)
	var result: ArrayMesh = ArrayMesh.new()
	for mat: Material in order:
		var st: SurfaceTool = SurfaceTool.new()
		for entry: Array in groups[mat]:
			var mesh: Mesh = entry[0]
			for surface in range(mesh.get_surface_count()):
				st.append_from(mesh, surface, entry[1])
		st.commit(result)
		result.surface_set_material(result.get_surface_count() - 1, mat)
	return result

static func _bake_collect(node: Node, parent_xform: Transform3D, groups: Dictionary, order: Array[Material], is_root: bool) -> void :
	var xform: Transform3D = parent_xform
	if not is_root and node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var item: MeshInstance3D = node
		var mat: Material = item.material_override
		if mat == null:
			mat = item.mesh.surface_get_material(0)
		if not groups.has(mat):
			groups[mat] = []
			order.append(mat)
		groups[mat].append([item.mesh, xform])
	for child in node.get_children():
		_bake_collect(child, xform, groups, order, false)
