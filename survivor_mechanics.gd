class_name PaperSurvivorMechanics
extends RefCounted

# Réglages 0.16 des survivants, appelés par PaperCombat (côté hôte uniquement) :
# usure de la surchauffe de Lysia, prise accélérée par Ashura, boost de Simon et PV de début de LMS.

const OVERHEAT_SECONDS: float = 3.0
const OVERHEAT_HP_COST: float = 40.0
# La surchauffe rend Lysia invincible : son usure ne peut donc pas la mettre hors service.
const OVERHEAT_HP_FLOOR: float = 1.0

const ASHURA_OUTLET_RANGE: float = 4.0
# Petite marge de sortie pour que le lien ne clignote pas à la limite des 4 m.
const ASHURA_OUTLET_RELEASE: float = 4.6
const ASHURA_OUTLET_FACTOR: float = 1.5

const SIMON_SPRINT_BONUS: float = 2.0

const LMS_HP_BONUS: float = 65.0
const LMS_HP_CAP: float = 150.0

const BOOST_SUMMARY: Dictionary = {
	"Ashura": "prochain drone : recharge −25 %",
	"Usayuko": "prochain stun +1,5 s",
	"Simon": "prochaine Course éclair +2 s",
	"Lysia": "prochaine recharge −25 %",
	"Elly": "prochain soin ×2",
}


# Perte progressive et linéaire : 40 PV sur les 3 s de surchauffe, au prorata du temps écoulé.
static func overheat_drain(actor) -> float:
	var left: float = maxf(0.0, float(actor.effects.get("overheat_time", 0.0)))
	var goal: float = OVERHEAT_HP_COST * clampf(1.0 - left / OVERHEAT_SECONDS, 0.0, 1.0)
	var drained: float = float(actor.effects.get("overheat_drained", 0.0))
	if goal <= drained: return 0.0
	actor.effects["overheat_drained"] = goal
	var before: float = float(actor.hp)
	actor.hp = maxf(minf(before, OVERHEAT_HP_FLOOR), before - (goal - drained))
	return before - float(actor.hp)


static func outlet_partner(combat, lysia):
	var current: int = int(lysia.effects.get("outlet_ashura", -1))
	for other in combat.world.actors.values():
		if other == lysia or other.killer or other.character != "Ashura" or not combat._can_act(other): continue
		if absf(other.position.y - lysia.position.y) > 2.0: continue
		var reach: float = ASHURA_OUTLET_RELEASE if int(other.id) == current else ASHURA_OUTLET_RANGE
		if combat._flat(other.position - lysia.position).length() > reach: continue
		if not combat._los(lysia.position, other.position): continue
		return other
	return null


# +65 PV au début du LMS, sans dépasser 150. Les élèves dont le maximum est sous 150 voient
# leur maximum porté à 150 ; Usayuko (165) et Lysia (200) gardent leur armure naturelle,
# mais le bonus ne les fait pas monter au-delà de 150. Seul le courage de Bleuette dépasse 150.
static func apply_lms_health(actor) -> float:
	var before: float = float(actor.hp)
	if float(actor.max_hp) < LMS_HP_CAP:
		actor.max_hp = LMS_HP_CAP
		actor.effects["lms_hp_cap"] = LMS_HP_CAP
	actor.hp = minf(float(actor.max_hp), maxf(before, minf(before + LMS_HP_BONUS, LMS_HP_CAP)))
	return float(actor.hp) - before


static func boost_summary(character_name: String) -> String:
	return str(BOOST_SUMMARY.get(character_name, ""))
