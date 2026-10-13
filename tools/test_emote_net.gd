extends Node

# Test réseau de la synchro des émotes (un hôte + un client sur la même machine).
#   godot --headless -- --host-test --duration 45 --tool test_emote_net &
#   godot --headless -- --join-test --duration 40 --tool test_emote_net --out /tmp/x
# L'hôte fait jouer « clap » à deux survivants (0,7 s d'écart) puis une danse à deux autres.
# Le client vérifie que les temps d'émote reçus coïncident et avancent sans à-coups.

var world: Node
var out: String = "user://test_emote_net"
var samples: Dictionary = {}
var started: bool = false

func setup(owner_world: Node) -> void :
	world = owner_world
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(raw.size()):
		if raw[i] == "--out" and i + 1 < raw.size(): out = raw[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	if "--host-test" in raw: _host.call_deferred()
	else: _client.call_deferred()

func _wait_clock(seconds: float) -> void :
	var goal: float = world.clock + seconds
	while world.clock < goal: await get_tree().physics_frame

func _host() -> void :
	while world.phase != "playing": await get_tree().physics_frame
	await _wait_clock(6.0)
	var team: Array[PaperActor] = []
	for a: PaperActor in world.actors.values():
		if not a.killer and a.active() and a.id != 1 and int(a.id) >= 0 and a.bot: team.append(a)
	var killer: PaperActor = world.killer_actor()
	if killer: killer.bot = false;killer.move_input = Vector3.ZERO;killer.position += Vector3(60, 0, 0)
	for a: PaperActor in team: a.bot = false;a.move_input = Vector3.ZERO
	print("TEST_EMOTE_NET host survivants figés : ", team.size())
	if team.size() >= 2:
		team[1].position = team[0].position + Vector3(1.5, 0, 0)
		world._start_emote(team[0], "clap")
		await _wait_clock(0.7)
		world._start_emote(team[1], "clap")
	await _wait_clock(3.5)
	if team.size() >= 4:
		team[3].position = team[2].position + Vector3(1.5, 0, 0)
		world._start_emote(team[2], "dance_golden")
		await _wait_clock(0.7)
		world._start_emote(team[3], "dance_golden")
	print("TEST_EMOTE_NET host émotes lancées")

func _client() -> void :
	while world.phase != "playing": await get_tree().physics_frame
	started = true

func _physics_process(_delta: float) -> void :
	if not started or world.authoritative(): return
	for a: PaperActor in world.actors.values():
		var id: String = str(a.effects.get("emote_id", ""))
		if id.is_empty(): continue
		if not samples.has(a.id): samples[a.id] = []
		samples[a.id].append([Engine.get_physics_frames(), id, float(a.effects.get("emote_time", 0.0)), float(a.visual.get("_emote_clip_time"))])

func _exit_tree() -> void :
	if world == null or world.authoritative() or samples.is_empty():
		if world and not world.authoritative(): _write(["FAIL aucune émote reçue par le client"])
		return
	var lines: Array[String] = []
	var by_frame: Dictionary = {}
	var worst_back: float = 0.0
	for actor_id: Variant in samples:
		var list: Array = samples[actor_id]
		for i: int in range(list.size()):
			var row: Array = list[i]
			if not by_frame.has(row[0]): by_frame[row[0]] = []
			by_frame[row[0]].append([actor_id, row[1], row[2], row[3]])
			if i > 0 and list[i - 1][1] == row[1]: worst_back = maxf(worst_back, float(list[i - 1][2]) - float(row[2]))
		lines.append("acteur %s : %d échantillons, émotes %s" % [str(actor_id), list.size(), str(list.map( func(r: Array) -> String: return str(r[1])).reduce( func(acc: Array, v: String) -> Array: return acc if acc.has(v) else acc + [v], []))])
	var worst: Dictionary = {}
	var pairs: Dictionary = {}
	for frame: Variant in by_frame:
		var rows: Array = by_frame[frame]
		for i: int in range(rows.size()):
			for j: int in range(i + 1, rows.size()):
				if rows[i][1] != rows[j][1]: continue
				var key: String = str(rows[i][1])
				worst[key] = maxf(float(worst.get(key, 0.0)), absf(float(rows[i][2]) - float(rows[j][2])))
				pairs[key] = int(pairs.get(key, 0)) + 1
	var ok: bool = not pairs.is_empty()
	for key: Variant in pairs:
		var good: bool = float(worst[key]) < 0.02
		ok = ok and good
		lines.append("%s %s : %d images où deux survivants la jouent, écart max des temps = %.4f s" % ["OK" if good else "FAIL", key, pairs[key], worst[key]])
	lines.append("plus grand recul du temps d'émote entre deux images (extrapolation client) : %.4f s" % worst_back)
	lines.append("RESULT " + ("PASS" if ok and worst_back < 0.1 else "FAIL"))
	_write(lines)

func _write(lines: Array) -> void :
	for line: Variant in lines: print("TEST_EMOTE_NET ", line)
	var file: FileAccess = FileAccess.open(out.path_join("net_report.txt"), FileAccess.WRITE)
	if file: file.store_string("\n".join(lines) + "\n")
