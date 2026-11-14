extends CanvasLayer

# Drag the MatchManager node into this slot in the Inspector
@export var match_manager: MatchManager

@onready var label: Label = $Label


func _ready() -> void:
	label.visible = false
	match_manager.match_ended.connect(_on_match_ended)


func _on_match_ended(winner_id: int) -> void:
	if winner_id == -1:
		label.text = "Draw!\nPress R to restart"
	else:
		label.text = "Player %d wins!\nPress R to restart" % winner_id
	label.visible = true


# Testing convenience only. The larger game will decide what happens after a match.
func _unhandled_input(event: InputEvent) -> void:
	if label.visible and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
