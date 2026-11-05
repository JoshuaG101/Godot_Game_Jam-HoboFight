extends CharacterBody3D

@export var player_id: int = 1          # 1 or 2, picks which input actions to read
@export var speed: float = 6.0          # meters per second
@export var turn_speed: float = 12.0    # how fast the player turns to face movement

var knockback: Vector3 = Vector3.ZERO   # extra push from hits, decays over time

# Input state: the movement code only reads these, never the keyboard directly.
var input_dir: Vector2 = Vector2.ZERO
var attack_pressed: bool = false
var deflect_pressed: bool = false

# The sword has its own script (sword.gd) that handles swinging and hits
@onready var sword: Sword = $Sword
@onready var deflect: Deflect = $Deflect


func _physics_process(delta: float) -> void:
	gather_input()   # LOCAL PLAYER ONLY (online: remote players get input from the network)
	simulate(delta)

	if attack_pressed:
		sword.try_attack()
	if deflect_pressed:
		deflect.try_deflect()


# Reads this player's keyboard and stores it in the state variables above.
func gather_input() -> void:
	input_dir = Input.get_vector(
		"p%d_left" % player_id, "p%d_right" % player_id,
		"p%d_up" % player_id, "p%d_down" % player_id)
	# "just_pressed" is true only on the frame the key goes down
	attack_pressed = Input.is_action_just_pressed("p%d_attack" % player_id)
	deflect_pressed = Input.is_action_just_pressed("p%d_deflect" % player_id)


# All movement logic, using only the state variables above.
func simulate(delta: float) -> void:
	# Map 2D input onto the ground plane (X and Z)
	var move := Vector3(input_dir.x, 0.0, input_dir.y) * speed

	# Set horizontal velocity only, so gravity (y) isn't overwritten
	velocity.x = move.x + knockback.x
	velocity.z = move.z + knockback.z

	# Fall when not on the ground
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Slow the knockback toward zero
	knockback = knockback.move_toward(Vector3.ZERO, 30.0 * delta)

	# Smoothly turn to face the movement direction
	if input_dir != Vector2.ZERO:
		var target_angle := atan2(-move.x, -move.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)

	# Move, sliding along any collisions
	move_and_slide()

# HOST DECIDES (online: only the host should run this)
func receive_hit(direction: Vector3, strength: float, attacker: Node3D) -> void:
	
	if deflect.is_active():
		attacker.apply_knockback(-direction, deflect.recoil_strength)
		return
	
	apply_knockback(direction, strength)


# The one place hits are applied.
# HOST DECIDES (online: only the host should call this)
func apply_knockback(direction: Vector3, strength: float) -> void:
	direction.y = 0.0   # keep the push along the ground, never upward
	knockback = direction.normalized() * strength
