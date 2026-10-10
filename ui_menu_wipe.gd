extends Control

# Transition entre deux écrans de menu (esprit Persona, version papier) :
# une pile de feuilles déchirées et inclinées (rouge, crème, encre) balaie
# l'écran, le couvre un instant pendant que le titre de la page suivante
# s'y plaque en lettres découpées, puis repart en dévoilant la nouvelle page.
# Le signal `covered` part quand l'écran est entièrement couvert.

const T = preload("res://ui_theme.gd")
const G = preload("res://ui_paper_geom.gd")
const C = preload("res://ui_collage.gd")

signal covered

const SLANT: float = 0.26
const RED_LEAD: float = 0.0
const CREAM_LEAD: float = 42.0
const INK_LEAD: float = 96.0
const COVER_AT: float = 0.38

var duration: float = 0.46
var _t: float = 1.0
var _dir: float = -1.0
var _covered_sent: bool = true
var _ink: Color = Color("0b0d14")
var _red: Color = T.RED
var _title: String = ""
var _seed: int = 3

func _init() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func play(direction: float, alice: bool = false, title: String = "") -> void :
	_dir = direction
	# Retour en arrière plus vif que l'aller.
	duration = 0.36 if direction > 0.0 else 0.46
	_ink = Color("140a10") if alice else Color("0b0d14")
	_red = Color("e0314f") if alice else T.RED
	_title = title
	_seed = randi() % 991
	_t = 0.0
	_covered_sent = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	queue_redraw()

# Fin de transition seulement : l'écran est déjà couvert (changement de
# phase brutal, chargement…) et les feuilles repartent.
func reveal(direction: float, title: String = "", alice: bool = false) -> void :
	play(direction, alice, title)
	_t = COVER_AT
	_covered_sent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func busy() -> bool:
	return visible and _t < 1.0

# Temps restant avant que l'écran soit couvert (0 s'il l'est déjà).
func time_to_cover() -> float:
	return maxf(0.0, (COVER_AT - _t) * duration) if busy() else 0.0

func stop() -> void :
	if not visible: return
	_t = 1.0
	visible = false
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _covered_sent:
		_covered_sent = true
		covered.emit()

func _process(delta: float) -> void :
	_t = minf(1.0, _t + delta / duration)
	if not _covered_sent and _t >= COVER_AT:
		_covered_sent = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		covered.emit()
	queue_redraw()
	if _t >= 1.0:
		visible = false
		set_process(false)


func _group(w: float, ink_w: float) -> float:
	var start: float = w + 60.0
	var cover: float = - INK_LEAD - 150.0
	var hold: float = cover - 46.0
	var finish: float = - (INK_LEAD + ink_w + 120.0 + 300.0)
	if _t < 0.36:
		var p: float = _t / 0.36
		return lerpf(start, cover, 1.0 - pow(1.0 - p, 3.0))
	if _t < 0.5:
		return lerpf(cover, hold, (_t - 0.36) / 0.14)
	var q: float = (_t - 0.5) / 0.5
	return lerpf(hold, finish, q * q)


# Feuille entre deux bords inclinés déchirés (lead → trail, en x à mi-hauteur).
func _sheet(lead: float, trail: float, h: float, salt: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 30
	var slant: float = tan(SLANT)
	for i: int in range(steps + 1):
		var y: float = -20.0 + (h + 40.0) * float(i) / float(steps)
		var x: float = lead + (y - h * 0.5) * slant + (G.noise(_seed + salt, i) - 0.5) * 22.0
		points.append(Vector2(x, y))
	for i: int in range(steps, -1, -1):
		var y: float = -20.0 + (h + 40.0) * float(i) / float(steps)
		var x: float = trail + (y - h * 0.5) * slant + (G.noise(_seed + salt + 50, i) - 0.5) * 22.0
		points.append(Vector2(x, y))
	return points


func _draw() -> void :
	var w: float = size.x
	var h: float = size.y
	if w < 10.0: return
	var ink_w: float = w + h * tan(SLANT) + 260.0
	var g: float = _group(w, ink_w)
	var ink_trail: float = g + INK_LEAD + ink_w
	if _dir > 0.0: draw_set_transform(Vector2(w, 0), 0.0, Vector2(-1, 1))
	var item: RID = get_canvas_item()
	# Feuille rouge (dessous), crème, puis encre : leurs bords décalés forment
	# des liserés colorés à l'avant et à l'arrière de la vague.
	var red: PackedVector2Array = _sheet(g + RED_LEAD, ink_trail + 110.0, h, 1)
	var cream: PackedVector2Array = _sheet(g + CREAM_LEAD, ink_trail + 54.0, h, 7)
	var ink: PackedVector2Array = _sheet(g + INK_LEAD, ink_trail, h, 13)
	G.polygon(item, G.offset(red, Vector2(-18, 0)), Color(0, 0, 0, 0.35))
	G.polygon(item, red, _red)
	G.polygon(item, cream, T.CREAM)
	G.polygon(item, G.offset(ink, Vector2(-10, 0)), Color(0, 0, 0, 0.4))
	G.polygon(item, ink, _ink)
	# Lignes de cahier et hachures sur la feuille d'encre.
	var slant: float = tan(SLANT)
	var lead_x: float = g + INK_LEAD
	var y: float = 34.0
	while y < h:
		var x0: float = maxf(lead_x + (y - h * 0.5) * slant + 26.0, -10.0)
		var x1: float = minf(ink_trail + (y - h * 0.5) * slant - 26.0, w + 10.0)
		if x1 > x0: draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.35, 0.5, 0.85, 0.07), 1.0)
		y += 34.0
	for k: int in range(7):
		var hx: float = g + INK_LEAD + 140.0 + float(k) * 22.0
		draw_line(Vector2(hx - h * 0.5 * slant, 0), Vector2(hx + h * 0.5 * slant, h), Color(_red, 0.16), 6.0)
	if _dir > 0.0: draw_set_transform(Vector2.ZERO)
	# Titre de la page suivante plaqué en lettres découpées sur l'encre.
	if _title.is_empty(): return
	var slam: float = clampf((_t - 0.18) / 0.18, 0.0, 1.0)
	if slam <= 0.0: return
	var k: float = h / 900.0
	var px: float = 118.0 * k
	var shown: String = T.tr_text(_title).to_upper()
	var seed_value: int = absi(shown.hash()) % 997
	var width: float = C.width(shown, px, seed_value)
	var travel: float = (g - (- INK_LEAD - 150.0)) * (1.0 if _dir < 0.0 else -1.0)
	var scale: float = lerpf(1.45, 1.0, 1.0 - pow(1.0 - slam, 3.0))
	var center: Vector2 = Vector2(w * 0.5 + travel, h * 0.53)
	# Mots géants en contour qui défilent derrière (comme « SYSTEM » / « CONFIG »).
	var font: Font = T.font("display")
	var giant: int = int(250.0 * k)
	var giant_w: float = font.get_string_size(shown + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, giant).x
	for row: int in range(2):
		var shift: float = fposmod(_t * 900.0 * (1.0 if row == 0 else -0.7) + travel * 0.5, maxf(giant_w, 1.0))
		draw_set_transform(Vector2(- shift + (- giant_w if row == 1 else 0.0), h * (0.36 + 0.5 * float(row))), -0.12, Vector2.ONE)
		for copy: int in range(4):
			draw_string_outline(font, Vector2(giant_w * float(copy), 0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, giant, int(3.0 * k), Color(_red, 0.24 * slam * (1.0 - clampf((_t - 0.5) / 0.16, 0.0, 1.0))))
		draw_set_transform(Vector2.ZERO)
	var base: Transform2D = Transform2D(-0.12, Vector2(scale, scale), 0.0, center) * Transform2D(0.0, Vector2(- width * 0.5, px * 0.3))
	C.draw_word(self, shown, base, px, seed_value, 1.0, _red, minf(1.0, slam * 2.0), 0, false, T.CREAM, _red)
