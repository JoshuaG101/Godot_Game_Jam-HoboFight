class_name ArtilleryAbility
extends "res://Minigames/Sword_Fight/Abilities/ability.gd"

const ArtilleryStrike = preload("res://Minigames/Sword_Fight/Abilities/artillery_strike_history.gd")

@export var target_distance: float = 10.0   # how far ahead of the player the shells land
@export var strike_radius: float = 3.5      # blast radius, in meters
@export var strike_delay: float = 1.5       # warning time before impact
@export var strike_knockback: float = 24.0  # push strength (roughly 10 m of travel)


func _init() -> void:
	cooldown = 20.0


func get_ability_name() -> String:
	return "Artillery"


# HOST DECIDES (online: the host creates the strike)
func activate() -> void:
	# Aim at the spot ahead of the player (arena floors sit at y = 0)
	var forward: Vector3 = -player.global_transform.basis.z
	var target: Vector3 = player.global_position + forward * target_distance
	target.y = 0.05

	var strike := ArtilleryStrike.new()
	strike.radius = strike_radius
	strike.delay = strike_delay
	strike.knockback_strength = strike_knockback

	# Add it next to the players (in Main), then move it to the target
	player.get_parent().add_child(strike)
	strike.global_position = target
