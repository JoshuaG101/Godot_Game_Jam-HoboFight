extends Control

@onready var play_btn: Button = $VBoxContainer/PlayButton
@onready var how_to_play_btn: Button = $VBoxContainer/HowToPlayButton
@onready var rounds_btn: Button = $VBoxContainer/RoundsButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton
@onready var rules_modal: Control = $RulesModal
@onready var close_rules_btn: Button = $RulesModal/Panel/CloseButton

var round_options: Array[int] = [3, 5, 10]
var current_round_idx: int = 1 # default 5 rounds

func _ready() -> void:
	GameState.max_rounds = round_options[current_round_idx]
	update_rounds_button_text()

	play_btn.pressed.connect(_on_play_pressed)
	how_to_play_btn.pressed.connect(_on_how_to_play_pressed)
	rounds_btn.pressed.connect(_on_rounds_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	close_rules_btn.pressed.connect(_on_close_rules_pressed)
	
	rules_modal.visible = false

func _on_play_pressed() -> void:
	SoundManager.play_click()
	get_tree().change_scene_to_file("res://CharacterSelect.tscn")

func _on_how_to_play_pressed() -> void:
	SoundManager.play_click()
	rules_modal.visible = true

func _on_close_rules_pressed() -> void:
	SoundManager.play_click()
	rules_modal.visible = false

func _on_rounds_pressed() -> void:
	SoundManager.play_click()
	current_round_idx = (current_round_idx + 1) % round_options.size()
	GameState.max_rounds = round_options[current_round_idx]
	update_rounds_button_text()

func update_rounds_button_text() -> void:
	rounds_btn.text = "⏱️ MATCH LENGTH: %d ROUNDS" % GameState.max_rounds

func _on_quit_pressed() -> void:
	SoundManager.play_click()
	get_tree().quit()
