class_name PaperDances
extends RefCounted





const LIST: Array[Dictionary] = [
	{"id": "dance_floss", "name": "Le Floss", "tag": "Réseaux sociaux", "price": 150, "bpm": 120.0, "music": "res://audio/dances/floss.ogg", "desc": "Les bras balancent devant et derrière, les hanches en sens inverse."}, 
	{"id": "dance_dab", "name": "Le Dab", "tag": "Classique", "price": 120, "bpm": 100.0, "music": "res://audio/dances/dab.ogg", "desc": "Rebond, tête dans le coude, bras tendu. Des deux côtés."}, 
	{"id": "dance_robot", "name": "Le Robot", "tag": "Rétro", "price": 180, "bpm": 110.0, "music": "res://audio/dances/robot.ogg", "desc": "Des poses saccadées, coudes à angle droit, sur un électro 8 bits."}, 
	{"id": "dance_shuffle", "name": "Running Man", "tag": "House", "price": 200, "bpm": 128.0, "music": "res://audio/dances/shuffle.ogg", "desc": "Genou levé, glissé arrière, l’autre genou. Sans s’arrêter."}, 
	{"id": "dance_griddy", "name": "Le Griddy", "tag": "Réseaux sociaux", "price": 220, "bpm": 140.0, "music": "res://audio/dances/griddy.ogg", "desc": "Penché, talons qui tapent, bras qui balancent mains ouvertes."}, 
	{"id": "dance_horse", "name": "Cheval invisible", "tag": "K-pop", "price": 250, "bpm": 132.0, "music": "res://audio/dances/horse.ogg", "desc": "Poignets croisés sur les rênes, pas chassés… et le lasso."}, 
	{"id": "dance_hedgehog", "name": "Le Hérisson pressé", "tag": "Jeux vidéo", "price": 300, "bpm": 150.0, "music": "res://audio/dances/hedgehog.ogg", "desc": "Poings sur les hanches, pied qui s’impatiente, doigt qui gronde et pouce levé."}, 
	{"id": "dance_zombie", "name": "Danse macabre", "tag": "Horreur", "price": 350, "bpm": 100.0, "music": "res://audio/dances/zombie.ogg", "desc": "Mains crochues, épaules qui sursautent, pas traînés. Le zombie, quoi."}, 
	{"id": "dance_sixseven", "name": "Le 6-7", "tag": "Mème 2025", "price": 260, "bpm": 144.0, "music": "res://audio/dances/sixseven.ogg", "desc": "Paumes vers le ciel, « six… seven », la balance qui monte et descend sur un beat drill.", "new": true}, 
	{"id": "dance_pikki", "name": "Pikki Pikki", "tag": "K-cheer", "price": 240, "bpm": 130.0, "music": "res://audio/dances/pikki.ogg", "desc": "L’air blasé… puis d’un coup les pouces levés qui montent et descendent, façon pom-pom girl coréenne.", "new": true}, 
	{"id": "dance_anxiety", "name": "Anxiety (le casque)", "tag": "Duo 2025", "price": 280, "bpm": 129.0, "music": "res://audio/dances/anxiety.ogg", "desc": "Casque sur les oreilles, on vibre seul… jusqu’à ce qu’un ami vienne danser derrière toi.", "new": true}, 
	{"id": "dance_grrr", "name": "Dame un Grrr", "tag": "Été 2025", "price": 260, "bpm": 126.0, "music": "res://audio/dances/grrr.ogg", "desc": "La griffe au visage, coup de hanche, griffures de chat, tour sur soi et rugissement.", "new": true}, 
	{"id": "dance_chicken", "name": "Poulet-Banane", "tag": "Mème 2025", "price": 220, "bpm": 128.0, "music": "res://audio/dances/chicken.ogg", "desc": "Les ailes de poulet qui battent, la tête qui picore… puis la banane, bras en arc au-dessus de la tête.", "new": true}, 
	{"id": "dance_golden", "name": "Golden", "tag": "K-pop 2025", "price": 320, "bpm": 123.0, "music": "res://audio/dances/golden.ogg", "desc": "Chasseuse de démons : dégainer, garde, coups nets et grand V doré. Le refrain, tu l’as forcément eu dans la tête.", "new": true}, 
	{"id": "dance_funk", "name": "Passinho funk", "tag": "Funk BR", "price": 260, "bpm": 130.0, "music": "res://audio/dances/funk.ogg", "desc": "Talon-pointe à toute vitesse, genoux qui rebondissent, hanches qui tournent, sur un funk brésilien à la cloche.", "new": true}, 
	{"id": "dance_amapiano", "name": "Pas Amapiano", "tag": "Amapiano 2026", "price": 280, "bpm": 113.0, "music": "res://audio/dances/amapiano.ogg", "desc": "Genoux souples, pas glissés, mains qui poussent et grand penché arrière, sur le log drum.", "new": true}, 
	{"id": "dance_retro", "name": "Retour en 2016", "tag": "Nostalgie 2026", "price": 240, "bpm": 140.0, "music": "res://audio/dances/retro.ogg", "desc": "Le Whip, le Nae Nae, deux pas de Juju… et Mannequin Challenge : tout le monde se fige !", "new": true}, 
	{"id": "dance_baby", "name": "Pretty Little Baby", "tag": "Vintage 2025", "price": 200, "bpm": 120.0, "music": "res://audio/dances/baby.ogg", "desc": "Doo-wop tout doux : claquements de doigts, bébé bercé, main sur le cœur et un petit twist.", "new": true}, 
]

const STARTING_TICKETS: int = 300

const MAX_SECONDS: float = 120.0

static func is_dance(id: String) -> bool:
	return id.begins_with("dance_")

static func info(id: String) -> Dictionary:
	for entry: Dictionary in LIST:
		if entry.id == id: return entry
	return {}

static func title(id: String) -> String:
	return str(info(id).get("name", id))

static var _streams: Dictionary = {}


static func music(id: String) -> AudioStream:
	if _streams.has(id): return _streams[id]
	var path: String = str(info(id).get("music", ""))
	var stream: AudioStream = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	if stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop = true
	_streams[id] = stream
	return stream


static func reward(points: float, won: bool) -> int:
	return 30 + mini(120, int(points / 3.0)) + (40 if won else 0)
