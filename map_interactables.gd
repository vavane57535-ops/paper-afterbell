class_name PaperMapInteractables
extends Node3D




const FOREST_OUTLETS: Array[Vector3] = [Vector3(-74, 0, 80), Vector3(80, 4, -72), Vector3(74, 0, 65)]
const SCHOOL_OUTLETS: Array[Vector3] = [Vector3(-99, 0, -69.6), Vector3(99, 0, -29.6), Vector3(-99, 0, 10.4), Vector3(38, 6, -69.6), Vector3(-38, 6, -69.6)]
const PROP_RANGE: float = 45.0

var school: PaperSchool
var exit_sign: Label3D
var exit_glow: MeshInstance3D

func build(map: PaperSchool) -> void :
	school = map
	school.escape_position = Vector3(0, 0.05, 81.1) if school.map_id == "school" else Vector3(-80, 0.05, 92.1)
	school.healing_outlets.clear()

	var layout: Variant = school.get("om_layout")
	if layout != null and layout.exit_point != Vector3.ZERO:
		school.escape_position = layout.exit_point
		for point: Vector3 in layout.outlets: _socket(point, bool(layout.portable_outlets))
	elif school.map_id == "school":
		for point: Vector3 in SCHOOL_OUTLETS: _socket(point, false)
	else:
		for point: Vector3 in FOREST_OUTLETS: _socket(point, true)
	var ring: TorusMesh = TorusMesh.new();ring.inner_radius = 2.65;ring.outer_radius = 2.75;ring.rings = 32;ring.ring_segments = 6
	exit_glow = MeshInstance3D.new();exit_glow.mesh = ring;exit_glow.position = school.escape_position + Vector3.UP * 0.05;add_child(exit_glow)
	var material: StandardMaterial3D = StandardMaterial3D.new();material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color = Color("e7bc62");exit_glow.material_override = material;exit_glow.hide()
	exit_sign = Label3D.new();exit_sign.text = "SORTIE · FERMÉE";exit_sign.position = school.escape_position + Vector3.UP * 3.1;exit_sign.font_size = 42;exit_sign.pixel_size = 0.006;exit_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED;exit_sign.modulate = Color("d4c8b3");add_child(exit_sign)

func _socket(point: Vector3, portable: bool) -> void :
	school.healing_outlets.append(point)

	var metal: StandardMaterial3D = school._mat(Color("999993"))
	var dark: StandardMaterial3D = school._mat(Color("171b24"))
	var green: StandardMaterial3D = school._mat(Color("a4b383"), true)
	green.emission = Color("9fc07a")
	green.emission_energy_multiplier = 1.6
	var parts: Array[MeshInstance3D] = []
	var socket: Vector3 = point + Vector3(0, 0.85, - 0.8)
	if portable:
		parts.append(school._box(Vector3(1.15, 0.75, 0.6), point + Vector3(0, 0.375, -1), dark, true, false))
		socket = point + Vector3(0, 0.55, - 0.66)
		for side: float in [ - 0.48, 0.48]: parts.append(school._box(Vector3(0.13, 0.85, 0.66), point + Vector3(side, 0.425, -1), metal, true, false))
	else:

		parts.append(school._box(Vector3(0.04, 3.1, 0.04), socket + Vector3(0.19, 1.25, - 0.045), dark, false, false))
	parts.append(school._box(Vector3(0.32, 0.36, 0.08), socket, metal, false, false))
	for side: float in [ - 0.07, 0.07]: parts.append(school._box(Vector3(0.025, 0.055, 0.025), socket + Vector3(side, 0, 0.05), dark, false, false))
	parts.append(school._box(Vector3(0.035, 0.025, 0.02), socket + Vector3(0, 0.12, 0.053), green, false, false))
	for part: MeshInstance3D in parts:
		part.visibility_range_end = PROP_RANGE
		part.visibility_range_end_margin = 3.0
	var label: Label3D = Label3D.new();label.text = "220 V";label.font_size = 26;label.pixel_size = 0.002;label.position = socket + Vector3(0, 0.28, 0.05)
	label.visibility_range_end = 14.0
	add_child(label)

func update_exit(opened: bool, true_form: bool) -> void :
	exit_glow.visible = opened
	exit_sign.text = "SORTIE · ÉCHAPPEZ-VOUS" if opened else "SORTIE · TRUE FORM" if true_form else "SORTIE · À 01:20"
	exit_sign.modulate = Color("c25263") if true_form else Color("d8c690") if opened else Color("a8aaa8")
