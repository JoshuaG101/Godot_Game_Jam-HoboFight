extends Node3D

signal turn_finished
signal steps_updated(remaining: int)

@export var player_id: int = 1
@export var current_space: BoardNode3D
@export var dice: RigidBody3D
@export var move_speed: float = 3.5

var is_moving: bool = false
var is_rolling: bool = false
var has_rolled_this_turn: bool = false
var is_my_turn: bool = false
var overhead_label: Label3D
var character_model: Node3D = null
var anim_player: AnimationPlayer = null

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
		current_space = get_node_or_null("../BoardMap/marioPartyTiles")
		if not current_space:
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
	
	# Hide placeholder capsule mesh
	var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		mesh_inst.visible = false

	# Instantiate the 3D model according to the player's major
	var model_scene = GameState.get_player_model_scene(player_id)
	if model_scene:
		character_model = model_scene.instantiate()
		character_model.name = "CharacterModel"
		character_model.rotation.y = PI # Face forward (-Z)
		character_model.scale = Vector3(0.85, 0.85, 0.85)
		add_child(character_model)
		anim_player = character_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player:
			GameState.setup_character_idle_animation(anim_player)
			play_anim("idle", true)
	elif mesh_inst:
		# Fallback to colored capsule
		mesh_inst.visible = true
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mesh_inst.material_override = mat

	# Add glowing player base ring / pedestal
	var ring = MeshInstance3D.new()
	ring.name = "PlayerRing"
	var torus = TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.45
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

	# Add subtle idle bobbing tween if model has no animation player
	start_idle_animation()

	# Add overhead 3D player badge with major identity
	overhead_label = Label3D.new()
	overhead_label.name = "OverheadBadge"
	overhead_label.text = "P%d %s" % [player_id, GameState.get_player_name(player_id)]
	overhead_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overhead_label.pixel_size = 0.009
	overhead_label.position = Vector3(0, 1.85, 0)
	overhead_label.font_size = 32
	overhead_label.modulate = color
	overhead_label.outline_size = 8
	overhead_label.outline_modulate = Color(0, 0, 0, 0.9)
	add_child(overhead_label)

func play_anim(anim_name: String, loop: bool = false, blend_time: float = 0.15) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	var anim = anim_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if anim_player.current_animation != anim_name or not anim_player.is_playing():
		anim_player.play(anim_name, blend_time)

func stop_anim(blend_time: float = 0.15) -> void:
	if anim_player:
		play_anim("idle", true, blend_time)

func start_idle_animation() -> void:
	# If model has no anim_player (e.g. Music), add subtle bobbing tween
	if character_model and anim_player == null:
		var initial_y = character_model.position.y
		var delay = float(player_id) * 0.25
		var tw = create_tween().set_loops()
		tw.tween_interval(delay)
		tw.tween_property(character_model, "position:y", initial_y + 0.05, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(character_model, "position:y", initial_y, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func start_turn() -> void:
	is_my_turn = true
	is_moving = false
	is_rolling = false
	has_rolled_this_turn = false
	
	# Turn indicator bounce
	if overhead_label:
		var tw = overhead_label.create_tween()
		tw.tween_property(overhead_label, "position:y", 1.85, 0.2).set_trans(Tween.TRANS_BACK)
		tw.tween_property(overhead_label, "position:y", 1.6, 0.2).set_trans(Tween.TRANS_BOUNCE)
		
	print("Player %d's turn started." % player_id)

func _input(event: InputEvent) -> void:
	if not is_my_turn or is_moving or is_rolling or has_rolled_this_turn:
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
	if not is_my_turn or is_moving or is_rolling or has_rolled_this_turn:
		return
	if dice:
		has_rolled_this_turn = true
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
			
		var chosen_tile: BoardNode3D = null
		if next_options.size() > 1:
			chosen_tile = await choose_branch_path(next_options)
		else:
			chosen_tile = next_options[0]

		current_space = chosen_tile
		remaining -= 1
		
		# Star Space passing check (if passing through before final landing space)
		if current_space.space_type == BoardNode3D.SpaceType.STAR and current_space.is_active_star and remaining > 0:
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

func choose_branch_path(options: Array[BoardNode3D]) -> BoardNode3D:
	# Show prompt on HUD for player to choose direction
	var hud = get_node_or_null("../HUD")
	if not hud:
		return options[0]

	# Build branch selection UI
	var branch_dialog = PanelContainer.new()
	branch_dialog.name = "BranchChoiceDialog"
	branch_dialog.anchors_preset = Control.PRESET_CENTER
	branch_dialog.custom_minimum_size = Vector2(360, 160)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.8, 0.2)
	style.content_margin_left = 16
	style.content_margin_top = 16
	style.content_margin_right = 16
	style.content_margin_bottom = 16
	branch_dialog.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	branch_dialog.add_child(vbox)

	var title = Label.new()
	title.text = "CHOOSE YOUR PATH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(title)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	hud.add_child(branch_dialog)

	# Wait for selection
	var selected_ref: Dictionary = {"tile": null}
	for i in range(options.size()):
		var opt = options[i]
		var btn = Button.new()
		# Compute cardinal direction from current tile to option
		var d = opt.global_position - current_space.global_position
		var dir_name = "Forward"
		if abs(d.x) > abs(d.z):
			dir_name = "Right (East)" if d.x > 0 else "Left (West)"
		else:
			dir_name = "Down (South)" if d.z > 0 else "Up (North)"
			
		btn.text = "Path %d: %s" % [i + 1, dir_name]
		btn.custom_minimum_size = Vector2(150, 44)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func():
			selected_ref["tile"] = opt
		)
		btn_row.add_child(btn)

	# Focus first button for keyboard / controller support
	if btn_row.get_child_count() > 0:
		btn_row.get_child(0).grab_focus()

	while selected_ref["tile"] == null:
		await get_tree().process_frame

	branch_dialog.queue_free()
	return selected_ref["tile"]

func hop_to_position(target_pos: Vector3) -> void:
	SoundManager.play_hop()
	play_anim("run", true)
	
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
	stop_anim(0.1)
	
	# Squash and stretch upon landing
	var squash_tw = create_tween()
	squash_tw.tween_property(self, "scale", Vector3(1.18, 0.82, 1.18), 0.07)
	squash_tw.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	
	if current_space:
		current_space.pulse()

func check_star_purchase() -> void:
	if not current_space or not current_space.is_active_star:
		return
	var coins = GameState.get_player_coins(player_id)
	if coins >= 20:
		GameState.award_coins(player_id, -20)
		GameState.award_stars(player_id, 1)
		SoundManager.play_star()
		play_anim("victory", false)
		spawn_floating_text("★ STAR BOUGHT! (-20 🪙)", Color(1.0, 0.88, 0.1))
		
		# Move star to another random star square
		var tm = get_node_or_null("../TurnManager")
		if tm and tm.has_method("relocate_star"):
			tm.relocate_star()
		await get_tree().create_timer(1.2).timeout
		stop_anim(0.2)
	else:
		spawn_floating_text("Need 20 Coins for Star!", Color(0.9, 0.9, 0.9))
		await get_tree().create_timer(0.8).timeout

func trigger_space_event() -> void:
	match current_space.space_type:
		BoardNode3D.SpaceType.BLUE:
			GameState.award_coins(player_id, 3)
			SoundManager.play_coin()
			play_anim("victory", false)
			spawn_floating_text("+3 Coins!", Color(0.3, 0.7, 1.0))
		BoardNode3D.SpaceType.RED:
			GameState.award_coins(player_id, -3)
			SoundManager.play_lose_coin()
			play_anim("block", false)
			spawn_floating_text("-3 Coins!", Color(1.0, 0.3, 0.3))
		BoardNode3D.SpaceType.STAR:
			if current_space.is_active_star:
				await check_star_purchase()
			else:
				spawn_floating_text("Dormant Star Space", Color(0.7, 0.7, 0.7))
		BoardNode3D.SpaceType.EVENT:
			SoundManager.play_event()
			play_anim("victory", false)
			handle_random_event()
		BoardNode3D.SpaceType.SHOP:
			spawn_floating_text("Shop closed for renovations!", Color(0.8, 0.4, 0.9))
			
	await get_tree().create_timer(1.2).timeout
	stop_anim(0.2)

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
	var parent_node = get_parent()
	if not parent_node:
		return
	var txt = Label3D.new()
	txt.text = msg
	txt.font_size = 40
	txt.pixel_size = 0.012
	txt.modulate = color
	txt.outline_size = 10
	txt.outline_modulate = Color(0, 0, 0, 0.9)
	txt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	txt.position = position + Vector3(0, 2.0, 0)
	parent_node.add_child(txt)
	if is_inside_tree():
		txt.global_position = global_position + Vector3(0, 2.0, 0)
	
	var tw = txt.create_tween()
	tw.set_parallel(true)
	tw.tween_property(txt, "position:y", txt.position.y + 1.2, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(txt, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(txt.queue_free)
