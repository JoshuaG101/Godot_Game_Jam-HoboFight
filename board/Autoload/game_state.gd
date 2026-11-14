extends Node

signal player_stats_changed(player_id: int)

const AVAILABLE_MAJORS: Array[Dictionary] = [
	{
		"id": "cs",
		"name": "Computer Science",
		"icon": "💻",
		"tagline": "Runs on caffeine and uncommitted code. Optimizes every hop.",
		"color": Color(0.18, 0.75, 0.98) # Cyan / Electric Blue
	},
	{
		"id": "business",
		"name": "Business & Finance",
		"icon": "💼",
		"tagline": "High-stakes ROI trades and aggressive coin management.",
		"color": Color(0.22, 0.86, 0.42) # Emerald Green
	},
	{
		"id": "arts",
		"name": "Fine Arts",
		"icon": "🎨",
		"tagline": "Chaotic inspiration and expressive, unpredictable energy.",
		"color": Color(0.95, 0.35, 0.75) # Magenta Pink
	},
	{
		"id": "engineering",
		"name": "Engineering",
		"icon": "⚙️",
		"tagline": "Calculated structural durability. Built to survive finals week.",
		"color": Color(1.0, 0.62, 0.16) # Safety Amber / Orange
	},
	{
		"id": "premed",
		"name": "Pre-Med",
		"icon": "🩺",
		"tagline": "Zero sleep, maximum caffeine, and laser-sharp focus under pressure.",
		"color": Color(0.18, 0.88, 0.78) # Mint Teal
	},
	{
		"id": "philosophy",
		"name": "Philosophy",
		"icon": "📖",
		"tagline": "If a die rolls in a forest and no one sees it, did it roll?",
		"color": Color(0.95, 0.32, 0.32) # Crimson Red
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
		"major_id": "business",
		"major": "Business & Finance",
		"icon": "💼",
		"coins": 10,
		"stars": 0,
		"saved_space": "",
		"color": Color(0.22, 0.86, 0.42)
	},
	{
		"id": 3,
		"name": "Player 3",
		"major_id": "engineering",
		"major": "Engineering",
		"icon": "⚙️",
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

var minigame_scenes: Array[String] = [
	"res://Minigames/Jenga/Scenes/JengaGame.tscn",
	"res://Minigames/snowball/SnowballSummit.tscn",
	"res://Minigames/Sword_Fight/main.tscn"
]

func get_available_majors() -> Array[Dictionary]:
	return AVAILABLE_MAJORS

func get_major_by_id(major_id: String) -> Dictionary:
	for m in AVAILABLE_MAJORS:
		if m["id"] == major_id:
			return m
	return AVAILABLE_MAJORS[0]

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
	if minigame_scenes.is_empty():
		return ""
	var valid_scenes = []
	for scene_path in minigame_scenes:
		if ResourceLoader.exists(scene_path):
			valid_scenes.append(scene_path)
	if valid_scenes.is_empty():
		return ""
	return valid_scenes.pick_random()

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
	for p in player_data:
		p["coins"] = 10
		p["stars"] = 0
		p["saved_space"] = ""
		player_stats_changed.emit(p["id"])
