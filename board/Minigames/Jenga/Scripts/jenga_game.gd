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

var camera_orbiting: bool = false
var camera_yaw: float = 0.0
var camera_start_offset: Vector3

# All power-up logic lives in jenga_power_ups.gd. The path is relative to THIS
# file, so keep the two scripts in the same folder (or use a full res:// path).
const JengaPowerUpsScript = preload("jenga_power_ups.gd")
var power_ups  # An instance of jenga_power_ups.gd

# Tower settling / collapse detection.
const SETTLE_CHECK_INTERVAL: float = 0.1
const MIN_SETTLE_TIME: float = 1.0
const MAX_SETTLE_TIME: float = 8.0
const REQUIRED_CALM_TIME: float = 0.5
const REST_LINEAR_SPEED: float = 0.05
const REST_ANGULAR_SPEED: float = 0.05


func _ready() -> void:
	power_ups = JengaPowerUpsScript.new()
	power_ups.name = "PowerUps"
	add_child(power_ups)
	power_ups.setup(self)

	var camera := find_child("Camera3D", true, false) as Camera3D

	if camera == null:
		push_error("Could not find Camera3D. Check its name in the scene tree.")
		return

	camera.global_position = Vector3(5, 5, 7)
	camera.current = true
	camera.look_at(Vector3(0, 2, 0), Vector3.UP)

	camera_start_offset = camera.global_position - Vector3(0, 2, 0)
	camera_yaw = 0.0

	update_camera_light()

	build_tower()
	update_turn_label()

	$BackgroundMusic.finished.connect(_on_music_finished)
	$BackgroundMusic.play()

	power_ups.assign_power_ups_from_majors()


func build_tower() -> void:
	# Clears Art Blocks, vacant slots and rewind history.
	power_ups.reset_for_new_tower()

	clear_selection()

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

	update_block_difficulties()


func get_block_half_extents(block: RigidBody3D) -> Vector2:
	var layer: int = int(block.get_meta("tower_layer", 0))

	if layer % 2 == 0:
		return Vector2(BLOCK_WIDTH / 2.0, BLOCK_LENGTH / 2.0)

	return Vector2(BLOCK_LENGTH / 2.0, BLOCK_WIDTH / 2.0)


func get_footprint_overlap_area(
	block_a: RigidBody3D,
	block_b: RigidBody3D
) -> float:
	var position_a: Vector3 = block_a.global_position
	var position_b: Vector3 = block_b.global_position

	var half_a: Vector2 = get_block_half_extents(block_a)
	var half_b: Vector2 = get_block_half_extents(block_b)

	var overlap_x: float = minf(
		position_a.x + half_a.x,
		position_b.x + half_b.x
	) - maxf(
		position_a.x - half_a.x,
		position_b.x - half_b.x
	)

	var overlap_z: float = minf(
		position_a.z + half_a.y,
		position_b.z + half_b.y
	) - maxf(
		position_a.z - half_a.y,
		position_b.z - half_b.y
	)

	if overlap_x <= 0.0 or overlap_z <= 0.0:
		return 0.0

	return overlap_x * overlap_z


# Calculate removal difficulty, including Art Block support.
func calculate_removal_difficulty(
	candidate: RigidBody3D,
	blocks: Array
) -> int:
	var candidate_layer: int = int(
		candidate.get_meta("tower_layer", 0)
	)

	var worst_remaining_support: float = 1.0
	var found_supported_block: bool = false

	var ideal_support_area: float = BLOCK_LENGTH * BLOCK_WIDTH

	# Regular blocks and Art Blocks can provide support.
	var support_blocks: Array = blocks.duplicate()

	support_blocks.append_array(power_ups.get_art_block_nodes())

	# Examine blocks directly above the candidate.
	for upper_block in blocks:
		var upper_layer: int = int(
			upper_block.get_meta("tower_layer", 0)
		)

		if upper_layer != candidate_layer + 1:
			continue

		var total_support_area: float = 0.0

		for support_block in support_blocks:
			var support_layer: int = int(
				support_block.get_meta("tower_layer", 0)
			)

			if support_layer != candidate_layer:
				continue

			total_support_area += get_footprint_overlap_area(
				support_block,
				upper_block
			)

		var candidate_support: float = get_footprint_overlap_area(
			candidate,
			upper_block
		)

		if candidate_support <= 0.0:
			continue

		found_supported_block = true

		var remaining_support: float = maxf(
			0.0,
			total_support_area - candidate_support
		)

		var remaining_coverage: float = clampf(
			remaining_support / ideal_support_area,
			0.0,
			1.0
		)

		worst_remaining_support = minf(
			worst_remaining_support,
			remaining_coverage
		)

	if not found_supported_block:
		return 1

	var support_risk: int = ceili(
		(1.0 - worst_remaining_support) * 6.0
	)

	var load_bonus: int = mini(
		3,
		LAYER_COUNT - candidate_layer - 1
	)

	var difficulty: int = 1 + support_risk + load_bonus

	return clampi(difficulty, 1, 10)


func update_block_difficulties() -> void:
	var blocks: Array = get_tree().get_nodes_in_group("jenga_blocks")

	for block in blocks:
		block.removal_difficulty = calculate_removal_difficulty(
			block,
			blocks
		)


func _input(event: InputEvent) -> void:
	if game_over or is_checking_collapse:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			camera_orbiting = event.pressed

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if power_ups.art_block_placement_active:
				power_ups.select_art_slot_at_mouse(event.position)
			else:
				select_block_at_mouse(event.position)

	if event is InputEventMouseMotion and camera_orbiting:
		rotate_camera(-event.relative.x * 0.005)

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_E:
				if power_ups.art_block_placement_active:
					power_ups.place_art_block()
				else:
					place_selected_block()

			elif event.keycode == KEY_Q:
				power_ups.activate_power_up()


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
			selected_block.removal_difficulty
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

	for block in blocks:
		if block == selected_block:
			continue

		var layer: int = int(block.get_meta("tower_layer", 0))
		highest_layer = maxi(highest_layer, layer)

	# Prevent removing the top layer unless Rabbit's Foot is lucky.
	if (
		int(selected_block.get_meta("tower_layer", 0)) >= highest_layer
		and not power_ups.rabbits_foot_lucky
	):
		print("You can't remove a block from the top layer!")
		return

	# Save the tower as it was BEFORE this move (for Architectural Prowess).
	power_ups.record_move_snapshot()

	# Record the empty space only after a legal removal.
	var original_slot := Vector2i(
		int(selected_block.get_meta("tower_layer", 0)),
		int(selected_block.get_meta("tower_slot", 0))
	)

	power_ups.record_vacant_slot(original_slot, selected_block.global_transform)

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

	# If the block lands in a slot that was listed as vacant, it isn't anymore.
	var destination_id := Vector2i(destination_layer, destination_slot)
	power_ups.clear_vacant_slot(destination_id)

	var spacing: float = BLOCK_WIDTH + BLOCK_GAP
	var destination_height: float = BLOCK_HEIGHT / 2.0
	destination_height += destination_layer * (BLOCK_HEIGHT + BLOCK_GAP)

	# Stabilize the tower during Amped Up.
	if power_ups.amped_up_active:
		power_ups.freeze_tower_except(selected_block)

	# Move the selected block.
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

	update_block_difficulties()

	selected_block.freeze = false

	clear_selection()

	is_checking_collapse = true

	# Wait for the tower to actually stop moving before judging it.
	var collapse_detected: bool = await wait_for_tower_to_settle()

	# Art Blocks expire at the end of the turn. If one was holding the tower
	# up, the player who just moved answers for it, so check again afterward.
	if not collapse_detected:
		if power_ups.on_turn_completed():
			collapse_detected = await wait_for_tower_to_settle(true)

	if power_ups.rabbits_foot_lucky:
		power_ups.consume_rabbits_foot()

		# Protected, but don't hand the next player a pile of blocks.
		if collapse_detected:
			await rebuild_tower()

		advance_turn()

	elif power_ups.amped_up_active:
		# The tower was frozen for the move, so let it loose and see what happens.
		power_ups.end_amped_up()

		if not collapse_detected:
			collapse_detected = await wait_for_tower_to_settle()

		if collapse_detected:
			await rebuild_tower()

		advance_turn()

	elif collapse_detected:
		await eliminate_current_player()

	else:
		advance_turn()

	is_checking_collapse = false


func find_available_slot(layer: int, height: float) -> int:
	var spacing: float = BLOCK_WIDTH + BLOCK_GAP

	for slot in range(BLOCKS_PER_LAYER):
		var target_x: float = 0.0
		var target_z: float = 0.0

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
		if block.global_position.y < 0.1:
			return true

		if (
			absf(block.global_position.x) > 1.8
			or absf(block.global_position.z) > 1.8
		):
			return true

		var up_direction: Vector3 = \
			block.global_transform.basis.y.normalized()

		if up_direction.dot(Vector3.UP) < 0.75:
			return true

	return false


# Waits until the tower stops moving. Returns true if it collapsed.
func wait_for_tower_to_settle(wake_blocks: bool = false) -> bool:
	if wake_blocks:
		# Let a freed Art Block leave the physics world, then wake the blocks.
		# Sleeping bodies don't notice that their support disappeared.
		await get_tree().physics_frame
		await get_tree().physics_frame
		wake_all_blocks()

	var elapsed: float = 0.0
	var calm_time: float = 0.0

	while elapsed < MAX_SETTLE_TIME:
		await get_tree().create_timer(SETTLE_CHECK_INTERVAL).timeout
		elapsed += SETTLE_CHECK_INTERVAL

		if check_tower_collapsed():
			return true

		if elapsed >= MIN_SETTLE_TIME and is_tower_at_rest():
			calm_time += SETTLE_CHECK_INTERVAL

			if calm_time >= REQUIRED_CALM_TIME:
				break
		else:
			calm_time = 0.0

	return check_tower_collapsed()


func is_tower_at_rest() -> bool:
	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		if block.sleeping:
			continue

		if (
			block.linear_velocity.length() > REST_LINEAR_SPEED
			or block.angular_velocity.length() > REST_ANGULAR_SPEED
		):
			return false

	return true


func wake_all_blocks() -> void:
	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block.sleeping = false


func rebuild_tower() -> void:
	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block.queue_free()

	await get_tree().process_frame

	build_tower()


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

	await get_tree().create_timer(2.0).timeout

	current_player = get_next_active_player(eliminated_player)

	await rebuild_tower()
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


# Lets other scripts (like the power-ups) set the HUD message.
func set_turn_text(text: String) -> void:
	$HUD/TurnLabel.text = text


func update_turn_label() -> void:
	$HUD/TurnLabel.text = "Player " + str(current_player) + "'s Turn"
	power_ups.update_powerup_label()


func rotate_camera(amount: float) -> void:
	var camera := find_child("Camera3D", true, false) as Camera3D

	if camera == null:
		return

	camera_yaw += amount

	var target: Vector3 = Vector3(0, 2, 0)
	var original_offset: Vector3 = camera_start_offset

	var rotated_offset: Vector3 = Vector3(
		original_offset.x * cos(camera_yaw)
			+ original_offset.z * sin(camera_yaw),
		original_offset.y,
		-original_offset.x * sin(camera_yaw)
			+ original_offset.z * cos(camera_yaw)
	)

	camera.global_position = target + rotated_offset
	camera.look_at(target, Vector3.UP)

	update_camera_light()


func update_camera_light() -> void:
	var camera := find_child("Camera3D", true, false) as Camera3D
	var light := find_child(
		"DirectionalLight3D", true, false
	) as DirectionalLight3D

	if camera == null or light == null:
		return

	light.global_rotation = camera.global_rotation
	light.light_energy = 1.2
	light.shadow_enabled = true


func _on_music_finished() -> void:
	$BackgroundMusic.play()
