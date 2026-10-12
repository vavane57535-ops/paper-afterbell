extends RefCounted



const T = preload("res://ui_theme.gd")
const Icons = preload("res://ui_icons.gd")
const Sound = preload("res://ui_sound.gd")
const Collage = preload("res://ui_collage.gd")
const Geom = preload("res://ui_paper_geom.gd")


class PaperStyle extends StyleBox:
	var fill: Color = T.CREAM
	var seed_value: int = 1
	var torn_top: bool = false
	var torn_bottom: bool = true
	var torn_sides: bool = false
	var jitter: float = 2.4
	var tape: bool = false
	var tape_angle: float = -0.05
	var ruled: bool = false
	var margin_line: bool = false
	var shadow: bool = true
	var grain_alpha: float = 0.09
	var border_color: Color = Color(0, 0, 0, 0)

	func _init(margin: float = 22.0) -> void :
		content_margin_left = margin
		content_margin_right = margin
		content_margin_top = margin * 0.9
		content_margin_bottom = margin * 0.9

	func _edge(points: PackedVector2Array, from: Vector2, to: Vector2, torn: bool, salt: int) -> void :
		var length: float = from.distance_to(to)
		var steps: int = maxi(1, int(length / 7.0))
		var normal: Vector2 = (to - from).normalized().orthogonal()
		for i: int in range(steps):
			var t: float = float(i) / float(steps)
			var offset: float = 0.0
			if torn: offset = (T.noise(seed_value + salt, i) - 0.5) * jitter * 2.0 + sin(t * 23.0 + float(seed_value)) * jitter * 0.35
			points.append(from.lerp(to, t) + normal * offset)

	func outline(rect: Rect2) -> PackedVector2Array:
		var points: PackedVector2Array = PackedVector2Array()
		var a: Vector2 = rect.position
		var b: Vector2 = Vector2(rect.end.x, rect.position.y)
		var c: Vector2 = rect.end
		var d: Vector2 = Vector2(rect.position.x, rect.end.y)
		_edge(points, a, b, torn_top, 11)
		_edge(points, b, c, torn_sides, 23)
		_edge(points, c, d, torn_bottom, 37)
		_edge(points, d, a, torn_sides, 41)
		return points

	func _draw(to_canvas_item: RID, rect: Rect2) -> void :
		var points: PackedVector2Array = outline(rect)
		if shadow:
			var soft: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in points: soft.append(point + Vector2(2, 8))
			RenderingServer.canvas_item_add_polygon(to_canvas_item, soft, PackedColorArray([Color(0, 0, 0, 0.28)]))
			var near: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in points: near.append(point + Vector2(1, 3))
			RenderingServer.canvas_item_add_polygon(to_canvas_item, near, PackedColorArray([Color(0, 0, 0, 0.22)]))
		RenderingServer.canvas_item_add_polygon(to_canvas_item, points, PackedColorArray([fill]))
		var texture: Texture2D = T.grain()
		if texture and grain_alpha > 0:

			var inner: Rect2 = rect.grow( - jitter)
			var tile: Vector2 = texture.get_size()
			var y: float = inner.position.y
			while y < inner.end.y:
				var x: float = inner.position.x
				var h: float = minf(tile.y, inner.end.y - y)
				while x < inner.end.x:
					var w: float = minf(tile.x, inner.end.x - x)
					RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(x, y, w, h), texture.get_rid(), Rect2(0, 0, w, h), Color(1, 1, 1, grain_alpha))
					x += tile.x
				y += tile.y
		if ruled:
			var line_y: float = rect.position.y + 34.0
			while line_y < rect.end.y - 8.0:
				RenderingServer.canvas_item_add_line(to_canvas_item, Vector2(rect.position.x + 6, line_y), Vector2(rect.end.x - 6, line_y), Color(0.2, 0.32, 0.45, 0.1), 1.0)
				line_y += 26.0
		if margin_line:
			RenderingServer.canvas_item_add_line(to_canvas_item, Vector2(rect.position.x + 30, rect.position.y + 4), Vector2(rect.position.x + 30, rect.end.y - 4), Color(0.75, 0.18, 0.25, 0.28), 1.5)
		if border_color.a > 0:
			var closed: PackedVector2Array = points.duplicate()
			closed.append(points[0])
			RenderingServer.canvas_item_add_polyline(to_canvas_item, closed, PackedColorArray([border_color]), 2.0, true)
		if tape: T.draw_tape(to_canvas_item, Vector2(rect.get_center().x + (T.noise(seed_value, 3) - 0.5) * rect.size.x * 0.3, rect.position.y + 1), clampf(rect.size.x * 0.28, 60, 120), tape_angle, Color(0.96, 0.93, 0.84, 0.62), seed_value)







class Hover extends RefCounted:
	var inside: bool = false
	var _refresh: Callable

	func attach(control: Control, refresh: Callable) -> void :
		_refresh = refresh
		control.mouse_entered.connect(_on_enter)
		control.mouse_exited.connect(_on_exit)
		control.focus_entered.connect(_on_focus)
		control.focus_exited.connect(_on_focus)

	func _on_enter() -> void :

		inside = not T.touch_mode
		_refresh.call()

	func _on_exit() -> void :
		inside = false
		_refresh.call()

	func _on_focus() -> void :
		_refresh.call()



	func lit(control: Control) -> bool:
		return (inside and T.pointer_mode) or key_focus(control)

	func key_focus(control: Control) -> bool:
		return control.has_focus() and not T.pointer_mode



	func still_over(control: Control) -> bool:
		if not inside: return false
		if not control.is_visible_in_tree() or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			inside = false
			return false
		var viewport: Viewport = control.get_viewport()
		if viewport == null: return true
		var hovered: Control = viewport.gui_get_hovered_control()
		if hovered == control or (hovered != null and control.is_ancestor_of(hovered)): return true

		if Input.get_mouse_button_mask() != 0: return true
		inside = false
		return false



class NavItem extends Button:
	signal hinted(text: String)
	var accent: Color = T.PAPER
	var hint: String = ""
	var primary: bool = false
	var font_size_px: int = 30
	var reduced_motion: bool = false
	# Collage façon Persona : inclinaison de l'entrée (degrés), décalage en
	# éventail (px) et couleur de la découpe derrière l'entrée sélectionnée.
	var tilt_deg: float = 0.0
	var arc_x: float = 0.0
	var cut_color: Color = T.RED
	var collage: bool = true
	# Reste allumée même sans survol ni focus (menu pause : il y a toujours
	# une commande choisie, comme dans Persona).
	var held: bool = false
	var _hover: float = 0.0
	var _target: float = 0.0
	var _velocity: float = 0.0
	var _shake: float = 0.0
	var _track: Hover = Hover.new()

	func _init() -> void :
		flat = true
		focus_mode = Control.FOCUS_ALL
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]: add_theme_stylebox_override(state, T.empty_style(24, 4))
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]: add_theme_color_override(key, Color(0, 0, 0, 0))
		_track.attach(self, refresh_highlight)
		set_process(false)

	func configure(size_px: int, color: Color, is_primary: bool = false) -> void :
		font_size_px = size_px
		accent = color
		primary = is_primary
		add_theme_font_override("font", T.font("nav"))
		add_theme_font_size_override("font_size", size_px)
		custom_minimum_size.y = roundf(size_px * 1.55)


	func refresh_highlight() -> void :
		var want: float = 1.0 if (_track.lit(self) or held) and not disabled else 0.0
		if want == _target:
			queue_redraw()
			return
		if want > _target:
			Sound.play("hover")
			hinted.emit(hint)
			_shake = 1.0
		else:

			hinted.emit("")
		_target = want
		_animate()

	func _notification(what: int) -> void :
		if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree(): _snap_off()

	func _snap_off() -> void :
		_track.inside = false
		_target = 0.0
		_hover = 0.0
		_velocity = 0.0
		_shake = 0.0
		queue_redraw()

	func _animate() -> void :
		if reduced_motion:
			_hover = _target
			queue_redraw()
			set_process(_track.inside)
			return
		set_process(true)

	func _process(delta: float) -> void :

		if _track.inside and not _track.still_over(self): refresh_highlight()
		if reduced_motion:
			_hover = _target
			_shake = 0.0
		else:
			# Ressort : l'entrée sélectionnée grossit avec un léger dépassement.
			var step: float = minf(delta, 1.0 / 30.0)
			_velocity += ((_target - _hover) * 380.0 - _velocity * 21.0) * step
			_hover += _velocity * step
			_shake = maxf(0.0, _shake - delta / 0.18)
		queue_redraw()
		var settled: bool = absf(_hover - _target) < 0.002 and absf(_velocity) < 0.01 and _shake <= 0.0
		if settled:
			_hover = _target
			_velocity = 0.0
		# Allumée : on continue de redessiner pour le trait qui frémit.
		if settled and not _track.inside and (_target <= 0.0 or reduced_motion): set_process(false)

	func set_held(on: bool) -> void :
		if held == on: return
		held = on
		refresh_highlight()

	func is_lit_now() -> bool:
		return _track.lit(self)

	func _draw() -> void :
		if collage:
			_draw_collage()
			return
		var font: Font = get_theme_font("font")
		var font_size: int = get_theme_font_size("font_size")
		var t: float = ease(_hover, 0.6)
		var mid: float = size.y * 0.5
		var baseline: float = mid + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		var x: float = 24.0 + 12.0 * t
		var color: Color = accent if primary else T.PAPER_DIM.lerp(Color("fffaf0"), t)
		if disabled: color = Color(T.PAPER, 0.3)
		draw_line(Vector2(0, mid), Vector2(6.0 + 12.0 * t, mid), Color(accent, 0.35 + 0.65 * t), 3.0)
		draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if t > 0.01:

			var points: PackedVector2Array = PackedVector2Array()
			var steps: int = 14
			for i: int in range(steps + 1):
				var u: float = float(i) / float(steps) * t
				points.append(Vector2(x - 2.0 + (width + 6.0) * u, baseline + 7.0 + sin(u * 11.0 + float(font_size)) * 1.3 + u * 1.5))
			draw_polyline(points, Color(accent, 0.9), 2.2, true)
		if primary:
			var ax: float = x + width + 18.0 + 8.0 * t
			var ay: float = mid + 1.0
			draw_line(Vector2(ax, ay), Vector2(ax + 26.0, ay), color, 3.0, true)
			draw_polyline(PackedVector2Array([Vector2(ax + 17.0, ay - 8.0), Vector2(ax + 26.0, ay), Vector2(ax + 17.0, ay + 8.0)]), color, 3.0, true)
		if _track.key_focus(self):
			var r: Rect2 = Rect2(Vector2(-6, 2), Vector2(minf(size.x, x + width + (58.0 if primary else 18.0)) + 6.0, size.y - 4))
			for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
				var dx: float = 10.0 if corner.x <= r.position.x else -10.0
				var dy: float = 8.0 if corner.y <= r.position.y else -8.0
				draw_line(corner, corner + Vector2(dx, 0), T.GOLD, 2.0)
				draw_line(corner, corner + Vector2(0, dy), T.GOLD, 2.0)

	# Mot en lettres découpées, incliné ; sélectionné : il grossit (ressort),
	# tremble, une découpe colorée se déplie derrière et le trait frémit.
	func _draw_collage() -> void :
		var shown: String = text.to_upper()
		var lit: float = clampf(_hover, 0.0, 1.25)
		var on: float = clampf(lit, 0.0, 1.0)
		var px: float = float(font_size_px) * 1.08
		var baseline: float = size.y * 0.5 + px * 0.36
		var shake: Vector2 = Vector2.ZERO
		if _shake > 0.0 and not reduced_motion:
			shake = Vector2(Geom.noise(Geom.boil_frame, 1) - 0.5, Geom.noise(Geom.boil_frame, 2) - 0.5) * 7.0 * _shake
		var grow: float = 1.0 + (0.18 if primary else 0.3) * lit
		var angle: float = deg_to_rad(tilt_deg) * (1.0 - 0.35 * on) + deg_to_rad(-2.5) * on
		var base: Transform2D = Transform2D(angle, Vector2(grow, grow), 0.0, Vector2(30.0 + arc_x + 16.0 * on, baseline) + shake)
		var alpha: float = 0.3 if disabled else 1.0
		var seed_value: int = absi(shown.hash()) % 9973
		var boil: int = Geom.boil_frame if lit > 0.5 and not reduced_motion else 0
		var ink: Color = T.CREAM if primary else T.PAPER_DIM.lerp(T.CREAM, 0.4)
		if on > 0.05:
			# Éclat de papier pointé sur l'entrée sélectionnée (curseur).
			var reach: float = px * (0.62 + 0.08 * sin(float(boil) * 1.7))
			var dart: PackedVector2Array = PackedVector2Array([Vector2(- reach - px * 0.5, - px * 0.62), Vector2(- px * 0.42, - px * 0.36), Vector2(- reach - px * 0.38, - px * 0.08)])
			var shape: PackedVector2Array = Geom.transformed(dart, base)
			Geom.polygon(get_canvas_item(), Geom.offset(shape, Vector2(4, 5)), Color(T.INK, 0.8 * on))
			Geom.polygon(get_canvas_item(), shape, Color(T.CREAM if cut_color.get_luminance() < 0.55 else T.RED, on))
		Collage.draw_word(self, shown, base, px, seed_value, lit, cut_color, alpha, boil, false, ink, accent.lerp(T.RED, 0.5))
		if primary:
			var width: float = Collage.width(shown, px, seed_value)
			Collage.draw_arrow(self, base, Vector2(width + px * 0.4 + 10.0 * on, - px * 0.32), px, accent if lit < 0.5 else T.CREAM, alpha)
		draw_set_transform(Vector2.ZERO)




class Stamp extends Control:
	var text: String = ""
	var caption: String = ""
	var color: Color = T.RED_INK
	var font_size_px: int = 20
	var angle_deg: float = -9.0
	var round: bool = false

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = T.ink_material()

	func configure(value: String, size_px: int = 20, ink: Color = T.RED_INK, round_stamp: bool = false, angle: float = -9.0) -> void :
		text = value
		font_size_px = size_px
		color = ink
		round = round_stamp
		angle_deg = angle
		queue_redraw()

	func slam(reduced: bool) -> void :
		pivot_offset = size * 0.5
		if reduced:
			scale = Vector2.ONE
			modulate.a = 1.0
			return
		scale = Vector2(1.7, 1.7)
		modulate.a = 0.0
		var tween: Tween = create_tween().set_parallel()
		tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 1.0, 0.12)



	func slam_after(delay: float) -> void :
		modulate.a = 0.0
		get_tree().create_timer(delay).timeout.connect(_slam_now)

	func _slam_now() -> void :
		slam(false)
		Sound.play("click")

	func _draw() -> void :
		var center: Vector2 = size * 0.5
		draw_set_transform(center, deg_to_rad(angle_deg), Vector2.ONE)
		var ink: Color = Color(color, 0.88)
		if round:
			var radius: float = minf(size.x, size.y) * 0.46
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, ink, 3.0, true)
			draw_arc(Vector2.ZERO, radius - 6.0, 0, TAU, 48, ink, 1.5, true)
			var big: Font = T.font("display")
			var glyph: Vector2 = big.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_px)
			draw_string(big, Vector2( - glyph.x * 0.5, (big.get_ascent(font_size_px) - big.get_descent(font_size_px)) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_px, ink)
		else:
			var font: Font = T.font("title")
			var shown: String = T.tr_text(text)
			var measure: Vector2 = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_px)
			var box: Rect2 = Rect2(Vector2( - measure.x * 0.5 - 12.0, - font_size_px * 0.78), Vector2(measure.x + 24.0, font_size_px * 1.56))
			draw_rect(box, ink, false, 3.0)
			draw_rect(box.grow(-4.0), ink, false, 1.2)
			draw_string(font, Vector2( - measure.x * 0.5, (font.get_ascent(font_size_px) - font.get_descent(font_size_px)) * 0.5), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_px, ink)
		draw_set_transform(Vector2.ZERO)



class KeyCap extends Control:
	var label: String = "E"
	var lit: bool = false
	var accent: Color = T.TEAL
	var font_size_px: int = 14
	var min_width: float = 0.0

	func _init(value: String = "E", size_px: int = 14) -> void :
		label = value
		font_size_px = size_px
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_label(value: String) -> void :
		if value == label: return
		label = value
		update_minimum_size()
		queue_redraw()

	func set_lit(value: bool) -> void :
		if value == lit: return
		lit = value
		queue_redraw()

	func _get_minimum_size() -> Vector2:
		var font: Font = T.font("semibold")
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_px).x
		var height: float = roundf(font_size_px * 1.75)
		return Vector2(maxf(maxf(height, min_width), width + font_size_px * 1.1), height)

	func _draw() -> void :
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var radius: float = minf(6.0, size.y * 0.22)
		var base: Color = accent if lit else Color("2a3142")
		var face: Color = accent.lerp(Color.WHITE, 0.15) if lit else Color("3a4357")
		draw_style_box(_rounded(Color(base.darkened(0.35), 0.95), radius), r)
		draw_style_box(_rounded(face, radius), Rect2(r.position, r.size - Vector2(0, maxf(2.0, size.y * 0.1))))
		var font: Font = T.font("semibold")
		var text_color: Color = Color("10141c") if lit else T.PAPER
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_px).x
		var top: float = (size.y - maxf(2.0, size.y * 0.1)) * 0.5
		draw_string(font, Vector2((size.x - width) * 0.5, top + (font.get_ascent(font_size_px) - font.get_descent(font_size_px)) * 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_px, text_color)

	func _rounded(color: Color, radius: float) -> StyleBoxFlat:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(int(radius))
		style.anti_aliasing = true
		return style



class Meter extends Control:
	var value: float = 1.0
	var ghost: float = 1.0
	var color: Color = T.GREEN
	var back: Color = Color("262c3a")
	var ghost_color: Color = Color(1.0, 0.86, 0.8, 0.55)
	var ticks: int = 0
	var segments: int = 0
	var radius: float = 3.0

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func set_value(ratio: float, instant: bool = false) -> void :
		ratio = clampf(ratio, 0.0, 1.0)
		if absf(ratio - value) < 0.0005: return
		if ratio < value and not instant: ghost = maxf(ghost, value)
		else: ghost = ratio
		value = ratio
		set_process(ghost > value + 0.0005)
		queue_redraw()

	func set_color(next: Color) -> void :
		if next == color: return
		color = next
		queue_redraw()

	func _process(delta: float) -> void :
		ghost = move_toward(ghost, value, delta * 0.55)
		queue_redraw()
		if ghost <= value + 0.0005: set_process(false)

	func _draw() -> void :
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		if segments > 0:
			var gap: float = 2.0
			var width: float = (size.x - gap * float(segments - 1)) / float(segments)
			var filled: int = int(round(value * float(segments)))
			for i: int in range(segments):
				var cell: Rect2 = Rect2(Vector2(float(i) * (width + gap), 0), Vector2(width, size.y))
				draw_rect(cell, color if i < filled else back)
			return
		_bar(r, back)
		if ghost > value: _bar(Rect2(r.position, Vector2(r.size.x * ghost, r.size.y)), ghost_color)
		if value > 0: _bar(Rect2(r.position, Vector2(maxf(r.size.x * value, radius * 2.0), r.size.y)), color)
		if ticks > 1:
			for i: int in range(1, ticks):
				var x: float = r.size.x * float(i) / float(ticks)
				draw_line(Vector2(x, 1), Vector2(x, r.size.y - 1), Color(0, 0, 0, 0.35), 1.0)

	func _bar(r: Rect2, fill: Color) -> void :
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = fill
		style.set_corner_radius_all(int(minf(radius, r.size.y * 0.5)))
		draw_style_box(style, r)



class AbilitySlot extends Control:
	var world: Node
	var index: int = 0
	var icon_tex: Texture2D
	var key_text: String = ""
	var accent: Color = T.TEAL
	var title: String = ""
	var state_text: String = ""
	var state_color: Color = T.PAPER_DIM
	var cooldown: float = 0.0
	var cooldown_peak: float = 1.0
	var blocked: bool = false
	var locked: bool = false
	var highlight: bool = false
	var charge: float = -1.0
	var charge_label: String = ""
	var square: float = 66.0
	var reduced_motion: bool = false
	var _flash: float = 0.0
	var _pulse: float = 0.0
	var _drawn_key: String = ""

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		set_process(false)

	func _get_minimum_size() -> Vector2:
		return Vector2(square + 8.0, square + 34.0)

	func _gui_input(event: InputEvent) -> void :
		if world == null or not (event is InputEventMouseButton): return
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT: return
		if button.pressed: world.request_ability(index)
		else: world.release_ability(index)
		accept_event()


	func apply(next_icon: Texture2D, next_key: String, next_title: String, next_state: String, next_state_color: Color, cd: float, peak: float, is_blocked: bool, is_locked: bool, is_highlight: bool, next_charge: float, next_charge_label: String) -> void :
		var redraw: bool = next_icon != icon_tex or next_key != key_text or next_title != title or next_state != state_text or next_state_color != state_color
		icon_tex = next_icon
		key_text = next_key
		title = next_title
		state_text = next_state
		state_color = next_state_color
		var was_cooling: bool = cooldown > 0.0

		if absf(cd - cooldown) >= 0.05 or (cd <= 0.0) != (cooldown <= 0.0) or not is_equal_approx(peak, cooldown_peak):
			cooldown = cd
			cooldown_peak = maxf(0.1, peak)
			redraw = true
		if was_cooling and cooldown <= 0.0 and not reduced_motion:
			_flash = 1.0
			set_process(true)
		if is_blocked != blocked or is_locked != locked:
			blocked = is_blocked
			locked = is_locked
			redraw = true
		if is_highlight != highlight:
			highlight = is_highlight
			redraw = true
			if highlight and not reduced_motion: set_process(true)
		if absf(next_charge - charge) > 0.004 or next_charge_label != charge_label:
			charge = next_charge
			charge_label = next_charge_label
			redraw = true
		if redraw: queue_redraw()

	func _process(delta: float) -> void :
		_flash = maxf(0.0, _flash - delta * 2.2)
		_pulse += delta
		queue_redraw()
		if _flash <= 0.0 and not highlight: set_process(false)

	func _draw() -> void :
		var origin: Vector2 = Vector2((size.x - square) * 0.5, 0)
		var r: Rect2 = Rect2(origin, Vector2(square, square))
		var active: bool = not blocked and not locked and cooldown <= 0.0
		var edge: Color = accent if active else Color("363d50")
		if highlight: edge = T.GOLD
		var base: StyleBoxFlat = StyleBoxFlat.new()
		base.bg_color = Color("141925") if active else Color("10131b")
		base.border_color = Color(edge, 0.95 if active or highlight else 0.8)
		base.set_border_width_all(2 if active or highlight else 1)
		base.set_corner_radius_all(9)
		base.anti_aliasing = true
		base.shadow_color = Color(0, 0, 0, 0.45)
		base.shadow_size = 6
		draw_style_box(base, r)
		if active:
			var glow: StyleBoxFlat = StyleBoxFlat.new()
			glow.bg_color = Color(0, 0, 0, 0)
			glow.draw_center = false
			glow.border_color = Color(accent, 0.18)
			glow.set_border_width_all(4)
			glow.set_corner_radius_all(12)
			glow.set_expand_margin_all(3)
			draw_style_box(glow, r)
		if icon_tex:
			var tint: Color = Color("f4efe4") if active else Color(0.55, 0.57, 0.63, 0.75)
			if highlight: tint = T.GOLD
			draw_texture_rect(icon_tex, Rect2(r.position + r.size * 0.2, r.size * 0.6), false, tint)
		if cooldown > 0.0:
			_draw_sweep(r, clampf(cooldown / cooldown_peak, 0.0, 1.0))
			var digits: Font = T.font("digits")
			var shown: String = "%d" % int(ceil(cooldown)) if cooldown >= 10.0 else "%.1f" % cooldown
			var fs: int = int(square * 0.4)
			var measure: Vector2 = digits.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string_outline(digits, Vector2(r.get_center().x - measure.x * 0.5, r.get_center().y + fs * 0.36), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
			draw_string(digits, Vector2(r.get_center().x - measure.x * 0.5, r.get_center().y + fs * 0.36), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff6e6"))
		if locked:
			draw_rect(r.grow(-2), Color(0.03, 0.03, 0.05, 0.55))
			var lock: Texture2D = Icons.icon("lock")
			if lock: draw_texture_rect(lock, Rect2(r.get_center() - Vector2(13, 15), Vector2(26, 26)), false, Color(T.RED, 0.95))
		if charge >= 0.0: _draw_charge(r, charge)
		if highlight and not reduced_motion:
			var pulse: float = 0.5 + 0.5 * sin(_pulse * 7.0)
			var ring: StyleBoxFlat = StyleBoxFlat.new()
			ring.draw_center = false
			ring.border_color = Color(T.GOLD, 0.35 + 0.45 * pulse)
			ring.set_border_width_all(2)
			ring.set_corner_radius_all(12)
			ring.set_expand_margin_all(3.0 + 2.0 * pulse)
			draw_style_box(ring, r)
		if _flash > 0.0:
			var burst: StyleBoxFlat = StyleBoxFlat.new()
			burst.draw_center = false
			burst.border_color = Color(accent, _flash * 0.9)
			burst.set_border_width_all(2)
			burst.set_corner_radius_all(12)
			burst.set_expand_margin_all(2.0 + (1.0 - _flash) * 9.0)
			draw_style_box(burst, r)
		if not key_text.is_empty():
			var font: Font = T.font("semibold")
			var fs: int = 13
			var width: float = maxf(20.0, font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0)
			var cap: Rect2 = Rect2(r.position + Vector2(-5, -7), Vector2(width, 20))
			var cap_style: StyleBoxFlat = StyleBoxFlat.new()
			cap_style.bg_color = Color("e9e2d2") if active else Color("5b6173")
			cap_style.set_corner_radius_all(4)
			cap_style.border_color = Color(0, 0, 0, 0.5)
			cap_style.border_width_bottom = 2
			draw_style_box(cap_style, cap)
			draw_string(font, Vector2(cap.position.x + (cap.size.x - font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) * 0.5, cap.position.y + 14.5), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("12151d"))
		var caps: Font = T.font("caps")
		var y: float = r.end.y + 15.0
		_centered(caps, title, y, 11, Color(T.PAPER, 0.82 if active else 0.55))
		if not state_text.is_empty(): _centered(caps, state_text, y + 15.0, 11, state_color)

	func _centered(font: Font, value: String, y: float, fs: int, color: Color) -> void :
		var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var limit: float = size.x + 26.0
		if width > limit:
			draw_string(font, Vector2(-13.0, y), value, HORIZONTAL_ALIGNMENT_CENTER, limit, fs, color, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL)
			return
		draw_string(font, Vector2((size.x - width) * 0.5, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	func _draw_sweep(r: Rect2, remaining: float) -> void :

		var center: Vector2 = r.get_center()
		var radius: float = r.size.x
		var start: float = - PI * 0.5 + TAU * (1.0 - remaining)
		var end: float = - PI * 0.5 + TAU
		var pie: PackedVector2Array = PackedVector2Array([center])
		var steps: int = maxi(2, int(ceil(40.0 * remaining)))
		for i: int in range(steps + 1):
			var angle: float = lerpf(start, end, float(i) / float(steps))
			pie.append(center + Vector2(cos(angle), sin(angle)) * radius)
		var inner: Rect2 = r.grow(-2.0)
		var clip: PackedVector2Array = PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(pie, clip):
			if piece.size() >= 3: draw_colored_polygon(piece, Color(0.02, 0.025, 0.04, 0.72))
		var hand: float = start
		draw_line(center, center + Vector2(cos(hand), sin(hand)) * (r.size.x * 0.46), Color(accent, 0.55), 1.5, true)

	func _draw_charge(r: Rect2, progress: float) -> void :

		var inner: Rect2 = r.grow(3.0)
		var perimeter: PackedVector2Array = PackedVector2Array([Vector2(inner.get_center().x, inner.position.y), Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y), inner.position, Vector2(inner.get_center().x, inner.position.y)])
		var total: float = inner.size.x * 2.0 + inner.size.y * 2.0
		var left: float = total * clampf(progress, 0.0, 1.0)
		var points: PackedVector2Array = PackedVector2Array([perimeter[0]])
		for i: int in range(1, perimeter.size()):
			var segment: float = perimeter[i - 1].distance_to(perimeter[i])
			if left <= segment:
				points.append(perimeter[i - 1].lerp(perimeter[i], left / maxf(0.001, segment)))
				break
			points.append(perimeter[i])
			left -= segment
		if points.size() >= 2: draw_polyline(points, T.GOLD, 3.0, true)
		if not charge_label.is_empty():
			var font: Font = T.font("digits")
			var width: float = font.get_string_size(charge_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var tag: Rect2 = Rect2(Vector2(r.end.x - width - 6.0, r.position.y - 9.0), Vector2(width + 10.0, 18.0))
			draw_rect(tag, T.GOLD)
			draw_string(font, Vector2(tag.position.x + 5.0, tag.position.y + 15.0), charge_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("171108"))



class CharacterCard extends Button:
	var person: String = ""
	var portrait: Texture2D
	var role_title: String = ""
	var hp_text: String = ""
	var accent: Color = T.TEAL
	var selected: bool = false
	var taken_by: String = ""
	var tilt: float = 0.0
	var reduced_motion: bool = false


	var art: Texture2D
	var art_accent: Color = T.TEAL
	var _hover: float = 0.0
	var _target: float = 0.0
	var _velocity: float = 0.0
	var _shake: float = 0.0
	var _paper: PaperStyle
	var _stamp: Stamp
	var _track: Hover = Hover.new()

	func _init() -> void :
		focus_mode = Control.FOCUS_ALL
		flat = true
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]: add_theme_stylebox_override(state, T.empty_style())
		_track.attach(self, refresh_highlight)
		resized.connect(_on_resized)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		set_process(false)

	func setup(name_value: String, tex: Texture2D, role: String, hp: String, color: Color, seed_value: int, angle: float) -> void :
		person = name_value
		portrait = tex
		role_title = role
		hp_text = hp
		accent = color
		tilt = angle
		tooltip_text = ""
		_paper = PaperStyle.new(8)
		_paper.seed_value = seed_value
		_paper.torn_bottom = true
		_paper.jitter = 1.8
		_paper.grain_alpha = 0.08
		_stamp = Stamp.new()
		add_child(_stamp)
		_stamp.configure("SÉLECTIONNÉ", 15, T.RED_INK, false, -7.0)
		_stamp.visible = false
		_on_resized()

	func set_selected(value: bool, taken: String = "") -> void :
		var changed: bool = value != selected
		selected = value
		taken_by = taken
		if _stamp:
			_stamp.visible = selected or not taken_by.is_empty()
			_stamp.configure("SÉLECTIONNÉ" if selected else "DÉJÀ PRIS", 15, T.RED_INK, false, -7.0)
			if changed and selected: _stamp.slam(reduced_motion)
		queue_redraw()


	func refresh_highlight() -> void :
		var want: float = 1.0 if _track.lit(self) else 0.0
		if want == _target:
			queue_redraw()
			return
		if want > _target:
			Sound.play("hover")
			_shake = 1.0
		_target = want
		if reduced_motion:
			_hover = _target
			queue_redraw()
			set_process(_track.inside)
		else: set_process(true)

	func _notification(what: int) -> void :
		if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
			_track.inside = false
			_target = 0.0
			_hover = 0.0
			queue_redraw()

	func _enter_tree() -> void :
		# Le conteneur remet rotation et échelle à zéro quand il se réorganise.
		var parent: Container = get_parent() as Container
		if parent and not parent.sort_children.is_connected(_on_resized): parent.sort_children.connect(_on_resized)

	func _process(delta: float) -> void :
		if _track.inside and not _track.still_over(self): refresh_highlight()
		if reduced_motion:
			_hover = _target
			_shake = 0.0
		else:
			var step: float = minf(delta, 1.0 / 30.0)
			_velocity += ((_target - _hover) * 420.0 - _velocity * 22.0) * step
			_hover += _velocity * step
			_shake = maxf(0.0, _shake - delta / 0.16)
		_apply_pose()
		queue_redraw()
		if absf(_hover - _target) < 0.002 and absf(_velocity) < 0.01 and _shake <= 0.0:
			_hover = _target
			_velocity = 0.0
			_apply_pose()
			if not _track.inside: set_process(false)

	func _apply_pose() -> void :
		var lit: float = maxf(_hover, 0.0)
		var pop: float = 1.0 + 0.06 * lit
		scale = Vector2(pop, pop)
		rotation = deg_to_rad(tilt * (1.0 - 0.6 * clampf(lit, 0.0, 1.0)) - 1.5 * clampf(lit, 0.0, 1.0)) + sin(float(Time.get_ticks_msec()) * 0.09) * 0.02 * _shake

	func _on_resized() -> void :
		pivot_offset = size * 0.5
		_apply_pose()
		if _stamp:
			_stamp.size = Vector2(size.x * 0.92, 36)
			_stamp.position = Vector2(size.x * 0.04, size.y * 0.63 - 24.0)

	func _draw() -> void :
		var lift: float = -7.0 * maxf(ease(clampf(_hover, 0.0, 1.0), 0.5), 1.0 if selected else 0.0)
		var r: Rect2 = Rect2(Vector2(0, lift), size)
		var lit: float = maxf(clampf(_hover, 0.0, 1.0), 1.0 if selected else 0.0)
		if _track.key_focus(self): lit = 1.0
		if lit > 0.01:
			# Découpe de couleur derrière la carte (couleur du personnage).
			var back: Rect2 = r.grow_individual(10, 8, 12, 14)
			var cut: PackedVector2Array = Geom.cut(back, person.length() * 11 + (Geom.boil_frame if _target > 0.5 and not reduced_motion else 0), 0.1)
			Geom.polygon(get_canvas_item(), Geom.offset(cut, Vector2(7, 9) * lit), Color(T.INK, 0.8 * lit))
			Geom.polygon(get_canvas_item(), cut, Color(art_accent if art else accent, lit))
		if _paper: _paper.draw(get_canvas_item(), r)
		var photo: Rect2 = Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, r.size.y * 0.63))
		var faded: Color = Color(1, 1, 1, 0.45) if not taken_by.is_empty() else Color.WHITE
		if art:

			var h: float = ease(_hover, 0.5)
			draw_rect(photo, art_accent.darkened(0.62 - 0.12 * h))
			var line_y: float = photo.position.y + 9.0
			while line_y < photo.end.y:
				draw_line(Vector2(photo.position.x, line_y), Vector2(photo.end.x, line_y), Color(art_accent, 0.13), 1.0)
				line_y += 11.0

			var tex_size: Vector2 = art.get_size()
			var src_w: float = tex_size.x * (1.0 - 0.08 * h)
			var src_h: float = minf(tex_size.y, src_w * photo.size.y / photo.size.x)
			var src: Rect2 = Rect2(Vector2((tex_size.x - src_w) * 0.5, tex_size.y * 0.02), Vector2(src_w, src_h))
			draw_texture_rect_region(art, photo, src, faded)
		elif portrait:
			draw_rect(photo, Color("1d1a24"))
			draw_texture_rect(portrait, photo, false, faded)
		else:
			draw_rect(photo, Color("1d1a24"))
		draw_rect(photo, Color(0.1, 0.09, 0.12, 0.9), false, 1.0)
		draw_rect(Rect2(photo.position.x, photo.end.y - 4.0, photo.size.x, 4.0), art_accent if art else accent)
		T.draw_tape(get_canvas_item(), Vector2(r.get_center().x + (T.noise(person.length(), 2) - 0.5) * 18.0, r.position.y + 3.0), 58.0, -0.08 + T.noise(person.length(), 5) * 0.16, Color(0.95, 0.92, 0.82, 0.55), person.length())
		var title: Font = T.font("title")
		var caps: Font = T.font("caps")
		var y: float = photo.end.y + 26.0
		draw_string(title, Vector2(r.position.x + 12.0, y), person.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 20, T.INK_TEXT)
		draw_string(caps, Vector2(r.position.x + 12.0, y + 19.0), T.tr_text(role_title), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 11, accent.darkened(0.45))
		var num: Font = T.font("num")
		var hp_shown: String = T.tr_text(hp_text)
		var hp_width: float = num.get_string_size(hp_shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(num, Vector2(r.end.x - 12.0 - hp_width, y), hp_shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, T.INK_MUTED)
		if not taken_by.is_empty():
			draw_string(caps, Vector2(r.position.x + 12.0, y + 36.0), taken_by.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24.0, 10, T.RED_INK)
		if _stamp and _stamp.visible:

			var band: Vector2 = Vector2(r.get_center().x, r.position.y + size.y * 0.63 - 6.0)
			T.draw_tape(get_canvas_item(), band, r.size.x * 0.86, deg_to_rad(-7.0), Color(0.97, 0.94, 0.86, 0.9), person.length() + 7)



class MapCard extends Button:
	var map_id: String = ""
	var thumb: Texture2D
	var title: String = ""
	var line: String = ""
	var selected: bool = false
	var _hover: bool = false

	func _init() -> void :
		focus_mode = Control.FOCUS_ALL
		flat = true
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]: add_theme_stylebox_override(state, T.empty_style())
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _set_hover(value: bool) -> void :
		if value and T.touch_mode: return
		if value and not _hover: Sound.play("hover")
		_hover = value
		queue_redraw()

	func _notification(what: int) -> void :
		if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree(): _hover = false

	func setup(id: String, tex: Texture2D, name_value: String, description: String, is_selected: bool) -> void :
		map_id = id
		title = name_value
		line = description
		selected = is_selected
		if tex:

			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = tex
			var full: Vector2 = tex.get_size()
			atlas.region = Rect2(full * Vector2(0.22, 0.2), full * Vector2(0.56, 0.6))
			thumb = atlas
		queue_redraw()

	func _draw() -> void :
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var item: RID = get_canvas_item()
		var lit: bool = _hover or (has_focus() and not T.pointer_mode)
		var seed_value: int = map_id.length() * 13 + 5
		if selected or lit:
			# Découpe colorée derrière la carte choisie / survolée.
			var cut: PackedVector2Array = Geom.cut(r.grow_individual(8, 6, 10, 10), seed_value + (Geom.boil_frame if lit else 0), 0.08)
			Geom.polygon(item, Geom.offset(cut, Vector2(6, 7)), Color(T.INK, 0.8))
			Geom.polygon(item, cut, T.TEAL if selected else Color(T.CREAM, 0.85))
		var shape: PackedVector2Array = Geom.strip(r, 6.0, 1.6, 1.4, seed_value)
		Geom.polygon(item, Geom.offset(shape, Vector2(3, 5)), Color(0, 0, 0, 0.45))
		Geom.polygon(item, shape, Color("171c29") if lit else Color("121621"))
		var edge: PackedVector2Array = shape.duplicate()
		if edge.size() > 2:
			edge.append(shape[0])
			draw_polyline(edge, Color(1, 1, 1, 0.08), 1.0, true)
		var image: Rect2 = Rect2(Vector2(6, 6), Vector2(size.x - 12, size.y * (0.5 if size.x <= 240 else 0.55)))
		if thumb: draw_texture_rect(thumb, image, false, Color.WHITE if selected or _hover else Color(0.75, 0.78, 0.85))
		draw_rect(image, Color(0, 0, 0, 0.35), false, 1.0)
		var title_font: Font = T.font("title")
		var body: Font = T.font("body")
		var title_size: int = 16 if size.x > 240 else 14
		var shown_title: String = T.tr_text(title)
		var lines: int = 1 if title_font.get_string_size(shown_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x <= size.x - 24 else 2
		draw_multiline_string(title_font, Vector2(12, image.end.y + 22), shown_title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, title_size, 2, T.PAPER if selected else T.PAPER_DIM)


		var body_lines: int = 3 if size.x > 240 else (2 if lines == 1 else 0)
		if size.y < 130: body_lines = 0
		if body_lines > 0: draw_multiline_string(body, Vector2(12, image.end.y + 26 + title_size * 1.25 * lines), T.tr_text(line), HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 12 if size.x <= 240 else 14, body_lines, Color(T.PAPER, 0.55))
		if selected:
			var badge: Vector2 = Vector2(size.x - 20, 20)
			draw_circle(badge, 12, T.TEAL)
			draw_polyline(PackedVector2Array([badge + Vector2(-5, 0), badge + Vector2(-1, 4), badge + Vector2(6, -4)]), Color("0f1419"), 2.5, true)
			T.draw_tape(item, Vector2(r.get_center().x, 2), 64.0, -0.06, Color(0.95, 0.92, 0.82, 0.6), seed_value)



class RoleTab extends Button:
	var accent: Color = T.TEAL
	var icon_tex: Texture2D
	var subtitle: String = ""
	var _hover: bool = false

	func _init() -> void :
		toggle_mode = true
		focus_mode = Control.FOCUS_ALL
		flat = true
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]: add_theme_stylebox_override(state, T.empty_style())
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]: add_theme_color_override(key, Color(0, 0, 0, 0))
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		toggled.connect(_on_toggled)

	func _set_hover(value: bool) -> void :
		if value and T.touch_mode: return
		if value and not _hover: Sound.play("hover")
		_hover = value
		queue_redraw()

	func _notification(what: int) -> void :
		if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree(): _hover = false

	func _on_toggled(_on: bool) -> void :
		queue_redraw()

	func _draw() -> void :
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var on: bool = button_pressed
		var item: RID = get_canvas_item()
		var lit: bool = _hover or (has_focus() and not T.pointer_mode)
		var seed_value: int = text.length() * 17 + 3
		if on:
			# Onglet choisi : papier de la couleur du rôle, découpe crème derrière.
			var cut: PackedVector2Array = Geom.cut(r.grow_individual(6, 5, 8, 7), seed_value + (Geom.boil_frame if lit else 0), 0.1)
			Geom.polygon(item, Geom.offset(cut, Vector2(5, 6)), Color(T.INK, 0.85))
			Geom.polygon(item, cut, T.CREAM if lit else Color(T.CREAM, 0.9))
		var shape: PackedVector2Array = Geom.strip(r, 10.0, 1.6, 1.2, seed_value)
		if not on: Geom.polygon(item, Geom.offset(shape, Vector2(3, 4)), Color(0, 0, 0, 0.4))
		Geom.polygon(item, shape, accent.darkened(0.45) if on else (Color("1d2232") if lit else Color("151925")))
		if lit and not on:
			var marker: PackedVector2Array = Geom.strip(Rect2(Vector2(10, size.y - 9), Vector2(size.x - 24, 5)), 4.0, 1.0, 0.6, seed_value + 3)
			Geom.polygon(item, marker, Color(accent, 0.8))
		var x: float = 18.0
		if icon_tex:
			draw_texture_rect(icon_tex, Rect2(Vector2(16, (size.y - 34) * 0.5), Vector2(34, 34)), false, accent if on else Color(T.PAPER, 0.45))
			x = 62.0
		var title_font: Font = T.font("title")
		var caps: Font = T.font("caps")
		var shown: String = text
		draw_string(title_font, Vector2(x, size.y * 0.5 + (4.0 if subtitle.is_empty() else -1.0)), shown, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 10, 22, T.PAPER if on else T.PAPER_DIM)
		if not subtitle.is_empty(): draw_string(caps, Vector2(x, size.y * 0.5 + 19.0), T.tr_text(subtitle), HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 10, 11, Color(accent, 0.9) if on else Color(T.PAPER, 0.4))



class DragRotate extends Control:
	var world: Node
	var _dragging: bool = false

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_DRAG

	func _gui_input(event: InputEvent) -> void :
		if world == null: return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			accept_event()
		elif event is InputEventMouseMotion and _dragging:
			world.preview_angle = wrapf(float(world.preview_angle) + event.relative.x * 0.011, - PI, PI)
			accept_event()
		elif event is InputEventScreenDrag:
			world.preview_angle = wrapf(float(world.preview_angle) + event.relative.x * 0.011, - PI, PI)
			accept_event()



class Spinner extends Control:
	var color: Color = T.TEAL
	var _angle: float = 0.0

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(34, 34)

	func _process(delta: float) -> void :
		_angle = wrapf(_angle + delta * 4.2, 0.0, TAU)
		queue_redraw()

	func _draw() -> void :
		# Trois bouts de papier découpé qui tournent l'un derrière l'autre.
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.34
		var item: RID = get_canvas_item()
		for i: int in range(3):
			var angle: float = _angle * (1.0 + 0.25 * float(i)) + float(i) * TAU / 3.0
			var at: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
			var chip: PackedVector2Array = Geom.transformed(Geom.cut(Rect2(Vector2(-6, -5), Vector2(12, 10)), i * 13 + 5, 0.15), Transform2D(angle * 1.5, at))
			Geom.polygon(item, Geom.offset(chip, Vector2(2, 3)), Color(0, 0, 0, 0.5))
			Geom.polygon(item, chip, [T.CREAM, T.RED, color][i])



class Rule extends Control:
	var color: Color = T.LINE_SOFT
	var accent: Color = T.TEAL

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 12

	func _draw() -> void :
		var y: float = size.y * 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(T.PAPER, 0.1), 1.0)
		draw_line(Vector2(0, y), Vector2(26, y), Color(accent, 0.8), 2.0)



# Titre en lettres découpées (titres de page, verdict des résultats). Le texte
# source est en français ; la traduction est appliquée au dessin.
class CollageTitle extends Control:
	var text: String = ""
	var px: float = 44.0
	var accent: Color = T.RED
	var max_width: float = 560.0
	var tilt: float = -0.03
	var _shown: String = ""
	var _lines: PackedStringArray = PackedStringArray()

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(value: String, size_px: float, color: Color = T.RED, width: float = 560.0) -> void :
		text = value
		px = size_px
		accent = color
		max_width = width
		_relayout()

	func _relayout() -> void :
		_shown = T.tr_text(text).to_upper()
		_lines = PackedStringArray()
		var line: String = ""
		for word: String in _shown.split(" ", false):
			var attempt: String = word if line.is_empty() else line + " " + word
			if not line.is_empty() and Collage.width(attempt, px, absi(attempt.hash()) % 997) > max_width:
				_lines.append(line)
				line = word
			else: line = attempt
		if not line.is_empty(): _lines.append(line)
		update_minimum_size()
		queue_redraw()

	func _get_minimum_size() -> Vector2:
		var widest: float = 0.0
		for line: String in _lines: widest = maxf(widest, Collage.width(line, px, absi(line.hash()) % 997))
		return Vector2(minf(widest + px * 0.3, max_width + px * 0.3), float(maxi(1, _lines.size())) * px * 1.12 + px * 0.28)

	func _draw() -> void :
		if T.tr_text(text).to_upper() != _shown:
			_relayout.call_deferred()
			return
		for i: int in range(_lines.size()):
			var line: String = _lines[i]
			var base: Transform2D = Transform2D(tilt, Vector2.ONE, 0.0, Vector2(px * 0.12 + float(i) * px * 0.35, px * 0.98 + float(i) * px * 1.1))
			Collage.draw_word(self, line, base, px, absi(line.hash()) % 997, 0.0, accent, 1.0, 0, false, T.CREAM, accent)



# Ligne de menu (réglage, danse, option du salon…) : quand son contrôle est
# sélectionné (souris, clavier, manette), une bande de papier rouge découpée
# se déplie derrière elle (ui_menu_fx.gd appelle set_row_lit).
class MenuRow extends PanelContainer:
	var accent: Color = T.RED_DEEP
	var reduced_motion: bool = false
	var separator: bool = true
	var _lit: float = 0.0
	var _goal: float = 0.0
	var _seed: int = 0

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_PASS
		add_theme_stylebox_override("panel", T.empty_style(16, 3))
		_seed = randi() % 997
		set_process(false)

	func set_row_lit(on: bool, reduced: bool) -> void :
		_goal = 1.0 if on else 0.0
		reduced_motion = reduced
		_tint_labels(on)
		if reduced:
			_lit = _goal
			queue_redraw()
			return
		set_process(true)

	# Sur la bande rouge, les textes de la ligne passent en crème (comme le
	# texte inversé des lignes choisies de Persona), puis reprennent leur
	# couleur.
	func _tint_labels(on: bool) -> void :
		for node: Node in find_children("*", "Label", true, false):
			var label: Label = node as Label
			if on:
				if label.has_meta("row_tint"): continue
				label.set_meta("row_tint", [label.has_theme_color_override("font_color"), label.get_theme_color("font_color")])
				var title: bool = label.get_theme_font_size("font_size") >= 17
				label.add_theme_color_override("font_color", T.CREAM if title else Color(T.CREAM, 0.82))
			elif label.has_meta("row_tint"):
				var saved: Array = label.get_meta("row_tint")
				label.remove_meta("row_tint")
				if bool(saved[0]): label.add_theme_color_override("font_color", saved[1])
				else: label.remove_theme_color_override("font_color")

	func _notification(what: int) -> void :
		if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
			_lit = 0.0
			_goal = 0.0
			_tint_labels(false)

	func _process(delta: float) -> void :
		_lit = move_toward(_lit, _goal, delta / (0.13 if _goal > 0.0 else 0.09))
		queue_redraw()
		if is_equal_approx(_lit, _goal): set_process(false)

	func _draw() -> void :
		if separator: draw_line(Vector2(8, size.y - 1), Vector2(size.x - 8, size.y - 1), Color(1, 1, 1, 0.05), 1.0)
		if _lit <= 0.01: return
		var p: float = _lit
		var back: float = 1.0 + 2.2 * pow(p - 1.0, 3.0) + 1.2 * pow(p - 1.0, 2.0)
		var band: Rect2 = Rect2(Vector2(-10, 3), Vector2((size.x + 4.0) * back, size.y - 6))
		var item: RID = get_canvas_item()
		var shape: PackedVector2Array = Geom.strip(band, 12.0, 2.5, 1.6, _seed + Geom.boil_frame * (0 if reduced_motion else 1))
		Geom.polygon(item, Geom.offset(shape, Vector2(5, 5)), Color(T.INK, 0.6 * p))
		Geom.polygon(item, shape, Color(accent, 0.92 * minf(1.0, p * 1.5)))
		Geom.polygon(item, Geom.strip(Rect2(band.position + Vector2(14, band.size.y - 5), Vector2(band.size.x * 0.7, 3)), 4.0, 1.0, 0.5, _seed + 3), Color(T.CREAM, 0.75 * p))
		Geom.polygon(item, PackedVector2Array([band.position + Vector2(10, 4), band.position + Vector2(18, 4), Vector2(band.position.x + 12, band.end.y - 4), Vector2(band.position.x + 4, band.end.y - 4)]), Color(T.CREAM, p))
