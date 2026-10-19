extends Node

# Traductions anglaises des textes EN PARTIE ajoutés en 0.16 (HUD, alerte de sortie, caméra, roue,
# repères de Lysia, Ashura ×1,5, LMS, encouragements de Bleuette, spectateur…).
#   godot --headless -- --tool test_ingame_i18n
# La langue n'est changée qu'en mémoire (rien n'est écrit dans settings.cfg).
# Imprime « I18N_MISSING <source> -> <rendu> » pour chaque texte resté en français, puis I18N_RESULT.

# Textes passés tels quels au traducteur par le code du jeu (gabarits avant formatage quand le code
# traduit le gabarit, texte final sinon).
const SOURCES: Array[String] = [
	"LA SORTIE EST OUVERTE", "LA SORTIE SE ROUVRE", "DERNIÈRES SECONDES", "EMPÊCHE-LES DE FUIR", "FUYEZ !", "SORTIE",
	"SORTIE OUVERTE · EMPÊCHE-LES DE FUIR", "SORTIE OUVERTE · FUYEZ !", "SORTIE À 01:20 · RESTEZ EN VIE", "LAST MAN STANDING",
	"CAMÉRA : DERRIÈRE", "CAMÉRA : LIBRE 360°", "Le personnage tourne avec la caméra", "Tourne librement autour du personnage",
	"Caméra", "Émotes", "Courir", "Interagir", "Saut", "Menu", "%s : caméra", "TAB : allié suivant", "SPECTATEUR", "Tu suis %s",
	"ÉVADÉ · TU ES EN SÉCURITÉ",
	"DANSES", "ÉMOTES", "Boutique du menu", "TAB · page suivante",
	"PRISE · %d m", "EN HAUT", "EN BAS", "ASHURA ×1,5", "PRISE",
	"BRANCHÉE · ASHURA ×1,5 · +10 PV / 1,3 s · %.1f s · BOUGER / INTERAGIR / 4 : DÉBRANCHER",
	"BRANCHÉE · +10 PV / 2 s · %.1f s · BOUGER / INTERAGIR / 4 : DÉBRANCHER",
	"ASHURA ×1,5 · TU ACCÉLÈRES LA RECHARGE DE LYSIA",
	"SURCHAUFFE · INVULNÉRABLE · ARMURE −%d PV · %.1f s",
	"INTERAGIR / 4 · SE BRANCHER · 15 s DE SOIN",
	"TRUE FORM · %.1f s · CHRONO SUSPENDU", "TRUE FORM · %.0f s · CAPACITÉ 4 : BONDIR",
	"DERNIER SURVIVANT", "DERNIÈRE SURVIVANTE", "TU ES ÉLIMINÉ", "TU ES ÉLIMINÉE", "TAB · suivre un allié", "AURA PLEINE", "Tes bonus de LMS sont débloqués.",
	"TU T’ÉCROULES…", "ÉTOURDI  ·  %.1f s", "AURA · %d / 100", "PRÊTE",
	"LMS · AURA PLEINE : LA SORTIE RESTE OUVERTE", "LMS · LA SORTIE S’OUVRIRA AUX 80 DERNIÈRES SECONDES",
	"TRUE FORM · LA SORTIE SE REFERME", "LMS · LA SORTIE SE REFERME",
	"Vise un allié à moins de 6 m", "Allié à moins de 6 m, près d’Alice, avec une recharge en cours",
	"LMS · +%d PV (150 max)", "PV",
	# Textes de partie réécrits en 0.17 (lot textes).
	"LES GRILLES SONT FERMÉES", "ALICE · Attrape-les avant qu’ils sortent.", "SURVIVANTS · Tenez jusqu’à 01:20, puis rejoignez la sortie.",
	"La cloche a sonné. La sortie s’ouvre à 01:20.", "Simon contre Alice", "Bleuette contre Alice", "ALERTE ARCHIVE · UN ÉLÈVE S’EST FAIT REPÉRER",
	"ARCHIVE · APPUIE SUR LA BONNE TOUCHE", "ALICE ARRIVE DERRIÈRE TOI ! BOUGE !", "OMBRES · TU VAS SURGIR DERRIÈRE UN ÉLÈVE AU HASARD",
	"Les élèves ont quelques secondes d’avance.", "ALICE ARRIVE DERRIÈRE TOI ! Dans 1,2 s. Bouge !", "TRUE FORM · bond mortel · chrono en pause",
	"UNE OMBRE DERRIÈRE TOI · Alice arrive dans 1,2 s !", "Pas de place derrière les élèves pour surgir.", "LMS · +65 PV (150 max)",
	"AURA PLEINE · Tiens jusqu’à la fin de ta musique !", "AURA PLEINE · 4 : un Dropkick (5 s de stun)", "AURA PLEINE · 4 : un tir de Shotgun (3 s de stun)",
	"AURA PLEINE · 4 : Je peux le faire !", "AURA PLEINE · un allié éliminé peut réparer ton armure (150 PV max).",
	"A-Ashura, ton drone, il gère ! Sa prochaine recharge ira 25 % plus vite.", "M-merci d’être là, Usayuko… Ton prochain stun dure 1,5 s de plus.",
	"C-cours, Simon, on te suit ! Ta prochaine Course éclair durera 2 s de plus.", "On… on va y arriver, Lysia ! Ta prochaine recharge sera 25 % plus courte.",
	"Elly, t-tu nous sauves la vie ! Ton prochain soin comptera double.", "J-je crois en toi ! Capacité rechargée.",
	"Tu tombes : la première fois, un allié peut te relever ; la deuxième, c’est fini. Lysia, elle, ne se relève jamais.",
]

func setup(_world: Node) -> void :
	_run.call_deferred()

func _run() -> void :
	await get_tree().process_frame
	var previous: String = PaperLanguage.language
	PaperLanguage.language = "en"
	var missing: Array[String] = []
	var texts: Array[String] = SOURCES.duplicate()
	for id: String in PaperEmotes.ids(): texts.append(PaperEmotes.title(id))
	for entry: Dictionary in PaperDances.LIST: texts.append(str(entry.name))
	for character: String in ["Ashura", "Usayuko", "Simon", "Lysia", "Elly"]:
		texts.append("BLEUETTE T’ENCOURAGE · " + PaperSurvivorMechanics.boost_summary(character))
	var neutral: Array[String] = ["LAST MAN STANDING", "Menu", "Facepalm", "Selfie", "Golden", "Pikki Pikki", "Pretty Little Baby", "Running Man", "ASHURA ×1,5", "%s : caméra", "AURA · %d / 100", "Dame un Grrr", "Passinho funk"]
	for source: String in texts:
		var shown: String = PaperLanguage.t(source)
		var french: bool = shown == source and not neutral.has(source)
		for marker: String in ["É", "È", "À", "Ç", "é", "è", "à", "ç", "ù", "ê", "â", "ô", "œ", " LA ", " DE ", " ET ", " TU ", " · PV", "PRISE", "SORTIE"]:
			if shown.contains(marker) and not neutral.has(source): french = true
		if french:
			missing.append(source)
			print("I18N_MISSING ", source, " -> ", shown)
		else:
			print("I18N_OK ", source, " -> ", shown)
	PaperLanguage.language = previous
	print("I18N_RESULT ", "OK" if missing.is_empty() else "MISSING %d" % missing.size())
	get_tree().quit()
