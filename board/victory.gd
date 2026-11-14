extends Node

# Last player standing wins. Fall off the map and you're out.

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

	_demo()


# TEMP: gives the test scene a floor and a visible player. delete later.
func _demo():
	var root = get_tree().current_scene

	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	root.add_child(ground)

	var solid = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	col.shape = box
	solid.add_child(col)
	solid.position = Vector3(0, -0.5, 0)
	root.add_child(solid)

	for p in root.get_children():
		if p is CharacterBody3D:
			p.add_to_group("players")
			var body = MeshInstance3D.new()
			body.mesh = CapsuleMesh.new()
			p.add_child(body)

	var cam = get_viewport().get_camera_3d()
	if cam:
		cam.position = Vector3(0, 3, 12)


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
	win_label.text = player.name + " WINS!"
	win_label.show()

	await get_tree().create_timer(3.0, true, false, true).timeout
	Engine.time_scale = 1.0
