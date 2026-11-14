extends Control

@onready var player_slots_box: HBoxContainer = $MarginContainer/VBox/PlayerSlotsContainer
@onready var majors_grid: GridContainer = $MarginContainer/VBox/MajorsGrid
@onready var start_btn: Button = $MarginContainer/VBox/BottomBar/StartButton
@onready var random_btn: Button = $MarginContainer/VBox/BottomBar/RandomButton
@onready var back_btn: Button = $MarginContainer/VBox/BottomBar/BackButton
@onready var prompt_lbl: Label = $MarginContainer/VBox/Header/PromptLabel

var active_player_id: int = 1
var player_cards: Dictionary = {}
var major_card_buttons: Dictionary = {}

func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	random_btn.pressed.connect(_on_randomize_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	build_player_slots()
	build_majors_grid()
	update_ui()

func build_player_slots() -> void:
	for child in player_slots_box.get_children():
		child.queue_free()
	player_cards.clear()

	for p in GameState.player_data:
		var pid = p["id"]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(240, 75)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			SoundManager.play_click()
			active_player_id = pid
			update_ui()
		)
		player_slots_box.add_child(btn)
		player_cards[pid] = btn

func build_majors_grid() -> void:
	for child in majors_grid.get_children():
		child.queue_free()
	major_card_buttons.clear()

	var majors = GameState.get_available_majors()
	for m in majors:
		var card = Button.new()
		card.custom_minimum_size = Vector2(340, 110)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var vbox = VBoxContainer.new()
		vbox.anchors_preset = Control.PRESET_FULL_RECT
		vbox.offset_left = 15
		vbox.offset_top = 10
		vbox.offset_right = -15
		vbox.offset_bottom = -10
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.theme_override_constants.separation = 4
		card.add_child(vbox)

		var title_row = HBoxContainer.new()
		title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(title_row)

		var title = Label.new()
		title.text = "%s  %s" % [m["icon"], m["name"]]
		title.add_theme_font_size_override("font_size", 20)
		title.modulate = m["color"]
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(title)

		var tagline = Label.new()
		tagline.text = m["tagline"]
		tagline.add_theme_font_size_override("font_size", 14)
		tagline.modulate = Color(0.85, 0.88, 0.95, 0.85)
		tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tagline)

		var m_id = m["id"]
		card.pressed.connect(func():
			SoundManager.play_hop()
			GameState.set_player_major(active_player_id, m_id)
			# Automatically advance to next player slot for convenience
			active_player_id = (active_player_id % GameState.player_data.size()) + 1
			update_ui()
		)
		majors_grid.add_child(card)
		major_card_buttons[m_id] = card

func update_ui() -> void:
	# Update player slot cards
	for p in GameState.player_data:
		var pid = p["id"]
		var btn = player_cards.get(pid) as Button
		if not btn:
			continue
		
		var is_selected = (pid == active_player_id)
		var prefix = "▶ " if is_selected else ""
		btn.text = "%sPlayer %d\n%s %s" % [prefix, pid, p.get("icon", ""), p.get("major", "")]
		btn.modulate = p["color"] if not is_selected else Color(1.2, 1.2, 1.2)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.15, 0.22, 0.9)
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.border_width_bottom = 3 if is_selected else 1
		style.border_width_top = 3 if is_selected else 1
		style.border_width_left = 3 if is_selected else 1
		style.border_width_right = 3 if is_selected else 1
		style.border_color = Color.WHITE if is_selected else p["color"]
		btn.add_theme_stylebox_override("normal", style)

	# Update active prompt label
	if prompt_lbl:
		var p_name = GameState.get_player_name(active_player_id)
		var p_color = GameState.get_player_color(active_player_id)
		prompt_lbl.text = "Selecting Major for Player %d (Currently: %s)" % [active_player_id, p_name]
		prompt_lbl.modulate = p_color

	# Highlight which major is chosen for active player
	var current_major_id = ""
	for p in GameState.player_data:
		if p["id"] == active_player_id:
			current_major_id = p.get("major_id", "")
			break

	for m_id in major_card_buttons:
		var card = major_card_buttons[m_id] as Button
		var is_current = (m_id == current_major_id)
		var m_info = GameState.get_major_by_id(m_id)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.13, 0.18, 0.95)
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.border_width_bottom = 3 if is_current else 1
		style.border_width_top = 3 if is_current else 1
		style.border_width_left = 3 if is_current else 1
		style.border_width_right = 3 if is_current else 1
		style.border_color = Color.WHITE if is_current else m_info["color"]
		card.add_theme_stylebox_override("normal", style)

func _on_randomize_pressed() -> void:
	SoundManager.play_roll()
	GameState.randomize_all_majors()
	update_ui()

func _on_back_pressed() -> void:
	SoundManager.play_click()
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_start_pressed() -> void:
	SoundManager.play_star()
	GameState.reset_game()
	get_tree().change_scene_to_file("res://Board/Board.tscn")
