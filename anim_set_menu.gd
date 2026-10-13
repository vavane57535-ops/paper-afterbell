extends "res://anim_pose.gd"

# Clips des scènes de survol de l'écran titre (ui_menu_vignettes.gd, menu_scene_*.gd).
# Chaque clip est écrit pour un temps fort d'une scène : aucun clip du jeu, aucune émote.
# Les poses sont posées à la main avec Take (plus bas) : poses clés et intervalles,
# chevauchement (le bassin part, le buste suit, la tête et les mains arrivent après),
# arrêts nets (« s »), tenues qui respirent, pas posés sans glisser.
# Noms : menu_<scène>_<temps fort>@<Personnage>.

const MenuPlay = preload("res://anim_menu_play.gd")
const MenuTraining = preload("res://anim_menu_training.gd")
const MenuFriends = preload("res://anim_menu_friends.gd")
const MenuGallery = preload("res://anim_menu_gallery.gd")
const MenuCredits = preload("res://anim_menu_credits.gd")
const MenuQuit = preload("res://anim_menu_quit.gd")
const MenuShop = preload("res://anim_menu_shop.gd")

static func add(c: Dictionary) -> void :
	MenuPlay.add(c)
	MenuTraining.add(c)
	MenuFriends.add(c)
	MenuGallery.add(c)
	MenuCredits.add(c)
	MenuQuit.add(c)
	MenuShop.add(c)
