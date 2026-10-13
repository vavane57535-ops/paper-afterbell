extends RefCounted

# Styles « papier découpé » des menus (inspirés des menus de Persona) :
# bandes de papier inclinées aux bords déchirés, découpe colorée derrière
# l'élément sélectionné, trait de surligneur, feuilles d'encre scotchées.
# ui_theme.gd s'en sert pour construire le thème commun : tout bouton,
# champ ou curseur créé par Button.new() & co hérite de ces styles.

const G = preload("res://ui_paper_geom.gd")



# Bande de papier : style des boutons, onglets, champs et lignes.
class Strip extends StyleBox:
	var fill: Color = Color("1b1f2c")
	var line: Color = Color(0, 0, 0, 0)
	var line_width: float = 1.0
	var shadow: Color = Color(0, 0, 0, 0.45)
	var shadow_offset: Vector2 = Vector2(3, 4)
	var cut_color: Color = Color(0, 0, 0, 0)
	var cut_grow: Vector2 = Vector2(7, 5)
	var cut_offset: Vector2 = Vector2(6, 3)
	var skew: float = 7.0
	var torn: float = 1.4
	var seed_value: int = 5
	var boil: bool = false
	var highlighter: bool = false
	var underline: Color = Color(0, 0, 0, 0)
	var notch: Color = Color(0, 0, 0, 0)
	var grow_rect: Vector2 = Vector2.ZERO

	func _init(margin_h: float = 18.0, margin_v: float = 9.0) -> void :
		content_margin_left = margin_h
		content_margin_right = margin_h
		content_margin_top = margin_v
		content_margin_bottom = margin_v

	func _draw(to_canvas_item: RID, rect: Rect2) -> void :
		var r: Rect2 = rect.grow_individual(grow_rect.x, grow_rect.y, grow_rect.x, grow_rect.y)
		var s: int = seed_value + (G.boil_frame * 7 if boil else 0)
		if highlighter:
			# Trait de surligneur : bande irrégulière derrière le texte.
			var band_rect: Rect2 = Rect2(r.position + Vector2(-4, r.size.y * 0.14), Vector2(r.size.x + 8, r.size.y * 0.74))
			var marker: PackedVector2Array = G.strip(band_rect, skew, 4.0, 2.2, s)
			if shadow.a > 0.0: G.polygon(to_canvas_item, G.offset(marker, shadow_offset), shadow)
			G.polygon(to_canvas_item, marker, fill)
			if underline.a > 0.0: RenderingServer.canvas_item_add_line(to_canvas_item, Vector2(band_rect.position.x + 4, band_rect.end.y + 2), Vector2(band_rect.end.x - 6, band_rect.end.y), underline, 2.0, true)
			return
		if cut_color.a > 0.0:
			var back: Rect2 = r.grow_individual(cut_grow.x, cut_grow.y, cut_grow.x * 0.6, cut_grow.y)
			G.polygon(to_canvas_item, G.offset(G.cut(back, s + 3, 0.22), cut_offset), cut_color)
		var shape: PackedVector2Array = G.strip(r, skew, torn * 1.6, torn, s)
		if shadow.a > 0.0: G.polygon(to_canvas_item, G.offset(shape, shadow_offset), shadow)
		G.polygon(to_canvas_item, shape, fill)
		if line.a > 0.0 and shape.size() > 2:
			var closed: PackedVector2Array = shape.duplicate()
			closed.append(shape[0])
			RenderingServer.canvas_item_add_polyline(to_canvas_item, closed, PackedColorArray([line]), line_width, true)
		if notch.a > 0.0:
			# Encoche colorée à gauche (repère de liste façon Persona).
			var top: float = r.position.y + 4.0
			var bottom: float = r.end.y - 4.0
			var lean: float = clampf(skew, 0.0, r.size.y * 0.9) * 0.9
			G.polygon(to_canvas_item, PackedVector2Array([Vector2(r.position.x + lean + 2, top), Vector2(r.position.x + lean + 9, top), Vector2(r.position.x + 9, bottom), Vector2(r.position.x + 2, bottom)]), notch)
		if underline.a > 0.0:
			var y: float = r.end.y - 2.0
			RenderingServer.canvas_item_add_line(to_canvas_item, Vector2(r.position.x + 6, y), Vector2(r.end.x - skew - 4, y + 1.0), underline, 2.0, true)



# Feuille d'encre scotchée : panneaux des formulaires (réglages, salon…).
class Sheet extends StyleBox:
	var fill: Color = Color(0.07, 0.082, 0.12, 0.97)
	var back: Color = Color("8f2439")
	var back_offset: Vector2 = Vector2(12, 14)
	var back_angle: float = 0.012
	var shadow: Color = Color(0, 0, 0, 0.5)
	var seed_value: int = 17
	var torn: float = 3.2
	var ruled: bool = true
	var tape: bool = true
	var margin_line: bool = true
	var edge_color: Color = Color(1, 1, 1, 0.06)

	func _init(margin_h: float = 30.0, margin_v: float = 26.0) -> void :
		content_margin_left = margin_h
		content_margin_right = margin_h
		content_margin_top = margin_v
		content_margin_bottom = margin_v

	func _outline(rect: Rect2, salt: int) -> PackedVector2Array:
		var points: PackedVector2Array = PackedVector2Array()
		var a: Vector2 = rect.position
		var b: Vector2 = Vector2(rect.end.x, rect.position.y)
		var c: Vector2 = rect.end
		var d: Vector2 = Vector2(rect.position.x, rect.end.y)
		G.edge(points, a, b, torn * 0.4, seed_value + salt + 1, 14.0)
		G.edge(points, b, c, torn, seed_value + salt + 2, 8.0)
		G.edge(points, c, d, torn, seed_value + salt + 3, 9.0)
		G.edge(points, d, a, torn * 0.3, seed_value + salt + 4, 16.0)
		return points

	func _draw(to_canvas_item: RID, rect: Rect2) -> void :
		if back.a > 0.0:
			var center: Vector2 = rect.get_center()
			var xform: Transform2D = Transform2D(back_angle, center + back_offset) * Transform2D(0.0, - center)
			G.polygon(to_canvas_item, G.transformed(_outline(rect, 50), xform), back)
		var points: PackedVector2Array = _outline(rect, 0)
		if shadow.a > 0.0: G.polygon(to_canvas_item, G.offset(points, Vector2(4, 9)), shadow)
		G.polygon(to_canvas_item, points, fill)
		var texture: Texture2D = G.grain()
		if texture:
			var inner: Rect2 = rect.grow(- torn - 1.0)
			var tile: Vector2 = texture.get_size()
			var y: float = inner.position.y
			while y < inner.end.y:
				var x: float = inner.position.x
				var th: float = minf(tile.y, inner.end.y - y)
				while x < inner.end.x:
					var tw: float = minf(tile.x, inner.end.x - x)
					RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(x, y, tw, th), texture.get_rid(), Rect2(0, 0, tw, th), Color(1, 1, 1, 0.035))
					x += tile.x
				y += tile.y
		if ruled:
			var line_y: float = rect.position.y + 40.0
			while line_y < rect.end.y - 10.0:
				RenderingServer.canvas_item_add_line(to_canvas_item, Vector2(rect.position.x + 8, line_y), Vector2(rect.end.x - 8, line_y), Color(0.45, 0.6, 0.95, 0.045), 1.0)
				line_y += 30.0
		if margin_line:
			RenderingServer.canvas_item_add_line(to_canvas_item, Vector2(rect.position.x + 14, rect.position.y + 6), Vector2(rect.position.x + 14, rect.end.y - 6), Color(0.84, 0.27, 0.36, 0.35), 2.0)
		if edge_color.a > 0.0 and points.size() > 2:
			var closed: PackedVector2Array = points.duplicate()
			closed.append(points[0])
			RenderingServer.canvas_item_add_polyline(to_canvas_item, closed, PackedColorArray([edge_color]), 1.0, true)
		if tape:
			_tape(to_canvas_item, Vector2(rect.position.x + 34, rect.position.y + 2), -0.5, 74.0)
			_tape(to_canvas_item, Vector2(rect.end.x - 30, rect.position.y + 4), 0.42, 66.0)

	func _tape(item: RID, center: Vector2, angle: float, width: float) -> void :
		var half: Vector2 = Vector2(width * 0.5, 11)
		var points: PackedVector2Array = PackedVector2Array()
		points.append(Vector2(- half.x, - half.y))
		points.append(Vector2(half.x, - half.y))
		for i: int in range(5): points.append(Vector2(half.x + (G.noise(seed_value, i) - 0.5) * 5.0, - half.y + half.y * 2.0 * float(i + 1) / 6.0))
		points.append(Vector2(half.x, half.y))
		points.append(Vector2(- half.x, half.y))
		for i: int in range(5): points.append(Vector2(- half.x + (G.noise(seed_value, i + 9) - 0.5) * 5.0, half.y - half.y * 2.0 * float(i + 1) / 6.0))
		G.polygon(item, G.transformed(points, Transform2D(angle, center)), Color(0.96, 0.93, 0.84, 0.5))



# Règle d'écolier : piste des curseurs (HSlider) ; `marker` = remplissage
# au surligneur.
class Ruler extends StyleBox:
	var fill: Color = Color(1, 1, 1, 0.12)
	var tick: Color = Color(1, 1, 1, 0.22)
	var marker: bool = false

	func _init() -> void :
		content_margin_top = 4
		content_margin_bottom = 4

	func _draw(to_canvas_item: RID, rect: Rect2) -> void :
		var mid: float = rect.get_center().y
		if marker:
			if rect.size.x < 3.0: return
			var band_rect: Rect2 = Rect2(Vector2(rect.position.x - 2, mid - 6), Vector2(rect.size.x + 2, 12))
			G.polygon(to_canvas_item, G.strip(band_rect, 4.0, 1.5, 1.2, 31), fill)
			return
		RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(Vector2(rect.position.x, mid - 1.5), Vector2(rect.size.x, 3)), fill)
		var count: int = maxi(2, int(rect.size.x / 14.0))
		for i: int in range(count + 1):
			var x: float = rect.position.x + rect.size.x * float(i) / float(count)
			var tall: float = 7.0 if i % 5 == 0 else 3.5
			RenderingServer.canvas_item_add_line(to_canvas_item, Vector2(x, mid + 3), Vector2(x, mid + 3 + tall), tick, 1.0)
