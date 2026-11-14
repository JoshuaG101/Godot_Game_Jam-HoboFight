class_name Sword
extends Area3D

@export var knockback_strength: float = 19.0   # how hard the sword shoves
@export var swing_time: float = 0.25           # seconds the hitbox stays active
@export var attack_cooldown: float = 0.6       # seconds between swings (keep above swing_time)
@export var swing_arc_degrees: float = 140.0   # total width of the swing
@export var sudden_death_power: float = 1.5    # knockback multiplier during sudden death

var swing_left: float = 0.0        # time remaining in the current swing
var cooldown_left: float = 0.0     # time until another swing is allowed
var already_hit: Array = []        # bodies hit during this swing
var power_multiplier: float = 1.0  # 1.0 normally, higher in sudden death

# The node holding the sword (the Player). Used to ignore self and aim knockback.
@onready var wielder: Node3D = get_parent()
# The visible blade (the MeshInstance3D under the Sword node)
@onready var blade: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	visible = false
	monitoring = false    # hitbox starts switched off
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)

	if swing_left > 0.0:
		swing_left -= delta

		# t goes from 0 to 1 over the course of the swing
		var t := 1.0 - maxf(swing_left, 0.0) / swing_time
		var half_arc := deg_to_rad(swing_arc_degrees) / 2.0

		# Sweep from the left side to the right side (rotation is local to the player)
		rotation.y = lerpf(half_arc, -half_arc, t)

		# Switch the hitbox off when the swing is over
		if swing_left <= 0.0:
			visible = false
			monitoring = false


# Called by the player when the attack button is pressed.
# HOST DECIDES (online: clients request an attack, the host runs it)
func try_attack() -> void:
	if cooldown_left > 0.0:
		return
	swing_left = swing_time
	cooldown_left = attack_cooldown
	already_hit.clear()

	# Start the blade at the left edge of the arc
	rotation.y = deg_to_rad(swing_arc_degrees) / 2.0
	visible = true
	monitoring = true


# True while a swing is in progress (the hitbox is active).
func is_swinging() -> bool:
	return swing_left > 0.0


# Turns sudden-death power on or off: stronger hits and a glowing blade.
func set_sudden_death(active: bool) -> void:
	power_multiplier = sudden_death_power if active else 1.0

	if active:
		# A red, glowing material that replaces the blade's normal one
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.2, 0.1)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.25, 0.1)
		glow.emission_energy_multiplier = 2.0
		blade.material_override = glow
	else:
		blade.material_override = null   # back to the normal look


# Runs when something enters the hitbox.
# HOST DECIDES (online: only the host should apply hits)
func _on_body_entered(body: Node3D) -> void:
	# Ignore ourselves, the floor, and anything that can't be hit
	if body == wielder or not body.has_method("receive_hit"):
		return
	# One hit per body per swing
	if body in already_hit:
		return
	already_hit.append(body)

	# Report the hit; the target decides what it does (knockback, deflect, ...)
	var direction: Vector3 = body.global_position - wielder.global_position
	body.receive_hit(direction, knockback_strength * power_multiplier, wielder)
