class_name DashAbility
extends Ability

@export var dash_distance: float = 5.0   # meters
@export var dash_time: float = 0.2       # seconds the dash lasts


func _init() -> void:
	cooldown = 10.0


func get_ability_name() -> String:
	return "Dash"


# Can't dash out of a deflect, which would cancel its slowdown.
func can_use() -> bool:
	return not player.deflect.is_active()


func activate() -> void:
	# Dash toward where the player is steering, or where they're facing if they aren't
	var direction := Vector3(player.input_dir.x, 0.0, player.input_dir.y)
	if direction == Vector3.ZERO:
		direction = -player.global_transform.basis.z
	player.start_dash(direction, dash_distance, dash_time)
