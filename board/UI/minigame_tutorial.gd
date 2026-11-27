class_name MinigameTutorial
extends CanvasLayer

signal tutorial_finished

var minigame_title: String = "MINIGAME"
var objective_text: String = "Objective description"
var player_controls: Array[Dictionary] = [] # [{ "player": "Player 1", "color": Color(...), "controls": [["Move", "WASD"], ...] }]
var general_tips: Array[String] = []
var countdown_seconds: int = 5

var _countdown_timer: float = 0.0
var _counting: bool = false
var _ready_button: Button
var _countdown_label: Label
var _is_dismissed: bool = false


func _ready() -> void:
	layer = 120 # Above game HUDs and elements
	process_mode = Node.PROCESS_MODE_ALWAYS # Can work even if tree is paused
	_build_ui()


func setup(
	p_title: String,
	p_objective: String,
	p_player_controls: Array[Dictionary],
	p_tips: Array[String] = [],
	p_countdown: int = 6
) -> void:
	minigame_title = p_title
	objective_text = p_objective
	player_controls = p_player_controls
	general_tips = p_tips
	countdown_seconds = p_countdown
	_countdown_timer = float(p_countdown)


func start_tutorial() -> void:
	_countdown_timer = float(countdown_seconds)
	_counting = true
	_update_countdown_display()


func _process(delta: float) -> void:
	if _counting and not _is_dismissed:
		_countdown_timer -= delta
		_update_countdown_display()
		if _countdown_timer <= 0.0:
			dismiss()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dismissed:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		dismiss()
		get_viewport().set_input_as_handled()


func dismiss() -> void:
	if _is_dismissed:
		return
	_is_dismissed = true
	_counting = false
	var tween = create_tween()
	tween.tween_property(self, "offset:y", -720.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		tutorial_finished.emit()
		queue_free()
	)


func _update_countdown_display() -> void:
	if _countdown_label:
		var secs: int = int(ceil(maxf(_countdown_timer, 0.0)))
		_countdown_label.text = "Starting in %d... (Press SPACE / ENTER / Ready)" % secs


func _build_ui() -> void:
	# Dark semi-transparent background
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.12, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(main_vbox)

	# --- Header: Title & Objective ---
	var title_lbl = Label.new()
	title_lbl.text = "HOW TO PLAY: %s" % minigame_title.to_upper()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 34)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 0.9))
	title_lbl.add_theme_constant_override("outline_size", 8)
	main_vbox.add_child(title_lbl)

	var obj_panel = PanelContainer.new()
	var obj_style = StyleBoxFlat.new()
	obj_style.bg_color = Color(0.12, 0.18, 0.28, 0.85)
	obj_style.set_corner_radius_all(10)
	obj_style.content_margin_left = 16
	obj_style.content_margin_right = 16
	obj_style.content_margin_top = 8
	obj_style.content_margin_bottom = 8
	obj_panel.add_theme_stylebox_override("panel", obj_style)
	main_vbox.add_child(obj_panel)

	var obj_lbl = Label.new()
	obj_lbl.text = "🎯 Objective: %s" % objective_text
	obj_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_lbl.add_theme_font_size_override("font_size", 18)
	obj_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	obj_panel.add_child(obj_lbl)

	# --- Player Controls Grid / Row ---
	var controls_hbox = HBoxContainer.new()
	controls_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_hbox.add_theme_constant_override("separation", 14)
	controls_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(controls_hbox)

	for p_info in player_controls:
		var p_name: String = p_info.get("player", "Player")
		var p_color: Color = p_info.get("color", Color.WHITE)
		var p_rows: Array = p_info.get("controls", [])

		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.08, 0.12, 0.2, 0.88)
		card_style.border_width_top = 4
		card_style.border_color = p_color
		card_style.set_corner_radius_all(8)
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 10
		card_style.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", card_style)
		controls_hbox.add_child(card)

		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 8)
		card.add_child(card_vbox)

		var p_header = Label.new()
		p_header.text = p_name
		p_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_header.add_theme_font_size_override("font_size", 20)
		p_header.add_theme_color_override("font_color", p_color)
		card_vbox.add_child(p_header)

		var sep = HSeparator.new()
		card_vbox.add_child(sep)

		for ctrl in p_rows:
			var row = HBoxContainer.new()
			var act_lbl = Label.new()
			act_lbl.text = str(ctrl[0])
			act_lbl.add_theme_font_size_override("font_size", 15)
			act_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
			act_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(act_lbl)

			var key_panel = PanelContainer.new()
			var key_style = StyleBoxFlat.new()
			key_style.bg_color = Color(0.18, 0.25, 0.38, 0.95)
			key_style.set_corner_radius_all(6)
			key_style.content_margin_left = 8
			key_style.content_margin_right = 8
			key_style.content_margin_top = 3
			key_style.content_margin_bottom = 3
			key_panel.add_theme_stylebox_override("panel", key_style)
			
			var key_lbl = Label.new()
			key_lbl.text = str(ctrl[1])
			key_lbl.add_theme_font_size_override("font_size", 14)
			key_lbl.add_theme_color_override("font_color", Color.WHITE)
			key_panel.add_child(key_lbl)

			row.add_child(key_panel)
			card_vbox.add_child(row)

	# --- Tips Section (if any) ---
	if general_tips.size() > 0:
		var tips_panel = PanelContainer.new()
		var tips_style = StyleBoxFlat.new()
		tips_style.bg_color = Color(0.06, 0.09, 0.16, 0.75)
		tips_style.set_corner_radius_all(6)
		tips_style.content_margin_left = 12
		tips_style.content_margin_right = 12
		tips_style.content_margin_top = 6
		tips_style.content_margin_bottom = 6
		tips_panel.add_theme_stylebox_override("panel", tips_style)
		main_vbox.add_child(tips_panel)

		var tips_vbox = VBoxContainer.new()
		tips_panel.add_child(tips_vbox)

		for tip in general_tips:
			var tip_lbl = Label.new()
			tip_lbl.text = "💡 " + tip
			tip_lbl.add_theme_font_size_override("font_size", 14)
			tip_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 0.95))
			tips_vbox.add_child(tip_lbl)

	# --- Bottom Bar: Countdown & Ready Button ---
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(bottom_hbox)

	_countdown_label = Label.new()
	_countdown_label.add_theme_font_size_override("font_size", 18)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	bottom_hbox.add_child(_countdown_label)
	_update_countdown_display()

	_ready_button = Button.new()
	_ready_button.text = "  Ready! (Start Now)  "
	_ready_button.custom_minimum_size = Vector2(180, 42)
	_ready_button.add_theme_font_size_override("font_size", 18)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.65, 0.35)
	btn_style.set_corner_radius_all(8)
	_ready_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.26, 0.8, 0.42)
	btn_hover.set_corner_radius_all(8)
	_ready_button.add_theme_stylebox_override("hover", btn_hover)
	_ready_button.pressed.connect(dismiss)
	bottom_hbox.add_child(_ready_button)
