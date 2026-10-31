class_name Sword
extends Area3D

@export var knockback_strength: float = 14.0   # how hard the sword shoves
@export var swing_time: float = 0.25           # seconds the hitbox stays active
@export var attack_cooldown: float = 0.6
@export var swing_arc_degrees: float = 140.0       # seconds between swings (keep above swing_time)

var swing_left: float = 0.0       # time remaining in the current swing
var cooldown_left: float = 0.0    # time until another swing is allowed
var already_hit: Array = []       # bodies hit during this swing

# The node holding the sword (the Player). Used to ignore self and aim knockback.
@onready var wielder: Node3D = get_parent()


func _ready() -> void:
	visible = false
	monitoring = false    # hitbox starts switched off
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)

	#Swing left tells us how much is left in our swing
	if swing_left > 0.0:
		swing_left -= delta

		# Work out the swing's progress, from 0 (just started) to 1 (finished)
		var t := swing_left/maxf(swing_time, 0.0)

		var half_arc := get_half_arc()

		# to the right edge (-half_arc) as t goes from 0 to 1
		
		rotation.y = lerpf(-half_arc, half_arc, t) #returns some value from -degree to +degree based on t


		# Switch the hitbox off when the swing is over (already done for you)
		if swing_left <= 0.0:
			visible = false
			monitoring = false

func get_half_arc() -> float:
	return -deg_to_rad(swing_arc_degrees) / 2

# Called by the player when the attack button is pressed.
# HOST DECIDES (online: clients request an attack, the host runs it)
# HOST DECIDES (online: clients request an attack, the host runs it)
func try_attack() -> void:
	if cooldown_left > 0.0:
		return
	swing_left = swing_time
	cooldown_left = attack_cooldown
	already_hit.clear()

	# Put the blade at the left edge of the arc before the swing begins
	rotation.y = get_half_arc()

	visible = true
	monitoring = true


# Runs when something enters the hitbox.
# HOST DECIDES (online: only the host should apply hits)
func _on_body_entered(body: Node3D) -> void:
	# Ignore ourselves, the floor, and anything that can't be knocked back
	if body == wielder or not body.has_method("receive_hit"):
		return
	# One hit per body per swing
	if body in already_hit:
		return
	already_hit.append(body)

	# Push the target directly away from the wielder
	var direction: Vector3 = body.global_position - wielder.global_position
	body.receive_hit(direction, knockback_strength, wielder)
