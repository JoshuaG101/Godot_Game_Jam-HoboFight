extends Node

const STARTING_CHARGES: int = 3

const POWER_UPS: Array[String] = [
	"probability_command",
	"rabbits_foot",
	"amped_up",
	"gods_favorite_child",
	"art_block",
	"architectural_prowess"
]

# Temporary player data until the board game selection system is ready.
var players: Dictionary = {
	1:{"power_up": "", "charges": STARTING_CHARGES},
	2:{"power_up": "", "charges": STARTING_CHARGES},
	3:{"power_up": "", "charges": STARTING_CHARGES},
	4:{"power_up": "", "charges": STARTING_CHARGES}
}

func assign_power_up(player_number:int, power_up: String) -> void:
	if not players.has(player_number):
		return
		
	if not POWER_UPS.has(power_up):
		return
		
	players[player_number]["power_up"] = power_up
	players[player_number]["charges"] = STARTING_CHARGES
	

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
