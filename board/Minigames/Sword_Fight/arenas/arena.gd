class_name Arena
extends Node3D

# How the camera should frame this arena (each arena can set its own in the Inspector)
@export var camera_position: Vector3 = Vector3(0.0, 18.0, 11.5)
@export var camera_rotation_degrees: Vector3 = Vector3(-70.0, 0.0, 0.0)


# Returns the world position where a given player should start.
# Looks for a Marker3D named Spawn1, Spawn2, ... under SpawnPoints.
func get_spawn_position(player_id: int) -> Vector3:
	var spawn: Node3D = get_node_or_null("SpawnPoints/Spawn%d" % player_id)
	if spawn != null:
		return spawn.global_position

	# Fallback if no specific Spawn marker exists for this player_id
	var spawn_points := get_node_or_null("SpawnPoints")
	if spawn_points and spawn_points.get_child_count() > 0:
		var child_idx = (player_id - 1) % spawn_points.get_child_count()
		var fallback_node = spawn_points.get_child(child_idx) as Node3D
		if fallback_node:
			return fallback_node.global_position

	# Default coordinate distribution around center if SpawnPoints missing
	var angle = (float(player_id - 1) / 4.0) * TAU
	return global_position + Vector3(cos(angle) * 8.0, 1.0, sin(angle) * 6.0)
