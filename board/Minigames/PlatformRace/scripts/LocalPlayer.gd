
extends CharacterBody3D
class_name LocalPlayer

@export_group("Movement")
@export var input_prefix: String = "p1"
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var wall_jump_force: float = 7.0
@export var wall_jump_lock_time: float = 0.2

@export_group("Character")
@export var visual_model: Node3D
@export var rotation_speed: float = 12.0
@export var facing_offset_degrees: float = 0.0

@export_group("Animations")
@export var idle_animation: StringName = &"Idle"
@export var run_animation: StringName = &"Running_A"
@export var jump_animation: StringName = &"Jump_Start"
@export var fall_animation: StringName = &"Jump_Idle"

@onready var animation_player: AnimationPlayer = find_child(
	"AnimationPlayer", true, false
) as AnimationPlayer

var last_wall_side: int = 0
var wall_jump_lock: float = 0.0


func _physics_process(delta: float) -> void:
	wall_jump_lock = maxf(wall_jump_lock - delta, 0.0)

	if is_on_floor():
		last_wall_side = 0
	else:
		velocity += get_gravity() * delta * 2.0

	_handle_jump()
	_handle_movement()

	move_and_slide()

	_update_facing(delta)
	_update_animation()


func _handle_jump() -> void:
	if not Input.is_action_just_pressed("pr_jump_%s" % input_prefix):
		return

	if is_on_floor():
		velocity.y = jump_velocity
		return

	if not is_on_wall() or wall_jump_lock > 0.0:
		return

	var wall_normal := get_wall_normal()

	# Only allow jumps from walls facing along the Z axis.
	if absf(wall_normal.z) < 0.7:
		return

	var wall_side := 1 if wall_normal.z > 0.0 else -1

	# The next wall jump must come from the opposite wall.
	if wall_side == last_wall_side:
		return

	velocity.y = jump_velocity
	velocity.z = wall_normal.z * wall_jump_force
	last_wall_side = wall_side
	wall_jump_lock = wall_jump_lock_time


func _handle_movement() -> void:
	# Allow the wall jump impulse to push the player away.
	if wall_jump_lock > 0.0:
		return

	var input_axis := Input.get_axis(
		"pr_walk_left_%s" % input_prefix,
		"pr_walk_right_%s" % input_prefix
	)

	if not is_zero_approx(input_axis):
		velocity.z = -input_axis * speed
	else:
		velocity.z = move_toward(velocity.z, 0.0, speed)

	velocity.x = 0.0


func _update_facing(delta: float) -> void:
	if visual_model == null or absf(velocity.z) < 0.1:
		return

	var target_rotation := PI if velocity.z > 0.0 else 0.0
	target_rotation += deg_to_rad(facing_offset_degrees)

	visual_model.rotation.y = lerp_angle(
		visual_model.rotation.y,
		target_rotation,
		minf(rotation_speed * delta, 1.0)
	)


func _update_animation() -> void:
	if animation_player == null:
		return

	var next_animation: StringName = idle_animation

	if not is_on_floor():
		next_animation = jump_animation if velocity.y > 0.0 else fall_animation
	elif absf(velocity.z) > 0.2:
		next_animation = run_animation

	if not animation_player.has_animation(next_animation):
		next_animation = idle_animation

	if animation_player.has_animation(next_animation):
		if animation_player.current_animation != next_animation:
			animation_player.play(next_animation, 0.15)
