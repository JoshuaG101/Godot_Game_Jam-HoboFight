extends CharacterBody3D

@export var player_id := 0
@export var base_speed := 7.0
@export var accel := 25.0
@export var turn_speed := 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("players")
	_setup_input()
	_apply_player_appearance()

func _apply_player_appearance() -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst:
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
		var mat = StandardMaterial3D.new()
		mat.albedo_color = p_color
		mat.metallic = 0.1
		mat.roughness = 0.4
		mesh_inst.material_override = mat


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
				collider.velocity += push_dir.normalized() * (8.0 * ball_mult)


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
