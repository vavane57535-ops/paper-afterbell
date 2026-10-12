extends Control

# Surcouche de la barre de PV du HUD pendant le LMS : repère du plafond de 150 PV et partie dorée
# au-delà, que seul le courage de Bleuette (Je peux le faire) permet de remplir.

const T = preload("res://ui_theme.gd")

var cap_ratio: float = 1.0
var fill_ratio: float = 0.0
var _pulse: float = 0.0


func _init() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	set_process(false)


# Renvoie vrai quand les PV dépassent le plafond de LMS (texte des PV à colorer en or).
func update_from(actor: PaperActor, life: String) -> bool:
	var cap: float = 0.0 if actor == null else float(actor.effects.get("lms_hp_cap", 0.0))
	var shown: bool = actor != null and life in ["alive", "second_life"] and cap > 0.0 and float(actor.max_hp) > cap + 0.5
	if shown != visible:
		visible = shown
		set_process(shown)
	if not shown: return false
	var next_cap: float = clampf(cap / float(actor.max_hp), 0.0, 1.0)
	var next_fill: float = clampf(float(actor.hp) / float(actor.max_hp), 0.0, 1.0)
	if absf(next_cap - cap_ratio) > 0.0005 or absf(next_fill - fill_ratio) > 0.0005:
		cap_ratio = next_cap
		fill_ratio = next_fill
		queue_redraw()
	return float(actor.hp) > cap + 0.01


func _process(delta: float) -> void :
	_pulse = fmod(_pulse + delta, 1.6)
	if fill_ratio > cap_ratio: queue_redraw()


func _draw() -> void :
	var x: float = size.x * cap_ratio
	var reserved: Rect2 = Rect2(Vector2(x, 0), Vector2(maxf(0.0, size.x - x), size.y))
	draw_rect(reserved, Color(T.GOLD_DIM, 0.28))
	if fill_ratio > cap_ratio:
		var glow: float = 0.82 + 0.18 * sin(_pulse / 1.6 * TAU)
		var gold: Rect2 = Rect2(Vector2(x, 0), Vector2(size.x * fill_ratio - x, size.y))
		draw_rect(gold, Color(T.GOLD, glow))
		draw_rect(Rect2(gold.position, Vector2(gold.size.x, maxf(1.0, size.y * 0.3))), Color(1.0, 0.96, 0.82, 0.55 * glow))
	draw_line(Vector2(x, -3.0), Vector2(x, size.y + 3.0), Color(T.PAPER, 0.92), 2.0)
