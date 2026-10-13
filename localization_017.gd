extends RefCounted

# Traductions anglaises des textes NOUVEAUX en 0.17 (sans entrée plus ancienne à remplacer).
# Un texte modifié remplace son entrée d'origine dans localization.gd ou localization_016.gd ;
# seuls les textes qui n'avaient pas d'entrée arrivent ici. Consulté avant les autres dictionnaires.

const TEXT: Dictionary = {
}

# Modèles avec valeurs (%d, %s, %.1f) : [français, anglais].
const TEMPLATES: Array = [
]

static var _compiled: Array = []


static func lookup(source: String) -> Variant:
	if TEXT.has(source): return TEXT[source]
	if _compiled.is_empty() and not TEMPLATES.is_empty(): _compile()
	for entry: Array in _compiled:
		var found: RegExMatch = (entry[0] as RegEx).search(source)
		if not found: continue
		var output: String = str(entry[1])
		for i: int in range(1, found.get_group_count() + 1): output = output.replace("\u0001%d\u0002" % i, found.get_string(i))
		return output
	return null


static func _compile() -> void :
	var token: RegEx = RegEx.new()
	token.compile("%(?:[0-9]*\\.[0-9]+f|0?[0-9]*d|s|f)")
	for pair: Array in TEMPLATES:
		var french: String = str(pair[0])
		var pattern: String = "^"
		var at: int = 0
		for found: RegExMatch in token.search_all(french):
			pattern += _escape(french.substr(at, found.get_start() - at))
			var kind: String = found.get_string()
			pattern += "(.+?)" if kind == "%s" else "(-?[0-9]+(?:[.,][0-9]+)?)"
			at = found.get_end()
		pattern += _escape(french.substr(at)) + "$"
		var english: String = str(pair[1])
		var index: int = 0
		var rebuilt: String = ""
		at = 0
		for found: RegExMatch in token.search_all(english):
			index += 1
			rebuilt += english.substr(at, found.get_start() - at) + "\u0001%d\u0002" % index
			at = found.get_end()
		rebuilt += english.substr(at)
		var expression: RegEx = RegEx.new()
		if expression.compile(pattern) == OK: _compiled.append([expression, rebuilt])


static func _escape(text: String) -> String:
	var output: String = ""
	for character: String in text:
		output += ("\\" + character) if "\\^$.|?*+()[]{}".contains(character) else character
	return output
