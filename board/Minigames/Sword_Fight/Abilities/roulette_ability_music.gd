class_name RouletteAbility
extends "res://Minigames/Sword_Fight/Abilities/ability.gd"

enum Genre { ROCK, HIP_HOP, JAZZ, POP, CLASSICAL }

# Each genre: how likely it is, and how strong the result is (2 = strong, 1 = medium, 0 = weak)
const GENRES := [
	{"genre": Genre.ROCK, "name": "Rock", "weight": 15, "tier": 2},
	{"genre": Genre.HIP_HOP, "name": "Hip-hop", "weight": 25, "tier": 1},
	{"genre": Genre.JAZZ, "name": "Jazz", "weight": 20, "tier": 1},
	{"genre": Genre.POP, "name": "Pop", "weight": 25, "tier": 0},
	{"genre": Genre.CLASSICAL, "name": "Classical", "weight": 15, "tier": 0},
]

@export var rock_power: float = 1.5          # knockback multiplier
@export var rock_time: float = 6.0
@export var hip_hop_speed: float = 1.4       # speed multiplier
@export var hip_hop_time: float = 5.0
@export var pop_bonus: float = 1.15          # small boost to both speed and knockback
@export var pop_time: float = 5.0
@export var jazz_distance: float = 4.0       # random hop, in meters
@export var classical_radius: float = 6.0    # nearby players are slowed
@export var classical_slow: float = 0.8      # their speed multiplier
@export var classical_time: float = 3.0

var weak_streak: int = 0    # weak rolls in a row (used to soften bad luck)
var result_name: String = ""
var result_left: float = 0.0


func _init() -> void:
	cooldown = 12.0


func get_ability_name() -> String:
	return "Roulette"


func _physics_process(delta: float) -> void:
	super(delta)   # keeps the cooldown counting down
	result_left = maxf(result_left - delta, 0.0)


func get_status_text() -> String:
	if result_left > 0.0:
		return "Rolled: %s" % result_name
	return ""


# HOST DECIDES (online: the host rolls and tells everyone the result)
func activate() -> void:
	var entry := _pick_genre()

	# Track weak rolls so a long unlucky streak can't happen
	if entry["tier"] == 0:
		weak_streak += 1
	else:
		weak_streak = 0

	result_name = entry["name"]
	result_left = 4.0

	match entry["genre"]:
		Genre.ROCK:
			player.apply_power_effect(rock_power, rock_time)
		Genre.HIP_HOP:
			player.apply_speed_effect(hip_hop_speed, hip_hop_time)
		Genre.JAZZ:
			_improvise()
		Genre.POP:
			player.apply_power_effect(pop_bonus, pop_time)
			player.apply_speed_effect(pop_bonus, pop_time)
		Genre.CLASSICAL:
			_soothe_nearby()


# Picks a genre at random, weighted by how likely each one is.
func _pick_genre() -> Dictionary:
	# After two weak rolls in a row, only medium and strong results are possible
	var min_tier := 1 if weak_streak >= 2 else 0

	var total_weight := 0
	for entry in GENRES:
		if entry["tier"] >= min_tier:
			total_weight += entry["weight"]

	# Roll a number, then walk through the genres until we pass it
	var roll := randi_range(0, total_weight - 1)
	for entry in GENRES:
		if entry["tier"] < min_tier:
			continue
		roll -= entry["weight"]
		if roll < 0:
			return entry
	return GENRES[0]   # never reached, but keeps the function complete


# Jazz: a short hop in a random direction. Risky near an edge.
func _improvise() -> void:
	var angle := randf() * TAU
	var direction := Vector3(cos(angle), 0.0, sin(angle))
	player.start_dash(direction, jazz_distance, 0.2)


# Classical: a gentle effect that slows nearby players for a moment.
func _soothe_nearby() -> void:
	for other in get_tree().get_nodes_in_group("players"):
		if other == player:
			continue
		var other_position: Vector3 = other.global_position
		if other_position.distance_to(player.global_position) <= classical_radius:
			other.apply_speed_effect(classical_slow, classical_time)
