
extends CharacterBody3D
class_name LocalPlayer

@export var input_prefix: String = "p1"
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta * 2

	if Input.is_action_just_pressed("pr_jump_%s" % input_prefix) and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector(
		"pr_walk_left_%s" % input_prefix,
		"pr_walk_right_%s" % input_prefix,
		"pr_jump_%s" % input_prefix,
		"pr_crouch_%s" % input_prefix
	)
	var direction := (transform.basis * Vector3(input_dir.y, 0.0, input_dir.x)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.y * speed
		velocity.z = -direction.z * speed #Negative Z is intentional
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
