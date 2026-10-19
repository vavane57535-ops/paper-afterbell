extends "res://anim_pose.gd"

# Clips des scènes de survol de l'écran titre (ui_menu_vignettes.gd, menu_scene_*.gd).
# Chaque clip est écrit pour un temps fort d'une scène : aucun clip du jeu, aucune émote.
# Les poses sont posées à la main avec Take (anim_menu_take.gd) : poses clés et intervalles,
# chevauchement (le bassin part, le buste suit, la tête et les mains arrivent après),
# arrêts nets (« s »), tenues qui respirent, pas plantés qui ne glissent pas.
# Noms : menu_<scène>_<temps fort>@<Personnage>.
#
# Les clips ne sont pas générés au démarrage du jeu (add reste vide) : chaque scène les écrit
# pendant sa construction en tâche de fond, un acteur par image, avec les mesures réelles de
# ses squelettes (pieds plantés au centimètre), puis les range dans la bibliothèque (install).

const AnimLibrary = preload("res://anim_library.gd")
const MenuPlay = preload("res://anim_menu_play.gd")
const MenuTraining = preload("res://anim_menu_training.gd")
const MenuFriends = preload("res://anim_menu_friends.gd")
const MenuGallery = preload("res://anim_menu_gallery.gd")
const MenuSettings = preload("res://anim_menu_settings.gd")
const MenuCredits = preload("res://anim_menu_credits.gd")
const MenuQuit = preload("res://anim_menu_quit.gd")
const MenuShop = preload("res://anim_menu_shop.gd")

const WRITERS: Dictionary = {
	"play": MenuPlay, "training": MenuTraining, "friends": MenuFriends, "gallery": MenuGallery,
	"settings": MenuSettings, "credits": MenuCredits, "quit": MenuQuit, "shop": MenuShop,
}

static func add(_c: Dictionary) -> void :
	pass

# Écrivains de clips d'une scène : une liste d'appels (un par acteur ou par temps fort), chacun
# renvoie {nom complet : source}. rigs : {acteur : AnimTake.rig_of(visual)}.
static func writers(scene_id: String, rigs: Dictionary) -> Array:
	var script: GDScript = WRITERS.get(scene_id)
	if script == null: return []
	return script.call("writers", rigs)

static func install(made: Dictionary) -> void :
	if made.is_empty(): return
	if AnimLibrary._all.is_empty(): AnimLibrary._all = AnimLibrary._sources()
	for full: String in made:
		AnimLibrary._all[full] = made[full]
		AnimLibrary._owner[full] = "menu"
		AnimLibrary._cache.erase(full)
