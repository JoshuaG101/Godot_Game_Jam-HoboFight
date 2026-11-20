extends CharacterBody3D

@export var player_id := 0
@export var base_speed := 7.0
@export var accel := 25.0
@export var turn_speed := 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	_setup_input()


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
