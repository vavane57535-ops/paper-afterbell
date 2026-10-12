class_name PaperEmotes
extends RefCounted

# Catalogue des émotes de la roue (gratuites) et règles de synchronisation partagées
# par l'hôte, les clients et l'interface. Les danses sont dans PaperDances.

const LIST: Array[Dictionary] = [
	{"id": "wave", "name": "Salut", "secs": 2.5},
	{"id": "thumbsup", "name": "Bien joué", "secs": 2.5},
	{"id": "cheer", "name": "Célébrer", "secs": 2.5},
	{"id": "laugh", "name": "Rire", "secs": 2.5},
	{"id": "point", "name": "Par ici", "secs": 2.5},
	{"id": "shrug", "name": "Hausser les épaules", "secs": 2.5},
	{"id": "sad", "name": "Déception", "secs": 2.5},
	{"id": "fear", "name": "Effroi", "secs": 2.5},
	{"id": "clap", "name": "Applaudir", "secs": 3.0},
	{"id": "facepalm", "name": "Facepalm", "secs": 2.9},
	{"id": "sulk", "name": "Bouder", "secs": 3.3},
	{"id": "heart", "name": "Cœur avec les mains", "secs": 2.9},
	{"id": "taunt", "name": "Nananère", "secs": 2.7},
	{"id": "salute", "name": "Salut militaire", "secs": 2.6},
	{"id": "selfie", "name": "Selfie", "secs": 3.3},
	{"id": "bow", "name": "Révérence", "secs": 2.9},
	{"id": "beg", "name": "Faire le beau", "secs": 3.1},
	{"id": "sit", "name": "En tailleur", "secs": 0.0},
]

# Émotes dont la pose est tenue (boucle) jusqu'à ce que le joueur bouge.
const HOLD_SECONDS: float = 90.0

# Portée de synchronisation : deux survivants à moins de cette distance qui font la même
# émote se calent sur le même temps. Les danses gardent la portée de la 0.15 (musique audible).
const SYNC_RANGE: float = 14.0
const DANCE_SYNC_RANGE: float = 30.0

# Une émote ponctuelle rejointe tôt : le nouveau venu prend le temps du groupe.
# Rejointe tard (au-delà de cette fraction) : tout le groupe repart ensemble de zéro.
const JOIN_FRACTION: float = 0.45

static var _ids: Array[String] = []

static func ids() -> Array[String]:
	if _ids.is_empty():
		for entry: Dictionary in LIST: _ids.append(str(entry.id))
	return _ids

static func info(id: String) -> Dictionary:
	for entry: Dictionary in LIST:
		if entry.id == id: return entry
	return {}

static func is_emote(id: String) -> bool:
	return not info(id).is_empty()

static func valid(id: String) -> bool:
	return is_emote(id) or not PaperDances.info(id).is_empty()

static func title(id: String) -> String:
	if PaperDances.is_dance(id): return PaperDances.title(id)
	return str(info(id).get("name", id))

static func holds(id: String) -> bool:
	return is_emote(id) and float(info(id).get("secs", 2.5)) <= 0.0

# Durée au bout de laquelle l'émote s'arrête d'elle-même (temps partagé du groupe).
static func duration(id: String) -> float:
	if PaperDances.is_dance(id): return PaperDances.MAX_SECONDS
	if holds(id): return HOLD_SECONDS
	return float(info(id).get("secs", 2.5))

static func sync_range(id: String) -> float:
	return DANCE_SYNC_RANGE if PaperDances.is_dance(id) else SYNC_RANGE

# Pose tenue (en tailleur) : on ne rejoint le groupe que pendant l'entrée, sinon le nouveau
# venu sauterait sa propre mise en place ; au-delà il s'installe à son rythme.
const HOLD_JOIN_SECONDS: float = 0.4

# Jusqu'à quel temps partagé un nouveau venu rejoint le groupe en cours de route.
static func join_window(id: String) -> float:
	if PaperDances.is_dance(id): return INF
	if holds(id): return HOLD_JOIN_SECONDS
	return duration(id) * JOIN_FRACTION
