class_name PaperCombatFeedback
extends Control


const DAMAGE_DURATION: float = 0.52
const CONFIRM_DURATION: float = 0.24
const BLOCK_DURATION: float = 0.42

const SHIELD: Array[Vector2] = [Vector2(-0.8, -0.82), Vector2(-0.32, -1.0), Vector2(0.32, -1.0), Vector2(0.8, -0.82), Vector2(0.8, 0.02), Vector2(0.56, 0.56), Vector2(0.0, 1.0), Vector2(-0.56, 0.56), Vector2(-0.8, 0.02)]

var damage_time: float = 0.0
var confirm_time: float = 0.0
var block_time: float = 0.0
var strength: float = 0.0
var direction: Vector2 = Vector2.UP
var stunned: bool = false
var reduced_motion: bool = false
var reduce_flashes: bool = false

var block_self: bool = true
var _world: Node

func _ready() -> void :
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func receive(data: Dictionary, camera: Camera3D, viewer: PaperActor) -> void :
	_sync_options(viewer)
	if bool(data.get("local_victim", false)):
		damage_time = DAMAGE_DURATION;strength = clampf(float(data.get("damage_strength", 0.5)), 0.2, 1.0)
		var source: Variant = data.get("source_position", Vector3.ZERO)
		if source is Vector3 and viewer and camera:
			var flat: Vector3 = source - viewer.position;flat.y = 0
			direction = Vector2(flat.dot(camera.global_basis.x), flat.dot(camera.global_basis.z)).normalized()
			if direction.length() < 0.1: direction = Vector2.UP
	if bool(data.get("hit_confirm", false)) or bool(data.get("stun_confirm", false)):
		confirm_time = CONFIRM_DURATION;stunned = bool(data.get("stun_confirm", false))
	if bool(data.get("blocked", false)):
		block_time = BLOCK_DURATION
		block_self = bool(data.get("block_self", true))
	queue_redraw()

func _sync_options(viewer: PaperActor) -> void :

	if not is_instance_valid(_world) and is_instance_valid(viewer): _world = viewer.get_parent()
	if not is_instance_valid(_world): return
	var options: Variant = _world.get("options")
	reduce_flashes = options is Dictionary and bool(options.get("reduce_flashes", false))

func _process(delta: float) -> void :
	if damage_time <= 0 and confirm_time <= 0 and block_time <= 0: return
	damage_time = maxf(0, damage_time - delta);confirm_time = maxf(0, confirm_time - delta);block_time = maxf(0, block_time - delta)
	queue_redraw()

func _draw() -> void :
	var center: Vector2 = size * 0.5
	if damage_time > 0:
		var calm: bool = reduced_motion or reduce_flashes
		var alpha: float = damage_time / DAMAGE_DURATION * strength * (0.24 if calm else 0.4)
		for i in range(18):
			var color: Color = Color(0.65, 0.09, 0.17, alpha * pow(1.0 - float(i) / 18.0, 2))
			var inset: float = i * 3.0
			draw_rect(Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2), color, false, 3)
		var point: Vector2 = center + direction * 86
		var side: Vector2 = Vector2( - direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([point + direction * 12, point - direction * 3 + side * 9, point - direction * 3 - side * 9]), Color(0.95, 0.31, 0.4, minf(1.0, damage_time * 3)))
	if confirm_time > 0:
		var color: Color = Color("f5cf8d") if stunned else Color("eee3d5")
		color.a = minf(1, confirm_time * 7)
		for offset: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
			draw_line(center + offset * 8, center + offset * 15, color, 2)
	if block_time > 0: _draw_block(center + Vector2(0, -64))



func _draw_block(at: Vector2) -> void :
	var t: float = block_time / BLOCK_DURATION
	var grow: float = 1.0 if reduced_motion else 1.0 + (1.0 - t) * 0.22
	var radius: float = 18.0 * grow
	var color: Color = Color("9fe3d4") if block_self else Color("f2b06b")
	color.a = minf(1.0, block_time * 6.0) * (0.75 if reduce_flashes else 1.0)
	var outline: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in SHIELD: outline.append(at + corner * radius)
	draw_colored_polygon(outline, Color(color, color.a * 0.2))
	outline.append(outline[0])
	draw_polyline(outline, color, 2.5, true)
	if block_self:
		draw_polyline(PackedVector2Array([at + Vector2(-0.34, 0.0) * radius, at + Vector2(-0.06, 0.3) * radius, at + Vector2(0.38, -0.28) * radius]), color, 2.5, true)
	else:
		draw_polyline(PackedVector2Array([at + Vector2(-0.3, -0.62) * radius, at + Vector2(0.06, -0.12) * radius, at + Vector2(-0.12, 0.2) * radius, at + Vector2(0.18, 0.58) * radius]), color, 2.0, true)
