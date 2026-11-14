class_name MatchManager
extends Node

# winner_id is the winner's player_id, or -1 for a draw.
signal match_ended(winner_id: int)
signal sudden_death_started
# Relays every landed hit, for effects like camera shake.
signal hit_landed(strength: float)

@export var sudden_death_time: float = 10   # seconds until sudden death begins

var match_over: bool = false
var sudden_death: bool = false
var time_elapsed: float = 0.0


func _ready() -> void:
	# Wait one frame so every player has finished its own _ready and joined the group
	await get_tree().process_frame
	for player in get_tree().get_nodes_in_group("players"):
		register_player(player)


# HOST DECIDES (online: only the host runs the clock)
func _physics_process(delta: float) -> void:
	if match_over or sudden_death:
		return
	time_elapsed += delta
	if time_elapsed >= sudden_death_time:
		start_sudden_death()


# Seconds left before sudden death (the HUD reads this).
func get_time_left() -> float:
	return maxf(sudden_death_time - time_elapsed, 0.0)


# Starts watching a player. Also call this for any player added later.
func register_player(player: Player) -> void:
	player.defeated.connect(_on_player_defeated)
	player.was_hit.connect(_on_player_hit)
	if sudden_death:
		player.set_sudden_death(true)   # late arrivals get the same rules


# HOST DECIDES (online: only the host starts sudden death)
func start_sudden_death() -> void:
	sudden_death = true
	for player in get_tree().get_nodes_in_group("players"):
		player.set_sudden_death(true)
	sudden_death_started.emit()


func _on_player_hit(strength: float) -> void:
	hit_landed.emit(strength)


# HOST DECIDES (online: only the host decides when the match ends)
func _on_player_defeated(_loser: Node3D) -> void:
	if match_over:
		return

	# Count who is still standing
	var alive: Array = []
	for player in get_tree().get_nodes_in_group("players"):
		if not player.is_defeated:
			alive.append(player)

	# The match goes on while two or more players remain
	if alive.size() > 1:
		return

	var winner_id := -1   # -1 means a draw (nobody left)
	if alive.size() == 1:
		winner_id = alive[0].player_id
	end_match(winner_id)


func end_match(winner_id: int) -> void:
	match_over = true

	# Freeze every player so nothing keeps happening after the match
	for player in get_tree().get_nodes_in_group("players"):
		player.process_mode = Node.PROCESS_MODE_DISABLED

	match_ended.emit(winner_id)
