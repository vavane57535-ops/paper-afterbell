extends RefCounted



const DIR: String = "res://ui/icons/"


const ABILITY_ICONS: Dictionary = {
	"Ashura": ["drone", "roller", "mode_cycle", ""], 
	"Usayuko": ["grab", "block", "punch", "dropkick"], 
	"Simon": ["flashbang", "flash_sprint", "switch_weapon", ""], 
	"Lysia": ["overheat", "consume", "xray", "outlet"], 
	"Elly": ["heal", "heal_zone", "", "shotgun"], 
	"Bleuette": ["encourage", "believe", "chocolate", "can_do"], 
	"Alice": ["slash", "reveal", "spikes", "shadow_step", "shadow_doubles", "true_form"], 
}
const PASSIVE_ICONS: Dictionary = {"Ashura": "ghost_ally", "Usayuko": "protect", "Simon": "invisible", "Lysia": "automaton", "Elly": "listen", "Bleuette": "adrenaline", "Alice": "shadow_grasp"}

const GENERIC: Array[String] = ["sprint", "jump", "interact", "archive", "exit", "lock", "aura", "heart", "hourglass", "bell", "emote", "eye", "tombstone", "stunned", "check", "cross", "cog", "play", "friends", "film", "scroll", "power", "map", "dummy", "gamepad", "keyboard", "speaker", "speaker_off", "trophy", "tv", "student", "pencil", "music", "sparkles", "notebook", "hand_ok"]

const CREDITS: String = "Icônes : game-icons.net — Lorc, Delapouite, Skoll, Sbed, Priorblue, Rihlsul, Guard13007, Lord Berandas — CC BY 3.0 (creativecommons.org/licenses/by/3.0). Formes blanches teintées, fond retiré. Détail : ui/icons/CREDITS.txt."

static var _cache: Dictionary = {}

static func icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty(): return null
	if _cache.has(icon_name): return _cache[icon_name]
	var path: String = DIR + icon_name + ".svg"
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[icon_name] = texture
	return texture

static func ability_name(character_name: String, slot: int) -> String:
	var names: Array = ABILITY_ICONS.get(character_name, [])
	return str(names[slot]) if slot >= 0 and slot < names.size() else ""

static func ability(character_name: String, slot: int) -> Texture2D:
	return icon(ability_name(character_name, slot))


static func ability_live(character_name: String, slot: int, effects: Dictionary) -> Texture2D:
	if character_name == "Simon" and slot == 0 and bool(effects.get("flash_melee", false)): return icon("punch")
	if character_name == "Ashura" and slot == 0 and bool(effects.get("drone_precise", false)): return icon("eye")
	return ability(character_name, slot)

static func passive(character_name: String) -> Texture2D:
	return icon(str(PASSIVE_ICONS.get(character_name, "aura")))
