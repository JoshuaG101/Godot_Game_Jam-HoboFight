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
var pause_menu: Control = null
var pause_bg: ColorRect = null
var pause_center_box: CenterContainer = null
var camera: Camera3D = null
var base_cam_offset: Vector3 = Vector3.ZERO
var initial_cam_pos: Vector3 = Vector3.ZERO
var star_tiles: Array[BoardNode3D] = []
var active_star_tile: BoardNode3D = null

func _ready() -> void:
	SoundManager.play_music(SoundManager.music_bosanova, 0.0)
	init_star_spaces()
	camera = get_node_or_null("../Camera3D") as Camera3D
	if camera:
		initial_cam_pos = camera.global_position

	# Ensure starting space fallback for players matches the new BoardMap
	var start_tile = get_node_or_null("../BoardMap/marioPartyTiles")
	if not start_tile:
		start_tile = get_node_or_null("../Node/marioPartyTiles")

	# Find players if not manually populated
	if players.is_empty():
		var found = get_tree().get_nodes_in_group("players")
		for node in found:
			if node is Node3D:
				players.append(node)

	# Sort players by player_id
	players.sort_custom(func(a, b): return a.player_id < b.player_id)

	# Connect signals and assign default space if needed
	for p in players:
		if not p.current_space and start_tile:
			p.current_space = start_tile
			p.global_position = start_tile.global_position + p.get_tile_offset()

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

func _process(delta: float) -> void:
	# Smoothly follow the active player a little bit
	if camera and current_player_index < players.size():
		var active_p = players[current_player_index]
		if active_p and is_instance_valid(active_p):
			# Follow player subtly with slight offset bias (weighted 35% towards player)
			var target_cam_pos = initial_cam_pos + (active_p.global_position * 0.35)
			camera.global_position = camera.global_position.lerp(target_cam_pos, delta * 3.0)

func setup_enhanced_hud() -> void:
	var hud = get_node_or_null("../HUD") as CanvasLayer
	if not hud:
		return

	# Hide old text labels if they exist
	if hud_info_label:
		hud_info_label.visible = false
	if turn_label:
		turn_label.visible = false

	# 1. Left-Side Vertical Container for Player Score Cards (P1, P2, P3, P4)
	var left_bar = VBoxContainer.new()
	left_bar.name = "PlayerLeftBar"
	left_bar.anchors_preset = Control.PRESET_LEFT_WIDE
	left_bar.offset_left = 24
	left_bar.offset_top = 24
	left_bar.offset_bottom = -24
	left_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	left_bar.add_theme_constant_override("separation", 14)
	hud.add_child(left_bar)

	# Build individual cards for each player
	player_hud_containers.clear()
	for p_data in GameState.player_data:
		var card = create_player_card(p_data)
		left_bar.add_child(card)
		player_hud_containers.append(card)

	# 2. Top-Right Box for Round & Player Turn (with sleek frosted container box)
	var top_right_container = PanelContainer.new()
	top_right_container.name = "TopRightPanel"
	top_right_container.anchors_preset = Control.PRESET_TOP_RIGHT
	top_right_container.offset_top = 20
	top_right_container.offset_right = -24
	top_right_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var box_style = StyleBoxFlat.new()
	box_style.bg_color = Color(0.08, 0.11, 0.18, 0.92)
	box_style.corner_radius_top_left = 14
	box_style.corner_radius_top_right = 14
	box_style.corner_radius_bottom_left = 14
	box_style.corner_radius_bottom_right = 14
	box_style.border_width_left = 2
	box_style.border_width_top = 2
	box_style.border_width_right = 2
	box_style.border_width_bottom = 2
	box_style.border_color = Color(0.35, 0.65, 0.95, 0.75)
	box_style.shadow_color = Color(0, 0, 0, 0.45)
	box_style.shadow_size = 10
	box_style.content_margin_left = 22
	box_style.content_margin_right = 22
	box_style.content_margin_top = 10
	box_style.content_margin_bottom = 12
	top_right_container.add_theme_stylebox_override("panel", box_style)
	hud.add_child(top_right_container)

	var banner_box = VBoxContainer.new()
	banner_box.name = "TurnBannerBox"
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.add_theme_constant_override("separation", 4)
	top_right_container.add_child(banner_box)

	var round_lbl = Label.new()
	round_lbl.name = "RoundBannerLabel"
	round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_lbl.add_theme_font_size_override("font_size", 16)
	round_lbl.modulate = Color(0.55, 0.85, 1.0)
	banner_box.add_child(round_lbl)

	var turn_lbl = Label.new()
	turn_lbl.name = "ActiveTurnLabel"
	turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_lbl.add_theme_font_size_override("font_size", 22)
	banner_box.add_child(turn_lbl)

	remaining_steps_label = Label.new()
	remaining_steps_label.name = "RemainingStepsLabel"
	remaining_steps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining_steps_label.add_theme_font_size_override("font_size", 18)
	remaining_steps_label.modulate = Color(1.0, 0.92, 0.3)
	remaining_steps_label.visible = false
	banner_box.add_child(remaining_steps_label)

	setup_pause_menu()

	# 3. Bottom-Center Interactive Roll Button
	var bottom_box = CenterContainer.new()
	bottom_box.anchors_preset = Control.PRESET_CENTER_BOTTOM
	bottom_box.offset_bottom = -30
	bottom_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(bottom_box)

	roll_button = Button.new()
	roll_button.name = "RollButton"
	roll_button.text = "🎲 ROLL DIE (SPACEBAR)"
	roll_button.custom_minimum_size = Vector2(300, 56)
	roll_button.add_theme_font_size_override("font_size", 20)
	
	# Custom gradient glass style for roll button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.2, 0.35, 0.92)
	btn_style.corner_radius_top_left = 16
	btn_style.corner_radius_top_right = 16
	btn_style.corner_radius_bottom_left = 16
	btn_style.corner_radius_bottom_right = 16
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 3
	btn_style.border_color = Color(0.4, 0.8, 1.0, 0.9)
	btn_style.shadow_color = Color(0, 0.5, 1.0, 0.35)
	btn_style.shadow_size = 12
	roll_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.18, 0.3, 0.5, 0.95)
	btn_hover.border_color = Color(0.6, 0.95, 1.0, 1.0)
	btn_hover.shadow_size = 18
	roll_button.add_theme_stylebox_override("hover", btn_hover)

	roll_button.pressed.connect(_on_roll_button_pressed)
	bottom_box.add_child(roll_button)

func create_player_card(p_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(210, 68)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.16, 0.88)
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_color = p_data["color"] * 0.7
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var icon_badge = Label.new()
	icon_badge.text = p_data.get("icon", "🎓")
	icon_badge.add_theme_font_size_override("font_size", 24)
	hbox.add_child(icon_badge)

	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = "P%d %s" % [p_data["id"], p_data.get("major", "")]
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.modulate = p_data["color"]
	info_vbox.add_child(name_lbl)

	var stats_lbl = Label.new()
	stats_lbl.name = "StatsLabel"
	stats_lbl.text = "🪙 %d  ★ %d" % [p_data["coins"], p_data["stars"]]
	stats_lbl.add_theme_font_size_override("font_size", 15)
	stats_lbl.modulate = Color(0.9, 0.9, 0.9)
	info_vbox.add_child(stats_lbl)

	return panel

func setup_pause_menu() -> void:
	var hud = get_node_or_null("../HUD")
	if not hud:
		return

	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(pause_menu)
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_menu.grow_vertical = Control.GROW_DIRECTION_BOTH

	# Dim background overlay
	pause_bg = ColorRect.new()
	pause_bg.color = Color(0, 0, 0, 0.75)
	pause_menu.add_child(pause_bg)
	pause_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_bg.grow_vertical = Control.GROW_DIRECTION_BOTH

	# Center Dialog Box
	pause_center_box = CenterContainer.new()
	pause_menu.add_child(pause_center_box)
	pause_center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_center_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_center_box.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 420)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.12, 0.18, 0.96)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.35, 0.65, 0.95, 0.8)
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 20
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", panel_style)
	pause_center_box.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "⏸️ PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(1.0, 0.88, 0.2)
	vbox.add_child(title)

	# Volume Section
	var vol_box = VBoxContainer.new()
	vol_box.add_theme_constant_override("separation", 6)
	vbox.add_child(vol_box)

	var vol_label = Label.new()
	vol_label.text = "🔊 Master Volume: %d%%" % int(SoundManager.get_volume() * 100)
	vol_label.add_theme_font_size_override("font_size", 16)
	vol_label.modulate = Color(0.85, 0.9, 1.0)
	vol_box.add_child(vol_label)

	var vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = SoundManager.get_volume()
	vol_slider.value_changed.connect(func(val: float):
		SoundManager.set_volume(val)
		vol_label.text = "🔊 Master Volume: %d%%" % int(val * 100)
	)
	vol_box.add_child(vol_slider)

	vbox.add_child(HSeparator.new())

	# Button Style helper
	var create_btn = func(text: String, color_accent: Color) -> Button:
		var btn = Button.new()
		btn.text = text
		btn.custom_minimum_size = Vector2(0, 46)
		btn.add_theme_font_size_override("font_size", 18)
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = Color(0.14, 0.18, 0.26, 0.9)
		b_style.corner_radius_top_left = 10
		b_style.corner_radius_top_right = 10
		b_style.corner_radius_bottom_left = 10
		b_style.corner_radius_bottom_right = 10
		b_style.border_width_left = 1
		b_style.border_width_top = 1
		b_style.border_width_right = 1
		b_style.border_width_bottom = 1
		b_style.border_color = color_accent * 0.7
		btn.add_theme_stylebox_override("normal", b_style)
		var h_style = b_style.duplicate()
		h_style.bg_color = Color(0.2, 0.26, 0.38, 0.95)
		h_style.border_color = color_accent
		btn.add_theme_stylebox_override("hover", h_style)
		return btn

	# Resume Button
	var resume_btn = create_btn.call("▶️ Resume", Color(0.3, 0.8, 1.0))
	resume_btn.pressed.connect(toggle_pause)
	vbox.add_child(resume_btn)

	# Main Menu Button
	var menu_btn = create_btn.call("🏠 Main Menu", Color(1.0, 0.8, 0.2))
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		GameState.reset_game()
		get_tree().change_scene_to_file("res://UI/MainMenu.tscn")
	)
	vbox.add_child(menu_btn)

	# Exit Game Button
	var exit_btn = create_btn.call("🚪 Exit Game", Color(1.0, 0.35, 0.35))
	exit_btn.pressed.connect(func():
		get_tree().quit()
	)
	vbox.add_child(exit_btn)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle_pause()

func toggle_pause() -> void:
	if not pause_menu:
		return
	var is_open = not pause_menu.visible
	if is_open:
		_update_pause_layout()
	pause_menu.visible = is_open
	get_tree().paused = is_open

func _update_pause_layout() -> void:
	if not pause_menu:
		return
	var vp_size = get_viewport().get_visible_rect().size
	pause_menu.position = Vector2.ZERO
	pause_menu.size = vp_size
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if pause_bg:
		pause_bg.position = Vector2.ZERO
		pause_bg.size = vp_size
		pause_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if pause_center_box:
		pause_center_box.position = Vector2.ZERO
		pause_center_box.size = vp_size
		pause_center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
				name_lbl.text = "P%d %s" % [p_data["id"], p_data.get("major", "")]
				name_lbl.modulate = p_data["color"]

			var stats_lbl = card.find_child("StatsLabel", true, false) as Label
			if stats_lbl:
				stats_lbl.text = "🪙 %d  ★ %d" % [p_data["coins"], p_data["stars"]]
				
			# Highlight active turn card with border glow and subtle scale
			var is_active = (i == current_player_index)
			var target_scale = Vector2(1.08, 1.08) if is_active else Vector2(1.0, 1.0)
			var tw = card.create_tween()
			tw.tween_property(card, "scale", target_scale, 0.2)

			var style = card.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				if is_active:
					style.border_color = p_data["color"] * 1.5
					style.border_width_bottom = 3
					style.border_width_top = 3
					style.border_width_left = 3
					style.border_width_right = 3
					style.shadow_color = p_data["color"] * 0.6
					style.shadow_size = 12
				else:
					style.border_color = p_data["color"] * 0.5
					style.border_width_bottom = 2
					style.border_width_top = 2
					style.border_width_left = 2
					style.border_width_right = 2
					style.shadow_color = Color(0, 0, 0, 0.4)
					style.shadow_size = 6

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
		roll_button.visible = false
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
	SoundManager.stop_music()
	get_tree().change_scene_to_file(minigame_scene)

func init_star_spaces() -> void:
	star_tiles.clear()
	var board_map = get_node_or_null("../BoardMap")
	if board_map:
		for child in board_map.get_children():
			if child is BoardNode3D and child.space_type == BoardNode3D.SpaceType.STAR:
				star_tiles.append(child)
				child.set_star_active(false)
	relocate_star()

func relocate_star() -> void:
	if star_tiles.is_empty():
		return
	if active_star_tile:
		active_star_tile.set_star_active(false)
	
	var candidates: Array[BoardNode3D] = []
	for st in star_tiles:
		if st != active_star_tile:
			candidates.append(st)
	if candidates.is_empty():
		candidates = star_tiles
	
	active_star_tile = candidates.pick_random()
	active_star_tile.set_star_active(true)
	active_star_tile.pulse()
	print("[TurnManager] Star is now active on: ", active_star_tile.name)

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
		get_tree().change_scene_to_file("res://UI/MainMenu.tscn")
	)
	btn_row.add_child(menu_btn)
