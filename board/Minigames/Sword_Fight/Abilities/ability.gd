class_name Ability
extends Node

@export var cooldown: float = 10.0   # seconds between uses

var cooldown_left: float = 0.0

# The player using this ability (abilities are created as children of the player)
@onready var player: Node3D = get_parent()


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


# Called by the player when the ability button is pressed.
# HOST DECIDES (online: clients request an ability, the host runs it)
func try_use() -> void:
	if cooldown_left > 0.0 or not can_use():
		return
	cooldown_left = cooldown
	activate()


# Extra conditions for a particular ability. Subclasses override this.
func can_use() -> bool:
	return true


# What the ability actually does. Subclasses override this.
func activate() -> void:
	pass


# The name shown on the HUD. Subclasses override this.
func get_ability_name() -> String:
	return "Ability"
