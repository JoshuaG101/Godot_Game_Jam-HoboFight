class_name PRSideSelect
extends Control
## Before the race, every connected controller picks where it plays, like a
## fighting game's side select:
##   a pad starts in the middle (not playing),
##   Left / Right moves it to the Blue or Gold side,
##   Up / Down picks Runner or Buddy, A locks it in, B steps back.
## A pad only ever drives the seat it locked. Seats no pad takes play on the
## keyboard (Runner 1 on WASD, Runner 2 on the arrows, Buddies on their own keys).
## With no pads at all, the keyboard simply plays all four seats.
## Enter, or Start once every pad on a side is locked, continues.

signal confirmed(devices: Array)

const COL_BLUE := -1
const COL_CENTER := 0
const COL_GOLD := 1

var input: PRInput
## pad id → {"col": int, "role": int, "locked": bool}
var cursors := {}

var _seat_cards: Array[PanelContainer] = []
var _pad_list: VBoxContainer
var _hint: Label
var _footer: HBoxContainer
var _built := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows the screen. `previous` is the last roster's devices, so a pad that
## played before starts locked in the same seat.
func open(p_input: PRInput, previous: Array = []) -> void:
	input = p_input
	if not _built:
		_build()
	cursors.clear()
	for pad in PRInput.connected_pads():
		_add_cursor(pad, previous)
	if not input.pads_changed.is_connected(_on_pads_changed):
		input.pads_changed.connect(_on_pads_changed)
	visible = true
	_refresh()
	for i in _seat_cards.size():
		PRTheme.wipe_in(_seat_cards[i], 0.05 * i)


func close() -> void:
	visible = false
	if input and input.pads_changed.is_connected(_on_pads_changed):
		input.pads_changed.disconnect(_on_pads_changed)


func _process(_delta: float) -> void:
	if not visible or input == null:
		return
	for pad in cursors.keys():
		var bits := input.read_pad_menu(pad)
		if bits & PRInput.MENU_LEFT:
			move(pad, -1)
		if bits & PRInput.MENU_RIGHT:
			move(pad, 1)
		if bits & (PRInput.MENU_UP | PRInput.MENU_DOWN):
			switch_role(pad)
		if bits & PRInput.MENU_ACCEPT:
			lock(pad)
		if bits & PRInput.MENU_BACK:
			back(pad)
		if bits & PRInput.MENU_START:
			try_confirm()
	if Input.is_action_just_pressed(&"pr2_confirm"):
		try_confirm()


# --- Picking --------------------------------------------------------------------------

func move(pad: int, dir: int) -> void:
	var c: Dictionary = cursors[pad]
	var col := clampi(int(c["col"]) + dir, COL_BLUE, COL_GOLD)
	if col == c["col"] and not c["locked"]:
		return
	c["locked"] = false
	c["col"] = col
	if col != COL_CENTER:
		c["role"] = _free_role(_team_of(col), pad, int(c["role"]))
	PRSfx.emit(self, "click", -8.0)
	_refresh()


func switch_role(pad: int) -> void:
	var c: Dictionary = cursors[pad]
	if c["col"] == COL_CENTER or c["locked"]:
		return
	c["role"] = 1 - int(c["role"])
	PRSfx.emit(self, "click", -8.0)
	_refresh()


## Locks a pad into the seat it is on. Returns false if the seat is taken.
func lock(pad: int) -> bool:
	var c: Dictionary = cursors[pad]
	if c["col"] == COL_CENTER or c["locked"]:
		return false
	if seat_taken(seat_of(pad), pad):
		_flash_hint("That seat is taken")
		return false
	c["locked"] = true
	PRSfx.emit(self, "ready", -2.0)
	_refresh()
	if _built:
		PRTheme.pop(_seat_cards[seat_of(pad)], 0.08)
	return true


func back(pad: int) -> void:
	var c: Dictionary = cursors[pad]
	if c["locked"]:
		c["locked"] = false
	elif c["col"] != COL_CENTER:
		c["col"] = COL_CENTER
	PRSfx.emit(self, "click", -8.0)
	_refresh()


## The seat a pad is on, or -1 in the middle.
func seat_of(pad: int) -> int:
	var c: Dictionary = cursors[pad]
	if c["col"] == COL_CENTER:
		return -1
	return PRRoster.slot_for(_team_of(int(c["col"])), int(c["role"]))


func seat_taken(slot: int, except_pad := -2) -> bool:
	for pad in cursors:
		if pad != except_pad and cursors[pad]["locked"] and seat_of(pad) == slot:
			return true
	return false


## True when every pad on a side is locked in (pads in the middle sit out).
func can_confirm() -> bool:
	for pad in cursors:
		if cursors[pad]["col"] != COL_CENTER and not cursors[pad]["locked"]:
			return false
	return true


func try_confirm() -> bool:
	if not can_confirm():
		_flash_hint("Lock in (A) or step back (B) first")
		return false
	PRSfx.emit(self, "go", -6.0)
	confirmed.emit(devices())
	return true


## The device of every seat: the pad locked there, or the keyboard.
func devices() -> Array:
	var out := [PRRoster.KEYBOARD, PRRoster.KEYBOARD, PRRoster.KEYBOARD, PRRoster.KEYBOARD]
	for pad in cursors:
		if cursors[pad]["locked"]:
			out[seat_of(pad)] = pad
	return out


static func _team_of(col: int) -> int:
	return PRConfig.TEAM_BLUE if col == COL_BLUE else PRConfig.TEAM_GOLD


## Prefers `want`, else the other role, whichever no other pad has locked.
func _free_role(team: int, pad: int, want: int) -> int:
	if not seat_taken(PRRoster.slot_for(team, want), pad):
		return want
	return 1 - want


func _add_cursor(pad: int, previous: Array) -> void:
	var c := {"col": COL_CENTER, "role": PRConfig.ROLE_RUNNER, "locked": false}
	var slot := previous.find(pad)
	if slot >= 0:
		c["col"] = COL_BLUE if PRRoster.slot_team(slot) == PRConfig.TEAM_BLUE else COL_GOLD
		c["role"] = PRRoster.slot_role(slot)
		c["locked"] = true
	cursors[pad] = c


func _on_pads_changed() -> void:
	var pads := PRInput.connected_pads()
	for pad in cursors.keys():
		if pad not in pads:
			cursors.erase(pad)
	for pad in pads:
		if not cursors.has(pad):
			_add_cursor(pad, [])
	_refresh()


# --- Drawing --------------------------------------------------------------------------

func _build() -> void:
	_built = true
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 24
	col.offset_right = -24
	col.offset_top = 20
	col.offset_bottom = -16
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.add_child(PROverlays.header("CHOOSE YOUR SIDE", "Controllers pick a seat. The keyboard plays every seat left over."))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_seat_cards.resize(PRConfig.SLOT_COUNT)
	for team in 2:
		var side := VBoxContainer.new()
		side.add_theme_constant_override("separation", 8)
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head := PRTheme.chip("%s TEAM" % PRConfig.team_name(team).to_upper(), PRConfig.team_color(team), 18)
		head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		side.add_child(head)
		for role in 2:
			var slot := PRRoster.slot_for(team, role)
			var card := PanelContainer.new()
			card.custom_minimum_size = Vector2(290, 104)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			side.add_child(card)
			_seat_cards[slot] = card
		if team == 1:
			row.add_child(_build_center())
		row.add_child(side)

	_hint = PRTheme.label("", 15, PRTheme.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)
	_footer = PRTheme.row(["[←]", "[→]", "side", "[↑]", "[↓]", "Runner / Buddy", "[A]", "lock in", "[B]", "back", "   ", "[Enter]", "/", "[Start]", "continue"], 14, PRTheme.WHITE)
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_footer)


func _build_center() -> Control:
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(190, 0)
	center.add_theme_constant_override("separation", 8)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := PRTheme.label("CONTROLLERS", 14, PRTheme.MUTED, PRTheme.display_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(t)
	_pad_list = VBoxContainer.new()
	_pad_list.add_theme_constant_override("separation", 6)
	_pad_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_pad_list)
	return center


func _refresh() -> void:
	if not _built:
		return
	for slot in PRConfig.SLOT_COUNT:
		_fill_seat(slot)
	PRTheme.clear(_pad_list)
	var waiting := 0
	for pad in cursors:
		if cursors[pad]["col"] == COL_CENTER:
			var chip := _pad_chip(pad, PRTheme.NAVY_LIGHT, "")
			chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_pad_list.add_child(chip)
			waiting += 1
	if cursors.is_empty():
		var none := PRTheme.label("No controllers.\nThe keyboard plays\nall four seats.", 15, PRTheme.WHITE)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pad_list.add_child(none)
	elif waiting > 0:
		var tip := PRTheme.label("◀  move  ▶", 13, PRTheme.MUTED)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pad_list.add_child(tip)
	_hint.text = "Ready! Press Enter or Start." if can_confirm() else "Lock in every controller on a side to continue."
	_hint.add_theme_color_override("font_color", PRTheme.GOLD if can_confirm() else PRTheme.MUTED)


func _fill_seat(slot: int) -> void:
	var card := _seat_cards[slot]
	var team := PRRoster.slot_team(slot)
	var color := PRConfig.team_color(team)
	var hover_pad := -2
	var locked_pad := -2
	for pad in cursors:
		if seat_of(pad) == slot:
			if cursors[pad]["locked"]:
				locked_pad = pad
			elif hover_pad == -2:
				hover_pad = pad
	var occupied := locked_pad != -2
	var sb := PRTheme.panel(color, PRTheme.NAVY, 0.92 if occupied else 0.7)
	if hover_pad != -2:
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_width_right = 2
	card.add_theme_stylebox_override("panel", sb)
	PRTheme.clear(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	box.add_child(PRTheme.title(PRConfig.ROLE_NAMES[PRRoster.slot_role(slot)].to_upper(), 22, PRTheme.WHITE))
	if occupied:
		box.add_child(PRTheme.row([_pad_chip(locked_pad, color, "LOCKED IN")], 14))
	elif hover_pad != -2:
		var taken := seat_taken(slot, hover_pad)
		box.add_child(PRTheme.row([_pad_chip(hover_pad, PRTheme.NAVY_LIGHT, ""), "TAKEN" if taken else "press [A]"], 14, PRTheme.MUTED))
	else:
		box.add_child(PRTheme.label("KEYBOARD", 13, PRTheme.MUTED, PRTheme.display_font()))
		var items: Array = []
		for pair in _keyboard_summary(slot):
			items.append("[%s]" % pair[1])
			items.append(pair[0])
		box.add_child(PRTheme.row(items, 12, PRTheme.WHITE, 4))


func _pad_chip(pad: int, color: Color, suffix: String) -> Control:
	var text := "PAD %d  %s" % [pad + 1, PRInput.pad_display_name(pad)]
	if suffix != "":
		text += "  ·  " + suffix
	return PRTheme.chip(text, color, 13)


## Short keyboard legend for a seat card: [[label, key], ...].
static func _keyboard_summary(slot: int) -> Array:
	if PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER:
		return [["move", PRInput.keyboard_key(slot, "move")], ["jump", PRInput.keyboard_key(slot, "jump")], ["power", PRInput.keyboard_key(slot, "power")]]
	return [["aim", PRInput.keyboard_key(slot, "move")], ["act", PRInput.keyboard_key(slot, "action")], ["trap", PRInput.keyboard_key(slot, "trap")], ["⇄", PRInput.keyboard_key(slot, "mode")], ["pow", PRInput.keyboard_key(slot, "power")]]


func _flash_hint(text: String) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", PRConfig.HINDER_COLOR)
	PRTheme.pop(_hint, 0.1)
