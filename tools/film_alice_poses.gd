extends "res://anim_pose.gd"

# Poses d'essai du labo (tools/film_alice_lab.gd --fal-mode pose --fal-pose <nom>) : chaque
# essai pose un ou plusieurs corps côte à côte (x en mètres, repère du film), joue un clip
# jusqu'à l'instant t et photographie la rangée (ou chaque corps avec --fal-each).
# Un essai peut suivre un trajet ("path", repère du film, ajouté à x / z).

const FA = preload("res://anim_set_film_alice.gd")


static func sets() -> Dictionary:
	return {
		"axes": [
			{"person": "Alice", "x": -2.4, "t": 0.5, "keys": [[0.0, M([FA._zero(), HD(0.6)])]]},
			{"person": "Alice", "x": -0.8, "t": 0.5, "keys": [[0.0, M([FA._zero(), B(0.5)])]]},
			{"person": "Alice", "x": 0.8, "t": 0.5, "keys": [[0.0, M([FA._zero(), R(0.0, 0.0, 1.0), L(1.0, 0.0, 0.0)])]]},
			{"person": "Alice", "x": 2.4, "t": 0.5, "keys": [[0.0, M([FA._zero(), FL(0.0, 0.5, 0.0), FR(0.3, 0.0, 0.3)])]]},
		],
		"runs": _runs(),
		# sens des cibles de main : R(…, fwd = +1) devant, R(…, fwd = -1) derrière (vue de profil, --fal-each)
		"dirs": [
			{"person": "Simon", "z": -2.4, "t": 0.5, "keys": [[0.0, M([FA._zero(), B(0.55), C(0.28)])]]},
			{"person": "Simon", "z": -0.8, "t": 0.5, "keys": [[0.0, M([FA._zero(), B(0.55), R(0.24, 0.1, -0.95), L(0.24, 0.1, -0.95)])]]},
			{"person": "Simon", "z": 0.8, "t": 0.5, "keys": [[0.0, M([FA._zero(), B(0.55), HD(0.8)])]]},
			{"person": "Simon", "z": 2.4, "t": 0.5, "keys": [[0.0, M([FA._zero(), H(0, -0.08, 0.1), B(0.55)])]]},
		],
	}


static func _runs() -> Array:
	var out: Array = []
	var x: float = -5.0
	for person: String in ["Bleuette", "Elly", "Simon", "Ashura", "Lysia", "Usayuko"]:
		var path: Array = [[0.0, Vector3(0, 0, -3.4)], [1.6, Vector3(0, 0, 3.4)]]
		var k: Array = [[0.0, M([FA._zero(), H(0, -0.05, 0), B(0.28), C(0.12), HD(0.32)])]]
		var plants: Array = FA.cadence(0.0, 1.6, 0.29, 0.16, -1, 0.3, 3.0 + x)
		FA.gait(k, person, path, Vector3(0, 0, 1), plants, {"kick": 0.3, "pass": 0.26, "reach_h": 0.08, "strike": 0.18, "push": -0.75, "bob_low": 0.07, "bob_high": 0.03, "lean": 0.28, "heel": 0.3, "yaw": 0.16})
		FA.pump(k, plants, {"lean": 0.12, "twist": 0.22, "head": 0.34, "front": Vector3(0.04, -0.12, 0.72), "back": Vector3(0.12, -0.55, -0.5), "flare": 0.15})
		out.append({"person": person, "x": x, "t": 1.6, "path": path, "keys": k})
		x += 2.0
	return out
