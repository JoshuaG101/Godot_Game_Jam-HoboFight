extends Camera3D

# Drag the MatchManager node into this slot in the Inspector
@export var match_manager: MatchManager
@export var shake_per_strength: float = 0.012   # meters of shake per unit of knockback
@export var max_shake: float = 0.5              # upper limit, in meters
@export var shake_decay: float = 0.8            # how fast the shake dies down, per second

var shake: float = 0.0
var base_position: Vector3


# LOCAL ONLY: purely cosmetic (online: every player's machine runs its own copy)
func _ready() -> void:
	assert(match_manager != null, "Assign the Match Manager in the Inspector")
	base_position = position   # remember where the camera normally sits
	match_manager.hit_landed.connect(_on_hit_landed)


func _process(delta: float) -> void:
	shake = move_toward(shake, 0.0, shake_decay * delta)
	# Jitter the camera by a random amount up to "shake" meters, or rest at base
	var offset := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	position = base_position + offset * shake


func _on_hit_landed(strength: float) -> void:
	# Only shake in sudden death (delete these two lines to shake on every hit)
	if not match_manager.sudden_death:
		return
	shake = minf(shake + strength * shake_per_strength, max_shake)
