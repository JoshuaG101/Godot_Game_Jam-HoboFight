class_name Deflect
extends Node3D

@export var deflect_time: float = 0.3       # seconds the deflect stays active
@export var deflect_cooldown: float = 0.8   # seconds before it can be used again (keep above deflect_time)
@export var recoil_strength: float = 6.0    # small shove on the attacker when deflected (0 = none)
@export var enabled: bool = true            # switched off for sudden death

var active_left: float = 0.0     # time remaining in the current deflect
var cooldown_left: float = 0.0   # time until another deflect is allowed


func _ready() -> void:
	visible = false   # the bubble only shows while deflecting


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)

	# Count the deflect down and hide the bubble when it ends
	if active_left > 0.0:
		active_left -= delta
	else:
		visible = false

# Called by the player when the deflect button is pressed.
func try_deflect() -> void:
	print("try_deflect called")
	if not enabled or cooldown_left > 0.0:
		return
	
	#Begin time for swing
	active_left = deflect_time
	
	#Set cooldown
	cooldown_left = deflect_cooldown
	
	visible = true


# True while incoming hits should be cancelled.
func is_active() -> bool:
	return (enabled == true and active_left > 0)



# Turns deflecting on or off for the whole match (sudden death turns it off).
# HOST DECIDES (online: the match manager calls this on the host)
func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		active_left = 0.0   # cancel any deflect in progress
		visible = false
