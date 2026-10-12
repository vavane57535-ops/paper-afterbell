extends RefCounted

# Géométrie « papier » partagée par les menus : bords déchirés, découpes aux
# ciseaux, bandes diagonales. Fonctions statiques sans dépendance (chargées
# par ui_paper_styles.gd, ui_collage.gd, ui_menu_fx.gd…).

# Image de « boil » : le trait des éléments allumés frémit comme un dessin
# animé (~8 images/s). ui_menu_fx.gd l'incrémente et redessine l'élément.
static var boil_frame: int = 0
# « Réduire les flashs » actif (mis à jour par ui_menu_fx.gd) : les décors
# arrêtent de bouger.
static var calm: bool = false

static func noise(seed_value: int, index: int) -> float:
	var h: int = (seed_value * 374761393 + index * 668265263) & 2147483647
	h = ((h ^ (h >> 13)) * 1274126177) & 2147483647
	return float(h % 10000) / 10000.0


# Bord découpé entre deux points (ajouté sans le point final).
static func edge(points: PackedVector2Array, from: Vector2, to: Vector2, jitter: float, seed_value: int, step: float = 10.0) -> void :
	var length: float = from.distance_to(to)
	var steps: int = maxi(1, int(length / step))
	var normal: Vector2 = (to - from).normalized().orthogonal() if length > 0.001 else Vector2.ZERO
	for i: int in range(steps):
		var t: float = float(i) / float(steps)
		var shift: float = 0.0
		if jitter > 0.0 and i > 0: shift = (noise(seed_value, i) - 0.5) * jitter * 2.0
		points.append(from.lerp(to, t) + normal * shift)


# Quadrilatère penché (italique) aux bords déchirés.
static func strip(rect: Rect2, skew: float, jitter_x: float, jitter_y: float, seed_value: int) -> PackedVector2Array:
	var s: float = clampf(skew, - rect.size.x * 0.25, rect.size.x * 0.25)
	s = clampf(s, - rect.size.y * 0.9, rect.size.y * 0.9)
	var a: Vector2 = Vector2(rect.position.x + maxf(s, 0.0), rect.position.y)
	var b: Vector2 = Vector2(rect.end.x + minf(s, 0.0), rect.position.y)
	var c: Vector2 = Vector2(rect.end.x - maxf(s, 0.0), rect.end.y)
	var d: Vector2 = Vector2(rect.position.x - minf(s, 0.0), rect.end.y)
	var points: PackedVector2Array = PackedVector2Array()
	var jy: float = minf(jitter_y, rect.size.y * 0.12)
	var jx: float = minf(jitter_x, rect.size.x * 0.12)
	edge(points, a, b, jy, seed_value + 11, 12.0)
	edge(points, b, c, jx, seed_value + 23, 5.0)
	edge(points, c, d, jy, seed_value + 37, 12.0)
	edge(points, d, a, jx, seed_value + 41, 5.0)
	return points


# Polygone découpé « aux ciseaux » : peu de sommets, angles vifs.
static func cut(rect: Rect2, seed_value: int, sharp: float = 0.18) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var w: float = rect.size.x
	var h: float = rect.size.y
	var k: float = minf(w, h) * sharp
	points.append(rect.position + Vector2((noise(seed_value, 1) - 0.3) * k * 2.0, (noise(seed_value, 2) - 0.5) * k))
	points.append(rect.position + Vector2(w * (0.45 + noise(seed_value, 3) * 0.1), - k * noise(seed_value, 4)))
	points.append(Vector2(rect.end.x + k * (noise(seed_value, 5) * 1.4), rect.position.y + (noise(seed_value, 6) - 0.5) * k))
	points.append(Vector2(rect.end.x - k * noise(seed_value, 7), rect.position.y + h * (0.5 + (noise(seed_value, 8) - 0.5) * 0.3)))
	points.append(rect.end + Vector2((noise(seed_value, 9) - 0.2) * k * 1.6, (noise(seed_value, 10) - 0.4) * k))
	points.append(Vector2(rect.position.x + w * (0.5 + (noise(seed_value, 11) - 0.5) * 0.2), rect.end.y + k * noise(seed_value, 12)))
	points.append(Vector2(rect.position.x - k * (0.4 + noise(seed_value, 13)), rect.end.y + (noise(seed_value, 14) - 0.5) * k))
	return points


# Formes mémorisées : les décors redessinent chaque image les mêmes bandes
# une fois leur entrée finie ; inutile de recalculer les bords en GDScript.
static var _cache: Dictionary = {}

static func _remember(key: Array, points: PackedVector2Array) -> PackedVector2Array:
	if _cache.size() > 1500: _cache.clear()
	_cache[key] = points
	return points

# Bande diagonale déchirée entre deux points, d'épaisseur donnée.
static func band(from: Vector2, to: Vector2, thickness: float, seed_value: int, jitter: float = 10.0) -> PackedVector2Array:
	var key: Array = [1, from.round(), to.round(), roundf(thickness), seed_value, roundf(jitter)]
	if _cache.has(key): return _cache[key]
	var points: PackedVector2Array = PackedVector2Array()
	var length: float = from.distance_to(to)
	if length < 1.0: return points
	var normal: Vector2 = (to - from).normalized().orthogonal()
	var half: float = thickness * 0.5
	var steps: int = maxi(2, int(length / 60.0))
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		points.append(from.lerp(to, t) + normal * (half + (noise(seed_value, i) - 0.5) * jitter))
	for i: int in range(steps, -1, -1):
		var t: float = float(i) / float(steps)
		points.append(from.lerp(to, t) - normal * (half + (noise(seed_value + 7, i) - 0.5) * jitter))
	return _remember(key, points)


# Bande droite sans déchirure (hachures qui défilent) : 4 sommets.
static func quad_band(from: Vector2, to: Vector2, thickness: float) -> PackedVector2Array:
	var normal: Vector2 = (to - from).normalized().orthogonal() * thickness * 0.5
	return PackedVector2Array([from + normal, to + normal, to - normal, from - normal])


# Bord découpé mémorisé (même usage que edge, renvoie les points).
static func edge_points(from: Vector2, to: Vector2, jitter: float, seed_value: int, step: float = 10.0) -> PackedVector2Array:
	var key: Array = [2, from.round(), to.round(), roundf(jitter * 10.0), seed_value, roundf(step)]
	if _cache.has(key): return _cache[key]
	var points: PackedVector2Array = PackedVector2Array()
	edge(points, from, to, jitter, seed_value, step)
	return _remember(key, points)


static func offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var key: Array = [3, hash(points), points.size(), by]
	if _cache.has(key): return _cache[key]
	var result: PackedVector2Array = PackedVector2Array()
	result.resize(points.size())
	for i: int in range(points.size()): result[i] = points[i] + by
	return _remember(key, result)


static func transformed(points: PackedVector2Array, xform: Transform2D) -> PackedVector2Array:
	var key: Array = [4, hash(points), points.size(), xform]
	if _cache.has(key): return _cache[key]
	return _remember(key, xform * points)


# Remplit un polygone sans message d'erreur si la triangulation échoue.
static var _triangles: Dictionary = {}

static func polygon(item: RID, points: PackedVector2Array, color: Color) -> void :
	if points.size() < 3 or color.a <= 0.003: return
	var key: int = hash(points) ^ points.size()
	var triangles: PackedInt32Array
	var known: Variant = _triangles.get(key)
	if known is Array and int(known[0]) == points.size(): triangles = known[1]
	else:
		triangles = Geometry2D.triangulate_polygon(points)
		if _triangles.size() > 600: _triangles.clear()
		_triangles[key] = [points.size(), triangles]
	if triangles.is_empty(): return
	RenderingServer.canvas_item_add_triangle_array(item, triangles, points, PackedColorArray([color]))


static var _grain: Texture2D

static func grain() -> Texture2D:
	if _grain == null and ResourceLoader.exists("res://ui/tex/paper_grain.png"): _grain = load("res://ui/tex/paper_grain.png")
	return _grain
