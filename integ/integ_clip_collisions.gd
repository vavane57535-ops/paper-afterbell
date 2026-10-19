extends Node
# Intégration : liste les clips définis par plusieurs jeux (le dernier écrase l'autre en silence).
const AnimLibrary = preload("res://anim_library.gd")

func setup(_world: Node) -> void:
	var owners: Dictionary = {}
	var dup: int = 0
	var t0: int = Time.get_ticks_msec()
	for set_name: String in AnimLibrary.SETS:
		var path: String = "res://anim_set_%s.gd" % set_name
		if not ResourceLoader.exists(path):
			print("ABSENT ", path)
			continue
		var c: Dictionary = {}
		var t: int = Time.get_ticks_msec()
		load(path).add(c)
		print("SET %s : %d clips en %d ms" % [set_name, c.size(), Time.get_ticks_msec() - t])
		for n: String in c:
			if owners.has(n):
				dup += 1
				print("DOUBLON ", n, " : ", owners[n], " puis ", set_name)
			owners[n] = set_name
	print("TOTAL %d clips, %d doublons, %d ms" % [owners.size(), dup, Time.get_ticks_msec() - t0])
	get_tree().quit()
