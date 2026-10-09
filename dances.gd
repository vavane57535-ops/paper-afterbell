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
	{"id": "dance_zombie", "name": "Danse macabre", "tag": "Horreur", "price": 350, "bpm": 100.0, "music": "res://audio/dances/zombie.ogg", "desc": "Mains crochues, épaules qui sursautent, pas traînés. Pour la nuit de la cloche."}, 
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
