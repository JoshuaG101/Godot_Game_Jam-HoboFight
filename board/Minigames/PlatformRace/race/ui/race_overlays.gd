class_name PROverlays
extends CanvasLayer
## Full-screen screens, built in code: side select, major select, the VS
## splash, the countdown, pause (with the controls page), a notice (pad
## unplugged) and results. No game rules live here; PRRaceManager decides when
## each one shows. Runs while the tree is paused.

## A pause / results menu option was picked: "resume", "restart", "setup",
## "rematch" or "quit". ("controls" is handled here.)
signal menu_chosen(id: String)

var sides: PRSideSelect
var majors: PRMajorSelect

var _root: Control
var _backdrop: Backdrop
var _big: Label
var _big_time := 0.0
var _big_total := 1.0
var _versus: Control
var _pause: Control
var _pause_menu: PRMenuList
var _controls: Control
var _controls_grid: GridContainer
var _notice: Control
var _notice_title: Label
var _notice_body: Label
var _results: Control
var _results_menu: PRMenuList
var _input: PRInput
var _roster: PRRoster


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_backdrop = Backdrop.new()
	_root.add_child(_backdrop)

	sides = PRSideSelect.new()
	_root.add_child(sides)
	majors = PRMajorSelect.new()
	_root.add_child(majors)
	_versus = _screen()
	_pause = _screen()
	_controls = _screen()
	_notice = _screen()
	_results = _screen()
	_build_pause()
	_build_controls()
	_build_notice()

	_big = PRTheme.title("", 160, PRTheme.WHITE, 24)
	_big.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.visible = false
	_root.add_child(_big)


func bind(p_input: PRInput, p_roster: PRRoster) -> void:
	_input = p_input
	_roster = p_roster


func _screen() -> Control:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	_root.add_child(c)
	return c


func _process(delta: float) -> void:
	_backdrop.visible = sides.visible or majors.visible or _versus.visible or _pause.visible or _controls.visible or _notice.visible or _results.visible
	if _big_time > 0.0:
		_big_time -= delta
		var t := 1.0 - _big_time / _big_total
		_big.pivot_offset = _big.size * 0.5
		var s := 1.0 + 0.4 * pow(1.0 - clampf(t * 3.0, 0.0, 1.0), 2.0)
		_big.scale = Vector2(s, s)
		_big.modulate.a = clampf(_big_time / 0.25, 0.0, 1.0)
		if _big_time <= 0.0:
			_big.visible = false
	if _controls.visible and Input.is_action_just_pressed(PRInput.menu_action("back")):
		_close_controls()


func hide_all() -> void:
	sides.close()
	majors.close()
	for c in [_versus, _pause, _controls, _notice, _results]:
		(c as Control).visible = false


## A slanted title bar with a gold underline, used at the top of every screen.
static func header(title_text: String, subtitle := "") -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := PRTheme.title(title_text, 40, PRTheme.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(220, 5)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", PRTheme.fill(PRTheme.GOLD, 1.2, 0, 0))
	box.add_child(bar)
	if subtitle != "":
		var s := PRTheme.label(subtitle, 15, PRTheme.MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)
	return box


# --- Countdown / big text ---------------------------------------------------------

## Huge centred text, e.g. countdown numbers or "GO!".
func show_big(text: String, color := PRTheme.WHITE, seconds := 0.9) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", color)
	_big.visible = true
	_big_time = seconds
	_big_total = seconds


# --- Versus ---------------------------------------------------------------------------

## The two teams slide in from the sides with their majors, "VS" pops between.
func show_versus(roster: PRRoster) -> void:
	PRTheme.clear(_versus)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_versus.add_child(row)
	for team in 2:
		var color := PRConfig.team_color(team)
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(330, 0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := PRTheme.panel(color, PRTheme.NAVY, 0.95, PRTheme.LEAN, 8)
		sb.content_margin_top = 14
		sb.content_margin_bottom = 16
		sb.content_margin_left = 26
		p.add_theme_stylebox_override("panel", sb)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(box)
		box.add_child(PRTheme.title(PRConfig.team_name(team).to_upper(), 54, color))
		for role in 2:
			var slot := PRRoster.slot_for(team, role)
			var m := roster.majors[slot]
			box.add_child(PRTheme.row([
				PRTheme.chip(PRConfig.ROLE_NAMES[role].to_upper(), color, 13),
				PRTheme.label("%s %s" % [PRMajors.icon(m), PRMajors.major_name(m)], 18, PRTheme.WHITE, PRTheme.display_font()),
				PRTheme.label(roster.tag(slot), 12, PRTheme.MUTED),
			], 14))
		if team == 1:
			var vs := PRTheme.title("VS", 84, PRTheme.GOLD, 10)
			vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(vs)
			PRTheme.pop(vs, 0.6, 0.35)
		row.add_child(p)
		PRTheme.wipe_in(p, 0.08 * team, 0.3)
	_versus.visible = true


func hide_versus() -> void:
	_versus.visible = false


# --- Pause + controls -------------------------------------------------------------------

func _build_pause() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.add_child(col)
	col.add_child(header("PAUSED"))
	_pause_menu = PRMenuList.new()
	_pause_menu.chosen.connect(_on_pause_chosen)
	_pause_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_pause_menu)
	var hint := PRTheme.row(["[Esc]", "resume"], 13, PRTheme.MUTED)
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(hint)


func show_pause(on: bool) -> void:
	_pause.visible = on
	_controls.visible = false
	if on:
		_pause_menu.set_items([["resume", "RESUME"], ["controls", "CONTROLS"], ["restart", "RESTART"], ["setup", "CHANGE SIDES & MAJORS"], ["quit", "QUIT"]])


func is_pause_visible() -> bool:
	return _pause.visible


func is_controls_visible() -> bool:
	return _controls.visible


func _on_pause_chosen(id: String) -> void:
	if id == "controls":
		show_controls()
	else:
		menu_chosen.emit(id)


func _build_controls() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.add_child(col)
	col.add_child(header("CONTROLS", "Every seat has its own keys or its own controller."))
	_controls_grid = GridContainer.new()
	_controls_grid.columns = 2
	_controls_grid.add_theme_constant_override("h_separation", 18)
	_controls_grid.add_theme_constant_override("v_separation", 12)
	_controls_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_controls_grid)
	var hint := PRTheme.row(["[Backspace]", "/", "[B]", "back"], 13, PRTheme.MUTED)
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(hint)


## The controls page: one card per seat with that seat's device and keys.
func show_controls() -> void:
	PRTheme.clear(_controls_grid)
	# Grid order: Blue Runner, Gold Runner / Blue Buddy, Gold Buddy.
	for slot in [0, 2, 1, 3]:
		_controls_grid.add_child(_controls_card(slot))
	_pause.visible = false
	_controls.visible = true


func _controls_card(slot: int) -> Control:
	var team := PRRoster.slot_team(slot)
	var color := PRConfig.team_color(team)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(330, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", PRTheme.panel(color, PRTheme.NAVY, 0.94))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(box)
	var device := _input.device_name(slot) if _input else "Keyboard"
	box.add_child(PRTheme.row([
		PRTheme.label(PRRoster.role_name(slot).to_upper(), 17, color, PRTheme.display_font()),
		PRTheme.label("·  " + device, 13, PRTheme.MUTED),
	], 13))
	if _input:
		for pair in _input.controls_for(slot):
			var line := PRTheme.row(["[%s]" % pair[1], str(pair[0])], 14, PRTheme.WHITE)
			box.add_child(line)
	if _roster:
		var m := _roster.majors[slot]
		var info := PRMajors.info(m)
		var is_runner := PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER
		var power := PRTheme.label("%s %s: %s" % [PRMajors.icon(m), info["runner" if is_runner else "buddy"], info["runner_text" if is_runner else "buddy_text"]], 12, PRTheme.GOLD)
		power.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		power.custom_minimum_size = Vector2(300, 0)
		box.add_child(power)
	return p


func _close_controls() -> void:
	_controls.visible = false
	show_pause(true)
	_pause_menu.select(1)


# --- Notice (pad unplugged) -------------------------------------------------------------

func _build_notice() -> void:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	var sb := PRTheme.panel(PRConfig.HINDER_COLOR, PRTheme.NAVY, 0.96, PRTheme.LEAN, 6)
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	sb.content_margin_left = 28
	sb.content_margin_right = 24
	p.add_theme_stylebox_override("panel", sb)
	_notice.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	p.add_child(col)
	_notice_title = PRTheme.title("", 32)
	_notice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_notice_title)
	_notice_body = PRTheme.label("", 17)
	_notice_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_body.custom_minimum_size = Vector2(500, 0)
	col.add_child(_notice_body)


func show_notice(title_text: String, body: String) -> void:
	_notice_title.text = title_text
	_notice_body.text = body
	_notice.visible = true


func hide_notice() -> void:
	_notice.visible = false


# --- Results -----------------------------------------------------------------------------

## data: {title, color, reason, time, rows: [[label, blue, gold]]}
func show_results(data: Dictionary) -> void:
	PRTheme.clear(_results)
	var accent: Color = data.get("color", PRTheme.GOLD)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results.add_child(col)

	var banner := PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", PRTheme.fill(accent, PRTheme.LEAN, 40, 4))
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var t := PRTheme.title(data.get("title", ""), 56, PRTheme.text_on(accent))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(t)
	col.add_child(banner)
	PRTheme.wipe_in(banner, 0.0, 0.3)
	var reason := PRTheme.label("%s   ·   %s" % [data.get("reason", ""), data.get("time", "")], 17, PRTheme.WHITE)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(reason)

	var table := PanelContainer.new()
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	table.add_theme_stylebox_override("panel", PRTheme.panel(PRTheme.NAVY_LIGHT, PRTheme.NAVY, 0.9, 0.0, 0))
	col.add_child(table)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_child(grid)
	grid.add_child(PRTheme.label("", 14))
	for team in 2:
		var h := PRTheme.title(PRConfig.team_name(team).to_upper(), 20, PRConfig.team_color(team))
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(h)
	for r in data.get("rows", []):
		grid.add_child(PRTheme.label(str(r[0]), 15, PRTheme.MUTED))
		for team in 2:
			var v := PRTheme.label(str(r[team + 1]), 16, PRTheme.WHITE, PRTheme.display_font())
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(v)

	_results_menu = PRMenuList.new()
	_results_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_results_menu.enabled = false
	_results_menu.chosen.connect(func(id: String) -> void: menu_chosen.emit(id))
	col.add_child(_results_menu)
	_results_menu.set_items([["rematch", "REMATCH"], ["setup", "CHANGE SIDES & MAJORS"], ["quit", "QUIT"]])
	_results.visible = true


## The results menu ignores input until this is called (no accidental rematch).
func enable_results_menu() -> void:
	if _results_menu:
		_results_menu.enabled = true


func is_results_visible() -> bool:
	return _results.visible


# --- Backdrop -------------------------------------------------------------------------------

## Dims the game and draws slow-moving diagonal bands behind every menu.
class Backdrop extends Control:
	var _t := 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _process(delta: float) -> void:
		if visible:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(PRTheme.INK, 0.86))
		var slant := size.y * 0.45
		var band := 140.0
		var shift := fmod(_t * 18.0, band * 2.0)
		var x := -slant - band * 2.0 + shift
		while x < size.x + band:
			var pts := PackedVector2Array([Vector2(x, size.y), Vector2(x + band, size.y), Vector2(x + band + slant, 0), Vector2(x + slant, 0)])
			draw_colored_polygon(pts, Color(PRTheme.NAVY, 0.45))
			x += band * 2.0
		# Gold and sky accent strokes across the corners.
		draw_line(Vector2(0, size.y * 0.82), Vector2(size.x * 0.32, size.y), Color(PRTheme.GOLD, 0.8), 3.0)
		draw_line(Vector2(size.x * 0.7, 0), Vector2(size.x, size.y * 0.16), Color(PRTheme.SKY, 0.7), 3.0)
