class_name PaperCanvas
extends Control



const T = preload("res://ui_theme.gd")

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void :
	draw_rect(Rect2(Vector2.ZERO, size), T.CREAM)
	var grain: Texture2D = T.grain()
	if grain: draw_texture_rect(grain, Rect2(Vector2.ZERO, size), true, Color(1, 1, 1, 0.08))
	for y: int in range(34, int(size.y), 26): draw_line(Vector2(6, y), Vector2(size.x - 6, y), Color(0.2, 0.32, 0.45, 0.1), 1)
	draw_line(Vector2(30, 0), Vector2(30, size.y), Color(0.75, 0.18, 0.25, 0.28), 1.5)
