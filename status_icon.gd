class_name PaperStatusIcon
extends Control


var character: String = "Ashura"
var life: String = "alive"
var chased: bool = false
var compact: bool = false
var portrait: Texture2D
var clock: float = 0.0
static var portraits: Dictionary = {}
const WHITE = Color("ece5d5")
const COLORS = {"alive": Color("8fc7af"), "second_life": Color("9eaff1"), "downed": Color("edbc72"), "dead": Color("85818b"), "escaped": Color("c8deba")}

static func portrait_for(person: String) -> Texture2D:
	if portraits.has(person): return portraits[person]
	var path: String = "res://ui/portraits/" + person + ".png"
	if ResourceLoader.exists(path):
		portraits[person] = load(path)
		return portraits[person]
	return null

func setup(person: String, state: String = "alive") -> void :
	character = person
	life = state
	portrait = portrait_for(person)
	custom_minimum_size = Vector2(58, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func update_state(state: String, pursued: bool) -> void :
	if state != life or pursued != chased:
		life = state
		chased = pursued
		queue_redraw()

func _draw() -> void :
	var side: float = minf(size.x, size.y)
	var inset: float = 2.0 if compact else 3.0
	var bounds: Rect2 = Rect2(Vector2(inset, inset), Vector2(side - inset * 2.0, side - inset * 2.0))
	var color: Color = COLORS.get(life, COLORS.alive)
	if chased and life not in ["dead", "downed"]: color = Color("ef7282")
	var radius: int = int(clampf(side * 0.16, 4, 9))
	var tile: StyleBoxFlat = StyleBoxFlat.new()
	tile.bg_color = Color("1b1822")
	tile.set_corner_radius_all(radius)
	tile.anti_aliasing = true
	draw_style_box(tile, bounds)
	if portrait:
		var modulate_color: Color = Color(0.4, 0.4, 0.45) if life == "dead" else Color(0.7, 0.72, 0.78) if life == "escaped" else Color.WHITE
		draw_texture_rect(portrait, bounds.grow(-1.0), false, modulate_color)
	else:
		var face: Font = ThemeDB.fallback_font
		draw_string(face, Vector2(side * 0.3, side * 0.68), character.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(side * 0.45), WHITE)
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = color
	ring.set_border_width_all(2 if compact else 2)
	ring.set_corner_radius_all(radius)
	ring.anti_aliasing = true
	draw_style_box(ring, bounds)
	if life == "dead":
		var a: Vector2 = bounds.position + Vector2(side * 0.18, side * 0.18)
		var b: Vector2 = bounds.end - Vector2(side * 0.18, side * 0.18)
		draw_line(a, b, Color("e0a3b2"), 2.0, true)
		draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), Color("e0a3b2"), 2.0, true)
	if compact and life in ["alive", "second_life"] and not chased: return
	var badge_radius: float = clampf(side * 0.15, 5.5, 10.0)
	var badge: Vector2 = Vector2(side - badge_radius - 1.0, side - badge_radius - 1.0)
	draw_circle(badge, badge_radius + 1.5, Color("11141c"))
	draw_circle(badge, badge_radius, color)
	var ink: Color = Color("1b1f2a")
	var u: float = badge_radius * 0.5
	if life == "downed":
		draw_line(badge + Vector2( - u, 0), badge + Vector2(u, 0), ink, 2.0)
		draw_line(badge + Vector2(0, - u), badge + Vector2(0, u), ink, 2.0)
	elif life == "escaped":
		draw_line(badge + Vector2( - u, 0), badge + Vector2(u * 0.8, 0), ink, 2.0)
		draw_polyline(PackedVector2Array([badge + Vector2(0, - u), badge + Vector2(u, 0), badge + Vector2(0, u)]), ink, 2.0)
	elif life == "second_life":
		for x: float in [ - u * 0.5, u * 0.5]: draw_line(badge + Vector2(x, - u), badge + Vector2(x, u), ink, 2.0)
	elif life == "dead":
		draw_line(badge + Vector2( - u * 0.7, - u * 0.7), badge + Vector2(u * 0.7, u * 0.7), ink, 2.0)
		draw_line(badge + Vector2(u * 0.7, - u * 0.7), badge + Vector2( - u * 0.7, u * 0.7), ink, 2.0)
	elif chased:
		draw_circle(badge, u * 0.55, ink)
	else:
		draw_colored_polygon(PackedVector2Array([badge + Vector2( - u, - u * 0.2), badge + Vector2( - u * 0.8, - u * 0.8), badge + Vector2( - u * 0.2, - u * 0.8), badge, badge + Vector2(u * 0.2, - u * 0.8), badge + Vector2(u * 0.8, - u * 0.8), badge + Vector2(u, - u * 0.2), badge + Vector2(0, u)]), ink)
