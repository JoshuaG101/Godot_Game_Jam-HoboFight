class_name Arena
extends Node3D

# How the camera should frame this arena (each arena can set its own in the Inspector)
@export var camera_position: Vector3 = Vector3(0.0, 18.0, 11.5)
@export var camera_rotation_degrees: Vector3 = Vector3(-70.0, 0.0, 0.0)


# Returns the world position where a given player should start.
# Looks for a Marker3D named Spawn1, Spawn2, ... under SpawnPoints.
func get_spawn_position(player_id: int) -> Vector3:
	var spawn: Node3D = get_node_or_null("SpawnPoints/Spawn%d" % player_id)
	if spawn == null:
		push_warning("Arena has no spawn point named Spawn%d" % player_id)
		return global_position
	return spawn.global_position
