class_name PRInput
extends Node
## Builds every pr2_* input action in code (so a project.godot merge can't delete
## them), binds each seat to exactly one device, handles hot-plugging, and
## removes all of its actions again when the scene exits.
##
## A seat on a gamepad only listens to that pad, and a pad only drives the seat
## it picked on the side select screen. Seats nobody picked play on the keyboard,
## each with its own keys:
##   Blue Runner   A / D move, W jump, S power, hold Q respawn
##   Gold Runner   ← / → move, ↑ jump, ↓ power, hold Right Shift respawn
##   Blue Buddy    F / H aim, G action, T trap, R switch mode, Y power
##   Gold Buddy    J / L aim, K action, I trap, U switch mode, O power
##
## Runner actions:  pr2_r{team}_left/right/jump/power/respawn
## Buddy actions:   pr2_b{team}_left/right/action/trap/mode/power
## Menu actions:    pr2_menu_up/down/left/right/accept/back (only read while a
##                  menu is open, so they may share keys with gameplay)
## Global actions:  pr2_pause, pr2_confirm, pr2_quit, pr2_debug

## A seat's pad was unplugged mid-game.
signal device_lost(slot: int)
## A seat got a device back (pad replugged, or moved to the keyboard).
signal device_restored(slot: int)
## A pad was plugged in or out (the side select screen rebuilds its cursors).
signal pads_changed

const STICK_DEADZONE := 0.35
const RUNNER_ACTIONS: Array[String] = ["left", "right", "jump", "power", "respawn"]
const BUDDY_ACTIONS: Array[String] = ["left", "right", "action", "trap", "mode", "power"]
const MENU_ACTIONS: Array[String] = ["up", "down", "left", "right", "accept", "back"]
const GLOBAL_ACTIONS: Array[String] = ["pr2_pause", "pr2_confirm", "pr2_quit", "pr2_debug"]

## Keyboard keys per team as [physical keycode, key location].
const RUNNER_KEYS: Array[Dictionary] = [
	{
		"left": [KEY_A, KEY_LOCATION_UNSPECIFIED],
		"right": [KEY_D, KEY_LOCATION_UNSPECIFIED],
		"jump": [KEY_W, KEY_LOCATION_UNSPECIFIED],
		"power": [KEY_S, KEY_LOCATION_UNSPECIFIED],
		"respawn": [KEY_Q, KEY_LOCATION_UNSPECIFIED],
	},
	{
		"left": [KEY_LEFT, KEY_LOCATION_UNSPECIFIED],
		"right": [KEY_RIGHT, KEY_LOCATION_UNSPECIFIED],
		"jump": [KEY_UP, KEY_LOCATION_UNSPECIFIED],
		"power": [KEY_DOWN, KEY_LOCATION_UNSPECIFIED],
		"respawn": [KEY_SHIFT, KEY_LOCATION_RIGHT],
	},
]
const BUDDY_KEYS: Array[Dictionary] = [
	{
		"left": [KEY_F, KEY_LOCATION_UNSPECIFIED],
		"right": [KEY_H, KEY_LOCATION_UNSPECIFIED],
		"action": [KEY_G, KEY_LOCATION_UNSPECIFIED],
		"trap": [KEY_T, KEY_LOCATION_UNSPECIFIED],
		"mode": [KEY_R, KEY_LOCATION_UNSPECIFIED],
		"power": [KEY_Y, KEY_LOCATION_UNSPECIFIED],
	},
	{
		"left": [KEY_J, KEY_LOCATION_UNSPECIFIED],
		"right": [KEY_L, KEY_LOCATION_UNSPECIFIED],
		"action": [KEY_K, KEY_LOCATION_UNSPECIFIED],
		"trap": [KEY_I, KEY_LOCATION_UNSPECIFIED],
		"mode": [KEY_U, KEY_LOCATION_UNSPECIFIED],
		"power": [KEY_O, KEY_LOCATION_UNSPECIFIED],
	},
]
## Pad buttons per role. Left / right are always the left stick and the D-pad.
const PAD_RUNNER := {"jump": JOY_BUTTON_A, "power": JOY_BUTTON_X, "respawn": JOY_BUTTON_Y}
const PAD_BUDDY := {"action": JOY_BUTTON_A, "trap": JOY_BUTTON_B, "mode": JOY_BUTTON_Y, "power": JOY_BUTTON_X}

## Virtual joystick drivers that show up as pads but aren't real controllers.
const IGNORED_PADS: Array[String] = ["vjoy"]
const PS_HINTS: Array[String] = ["ps4", "ps5", "dualshock", "dualsense", "playstation", "wireless controller"]
const VENDOR_SONY := 0x054C

## Bits returned by read_pad_menu().
const MENU_LEFT := 1
const MENU_RIGHT := 2
const MENU_UP := 4
const MENU_DOWN := 8
const MENU_ACCEPT := 16
const MENU_BACK := 32
const MENU_START := 64

var roster: PRRoster = PRRoster.keyboard_only()
## Seats whose pad is unplugged and that wait for it (or for the keyboard).
var lost: Array[bool] = [false, false, false, false]

var _created: Array[String] = []
## Pad id → bits held last time read_pad_menu() looked at it.
var _pad_prev := {}


func _enter_tree() -> void:
	_create_actions()
	bind_roster(roster)
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	for action in _created:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	_created.clear()


# --- Action names -------------------------------------------------------------

static func runner_action(team: int, action: String) -> StringName:
	return StringName("pr2_r%d_%s" % [team, action])


static func buddy_action(team: int, action: String) -> StringName:
	return StringName("pr2_b%d_%s" % [team, action])


static func menu_action(action: String) -> StringName:
	return StringName("pr2_menu_" + action)


## The action a seat uses for `action` ("left", "right", and the role's buttons).
static func seat_action(slot: int, action: String) -> StringName:
	var team := PRRoster.slot_team(slot)
	if PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER:
		return runner_action(team, action)
	return buddy_action(team, action)


## The button a seat presses to confirm on the select screens.
static func seat_confirm(slot: int) -> StringName:
	return seat_action(slot, "jump" if PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER else "action")


# --- Binding ------------------------------------------------------------------

## Binds every seat to the device the roster gives it.
func bind_roster(p_roster: PRRoster) -> void:
	roster = p_roster
	for slot in PRConfig.SLOT_COUNT:
		lost[slot] = false
		_bind_seat(slot)


## Moves a seat whose pad went missing onto its keyboard keys.
func move_seat_to_keyboard(slot: int) -> void:
	roster.devices[slot] = PRRoster.KEYBOARD
	var was_lost := lost[slot]
	lost[slot] = false
	_bind_seat(slot)
	if was_lost:
		device_restored.emit(slot)


## The first seat waiting for its pad, or -1.
func first_lost_seat() -> int:
	return lost.find(true)


func _bind_seat(slot: int) -> void:
	var team := PRRoster.slot_team(slot)
	var is_runner := PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER
	var actions := RUNNER_ACTIONS if is_runner else BUDDY_ACTIONS
	for a in actions:
		InputMap.action_erase_events(seat_action(slot, a))
	if lost[slot]:
		return
	var pad := roster.devices[slot]
	if pad == PRRoster.KEYBOARD:
		var keys: Dictionary = RUNNER_KEYS[team] if is_runner else BUDDY_KEYS[team]
		for a in actions:
			var k: Array = keys[a]
			InputMap.action_add_event(seat_action(slot, a), _key(k[0], k[1]))
		return
	_add_pad_axis(seat_action(slot, "left"), pad, -1.0)
	_add_pad_axis(seat_action(slot, "right"), pad, 1.0)
	_add_pad_button(seat_action(slot, "left"), pad, JOY_BUTTON_DPAD_LEFT)
	_add_pad_button(seat_action(slot, "right"), pad, JOY_BUTTON_DPAD_RIGHT)
	var buttons: Dictionary = PAD_RUNNER if is_runner else PAD_BUDDY
	for a in buttons:
		_add_pad_button(seat_action(slot, a), pad, buttons[a])


# --- On-screen names ------------------------------------------------------------

## The name of the key or button a seat presses for `action`, e.g. "W", "↑", "A".
## "move" gives both directions ("A D", "← →", "Stick").
func key_name(slot: int, action: String) -> String:
	var is_runner := PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER
	var pad := roster.devices[slot]
	if pad != PRRoster.KEYBOARD:
		if action in ["move", "left", "right"]:
			return "Stick"
		var buttons: Dictionary = PAD_RUNNER if is_runner else PAD_BUDDY
		return pad_button_name(pad, buttons.get(action, -1))
	return keyboard_key(slot, action)


## One line with a seat's keyboard keys, e.g. "A D move · W jump · S power · Q respawn".
static func keyboard_legend(slot: int) -> String:
	var actions := ["move", "jump", "power", "respawn"]
	var names := ["move", "jump", "power", "respawn (hold)"]
	if PRRoster.slot_role(slot) == PRConfig.ROLE_BUDDY:
		actions = ["move", "action", "trap", "mode", "power"]
		names = ["aim", "action", "trap", "help ⇄ hinder", "power"]
	var parts: PackedStringArray = []
	for i in actions.size():
		parts.append("%s %s" % [keyboard_key(slot, actions[i]), names[i]])
	return "  ·  ".join(parts)


## The keyboard key a seat uses for `action`, whatever device it is on now.
static func keyboard_key(slot: int, action: String) -> String:
	var team := PRRoster.slot_team(slot)
	var is_runner := PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER
	var keys: Dictionary = RUNNER_KEYS[team] if is_runner else BUDDY_KEYS[team]
	if action == "move":
		return "%s %s" % [_key_text(keys["left"]), _key_text(keys["right"])]
	if not keys.has(action):
		return "?"
	return _key_text(keys[action])


## "Keyboard" or the pad's friendly name, e.g. "PS controller".
func device_name(slot: int) -> String:
	var pad := roster.devices[slot]
	if pad == PRRoster.KEYBOARD:
		return "Keyboard"
	return pad_display_name(pad)


## The controls of one seat as [action label, key] pairs (pause menu, side select).
func controls_for(slot: int) -> Array:
	if PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER:
		return [
			["Move", key_name(slot, "move")],
			["Jump", key_name(slot, "jump")],
			["Power", key_name(slot, "power")],
			["Respawn (hold)", key_name(slot, "respawn")],
		]
	return [
		["Aim / pick machine", key_name(slot, "move")],
		["Action", key_name(slot, "action")],
		["Trap", key_name(slot, "trap")],
		["Help ⇄ Hinder", key_name(slot, "mode")],
		["Power barrel", key_name(slot, "power")],
	]


static func _key_text(k: Array) -> String:
	match k[0]:
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_SHIFT:
			return "R-Shift" if k[1] == KEY_LOCATION_RIGHT else "Shift"
	return OS.get_keycode_string(k[0])


static func is_playstation(pad: int) -> bool:
	var lower := Input.get_joy_name(pad).to_lower()
	for h in PS_HINTS:
		if lower.contains(h):
			return true
	return int(Input.get_joy_info(pad).get("vendor_id", -1)) == VENDOR_SONY


static func pad_button_name(pad: int, button: int) -> String:
	var ps := is_playstation(pad)
	match button:
		JOY_BUTTON_A:
			return "✕" if ps else "A"
		JOY_BUTTON_B:
			return "○" if ps else "B"
		JOY_BUTTON_X:
			return "□" if ps else "X"
		JOY_BUTTON_Y:
			return "△" if ps else "Y"
		JOY_BUTTON_START:
			return "Options" if ps else "Menu"
	return "?"


static func pad_display_name(pad: int) -> String:
	if is_playstation(pad):
		return "PS controller"
	var pad_name := Input.get_joy_name(pad)
	if pad_name.to_lower().contains("xbox") or pad_name.to_lower().contains("xinput"):
		return "Xbox controller"
	return pad_name if pad_name != "" else "Controller"


# --- Pads -----------------------------------------------------------------------

static func is_ignored_pad(id: int) -> bool:
	var pad_name := Input.get_joy_name(id).to_lower()
	for h in IGNORED_PADS:
		if pad_name.contains(h):
			return true
	return false


## Real controllers that are plugged in, lowest id first.
static func connected_pads() -> Array[int]:
	var pads: Array[int] = []
	for id in Input.get_connected_joypads():
		if not is_ignored_pad(id):
			pads.append(id)
	pads.sort()
	return pads


## What a pad pressed since the last call (MENU_* bits). Used by the side select
## screen, before any seat is bound to a pad. Call it once per frame per pad.
func read_pad_menu(pad: int) -> int:
	var held := 0
	var x := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
	if x < -0.5 or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT):
		held |= MENU_LEFT
	if x > 0.5 or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT):
		held |= MENU_RIGHT
	if y < -0.5 or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP):
		held |= MENU_UP
	if y > 0.5 or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN):
		held |= MENU_DOWN
	if Input.is_joy_button_pressed(pad, JOY_BUTTON_A):
		held |= MENU_ACCEPT
	if Input.is_joy_button_pressed(pad, JOY_BUTTON_B):
		held |= MENU_BACK
	if Input.is_joy_button_pressed(pad, JOY_BUTTON_START):
		held |= MENU_START
	var prev: int = _pad_prev.get(pad, held) # a pad seen for the first time presses nothing
	_pad_prev[pad] = held
	return held & ~prev


func describe() -> String:
	var lines: PackedStringArray = []
	var pads: PackedStringArray = []
	for id in connected_pads():
		pads.append("%d: %s" % [id, Input.get_joy_name(id)])
	lines.append("[PlatformRace] Connected pads: [%s]" % ", ".join(pads))
	for slot in PRConfig.SLOT_COUNT:
		lines.append("[PlatformRace] %s → %s" % [PRRoster.role_name(slot), device_name(slot)])
	return "\n".join(lines)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if is_ignored_pad(device):
		return
	_pad_prev.erase(device)
	if connected:
		# Give the pad back to a seat that lost it (Godot usually reuses the id).
		for slot in PRConfig.SLOT_COUNT:
			if lost[slot] and roster.devices[slot] == device:
				lost[slot] = false
				_bind_seat(slot)
				device_restored.emit(slot)
		# A different pad can take over a seat that is still waiting.
		var waiting := first_lost_seat()
		if waiting >= 0 and roster.slot_of_pad(device) < 0:
			roster.devices[waiting] = device
			lost[waiting] = false
			_bind_seat(waiting)
			device_restored.emit(waiting)
	else:
		for slot in PRConfig.SLOT_COUNT:
			if roster.devices[slot] == device and not lost[slot]:
				lost[slot] = true
				_bind_seat(slot)
				device_lost.emit(slot)
	pads_changed.emit()


# --- Action building ----------------------------------------------------------

func _create_actions() -> void:
	for team in 2:
		for a in RUNNER_ACTIONS:
			_add_action(runner_action(team, a), STICK_DEADZONE if a in ["left", "right"] else 0.5)
		for a in BUDDY_ACTIONS:
			_add_action(buddy_action(team, a), STICK_DEADZONE if a in ["left", "right"] else 0.5)
	for a in MENU_ACTIONS:
		_add_action(menu_action(a), 0.5)
	for a in GLOBAL_ACTIONS:
		_add_action(StringName(a))
	# Menus: arrows, WASD, Enter / Esc, and any pad's D-pad, stick, A and B.
	var menu_keys := {"up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S], "left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "accept": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], "back": [KEY_BACKSPACE]}
	for a in menu_keys:
		for k in menu_keys[a]:
			InputMap.action_add_event(menu_action(a), _key(k))
	var menu_pad := {"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "accept": JOY_BUTTON_A, "back": JOY_BUTTON_B}
	for a in menu_pad:
		_add_pad_button(menu_action(a), -1, menu_pad[a])
	_add_pad_axis(menu_action("up"), -1, -1.0, JOY_AXIS_LEFT_Y)
	_add_pad_axis(menu_action("down"), -1, 1.0, JOY_AXIS_LEFT_Y)
	InputMap.action_add_event(&"pr2_pause", _key(KEY_ESCAPE))
	_add_pad_button(&"pr2_pause", -1, JOY_BUTTON_START) # any pad's Menu / Options
	InputMap.action_add_event(&"pr2_confirm", _key(KEY_ENTER))
	InputMap.action_add_event(&"pr2_confirm", _key(KEY_KP_ENTER))
	InputMap.action_add_event(&"pr2_quit", _key(KEY_BACKSPACE))
	InputMap.action_add_event(&"pr2_debug", _key(KEY_F1))


func _add_action(action: StringName, deadzone: float = 0.5) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, deadzone)
	_created.append(String(action))


static func _add_pad_axis(action: StringName, pad: int, direction: float, axis: JoyAxis = JOY_AXIS_LEFT_X) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = pad
	ev.axis = axis
	ev.axis_value = direction
	InputMap.action_add_event(action, ev)


static func _add_pad_button(action: StringName, pad: int, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = pad
	ev.button_index = button
	InputMap.action_add_event(action, ev)


static func _key(keycode: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.device = -1 # all devices: Godot merges every keyboard into one anyway
	ev.physical_keycode = keycode
	ev.location = location
	return ev
