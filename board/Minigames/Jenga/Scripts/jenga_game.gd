extends Node3D

const BLOCK_SCENE: PackedScene = preload(
	"res://Minigames/Jenga/Scenes/jenga_block.tscn"
)

const BLOCK_LENGTH: float = 1.5
const BLOCK_WIDTH: float = 0.5
const BLOCK_HEIGHT: float = 0.5
const BLOCK_GAP: float = 0.025

const LAYER_COUNT: int = 8
const BLOCKS_PER_LAYER: int = 3
const PLAYER_COUNT: int = 4

var current_player: int = 1
var selected_block: RigidBody3D = null
var hovered_block: RigidBody3D = null

var active_players: Array[int] = [1, 2, 3, 4]
var is_checking_collapse: bool = false
var game_over: bool = false

# Orbit camera parameters
var cam_target: Vector3 = Vector3(0, 2.0, 0)
var cam_distance: float = 8.5
var cam_yaw: float = 0.8
var cam_pitch: float = 0.45
var is_dragging_cam: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

var place_button: Button = null

func _ready() -> void:
	update_camera_transform()
	build_tower()
	setup_hud()
	update_turn_label()

func update_camera_transform() -> void:
	var cam: Camera3D = $Camera3D
	if not cam:
		return
	var offset = Vector3(
		cam_distance * cos(cam_pitch) * sin(cam_yaw),
		cam_distance * sin(cam_pitch),
		cam_distance * cos(cam_pitch) * cos(cam_yaw)
	)
	cam.global_position = cam_target + offset
	cam.look_at(cam_target, Vector3.UP)

func build_tower() -> void:
	var spacing: float = BLOCK_WIDTH + BLOCK_GAP

	for layer in range(LAYER_COUNT):
		for i in range(BLOCKS_PER_LAYER):
			var block = BLOCK_SCENE.instantiate() as RigidBody3D
			add_child(block)

			block.set_meta("tower_layer", layer)
			block.set_meta("tower_slot", i)

			block.position.y = BLOCK_HEIGHT / 2.0
			block.position.y += layer * (BLOCK_HEIGHT + BLOCK_GAP)

			if layer % 2 == 0:
				block.position.x = 0.0
				block.position.z = (i - 1) * spacing
				block.rotation.y = 0.0
			else:
				block.position.x = (i - 1) * spacing
				block.position.z = 0.0
				block.rotation.y = PI / 2.0

func setup_hud() -> void:
	var hud = $HUD
	if not hud:
		return

	# Style the existing TurnLabel
	var turn_lbl = $HUD/TurnLabel as Label
	if turn_lbl:
		turn_lbl.position = Vector2(30, 25)
		turn_lbl.add_theme_font_size_override("font_size", 26)

	# Instructions Banner
	var help_lbl = Label.new()
	help_lbl.name = "HelpLabel"
	help_lbl.text = "🖱️ Left Click: Select Block | ⌨️ E: Place on Top | 🖱️ Right Click Drag / A-D: Rotate Camera"
	help_lbl.position = Vector2(30, 70)
	help_lbl.add_theme_font_size_override("font_size", 16)
	help_lbl.modulate = Color(0.8, 0.8, 0.8, 0.9)
	hud.add_child(help_lbl)

	# Active Players List
	var player_box = HBoxContainer.new()
	player_box.name = "ActivePlayerBox"
	player_box.position = Vector2(30, 105)
	player_box.add_theme_constant_override("separation", 15)
	hud.add_child(player_box)

	# Place Block Button
	place_button = Button.new()
	place_button.name = "PlaceButton"
	place_button.text = "⬆️ PLACE ON TOP (E)"
	place_button.custom_minimum_size = Vector2(240, 50)
	place_button.anchors_preset = Control.PRESET_BOTTOM_WIDE
	place_button.offset_bottom = -30
	place_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	place_button.add_theme_font_size_override("font_size", 18)
	place_button.visible = false
	place_button.pressed.connect(place_selected_block)
	hud.add_child(place_button)

func _process(delta: float) -> void:
	# Continuous keyboard camera rotation
	var rotate_input = Input.get_axis("ui_left", "ui_right")
	if rotate_input != 0.0:
		cam_yaw += rotate_input * delta * 2.0
		update_camera_transform()

func _input(event: InputEvent) -> void:
	if game_over:
		return

	# Camera Orbit with Right Mouse Button
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging_cam = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_distance = clampf(cam_distance - 0.6, 4.5, 15.0)
			update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_distance = clampf(cam_distance + 0.6, 4.5, 15.0)
			update_camera_transform()

	if event is InputEventMouseMotion:
		if is_dragging_cam:
			var diff = event.position - last_mouse_pos
			last_mouse_pos = event.position
			cam_yaw -= diff.x * 0.008
			cam_pitch = clampf(cam_pitch + diff.y * 0.008, 0.1, 1.4)
			update_camera_transform()
		else:
			update_hovered_block(event.position)

	if is_checking_collapse:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			select_block_at_mouse(event.position)

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_E:
				place_selected_block()

func update_hovered_block(mouse_position: Vector2) -> void:
	if is_checking_collapse or game_over:
		return
	var hit_block = raycast_block_at(mouse_position)
	if hit_block != hovered_block:
		if is_instance_valid(hovered_block) and hovered_block.has_method("set_hovered"):
			hovered_block.set_hovered(false)
		hovered_block = hit_block
		if is_instance_valid(hovered_block) and hovered_block.has_method("set_hovered"):
			hovered_block.set_hovered(true)

func raycast_block_at(mouse_position: Vector2) -> RigidBody3D:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return null
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_dir = camera.project_ray_normal(mouse_position)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 1000.0)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit["collider"] is RigidBody3D and hit["collider"].is_in_group("jenga_blocks"):
		return hit["collider"] as RigidBody3D
	return null

func select_block_at_mouse(mouse_position: Vector2) -> void:
	var block = raycast_block_at(mouse_position)
	if block:
		clear_selection()
		selected_block = block
		selected_block.set_selected(true)
		SoundManager.play_hop()
		if place_button:
			place_button.visible = true
	else:
		clear_selection()

func clear_selection() -> void:
	if is_instance_valid(selected_block):
		selected_block.set_selected(false)
	selected_block = null
	if place_button:
		place_button.visible = false

func place_selected_block() -> void:
	if not is_instance_valid(selected_block):
		return

	var blocks: Array = get_tree().get_nodes_in_group("jenga_blocks")
	var highest_layer: int = 0

	for block in blocks:
		if block == selected_block:
			continue
		var layer: int = int(block.get_meta("tower_layer", 0))
		highest_layer = maxi(highest_layer, layer)

	var occupied_slots: Array[bool] = [false, false, false]
	for block in blocks:
		if block == selected_block:
			continue
		var layer: int = int(block.get_meta("tower_layer", 0))
		if layer != highest_layer:
			continue
		var slot: int = int(block.get_meta("tower_slot", -1))
		if slot >= 0 and slot < BLOCKS_PER_LAYER:
			occupied_slots[slot] = true

	var destination_layer: int = highest_layer
	var destination_slot: int = -1

	for i in range(BLOCKS_PER_LAYER):
		if not occupied_slots[i]:
			destination_slot = i
			break

	if destination_slot == -1:
		destination_layer += 1
		destination_slot = 0

	var spacing: float = BLOCK_WIDTH + BLOCK_GAP
	var destination_height: float = BLOCK_HEIGHT / 2.0 + destination_layer * (BLOCK_HEIGHT + BLOCK_GAP)

	# Sound effect and placement
	SoundManager.play_roll()
	selected_block.freeze = true
	selected_block.linear_velocity = Vector3.ZERO
	selected_block.angular_velocity = Vector3.ZERO
	selected_block.position.y = destination_height

	if destination_layer % 2 == 0:
		selected_block.position.x = 0.0
		selected_block.position.z = (destination_slot - 1) * spacing
		selected_block.rotation = Vector3.ZERO
	else:
		selected_block.position.x = (destination_slot - 1) * spacing
		selected_block.position.z = 0.0
		selected_block.rotation = Vector3(0.0, PI / 2.0, 0.0)

	selected_block.set_meta("tower_layer", destination_layer)
	selected_block.set_meta("tower_slot", destination_slot)
	selected_block.freeze = false

	clear_selection()

	# Settle time
	is_checking_collapse = true
	await get_tree().create_timer(1.4).timeout

	if check_tower_collapsed():
		await eliminate_current_player()
	else:
		advance_turn()

	is_checking_collapse = false

func check_tower_collapsed() -> bool:
	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		if block.global_position.y < 0.1:
			return true
		if absf(block.global_position.x) > 2.0 or absf(block.global_position.z) > 2.0:
			return true
		var up_dir: Vector3 = block.global_transform.basis.y.normalized()
		if up_dir.dot(Vector3.UP) < 0.7:
			return true
	return false

func eliminate_current_player() -> void:
	SoundManager.play_lose_coin()
	var eliminated_player: int = current_player
	active_players.erase(eliminated_player)

	if active_players.size() <= 1:
		game_over = true
		var winner: int = active_players[0] if !active_players.is_empty() else 1
		SoundManager.play_star()
		var winner_color = GameState.get_player_color(winner)
		$HUD/TurnLabel.text = "🏆 PLAYER %d WINS THE MINIGAME! (+10 COINS) 🏆\nReturning to Board..." % winner
		$HUD/TurnLabel.modulate = winner_color
		GameState.award_coins(winner, 10)
		await get_tree().create_timer(3.5).timeout
		get_tree().change_scene_to_file("res://Board/Board.tscn")
		return

	$HUD/TurnLabel.text = "💥 Tower Collapsed! Player %d is eliminated!" % eliminated_player
	$HUD/TurnLabel.modulate = Color(1.0, 0.3, 0.3)

	await get_tree().create_timer(2.2).timeout

	current_player = get_next_active_player(eliminated_player)

	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block.queue_free()

	await get_tree().process_frame
	build_tower()
	update_turn_label()

func get_next_active_player(after_player: int) -> int:
	for offset in range(1, PLAYER_COUNT + 1):
		var candidate: int = ((after_player - 1 + offset) % PLAYER_COUNT) + 1
		if active_players.has(candidate):
			return candidate
	return after_player

func advance_turn() -> void:
	current_player = get_next_active_player(current_player)
	update_turn_label()

func update_turn_label() -> void:
	var turn_lbl = $HUD/TurnLabel as Label
	if turn_lbl:
		turn_lbl.text = "Player %d's Turn!" % current_player
		turn_lbl.modulate = GameState.get_player_color(current_player)

	# Update active players banner in HUD
	var player_box = $HUD.find_child("ActivePlayerBox", true, false) as HBoxContainer
	if player_box:
		for child in player_box.get_children():
			child.queue_free()
		for pid in [1, 2, 3, 4]:
			var badge = Label.new()
			badge.text = "P%d" % pid
			badge.add_theme_font_size_override("font_size", 18)
			if active_players.has(pid):
				badge.modulate = GameState.get_player_color(pid)
			else:
				badge.text += " (OUT)"
				badge.modulate = Color(0.4, 0.4, 0.4)
			player_box.add_child(badge)
