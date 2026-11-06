class_name TurnManager
extends Node

@export var players: Array[Node3D] = []
@export var turn_label: Label
@export var hud_info_label: Label

var current_player_index: int = 0
var roll_button: Button = null
var remaining_steps_label: Label = null
var player_hud_containers: Array[PanelContainer] = []
var victory_overlay: Control = null

func _ready() -> void:
	# Find players if not manually populated
	if players.is_empty():
		var found = get_tree().get_nodes_in_group("players")
		for node in found:
			if node is Node3D:
				players.append(node)

	# Sort players by player_id
	players.sort_custom(func(a, b): return a.player_id < b.player_id)

	# Connect signals for each player
	for p in players:
		if p.has_signal("turn_finished") and not p.turn_finished.is_connected(_on_player_turn_finished):
			p.turn_finished.connect(_on_player_turn_finished)
		if p.has_signal("steps_updated") and not p.steps_updated.is_connected(_on_steps_updated):
			p.steps_updated.connect(_on_steps_updated)

	# Connect to GameState updates
	if not GameState.player_stats_changed.is_connected(_on_stats_changed):
		GameState.player_stats_changed.connect(_on_stats_changed)

	setup_enhanced_hud()
	update_hud()
	
	await get_tree().create_timer(0.6).timeout
	start_player_turn()

func setup_enhanced_hud() -> void:
	var hud = get_node_or_null("../HUD") as CanvasLayer
	if not hud:
		return

	# Hide old text labels if they exist
	if hud_info_label:
		hud_info_label.visible = false
	if turn_label:
		turn_label.visible = false

	# Create a modern Top Bar Container for Player Score Cards
	var top_bar = HBoxContainer.new()
	top_bar.name = "PlayerTopBar"
	top_bar.custom_minimum_size = Vector2(0, 70)
	top_bar.anchors_preset = Control.PRESET_TOP_WIDE
	top_bar.offset_left = 20
	top_bar.offset_top = 15
	top_bar.offset_right = -20
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 20)
	hud.add_child(top_bar)

	# Build individual cards for each player
	player_hud_containers.clear()
	for p_data in GameState.player_data:
		var card = create_player_card(p_data)
		top_bar.add_child(card)
		player_hud_containers.append(card)

	# Round and Turn Banner in the Center-Top
	var banner_box = VBoxContainer.new()
	banner_box.name = "TurnBannerBox"
	banner_box.anchors_preset = Control.PRESET_TOP_WIDE
	banner_box.offset_top = 95
	banner_box.offset_bottom = 200
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(banner_box)

	var round_lbl = Label.new()
	round_lbl.name = "RoundBannerLabel"
	round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_lbl.add_theme_font_size_override("font_size", 18)
	round_lbl.modulate = Color(0.85, 0.85, 0.85)
	banner_box.add_child(round_lbl)

	var turn_lbl = Label.new()
	turn_lbl.name = "ActiveTurnLabel"
	turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_lbl.add_theme_font_size_override("font_size", 28)
	banner_box.add_child(turn_lbl)

	remaining_steps_label = Label.new()
	remaining_steps_label.name = "RemainingStepsLabel"
	remaining_steps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining_steps_label.add_theme_font_size_override("font_size", 24)
	remaining_steps_label.modulate = Color(1.0, 0.9, 0.2)
	remaining_steps_label.visible = false
	banner_box.add_child(remaining_steps_label)

	# Bottom-Center Interactive Roll Button
	var bottom_box = VBoxContainer.new()
	bottom_box.anchors_preset = Control.PRESET_BOTTOM_WIDE
	bottom_box.offset_bottom = -30
	bottom_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(bottom_box)

	roll_button = Button.new()
	roll_button.name = "RollButton"
	roll_button.text = "🎲 ROLL DIE (SPACEBAR)"
	roll_button.custom_minimum_size = Vector2(280, 52)
	roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	roll_button.add_theme_font_size_override("font_size", 20)
	roll_button.pressed.connect(_on_roll_button_pressed)
	bottom_box.add_child(roll_button)

func create_player_card(p_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.92)
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_color = p_data["color"]
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = "P%d %s %s" % [p_data["id"], p_data.get("icon", ""), p_data.get("major", "")]
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.modulate = p_data["color"]
	hbox.add_child(name_lbl)

	var stats_lbl = Label.new()
	stats_lbl.name = "StatsLabel"
	stats_lbl.text = "🪙 %d  ★ %d" % [p_data["coins"], p_data["stars"]]
	stats_lbl.add_theme_font_size_override("font_size", 18)
	hbox.add_child(stats_lbl)

	return panel

func update_hud() -> void:
	var hud = get_node_or_null("../HUD")
	if not hud:
		return

	# Update Top Bar Player Cards
	for i in range(GameState.player_data.size()):
		if i < player_hud_containers.size():
			var card = player_hud_containers[i]
			var p_data = GameState.player_data[i]
			
			var name_lbl = card.find_child("NameLabel", true, false) as Label
			if name_lbl:
				name_lbl.text = "P%d %s %s" % [p_data["id"], p_data.get("icon", ""), p_data.get("major", "")]
				name_lbl.modulate = p_data["color"]

			var stats_lbl = card.find_child("StatsLabel", true, false) as Label
			if stats_lbl:
				stats_lbl.text = "🪙 %d  ★ %d" % [p_data["coins"], p_data["stars"]]
				
			# Highlight active turn card with scale
			var is_active = (i == current_player_index)
			var target_scale = Vector2(1.08, 1.08) if is_active else Vector2(1.0, 1.0)
			var tw = card.create_tween()
			tw.tween_property(card, "scale", target_scale, 0.2)

	# Update Round & Turn text
	var round_lbl = hud.find_child("RoundBannerLabel", true, false) as Label
	if round_lbl:
		round_lbl.text = "ROUND %d / %d" % [GameState.current_round, GameState.max_rounds]

	var turn_lbl = hud.find_child("ActiveTurnLabel", true, false) as Label
	if turn_lbl and current_player_index < players.size():
		var active_p = players[current_player_index]
		var color = GameState.get_player_color(active_p.player_id)
		var p_name = GameState.get_player_name(active_p.player_id)
		turn_lbl.text = "Player %d's Turn! (%s)" % [active_p.player_id, p_name]
		turn_lbl.modulate = color

	if roll_button:
		roll_button.visible = true

func _on_stats_changed(_player_id: int) -> void:
	update_hud()

func _on_steps_updated(remaining: int) -> void:
	if remaining_steps_label:
		if remaining > 0:
			remaining_steps_label.visible = true
			remaining_steps_label.text = "Moving: %d steps remaining..." % remaining
		else:
			remaining_steps_label.visible = false

func start_player_turn() -> void:
	if players.is_empty():
		return

	if current_player_index >= players.size():
		end_of_round()
		return

	var active_player = players[current_player_index]
	update_hud()
	
	if remaining_steps_label:
		remaining_steps_label.visible = false

	if roll_button:
		roll_button.visible = true
		roll_button.disabled = false

	active_player.start_turn()

func _on_roll_button_pressed() -> void:
	if roll_button:
		roll_button.disabled = true
	if current_player_index < players.size():
		var active_p = players[current_player_index]
		if active_p.has_method("request_roll"):
			active_p.request_roll()

func _on_player_turn_finished() -> void:
	if roll_button:
		roll_button.visible = false

	current_player_index += 1
	
	if current_player_index >= players.size():
		end_of_round()
	else:
		start_player_turn()

func end_of_round() -> void:
	update_hud()
	if roll_button:
		roll_button.visible = false

	# Check if game has reached maximum rounds
	if GameState.current_round >= GameState.max_rounds:
		show_game_over_screen()
		return

	var hud = get_node_or_null("../HUD")
	var turn_lbl = hud.find_child("ActiveTurnLabel", true, false) as Label if hud else null
	if turn_lbl:
		turn_lbl.text = "ROUND COMPLETE!\nSelecting Minigame..."
		turn_lbl.modulate = Color.WHITE

	SoundManager.play_event()
	await get_tree().create_timer(2.2).timeout

	var minigame_scene = GameState.get_random_minigame()
	if minigame_scene == "":
		print("No minigame found, advancing round directly.")
		GameState.current_round += 1
		current_player_index = 0
		start_player_turn()
		return

	GameState.current_round += 1
	print("Switching to minigame scene: ", minigame_scene)
	get_tree().change_scene_to_file(minigame_scene)

func show_game_over_screen() -> void:
	SoundManager.play_star()
	var hud = get_node_or_null("../HUD")
	if not hud:
		return

	var overlay = ColorRect.new()
	overlay.name = "VictoryOverlay"
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.color = Color(0, 0, 0, 0.88)
	hud.add_child(overlay)

	var center_box = VBoxContainer.new()
	center_box.anchors_preset = Control.PRESET_CENTER
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 18)
	overlay.add_child(center_box)

	var title = Label.new()
	title.text = "🎓 GRADUATION DAY! 🏆"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(1.0, 0.88, 0.2)
	center_box.add_child(title)

	var ranked = GameState.get_ranked_players()
	var winner = ranked[0]
	
	var winner_lbl = Label.new()
	winner_lbl.text = "★ VALEDICTORIAN: PLAYER %d (%s) ★" % [winner["id"], GameState.get_player_name(winner["id"])]
	winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_lbl.add_theme_font_size_override("font_size", 28)
	winner_lbl.modulate = winner["color"]
	center_box.add_child(winner_lbl)

	# Rankings table
	for rank_idx in range(ranked.size()):
		var p = ranked[rank_idx]
		var rank_lbl = Label.new()
		rank_lbl.text = "#%d: P%d %s %s - %d Stars | %d Coins" % [
			rank_idx + 1,
			p["id"],
			p.get("icon", ""),
			p.get("major", ""),
			p["stars"],
			p["coins"]
		]
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.add_theme_font_size_override("font_size", 22)
		rank_lbl.modulate = p["color"]
		center_box.add_child(rank_lbl)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	center_box.add_child(btn_row)

	var restart_btn = Button.new()
	restart_btn.text = "🔄 Play Again"
	restart_btn.custom_minimum_size = Vector2(180, 48)
	restart_btn.add_theme_font_size_override("font_size", 20)
	restart_btn.pressed.connect(func():
		GameState.reset_game()
		get_tree().reload_current_scene()
	)
	btn_row.add_child(restart_btn)

	var menu_btn = Button.new()
	menu_btn.text = "🏠 Main Menu"
	menu_btn.custom_minimum_size = Vector2(180, 48)
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.pressed.connect(func():
		GameState.reset_game()
		get_tree().change_scene_to_file("res://MainMenu.tscn")
	)
	btn_row.add_child(menu_btn)

