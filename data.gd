class_name PaperData
extends RefCounted

const HEIGHTS: Dictionary = {"Usayuko": 1.87, "Simon": 1.75, "Ashura": 1.7, "Lysia": 1.75, "Elly": 1.9, "Bleuette": 1.65, "Alice": 1.75}
const NAMES = ["Ashura", "Usayuko", "Simon", "Lysia", "Elly", "Bleuette"]
const STATS = {
	"Ashura": [90.0, 90.0, 0, "OBSERVATEUR", "Les yeux de l'équipe.", Color("7cacb9")], 
	"Usayuko": [165.0, 70.0, 0, "PROTECTEUR", "Tenez-vous derrière moi.", Color("bea56f")], 
	"Simon": [90.0, 140.0, 0, "ÉCLAIREUR", "Un pas d'avance sur l'ombre.", Color("a99abc")], 
	"Lysia": [200.0, -1.0, 700, "AUTOMATE", "L'armure se brise. La volonté reste.", Color("85b5a2")], 
	"Elly": [100.0, 100.0, 0, "SOIGNEUR", "Personne ne reste en arrière.", Color("90bbc0")], 
	"Bleuette": [90.0, 120.0, 0, "SOUTIEN", "Je crois en toi.", Color("82a0cc")], 
	"Alice": [-1.0, 200.0, 0, "L'OMBRE DE L'ÉCOLE", "Elle connaît la dernière sonnerie.", Color("bd4958")]
}
const ABILITIES = {
	"Ashura": [["Drone", 25, "3 change de mode ; 1 lance. Rapide : stun 2 s, recharge 25 s. Précis : contrôle en vue drone, Ashura immobile, stun 4 s, recharge 35 s. Batterie 10 s ; face à l’aura rouge d’Alice, le drone attend qu’elle s’éteigne. Épave 15 s, Lysia la mange pour 7 PV."], ["Roller Boost", 40, "Maintiens pour charger sans bouger, relâche pour partir. 1–2 s : boost 3 s ; 2–3 s : 4 s ; 3 s et plus : 6 s. Vitesse identique à Simon. Permet de glisser sur les rails."], ["Rapide / précis", 0, "Change le mode du drone ; recharge partagée, conservée en changeant de mode."], ["—", 0, ""]], 
	"Usayuko": [["Grab", 45, "Charge 4 s vers ton viseur, attrape Alice au contact et emporte-la. Impact contre un mur : stun 3 s."], ["Block / contre", 30, "Bloque 1,5 s. En cas d'impact, réappuie pour un contre de 4 s. Recharge réussie : 20 s."], ["Punch", 35, "Coup de poing : 2 s d'étourdissement."], ["Dropkick · LMS", 0, "Une charge unique, recul et 5 s d'étourdissement."]], 
	"Simon": [["Flashbang / poing", 30, "3 change de mode. Lancer : active 1 pour viser, puis 1 ou clic pour lancer ; clic droit annule. Grenade : stun 2–4 s. Poing : stun 2,5 s et aveuglement 4 s."], ["Course éclair", 40, "Maintiens en restant immobile. Charge 1–2 s : boost 3 s ; 2–3 s : 4 s ; ≥3 s : 6 s, même vitesse. E pendant le boost pour emporter un allié proche, sauf Lysia. Usayuko réduit la vitesse de 15 %."], ["Lancer / poing", 0, "Change le mode de la Flashbang, sans réinitialiser sa recharge."], ["—", 0, ""]], 
	"Lysia": [["Surchauffe", 30, "Charge en avant. Au contact : Alice immobilisée 3 s, puis stun 2 s supplémentaires. Lysia invincible pendant la charge et la surchauffe, mais la chaleur use doucement son armure : −40 PV sur les 3 s (au prorata si elle est interrompue), jamais sous 1 PV."], ["Consommation", 50, "Repousse Alice sur 20 m, jusqu’au premier obstacle."], ["Xray", 20, "Voit Alice et les prises électriques à travers les murs pendant 3 s."], ["Recharge électrique", 30, "Près d’une prise, branche-toi jusqu’à 15 s : +10 PV toutes les 2 s sans bouger, arrêt à armure pleine. Ashura à moins de 4 m : soin 1,5 fois plus rapide. Bouger, INTERAGIR ou 4 te débranche. Recharge 30 s après la fin du soin. Être frappée interrompt le branchement."]], 
	"Elly": [["Soin", 35, "Soigne de 50 PV l’allié visé (sinon le plus proche) en 3 s, tous deux immobiles."], ["Zone de soin", 50, "2 PV/s dans la zone pendant 20 s."], ["—", 0, ""], ["Shotgun · LMS", 0, "Un tir unique : 203 dégâts, aveuglement et stun 3 s. Alice reste immortelle."]], 
	"Bleuette": [["Encourager", 40, "Vise n’importe quel allié à moins de 6 m : prochain drone -25 % recharge ; prochain stun d’Usayuko +1,5 s ; prochaine Course éclair de Simon +2 s ; prochaine recharge de Lysia -25 % ; prochain soin d’Elly ×2."], ["Je crois en toi", 45, "Recharge une capacité d’un allié visé à moins de 6 m et situé à moins de 12 m d’Alice."], ["Chocolat", 35, "Seulement blessée, deux tablettes par partie. +20 PV immédiatement, puis +20 PV progressivement en 10 s."], ["Je peux le faire · LMS", 0, "Aura remplie : augmente une fois les PV maximum de 30. Seul moyen de dépasser 150 PV en LMS."]], 
	"Alice": [["Slash", 3, "Griffe en volume devant toi : 30 dégâts. Le cube rouge montre la zone du coup."], ["Shadow reveal", 30, "Révèle tous les survivants sauf Simon."], ["Shadow spike", 18, "Prépare, vise, confirme : les piques avancent rapidement sur 15 m. 20 dégâts par cible, lenteur 15 %. Clic droit annule."], ["Ombres / Bond", 32, "Ombres derrière chaque élève, vraie Alice derrière un élève au hasard après 1,2 s. En True Form : bond frontal infligeant 40 dégâts, recharge 6 s."], ["Doubles d’ombre", 32, "Deux ombres poursuivent en marchant pendant 25 s : 10 dégâts au contact. Les capacités de survivants les dispersent."], ["True Form", 0, "15 stuns subis débloquent une unique transformation de 30 s : vitesse +70 %, bond meurtrier, chronomètre suspendu et sortie fermée."]]
}
const PASSIVES = {
	"Ashura": "Quand tu es frappé, tes alliés voient ta silhouette à travers les murs. Près de Lysia branchée à une prise (4 m), sa recharge est 1,5 fois plus rapide.", 
	"Usayuko": "115 PV + 50 surPV soignables. Voit l'allié le plus blessé. LMS : recharges améliorées et Dropkick.", 
	"Simon": "Invisible au Shadow reveal. Après un coup : +30 % vitesse 5 s. Esquive : 10 %. LMS : recharges améliorées.", 
	"Lysia": "Armure 200. Mange les épaves de drone au contact : +7 PV. Se recharge aux prises. Les soins d’Elly ne fonctionnent pas sur elle. Explose à sa mort : Alice étourdie 5 s dans un rayon de 7 m. Ne peut pas être réanimée.", 
	"Elly": "Entend les actions d'Alice partout dans l'école. LMS : Shotgun unique.", 
	"Bleuette": "Après un coup : vitesse ×2 pendant 3 s. LMS : hausse des ressources.", 
	"Alice": "Une seule porte condamnée à la fois. Traverse ses propres piques. Après chaque stun : aura rouge et protection contre les stuns pendant 5 s."
}

static func stat_text(character_name: String, mode: String = "om") -> String:
	var s: Array = STATS[character_name]
	return ("∞" if s[0] < 0 else str(int(s[0]))) + " PV     /     ∞ ENDURANCE"

static func passive_for(character_name: String, mode: String = "om") -> String:
	var passive: String = str(PASSIVES.get(character_name, ""))
	if mode == "om" and character_name == "Usayuko": passive = "115 PV + 50 surPV soignables. Protège les alliés collés à lui (1,5 m) : la griffe d’Alice ne touche que lui. Peut bloquer ou contrer. Chaque protection remplit l’aura."
	if mode == "om" and character_name != "Alice": passive += " Aura : aide l’équipe ou reste en danger près d’Alice ; 100/100 débloque les bonus de LMS."
	return passive

static func abilities_for(character_name: String, mode: String = "om") -> Array:
	return ABILITIES.get(character_name, []).duplicate(true)
