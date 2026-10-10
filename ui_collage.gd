extends RefCounted

# Typographie « collage » des menus : chaque lettre est découpée dans un
# papier différent (crème, encre, rouge), avec sa police, sa taille et son
# inclinaison, comme les commandes des menus de Persona mais en papier.
# Fonctions statiques : les widgets (NavItem, menu pause, décors) les
# appellent depuis leur _draw.

const T = preload("res://ui_theme.gd")
const G = preload("res://ui_paper_geom.gd")

const CHIP_NONE: int = 0
const CHIP_CREAM: int = 1
const CHIP_INK: int = 2
const CHIP_RED: int = 3
const INK_CHIP: Color = Color("15131b")
const KEEP_CASE: String = "ÉÈÊËÀÂÇÔÛÙÎÏ’'·-–—!?.:,0123456789"

static var _layouts: Dictionary = {}


# Mise en page déterministe d'un mot : une entrée par lettre.
static func layout(text: String, size_px: float, seed_value: int, plain: bool = false) -> Dictionary:
	var key: String = "%s|%d|%d|%s" % [text, int(size_px), seed_value, plain]
	if _layouts.has(key): return _layouts[key]
	if _layouts.size() > 600: _layouts.clear()
	var glyphs: Array = []
	var x: float = 0.0
	var kinds: Array[String] = ["display", "display", "display", "digits", "title", "display", "logo", "digits"]
	var letter: int = 0
	for i: int in range(text.length()):
		var ch: String = text[i]
		if ch == " ":
			x += size_px * 0.3
			continue
		var kind: String = "display" if plain else kinds[int(G.noise(seed_value, i * 3 + 2) * kinds.size()) % kinds.size()]
		var scale: float = 1.0 if plain else (1.22 if letter == 0 else lerpf(0.84, 1.06, G.noise(seed_value, i * 3 + 3)))
		var fs: int = int(round(size_px * scale))
		var shown: String = ch
		if not plain and kind == "display" and letter > 0 and G.noise(seed_value, i * 3 + 1) > 0.82 and KEEP_CASE.find(ch) < 0: shown = ch.to_lower()
		var font: Font = T.font(kind)
		var advance: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var chip: int = CHIP_NONE
		if not plain:
			var c: float = G.noise(seed_value, i * 7 + 5)
			chip = CHIP_CREAM if c < 0.32 else CHIP_INK if c < 0.47 else CHIP_RED if c < 0.55 else CHIP_NONE
		var pad: float = fs * 0.06 if chip != CHIP_NONE else fs * 0.02
		glyphs.append({
			"ch": shown, "kind": kind, "fs": fs, "x": x + pad, "adv": advance,
			"dy": 0.0 if plain else (G.noise(seed_value, i * 5 + 7) - 0.5) * size_px * 0.12,
			"rot": 0.0 if plain else (G.noise(seed_value, i * 5 + 9) - 0.5) * 0.19,
			"chip": chip, "seed": seed_value * 31 + i,
		})
		x += advance + pad * 2.0
		letter += 1
	var result: Dictionary = {"glyphs": glyphs, "width": x, "size": size_px}
	_layouts[key] = result
	return result


static func width(text: String, size_px: float, seed_value: int, plain: bool = false) -> float:
	return float(layout(text, size_px, seed_value, plain).width)


# Dessine un mot collage dans le repère `base` (origine = début de la ligne
# de base ; rotation/échelle de l'entrée). lit (0..1+) : élément sélectionné
# (dalle colorée découpée qui se déplie, lettres inversées). boil > 0 : le
# trait frémit (image courante du boil).
static func draw_word(ci: CanvasItem, text: String, base: Transform2D, size_px: float, seed_value: int, lit: float = 0.0, accent: Color = T.RED, alpha: float = 1.0, boil: int = 0, plain: bool = false, letter_color: Color = T.CREAM, red_chip: Color = T.RED) -> void :
	var data: Dictionary = layout(text, size_px, seed_value, plain)
	var glyphs: Array = data.glyphs
	if glyphs.is_empty(): return
	var item: RID = ci.get_canvas_item()
	var total: float = float(data.width)
	var on: bool = lit > 0.5
	var amount: float = clampf(lit, 0.0, 1.0)
	if lit > 0.02:
		# Dalle de papier coloré découpée derrière le mot (ombre d'encre).
		var unfold: float = lerpf(0.12, 1.0, ease(amount, 0.5))
		var slab: Rect2 = Rect2(Vector2(- size_px * 0.32, - size_px * 0.98), Vector2((total + size_px * 0.66) * unfold, size_px * 1.24))
		var shape: PackedVector2Array = G.transformed(G.cut(slab, seed_value * 5 + boil * 3, 0.24), base)
		G.polygon(item, G.offset(shape, Vector2(size_px * 0.14, size_px * 0.16)), Color(T.INK, 0.9 * alpha * amount))
		G.polygon(item, shape, Color(accent, alpha * minf(1.0, lit * 1.6)))
		var slash: Rect2 = Rect2(slab.position + Vector2(slab.size.x * 0.06, slab.size.y * 0.8), Vector2(slab.size.x * 0.92, maxf(3.0, size_px * 0.08)))
		G.polygon(item, G.transformed(G.strip(slash, size_px * 0.08, 2.0, 1.0, seed_value + boil), base), Color(T.CREAM, 0.9 * alpha * amount))
	for glyph: Dictionary in glyphs:
		var fs: int = int(glyph.fs)
		var font: Font = T.font(str(glyph.kind))
		var rot: float = float(glyph.rot)
		var jitter: Vector2 = Vector2.ZERO
		if boil > 0 and on:
			jitter = Vector2(G.noise(int(glyph.seed) + boil, 1) - 0.5, G.noise(int(glyph.seed) + boil, 2) - 0.5) * size_px * 0.045
			rot += (G.noise(int(glyph.seed) + boil, 3) - 0.5) * 0.05
		var half: float = float(glyph.adv) * 0.5
		ci.draw_set_transform_matrix(base * Transform2D(rot, Vector2(float(glyph.x) + half, float(glyph.dy)) + jitter))
		var chip: int = int(glyph.chip)
		if on: chip = CHIP_CREAM if chip in [CHIP_NONE, CHIP_RED] else CHIP_INK
		var ink: Color = letter_color
		if chip != CHIP_NONE:
			var box: Rect2 = Rect2(Vector2(- half - fs * 0.06, - fs * 0.79), Vector2(float(glyph.adv) + fs * 0.12, fs * 0.9))
			var paper: PackedVector2Array = G.cut(box, int(glyph.seed), 0.1)
			var chip_color: Color = T.CREAM if chip == CHIP_CREAM else INK_CHIP if chip == CHIP_INK else red_chip
			G.polygon(item, G.offset(paper, Vector2(fs * 0.05, fs * 0.07)), Color(0, 0, 0, 0.5 * alpha))
			G.polygon(item, paper, Color(chip_color, alpha))
			ink = T.INK_TEXT if chip == CHIP_CREAM else T.CREAM
		elif on:
			ink = T.INK_TEXT
		else:
			# Lettre seule : ombre portée d'encre pour la décoller du fond.
			ci.draw_string(font, Vector2(- half + fs * 0.045, fs * 0.055), str(glyph.ch), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * alpha))
		ci.draw_string(font, Vector2(- half, 0), str(glyph.ch), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, alpha))
	ci.draw_set_transform(Vector2.ZERO)


# Flèche de papier découpé (après l'entrée principale).
static func draw_arrow(ci: CanvasItem, base: Transform2D, at: Vector2, px: float, color: Color, alpha: float = 1.0) -> void :
	var arrow: PackedVector2Array = PackedVector2Array([at + Vector2(0, - px * 0.1), at + Vector2(px * 0.55, - px * 0.14), at + Vector2(px * 0.5, - px * 0.34), at + Vector2(px * 0.95, 0), at + Vector2(px * 0.48, px * 0.36), at + Vector2(px * 0.52, px * 0.15), at + Vector2(0, px * 0.12)])
	var shape: PackedVector2Array = G.transformed(arrow, base)
	G.polygon(ci.get_canvas_item(), G.offset(shape, Vector2(3, 4)), Color(0, 0, 0, 0.6 * alpha))
	G.polygon(ci.get_canvas_item(), shape, Color(color, alpha))


# Mot géant incliné (titre de page, « PAUSE »…), rempli et/ou en contour.
static func draw_giant(ci: CanvasItem, text: String, at: Vector2, size_px: int, angle: float, fill: Color, outline: Color = Color(0, 0, 0, 0), outline_px: int = 0) -> void :
	var font: Font = T.font("display")
	ci.draw_set_transform(at, angle, Vector2.ONE)
	if outline.a > 0.0 and outline_px > 0: ci.draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, outline_px, outline)
	if fill.a > 0.0: ci.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, fill)
	ci.draw_set_transform(Vector2.ZERO)


# Ruban de scotch avec texte répété qui défile le long d'une droite.
static func draw_ribbon(ci: CanvasItem, from: Vector2, to: Vector2, thickness: float, text: String, scroll: float, paper: Color, ink: Color, seed_value: int = 3) -> void :
	var item: RID = ci.get_canvas_item()
	var shape: PackedVector2Array = G.band(from, to, thickness, seed_value, 3.0)
	G.polygon(item, G.offset(shape, Vector2(3, 6)), Color(0, 0, 0, 0.35 * minf(1.0, paper.a * 3.0)))
	G.polygon(item, shape, paper)
	var font: Font = T.font("caps_wide")
	var fs: int = maxi(8, int(thickness * 0.5))
	var unit: String = text + "   ·   "
	var unit_w: float = font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if unit_w <= 1.0: return
	var direction: Vector2 = (to - from).normalized()
	var length: float = from.distance_to(to)
	ci.draw_set_transform(from, direction.angle(), Vector2.ONE)
	var x: float = - fposmod(scroll, unit_w)
	while x < length:
		ci.draw_string(font, Vector2(x, fs * 0.36), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		x += unit_w
	ci.draw_set_transform(Vector2.ZERO)
