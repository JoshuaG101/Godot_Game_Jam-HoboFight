
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

var probability_active: bool = false
var probability_duration: float = 5.0

var safest_active: bool = false
var safest_duration: float = 5.0

var rabbits_foot_active: bool = false
var rabbits_foot_lucky: bool = false

var amped_up_active: bool = false
var original_music_volume: float = 0.0

# Art Block placement and lifetime.
var art_block_placement_active: bool = false
var selected_art_slot: Vector2i = Vector2i(-1, -1)

var vacant_slots: Array[Vector2i] = []
var active_art_blocks: Array[Dictionary] = []
var completed_turn_count: int = 0


func _ready() -> void:
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

	test_player_powerups()


func build_tower() -> void:
	# Remove Art Blocks from the previous tower.
	for entry in active_art_blocks:
		var old_art_block: RigidBody3D = entry["block"]

		if is_instance_valid(old_art_block):
			old_art_block.queue_free()

	active_art_blocks.clear()
	vacant_slots.clear()
	selected_art_slot = Vector2i(-1, -1)
	art_block_placement_active = false
	completed_turn_count = 0

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

	for entry in active_art_blocks:
		var art_block: RigidBody3D = entry["block"]

		if is_instance_valid(art_block):
			support_blocks.append(art_block)

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
			if art_block_placement_active:
				select_art_slot_at_mouse(event.position)
			else:
				select_block_at_mouse(event.position)

	if event is InputEventMouseMotion and camera_orbiting:
		rotate_camera(-event.relative.x * 0.005)

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_E:
				if art_block_placement_active:
					place_art_block()
				else:
					place_selected_block()

			elif event.keycode == KEY_Q:
				activate_power_up()


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


func get_vacant_slot_position(slot: Vector2i) -> Vector3:
	var layer: int = slot.x
	var block_slot: int = slot.y
	var spacing: float = BLOCK_WIDTH + BLOCK_GAP

	var position := Vector3.ZERO

	position.y = BLOCK_HEIGHT / 2.0
	position.y += layer * (BLOCK_HEIGHT + BLOCK_GAP)

	if layer % 2 == 0:
		position.x = 0.0
		position.z = (block_slot - 1) * spacing
	else:
		position.x = (block_slot - 1) * spacing
		position.z = 0.0

	return to_global(position)


func select_art_slot_at_mouse(mouse_position: Vector2) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return

	var closest_slot := Vector2i(-1, -1)
	var closest_distance: float = 55.0

	for slot in vacant_slots:
		var already_filled: bool = false

		for entry in active_art_blocks:
			if entry["slot"] == slot:
				already_filled = true
				break

		if already_filled:
			continue

		var world_position: Vector3 = get_vacant_slot_position(slot)
		var screen_position: Vector2 = camera.unproject_position(world_position)

		var distance: float = mouse_position.distance_to(screen_position)

		if distance < closest_distance:
			closest_distance = distance
			closest_slot = slot

	if closest_slot.x == -1:
		selected_art_slot = Vector2i(-1, -1)
		print("Click closer to an empty space where a block was removed.")
		return

	selected_art_slot = closest_slot

	print(
		"Selected empty space: Layer ",
		selected_art_slot.x + 1,
		", Slot ",
		selected_art_slot.y + 1,
		". Press E to place the Art Block."
	)


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
		and not rabbits_foot_lucky
	):
		print("You can't remove a block from the top layer!")
		return

	# Record the empty space only after a legal removal.
	var original_slot := Vector2i(
		int(selected_block.get_meta("tower_layer", 0)),
		int(selected_block.get_meta("tower_slot", 0))
	)

	if not vacant_slots.has(original_slot):
		vacant_slots.append(original_slot)

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
	var destination_height: float = BLOCK_HEIGHT / 2.0
	destination_height += destination_layer * (BLOCK_HEIGHT + BLOCK_GAP)

	# Stabilize the tower during Amped Up.
	if amped_up_active:
		for block in blocks:
			if block != selected_block:
				block.freeze = true
				block.linear_velocity = Vector3.ZERO
				block.angular_velocity = Vector3.ZERO

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

	var collapse_detected: bool = false
	var elapsed: float = 0.0
	var check_interval: float = 0.1
	var max_wait: float = 3.0

	while elapsed < max_wait:
		await get_tree().create_timer(check_interval).timeout
		elapsed += check_interval

		if check_tower_collapsed():
			collapse_detected = true
			break

	if rabbits_foot_lucky:
		rabbits_foot_lucky = false
		rabbits_foot_active = false

		print("Rabbit's Foot protected the player!")
		advance_turn()

	elif amped_up_active:
		amped_up_active = false
		$BackgroundMusic.volume_db = original_music_volume

		stabilize_tower(false)

		print("Amped Up protected the player!")
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
	completed_turn_count += 1
	update_art_block_lifetimes()

	current_player = get_next_active_player(current_player)
	update_turn_label()


func update_turn_label() -> void:
	$HUD/TurnLabel.text = "Player " + str(current_player) + "'s Turn"
	update_powerup_label()


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


func test_player_powerups() -> void:
	PlayerPowerUps.assign_power_up(1, "probability_command")
	PlayerPowerUps.assign_power_up(2, "rabbits_foot")
	PlayerPowerUps.assign_power_up(3, "amped_up")
	PlayerPowerUps.assign_power_up(4, "art_block")

	for player in range(1, 5):
		print(
			"Player ", player,
			" | Power-up: ",
			PlayerPowerUps.get_player_power_up(player),
			" | Charges: ",
			PlayerPowerUps.get_player_charges(player)
		)


func update_powerup_label() -> void:
	var power_up: String = PlayerPowerUps.get_player_power_up(
		current_player
	)

	var charges: int = PlayerPowerUps.get_player_charges(
		current_player
	)

	var power_up_names: Dictionary = {
		"probability_command": "Probability Command",
		"rabbits_foot": "Rabbit's Foot",
		"amped_up": "Amped Up",
		"gods_favorite_child": "God's Favorite Child",
		"art_block": "Art Block",
		"architectural_prowess": "Architectural Prowess"
	}

	var display_name: String = power_up_names.get(
		power_up,
		"None"
	)

	$HUD/PowerUpLabel.text = (
		"Power-up: " + display_name +
		" | Charges: " + str(charges)
	)


func activate_power_up() -> void:
	if game_over or is_checking_collapse:
		return

	var power_up: String = PlayerPowerUps.get_player_power_up(
		current_player
	)

	if power_up == "":
		print("This player has no power-up assigned!")
		return

	if PlayerPowerUps.get_player_charges(current_player) <= 0:
		print("No power-up charges remaining!")
		return

	if power_up == "probability_command" and probability_active:
		print("Probability Command is already active!")
		return

	if power_up == "gods_favorite_child" and safest_active:
		print("God's Favorite Child is already active!")
		return

	if (
		power_up != "probability_command"
		and power_up != "rabbits_foot"
		and power_up != "amped_up"
		and power_up != "gods_favorite_child"
		and power_up != "art_block"
	):
		print("This power-up has not been implemented yet!")
		return

	# Art Block only consumes a charge when successfully placed.
	if power_up == "art_block":
		if art_block_placement_active:
			cancel_art_block_placement()
			return

		clear_selection()
		art_block_placement_active = true
		selected_art_slot = Vector2i(-1, -1)

		print("Art Block placement mode! Click an empty slot, then press E.")
		$HUD/TurnLabel.text = "Player " + str(current_player) + ": Choose an Art Block space!"
		return

	if PlayerPowerUps.use_charge(current_player):
		update_powerup_label()

		match power_up:
			"probability_command":
				print("Player ", current_player, " activated Probability Command!")
				activate_probability_command()

			"rabbits_foot":
				print("Player ", current_player, " activated Rabbit's Foot!")
				await activate_rabbits_foot()

			"amped_up":
				print("Player ", current_player, " activated Amped Up!")
				activate_amped_up()

			"gods_favorite_child":
				print("Player ", current_player, " activated God's Favorite Child!")
				activate_gods_favorite_child()


# Highlight only the blocks with the highest difficulty.
func activate_probability_command() -> void:
	if probability_active:
		print("Probability Command is already active!")
		return

	update_block_difficulties()

	var blocks: Array = get_tree().get_nodes_in_group("jenga_blocks")

	if blocks.is_empty():
		return

	var highest_layer: int = 0

	for block in blocks:
		highest_layer = maxi(
			highest_layer,
			int(block.get_meta("tower_layer", 0))
		)

	var highest_difficulty: int = 1

	for block in blocks:
		var layer: int = int(block.get_meta("tower_layer", 0))

		if layer >= highest_layer:
			continue

		highest_difficulty = maxi(
			highest_difficulty,
			block.removal_difficulty
		)

	for block in blocks:
		var layer: int = int(block.get_meta("tower_layer", 0))

		if layer >= highest_layer:
			block.set_probability_highlight(false)
		elif block.removal_difficulty == highest_difficulty:
			block.set_probability_highlight(true)
		else:
			block.set_probability_highlight(false)

	probability_active = true

	print("Probability Command activated!")

	await get_tree().create_timer(probability_duration).timeout

	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block.set_probability_highlight(false)

	probability_active = false
	print("Probability Command ended!")


func activate_gods_favorite_child() -> void:
	if safest_active:
		print("God's Favorite Child is already active!")
		return

	update_block_difficulties()

	var blocks: Array = get_tree().get_nodes_in_group("jenga_blocks")

	if blocks.is_empty():
		return

	var highest_layer: int = 0

	for block in blocks:
		highest_layer = maxi(
			highest_layer,
			int(block.get_meta("tower_layer", 0))
		)

	var safest_block: RigidBody3D = null
	var lowest_difficulty: int = 11

	for block in blocks:
		var layer: int = int(block.get_meta("tower_layer", 0))

		if layer >= highest_layer:
			continue

		if block.removal_difficulty < lowest_difficulty:
			lowest_difficulty = block.removal_difficulty
			safest_block = block

	if safest_block == null:
		print("No removable block was found!")
		return

	safest_block.set_safest_highlight(true)

	safest_active = true

	print(
		"God's Favorite Child revealed a safer block! Difficulty: ",
		lowest_difficulty
	)

	await get_tree().create_timer(safest_duration).timeout

	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block.set_safest_highlight(false)

	safest_active = false

	print("God's Favorite Child ended!")


func activate_rabbits_foot() -> void:
	is_checking_collapse = true

	var outcome: int = randi_range(0, 1)

	if outcome == 0:
		rabbits_foot_active = true
		rabbits_foot_lucky = true

		print("Rabbit's Foot: Lucky! Your next block removal is guaranteed!")

		$HUD/TurnLabel.text = "Player " + str(current_player) + " Got Lucky!"

		await get_tree().create_timer(2.0).timeout

		update_turn_label()
		is_checking_collapse = false
		return

	print("Rabbit's Foot: Unlucky! The tower exploded!")

	$HUD/TurnLabel.text = "Player " + str(current_player) + " Was Unlucky!"

	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block.freeze = false

		var explosion_direction: Vector3 = (
			block.global_position - Vector3(0, 2, 0)
		).normalized()

		block.apply_central_impulse(
			explosion_direction * 12.0 + Vector3.UP * 8.0
		)

	await get_tree().create_timer(2.0).timeout

	await eliminate_current_player()

	is_checking_collapse = false


func activate_amped_up() -> void:
	if amped_up_active:
		print("Amped Up is already active!")
		return

	amped_up_active = true

	original_music_volume = $BackgroundMusic.volume_db
	$BackgroundMusic.volume_db = minf(original_music_volume + 8.0, 0.0)

	print("Amped Up activated! Your next removal is protected!")
	$HUD/TurnLabel.text = "Player " + str(current_player) + " is Amped Up!"


func stabilize_tower(value: bool) -> void:
	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block.freeze = value

		if value:
			block.linear_velocity = Vector3.ZERO
			block.angular_velocity = Vector3.ZERO


func place_art_block() -> void:
	if not art_block_placement_active:
		return

	if selected_art_slot.x == -1:
		print("Select an empty space first!")
		return

	if not vacant_slots.has(selected_art_slot):
		print("That space is no longer available!")
		return

	for entry in active_art_blocks:
		if entry["slot"] == selected_art_slot:
			print("An Art Block is already in that space!")
			return

	if not PlayerPowerUps.use_charge(current_player):
		print("No Art Block charges remaining!")
		cancel_art_block_placement()
		return

	var art_block := BLOCK_SCENE.instantiate() as RigidBody3D

	var layer: int = selected_art_slot.x

	art_block.set_meta("tower_layer", layer)
	art_block.set_meta("tower_slot", selected_art_slot.y)
	art_block.set_meta("is_art_block", true)

	add_child(art_block)

	art_block.global_position = get_vacant_slot_position(selected_art_slot)

	if layer % 2 == 0:
		art_block.global_rotation = Vector3.ZERO
	else:
		art_block.global_rotation = Vector3(0.0, PI / 2.0, 0.0)

	# Keep it fixed and out of normal Jenga selection.
	art_block.remove_from_group("jenga_blocks")
	art_block.freeze = true
	art_block.linear_velocity = Vector3.ZERO
	art_block.angular_velocity = Vector3.ZERO

	active_art_blocks.append({
		"block": art_block,
		"slot": selected_art_slot,
		"expires_at": completed_turn_count + 3
	})

	art_block_placement_active = false
	selected_art_slot = Vector2i(-1, -1)

	update_turn_label()
	update_powerup_label()
	update_block_difficulties()

	print("Art Block placed! It will last for 3 completed turns.")


func cancel_art_block_placement() -> void:
	art_block_placement_active = false
	selected_art_slot = Vector2i(-1, -1)

	update_turn_label()

	print("Art Block placement cancelled.")


func update_art_block_lifetimes() -> void:
	for i in range(active_art_blocks.size() - 1, -1, -1):
		var entry: Dictionary = active_art_blocks[i]

		if completed_turn_count < int(entry["expires_at"]):
			continue

		var art_block: RigidBody3D = entry["block"]
		var slot: Vector2i = entry["slot"]

		if is_instance_valid(art_block):
			art_block.queue_free()

		active_art_blocks.remove_at(i)

		print(
			"An Art Block expired at Layer ",
			slot.x + 1,
			", Slot ",
			slot.y + 1,
			"."
		)

	update_block_difficulties()
