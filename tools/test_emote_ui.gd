extends Node

# Captures de la boutique (menu) ou de la roue des émotes (en partie, avec --simulate).
#   xvfb-run ... godot --rendering-driver opengl3 -- --tool test_emote_ui --out /tmp/x
#   xvfb-run ... godot --rendering-driver opengl3 -- --simulate Simon --tool test_emote_ui --wheel --out /tmp/x

var world: Node
var out: String = "user://test_emote_ui"

func setup(owner_world: Node) -> void :
	world = owner_world
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(raw.size()):
		if raw[i] == "--out" and i + 1 < raw.size(): out = raw[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	if "--wheel" in raw: _wheel.call_deferred()
	else: _shop.call_deferred()

func _snap(file_name: String) -> void :
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file_name))
	print("TEST_EMOTE_UI ", file_name)

func _wait(seconds: float) -> void :
	await get_tree().create_timer(seconds).timeout

func _shop() -> void :
	await _wait(2.5)
	world.tickets = 900
	world.owned_dances = ["dance_floss", "dance_golden"]
	world.ui.shop_selected = "dance_golden"
	world.ui.show_shop()
	await _wait(1.6)
	await _snap("shop_top.png")
	var scroll: ScrollContainer = null
	for node: Node in world.ui.page.find_children("*", "ScrollContainer", true, false):
		scroll = node
		break
	if scroll:
		scroll.scroll_vertical = 900
		await _wait(0.4)
		await _snap("shop_mid.png")
		scroll.scroll_vertical = 4000
		await _wait(0.4)
		await _snap("shop_bottom.png")
	get_tree().quit()

func _wheel() -> void :
	while world.phase != "playing":
		await get_tree().physics_frame
	await _wait(1.0)
	world.owned_dances = PaperDances.LIST.map( func(entry: Dictionary) -> String: return str(entry.id))
	var actor: PaperActor = world.local_actor()
	actor.bot = false
	world.emote_wheel.open()
	for p: int in range(world.emote_wheel._pages().size()):
		world.emote_wheel.page = p
		world.emote_wheel.selected = 2
		world.emote_wheel.queue_redraw()
		await _wait(0.3)
		await _snap("wheel_%d.png" % p)
	world.emote_wheel.close()
	get_tree().quit()
