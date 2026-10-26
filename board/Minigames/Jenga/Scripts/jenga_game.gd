

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

var active_players: Array[int] = [1, 2, 3, 4]
var is_checking_collapse: bool = false
var game_over: bool = false


func _ready() -> void:
	$Camera3D.current = true
	$Camera3D.look_at(Vector3(0, 2, 0), Vector3.UP)

	build_tower()
	update_turn_label()



func build_tower() -> void:
	var spacing: float = BLOCK_WIDTH + BLOCK_GAP

	for layer in range(LAYER_COUNT):
		for i in range(BLOCKS_PER_LAYER):
			var block = BLOCK_SCENE.instantiate() as RigidBody3D
			add_child(block)

			# Remember this block's original tower position.
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


func _input(event: InputEvent) -> void:
	if game_over or is_checking_collapse:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			select_block_at_mouse(event.position)

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_E:
				place_selected_block()


func select_block_at_mouse(mouse_position: Vector2) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return

	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position)

	var query: PhysicsRayQueryParameters3D = \
		PhysicsRayQueryParameters3D.create(
			ray_origin,
			ray_origin + ray_direction * 1000.0
		)

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		clear_selection()
		return

	var collider = hit["collider"]

	if collider is RigidBody3D and collider.is_in_group("jenga_blocks"):
		clear_selection()
		selected_block = collider as RigidBody3D
		selected_block.set_selected(true)

		print(
			"Selected block difficulty: ",
			selected_block.get("removal_difficulty")
		)
	else:
		clear_selection()


func clear_selection() -> void:
	if is_instance_valid(selected_block):
		selected_block.set_selected(false)

	selected_block = null




func place_selected_block() -> void:
	if not is_instance_valid(selected_block):
		print("Click a block first!")
		return

	var blocks: Array = get_tree().get_nodes_in_group("jenga_blocks")
	var highest_layer: int = 0

	# Find the highest intended layer, ignoring the moving block.
	for block in blocks:
		if block == selected_block:
			continue

		var layer: int = int(block.get_meta("tower_layer", 0))
		highest_layer = maxi(highest_layer, layer)

	# Record which slots on the highest layer are occupied.
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

	# Look for an open slot on the current top layer.
	var destination_layer: int = highest_layer
	var destination_slot: int = -1

	for i in range(BLOCKS_PER_LAYER):
		if not occupied_slots[i]:
			destination_slot = i
			break

	# Only create another layer when all three slots are occupied.
	if destination_slot == -1:
		destination_layer += 1
		destination_slot = 0

	var spacing: float = BLOCK_WIDTH + BLOCK_GAP
	var destination_height: float = BLOCK_HEIGHT / 2.0
	destination_height += destination_layer * (BLOCK_HEIGHT + BLOCK_GAP)

	# Freeze while moving the block.
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

	# Save the block's new intended position.
	selected_block.set_meta("tower_layer", destination_layer)
	selected_block.set_meta("tower_slot", destination_slot)

	selected_block.freeze = false

	clear_selection()

	# Allow the tower to settle before checking for a collapse.
	is_checking_collapse = true
	await get_tree().create_timer(1.5).timeout

	if check_tower_collapsed():
		await eliminate_current_player()
	else:
		advance_turn()

	is_checking_collapse = false



func find_available_slot(layer: int, height: float) -> int:
	var spacing: float = BLOCK_WIDTH + BLOCK_GAP

	for slot in range(BLOCKS_PER_LAYER):
		var target_x: float = 0
		var target_z: float = 0

		if layer % 2 == 0:
			target_z = (slot - 1) * spacing
		else:
			target_x = (slot - 1) * spacing

		var occupied: bool = false

		for block in get_tree().get_nodes_in_group("jenga_blocks"):
			if block == selected_block:
				continue

			if absf(block.position.y - height) > 0.05:
				continue

			if (
				absf(block.position.x - target_x) < 0.2
				and absf(block.position.z - target_z) < 0.2
			):
				occupied = true
				break

		if not occupied:
			return slot

	return -1


func check_tower_collapsed() -> bool:
	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		# A block has fallen below the floor area.
		if block.global_position.y < 0.1:
			return true

		# A block has moved too far away from the tower.
		if (
			absf(block.global_position.x) > 1.8
			or absf(block.global_position.z) > 1.8
		):
			return true

		# A block has tilted too far from upright.
		var up_direction: Vector3 = \
			block.global_transform.basis.y.normalized()

		if up_direction.dot(Vector3.UP) < 0.75:
			return true

	return false


func eliminate_current_player() -> void:
	var eliminated_player: int = current_player

	active_players.erase(eliminated_player)

	if active_players.size() <= 1:
		game_over = true
		$HUD/TurnLabel.text = (
			"Player " + str(active_players[0]) + " Wins!"
		)
		print("Player ", active_players[0], " wins!")
		return

	$HUD/TurnLabel.text = (
		"Player " + str(eliminated_player) + " is out!"
	)

	print("Player ", eliminated_player, " is out!")

	# Give everyone time to see the elimination message.
	await get_tree().create_timer(2.0).timeout

	# Choose the next player who has not been eliminated.
	current_player = get_next_active_player(eliminated_player)

	# Remove the fallen tower and build a fresh one.
	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block.queue_free()

	await get_tree().process_frame

	build_tower()
	update_turn_label()


func get_next_active_player(after_player: int) -> int:
	for offset in range(1, PLAYER_COUNT + 1):
		var candidate: int = (
			(after_player - 1 + offset) % PLAYER_COUNT
		) + 1

		if active_players.has(candidate):
			return candidate

	return after_player


func advance_turn() -> void:
	current_player = get_next_active_player(current_player)
	update_turn_label()


func update_turn_label() -> void:
	$HUD/TurnLabel.text = "Player " + str(current_player) + "'s Turn"
