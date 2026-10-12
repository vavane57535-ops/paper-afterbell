extends Node

# Traductions anglaises des textes EN PARTIE ajoutés en 0.16 (HUD, alerte de sortie, caméra, roue,
# repères de Lysia, Ashura ×1,5, LMS, encouragements de Bleuette, spectateur…).
#   godot --headless -- --tool test_ingame_i18n
# La langue n'est changée qu'en mémoire (rien n'est écrit dans settings.cfg).
# Imprime « I18N_MISSING <source> -> <rendu> » pour chaque texte resté en français, puis I18N_RESULT.

# Textes passés tels quels au traducteur par le code du jeu (gabarits avant formatage quand le code
# traduit le gabarit, texte final sinon).
const SOURCES: Array[String] = [
	"LA SORTIE EST OUVERTE", "LA SORTIE SE ROUVRE", "DERNIÈRES SECONDES", "EMPÊCHEZ LEUR FUITE", "FUYEZ !", "SORTIE",
	"SORTIE OUVERTE · EMPÊCHEZ LEUR FUITE", "SORTIE OUVERTE · FUYEZ !", "SORTIE À 01:20 · RESTEZ EN VIE", "LAST MAN STANDING",
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
	"TRUE FORM · %.1f s · CHRONO SUSPENDU", "TRUE FORM · %.0f s · COMPÉTENCE 4 : BONDIR",
	"DERNIÈRE PRÉSENCE", "VOUS ÊTES TOMBÉ", "TAB · suivre un allié", "AURA ÉVEILLÉE", "Les bonus de LMS sont disponibles.",
	"LA DERNIÈRE BLESSURE…", "ÉTOURDI  ·  %.1f s", "AURA · %d / 100", "PRÊTE",
	"LMS · AURA COMPLÈTE, SORTIE MAINTENUE", "LMS · LA SORTIE S’OUVRIRA AUX 80 DERNIÈRES SECONDES",
	"TRUE FORM · LA SORTIE SE REFERME", "LMS · LA SORTIE SE REFERME",
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
