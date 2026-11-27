extends CanvasLayer

# Drag the MatchManager node into this slot in the Inspector
@export var match_manager: MatchManager

@onready var label: Label = $Label


func _ready() -> void:
	label.visible = false
	match_manager.match_ended.connect(_on_match_ended)


func _on_match_ended(winner_id: int) -> void:
	if winner_id == -1:
		label.text = "Draw!\nReturning to Board..."
	else:
		var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
		if gs:
			gs.award_coins(winner_id, 7)
		var p_name = gs.get_player_name(winner_id) if gs else ("Player %d" % winner_id)
		label.text = "%s wins!\n(+7 Coins Awarded!)\nReturning to Board..." % p_name
	label.visible = true
	
	# Automatically transition back to board after match ends
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://Board/Board.tscn")


# Testing convenience only. The larger game will decide what happens after a match.
func _unhandled_input(event: InputEvent) -> void:
	if label.visible and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
