extends Node3D

const Arena = preload("res://Minigames/Sword_Fight/arenas/arena.gd")

# Every arena that can be played. Add more scenes here later, and one is picked at random.
@export var arena_scenes: Array[PackedScene] = []

@onready var camera: Camera3D = $Camera3D

var current_arena: Arena


func _ready() -> void:
	load_arena()


# Loads an arena, moves the players to its spawn points, and frames it with the camera.
# Pass an index to choose a specific arena; the default (-1) picks one at random.
# HOST DECIDES (online: the host picks the index and tells every machine to load it)
func load_arena(index: int = -1) -> void:
	
	if arena_scenes.is_empty():
		push_error("Main has no arenas: add a scene to Arena Scenes in the Inspector")
		return
	if index < 0:
		index = randi() % arena_scenes.size()

	# Remove the previous arena, if there is one (needed once arenas can switch)
	if current_arena != null:
		current_arena.queue_free()

	# Create the arena from its scene file and add it to the game
	current_arena = arena_scenes[index].instantiate()
	add_child(current_arena)

	# Put each player on its spawn point
	for player in get_tree().get_nodes_in_group("players"):
		player.global_position = current_arena.get_spawn_position(player.player_id)

	# Frame the arena
	camera.global_position = current_arena.camera_position
	camera.rotation_degrees = current_arena.camera_rotation_degrees
