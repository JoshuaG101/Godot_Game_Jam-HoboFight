extends Node

const STARTING_CHARGES: int = 3

# Power-up ids. Use these instead of typing the strings by hand,
# e.g. PlayerPowerUps.ART_BLOCK
const PROBABILITY_COMMAND: String = "probability_command"
const RABBITS_FOOT: String = "rabbits_foot"
const AMPED_UP: String = "amped_up"
const GODS_FAVORITE_CHILD: String = "gods_favorite_child"
const ART_BLOCK: String = "art_block"
const ARCHITECTURAL_PROWESS: String = "architectural_prowess"

const POWER_UPS: Array[String] = [
	PROBABILITY_COMMAND,
	RABBITS_FOOT,
	AMPED_UP,
	GODS_FAVORITE_CHILD,
	ART_BLOCK,
	ARCHITECTURAL_PROWESS
]

# Display names and descriptions (HUD, tooltips, etc.).
const POWER_UP_INFO: Dictionary = {
	PROBABILITY_COMMAND: {
		"name": "Probability Command",
		"description": "Highlights the riskiest blocks for a few seconds."
	},
	RABBITS_FOOT: {
		"name": "Rabbit's Foot",
		"description": "Coin flip: a guaranteed safe removal, or the tower explodes."
	},
	AMPED_UP: {
		"name": "Amped Up",
		"description": "Your next removal is protected."
	},
	GODS_FAVORITE_CHILD: {
		"name": "God's Favorite Child",
		"description": "Reveals the safest block to remove."
	},
	ART_BLOCK: {
		"name": "Art Block",
		"description": "Fill an empty space with a temporary block for 3 turns."
	},
	ARCHITECTURAL_PROWESS: {
		"name": "Architectural Prowess",
		"description": "Rewind the last 3 block moves and remove all Art Blocks."
	}
}

# Which power-up each major gets.
# These entries are EXAMPLES. Replace them with your real majors.
# Keys are lowercase; lookups ignore capitalization and extra spaces.
const MAJOR_TO_POWER_UP: Dictionary = {
	"statistics": PROBABILITY_COMMAND,
	"business": RABBITS_FOOT,
	"music": AMPED_UP,
	"theology": GODS_FAVORITE_CHILD,
	"art": ART_BLOCK,
	"architecture": ARCHITECTURAL_PROWESS
}

# Temporary player data until the board game selection system is ready.
var players: Dictionary = {
	1: {"power_up": "", "charges": STARTING_CHARGES},
	2: {"power_up": "", "charges": STARTING_CHARGES},
	3: {"power_up": "", "charges": STARTING_CHARGES},
	4: {"power_up": "", "charges": STARTING_CHARGES}
}


func assign_power_up(player_number: int, power_up: String) -> void:
	if not players.has(player_number):
		return

	if not POWER_UPS.has(power_up):
		return

	players[player_number]["power_up"] = power_up
	players[player_number]["charges"] = STARTING_CHARGES


# Gives the player whichever power-up their major maps to.
# Returns false if the major has no power-up or the player doesn't exist.
func assign_power_up_for_major(player_number: int, major: String) -> bool:
	var power_up: String = get_power_up_for_major(major)

	if power_up == "" or not players.has(player_number):
		return false

	assign_power_up(player_number, power_up)
	return true


func get_power_up_for_major(major: String) -> String:
	var key: String = major.strip_edges().to_lower()

	return MAJOR_TO_POWER_UP.get(key, "")


func is_valid_power_up(power_up: String) -> bool:
	return POWER_UPS.has(power_up)


func get_power_up_name(power_up: String) -> String:
	if not POWER_UP_INFO.has(power_up):
		return "None"

	return POWER_UP_INFO[power_up]["name"]


func get_power_up_description(power_up: String) -> String:
	if not POWER_UP_INFO.has(power_up):
		return ""

	return POWER_UP_INFO[power_up]["description"]


func get_player_power_up(player_number: int) -> String:
	if not players.has(player_number):
		return ""

	return players[player_number]["power_up"]


func get_player_charges(player_number: int) -> int:
	if not players.has(player_number):
		return 0

	return players[player_number]["charges"]


func use_charge(player_number: int) -> bool:
	if not players.has(player_number):
		return false

	if players[player_number]["charges"] <= 0:
		return false

	players[player_number]["charges"] -= 1
	return true


func reset_all_players() -> void:
	for player_number in players:
		players[player_number]["power_up"] = ""
		players[player_number]["charges"] = STARTING_CHARGES
