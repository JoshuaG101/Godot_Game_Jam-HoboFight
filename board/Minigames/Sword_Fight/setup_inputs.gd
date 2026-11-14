@tool
extends EditorScript

func _run() -> void:
	# action name -> [player 1 key, player 2 key]
	var bindings := {
		"left": [KEY_A, KEY_LEFT],
		"right": [KEY_D, KEY_RIGHT],
		"up": [KEY_W, KEY_UP],
		"down": [KEY_S, KEY_DOWN],
		"attack": [KEY_F, KEY_COMMA],
		"deflect": [KEY_G, KEY_PERIOD],
	}

	for action in bindings:
		for player in [1, 2]:
			var action_name := "p%d_%s" % [player, action]
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action][player - 1]
			ProjectSettings.set_setting("input/" + action_name,
				{"deadzone": 0.5, "events": [event]})

	ProjectSettings.save()
	print("Input actions created.")
