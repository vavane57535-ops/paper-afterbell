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
# Lettres jamais passées en minuscule : accents, et I/J/L/T dont la minuscule
# se confond avec une autre lettre dans la police d'affichage.
const KEEP_CASE: String = "ÉÈÊËÀÂÇÔÛÙÎÏIJLT’'·-–—!?.:,0123456789"
# Écarts minimaux entre lettres voisines (fraction de la taille de la lettre), mesurés sur
# l'encre réelle et la découpe inclinée : une découpe ne recouvre jamais l'encre de la lettre
# d'avant (elle est dessinée par-dessus), et une lettre seule, crème, ne touche pas une
# découpe crème voisine (sinon elles se fondent : « SETTINGS » se lisait « SETINGS »).
const GAP_INK: float = 0.03
const GAP_LIGHT: float = 0.06
const GAP_PLAIN: float = 0.015

static var _layouts: Dictionary = {}
static var _inks: Dictionary = {}


# Mise en page déterministe d'un mot : une entrée par lettre.
static func layout(text: String, size_px: float, seed_value: int, plain: bool = false) -> Dictionary:
	var key: String = "%s|%d|%d|%s" % [text, int(size_px), seed_value, plain]
	if _layouts.has(key): return _layouts[key]
	if _layouts.size() > 600: _layouts.clear()
	var glyphs: Array = []
	var x: float = 0.0
	var kinds: Array[String] = ["display", "display", "display", "digits", "title", "display", "logo", "digits"]
	var letter: int = 0
	# Formes déjà posées, dans le repère du mot : encre, découpe (vide sans découpe), type de découpe.
	var placed: Array = []
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
		var glyph: Dictionary = {
			"ch": shown, "kind": kind, "fs": fs, "x": x + pad, "adv": advance,
			"dy": 0.0 if plain else (G.noise(seed_value, i * 5 + 7) - 0.5) * size_px * 0.12,
			"rot": 0.0 if plain else (G.noise(seed_value, i * 5 + 9) - 0.5) * 0.19,
			"chip": chip, "seed": seed_value * 31 + i,
			# Accent au-dessus / cédille en dessous : morceau de papier agrandi.
			"top": 1.02 if "ÉÈÊËÀÂÄÔÖÛÙÜÎÏ".find(shown) >= 0 else 0.79,
			"bottom": 0.3 if shown == "Ç" or shown == "ç" else 0.11,
		}
		if not plain:
			# Lettre décalée vers la droite, juste assez, si elle mordait sur ses voisines de gauche.
			var half: float = advance * 0.5
			var ink: Rect2 = _ink_box(font, kind, shown, fs, advance)
			ink.position.x -= half
			var top: float = float(glyph.top)
			var paper: PackedVector2Array = _hug(G.cut(Rect2(Vector2(- half - fs * 0.06, - fs * top), Vector2(advance + fs * 0.12, fs * (top + float(glyph.bottom)))), int(glyph.seed), 0.1), ink.grow(fs * 0.02))
			var place: Transform2D = Transform2D(float(glyph.rot), Vector2(float(glyph.x) + half, float(glyph.dy)))
			var ink_shape: PackedVector2Array = place * _corners(ink)
			var paper_shape: PackedVector2Array = place * paper
			var shift: float = 0.0
			for j: int in range(maxi(0, placed.size() - 2), placed.size()):
				var other: Dictionary = placed[j]
				var next_to: bool = j == placed.size() - 1
				shift = maxf(shift, _sweep(other.ink, ink_shape) + fs * GAP_PLAIN)
				if chip != CHIP_NONE: shift = maxf(shift, _sweep(other.ink, paper_shape) + fs * (GAP_LIGHT if next_to and chip == CHIP_CREAM and int(other.chip) == CHIP_NONE else GAP_INK))
				elif next_to and int(other.chip) == CHIP_CREAM: shift = maxf(shift, _sweep(other.paper, ink_shape) + fs * GAP_LIGHT)
			if shift > 0.0:
				x += shift
				glyph.x = float(glyph.x) + shift
				place.origin.x += shift
				ink_shape = place * _corners(ink)
				paper_shape = place * paper
			if chip != CHIP_NONE:
				glyph["paper"] = paper
				glyph["paper_shade"] = G.offset(paper, Vector2(fs * 0.05, fs * 0.07))
			else:
				# Découpe de l'état sélectionné (toutes les lettres en ont une) : recoupée autour de
				# l'encre des lettres d'avant, qu'elle ne doit pas recouvrir.
				var lit: PackedVector2Array = paper_shape
				for j: int in range(maxi(0, placed.size() - 2), placed.size()):
					var pieces: Array = Geometry2D.clip_polygons(lit, placed[j].halo)
					var biggest: float = 0.0
					for piece: PackedVector2Array in pieces:
						var area: float = _area(piece)
						if area > biggest:
							biggest = area
							lit = piece
				paper = place.affine_inverse() * lit
				glyph["lit_paper"] = paper
				glyph["lit_shade"] = G.offset(paper, Vector2(fs * 0.05, fs * 0.07))
			placed.append({"ink": ink_shape, "paper": paper_shape if chip != CHIP_NONE else PackedVector2Array(), "chip": chip, "halo": place * _corners(ink.grow(fs * GAP_PLAIN))})
		glyphs.append(glyph)
		x += advance + pad * 2.0
		letter += 1
	var result: Dictionary = {"glyphs": glyphs, "width": x, "size": size_px}
	_layouts[key] = result
	return result


static func width(text: String, size_px: float, seed_value: int, plain: bool = false) -> float:
	return float(layout(text, size_px, seed_value, plain).width)


# Boîte d'encre d'une lettre, depuis la plume posée sur la ligne de base (métriques du glyphe ;
# repli : boîte d'avance à hauteur de capitale).
static func _ink_box(font: Font, kind: String, shown: String, fs: int, advance: float) -> Rect2:
	var key: String = "%s|%s|%d" % [kind, shown, fs]
	if _inks.has(key): return _inks[key]
	var result: Rect2 = Rect2(Vector2(advance * 0.04, - fs * 0.72), Vector2(advance * 0.92, fs * 0.72))
	var server: TextServer = TextServerManager.get_primary_interface()
	if server and not shown.is_empty():
		for rid: RID in font.get_rids():
			var index: int = server.font_get_glyph_index(rid, fs, shown.unicode_at(0), 0)
			if index == 0: continue
			var extent: Vector2 = server.font_get_glyph_size(rid, Vector2i(fs, 0), index)
			# La texture du glyphe garde une marge d'un pixel autour de l'encre.
			if extent.x > 2.0 and extent.y > 2.0: result = Rect2(server.font_get_glyph_offset(rid, Vector2i(fs, 0), index), extent).grow(-1.0)
			break
	if _inks.size() > 2000: _inks.clear()
	_inks[key] = result
	return result


# Découpe élargie là où une encoche du découpage (sommets de G.cut, dans l'ordre : haut gauche,
# haut, haut droit, droite, bas droit, bas, bas gauche) mordrait sur l'encre : une lettre sombre
# qui dépassait de son papier crème disparaissait sur le fond (le T de « CHARACTER » lu « I »).
static func _hug(paper: PackedVector2Array, ink: Rect2) -> PackedVector2Array:
	if paper.size() != 7: return paper
	var out: PackedVector2Array = paper.duplicate()
	out[0] = Vector2(minf(out[0].x, ink.position.x), minf(out[0].y, ink.position.y))
	out[1].y = minf(out[1].y, ink.position.y)
	out[2] = Vector2(maxf(out[2].x, ink.end.x), minf(out[2].y, ink.position.y))
	out[3].x = maxf(out[3].x, ink.end.x)
	out[4] = Vector2(maxf(out[4].x, ink.end.x), maxf(out[4].y, ink.end.y))
	out[5].y = maxf(out[5].y, ink.end.y)
	out[6] = Vector2(minf(out[6].x, ink.position.x), maxf(out[6].y, ink.end.y))
	return out


static func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


static func _area(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


# Chevauchement horizontal de deux formes posées côte à côte : à chaque hauteur commune, bord droit
# de la forme de gauche moins bord gauche de celle de droite (le plus grand ; -INF si elles ne sont
# jamais à la même hauteur). Les bords étant des segments, il suffit des hauteurs des sommets.
static func _sweep(left: PackedVector2Array, right: PackedVector2Array) -> float:
	var low: float = maxf(_rise(left).x, _rise(right).x)
	var high: float = minf(_rise(left).y, _rise(right).y)
	if low >= high: return - INF
	var heights: Array[float] = [low, high]
	for point: Vector2 in left + right:
		if point.y > low and point.y < high: heights.append(point.y)
	var worst: float = - INF
	for y: float in heights:
		var a: Vector2 = _cross(left, y)
		var b: Vector2 = _cross(right, y)
		if a.x <= a.y and b.x <= b.y: worst = maxf(worst, a.y - b.x)
	return worst


# Hauteurs extrêmes (min, max) d'une forme.
static func _rise(points: PackedVector2Array) -> Vector2:
	var span: Vector2 = Vector2(INF, - INF)
	for point: Vector2 in points: span = Vector2(minf(span.x, point.y), maxf(span.y, point.y))
	return span


# Étendue horizontale (min, max) d'une forme coupée par la ligne de hauteur y.
static func _cross(points: PackedVector2Array, y: float) -> Vector2:
	var span: Vector2 = Vector2(INF, - INF)
	for i: int in range(points.size()):
		var p: Vector2 = points[i]
		var q: Vector2 = points[(i + 1) % points.size()]
		if (p.y - y) * (q.y - y) > 0.0: continue
		if is_equal_approx(p.y, q.y):
			span = Vector2(minf(span.x, minf(p.x, q.x)), maxf(span.y, maxf(p.x, q.x)))
		else:
			var at: float = lerpf(p.x, q.x, (y - p.y) / (q.y - p.y))
			span = Vector2(minf(span.x, at), maxf(span.y, at))
	return span


# Dessine un mot collage dans le repère `base` (origine = début de la ligne
# de base ; rotation/échelle de l'entrée). lit (0..1+) : élément sélectionné
# (dalle colorée découpée qui se déplie, lettres inversées). boil > 0 : le
# trait frémit (image courante du boil).
static func draw_word(ci: CanvasItem, text: String, base: Transform2D, size_px: float, seed_value: int, lit: float = 0.0, accent: Color = T.RED, alpha: float = 1.0, boil: int = 0, plain: bool = false, letter_color: Color = T.CREAM, red_chip: Color = T.RED, dark_on_light: bool = false) -> void :
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
			# Lettre seule à l'état sélectionné : découpe recoupée par la mise en page.
			var lit_only: bool = int(glyph.chip) == CHIP_NONE and glyph.has("lit_paper")
			# Morceau de papier de la lettre : fixe pour une mise en page donnée,
			# calculé une fois puis gardé dans la lettre.
			if not lit_only and not glyph.has("paper"):
				var top: float = float(glyph.get("top", 0.79))
				var box: Rect2 = Rect2(Vector2(- half - fs * 0.06, - fs * top), Vector2(float(glyph.adv) + fs * 0.12, fs * (top + float(glyph.get("bottom", 0.11)))))
				var cut_paper: PackedVector2Array = G.cut(box, int(glyph.seed), 0.1)
				glyph["paper"] = cut_paper
				glyph["paper_shade"] = G.offset(cut_paper, Vector2(fs * 0.05, fs * 0.07))
			var paper: PackedVector2Array = glyph.lit_paper if lit_only else glyph.paper
			var chip_color: Color = T.CREAM if chip == CHIP_CREAM else INK_CHIP if chip == CHIP_INK else red_chip
			G.polygon(item, glyph.lit_shade if lit_only else glyph.paper_shade, Color(0, 0, 0, 0.5 * alpha))
			G.polygon(item, paper, Color(chip_color, alpha))
			ink = T.INK_TEXT if chip == CHIP_CREAM else T.CREAM
			# Titres : sur une découpe claire (turquoise d'un verdict…), lettre à l'encre sombre, lisible.
			if dark_on_light and chip == CHIP_RED and red_chip.get_luminance() > 0.5: ink = T.INK_TEXT
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
