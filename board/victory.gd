extends Node

# last player standing wins. fall off the summit and you're out.

const DEATH_Y = -5.0
const TutorialScene = preload("res://UI/minigame_tutorial.gd")

var win_label: Label
var winner = null
var started: bool = false
var match_over: bool = false

func _ready() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	win_label = Label.new()
	win_label.add_theme_font_size_override("font_size", 54)
	win_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_label.add_theme_color_override("font_outline_color", Color.BLACK)
	win_label.add_theme_constant_override("outline_size", 12)
	win_label.hide()
	layer.add_child(win_label)

	# Connect timer if present
	var timer_ui = get_parent().get_node_or_null("TimerUi")
	if timer_ui and timer_ui.has_signal("time_up"):
		timer_ui.time_up.connect(_on_time_up)
		timer_ui.running = false # Pause timer until tutorial ends

	# Freeze player controls during tutorial
	for p in get_tree().get_nodes_in_group("players"):
		p.set_physics_process(false)
		p.set_process(false)

	_show_tutorial(timer_ui)


func _show_tutorial(timer_ui: CanvasLayer) -> void:
	var tut = TutorialScene.new()
	var controls_data: Array[Dictionary] = [
		{
			"player": "Player 1",
			"color": Color(0.18, 0.75, 0.98),
			"controls": [["Move", "WASD"], ["Roll Snowball", "Keep Moving"], ["Launch Ball", "Space / LMB"]]
		},
		{
			"player": "Player 2",
			"color": Color(0.22, 0.86, 0.42),
			"controls": [["Move", "Arrow Keys"], ["Roll Snowball", "Keep Moving"], ["Launch Ball", "Enter"]]
		},
		{
			"player": "Player 3",
			"color": Color(1.0, 0.62, 0.16),
			"controls": [["Move", "I J K L"], ["Roll Snowball", "Keep Moving"], ["Launch Ball", "O Key"]]
		},
		{
			"player": "Player 4",
			"color": Color(0.95, 0.35, 0.75),
			"controls": [["Move", "T F G H"], ["Roll Snowball", "Keep Moving"], ["Launch Ball", "Y Key"]]
		}
	]
	var tips: Array[String] = [
		"Roll around on the icy mountain to grow your snowball bigger and heavier.",
		"Bumping into players or launching your snowball knocks them backward.",
		"Knock your rivals off the summit! Last player standing wins."
	]
	tut.setup("Snowball Summit", "Grow your snowball and knock opponents off the summit!", controls_data, tips, 7)
	tut.tutorial_finished.connect(func():
		for p in get_tree().get_nodes_in_group("players"):
			p.set_physics_process(true)
			p.set_process(true)
		if timer_ui and "running" in timer_ui:
			timer_ui.running = true
		started = true
	)
	add_child(tut)
	tut.start_tutorial()

func _process(_delta: float) -> void:
	if not started or match_over:
		return

	var alive = []
	for p in get_tree().get_nodes_in_group("players"):
		if p.global_position.y < DEATH_Y:
			p.hide()
		else:
			alive.append(p)

	if alive.size() == 1:
		win(alive[0])
	elif alive.size() == 0:
		draw_match()

func _on_time_up() -> void:
	if match_over:
		return
	var alive = []
	for p in get_tree().get_nodes_in_group("players"):
		if p.global_position.y >= DEATH_Y:
			alive.append(p)

	if alive.size() == 1:
		win(alive[0])
	elif alive.size() > 1:
		var best_player = alive[0]
		var best_size: float = -1.0
		for p in alive:
			var sb = p.get_node_or_null("Snowball")
			var sz: float = sb.size if (sb and "size" in sb) else 0.0
			if sz > best_size:
				best_size = sz
				best_player = p
		win(best_player)
	else:
		draw_match()

func win(player: Node) -> void:
	match_over = true
	winner = player

	# slow mo
	Engine.time_scale = 0.4

	if player.has_method("play_anim"):
		player.play_anim("victory", true, 0.2)

	var p_id: int = player.get("player_id") if "player_id" in player else 0
	var p_name: String = GameState.get_player_name(p_id + 1) if GameState else player.name
	if GameState:
		GameState.award_coins(p_id + 1, 7)

	# camera moves in on winner
	var cam = get_viewport().get_camera_3d()
	if cam:
		cam.look_at(player.global_position, Vector3.UP)
		var spot = player.global_position + Vector3(0, 2.0, 5.0)
		create_tween().tween_property(cam, "global_position", spot, 1.2)

	# text
	win_label.text = "%s WINS!\n(+7 Coins Awarded!)\nReturning to Board..." % p_name
	win_label.show()

	await get_tree().create_timer(3.0, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://Board/Board.tscn")

func draw_match() -> void:
	match_over = true
	win_label.text = "DRAW!\nReturning to Board..."
	win_label.show()

	await get_tree().create_timer(3.0, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://Board/Board.tscn")
