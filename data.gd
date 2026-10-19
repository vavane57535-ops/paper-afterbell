class_name PaperData
extends RefCounted

const HEIGHTS: Dictionary = {"Usayuko": 1.87, "Simon": 1.75, "Ashura": 1.7, "Lysia": 1.75, "Elly": 1.9, "Bleuette": 1.65, "Alice": 1.75}
const NAMES = ["Ashura", "Usayuko", "Simon", "Lysia", "Elly", "Bleuette"]
const STATS = {
	"Ashura": [90.0, 90.0, 0, "OBSERVATEUR", "Pas de panique, j’ai un drone.", Color("7cacb9")], 
	"Usayuko": [165.0, 70.0, 0, "PROTECTEUR", "Derrière moi, les p’tits.", Color("bea56f")], 
	"Simon": [90.0, 140.0, 0, "ÉCLAIREUR", "J’cours d’abord, j’réfléchis après.", Color("a99abc")], 
	"Lysia": [200.0, -1.0, 700, "AUTOMATE", "Batterie faible. Tout va bien.", Color("85b5a2")], 
	"Elly": [100.0, 100.0, 0, "SOIGNEUSE", "Bouge pas, je te soigne.", Color("90bbc0")], 
	"Bleuette": [90.0, 120.0, 0, "SOUTIEN", "J-je crois en toi. Vraiment !", Color("82a0cc")], 
	"Alice": [-1.0, 200.0, 0, "TUEUSE", "Qui veut rester après les cours ?", Color("bd4958")]
}
const ABILITIES = {
	"Ashura": [["Drone", 25, "1 lance le drone, 3 change de mode. Rapide : stun 2 s, recharge 25 s. Précis : tu le pilotes en vue drone pendant qu’Ashura reste planté là ; stun 4 s, recharge 35 s. 10 s de batterie. Si Alice a son aura rouge, le drone attend qu’elle s’éteigne. L’épave reste 15 s, et Lysia peut la manger (+7 PV)."], ["Roller Boost", 40, "Maintiens sans bouger pour charger, relâche pour partir. 1–2 s de charge : 3 s de boost ; 2–3 s : 4 s ; 3 s ou plus : 6 s. Aussi rapide que Simon, et tu peux glisser sur les rails."], ["Rapide / précis", 0, "Passe le drone de rapide à précis, et inversement. Les deux modes partagent la même recharge : changer ne la remet pas à zéro."], ["—", 0, ""]], 
	"Usayuko": [["Grab", 45, "Tu fonces 4 s là où tu vises. Si tu touches Alice, tu l’embarques ; écrase-la contre un mur et elle est stun 3 s."], ["Block / contre", 30, "Garde de 1,5 s. Si Alice tape dedans, réappuie vite pour contrer : stun 4 s. Après un blocage réussi, la recharge n’est que de 20 s."], ["Punch", 35, "Un bon coup de poing : Alice est étourdie 2 s."], ["Dropkick · LMS", 0, "Une seule fois en LMS : tu fonces, Alice recule et reste étourdie 5 s."]], 
	"Simon": [["Flashbang / poing", 30, "3 change de mode. En lancer : 1 pour viser, puis 1 ou clic pour lancer (clic droit annule). La grenade étourdit 2 à 4 s. En poing : stun 2,5 s et Alice aveuglée 4 s."], ["Course éclair", 40, "Maintiens sans bouger pour charger. 1–2 s : 3 s de boost ; 2–3 s : 4 s ; 3 s ou plus : 6 s, toujours à la même vitesse. E pendant le boost pour embarquer un allié proche (pas Lysia, trop lourde). Avec Usayuko, tu perds 15 % de vitesse."], ["Lancer / poing", 0, "Passe la Flashbang du lancer au poing, sans toucher à sa recharge."], ["—", 0, ""]], 
	"Lysia": [["Surchauffe", 30, "Tu charges là où tu vises. Au contact, Alice est bloquée 3 s, puis étourdie 2 s de plus. Tu es invincible pendant la charge et la surchauffe, mais la chaleur grignote ton armure : −40 PV sur les 3 s (au prorata si elle est coupée), sans jamais descendre sous 1 PV."], ["Consommation", 50, "Envoie valser Alice jusqu’à 20 m, ou jusqu’au premier obstacle."], ["Xray", 20, "Pendant 3 s, tu vois Alice et les prises électriques à travers les murs."], ["Recharge électrique", 30, "Près d’une prise, branche-toi jusqu’à 15 s : +10 PV toutes les 2 s tant que tu ne bouges pas, jusqu’à l’armure pleine. Si Ashura est à moins de 4 m, ça va 1,5 fois plus vite. Bouger, INTERAGIR ou 4 te débranche, un coup aussi. Recharge de 30 s une fois le soin fini."]], 
	"Elly": [["Soin", 35, "Rend 50 PV à l’allié visé (ou au plus proche) en 3 s. Vous restez immobiles tous les deux."], ["Zone de soin", 50, "Une zone qui rend 2 PV/s pendant 20 s."], ["—", 0, ""], ["Shotgun · LMS", 0, "Une seule cartouche : 203 dégâts, Alice aveuglée et stun 3 s. Elle ne meurt pas pour autant."]], 
	"Bleuette": [["Encourager", 40, "Vise un allié à moins de 6 m pour booster sa prochaine action : drone d’Ashura −25 % de recharge, stun d’Usayuko +1,5 s, Course éclair de Simon +2 s, recharge de Lysia −25 %, soin d’Elly ×2."], ["Je crois en toi", 45, "Termine d’un coup la plus longue recharge d’un allié à moins de 6 m, s’il est à moins de 12 m d’Alice."], ["Chocolat", 35, "Deux tablettes par partie, seulement si tu es blessée : +20 PV tout de suite, puis +20 PV sur 10 s."], ["Je peux le faire · LMS", 0, "Avec l’aura pleine, une seule fois : +30 PV max. C’est le seul moyen de dépasser 150 PV en LMS."]], 
	"Alice": [["Slash", 3, "Un coup de griffes devant toi : 30 dégâts. Le cube rouge montre où ça touche."], ["Shadow reveal", 30, "Montre où sont tous les survivants, sauf Simon."], ["Shadow spike", 18, "Prépare, vise, confirme : les piques filent sur 15 m. 20 dégâts par cible et 15 % de lenteur. Clic droit pour annuler."], ["Ombres / Bond", 32, "Une ombre apparaît derrière chaque élève ; 1,2 s plus tard, tu surgis derrière l’un d’eux, au hasard. En True Form : un bond en avant à 40 dégâts, recharge 6 s."], ["Doubles d’ombre", 32, "Deux ombres traquent les élèves en marchant pendant 25 s : 10 dégâts au contact. Une capacité de survivant suffit à les dissiper."], ["True Form", 0, "Après 15 stuns subis, tu peux te transformer une fois, pendant 30 s : +70 % de vitesse, bond mortel, chrono en pause et sortie fermée."]]
}
const PASSIVES = {
	"Ashura": "Quand tu prends un coup, tes alliés voient ta silhouette à travers les murs. À moins de 4 m de Lysia branchée à une prise, tu accélères sa recharge (×1,5).", 
	"Usayuko": "115 PV + 50 surPV soignables. Voit l'allié le plus blessé. LMS : recharges améliorées et Dropkick.", 
	"Simon": "Le Shadow reveal ne te montre pas. Après un coup : +30 % de vitesse pendant 5 s. 10 % de chances d’esquiver. En LMS : recharges plus courtes.", 
	"Lysia": "200 d’armure. Tu manges les épaves de drone au contact (+7 PV) et tu te recharges aux prises. Les soins d’Elly ne marchent pas sur toi. À ta mort, tu exploses : Alice est étourdie 5 s si elle est à moins de 7 m. Personne ne peut te réanimer.", 
	"Elly": "Tu entends les pas et les capacités d’Alice partout sur la carte. En LMS : un tir de Shotgun, une seule fois.", 
	"Bleuette": "Après un coup : vitesse ×2 pendant 3 s. En LMS : « Je peux le faire » se débloque.", 
	"Alice": "Une seule porte condamnée à la fois. Tu traverses tes propres piques. Après chaque stun : aura rouge, et plus aucun stun pendant 5 s."
}

static func stat_text(character_name: String, mode: String = "om") -> String:
	var s: Array = STATS[character_name]
	return ("∞" if s[0] < 0 else str(int(s[0]))) + " PV     /     ∞ ENDURANCE"

static func passive_for(character_name: String, mode: String = "om") -> String:
	var passive: String = str(PASSIVES.get(character_name, ""))
	if mode == "om" and character_name == "Usayuko": passive = "115 PV + 50 surPV soignables. Les alliés collés à toi (1,5 m) sont à l’abri : la griffe d’Alice ne touche que toi. Tu peux bloquer ou contrer, et chaque protection remplit ton aura."
	if mode == "om" and character_name != "Alice": passive += " Aura : aide l’équipe ou reste en danger près d’Alice ; 100/100 débloque les bonus de LMS."
	return passive

static func abilities_for(character_name: String, mode: String = "om") -> Array:
	return ABILITIES.get(character_name, []).duplicate(true)
