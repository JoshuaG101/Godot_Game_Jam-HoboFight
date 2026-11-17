class_name PRMajorSelect
extends Control
## Every player picks a college major. Each seat browses with its own Left /
## Right and locks in with its own confirm button (Runner: Jump, Buddy: Action);
## moving again unlocks. A Runner gets the major's Runner power, a Buddy its
## Buddy power. Once all four are locked the race begins. Backspace goes back to
## the side select.

signal confirmed(majors: Array)
signal back_requested

## Seconds everyone must stay locked before the screen moves on.
const LOCK_DELAY := 0.5

var input: PRInput
var roster: PRRoster
var picks: Array[int] = [0, 0, 0, 0]
var locked: Array[bool] = [false, false, false, false]

var _cards: Array[PanelContainer] = []
var _card_marks: Array[HBoxContainer] = []
var _seat_panels: Array[PanelContainer] = []
var _all_locked_time := 0.0
var _built := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open(p_input: PRInput, p_roster: PRRoster) -> void:
	input = p_input
	roster = p_roster
	if not _built:
		_build()
	for slot in PRConfig.SLOT_COUNT:
		picks[slot] = roster.majors[slot]
		locked[slot] = false
	_all_locked_time = 0.0
	visible = true
	_refresh()
	for i in _seat_panels.size():
		PRTheme.wipe_in(_seat_panels[i], 0.05 * i)
	for i in _cards.size():
		PRTheme.wipe_in(_cards[i], 0.12 + 0.03 * i)


func close() -> void:
	visible = false


func all_locked() -> bool:
	return not locked.has(false)


func _process(delta: float) -> void:
	if not visible or input == null:
		return
	for slot in PRConfig.SLOT_COUNT:
		if Input.is_action_just_pressed(PRInput.seat_action(slot, "left")):
			step(slot, -1)
		elif Input.is_action_just_pressed(PRInput.seat_action(slot, "right")):
			step(slot, 1)
		elif Input.is_action_just_pressed(PRInput.seat_confirm(slot)):
			lock(slot)
	if Input.is_action_just_pressed(&"pr2_quit"):
		back_requested.emit()
		return
	if all_locked():
		_all_locked_time += delta
		if _all_locked_time >= LOCK_DELAY:
			_all_locked_time = -INF # fire once
			confirmed.emit(picks.duplicate())
	else:
		_all_locked_time = 0.0


func step(slot: int, dir: int) -> void:
	picks[slot] = wrapi(picks[slot] + dir, 0, PRMajors.COUNT)
	locked[slot] = false
	PRSfx.emit(self, "click", -10.0)
	_refresh()


func lock(slot: int) -> void:
	if locked[slot]:
		return
	locked[slot] = true
	PRSfx.emit(self, "ready", -3.0)
	_refresh()
	PRTheme.pop(_seat_panels[slot], 0.08)


# --- Drawing --------------------------------------------------------------------------

func _build() -> void:
	_built = true
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20
	col.offset_right = -20
	col.offset_top = 18
	col.offset_bottom = -14
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.add_child(PROverlays.header("PICK YOUR MAJOR", "Your major is your power. Runners and Buddies get different ones."))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_seat_panels.resize(PRConfig.SLOT_COUNT)
	for team in 2:
		var side := VBoxContainer.new()
		side.add_theme_constant_override("separation", 10)
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for role in 2:
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(250, 150)
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			side.add_child(panel)
			_seat_panels[PRRoster.slot_for(team, role)] = panel
		if team == 1:
			row.add_child(_build_grid())
		row.add_child(side)
	var foot := PRTheme.row(["Each player: your", "Left / Right", "to browse, your", "Jump / Action", "to lock in.", "   ", "[Backspace]", "back"], 13, PRTheme.MUTED)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(foot)


func _build_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in PRMajors.COUNT:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(118, 118)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		var icon := PRTheme.title(PRMajors.icon(m), 40, PRTheme.WHITE)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(icon)
		var name_l := PRTheme.label(str(PRMajors.info(m)["card"]), 12, PRTheme.WHITE, PRTheme.display_font())
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_l)
		var marks := HBoxContainer.new()
		marks.alignment = BoxContainer.ALIGNMENT_CENTER
		marks.add_theme_constant_override("separation", 2)
		marks.custom_minimum_size = Vector2(0, 18)
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(marks)
		grid.add_child(card)
		_cards.append(card)
		_card_marks.append(marks)
	return grid


func _refresh() -> void:
	for m in PRMajors.COUNT:
		var hovered := picks.has(m)
		var sb := PRTheme.panel(PRTheme.GOLD if hovered else PRTheme.NAVY_LIGHT, PRTheme.NAVY, 0.92 if hovered else 0.75, 0.12, 3)
		_cards[m].add_theme_stylebox_override("panel", sb)
		PRTheme.clear(_card_marks[m])
	for slot in PRConfig.SLOT_COUNT:
		var mark := PRTheme.chip("RUN" if PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER else "BUD", PRConfig.team_color(PRRoster.slot_team(slot)), 10)
		_card_marks[picks[slot]].add_child(mark)
		_fill_seat(slot)


func _fill_seat(slot: int) -> void:
	var panel := _seat_panels[slot]
	var team := PRRoster.slot_team(slot)
	var is_runner := PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER
	var color := PRConfig.team_color(team)
	var m := picks[slot]
	var info := PRMajors.info(m)
	panel.add_theme_stylebox_override("panel", PRTheme.panel(color, PRTheme.NAVY, 0.94 if locked[slot] else 0.8))
	PRTheme.clear(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var head := PRTheme.row([
		PRTheme.label("%s %s" % [PRConfig.team_name(team).to_upper(), "RUNNER" if is_runner else "BUDDY"], 13, color, PRTheme.display_font()),
		PRTheme.label("·  " + roster.tag(slot), 12, PRTheme.MUTED),
	], 12)
	box.add_child(head)
	box.add_child(PRTheme.title("%s  %s" % [PRMajors.icon(m), str(info["name"]).to_upper()], 22, PRTheme.WHITE))
	box.add_child(PRTheme.label(str(info["runner" if is_runner else "buddy"]), 15, PRTheme.GOLD, PRTheme.display_font()))
	var desc := PRTheme.label(str(info["runner_text" if is_runner else "buddy_text"]), 13, PRTheme.WHITE)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(220, 0)
	box.add_child(desc)
	if locked[slot]:
		box.add_child(PRTheme.chip("LOCKED IN", color, 13))
	else:
		var keys := input.key_name(slot, "move")
		var confirm := input.key_name(slot, "jump" if is_runner else "action")
		var hint := PRTheme.row(["[%s]" % keys, "pick", "[%s]" % confirm, "lock in"], 12, PRTheme.MUTED, 4)
		box.add_child(hint)
