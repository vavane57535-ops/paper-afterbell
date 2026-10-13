extends Node

# Mots en lettres découpées (collage) : lettres masquées par la découpe d'une voisine.
#   XDG_DATA_HOME=<dossier de test> godot --headless -- --tool test_collage_titles [--ct-all]
#   XDG_DATA_HOME=<dossier de test> xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 \
#       -- --tool test_collage_titles --ct-out DIR   (planches agrandies ×2 à regarder)
# Mots vérifiés, en français et en anglais : titres de page (CollageTitle, lignes coupées comme à
# l'écran), entrées du menu principal et du menu pause (normales et sélectionnées), titres des volets
# (toujours « sélectionnés »), « PAUSE ».
# Pour chaque lettre : part de sa boîte d'encre recouverte par la découpe d'une lettre dessinée
# après elle, ou posée sur une découpe de la même couleur qu'elle (lettre crème sur papier crème) ;
# une lettre seule collée à une découpe crème voisine (moins de 4 % de sa taille) compte comme touchée,
# comme une lettre dont l'encre dépasse de sa propre découpe.
# Lignes « COLLAGE <état> | <mot> | pire <lettre> <part> » au-dessus du seuil (--ct-all : toutes),
# puis COLLAGE_TEST OK|FAIL <nombre de mots touchés>.

const Collage = preload("res://ui_collage.gd")
const G = preload("res://ui_paper_geom.gd")
const T = preload("res://ui_theme.gd")
const UI = preload("res://ui.gd")

# Part de la boîte d'encre d'une lettre au-delà de laquelle elle devient difficile à lire.
const LIMIT: float = 0.06

var world: Node
var out_dir: String = ""
var show_all: bool = false
var _ink_cache: Dictionary = {}

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--ct-out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--ct-all": show_all = true
	_run.call_deferred()

# Mots à l'écran : [texte source, taille px, graine (-1 : hash % 997, -2 : hash % 9973), état, largeur max (titres)].
func _specs() -> Array:
	var rows: Array = []
	for title: Array in [["Réglages", 48], ["Boutique", 50], ["Entre amis", 50], ["Ouverture du salon", 50], ["Réglages réseau", 50], ["En attendant les autres", 50], ["Crédits", 50], ["Cinémathèque", 50], ["Choisis ton personnage", 46], ["Incarne Alice", 46], ["Choisis ton élève", 46], ["Le terrain d’essai", 40]]:
		rows.append({"text": title[0], "px": float(title[1]) * 0.92, "seed": -1, "lit": 0.0, "width": 560.0, "kind": "titre"})
	rows.append({"text": "Choisis ton élève", "px": 36.0 * 0.92, "seed": -1, "lit": 0.0, "width": 560.0, "kind": "titre"})
	for verdict: String in ["VICTOIRE D’ALICE", "VICTOIRE PAR FORFAIT", "LES ÉLÈVES S’ÉCHAPPENT"]:
		rows.append({"text": verdict, "px": 70.0 * 0.92, "seed": -1, "lit": 0.0, "width": 500.0, "kind": "titre"})
	rows.append({"text": "Mon carnet de commandes", "px": 40.0, "seed": -1, "lit": 0.0, "width": 900.0, "kind": "titre"})
	for entry: Array in [["JOUER", 60], ["ENTRE AMIS", 34], ["TERRAIN D’ESSAI", 34], ["BOUTIQUE", 34], ["CINÉMATHÈQUE", 34], ["RÉGLAGES", 34], ["CRÉDITS", 34], ["QUITTER", 34], ["REPRENDRE", 76], ["RÉGLAGES", 60], ["COMMANDES", 60], ["QUITTER LA PARTIE", 60]]:
		for lit: float in [0.0, 1.25]:
			rows.append({"text": entry[0], "px": float(entry[1]) * 1.08, "seed": -2, "lit": lit, "width": 0.0, "kind": "menu"})
	for page: String in UI.PAGE_TITLES.values():
		rows.append({"text": page, "px": 118.0, "seed": -1, "lit": 1.0, "width": 0.0, "kind": "volet"})
	rows.append({"text": "PAUSE", "px": 150.0, "seed": 77, "lit": 0.0, "width": 0.0, "kind": "pause"})
	return rows

# Lignes telles que CollageTitle les coupe (même règle de largeur).
func _lines(text: String, px: float, width: float) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if width <= 0.0:
		lines.append(text)
		return lines
	var line: String = ""
	for word: String in text.split(" ", false):
		var attempt: String = word if line.is_empty() else line + " " + word
		if not line.is_empty() and Collage.width(attempt, px, absi(attempt.hash()) % 997) > width:
			lines.append(line)
			line = word
		else: line = attempt
	if not line.is_empty(): lines.append(line)
	return lines

func _seed(line: String, mode: int) -> int:
	if mode == -1: return absi(line.hash()) % 997
	if mode == -2: return absi(line.hash()) % 9973
	return mode

# Boîte d'encre d'une lettre (repère : plume au début de la lettre, sur la ligne de base).
func _ink(kind: String, ch: String, fs: int) -> Rect2:
	var key: String = "%s|%s|%d" % [kind, ch, fs]
	if _ink_cache.has(key): return _ink_cache[key]
	var font: Font = T.font(kind)
	var ts: TextServer = TextServerManager.get_primary_interface()
	var code: int = ch.unicode_at(0)
	var result: Rect2 = Rect2()
	for rid: RID in font.get_rids():
		var glyph: int = ts.font_get_glyph_index(rid, fs, code, 0)
		if glyph == 0: continue
		var offset: Vector2 = ts.font_get_glyph_offset(rid, Vector2i(fs, 0), glyph)
		var extent: Vector2 = ts.font_get_glyph_size(rid, Vector2i(fs, 0), glyph)
		if extent.x > 0.0:
			# La texture du glyphe a une marge d'un ou deux pixels : on la retire.
			result = Rect2(offset, extent).grow(-1.5)
			break
	if result.size.x <= 0.0:
		var advance: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		result = Rect2(Vector2(advance * 0.06, - fs * 0.72), Vector2(advance * 0.88, fs * 0.72))
	_ink_cache[key] = result
	return result

func _area(poly: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5

func _overlap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var total: float = 0.0
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(a, b): total += _area(piece)
	return total

func _rect_poly(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

# Géométrie dessinée par Collage.draw_word pour un état donné (lit > 0.5 : toutes les lettres ont une découpe).
func _glyph_shapes(line: String, px: float, seed_value: int, lit: float) -> Array:
	var data: Dictionary = Collage.layout(line, px, seed_value, false)
	var on: bool = lit > 0.5
	var shapes: Array = []
	for glyph: Dictionary in data.glyphs:
		var fs: int = int(glyph.fs)
		var half: float = float(glyph.adv) * 0.5
		var xform: Transform2D = Transform2D(float(glyph.rot), Vector2(float(glyph.x) + half, float(glyph.dy)))
		var ink_box: Rect2 = _ink(str(glyph.kind), str(glyph.ch), fs)
		ink_box.position.x -= half
		var chip: int = int(glyph.chip)
		if on: chip = Collage.CHIP_CREAM if chip in [Collage.CHIP_NONE, Collage.CHIP_RED] else Collage.CHIP_INK
		var paper: PackedVector2Array = PackedVector2Array()
		if chip != Collage.CHIP_NONE:
			var lit_only: bool = int(glyph.chip) == Collage.CHIP_NONE and glyph.has("lit_paper")
			var local: PackedVector2Array = glyph.lit_paper if lit_only else glyph.get("paper", PackedVector2Array())
			if local.is_empty():
				var top: float = float(glyph.get("top", 0.79))
				var box: Rect2 = Rect2(Vector2(- half - fs * 0.06, - fs * top), Vector2(float(glyph.adv) + fs * 0.12, fs * (top + float(glyph.get("bottom", 0.11)))))
				local = G.cut(box, int(glyph.seed), 0.1)
			paper = xform * local
		shapes.append({"ch": str(glyph.ch), "chip": chip, "fs": fs, "ink": xform * _rect_poly(ink_box), "paper": paper})
	return shapes

# Plus petite distance entre deux formes (0 si elles se touchent ou se recouvrent).
func _gap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if not Geometry2D.intersect_polygons(a, b).is_empty(): return 0.0
	var best: float = INF
	for i: int in range(a.size()):
		for j: int in range(b.size()):
			var points: PackedVector2Array = Geometry2D.get_closest_points_between_segments(a[i], a[(i + 1) % a.size()], b[j], b[(j + 1) % b.size()])
			best = minf(best, points[0].distance_to(points[1]))
	return best

# Pire lettre d'une ligne : [lettre, part masquée].
func _worst(line: String, px: float, seed_value: int, lit: float) -> Array:
	var shapes: Array = _glyph_shapes(line, px, seed_value, lit)
	var worst: Array = ["", 0.0]
	for i: int in range(shapes.size()):
		var ink: PackedVector2Array = shapes[i].ink
		var area: float = maxf(_area(ink), 1.0)
		var hidden: float = 0.0
		# Découpes des lettres suivantes, dessinées par-dessus.
		for j: int in range(i + 1, shapes.size()):
			if not (shapes[j].paper as PackedVector2Array).is_empty(): hidden += _overlap(ink, shapes[j].paper)
			# Lettre suivante (sans découpe) qui chevauche celle-ci.
			elif int(shapes[j].chip) == Collage.CHIP_NONE: hidden += _overlap(ink, shapes[j].ink)
		# Lettre sans découpe (crème) posée sur la découpe crème d'une lettre précédente.
		if int(shapes[i].chip) == Collage.CHIP_NONE:
			for j: int in range(i):
				if int(shapes[j].chip) == Collage.CHIP_CREAM: hidden += _overlap(ink, shapes[j].paper)
		var part: float = hidden / area
		# Lettre qui dépasse de sa propre découpe : le bout qui dépasse passe sur le fond (lettre sombre invisible).
		if not (shapes[i].paper as PackedVector2Array).is_empty():
			part = maxf(part, 1.0 - _overlap(ink, shapes[i].paper) / area)
		# Lettre seule (crème) collée à une découpe crème voisine : elles se fondent en une seule forme.
		if int(shapes[i].chip) == Collage.CHIP_NONE:
			for j: int in [i - 1, i + 1]:
				if j < 0 or j >= shapes.size() or int(shapes[j].chip) != Collage.CHIP_CREAM: continue
				if _gap(ink, shapes[j].paper) < float(shapes[i].fs) * 0.04: part = maxf(part, LIMIT + 0.01)
		if part > float(worst[1]): worst = [str(shapes[i].ch) + "#" + str(i), part]
	return worst

func _run() -> void :
	await get_tree().process_frame
	var touched: int = 0
	var checked: int = 0
	for language: String in ["fr", "en"]:
		PaperLanguage.language = language
		for spec: Dictionary in _specs():
			var shown: String = (T.tr_text(str(spec.text))).to_upper()
			for line: String in _lines(shown, float(spec.px), float(spec.width)):
				var seed_value: int = _seed(line, int(spec.seed))
				var worst: Array = _worst(line, float(spec.px), seed_value, float(spec.lit))
				checked += 1
				var bad: bool = float(worst[1]) > LIMIT
				if bad: touched += 1
				if bad or show_all:
					print("COLLAGE %s %s %s | %s | pire %s %.0f %%%s" % [language, spec.kind, "sélectionné" if float(spec.lit) > 0.5 else "normal", line, worst[0], float(worst[1]) * 100.0, "  <<<" if bad else ""])
	PaperLanguage.language = "fr"
	print("COLLAGE_TEST %s %d/%d mots touchés (seuil %.0f %%)" % ["OK" if touched == 0 else "FAIL", touched, checked, LIMIT * 100.0])
	if not out_dir.is_empty() and DisplayServer.get_name() != "headless": await _sheets()
	get_tree().quit()

# Planches agrandies (×2) : chaque mot, normal puis sélectionné pour les entrées de menu.
func _sheets() -> void :
	DirAccess.make_dir_recursive_absolute(out_dir)
	world.ui.hide()
	for language: String in ["fr", "en"]:
		PaperLanguage.language = language
		var specs: Array = _specs()
		var page: int = 0
		var index: int = 0
		while index < specs.size():
			var viewport: SubViewport = SubViewport.new()
			viewport.size = Vector2i(1800, 1300)
			viewport.transparent_bg = false
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(viewport)
			var back: ColorRect = ColorRect.new()
			back.color = Color("17181f")
			back.size = Vector2(viewport.size)
			viewport.add_child(back)
			var board: Board = Board.new()
			board.size = Vector2(viewport.size)
			viewport.add_child(board)
			var y: float = 20.0
			while index < specs.size():
				var spec: Dictionary = specs[index]
				var shown: String = (T.tr_text(str(spec.text))).to_upper()
				var lines: PackedStringArray = _lines(shown, float(spec.px), float(spec.width))
				var zoom: float = 2.0 if float(spec.px) < 70.0 else 1.2
				var height: float = float(lines.size()) * float(spec.px) * 1.25 * zoom + 18.0
				if y + height > float(viewport.size.y) - 10.0: break
				for i: int in range(lines.size()):
					board.words.append({"text": lines[i], "px": float(spec.px), "seed": _seed(lines[i], int(spec.seed)), "lit": float(spec.lit), "at": Vector2(40.0 + float(spec.px) * 0.4 * zoom, y + float(spec.px) * 1.05 * zoom + float(i) * float(spec.px) * 1.12 * zoom), "zoom": zoom, "dark": spec.kind == "titre"})
				y += height
				index += 1
			board.queue_redraw()
			for frame: int in range(3): await RenderingServer.frame_post_draw
			var path: String = out_dir.path_join("collage_%s_%d.png" % [language, page])
			viewport.get_texture().get_image().save_png(path)
			print("COLLAGE_SHEET ", path)
			viewport.queue_free()
			page += 1
	PaperLanguage.language = "fr"

class Board extends Control:
	var words: Array = []

	func _draw() -> void :
		for word: Dictionary in words:
			var base: Transform2D = Transform2D(-0.03, Vector2(float(word.zoom), float(word.zoom)), 0.0, word.at)
			Collage.draw_word(self, str(word.text), base, float(word.px), int(word.seed), float(word.lit), T.RED, 1.0, 0, false, T.CREAM, T.RED, bool(word.dark))
