extends RefCounted




const BUCKET: float = 6.0


static var _index_owner: int = 0
static var _points: PackedVector3Array = PackedVector3Array()
static var _buckets: Dictionary = {}

var school

func _init(map_school) -> void :
	school = map_school

func _graph() -> AStar3D:
	if school == null: return null
	var layout: Variant = school.get("om_layout")
	if layout == null: return null
	var graph: Variant = layout.get("graph")
	return graph if graph is AStar3D else null

func _ensure_index() -> bool:
	var graph: AStar3D = _graph()
	if graph == null or graph.get_point_count() == 0: return false
	var owner: int = graph.get_instance_id()
	if owner == _index_owner and not _points.is_empty(): return true
	_index_owner = owner
	_points = PackedVector3Array()
	_buckets = {}
	for id in graph.get_point_ids():
		var point: Vector3 = graph.get_point_position(id)
		var key: Vector2i = Vector2i(floori(point.x / BUCKET), floori(point.z / BUCKET))
		var bucket: PackedInt32Array = _buckets.get(key, PackedInt32Array())
		bucket.append(_points.size())
		_buckets[key] = bucket
		_points.append(point)
	return true



func ring(center: Vector3, inner: float, outer: float, rise: float, count: int, rng: RandomNumberGenerator) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	if school != null and school.has_method("nav_points_near"):
		for point in school.nav_points_near(center, outer, count * 3):
			var flat: float = Vector2(point.x - center.x, point.z - center.z).length()
			if flat >= inner and flat <= outer and absf(point.y - center.y) <= rise: result.append(point)
			if result.size() >= count: break
		return result
	if not _ensure_index(): return result
	var attempts: int = count * 3
	for attempt in range(attempts):
		var angle: float = rng.randf() * TAU
		var radius: float = lerpf(inner, outer, sqrt(rng.randf()))
		var probe: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var bucket: PackedInt32Array = _buckets.get(Vector2i(floori(probe.x / BUCKET), floori(probe.z / BUCKET)), PackedInt32Array())
		if bucket.is_empty(): continue
		var best: int = -1
		var best_score: float = INF
		for index in bucket:
			var point: Vector3 = _points[index]
			var rise_gap: float = absf(point.y - center.y)
			if rise_gap > rise: continue
			var score: float = Vector2(point.x - probe.x, point.z - probe.z).length() + rise_gap * 2.0
			if score < best_score:
				best = index
				best_score = score
		if best < 0: continue
		var chosen: Vector3 = _points[best]
		var flat: float = Vector2(chosen.x - center.x, chosen.z - center.z).length()
		if flat < inner or flat > outer or result.has(chosen): continue
		result.append(chosen)
		if result.size() >= count: break
	return result
