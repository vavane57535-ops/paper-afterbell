extends "res://anim_pose.gd"

# Poses du blocus (fin « Alice a quitté la partie »).
# Volontairement raides : clés tenues ("h") et boucles calées sur 100 BPM (0,6 s par temps),
# le tempo de la musique audio/cinematic/blocus.ogg.
# Ces clips sont enregistrés à la volée par PaperFilmBlocus (pas dans AnimLibrary.SETS) ;
# le préfixe « dance_ » les fait jouer comme des émotes en boucle.

const BEAT: float = 0.6

static func add(c: Dictionary) -> void :
	_chant(c)
	_sign(c)
	_megaphone(c)
	_clap(c)
	_stomp(c)
	_mope(c)


static func _base() -> Dictionary:
	return M([rest(), {"curl": 0.3, "curl_l": 0.3, "jaw": 0.0, "shake": 0.0}])


static func _hip_l() -> Dictionary:
	return M([Lt(0.12, -0.66, 0.1, 0.6), WL(0.0), {"curl_l": 0.9}])


# Poing levé, poing à l'épaule, en boucle. Toujours les mêmes deux images.
static func _chant(c: Dictionary) -> void :
	var up: Dictionary = M([_base(), H(0.0, 0.05, 0.0), B(-0.04), C(-0.08), HD(0.2, 0.0, 0.0), R(0.2, 1.0, 0.08), WR(0.0), _hip_l(), {"curl": 1.1, "jaw": 0.9, "sq": 1.03}])
	var down: Dictionary = M([_base(), H(0.0, -0.06, 0.0), B(0.06), C(0.04), HD(0.02, 0.0, 0.0), R(0.32, 0.22, 0.18), WR(0.0), _hip_l(), {"curl": 1.1, "jaw": 0.15, "sq": 0.97}])
	c["dance_blocus_chant"] = {"len": BEAT * 2.0, "loop": true, "in": 0.08, "face": "determined", "keys": [
		[0.0, up, "h"], [BEAT, down, "h"], [BEAT * 2.0, up, "h"]]}


# Pancarte tenue à deux mains au-dessus de la tête, qui monte et descend d'un cran.
static func _sign(c: Dictionary) -> void :
	var high: Dictionary = M([_base(), H(0.0, 0.03, 0.0), B(-0.06), C(-0.06), HD(0.12), LR(0.24, 0.98, 0.0, 0.15), WL(0.0), WR(0.0), {"curl": 1.0, "curl_l": 1.0, "jaw": 0.7, "sq": 1.02}])
	var low: Dictionary = M([_base(), H(0.0, -0.05, 0.0), B(0.02), C(0.0), HD(0.05), LR(0.26, 0.8, 0.02, 0.2), WL(0.0), WR(0.0), {"curl": 1.0, "curl_l": 1.0, "jaw": 0.1, "sq": 0.98}])
	c["dance_blocus_sign"] = {"len": BEAT * 2.0, "loop": true, "in": 0.1, "face": "grin", "keys": [
		[0.0, high, "h"], [BEAT, low, "h"], [BEAT * 2.0, high, "h"]]}


# Mégaphone collé à la bouche (main droite), bras gauche qui martèle les syllabes.
static func _megaphone(c: Dictionary) -> void :
	var hold: Dictionary = M([R(-0.26, 0.14, 0.72, 0.45), WR(0.0), {"curl": 1.0}])
	var shout: Dictionary = M([_base(), hold, H(0.0, 0.03, 0.0), B(-0.1), C(-0.12), HD(0.16, 0.0, 0.0), L(0.55, 0.85, 0.15, 0.2), WL(0.0), {"curl_l": 1.1, "jaw": 1.0, "sq": 1.03}])
	var beat: Dictionary = M([_base(), hold, H(0.0, -0.05, 0.0), B(0.08), C(0.06), HD(0.0, 0.0, 0.0), L(0.6, 0.15, 0.3, 0.2), WL(0.0), {"curl_l": 1.1, "jaw": 0.35, "sq": 0.97}])
	c["dance_blocus_megaphone"] = {"len": BEAT * 2.0, "loop": true, "in": 0.12, "face": "angry", "keys": [
		[0.0, shout, "h"], [BEAT * 0.5, M([shout, HD(0.2, 0.08, 0.05)]), "h"], [BEAT, beat, "h"], [BEAT * 1.5, M([beat, HD(0.04, -0.08, -0.05)]), "h"], [BEAT * 2.0, shout, "h"]]}


# « On est là ! » : clap au-dessus de la tête sur chaque temps, raide comme un métronome.
static func _clap(c: Dictionary) -> void :
	var open: Dictionary = M([_base(), H(0.0, -0.04, 0.0), HD(0.1), LR(0.42, 0.75, 0.1, 0.2), WL(0.0, 1.2), WR(0.0, -1.2), {"curl": 0.0, "curl_l": 0.0, "jaw": 0.2}])
	var shut: Dictionary = M([_base(), H(0.0, 0.04, 0.0), HD(0.18), LR(0.06, 0.95, 0.12, 0.1), WL(0.0, 1.4), WR(0.0, -1.4), {"curl": 0.0, "curl_l": 0.0, "jaw": 0.9, "fx": "pop_r"}])
	c["dance_blocus_clap"] = {"len": BEAT * 2.0, "loop": true, "in": 0.08, "face": "grin", "keys": [
		[0.0, shut, "h"], [BEAT * 0.5, open, "h"], [BEAT, shut, "h"], [BEAT * 1.5, open, "h"], [BEAT * 2.0, shut, "h"]]}


# Marche sur place de soldat de plomb : genou, bras raide, genou, bras raide.
static func _stomp(c: Dictionary) -> void :
	var left: Dictionary = M([_base(), H(0.0, 0.04, 0.0), FL(0.08, 0.12, 0.28), FR(0.08, 0.0), B(-0.04), HD(0.12), R(0.14, -0.4, 0.55), L(0.14, -0.92, -0.25), WL(0.0), WR(0.0), {"fp_l": 0.3, "curl": 1.0, "curl_l": 1.0, "jaw": 0.8}])
	var right: Dictionary = M([_base(), H(0.0, 0.04, 0.0), FR(0.08, 0.12, 0.28), FL(0.08, 0.0), B(-0.04), HD(0.12), L(0.14, -0.4, 0.55), R(0.14, -0.92, -0.25), WL(0.0), WR(0.0), {"fp_r": 0.3, "curl": 1.0, "curl_l": 1.0, "jaw": 0.2}])
	var stand: Dictionary = M([_base(), H(0.0, -0.03, 0.0), FLR(0.08, 0.0), HD(0.06), LR(0.14, -0.95, 0.05), {"curl": 1.0, "curl_l": 1.0}])
	c["dance_blocus_stomp"] = {"len": BEAT * 2.0, "loop": true, "in": 0.1, "face": "determined", "keys": [
		[0.0, left, "h"], [BEAT * 0.5, stand, "h"], [BEAT, right, "h"], [BEAT * 1.5, stand, "h"], [BEAT * 2.0, left, "h"]]}


# Bras croisés, pied qui tape : celui ou celle qui « surveille la barricade ».
static func _mope(c: Dictionary) -> void :
	var crossed: Dictionary = M([_base(), H(0.0, -0.02, 0.0), FLR(0.1, 0.0), B(-0.04), C(-0.06), HD(0.08, 0.0, 0.06), Lt(-0.22, -0.18, 0.36, 0.3), Rt(-0.22, -0.12, 0.34, 0.3), WL(0.0), WR(0.0), {"curl": 0.9, "curl_l": 0.9}])
	c["dance_blocus_mope"] = {"len": BEAT * 2.0, "loop": true, "in": 0.15, "face": "calm", "keys": [
		[0.0, M([crossed, FR(0.1, 0.05, 0.08)]), "h"], [BEAT * 0.5, M([crossed, FR(0.1, 0.0, 0.0)]), "h"], [BEAT, M([crossed, FR(0.1, 0.05, 0.08), HD(0.08, 0.1, 0.06)]), "h"], [BEAT * 1.5, M([crossed, FR(0.1, 0.0, 0.0)]), "h"], [BEAT * 2.0, M([crossed, FR(0.1, 0.05, 0.08)]), "h"]]}
