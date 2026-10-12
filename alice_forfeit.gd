class_name PaperAliceForfeit
extends RefCounted

# Fin de manche par forfait : le joueur humain qui incarne Alice quitte la partie en pleine manche.
# Les survivants encore là gagnent et la manche se termine sur le film du blocus (film_blocus.gd).
# Une Alice IA ne déclenche jamais ça (elle ne se déconnecte pas, et un acteur devenu bot non plus).

const KIND: String = "ending_blocus"

# Identifiant réseau de ce poste, mémorisé à la connexion : une fois l'hôte parti, ni
# multiplayer.get_unique_id() ni le pair ENet ne répondent plus.
static var own_peer: int = 0


static func applies(world: Node, alice: PaperActor) -> bool:
	return alice != null and alice.killer and not alice.bot and not bool(world.get("training")) and str(world.get("phase")) == "playing"


# Hôte (ou serveur dédié) : un pair vient de partir. Vrai si c'était Alice et que la manche est finie.
static func peer_left(world: Node, peer: int) -> bool:
	var alice: PaperActor = world.actors.get(peer)
	if not applies(world, alice): return false
	alice.bot = true;alice.move_input = Vector3.ZERO;alice.velocity = Vector3.ZERO;alice.sprint = false
	alice.effects["forfeit"] = true
	print("ALICE_FORFEIT peer=", peer, " survivors=", survivors(world).size())
	world._finish("survivors", true)
	return true


# Survivants qui participent au blocus : encore en vie (même au sol) ou déjà évadés.
static func survivors(world: Node) -> Array[PaperActor]:
	var result: Array[PaperActor] = []
	for person: String in PaperData.NAMES:
		for actor: PaperActor in world.actors.values():
			if actor.killer or actor.character != person: continue
			var escaped: bool = bool(actor.effects.get("escaped", false))
			if (actor.alive and not bool(actor.effects.get("dying", false))) or escaped: result.append(actor)
	return result


static func winners(world: Node) -> Array:
	var ids: Array = []
	for actor: PaperActor in survivors(world): ids.append(actor.id)
	return ids


# Distribution du film : les survivants restants, le mégaphone au meilleur score.
static func stage(world: Node) -> void :
	var people: Array = []
	var focus: String = ""
	var best: float = 0.0
	for actor: PaperActor in survivors(world):
		people.append(actor.character)
		for row: Dictionary in world.match_results:
			if int(row.get("id", -1)) == actor.id and float(row.get("points", 0.0)) > best:
				best = float(row.get("points", 0.0));focus = actor.character
	world.ending_people = people
	world.ending_kind = KIND
	world.ending_focus = str(people[PaperFilmBlocus.pick_lead(people, focus)]) if not people.is_empty() else "Ashura"


# Client : l'hôte qui jouait Alice a fermé la partie. La simulation est partie avec lui, mais
# chaque client a encore les acteurs : on joue le blocus localement avant de revenir au menu.
static func host_left(world: Node) -> bool:
	var own_id: int = own_peer
	if bool(world.get("dedicated")) or not bool(world.get("networked")) or own_id <= 1: return false
	var service: Variant = world.get("service")
	if service != null and bool(service.get("regional")): return false
	var alice: PaperActor = world.actors.get(1)
	if not applies(world, alice): return false
	var me: PaperActor = world.actors.get(own_id)
	if me == null or me.killer: return false
	var rows: Array[Dictionary] = []
	for actor: PaperActor in world.actors.values():
		if actor.killer: continue
		var points: float = float(actor.effects.get("score_points", 0.0))
		rows.append({"id": actor.id, "character": actor.character, "name": actor.display_name, "points": snappedf(points, 0.1), "aura": snappedf(float(actor.effects.get("aura_charge", 0.0)), 0.1), "grade": PaperMatchRewards.grade(points), "breakdown": {}})
	rows.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return float(a.points) > float(b.points) if not is_equal_approx(float(a.points), float(b.points)) else int(a.id) < int(b.id))
	world.match_results = rows
	world.emote_wheel.hide()
	world._award_tickets("survivors", me)
	stage(world)
	world.leave_network()
	world.pause_open = false
	world.phase = "ending";world.outcome = "survivors";world.cinema = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.audio.set_mode("blocus")
	world._begin_film(false)
	print("ALICE_FORFEIT host_left people=", world.ending_people)
	return true
