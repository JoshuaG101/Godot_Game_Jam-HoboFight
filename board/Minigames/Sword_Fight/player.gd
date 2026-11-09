class_name Player
extends CharacterBody3D

# Announced once when this player is out of the match.
signal defeated(player: Node3D)

@export var player_id: int = 1          # 1 or 2, picks which input actions to read
@export var speed: float = 6.0          # meters per second
@export var turn_speed: float = 12.0    # how fast the player turns to face movement
@export var fall_limit_y: float = -8.0  # falling below this height means defeat

var knockback: Vector3 = Vector3.ZERO   # extra push from hits, decays over time
var is_defeated: bool = false

# Input state: the movement code only reads these, never the keyboard directly.
var input_dir: Vector2 = Vector2.ZERO
var attack_pressed: bool = false
var deflect_pressed: bool = false

# Sword and Deflect have their own scripts (sword.gd, deflect.gd)
@onready var sword: Sword = $Sword
@onready var deflect: Deflect = $Deflect


func _ready() -> void:
	add_to_group("players")   # lets the match manager find every player


func _physics_process(delta: float) -> void:
	gather_input()   # LOCAL PLAYER ONLY (online: remote players get input from the network)
	simulate(delta)

	# Attacking and deflecting can't overlap.
	# HOST DECIDES (online: the host validates attack and deflect requests)
	if deflect_pressed and not sword.is_swinging():
		deflect.try_deflect()
	if attack_pressed and not deflect.is_active():
		sword.try_attack()

	# Falling off the arena means defeat
	if global_position.y < fall_limit_y:
		defeat()


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
	# Map 2D input onto the ground plane (X and Z), slowed while deflecting
	var move := Vector3(input_dir.x, 0.0, input_dir.y) * speed * deflect.get_speed_multiplier()

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


# The one entry point for being hit by a sword. Decides what the hit does.
# HOST DECIDES (online: only the host should run this)
func receive_hit(direction: Vector3, strength: float, attacker: Node3D) -> void:
	# A deflect only works against attackers in front of us
	if deflect.blocks_hit_from(attacker.global_position):
		# Hit cancelled, and the attacker gets a small recoil
		attacker.apply_knockback(-direction, deflect.recoil_strength)
		return
	apply_knockback(direction, strength)
	was_hit.emit(strength)

# Applies a push to this player.
# HOST DECIDES (online: only the host should call this)
func apply_knockback(direction: Vector3, strength: float) -> void:
	direction.y = 0.0   # keep the push along the ground, never upward
	knockback = direction.normalized() * strength


# Takes this player out of the match and announces it. Anything can call this:
# the fall check above now, and hazards in future arenas.
# HOST DECIDES (online: only the host should declare defeats)
func defeat() -> void:
	if is_defeated:
		return   # only announce once
	is_defeated = true
	defeated.emit(self)
	
# Switches this player in or out of sudden death.
# HOST DECIDES (online: the match manager calls this on the host)
func set_sudden_death(active: bool) -> void:
	deflect.set_enabled(not active)   # no deflecting in sudden death
	sword.set_sudden_death(active)    # stronger, glowing sword

# Announced when a hit actually lands (not deflected). Used for effects.
signal was_hit(strength: float)
