class_name PRRoster
extends RefCounted
## Who plays which seat: the input device each seat uses and the major each
## seat picked. Filled in by the side select and major select screens.
##
## Seat order: 0 Blue Runner, 1 Blue Buddy, 2 Gold Runner, 3 Gold Buddy.
## A device of KEYBOARD means that seat plays on its own set of keyboard keys.

const KEYBOARD := -1

const SLOT_BLUE_RUNNER := 0
const SLOT_BLUE_BUDDY := 1
const SLOT_GOLD_RUNNER := 2
const SLOT_GOLD_BUDDY := 3

## Joypad id per seat, or KEYBOARD.
var devices: Array[int] = [KEYBOARD, KEYBOARD, KEYBOARD, KEYBOARD]
## PRMajors.Major per seat.
var majors: Array[int] = [0, 0, 0, 0]


static func keyboard_only() -> PRRoster:
	return PRRoster.new()


## Rebuilds a roster saved with to_dict() (used to carry it across a reload).
static func from_dict(data: Dictionary) -> PRRoster:
	var roster := PRRoster.new()
	var devs: Array = data.get("devices", [])
	var maj: Array = data.get("majors", [])
	for slot in PRConfig.SLOT_COUNT:
		if slot < devs.size():
			roster.devices[slot] = int(devs[slot])
		if slot < maj.size():
			roster.majors[slot] = clampi(int(maj[slot]), 0, PRMajors.COUNT - 1)
	return roster


func to_dict() -> Dictionary:
	return {"devices": devices.duplicate(), "majors": majors.duplicate()}


static func slot_team(slot: int) -> int:
	return PRConfig.TEAM_BLUE if slot < 2 else PRConfig.TEAM_GOLD


static func slot_role(slot: int) -> int:
	return PRConfig.ROLE_RUNNER if slot % 2 == 0 else PRConfig.ROLE_BUDDY


static func slot_for(team: int, role: int) -> int:
	return team * 2 + role


static func role_name(slot: int) -> String:
	return "%s %s" % [PRConfig.team_name(slot_team(slot)), PRConfig.ROLE_NAMES[slot_role(slot)]]


func is_keyboard(slot: int) -> bool:
	return devices[slot] == KEYBOARD


## The seat a joypad plays, or -1.
func slot_of_pad(pad: int) -> int:
	return devices.find(pad) if pad != KEYBOARD else -1


func runner_major(team: int) -> int:
	return majors[slot_for(team, PRConfig.ROLE_RUNNER)]


func buddy_major(team: int) -> int:
	return majors[slot_for(team, PRConfig.ROLE_BUDDY)]


## Short player tag shown over heads and on cards: "KEYS" or "PAD 1".
func tag(slot: int) -> String:
	return "KEYS" if devices[slot] == KEYBOARD else "PAD %d" % (devices[slot] + 1)


func describe() -> String:
	var lines: PackedStringArray = []
	for slot in PRConfig.SLOT_COUNT:
		lines.append("[PlatformRace] %s = %s, %s" % [role_name(slot), tag(slot), PRMajors.major_name(majors[slot])])
	return "\n".join(lines)
