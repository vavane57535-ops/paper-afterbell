extends RefCounted




const G = preload("res://model_geometry.gd")
const CharMaterials = preload("res://char_materials.gd")


static var _props: Dictionary = {}
static var _aura_mesh: ArrayMesh
static var _injury_mesh: ArrayMesh
static var _cable_segment: ArrayMesh
static var _cable_plug: ArrayMesh

const PROP_NAMES: Array[String] = ["chocolate", "flash", "camera", "heal", "shotgun"]


static func prop(prop_name: String) -> Dictionary:
	if _props.is_empty():
		_build_props()
	return _props.get(prop_name, {})



static func shotgun_muzzle() -> Vector3:
	return Vector3(0, 0.032, -0.65)


static func aura_mesh() -> ArrayMesh:
	if _aura_mesh == null:
		var root: Node3D = Node3D.new()
		var mat: Material = CharMaterials.flat(Color("ddc6ff"), 1.5, false)
		G.ring(root, Vector3.ZERO, 0.58, 0.018, mat)
		for j in range(8):
			var a: float = j * TAU / 8
			G.oval(root, Vector3(cos(a) * 0.61, 0.045, sin(a) * 0.61), Vector3(0.025, 0.052, 0.025), mat)
		_aura_mesh = G.bake(root)
		root.free()
	return _aura_mesh



static func injury_mesh() -> ArrayMesh:
	if _injury_mesh == null:
		var root: Node3D = Node3D.new()
		var bruised: Material = CharMaterials.flat(Color("513a4a"), 0.0, false)
		for i in range(3):
			G.strand(root, [Vector3(-0.05, 0.03 - i * 0.027, 0), Vector3(-0.015, 0.042 - i * 0.027, -0.026), Vector3(0.035, 0.016 - i * 0.027, -0.025), Vector3(0.065, 0.011 - i * 0.027, 0)], 0.008, bruised, 0.45, 0.004, 8)
		_injury_mesh = G.bake(root)
		root.free()
	return _injury_mesh



static func cable_segment() -> ArrayMesh:
	if _cable_segment == null:
		var root: Node3D = Node3D.new()
		G.strand(root, [Vector3.ZERO, Vector3(0, 0, 0.04), Vector3(0, 0, 0.08), Vector3(0, 0, 0.13)], 0.016, CharMaterials.flat(Color("17131e")), 0.9, 0.013, 8)
		_cable_segment = G.bake(root)
		root.free()
	return _cable_segment


static func cable_plug() -> ArrayMesh:
	if _cable_plug == null:
		var root: Node3D = Node3D.new()
		G.oval(root, Vector3(0, 0, 0.155), Vector3(0.046, 0.032, 0.065), CharMaterials.flat(Color("17131e")))
		for side in [-1, 1]:
			G.line(root, [Vector3(side * 0.024, 0, 0.2), Vector3(side * 0.024, 0, 0.25)], 0.007, _metal())
		_cable_plug = G.bake(root)
		root.free()
	return _cable_plug


static func _metal() -> ShaderMaterial:
	var metal: ShaderMaterial = CharMaterials.flat(Color("adb4bc"))
	metal.set_shader_parameter("spec_amount", 0.55)
	return metal


static func _store(prop_name: String, root: Node3D, offset: Vector3, hand: String) -> void :
	_props[prop_name] = {"mesh": G.bake(root), "offset": offset, "hand": hand}
	root.free()


static func _build_props() -> void :
	var ink: Material = CharMaterials.flat(Color("17131e"))
	var paper: Material = CharMaterials.flat(Color("dddbea"))
	var white: Material = CharMaterials.flat(Color("f9f8ff"))
	var metal: Material = _metal()

	var chocolate: Node3D = Node3D.new()
	var cocoa: Material = CharMaterials.flat(Color("512b29"))
	var foil: Material = CharMaterials.flat(Color("b1a7af"))
	for row in range(3):
		for col in range(2):
			G.oval(chocolate, Vector3((col - 0.5) * 0.036, row * 0.035 - 0.035, 0), Vector3(0.022, 0.022, 0.01), cocoa)
	G.loft(chocolate, [Vector3(-0.075, 0.043, 0.014), Vector3(-0.015, 0.043, 0.014)], foil, 8)
	_store("chocolate", chocolate, Vector3(0, -0.065, -0.045), "right")

	var grenade: Node3D = Node3D.new()
	G.loft(grenade, [Vector3(-0.083, 0.041, 0.041), Vector3(-0.069, 0.05, 0.05), Vector3(0.06, 0.05, 0.05), Vector3(0.075, 0.04, 0.04)], metal, 20)
	for y in [-0.043, 0.027]:
		G.loft(grenade, [Vector3(y - 0.014, 0.052, 0.052), Vector3(y + 0.014, 0.052, 0.052)], ink, 20)
	G.line(grenade, [Vector3(0.012, 0.085, 0), Vector3(0.039, 0.076, 0), Vector3(0.055, -0.04, 0)], 0.009, paper)
	var pin: MeshInstance3D = G.ring(grenade, Vector3(-0.018, 0.096, 0), 0.025, 0.005, metal)
	pin.rotation.x = PI / 2
	_store("flash", grenade, Vector3(0, -0.03, -0.042), "right")

	var cam: Node3D = Node3D.new()
	G.oval(cam, Vector3.ZERO, Vector3(0.13, 0.08, 0.055), ink)
	var lens: MeshInstance3D = G.loft(cam, [Vector3(-0.04, 0.045, 0.045), Vector3(0.055, 0.05, 0.05)], metal, 24)
	lens.rotation.x = PI / 2
	lens.position.z = -0.06
	G.oval(cam, Vector3(0, 0, -0.12), Vector3(0.04, 0.04, 0.008), CharMaterials.flat(Color("ddc6ff"), 1.5, false))
	G.oval(cam, Vector3(-0.084, 0.035, -0.053), Vector3(0.012, 0.012, 0.006), white)
	_store("camera", cam, Vector3(0, -0.014, -0.06), "right")

	var kit: Node3D = Node3D.new()
	G.oval(kit, Vector3.ZERO, Vector3(0.13, 0.082, 0.068), paper)
	var red: Material = CharMaterials.flat(Color("ad495c"))
	G.line(kit, [Vector3(-0.047, 0, -0.069), Vector3(0.047, 0, -0.069)], 0.015, red)
	G.line(kit, [Vector3(0, -0.047, -0.069), Vector3(0, 0.047, -0.069)], 0.015, red)
	_store("heal", kit, Vector3(0, -0.03, -0.055), "left")

	var gun: Node3D = Node3D.new()
	G.strand(gun, [Vector3(0, -0.02, 0.22), Vector3(0, -0.017, 0.13), Vector3(0, 0.03, 0.05), Vector3(0, 0.035, -0.05)], 0.048, CharMaterials.flat(Color("806253")), 0.62, 0.031, 14)
	for x in [-0.024, 0.024]:
		G.line(gun, [Vector3(x, 0.032, -0.01), Vector3(x, 0.032, -0.65)], 0.023, ink)
	G.strand(gun, [Vector3(0, 0.01, -0.21), Vector3(0, 0.01, -0.27), Vector3(0, 0.01, -0.34), Vector3(0, 0.01, -0.39)], 0.041, metal, 0.8, 0.039, 12)
	G.line(gun, [Vector3(-0.025, 0, -0.08), Vector3(-0.025, -0.058, -0.09), Vector3(0.025, -0.058, -0.09), Vector3(0.025, 0, -0.08)], 0.007, metal)
	_store("shotgun", gun, Vector3(0, -0.01, -0.02), "right")
