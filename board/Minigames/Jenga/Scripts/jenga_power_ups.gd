extends Node
## All power-up logic for the Jenga minigame.
##
## jenga_game.gd creates this node, calls setup(self), and from then on only
## talks to it through the functions below. This script reaches back into the
## game through the `tower` reference (current_player, is_checking_collapse,
## clear_selection(), update_block_difficulties(), etc.).

# The Jenga game script (jenga_game.gd). Left untyped on purpose so the two
# scripts don't depend on each other's class names.
var tower

# --- Probability Command / God's Favorite Child ---
var probability_active: bool = false
var probability_duration: float = 5.0

var safest_active: bool = false
var safest_duration: float = 5.0

# --- Rabbit's Foot ---
var rabbits_foot_active: bool = false
var rabbits_foot_lucky: bool = false

# --- Amped Up ---
var amped_up_active: bool = false
var original_music_volume: float = 0.0

# --- Art Block ---
var art_block_placement_active: bool = false
var selected_art_slot: Vector2i = Vector2i(-1, -1)

var vacant_slots: Array[Vector2i] = []
# Real (settled) positions of removed blocks, so Art Blocks fill gaps exactly.
# Vector2i(layer, slot) -> Transform3D (global)
var vacant_slot_transforms: Dictionary = {}
var active_art_blocks: Array[Dictionary] = []
var completed_turn_count: int = 0

# --- Architectural Prowess ---
const MAX_UNDO_MOVES: int = 3
var move_history: Array[Dictionary] = []

# TEMPORARY test majors. Replace get_player_major() with wherever your
# game actually stores each player's major.
var test_player_majors: Dictionary = {
	1: "Statistics",
	2: "Business",
	3: "Music",
	4: "Art"
}


func setup(game) -> void:
	tower = game


# ---------------------------------------------------------------------------
# Assigning power-ups
# ---------------------------------------------------------------------------

func get_player_major(player: int) -> String:
	return test_player_majors.get(player, "")


func assign_power_ups_from_majors() -> void:
	for player in range(1, tower.PLAYER_COUNT + 1):
		var major: String = get_player_major(player)

		if not PlayerPowerUps.assign_power_up_for_major(player, major):
			push_warning(
				"No power-up mapped for player %d's major: %s" % [player, major]
			)

	for player in range(1, tower.PLAYER_COUNT + 1):
		print(
			"Player ", player,
			" | Power-up: ",
			PlayerPowerUps.get_player_power_up(player),
			" | Charges: ",
			PlayerPowerUps.get_player_charges(player)
		)


# ---------------------------------------------------------------------------
# Hooks the Jenga game calls
# ---------------------------------------------------------------------------

# Called whenever a fresh tower is built.
func reset_for_new_tower() -> void:
	for entry in active_art_blocks:
		var old_art_block: RigidBody3D = entry["block"]

		if is_instance_valid(old_art_block):
			old_art_block.queue_free()

	active_art_blocks.clear()
	vacant_slots.clear()
	vacant_slot_transforms.clear()
	selected_art_slot = Vector2i(-1, -1)
	art_block_placement_active = false
	completed_turn_count = 0

	# Old snapshots point at blocks that no longer exist.
	move_history.clear()


# Art Blocks that currently exist (they also help hold the tower up).
func get_art_block_nodes() -> Array:
	var result: Array = []

	for entry in active_art_blocks:
		var art_block: RigidBody3D = entry["block"]

		if is_instance_valid(art_block):
			result.append(art_block)

	return result


# Called when a legal block removal leaves a gap in the tower.
func record_vacant_slot(slot: Vector2i, block_transform: Transform3D) -> void:
	if not vacant_slots.has(slot):
		vacant_slots.append(slot)

	# Remember exactly where the block was before it moves.
	vacant_slot_transforms[slot] = block_transform


# Called when a block lands in a slot that was listed as vacant.
func clear_vacant_slot(slot: Vector2i) -> void:
	vacant_slots.erase(slot)
	vacant_slot_transforms.erase(slot)


# Called at the end of a turn. Returns true if an Art Block expired.
func on_turn_completed() -> bool:
	completed_turn_count += 1
	return update_art_block_lifetimes()


# Rabbit's Foot protected the player this turn.
func consume_rabbits_foot() -> void:
	rabbits_foot_lucky = false
	rabbits_foot_active = false

	print("Rabbit's Foot protected the player!")


# Amped Up protected the player this turn.
func end_amped_up() -> void:
	amped_up_active = false

	var music = tower.get_node("BackgroundMusic")
	music.volume_db = original_music_volume

	stabilize_tower(false)

	print("Amped Up protected the player!")


# Freezes every block except the one being moved (used during Amped Up).
func freeze_tower_except(except_block: RigidBody3D) -> void:
	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		if block != except_block:
			block.freeze = true
			block.linear_velocity = Vector3.ZERO
			block.angular_velocity = Vector3.ZERO


func stabilize_tower(value: bool) -> void:
	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block.freeze = value

		if value:
			block.linear_velocity = Vector3.ZERO
			block.angular_velocity = Vector3.ZERO


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------

func update_powerup_label() -> void:
	var power_up: String = PlayerPowerUps.get_player_power_up(
		tower.current_player
	)

	var charges: int = PlayerPowerUps.get_player_charges(
		tower.current_player
	)

	var display_name: String = PlayerPowerUps.get_power_up_name(power_up)

	tower.get_node("HUD/PowerUpLabel").text = (
		"Power-up: " + display_name +
		" | Charges: " + str(charges)
	)


# ---------------------------------------------------------------------------
# Activating a power-up (Q key)
# ---------------------------------------------------------------------------

func activate_power_up() -> void:
	if tower.game_over or tower.is_checking_collapse:
		return

	var player: int = tower.current_player

	var power_up: String = PlayerPowerUps.get_player_power_up(player)

	if power_up == "":
		print("This player has no power-up assigned!")
		return

	if PlayerPowerUps.get_player_charges(player) <= 0:
		print("No power-up charges remaining!")
		return

	if power_up == PlayerPowerUps.PROBABILITY_COMMAND and probability_active:
		print("Probability Command is already active!")
		return

	if power_up == PlayerPowerUps.GODS_FAVORITE_CHILD and safest_active:
		print("God's Favorite Child is already active!")
		return

	if not PlayerPowerUps.is_valid_power_up(power_up):
		print("This power-up has not been implemented yet!")
		return

	# Don't waste a charge if there is nothing to rewind.
	if power_up == PlayerPowerUps.ARCHITECTURAL_PROWESS and move_history.is_empty():
		print("There are no moves to rewind yet!")
		return

	# Art Block only consumes a charge when successfully placed.
	if power_up == PlayerPowerUps.ART_BLOCK:
		if art_block_placement_active:
			cancel_art_block_placement()
			return

		tower.clear_selection()
		art_block_placement_active = true
		selected_art_slot = Vector2i(-1, -1)

		print("Art Block placement mode! Click an empty slot, then press E.")
		tower.set_turn_text(
			"Player " + str(player) + ": Choose an Art Block space!"
		)
		return

	if not PlayerPowerUps.use_charge(player):
		return

	update_powerup_label()

	if power_up == PlayerPowerUps.PROBABILITY_COMMAND:
		print("Player ", player, " activated Probability Command!")
		activate_probability_command()

	elif power_up == PlayerPowerUps.RABBITS_FOOT:
		print("Player ", player, " activated Rabbit's Foot!")
		await activate_rabbits_foot()

	elif power_up == PlayerPowerUps.AMPED_UP:
		print("Player ", player, " activated Amped Up!")
		activate_amped_up()

	elif power_up == PlayerPowerUps.GODS_FAVORITE_CHILD:
		print("Player ", player, " activated God's Favorite Child!")
		activate_gods_favorite_child()

	elif power_up == PlayerPowerUps.ARCHITECTURAL_PROWESS:
		print("Player ", player, " activated Architectural Prowess!")
		await activate_architectural_prowess()


# ---------------------------------------------------------------------------
# Probability Command
# ---------------------------------------------------------------------------

# Highlight only the blocks with the highest difficulty.
func activate_probability_command() -> void:
	if probability_active:
		print("Probability Command is already active!")
		return

	tower.update_block_difficulties()

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


# ---------------------------------------------------------------------------
# God's Favorite Child
# ---------------------------------------------------------------------------

func activate_gods_favorite_child() -> void:
	if safest_active:
		print("God's Favorite Child is already active!")
		return

	tower.update_block_difficulties()

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


# ---------------------------------------------------------------------------
# Rabbit's Foot
# ---------------------------------------------------------------------------

func activate_rabbits_foot() -> void:
	tower.is_checking_collapse = true

	var outcome: int = randi_range(0, 1)

	if outcome == 0:
		rabbits_foot_active = true
		rabbits_foot_lucky = true

		print("Rabbit's Foot: Lucky! Your next block removal is guaranteed!")

		tower.set_turn_text("Player " + str(tower.current_player) + " Got Lucky!")

		await get_tree().create_timer(2.0).timeout

		tower.update_turn_label()
		tower.is_checking_collapse = false
		return

	print("Rabbit's Foot: Unlucky! The tower exploded!")

	tower.set_turn_text("Player " + str(tower.current_player) + " Was Unlucky!")

	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block.freeze = false

		var explosion_direction: Vector3 = (
			block.global_position - Vector3(0, 2, 0)
		).normalized()

		block.apply_central_impulse(
			explosion_direction * 12.0 + Vector3.UP * 8.0
		)

	await get_tree().create_timer(2.0).timeout

	await tower.eliminate_current_player()

	tower.is_checking_collapse = false


# ---------------------------------------------------------------------------
# Amped Up
# ---------------------------------------------------------------------------

func activate_amped_up() -> void:
	if amped_up_active:
		print("Amped Up is already active!")
		return

	amped_up_active = true

	var music = tower.get_node("BackgroundMusic")
	original_music_volume = music.volume_db
	music.volume_db = minf(original_music_volume + 8.0, 0.0)

	print("Amped Up activated! Your next removal is protected!")
	tower.set_turn_text("Player " + str(tower.current_player) + " is Amped Up!")


# ---------------------------------------------------------------------------
# Architectural Prowess
# ---------------------------------------------------------------------------

# Saves the tower state right before a block is moved.
func record_move_snapshot() -> void:
	var block_states: Array[Dictionary] = []

	for block in get_tree().get_nodes_in_group("jenga_blocks"):
		block_states.append({
			"block": block,
			"transform": block.transform,
			"layer": int(block.get_meta("tower_layer", 0)),
			"slot": int(block.get_meta("tower_slot", 0))
		})

	move_history.append({
		"blocks": block_states,
		"vacant_slots": vacant_slots.duplicate(),
		"vacant_slot_transforms": vacant_slot_transforms.duplicate()
	})

	# Only keep the last 3 moves.
	while move_history.size() > MAX_UNDO_MOVES:
		move_history.pop_front()


# Rewinds the tower up to 3 block moves and removes all Art Blocks.
func activate_architectural_prowess() -> void:
	tower.is_checking_collapse = true  # Blocks input while we rewind.

	tower.clear_selection()

	if art_block_placement_active:
		cancel_art_block_placement()

	# Remove any Art Blocks currently in the tower.
	for entry in active_art_blocks:
		var art_block: RigidBody3D = entry["block"]

		if is_instance_valid(art_block):
			art_block.queue_free()

	active_art_blocks.clear()

	# Oldest snapshot = the tower as it was up to 3 moves ago
	# (or as far back as history goes if fewer moves have happened).
	var snapshot: Dictionary = move_history[0]
	move_history.clear()

	var states: Array = snapshot["blocks"]

	# Freeze everything while we reposition it.
	for state in states:
		var block: RigidBody3D = state["block"]

		if not is_instance_valid(block):
			continue

		block.freeze = true
		block.linear_velocity = Vector3.ZERO
		block.angular_velocity = Vector3.ZERO

		block.transform = state["transform"]
		block.set_meta("tower_layer", state["layer"])
		block.set_meta("tower_slot", state["slot"])

	vacant_slots = snapshot["vacant_slots"].duplicate()
	vacant_slot_transforms = snapshot["vacant_slot_transforms"].duplicate()

	# Let physics settle on the restored positions before unfreezing.
	await get_tree().physics_frame
	await get_tree().physics_frame

	for state in states:
		var block: RigidBody3D = state["block"]

		if is_instance_valid(block):
			block.freeze = false

	tower.update_block_difficulties()

	print("Architectural Prowess rewound the tower!")
	tower.set_turn_text(
		"Player " + str(tower.current_player) + " Rewound the Tower!"
	)

	await get_tree().create_timer(1.5).timeout

	tower.update_turn_label()
	tower.is_checking_collapse = false


# ---------------------------------------------------------------------------
# Art Block
# ---------------------------------------------------------------------------

func get_vacant_slot_position(slot: Vector2i) -> Vector3:
	# Prefer where the removed block was REALLY sitting. The tower settles
	# a little after it is built, so the "ideal" position can float above it.
	if vacant_slot_transforms.has(slot):
		var recorded: Transform3D = vacant_slot_transforms[slot]
		return recorded.origin

	var layer: int = slot.x
	var block_slot: int = slot.y
	var spacing: float = tower.BLOCK_WIDTH + tower.BLOCK_GAP

	var local_position := Vector3.ZERO

	local_position.y = tower.BLOCK_HEIGHT / 2.0
	local_position.y += layer * (tower.BLOCK_HEIGHT + tower.BLOCK_GAP)

	if layer % 2 == 0:
		local_position.x = 0.0
		local_position.z = (block_slot - 1) * spacing
	else:
		local_position.x = (block_slot - 1) * spacing
		local_position.z = 0.0

	return tower.to_global(local_position)


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

	if not PlayerPowerUps.use_charge(tower.current_player):
		print("No Art Block charges remaining!")
		cancel_art_block_placement()
		return

	var art_block: RigidBody3D = tower.BLOCK_SCENE.instantiate() as RigidBody3D

	var layer: int = selected_art_slot.x

	art_block.set_meta("tower_layer", layer)
	art_block.set_meta("tower_slot", selected_art_slot.y)
	art_block.set_meta("is_art_block", true)

	# Parent it to the tower, like every other block.
	tower.add_child(art_block)

	# Freeze first so it can't drift or fall before it is positioned.
	art_block.freeze = true
	art_block.linear_velocity = Vector3.ZERO
	art_block.angular_velocity = Vector3.ZERO

	art_block.global_position = get_vacant_slot_position(selected_art_slot)

	if layer % 2 == 0:
		art_block.global_rotation = Vector3.ZERO
	else:
		art_block.global_rotation = Vector3(0.0, PI / 2.0, 0.0)

	# Keep it fixed and out of normal Jenga selection.
	art_block.remove_from_group("jenga_blocks")

	active_art_blocks.append({
		"block": art_block,
		"slot": selected_art_slot,
		"expires_at": completed_turn_count + 3
	})

	art_block_placement_active = false
	selected_art_slot = Vector2i(-1, -1)

	tower.update_turn_label()
	update_powerup_label()
	tower.update_block_difficulties()

	print("Art Block placed! It will last for 3 completed turns.")


func cancel_art_block_placement() -> void:
	art_block_placement_active = false
	selected_art_slot = Vector2i(-1, -1)

	tower.update_turn_label()

	print("Art Block placement cancelled.")


# Returns true if at least one Art Block expired.
func update_art_block_lifetimes() -> bool:
	var any_expired: bool = false

	for i in range(active_art_blocks.size() - 1, -1, -1):
		var entry: Dictionary = active_art_blocks[i]

		if completed_turn_count < int(entry["expires_at"]):
			continue

		var art_block: RigidBody3D = entry["block"]
		var slot: Vector2i = entry["slot"]

		if is_instance_valid(art_block):
			art_block.queue_free()

		active_art_blocks.remove_at(i)
		any_expired = true

		print(
			"An Art Block expired at Layer ",
			slot.x + 1,
			", Slot ",
			slot.y + 1,
			"."
		)

	tower.update_block_difficulties()

	return any_expired
