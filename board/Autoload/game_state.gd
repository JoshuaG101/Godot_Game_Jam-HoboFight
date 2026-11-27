extends Node

signal player_stats_changed(player_id: int)

const AVAILABLE_MAJORS: Array[Dictionary] = [
	{
		"id": "cs",
		"name": "Computer Science",
		"icon": "💻",
		"tagline": "Runs on caffeine and uncommitted code. Optimizes every hop.",
		"color": Color(0.18, 0.75, 0.98), # Cyan / Electric Blue
		"scene_path": "res://comp_sci_animations.tscn"
	},
	{
		"id": "arts",
		"name": "Fine Arts",
		"icon": "🎨",
		"tagline": "Chaotic inspiration and expressive, unpredictable energy.",
		"color": Color(0.95, 0.35, 0.75), # Magenta Pink
		"scene_path": "res://art_animations.tscn"
	},
	{
		"id": "anthro",
		"name": "Anthropology",
		"icon": "🏛️",
		"tagline": "Excavates ancient lore and calculated structural survival.",
		"color": Color(1.0, 0.62, 0.16), # Safety Amber / Orange
		"scene_path": "res://antrho_animations.tscn"
	},
	{
		"id": "history",
		"name": "History",
		"icon": "📜",
		"tagline": "Tracks the past to predict and conquer every encounter.",
		"color": Color(0.22, 0.86, 0.42), # Emerald Green
		"scene_path": "res://history_animations.tscn"
	},
	{
		"id": "music",
		"name": "Music",
		"icon": "🎵",
		"tagline": "Up-tempo rhythm, high frequencies, and laser focus.",
		"color": Color(0.72, 0.45, 0.98), # Violet / Purple
		"scene_path": "res://music_animations.tscn"
	},
	{
		"id": "religion",
		"name": "Religion & Philosophy",
		"icon": "✨",
		"tagline": "Leaps of faith, cosmic contemplation, and divine fortune.",
		"color": Color(0.95, 0.32, 0.32), # Crimson Red
		"scene_path": "res://religion_animations.tscn"
	}
]

var player_data: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Player 1",
		"major_id": "cs",
		"major": "Computer Science",
		"icon": "💻",
		"coins": 10,
		"stars": 0,
		"saved_space": "",
		"color": Color(0.18, 0.75, 0.98)
	},
	{
		"id": 2,
		"name": "Player 2",
		"major_id": "history",
		"major": "History",
		"icon": "📜",
		"coins": 10,
		"stars": 0,
		"saved_space": "",
		"color": Color(0.22, 0.86, 0.42)
	},
	{
		"id": 3,
		"name": "Player 3",
		"major_id": "anthro",
		"major": "Anthropology",
		"icon": "🏛️",
		"coins": 10,
		"stars": 0,
		"saved_space": "",
		"color": Color(1.0, 0.62, 0.16)
	},
	{
		"id": 4,
		"name": "Player 4",
		"major_id": "arts",
		"major": "Fine Arts",
		"icon": "🎨",
		"coins": 10,
		"stars": 0,
		"saved_space": "",
		"color": Color(0.95, 0.35, 0.75)
	},
]

var current_round: int = 1
var max_rounds: int = 5
var current_minigame_index: int = 0

var minigame_scenes: Array[String] = [
	"res://Minigames/Jenga/Scenes/JengaGame.tscn",
	"res://Minigames/Sword_Fight/main.tscn",
	"res://Minigames/PlatformRace/race/platform_race.tscn",
	"res://Minigames/SnowballSummit/Scenes/SnowballSummit.tscn"
]

func _ready() -> void:
	# Enable fullscreen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _unhandled_input(event: InputEvent) -> void:
	# F11 or Alt+Enter toggles fullscreen
	if event is InputEventKey and event.is_pressed() and not event.echo:
		if event.keycode == KEY_F11 or (event.alt_pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)):
			toggle_fullscreen()

func toggle_fullscreen() -> void:
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func get_available_majors() -> Array[Dictionary]:
	return AVAILABLE_MAJORS

func get_major_by_id(major_id: String) -> Dictionary:
	var mid = major_id.to_lower().strip_edges()
	match mid:
		"business", "business & finance":
			mid = "history"
		"engineering":
			mid = "anthro"
		"premed", "pre-med":
			mid = "music"
		"philosophy", "theology":
			mid = "religion"
		"art":
			mid = "arts"
		"anthropology":
			mid = "anthro"
		"computer science":
			mid = "cs"

	for m in AVAILABLE_MAJORS:
		if m["id"] == mid:
			return m
	return AVAILABLE_MAJORS[0]

func get_model_scene_path_for_major(major_id: String) -> String:
	var m = get_major_by_id(major_id)
	return m.get("scene_path", "res://comp_sci_animations.tscn")

func get_player_model_path(player_id: int) -> String:
	for p in player_data:
		if p["id"] == player_id:
			return get_model_scene_path_for_major(p.get("major_id", "cs"))
	return "res://comp_sci_animations.tscn"

func get_player_model_scene(player_id: int) -> PackedScene:
	var path = get_player_model_path(player_id)
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null

static func setup_character_idle_animation(anim_player: AnimationPlayer) -> void:
	if not anim_player or not anim_player.has_animation("jump"):
		return
	if anim_player.has_animation("idle"):
		return
	var jump_anim = anim_player.get_animation("jump")
	if not jump_anim:
		return
	var idle_anim = Animation.new()
	idle_anim.length = 0.5
	idle_anim.loop_mode = Animation.LOOP_LINEAR
	for t in range(jump_anim.get_track_count()):
		var track_path = jump_anim.track_get_path(t)
		var track_type = jump_anim.track_get_type(t)
		if jump_anim.track_get_key_count(t) > 0:
			var idx = idle_anim.add_track(track_type)
			idle_anim.track_set_path(idx, track_path)
			var val = jump_anim.track_get_key_value(t, 0)
			idle_anim.track_insert_key(idx, 0.0, val)
	var lib = anim_player.get_animation_library("")
	if lib:
		lib.add_animation("idle", idle_anim)

func set_player_major(player_id: int, major_id: String) -> void:
	var major_info = get_major_by_id(major_id)
	for p in player_data:
		if p["id"] == player_id:
			p["major_id"] = major_info["id"]
			p["major"] = major_info["name"]
			p["icon"] = major_info["icon"]
			p["color"] = major_info["color"]
			print("[GameState] Set Player %d major to %s" % [player_id, major_info["name"]])
			player_stats_changed.emit(player_id)
			break

func randomize_all_majors() -> void:
	var pool = AVAILABLE_MAJORS.duplicate()
	pool.shuffle()
	for i in range(player_data.size()):
		var m = pool[i % pool.size()]
		set_player_major(player_data[i]["id"], m["id"])

func get_random_minigame() -> String:
	return get_next_minigame()

func get_next_minigame() -> String:
	if minigame_scenes.is_empty():
		return ""
	var valid_scenes = []
	for scene_path in minigame_scenes:
		if ResourceLoader.exists(scene_path):
			valid_scenes.append(scene_path)
	if valid_scenes.is_empty():
		return ""
	var picked_scene = valid_scenes[current_minigame_index % valid_scenes.size()]
	current_minigame_index += 1
	return picked_scene

func award_coins(player_id: int, amount: int) -> void:
	for p in player_data:
		if p["id"] == player_id:
			p["coins"] = max(0, p["coins"] + amount)
			print("[GameState] Player %d now has %d coins" % [player_id, p["coins"]])
			player_stats_changed.emit(player_id)
			break

func award_stars(player_id: int, amount: int) -> void:
	for p in player_data:
		if p["id"] == player_id:
			p["stars"] = max(0, p["stars"] + amount)
			print("[GameState] Player %d now has %d stars" % [player_id, p["stars"]])
			player_stats_changed.emit(player_id)
			break

func get_player_coins(player_id: int) -> int:
	for p in player_data:
		if p["id"] == player_id:
			return p["coins"]
	return 0

func get_player_stars(player_id: int) -> int:
	for p in player_data:
		if p["id"] == player_id:
			return p["stars"]
	return 0

func get_player_color(player_id: int) -> Color:
	for p in player_data:
		if p["id"] == player_id:
			return p["color"]
	return Color.WHITE

func get_player_name(player_id: int) -> String:
	for p in player_data:
		if p["id"] == player_id:
			return "%s %s" % [p.get("icon", ""), p.get("major", "Player %d" % player_id)]
	return "Player %d" % player_id

func save_player_space(player_id: int, space_path: NodePath) -> void:
	for p in player_data:
		if p["id"] == player_id:
			p["saved_space"] = str(space_path)
			break

func get_player_space(player_id: int) -> String:
	for p in player_data:
		if p["id"] == player_id:
			return p.get("saved_space", "")
	return ""

func get_ranked_players() -> Array[Dictionary]:
	var ranked: Array[Dictionary] = player_data.duplicate(true)
	ranked.sort_custom(func(a, b):
		if a["stars"] != b["stars"]:
			return a["stars"] > b["stars"]
		return a["coins"] > b["coins"]
	)
	return ranked

func reset_game() -> void:
	current_round = 1
	current_minigame_index = 0
	for p in player_data:
		p["coins"] = 10
		p["stars"] = 0
		p["saved_space"] = ""
		player_stats_changed.emit(p["id"])
