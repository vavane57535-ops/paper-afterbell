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
	}


static func _runs() -> Array:
	var out: Array = []
	var x: float = -5.0
	for person: String in ["Bleuette", "Elly", "Simon", "Ashura", "Lysia", "Usayuko"]:
		var path: Array = [[0.0, Vector3(0, 0, -3.0)], [1.6, Vector3(0, 0, 3.0)]]
		var k: Array = [[0.0, M([FA._zero(), H(0, -0.05, 0), B(0.15), C(0.1), HD(0.2)])]]
		var plants: Array = FA.cadence(0.02, 1.6, 0.3, 0.17, -1, 0.29, 3.0 + x)
		FA.gait(k, person, path, Vector3(0, 0, 1), plants, {"kick": 0.2, "pass": 0.2, "reach_h": 0.07, "strike": 0.15, "push": -0.7, "bob_low": 0.07, "bob_high": 0.02, "lean": 0.15, "heel": 0.3})
		FA.pump(k, plants, {"lean": 0.1, "twist": 0.18, "head": 0.22})
		out.append({"person": person, "x": x, "t": 1.6, "path": path, "keys": k})
		x += 2.0
	return out
