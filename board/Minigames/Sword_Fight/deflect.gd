class_name Deflect
extends Node3D

@export var deflect_time: float = 0.3            # seconds the deflect stays active
@export var deflect_cooldown: float = 0.8        # seconds before it can be used again (keep above deflect_time)
@export var recoil_strength: float = 6.0         # small shove on the attacker when deflected (0 = none)
@export var deflect_arc_degrees: float = 120.0   # width of the protected cone in front of the player
@export var move_speed_multiplier: float = 0.15   # movement speed while deflecting (1.0 = no slowdown)
@export var enabled: bool = true                 # switched off for sudden death

var active_left: float = 0.0     # time remaining in the current deflect
var cooldown_left: float = 0.0   # time until another deflect is allowed


func _ready() -> void:
	visible = false   # the shield only shows while deflecting


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)

	# Count the deflect down and hide the shield when it ends
	if active_left > 0.0:
		active_left -= delta
		if active_left <= 0.0:
			visible = false


# Called by the player when the deflect button is pressed.
func try_deflect() -> void:
	if not enabled or cooldown_left > 0.0:
		return
	active_left = deflect_time
	cooldown_left = deflect_cooldown
	visible = true


# True while a deflect is running.
func is_active() -> bool:
	return enabled and active_left > 0.0


# True if a hit coming from this world position would be deflected.
# HOST DECIDES (online: part of hit validation, runs on the host)
func blocks_hit_from(attacker_position: Vector3) -> bool:
	if not is_active():
		return false

	# Direction from us to the attacker, flattened onto the ground, length 1
	var to_attacker := attacker_position - global_position
	to_attacker.y = 0.0
	to_attacker = to_attacker.normalized()

	# The direction we're facing (forward is -Z)
	var facing := -global_transform.basis.z

	# The dot product of two unit vectors is the cosine of the angle between them:
	# 1 = straight ahead, 0 = exactly to the side, -1 = directly behind.
	# The attacker is covered if they're within half the arc on either side of center.
	return facing.dot(to_attacker) >= cos(deg_to_rad(deflect_arc_degrees / 2.0))


# Movement speed multiplier: slowed while deflecting, normal otherwise.
func get_speed_multiplier() -> float:
	if is_active():
		return move_speed_multiplier
	return 1.0


# Turns deflecting on or off for the whole match (sudden death turns it off).
# HOST DECIDES (online: the match manager calls this on the host)
func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		active_left = 0.0   # cancel any deflect in progress
		visible = false
