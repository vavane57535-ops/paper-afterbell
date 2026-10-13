extends "res://anim_menu_take.gd"

# JOUER : Simon s'échauffe dans le couloir, la nuit ; il se croit seul.

static func add(c: Dictionary) -> void :
	_calibration(c)

# Clip de calibrage (temporaire) : une commande par tranche de 2 s.
static func _calibration(c: Dictionary) -> void :
	var k: Take = Take.new(22.0, "neutral")
	k.key(0.0, stand(), "s")
	k.key(1.5, stand(), "s")
	k.key(2.0, B(0.4), "s")
	k.key(3.5, B(0.4), "s")
	k.key(4.0, B(0.0, 0.6), "s")
	k.key(5.5, B(0.0, 0.6), "s")
	k.key(6.0, B(0.0, 0.0, 0.3), "s")
	k.key(7.5, B(0.0, 0.0, 0.3), "s")
	k.key(8.0, M([B(0.0), H(0.2, 0.0, 0.0)]), "s")
	k.key(9.5, H(0.2, 0.0, 0.0), "s")
	k.key(10.0, H(0.0, -0.3, 0.0), "s")
	k.key(11.5, H(0.0, -0.3, 0.0), "s")
	k.key(12.0, M([H(0, 0, 0), L(0.6, 0.3, 0.6, 0.0)]), "s")
	k.key(13.5, L(0.6, 0.3, 0.6, 0.0), "s")
	k.key(14.0, M([L(0.2, -0.93, 0.04, 0.0), HD(0.4)]), "s")
	k.key(15.5, HD(0.4), "s")
	k.key(16.0, M([HD(0.0), FL(0.1, 0.4, 0.15)]), "s")
	k.key(17.5, FL(0.1, 0.4, 0.15), "s")
	k.key(18.0, M([FL(0.02, 0.0), C(0.0, 0.5)]), "s")
	k.key(19.5, C(0.0, 0.5), "s")
	k.key(20.0, M([C(0.02), {"turn": 0.8}]), "s")
	k.key(22.0, {"turn": 0.8}, "s")
	c["menu_calib@Simon"] = k.clip()
