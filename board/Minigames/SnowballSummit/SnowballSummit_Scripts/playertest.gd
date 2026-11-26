extends CharacterBody3D

@export var player_id := 0
@export var base_speed := 7.0
@export var accel := 25.0
@export var turn_speed := 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var character_model: Node3D = null
var anim_player: AnimationPlayer = null


func _ready() -> void:
	add_to_group("players")
	_setup_input()
	_apply_player_appearance()
	_apply_major_powerup()


func _apply_major_powerup() -> void:
	if not GameState or player_id >= GameState.player_data.size():
		return
	var m_id: String = GameState.player_data[player_id].get("major_id", "")
	match m_id.to_lower():
		"cs":
			turn_speed = 18.0
			accel = 32.0
		"business":
			base_speed = 8.2
			accel = 30.0
		"arts":
			set_meta("growth_boost", 1.5)
		"engineering":
			set_meta("bump_mult", 1.5)
			set_meta("knockback_resist", 0.65)
		"premed":
			base_speed = 8.5
		"philosophy":
			set_meta("knockback_resist", 0.5)

func _apply_player_appearance() -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst:
		mesh_inst.visible = false

	var p_color: Color = Color.WHITE
	if GameState:
		p_color = GameState.get_player_color(player_id + 1)
	else:
		var default_colors = [
			Color(0.18, 0.75, 0.98),
			Color(0.22, 0.86, 0.42),
			Color(1.0, 0.62, 0.16),
			Color(0.95, 0.35, 0.75)
		]
		p_color = default_colors[player_id % default_colors.size()]

	var model_scene = GameState.get_player_model_scene(player_id + 1) if GameState else null
	if model_scene:
		character_model = model_scene.instantiate()
		character_model.name = "CharacterModel"
		character_model.rotation.y = PI # Face forward (-Z)
		character_model.scale = Vector3(1.0, 1.0, 1.0)
		add_child(character_model)
		anim_player = character_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player and GameState:
			GameState.setup_character_idle_animation(anim_player)
			play_anim("idle", true)
	elif mesh_inst:
		mesh_inst.visible = true
		var mat = StandardMaterial3D.new()
		mat.albedo_color = p_color
		mesh_inst.material_override = mat

	# Base ring
	var ring = MeshInstance3D.new()
	ring.name = "PlayerRing"
	var torus = TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.52
	torus.rings = 24
	ring.mesh = torus
	ring.position = Vector3(0, 0.05, 0)
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = p_color
	ring_mat.emission_enabled = true
	ring_mat.emission = p_color * 1.5
	ring.material_override = ring_mat
	add_child(ring)

	# Overhead badge
	var overhead = Label3D.new()
	overhead.name = "OverheadBadge"
	overhead.text = "P%d %s" % [player_id + 1, GameState.get_player_name(player_id + 1) if GameState else ""]
	overhead.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overhead.pixel_size = 0.010
	overhead.position = Vector3(0, 2.1, 0)
	overhead.font_size = 32
	overhead.modulate = p_color
	overhead.outline_size = 8
	overhead.outline_modulate = Color.BLACK
	add_child(overhead)


func play_anim(anim_name: String, loop: bool = false, blend_time: float = 0.15) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	var anim = anim_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if anim_player.current_animation != anim_name or not anim_player.is_playing():
		anim_player.play(anim_name, blend_time)


func _physics_process(delta: float) -> void:
	var p := "p%d_" % player_id
	var input := Input.get_vector(p + "left", p + "right", p + "up", p + "down")
	var dir := Vector3(input.x, 0.0, input.y)

	velocity.x = move_toward(velocity.x, dir.x * base_speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * base_speed, accel * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), turn_speed * delta)
		play_anim("push", true, 0.12)
	else:
		play_anim("idle", true, 0.15)

	move_and_slide()

	# Bump / push other players when colliding
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is CharacterBody3D and collider != self:
			var push_dir = -col.get_normal()
			push_dir.y = 0
			if push_dir.length_squared() > 0.001:
				var ball_mult: float = 1.0
				var ball = get_node_or_null("Snowball")
				if ball and "size" in ball:
					ball_mult += ball.size * 0.5
				var my_bump: float = get_meta("bump_mult") if has_meta("bump_mult") else 1.0
				var target_resist: float = collider.get_meta("knockback_resist") if collider.has_meta("knockback_resist") else 1.0
				collider.velocity += push_dir.normalized() * (8.0 * ball_mult * my_bump * target_resist)


var _joy_fire_was_down := false


func _process(_delta: float) -> void:
	var fire := Input.is_action_just_pressed("p%d_fire" % player_id)

	var joy_down := Input.is_joy_button_pressed(player_id, JOY_BUTTON_A) \
		or Input.is_joy_button_pressed(player_id, JOY_BUTTON_RIGHT_SHOULDER)
	if joy_down and not _joy_fire_was_down:
		fire = true
	_joy_fire_was_down = joy_down

	if fire:
		var ball := get_node_or_null("Snowball")
		if ball:
			ball.release()


func _setup_input() -> void:
	var p := "p%d_" % player_id
	_add_axis(p + "left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis(p + "right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis(p + "up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis(p + "down", JOY_AXIS_LEFT_Y, 1.0)
	if player_id == 0:
		_add_key(p + "left", KEY_A)
		_add_key(p + "right", KEY_D)
		_add_key(p + "up", KEY_W)
		_add_key(p + "down", KEY_S)
	elif player_id == 1:
		_add_key(p + "left", KEY_LEFT)
		_add_key(p + "right", KEY_RIGHT)
		_add_key(p + "up", KEY_UP)
		_add_key(p + "down", KEY_DOWN)
	elif player_id == 2:
		_add_key(p + "left", KEY_J)
		_add_key(p + "right", KEY_L)
		_add_key(p + "up", KEY_I)
		_add_key(p + "down", KEY_K)
	elif player_id == 3:
		_add_key(p + "left", KEY_F)
		_add_key(p + "right", KEY_H)
		_add_key(p + "up", KEY_T)
		_add_key(p + "down", KEY_G)

	# Fire (outside the if/elif chain above)
	match player_id:
		0:
			_add_key(p + "fire", KEY_SPACE)
			_add_mouse(p + "fire", MOUSE_BUTTON_LEFT)
		1:
			_add_key(p + "fire", KEY_ENTER)
		2:
			_add_key(p + "fire", KEY_O)
		3:
			_add_key(p + "fire", KEY_Y)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var e := InputEventJoypadMotion.new()
	e.device = player_id
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var e := InputEventKey.new()
	e.physical_keycode = key
	InputMap.action_add_event(action, e)
func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
