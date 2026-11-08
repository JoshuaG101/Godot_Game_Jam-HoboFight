extends Node3D

signal turn_finished
signal steps_updated(remaining: int)

@export var player_id: int = 1
@export var current_space: BoardNode3D
@export var dice: RigidBody3D
@export var move_speed: float = 3.5

var is_moving: bool = false
var is_rolling: bool = false
var is_my_turn: bool = false
var overhead_label: Label3D

# Offset per player so 4 players stand neatly on the same space without overlapping
var tile_offsets: Dictionary = {
	1: Vector3(-0.35, 0.0, -0.35),
	2: Vector3(0.35, 0.0, -0.35),
	3: Vector3(-0.35, 0.0, 0.35),
	4: Vector3(0.35, 0.0, 0.35)
}

func _ready() -> void:
	# Restore saved space from GameState if returning from a minigame
	var saved_space_path = GameState.get_player_space(player_id)
	if saved_space_path != "":
		var node = get_node_or_null(saved_space_path)
		if node is BoardNode3D:
			current_space = node

	if not current_space:
		# Fallback to default starting space
		current_space = get_node_or_null("../Node/marioPartyTiles")

	if current_space:
		global_position = current_space.global_position + get_tile_offset()
	else:
		push_error("Player %d has no Current Space assigned!" % player_id)

	setup_player_visuals()

	if not dice:
		dice = get_node_or_null("../Die")

	if dice:
		if not dice.roll_finished.is_connected(_on_dice_roll_finished):
			dice.roll_finished.connect(_on_dice_roll_finished)

func get_tile_offset() -> Vector3:
	return tile_offsets.get(player_id, Vector3.ZERO)

func setup_player_visuals() -> void:
	var color = GameState.get_player_color(player_id)
	
	# Set capsule material
	var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.2
		mat.metallic = 0.35
		mat.rim_enabled = true
		mat.rim = 0.6
		mat.rim_tint = 0.5
		mesh_inst.material_override = mat

	# Add glowing player base ring / pedestal
	var ring = MeshInstance3D.new()
	ring.name = "PlayerRing"
	var torus = TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.36
	torus.rings = 24
	torus.ring_segments = 16
	ring.mesh = torus
	ring.position = Vector3(0, 0.04, 0)
	
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = color
	ring_mat.emission_enabled = true
	ring_mat.emission = color * 1.8
	ring_mat.roughness = 0.1
	ring_mat.metallic = 0.4
	ring.material_override = ring_mat
	add_child(ring)

	# Add subtle idle bobbing tween to mesh
	start_idle_animation()

	# Add overhead 3D player badge with major identity
	overhead_label = Label3D.new()
	overhead_label.name = "OverheadBadge"
	overhead_label.text = "P%d %s" % [player_id, GameState.get_player_name(player_id)]
	overhead_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overhead_label.pixel_size = 0.009
	overhead_label.position = Vector3(0, 1.65, 0)
	overhead_label.font_size = 32
	overhead_label.modulate = color
	overhead_label.outline_size = 8
	overhead_label.outline_modulate = Color(0, 0, 0, 0.9)
	add_child(overhead_label)

func start_idle_animation() -> void:
	var mesh_inst = get_node_or_null("MeshInstance3D")
	if not mesh_inst:
		return
	var initial_y = mesh_inst.position.y
	# Offset tween phase by player_id so players do not bob in robotic unison
	var delay = float(player_id) * 0.25
	var tw = create_tween().set_loops()
	tw.tween_interval(delay)
	tw.tween_property(mesh_inst, "position:y", initial_y + 0.05, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mesh_inst, "position:y", initial_y, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func start_turn() -> void:
	is_my_turn = true
	is_moving = false
	is_rolling = false
	
	# Turn indicator bounce
	if overhead_label:
		var tw = overhead_label.create_tween()
		tw.tween_property(overhead_label, "position:y", 1.85, 0.2).set_trans(Tween.TRANS_BACK)
		tw.tween_property(overhead_label, "position:y", 1.6, 0.2).set_trans(Tween.TRANS_BOUNCE)
		
	print("Player %d's turn started." % player_id)

func _input(event: InputEvent) -> void:
	if not is_my_turn or is_moving or is_rolling:
		return

	var is_roll_pressed: bool = (
		event.is_action_pressed("roll_dice") or
		event.is_action_pressed("ui_accept") or
		event.is_action_pressed("UI_ACCEPT") or
		event.is_action_pressed("get_next_spaces") or
		(event is InputEventKey and event.is_pressed() and not event.echo and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE))
	)

	if is_roll_pressed:
		request_roll()

func request_roll() -> void:
	if not is_my_turn or is_moving or is_rolling:
		return
	if dice:
		is_rolling = true
		dice._roll()

func _on_dice_roll_finished(roll_value: int) -> void:
	if not is_my_turn or not is_rolling:
		return
	is_rolling = false
	print("Player %d moving %d spaces" % [player_id, roll_value])
	move_steps(roll_value)

func move_steps(steps: int) -> void:
	is_moving = true
	var remaining = steps
	steps_updated.emit(remaining)
	
	for i in range(steps):
		var next_options = current_space.get_next_spaces()
		if next_options.is_empty():
			print("Player %d reached dead end!" % player_id)
			break
			
		current_space = next_options[0]
		remaining -= 1
		
		# Star Space passing check (if passing through before final landing space)
		if current_space.space_type == BoardNode3D.SpaceType.STAR and remaining > 0:
			await check_star_purchase()

		var target_pos = current_space.global_position + get_tile_offset()
		await hop_to_position(target_pos)
		
		steps_updated.emit(remaining)
		
	is_moving = false
	
	# Save player's landed space in GameState
	GameState.save_player_space(player_id, current_space.get_path())
	
	await trigger_space_event()
	
	is_my_turn = false
	turn_finished.emit()

func hop_to_position(target_pos: Vector3) -> void:
	SoundManager.play_hop()
	
	# Smoothly orient player toward the direction of travel
	var dir = (target_pos - global_position)
	dir.y = 0
	if dir.length_squared() > 0.01:
		var look_target = global_position + dir.normalized()
		look_at(look_target, Vector3.UP)
	
	var start_pos = global_position
	var hop_height: float = 0.55
	var hop_duration: float = 1.0 / move_speed
	
	# Custom parabolic hop tween using parallel tweens
	var tween = create_tween()
	tween.set_parallel(true)
	# Horizontal motion
	tween.tween_property(self, "global_position:x", target_pos.x, hop_duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "global_position:z", target_pos.z, hop_duration).set_trans(Tween.TRANS_LINEAR)
	# Vertical parabolic arc (up then down)
	var half_dur = hop_duration * 0.5
	var peak_y = max(start_pos.y, target_pos.y) + hop_height
	tween.tween_property(self, "global_position:y", peak_y, half_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "global_position:y", target_pos.y, half_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	# Squash and stretch upon landing
	var squash_tw = create_tween()
	squash_tw.tween_property(self, "scale", Vector3(1.18, 0.82, 1.18), 0.07)
	squash_tw.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	
	if current_space:
		current_space.pulse()

func check_star_purchase() -> void:
	var coins = GameState.get_player_coins(player_id)
	if coins >= 20:
		GameState.award_coins(player_id, -20)
		GameState.award_stars(player_id, 1)
		SoundManager.play_star()
		spawn_floating_text("★ STAR BOUGHT! (-20 🪙)", Color(1.0, 0.88, 0.1))
		await get_tree().create_timer(1.2).timeout
	else:
		spawn_floating_text("Need 20 Coins for Star!", Color(0.9, 0.9, 0.9))
		await get_tree().create_timer(0.8).timeout

func trigger_space_event() -> void:
	match current_space.space_type:
		BoardNode3D.SpaceType.BLUE:
			GameState.award_coins(player_id, 3)
			SoundManager.play_coin()
			spawn_floating_text("+3 Coins!", Color(0.3, 0.7, 1.0))
		BoardNode3D.SpaceType.RED:
			GameState.award_coins(player_id, -3)
			SoundManager.play_lose_coin()
			spawn_floating_text("-3 Coins!", Color(1.0, 0.3, 0.3))
		BoardNode3D.SpaceType.STAR:
			await check_star_purchase()
		BoardNode3D.SpaceType.EVENT:
			SoundManager.play_event()
			handle_random_event()
		BoardNode3D.SpaceType.SHOP:
			spawn_floating_text("Shop closed for renovations!", Color(0.8, 0.4, 0.9))
			
	await get_tree().create_timer(1.2).timeout

func handle_random_event() -> void:
	var roll = randi_range(1, 3)
	match roll:
		1:
			spawn_floating_text("Lucky Event! +6 Coins!", Color(0.2, 1.0, 0.5))
			GameState.award_coins(player_id, 6)
			SoundManager.play_coin()
		2:
			spawn_floating_text("Coin Shower! Everyone gets +3!", Color(1.0, 0.85, 0.2))
			for p in GameState.player_data:
				GameState.award_coins(p["id"], 3)
			SoundManager.play_coin()
		3:
			spawn_floating_text("Mystery Event! +10 Coins!", Color(0.3, 1.0, 0.8))
			GameState.award_coins(player_id, 10)
			SoundManager.play_coin()

func spawn_floating_text(msg: String, color: Color) -> void:
	var txt = Label3D.new()
	txt.text = msg
	txt.font_size = 40
	txt.pixel_size = 0.012
	txt.modulate = color
	txt.outline_size = 10
	txt.outline_modulate = Color(0, 0, 0, 0.9)
	txt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	txt.global_position = global_position + Vector3(0, 2.0, 0)
	get_parent().add_child(txt)
	
	var tw = txt.create_tween()
	tw.set_parallel(true)
	tw.tween_property(txt, "position:y", txt.position.y + 1.2, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(txt, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(txt.queue_free)
