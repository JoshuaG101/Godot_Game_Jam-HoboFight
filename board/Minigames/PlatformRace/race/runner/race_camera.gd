class_name PRRaceCamera
extends Camera3D
## Follows one Runner vertically. The horizontal field of view is fixed
## (KEEP_WIDTH), so the whole course width is visible at any window size.

@export var visible_width := 16.0
@export var follow_speed := 6.0
@export var look_ahead_up := 2.0
@export var look_ahead_down := -1.0
## Follow speed used for a short moment after a respawn.
@export var catch_up_speed := 16.0

var target: PRRunner
var center_x := 0.0
var min_y := -1.0
var max_y := 60.0

var _look := 0.0
var _catch_up := 0.0


func _ready() -> void:
	keep_aspect = KEEP_WIDTH
	projection = PROJECTION_PERSPECTIVE
	fov = 35.0
	near = 0.5
	far = 120.0


func setup(runner: PRRunner, course_center_x: float, low_y: float, high_y: float) -> void:
	target = runner
	center_x = course_center_x
	min_y = low_y
	max_y = high_y
	if not runner.respawned.is_connected(_on_respawned):
		runner.respawned.connect(_on_respawned)
	snap()


func get_distance() -> float:
	return visible_width * 0.5 / tan(deg_to_rad(fov * 0.5))


## Half of the visible height at the course plane (z = 0).
func get_half_height() -> float:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	return visible_width * 0.5 / maxf(aspect, 0.1)


func snap() -> void:
	if target == null:
		return
	position = Vector3(center_x, _desired_y(), get_distance())
	reset_physics_interpolation()


func _process(delta: float) -> void:
	if target == null:
		return
	var vy := target.velocity.y
	var want_look := 0.0
	if vy > 1.0:
		want_look = look_ahead_up
	elif vy < -4.0:
		want_look = look_ahead_down
	_look = lerpf(_look, want_look, 1.0 - exp(-2.5 * delta))
	var speed := follow_speed
	if _catch_up > 0.0:
		_catch_up -= delta
		speed = catch_up_speed
	position.x = center_x
	position.z = get_distance()
	position.y = lerpf(position.y, _desired_y(), 1.0 - exp(-speed * delta))


func _desired_y() -> float:
	var y := target.global_position.y + 1.0 + _look
	var hh := get_half_height()
	var low := min_y + hh
	var high := maxf(max_y - hh, low)
	return clampf(y, low, high)


func _on_respawned(_team: int) -> void:
	_catch_up = 0.6
