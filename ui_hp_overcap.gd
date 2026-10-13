extends Control

# Surcouche de la barre de PV du HUD pendant le LMS : repère du plafond de 150 PV et partie dorée
# au-delà, que seul le courage de Bleuette (Je peux le faire) permet de remplir. Pour un élève entré
# en LMS au-dessus de 150 (Usayuko, Lysia), la partie au-delà de 150 déjà perdue est barrée : elle ne se regagne pas.

const T = preload("res://ui_theme.gd")

var cap_ratio: float = 1.0
var fill_ratio: float = 0.0
var courage: bool = false
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
	var next_courage: bool = actor.character == "Bleuette"
	if absf(next_cap - cap_ratio) > 0.0005 or absf(next_fill - fill_ratio) > 0.0005 or next_courage != courage:
		cap_ratio = next_cap
		fill_ratio = next_fill
		courage = next_courage
		queue_redraw()
	return courage and float(actor.hp) > cap + 0.01


func _process(delta: float) -> void :
	_pulse = fmod(_pulse + delta, 1.6)
	if courage and fill_ratio > cap_ratio: queue_redraw()


func _draw() -> void :
	var x: float = size.x * cap_ratio
	if not courage:
		# Surplus perdu au-delà de 150 : hachures sombres, ces PV ne reviendront pas pendant le LMS.
		var from: float = maxf(x, size.x * fill_ratio)
		if size.x - from > 1.0:
			draw_rect(Rect2(Vector2(from, 0), Vector2(size.x - from, size.y)), Color(0.02, 0.03, 0.05, 0.55))
			var tall: float = size.y
			var hatch: float = from - tall
			while hatch < size.x:
				var x0: float = maxf(hatch, from)
				var x1: float = minf(hatch + tall, size.x)
				if x1 > x0: draw_line(Vector2(x0, tall - (x0 - hatch)), Vector2(x1, tall - (x1 - hatch)), Color(T.PAPER, 0.22), 1.0)
				hatch += 6.0
		draw_line(Vector2(x, -3.0), Vector2(x, size.y + 3.0), Color(T.PAPER, 0.92), 2.0)
		return
	var reserved: Rect2 = Rect2(Vector2(x, 0), Vector2(maxf(0.0, size.x - x), size.y))
	draw_rect(reserved, Color(T.GOLD_DIM, 0.28))
	if fill_ratio > cap_ratio:
		var glow: float = 0.82 + 0.18 * sin(_pulse / 1.6 * TAU)
		var gold: Rect2 = Rect2(Vector2(x, 0), Vector2(size.x * fill_ratio - x, size.y))
		draw_rect(gold, Color(T.GOLD, glow))
		draw_rect(Rect2(gold.position, Vector2(gold.size.x, maxf(1.0, size.y * 0.3))), Color(1.0, 0.96, 0.82, 0.55 * glow))
	draw_line(Vector2(x, -3.0), Vector2(x, size.y + 3.0), Color(T.PAPER, 0.92), 2.0)
