class_name UndoAbility
extends Ability

@export var rewind_time: float = 2.0     # how far back in time you return, in seconds
@export var latest_use_y: float = -3.0   # can't be used once you've fallen below this height

var clock: float = 0.0
var times: Array[float] = []        # when each position was recorded
var positions: Array[Vector3] = []  # where the player was standing


func _init() -> void:
	cooldown = 20.0


func get_ability_name() -> String:
	return "Undo"


func _physics_process(delta: float) -> void:
	super(delta)   # keeps the cooldown counting down
	clock += delta

	# Remember where we've stood recently (only solid ground counts)
	if player.is_on_floor():
		times.append(clock)
		positions.append(player.global_position)

	# Forget anything older than the rewind window
	while not times.is_empty() and clock - times[0] > rewind_time:
		times.pop_front()
		positions.pop_front()


# Needs a recorded position, and doesn't work once you've fallen too far.
func can_use() -> bool:
	return not positions.is_empty() and player.global_position.y > latest_use_y


func activate() -> void:
	# The oldest remembered position is where we were about rewind_time ago
	player.teleport_to(positions[0])
	times.clear()
	positions.clear()
