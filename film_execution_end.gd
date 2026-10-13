class_name PaperFilmExecutionEnd
extends RefCounted

# Fin de manche par l'EXÉCUTION du dernier survivant (0.16).
# Le plan d'exécution vient de montrer la mise à mort : le film « Alice · X rattrapé(e) » remontrait
# la victime entière, puis la tuait une seconde fois. À la place, un épilogue sans victime :
# Alice rentre dans sa chambre (le décor de l'ancien film intro_alice, « DO NOT OPEN »), se retourne
# sur le seuil pour savourer sa victoire, puis disparaît dans le noir et la porte claque.
# Écran noir d'abord (le temps de quitter le plan d'exécution), puis fondu d'ouverture.
# Même film chez l'hôte et chez les clients : le type de fin passe par l'événement « ending »
# (main._finish, PaperKillScenes.last_executed).

const KIND: String = "ending_execution"
const DURATION: float = 6.7


static func write(film: PaperCinema) -> void :
	var a: int = film.alice_index
	# noir tenu 0,45 s après le plan d'exécution, puis fondu jusqu'à 1 s
	film._open_fade = Vector2(0.45, 1.0)
	film._door.append([5.25, 5.95, 1.0, 0.0])

	# Retour vers la porte ouverte, de dos.
	film._put(a, Vector3(0.2, 0, 3.3))
	film._face(a, 0.0, "dir", Vector3(0, 0, -1))
	film._do(a, 0.0, "mood", "menace")
	film._move(a, 0.5, 2.3, Vector3(0.0, 0, 0.7), "smooth")
	# De dos, dans l'axe : sa silhouette s'encadre dans la porte noire et la lueur rouge de la chambre.
	film._shot(0.0, {"eye": [Vector3(0.38, 1.22, 6.3), Vector3(0.3, 1.28, 5.35)], "look": [Vector3(0.05, 1.45, 0.0), Vector3(0.0, 1.38, 0.0)], "fov": [40, 37], "hand": 0.35, "safe": false})

	# Sur le seuil : elle se retourne lentement vers nous et savoure.
	film._cue(2.3, "sound", "presence", Vector3(0, 1.2, 0.7), 0.8, 0.85)
	film._face(a, 2.35, "dir", Vector3(0.35, 0, -1))
	film._face(a, 2.48, "dir", Vector3(0.95, 0, -0.3))
	film._face(a, 2.62, "dir", Vector3(0.7, 0, 0.7))
	film._face(a, 2.76, "dir", Vector3(-0.15, 0, 1))
	film._do(a, 2.55, "trigger", "gloat", false)
	# sourire en relevant la tête (clip gloat, 1,3 s) : pulsation rouge
	film._cue(3.85, "event", "reveal", {"position": {"a": a}})
	film._cue(3.85, "pulse", Color(0.7, 0.05, 0.2, 0.34), 1.3)
	film._cue(3.85, "sound", "shadow", Vector3(0, 1.4, 0.7), 0.75, 0.8)
	# Plan taille de trois-quarts en contre-plongée, la porte noire derrière elle : assez bas pour voir
	# son visage sous le chapeau quand elle se penche, assez large pour garder tout le rire (gloat).
	film._shot(2.45, {"eye": [Vector3(1.3, 0.72, 2.85), Vector3(1.0, 0.84, 2.4)], "look": [Vector3(0.0, 1.3, 0.7), Vector3(0.0, 1.26, 0.7)], "fov": [38, 34], "hand": 0.3, "roll": [0, -3], "safe": false})

	# Elle rentre dans le noir ; la porte se referme et claque.
	film._face(a, 4.9, "dir", Vector3(0, 0, -1))
	film._move(a, 5.0, 5.8, Vector3(0.0, 0, -1.8), "in")
	film._cue(5.25, "sound", "door_creak", Vector3(0, 1.5, 0), 0.9, 0.9)
	film._cue(5.95, "sound", "door_open", Vector3(0, 1.5, 0), 1.0, 0.68)
	film._cue(5.95, "sound", "ground_impact", Vector3(0, 0.6, 0.2), 0.55, 0.75)
	film._cue(5.95, "shake", 0.35)
	film._shot(4.95, {"eye": [Vector3(0.25, 1.3, 5.2), Vector3(0.18, 1.32, 4.75)], "look": Vector3(0, 1.55, 0), "fov": [42, 40], "hand": 0.5, "safe": false})
