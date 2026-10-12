extends Node3D
class_name PaperImportedCharacter





const CharMaterials = preload("res://char_materials.gd")
const EYE_LID = preload("res://eye_lid.gdshader")

const KIND_NONE: int = 0
const KIND_FINGER: int = 1
const KIND_CLOTH: int = 2
const KIND_EAR: int = 3
const KIND_BRAID: int = 4
const KIND_HAIR: int = 5

const MODE_CONSTANT: int = 0
const MODE_DRIVEN: int = 1
const MODE_SPRING: int = 2
const MODE_FINGER: int = 3
const MODE_TWIST: int = 4


const GROUP_FALLBACK: Dictionary = {"spine": "body", "chest": "spine", "neck": "head", "left_toe": "left_ankle", "right_toe": "right_ankle", "left_clav": "chest", "right_clav": "chest"}
const FACE_LABELS: Array[String] = ["Blink", "Pain", "Fear", "Angry", "Smile", "JawOpen"]

var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var model_name: String

var secondary_detail: bool = true
var _bone_rest: Array[Transform3D] = []
var _bone_groups: Array[String] = []
var _rest_proxy: Dictionary = {}
var _joints: Dictionary = {}
var _skeleton_frame: Transform3D
var _hair_angle: float = 0.0
var _hand_gesture: String = ""
var _hand_weight: float = 0.0
var _hand_shapes: Array[MeshInstance3D] = []
var _face_mood: String = "neutral"
var _blink: float = 0.0
var _finger_curl: float = 0.12
var _finger_curl_left: float = 0.12
var _secondary_sway: float = 0.0
var _skeleton_inverse: Transform3D
var _parents: PackedInt32Array = PackedInt32Array()
var _secondary_kind: PackedInt32Array = PackedInt32Array()
var _finger_kind: PackedInt32Array = PackedInt32Array()
var _finger_joint: PackedInt32Array = PackedInt32Array()





const FINGER_BEND: Array[float] = [1.2, 1.45, 0.95]
const THUMB_BEND: Array[float] = [0.45, 0.55, 0.65]
var _finger_axis: Array[Vector3] = []
var _thumb_side: PackedFloat32Array = PackedFloat32Array()
var _chain_rest: Array[Transform3D] = []
var _bound_joints: Array[Node3D] = []
var _proxy_inverse: Array[Transform3D] = []
var _group_indices: PackedInt32Array = PackedInt32Array()
var _deltas: Array[Transform3D] = []
var _poses: Array[Transform3D] = []
var _pose_inverse: Array[Transform3D] = []
var _last_scales: Array[Vector3] = []
var _face_shapes: Array[Dictionary] = []
var _face_initialized: bool = false

var _fast: bool = false
var _mode: PackedInt32Array = PackedInt32Array()
var _driven: PackedInt32Array = PackedInt32Array()
var _springs: PackedInt32Array = PackedInt32Array()
var _fingers: PackedInt32Array = PackedInt32Array()
var _twists: PackedInt32Array = PackedInt32Array()
var _parent_group: PackedInt32Array = PackedInt32Array()
var _rest_parent_inv: Array[Transform3D] = []
var _rest_rotation_inv: Array[Basis] = []
var _delta_inverse: Array[Transform3D] = []
var _is_right: PackedByteArray = PackedByteArray()
var _fingers_dirty: bool = true
var _twist_dirty: bool = true
var _twist_left: float = 0.0
var _twist_right: float = 0.0
var _twist_axis: Array[Vector3] = []
var _twist_share: PackedFloat32Array = PackedFloat32Array()

var _spring_dir: Array[Vector3] = []
var _spring_offset: Array[Vector3] = []
var _spring_speed: Array[Vector3] = []
var _spring_omega: PackedFloat32Array = PackedFloat32Array()
var _spring_zeta: PackedFloat32Array = PackedFloat32Array()
var _spring_gain: PackedFloat32Array = PackedFloat32Array()
var _spring_drag: PackedFloat32Array = PackedFloat32Array()
var _spring_side: PackedFloat32Array = PackedFloat32Array()
var _motion_accel: Vector3 = Vector3.ZERO
var _motion_velocity: Vector3 = Vector3.ZERO
var _motion_yaw_rate: float = 0.0
var _motion_dt: float = 0.0
var _motion_clock: float = 0.0
var _cloth_drive: Vector2 = Vector2.ZERO

var _lids: Array[ShaderMaterial] = []
var _lid_state: Vector3 = Vector3(-1, -1, -1)

var eyelids: bool = true

func setup(person: String) -> void :
	model_name = person
	var packed: PackedScene = load("res://models/supplied/" + person + ".glb")
	var scene: Node3D = packed.instantiate()
	add_child(scene)
	_scan(scene)
	_skeleton_frame = global_transform.affine_inverse() * skeleton.global_transform
	_skeleton_inverse = _skeleton_frame.affine_inverse()
	for i in range(skeleton.get_bone_count()):
		_bone_rest.append(_skeleton_frame * skeleton.get_bone_global_rest(i))
		var label: String = skeleton.get_bone_name(i)
		_bone_groups.append(_group(label))
		_parents.append(skeleton.get_bone_parent(i))
		_secondary_kind.append(KIND_FINGER if _is_finger(label) else KIND_CLOTH if "Cloth" in label else KIND_EAR if "Ear" in label else KIND_BRAID if "Braid" in label else KIND_HAIR if label.begins_with("HairBack") else KIND_NONE)
		_finger_kind.append(1 if "Thumb" in label else 2 if "Index" in label else 0)
		_finger_joint.append(2 if label.ends_with("03") else 1 if label.ends_with("02") else 0)
		_thumb_side.append(1.0 if label.begins_with("L_") else -1.0)
		_is_right.append(1 if label.begins_with("R_") else 0)
	for i in range(_bone_rest.size()):
		_chain_rest.append(_bone_rest[_parents[i]].affine_inverse() * _bone_rest[i] if _parents[i] >= 0 else _bone_rest[i])
		_poses.append(Transform3D.IDENTITY)
		_pose_inverse.append(Transform3D.IDENTITY)
		_last_scales.append(Vector3(INF, INF, INF))
	_prepare_finger_axes()
	for mesh in meshes:
		mesh.extra_cull_margin = 1.5
		mesh.set_meta("dynamic", true)
		for surface in range(mesh.mesh.get_surface_count()):
			var source: Material = mesh.get_active_material(surface)
			mesh.set_surface_override_material(surface, CharMaterials.skin(source))
		for shape in range(mesh.mesh.get_blend_shape_count()):
			var label: String = mesh.mesh.get_blend_shape_name(shape)
			if label in ["Blink", "Pain", "Fear", "Angry", "Smile", "JawOpen"]:
				_face_shapes.append({"mesh": mesh, "index": shape, "label": label, "value": -1.0, "slot": FACE_LABELS.find(label)})
	if eyelids: _build_eyelids(person)


func set_eyelids(top: float, bottom: float, tilt: float) -> void :
	if _lids.is_empty(): return
	var state: Vector3 = Vector3(top, bottom, tilt)
	if state.distance_squared_to(_lid_state) < 2e-05: return
	_lid_state = state
	for material: ShaderMaterial in _lids:
		material.set_shader_parameter("top", top)
		material.set_shader_parameter("bottom", bottom)
		material.set_shader_parameter("tilt", tilt)

func has_eyelids() -> bool:
	return not _lids.is_empty()



func _build_eyelids(person: String) -> void :
	var path: String = "res://models/eyes/%s.json" % person
	if not FileAccess.file_exists(path): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	var head: int = skeleton.find_bone("Head")
	if head < 0: return
	var attach: BoneAttachment3D = BoneAttachment3D.new()
	attach.name = "Eyelids"
	skeleton.add_child(attach)
	attach.bone_name = "Head"
	var bone_scale: float = (_skeleton_frame * skeleton.get_bone_global_rest(head)).basis.get_scale().x
	for eye: Dictionary in (data as Dictionary).get("eyes", []):
		var cols: int = int(eye.cols)
		var rows: int = int(eye.rows)
		var pts: Array = eye.points
		var normal: Vector3 = Vector3(float(eye.normal[0]), float(eye.normal[1]), float(eye.normal[2])).normalized()
		var grid: Array[Vector3] = []
		var ok: Array[bool] = []
		for pt: Array in pts:
			grid.append(Vector3(float(pt[0]), float(pt[1]), float(pt[2])))
			ok.append(int(pt[3]) == 1)

		for sweep: int in range(6):
			for k: int in range(grid.size()):
				if ok[k]: continue
				var sum: float = 0.0
				var n: int = 0
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var c: int = k % cols + d.x
					var r: int = k / cols + d.y
					if c < 0 or r < 0 or c >= cols or r >= rows: continue
					var j: int = r * cols + c
					if ok[j]:
						sum += grid[j].z
						n += 1
				if n > 0:
					grid[k].z = sum / float(n)
					ok[k] = true

		var normals: Array[Vector3] = []
		for k: int in range(grid.size()):
			var c0: int = k % cols
			var r0: int = k / cols
			var across: Vector3 = grid[r0 * cols + mini(c0 + 1, cols - 1)] - grid[r0 * cols + maxi(c0 - 1, 0)]
			var down: Vector3 = grid[mini(r0 + 1, rows - 1) * cols + c0] - grid[maxi(r0 - 1, 0) * cols + c0]
			var n_k: Vector3 = across.cross(down).normalized()
			if n_k.dot(normal) < 0.0: n_k = - n_k
			normals.append(n_k.lerp(normal, 0.35).normalized() if n_k.is_finite() and n_k.length() > 0.5 else normal)
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var lift: Vector3 = normal * (0.003 / maxf(bone_scale, 0.001))
		for r: int in range(rows - 1):
			for c: int in range(cols - 1):

				var corners: Array = [[c, r], [c + 1, r + 1], [c + 1, r], [c, r], [c, r + 1], [c + 1, r + 1]]
				for corner: Array in corners:
					var k: int = int(corner[1]) * cols + int(corner[0])
					st.set_uv(Vector2(float(corner[0]) / float(cols - 1), float(corner[1]) / float(rows - 1)))
					st.set_normal(normals[k])
					st.add_vertex(grid[k] + lift)
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.name = "Lid"
		mesh_node.mesh = st.commit()
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = EYE_LID
		material.set_shader_parameter("skin", Color(float(eye.skin[0]), float(eye.skin[1]), float(eye.skin[2])))
		var lash: Array = eye.get("lash", [0.08, 0.06, 0.1])
		material.set_shader_parameter("lash", Color(float(lash[0]), float(lash[1]), float(lash[2])))

		material.set_shader_parameter("inner", 1.0 if float(eye.centre[0]) < 0.0 else -1.0)
		mesh_node.material_override = material
		attach.add_child(mesh_node)
		_lids.append(material)

func set_expression(mood: String, blink: float = 0.0) -> void :
	if _face_initialized and mood == _face_mood and is_equal_approx(blink, _blink): return
	_face_mood = mood;_blink = blink
	_face_initialized = true
	for entry in _face_shapes:
		var amount: float = 0.0
		match entry.label:
			"Blink": amount = blink
			"Pain": amount = 1.0 if mood == "pain" else 0.0
			"Fear": amount = 0.85 if mood == "fear" else 0.0
			"Angry": amount = 0.85 if mood == "angry" else 0.0
			"Smile": amount = 0.7 if mood == "smile" else 0.0
			"JawOpen": amount = 0.45 if mood == "fear" or mood == "pain" else 0.0
		if not is_equal_approx(amount, float(entry.value)):
			entry.mesh.set_blend_shape_value(entry.index, amount);entry.value = amount



func set_face_weights(values: PackedFloat32Array) -> void :
	_face_initialized = false
	for entry in _face_shapes:
		var index: int = int(entry.slot)
		if index < 0 or index >= values.size(): continue
		var amount: float = clampf(values[index], 0.0, 1.0)

		amount = amount * 0.6 if str(entry.label) == "JawOpen" else 0.0
		if absf(amount - float(entry.value)) < 0.01 and not (amount == 0.0 and float(entry.value) != 0.0): continue
		entry.mesh.set_blend_shape_value(entry.index, amount);entry.value = amount



func set_finger_curl(amount: float, left_amount: float = -1.0) -> void :
	var right: float = clampf(amount, 0.0, 1.2)
	var left: float = right if left_amount < 0.0 else clampf(left_amount, 0.0, 1.2)

	if absf(right - _finger_curl) < 0.006 and absf(left - _finger_curl_left) < 0.006: return
	_finger_curl = right
	_finger_curl_left = left
	_fingers_dirty = true

func set_hand_gesture(gesture: String, weight: float) -> void :
	if gesture == _hand_gesture and is_equal_approx(weight, _hand_weight): return
	_hand_gesture = gesture;_hand_weight = clampf(weight, 0, 1)
	_fingers_dirty = true
	for mesh in _hand_shapes:
		for shape in range(mesh.mesh.get_blend_shape_count()):
			var label: String = mesh.mesh.get_blend_shape_name(shape)
			if label == "RightThumbsUp": mesh.set_blend_shape_value(shape, _hand_weight if gesture.trim_suffix("_both") == "thumbsup" else 0.0)
			elif label == "RightPoint": mesh.set_blend_shape_value(shape, _hand_weight if gesture.trim_suffix("_both") == "point" else 0.0)


func set_forearm_twist(left: float, right: float) -> void :
	if absf(left - _twist_left) < 0.004 and absf(right - _twist_right) < 0.004: return
	_twist_left = left
	_twist_right = right
	_twist_dirty = true


func set_motion(accel: Vector3, velocity: Vector3, yaw_rate: float, delta: float, clock: float, cloth_drive: Vector2 = Vector2.ZERO) -> void :
	_motion_accel = accel
	_motion_velocity = velocity
	_motion_yaw_rate = yaw_rate
	_motion_dt += delta
	_motion_clock = clock
	_cloth_drive = cloth_drive


func reset_motion() -> void :
	for k in range(_spring_offset.size()):
		_spring_offset[k] = Vector3.ZERO
		_spring_speed[k] = Vector3.ZERO
	_motion_dt = 0.0
	_motion_accel = Vector3.ZERO
	_motion_velocity = Vector3.ZERO
	_motion_yaw_rate = 0.0

func _scan(node: Node) -> void :
	if node is Skeleton3D: skeleton = node
	if node is MeshInstance3D: meshes.append(node)
	for child in node.get_children(): _scan(child)

func joint_position(bone: String) -> Vector3:
	var index: int = skeleton.find_bone(bone)
	return _bone_rest[index].origin if index >= 0 else Vector3.ZERO

func has_joint(bone: String) -> bool:
	return skeleton.find_bone(bone) >= 0

func bind(joints: Dictionary) -> void :
	_joints = joints
	_build_hand_shapes()
	var inverse: Transform3D = global_transform.affine_inverse()
	var keys: Array = joints.keys()
	for key in keys:
		_rest_proxy[key] = inverse * joints[key].global_transform
		_bound_joints.append(joints[key]);_proxy_inverse.append(Transform3D(_rest_proxy[key]).affine_inverse());_deltas.append(Transform3D.IDENTITY)
		_delta_inverse.append(Transform3D.IDENTITY)
	for group in _bone_groups:
		var bound: String = group
		while keys.find(bound) < 0 and GROUP_FALLBACK.has(bound): bound = GROUP_FALLBACK[bound]
		var index: int = keys.find(bound)
		if index < 0: index = keys.find("body")
		_group_indices.append(maxi(index, 0))
	_prepare_fast()


func _prepare_fast() -> void :
	var count: int = _bone_rest.size()
	_mode.resize(count)
	_parent_group.resize(count)
	for i in range(count):
		var kind: int = _secondary_kind[i]
		var label: String = skeleton.get_bone_name(i)
		if kind == KIND_FINGER and _parents[i] >= 0: _mode[i] = MODE_FINGER
		elif kind != KIND_NONE and _parents[i] >= 0: _mode[i] = MODE_SPRING
		elif "ForearmTwist" in label and _parents[i] >= 0: _mode[i] = MODE_TWIST
		else: _mode[i] = MODE_DRIVEN


	var changed: bool = true
	while changed:
		changed = false
		for i in range(count):
			var parent: int = _parents[i]
			if parent < 0: continue
			var child_rigid: bool = _mode[i] == MODE_DRIVEN or _mode[i] == MODE_CONSTANT
			var parent_rigid: bool = _mode[parent] == MODE_DRIVEN or _mode[parent] == MODE_CONSTANT
			if child_rigid and not parent_rigid:
				_mode[parent] = MODE_DRIVEN
				changed = true
	for i in range(count):
		var parent: int = _parents[i]
		_parent_group[i] = _group_indices[parent] if parent >= 0 else -1
		if _mode[i] == MODE_DRIVEN and parent >= 0 and _group_indices[i] == _group_indices[parent] and (_mode[parent] == MODE_DRIVEN or _mode[parent] == MODE_CONSTANT):
			_mode[i] = MODE_CONSTANT
	_driven.clear();_springs.clear();_fingers.clear();_twists.clear()
	_rest_parent_inv.clear();_rest_rotation_inv.clear()
	var twist_count: Dictionary = {"L": 0, "R": 0}
	for i in range(count):
		var parent: int = _parents[i]
		_rest_parent_inv.append(_bone_rest[parent].affine_inverse() if parent >= 0 else Transform3D.IDENTITY)
		_rest_rotation_inv.append(_bone_rest[i].basis.orthonormalized().inverse())
		if _mode[i] != MODE_DRIVEN:

			var local: Transform3D = _chain_rest[i]
			skeleton.set_bone_pose_position(i, local.origin)
			skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
			skeleton.set_bone_pose_scale(i, local.basis.get_scale())
		match _mode[i]:
			MODE_DRIVEN: _driven.append(i)
			MODE_SPRING: _add_spring(i)
			MODE_FINGER: _fingers.append(i)
			MODE_TWIST:
				_twists.append(i)
				twist_count["R" if _is_right[i] == 1 else "L"] += 1
	for i in _twists:
		var side: String = "R" if _is_right[i] == 1 else "L"
		var hand: int = skeleton.find_bone(side + "_Hand")
		var forearm: int = skeleton.find_bone(side + "_Forearm")
		var axis: Vector3 = Vector3.DOWN
		if hand >= 0 and forearm >= 0: axis = (_bone_rest[hand].origin - _bone_rest[forearm].origin).normalized()
		_twist_axis.append((_rest_rotation_inv[i] * axis).normalized())
		_twist_share.append(1.0 / (float(twist_count[side]) + 1.0))
	_fast = true
	_fingers_dirty = true
	_twist_dirty = true

func _add_spring(i: int) -> void :
	var kind: int = _secondary_kind[i]
	var label: String = skeleton.get_bone_name(i)

	var direction: Vector3 = Vector3.DOWN
	if kind == KIND_EAR:
		direction = Vector3.UP
		for child in range(_parents.size()):
			if _parents[child] == i:
				var along: Vector3 = _bone_rest[child].origin - _bone_rest[i].origin
				if along.length() > 0.001 and along.y > 0.0: direction = along.normalized()
	var depth: int = 0
	var parent: int = _parents[i]
	while parent >= 0 and _secondary_kind[parent] == kind:
		depth += 1
		parent = _parents[parent]
	var omega: float = 10.0
	var zeta: float = 0.4
	var gain: float = 0.009
	var drag: float = 0.012
	match kind:
		KIND_CLOTH:
			omega = 10.0;zeta = 0.42;gain = 0.01;drag = 0.018
		KIND_EAR:
			omega = 15.0 - depth * 3.0;zeta = 0.28;gain = 0.006;drag = 0.008
		KIND_BRAID:
			omega = 9.0 - depth * 1.5;zeta = 0.33;gain = 0.012;drag = 0.014
		KIND_HAIR:

			omega = 10.0 - depth * 2.0;zeta = 0.36;gain = 0.009 + depth * 0.003;drag = 0.012 + depth * 0.003
	_springs.append(i)
	_spring_dir.append(direction)
	_spring_offset.append(Vector3.ZERO)
	_spring_speed.append(Vector3.ZERO)
	_spring_omega.append(omega)
	_spring_zeta.append(zeta)
	_spring_gain.append(gain)
	_spring_drag.append(drag)
	_spring_side.append(1.0 if label.begins_with("R_") else -1.0 if label.begins_with("L_") else 0.0)

func _build_hand_shapes() -> void :
	if model_name == "Alice": return
	for i in range(skeleton.get_bone_count()):
		if _is_finger(skeleton.get_bone_name(i)): return
	var bone: int = skeleton.find_bone("R_Hand")
	if bone < 0: return
	var wrist: Vector3 = _bone_rest[bone].origin
	for mesh in meshes:


		if mesh.skin == null or mesh.mesh.get_blend_shape_count() > 0: continue
		var hand_bind: int = -1
		for b in range(mesh.skin.get_bind_count()):
			if mesh.skin.get_bind_bone(b) == bone or mesh.skin.get_bind_name(b) == "R_Hand": hand_bind = b
		if hand_bind < 0: continue
		var output: ArrayMesh = ArrayMesh.new()
		for shape in range(mesh.mesh.get_blend_shape_count()): output.add_blend_shape(mesh.mesh.get_blend_shape_name(shape))
		output.add_blend_shape("RightThumbsUp");output.add_blend_shape("RightPoint")
		output.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		var frame: Transform3D = _bone_rest[bone] * mesh.skin.get_bind_pose(hand_bind)
		var inverse: Transform3D = frame.affine_inverse()
		var edited: bool = false
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var morphs: Array = mesh.mesh.surface_get_blend_shape_arrays(surface).duplicate()
			for gesture in ["thumbsup", "point"]:
				var target: PackedVector3Array = vertices.duplicate()
				for i in range(vertices.size()):
					if bones.is_empty(): continue
					var amount: float = 0.0; var stride: int = bones.size() / vertices.size()
					for j in range(stride):
						if bones[i * stride + j] == hand_bind: amount += weights[i * stride + j]
					if amount < 0.1: continue
					var at: Vector3 = frame * vertices[i]; var relative: Vector3 = at - wrist

					var medial: float = - relative.x
					var keep: bool = medial > 0.04 if gesture == "thumbsup" else medial > 0.01 and medial < 0.035
					var distal: float = clampf(( - relative.y - 0.035) / 0.11, 0, 1)
					if keep or distal <= 0: continue
					var hinge: Vector3 = wrist + Vector3(relative.x, - 0.043, relative.z * 0.3)
					var bent: Vector3 = hinge + Basis(Vector3.RIGHT, 1.75 * distal) * (at - hinge)
					target[i] = inverse * at.lerp(bent, amount);edited = true
				var shape: Array = [];shape.resize(Mesh.ARRAY_MAX)
				shape[Mesh.ARRAY_VERTEX] = target;shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL];shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
				morphs.append(shape)
			output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, morphs)
			output.surface_set_material(surface, mesh.mesh.surface_get_material(surface))
		if edited: mesh.mesh = output;_hand_shapes.append(mesh)

func _group(bone: String) -> String:
	if bone == "Head" or bone.begins_with("HairBack") or "Ear" in bone or "Braid" in bone: return "head"
	if bone in ["Neck", "NeckTwist01", "NeckTwist02"]: return "neck"
	if bone == "Spine01": return "spine"
	if "Clavicle" in bone: return ("left" if bone.begins_with("L_") else "right") + "_clav"
	if bone == "Spine02": return "chest"
	var side: String = "left" if bone.begins_with("L_") else "right"
	if _is_finger(bone): return side + "_hand"
	if "Upperarm" in bone: return side + "_arm"
	if "Forearm" in bone: return side + "_elbow"
	if "Hand" in bone: return side + "_hand"
	if "Thigh" in bone: return side + "_leg"
	if "Calf" in bone: return side + "_knee"
	if "ToeBase" in bone: return side + "_toe"
	if "Foot" in bone: return side + "_ankle"
	return "body"

func _is_finger(bone: String) -> bool:
	return "Thumb" in bone or "Index" in bone or "Middle" in bone or "Ring" in bone or "Pinky" in bone

func sync(clock: float = 0.0, speed: float = 0.0) -> void :
	if _joints.is_empty(): return
	if not _fast:
		_sync_full(clock, speed)
		return
	var inverse: Transform3D = global_transform.affine_inverse()
	for j in range(_bound_joints.size()):
		var delta: Transform3D = (inverse * _bound_joints[j].global_transform) * _proxy_inverse[j]
		_deltas[j] = delta
		_delta_inverse[j] = delta.affine_inverse()
	for i in _driven:
		var parent_group: int = _parent_group[i]
		var local: Transform3D
		if parent_group < 0:
			local = _skeleton_inverse * _deltas[_group_indices[i]] * _bone_rest[i]
		else:
			local = _rest_parent_inv[i] * (_delta_inverse[parent_group] * _deltas[_group_indices[i]]) * _bone_rest[i]
		skeleton.set_bone_pose_position(i, local.origin)
		skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
	if _twist_dirty:
		_twist_dirty = false
		for k in range(_twists.size()):
			var i: int = _twists[k]
			var angle: float = (_twist_right if _is_right[i] == 1 else _twist_left) * _twist_share[k]
			skeleton.set_bone_pose_rotation(i, _chain_rest[i].basis.get_rotation_quaternion() * Quaternion(_twist_axis[k], angle))
	if not secondary_detail:
		_motion_dt = 0.0
		return
	if _fingers_dirty:
		_fingers_dirty = false
		_write_fingers()
	if _motion_dt > 0.0:
		_step_springs(minf(_motion_dt, 0.1))
		_motion_dt = 0.0

func _write_fingers() -> void :
	# Geste « thumbsup_both » / « point_both » : les deux mains (sinon la main droite seule).
	var both: bool = _hand_gesture.ends_with("_both")
	var gesture: String = _hand_gesture.trim_suffix("_both")
	for i in _fingers:
		var right: bool = _is_right[i] == 1
		var curl: float = _finger_curl if right else _finger_curl_left

		if (right or both) and _hand_weight > 0.1:
			if gesture == "thumbsup" and _finger_kind[i] == 1: curl = lerpf(curl, 0.0, _hand_weight)
			elif gesture == "point" and _finger_kind[i] == 2: curl = lerpf(curl, 0.0, _hand_weight)
			else: curl = lerpf(curl, 1.0, _hand_weight)
		skeleton.set_bone_pose_rotation(i, _chain_rest[i].basis.get_rotation_quaternion() * _finger_rotation(i, curl))


func _finger_rotation(i: int, curl: float) -> Quaternion:
	var joint: int = _finger_joint[i]
	var angle: float = curl * (THUMB_BEND[joint] if _finger_kind[i] == 1 else FINGER_BEND[joint])
	var axis: Vector3 = _finger_axis[i] if i < _finger_axis.size() else Vector3.ZERO
	if axis.length_squared() < 0.5: return Quaternion(Vector3.RIGHT, - angle)
	return Quaternion(axis, angle)




func _prepare_finger_axes() -> void :
	_finger_axis.clear()
	_finger_axis.resize(_bone_rest.size())

	var mirror: float = signf(_skeleton_frame.basis.determinant())
	for side: String in ["L", "R"]:
		var hand: int = skeleton.find_bone(side + "_Hand")
		if hand < 0: continue
		var bases: Array[int] = []
		for finger: String in ["Index", "Middle", "Ring", "Pinky"]:
			var b: int = skeleton.find_bone(side + "_" + finger + "01")
			if b >= 0: bases.append(b)
		if bases.size() < 2: continue
		var knuckles: Vector3 = Vector3.ZERO
		for b: int in bases: knuckles += _bone_rest[b].origin
		knuckles /= float(bases.size())
		var forward: Vector3 = (knuckles - _bone_rest[hand].origin).normalized()
		var across: Vector3 = _bone_rest[bases[bases.size() - 1]].origin - _bone_rest[bases[0]].origin
		across = (across - forward * across.dot(forward)).normalized()

		var palm: Vector3 = (forward.cross(across) if side == "R" else across.cross(forward)) * mirror
		if not palm.is_finite() or palm.length_squared() < 0.5: continue
		for i in range(_bone_rest.size()):
			if _secondary_kind[i] != KIND_FINGER or not skeleton.get_bone_name(i).begins_with(side + "_"): continue
			var direction: Vector3 = _finger_direction(i, forward)
			var goal: Vector3 = palm if _finger_kind[i] != 1 else (palm * 0.75 + across * 0.65).normalized()
			var hinge: Vector3 = direction.cross(goal)
			if hinge.length_squared() < 0.0025: hinge = across.cross(palm) * -1.0 if _finger_kind[i] != 1 else forward
			_finger_axis[i] = (_bone_rest[i].basis.orthonormalized().inverse() * hinge.normalized()).normalized()


func _finger_direction(i: int, fallback: Vector3) -> Vector3:
	for child in range(_parents.size()):
		if _parents[child] == i and _secondary_kind[child] == KIND_FINGER:
			var d: Vector3 = _bone_rest[child].origin - _bone_rest[i].origin
			if d.length() > 0.0005: return d.normalized()
	var parent: int = _parents[i]
	if parent >= 0 and _secondary_kind[parent] == KIND_FINGER:
		var d2: Vector3 = _bone_rest[i].origin - _bone_rest[parent].origin
		if d2.length() > 0.0005: return d2.normalized()
	return fallback


func pose_fingers_at_rest(curl: float) -> void :
	for i in range(_bone_rest.size()):
		if _secondary_kind[i] == KIND_FINGER and _parents[i] >= 0:
			skeleton.set_bone_pose_rotation(i, _chain_rest[i].basis.get_rotation_quaternion() * _finger_rotation(i, curl))

func _step_springs(total: float) -> void :
	var steps: int = ceili(total / 0.034)
	var dt: float = total / float(steps)
	var velocity: Vector3 = Vector3(_motion_velocity.x, 0.0, _motion_velocity.z)
	var speed: float = velocity.length()
	for k in range(_springs.size()):
		var i: int = _springs[k]
		var kind: int = _secondary_kind[i]
		var gain: float = _spring_gain[k]

		var target: Vector3 = Vector3( - _motion_accel.x, 0.0, - _motion_accel.z) * gain
		if speed > 0.01: target -= velocity / speed * minf(speed * _spring_drag[k], 0.24)
		target.x -= _motion_yaw_rate * 0.02
		if kind == KIND_EAR: target.z += _motion_accel.y * 0.004

		var fall: float = clampf( - _motion_velocity.y * 0.022, 0.0, 0.32)
		var bounce: float = clampf(_motion_accel.y * 0.004, -0.12, 0.2)
		if kind == KIND_CLOTH:
			var drive: float = _cloth_drive.x if _spring_side[k] < 0.0 else _cloth_drive.y if _spring_side[k] > 0.0 else 0.5 * (_cloth_drive.x + _cloth_drive.y)
			target.z -= drive * 0.4
			target.x += _spring_side[k] * (fall * 0.8 - bounce * 0.3)
			target.z += fall * 0.35
		elif kind == KIND_HAIR or kind == KIND_BRAID:
			target.z += fall * (0.9 if kind == KIND_HAIR else 0.6) - bounce * 0.4
			if kind == KIND_BRAID: target.x += _spring_side[k] * fall * 0.3
		var phase: float = float(i) * 1.37

		target += Vector3(sin(_motion_clock * 1.3 + phase), 0.0, cos(_motion_clock * 1.1 + phase)) * 0.016
		var offset: Vector3 = _spring_offset[k]
		var spring_speed: Vector3 = _spring_speed[k]
		var omega: float = _spring_omega[k]
		for s in range(steps):
			spring_speed += ((target - offset) * omega * omega - spring_speed * 2.0 * _spring_zeta[k] * omega) * dt
			offset += spring_speed * dt
		offset = offset.limit_length(0.5)
		_spring_offset[k] = offset
		_spring_speed[k] = spring_speed
		var axis: Vector3 = _spring_dir[k].cross(offset)
		var angle: float = axis.length()
		var rest: Quaternion = _chain_rest[i].basis.get_rotation_quaternion()
		if angle < 1e-05:
			skeleton.set_bone_pose_rotation(i, _hang(i, kind) * rest)
			continue
		var local_axis: Vector3 = (_rest_rotation_inv[i] * (axis / angle)).normalized()
		skeleton.set_bone_pose_rotation(i, _hang(i, kind) * rest * Quaternion(local_axis, angle))




func _hang(i: int, kind: int) -> Quaternion:
	if kind != KIND_HAIR and kind != KIND_BRAID: return Quaternion.IDENTITY
	var parent: int = _parents[i]
	if parent < 0 or _secondary_kind[parent] == KIND_HAIR or _secondary_kind[parent] == KIND_BRAID: return Quaternion.IDENTITY
	var now: Quaternion = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var rest: Quaternion = skeleton.get_bone_global_rest(parent).basis.get_rotation_quaternion()
	var undo: Quaternion = Quaternion.IDENTITY.slerp((now * rest.inverse()).inverse(), 0.6 if kind == KIND_HAIR else 0.45)
	return now.inverse() * undo * now


func _sync_full(clock: float = 0.0, speed: float = 0.0) -> void :
	var inverse: Transform3D = global_transform.affine_inverse()
	for j in range(_bound_joints.size()): _deltas[j] = (inverse * _bound_joints[j].global_transform) * _proxy_inverse[j]
	for i in range(_bone_rest.size()):
		var desired: Transform3D
		var parent: int = _parents[i]
		var kind: int = _secondary_kind[i]
		if kind > 0 and parent >= 0 and parent < i:
			desired = _poses[parent] * _chain_rest[i]
			var turn: Vector3 = Vector3.ZERO
			if kind == 1:
				var curl: float = _finger_curl if _is_right[i] == 1 else _finger_curl_left
				if _is_right[i] == 1 and _hand_weight > 0.1:
					if _hand_gesture == "thumbsup" and _finger_kind[i] == 1: curl = lerpf(curl, 0.0, _hand_weight)
					elif _hand_gesture == "point" and _finger_kind[i] == 2: curl = lerpf(curl, 0.0, _hand_weight)
					else: curl = lerpf(curl, 1.0, _hand_weight)
				desired.basis = desired.basis * Basis(_finger_rotation(i, curl))
			elif kind == 2: turn = Vector3(sin(clock * 2.8 + i) * 0.025 + clampf(speed * 0.005, 0, 0.065), 0, sin(clock * 2 + i) * 0.015)
			elif kind == 3: turn = Vector3(sin(clock * 2.7 + i) * 0.045 + clampf(speed * 0.006, 0, 0.08), 0, sin(clock * 1.6 + i) * 0.03)
			elif kind == 4: turn = Vector3(sin(clock * 2.5 - i * 0.7) * 0.035 + clampf(speed * 0.006, 0, 0.09), sin(clock * 2 - i) * 0.025, 0)
			else: turn = Vector3(sin(clock * 2.8) * 0.016 + clampf(speed * 0.006, 0, 0.065), sin(clock * 1.7) * 0.018, 0)
			if kind != 1: desired.basis = desired.basis * Basis.from_euler(turn)
		else:
			desired = _skeleton_inverse * _deltas[_group_indices[i]] * _bone_rest[i]
		_poses[i] = desired;_pose_inverse[i] = desired.affine_inverse()
	for i in range(_poses.size()):
		var parent: int = _parents[i]
		var local: Transform3D = _poses[i] if parent < 0 else _pose_inverse[parent] * _poses[i]
		skeleton.set_bone_pose_position(i, local.origin)
		skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		var local_scale: Vector3 = local.basis.get_scale()
		if not local_scale.is_equal_approx(_last_scales[i]):
			skeleton.set_bone_pose_scale(i, local_scale);_last_scales[i] = local_scale

func shadow_tint() -> void :
	var material: Material = CharMaterials.clone_tint()
	for mesh in meshes:
		mesh.material_override = material
