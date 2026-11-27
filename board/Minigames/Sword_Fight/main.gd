extends Node3D

const Arena = preload("res://Minigames/Sword_Fight/arenas/arena.gd")
const PlayerScene = preload("res://Minigames/Sword_Fight/player.tscn")
const TutorialScene = preload("res://UI/minigame_tutorial.gd")

# Every arena that can be played. Add more scenes here later, and one is picked at random.
@export var arena_scenes: Array[PackedScene] = []

@onready var camera: Camera3D = $Camera3D

var current_arena: Arena


func _ready() -> void:
	_setup_players()
	load_arena()
	_show_tutorial()


func _show_tutorial() -> void:
	# Freeze players and match timer during tutorial
	var match_mgr = get_node_or_null("MatchManager")
	if match_mgr:
		match_mgr.set_physics_process(false)

	for p in get_tree().get_nodes_in_group("players"):
		p.set_physics_process(false)

	var tut = TutorialScene.new()
	var controls_data: Array[Dictionary] = [
		{
			"player": "Player 1",
			"color": Color(0.18, 0.75, 0.98),
			"controls": [["Move", "WASD"], ["Slash", "F / Space"], ["Deflect", "G Key"], ["Major Ability", "H Key"]]
		},
		{
			"player": "Player 2",
			"color": Color(0.22, 0.86, 0.42),
			"controls": [["Move", "Arrow Keys"], ["Slash", ", / Enter"], ["Deflect", ". Key"], ["Major Ability", "/ Key"]]
		},
		{
			"player": "Player 3",
			"color": Color(1.0, 0.62, 0.16),
			"controls": [["Move", "I J K L"], ["Slash", "U Key"], ["Deflect", "O Key"], ["Major Ability", "P Key"]]
		},
		{
			"player": "Player 4",
			"color": Color(0.95, 0.35, 0.75),
			"controls": [["Move", "Numpad 8456"], ["Slash", "Pad 1 / Z"], ["Deflect", "Pad 2 / X"], ["Major Ability", "Pad 3 / C"]]
		}
	]
	var tips: Array[String] = [
		"Controllers: Left Stick to move, X / R1 to Slash, B to Deflect, Y for Major Ability.",
		"Time your Deflect to bounce away enemy strikes and avoid getting knocked off.",
		"Knock opponents off the arena platform! Last duelist standing wins."
	]
	tut.setup("Sword Fight", "Slash, deflect, and knock all opponents off the arena!", controls_data, tips, 7)
	tut.tutorial_finished.connect(func():
		for p in get_tree().get_nodes_in_group("players"):
			p.set_physics_process(true)
		if match_mgr:
			match_mgr.set_physics_process(true)
	)
	add_child(tut)
	tut.start_tutorial()


func _setup_players() -> void:
	var existing_players: Array[Node] = []
	for node in get_children():
		if node is Player or node.is_in_group("players") or node.name.begins_with("Player"):
			existing_players.append(node)

	var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
	var num_players: int = 4
	if gs and "player_data" in gs and gs.player_data.size() > 0:
		num_players = gs.player_data.size()

	# Remove existing players from the scene tree so we can spawn the exact player count cleanly
	for p in existing_players:
		p.queue_free()

	for i in range(num_players):
		var p_id: int = i + 1
		var new_player: Player = PlayerScene.instantiate()
		new_player.name = "Player%d" % p_id
		new_player.player_id = p_id
		add_child(new_player)


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
