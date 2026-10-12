extends Node

# Capture du salon avec le sélecteur « Qui joue Alice ? » et le badge ALICE.
# godot --rendering-driver opengl3 -- --tool lobby_alice_capture --out /tmp/x [--as-client]

var world: Node
var out_dir: String = "/tmp/lobby_capture"
var as_client: bool = false

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--as-client": as_client = true
	_run.call_deferred()

func _shot(file_name: String) -> void :
	for k: int in range(4): await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/" + file_name)
	print("FRAME ", out_dir + "/" + file_name)

func _run() -> void :
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 800)
	for i: int in range(6): await get_tree().process_frame
	# Salon hors ligne simulé : le serveur n'est pas ouvert, seul l'écran nous intéresse.
	world.phase = "lobby";world.stage.visible = true
	world.roster = {1: {"name": "Hote", "character": "Simon", "malice": 2}, 51234: {"name": "Margaux", "character": "Lysia", "malice": 4}, 77001: {"name": "Theo", "character": "Bleuette", "malice": 1}}
	world.room_options = world._clean_room_options({"killer_mode": "player", "alice_peer": 51234})
	world.ui.show_lobby()
	await _shot("lobby_host.png")
	var choice: OptionButton = world.ui.get("lobby_alice")
	if is_instance_valid(choice):
		choice.show_popup()
		await _shot("lobby_host_popup.png")
		choice.get_popup().hide()
	get_tree().quit()
