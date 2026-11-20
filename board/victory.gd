extends Node

# last player standing wins. fall off the summit and you're out.

const DEATH_Y = -10.0

var win_label
var winner = null

func _ready():
	var layer = CanvasLayer.new()
	add_child(layer)

	win_label = Label.new()
	win_label.add_theme_font_size_override("font_size", 72)
	win_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_label.hide()
	layer.add_child(win_label)

func _process(_delta):
	if winner:
		return

	var alive = []
	for p in get_tree().get_nodes_in_group("players"):
		if p.global_position.y < DEATH_Y:
			p.hide()
		else:
			alive.append(p)

	if alive.size() == 1:
		win(alive[0])

func win(player):
	winner = player

	# slow mo
	Engine.time_scale = 0.3

	# camera moves in on them
	var cam = get_viewport().get_camera_3d()
	if cam:
		cam.look_at(player.global_position, Vector3.UP)
		var spot = player.global_position + Vector3(0, 1.5, 4)
		create_tween().tween_property(cam, "global_position", spot, 1.5)

	# text
	win_label.text = player.name + " WINS!\nReturning to Board..."
	win_label.show()

	await get_tree().create_timer(3.0, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://Board/Board.tscn")
