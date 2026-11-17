class_name PRHud
extends CanvasLayer
## In-race UI, built in code. It reads the race state every frame (bind() it to
## the PRRaceManager) and holds no game rules. It is kept small and see-through
## so it never hides the course:
##
##   top outer corner   team plate: Runner power, Buddy mode, cooldowns, power
##   top inner corner   a small red tag while the enemy Buddy hinders you
##   upper middle       short slanted banners (checkpoint, stunned, powers)
##   lower middle       flashing trap alerts
##
## Centre divider: the race timer and the tower meter.

const DIVIDER_WIDTH := 72.0
const PLATE_ALPHA := 0.5

var race: PRRaceManager

var _halves: Array[Control] = []
var _plates: Array[TeamPlate] = []
var _hinder_tags: Array[Control] = []
var _banners: Array[PanelContainer] = []
var _banner_labels: Array[Label] = []
var _banner_time: Array[float] = [0.0, 0.0]
var _alerts: Array[PanelContainer] = []
var _alert_labels: Array[Label] = []
var _alert_time: Array[float] = [0.0, 0.0]
var _timer: Label
var _meter: PRTowerMeter
var _debug: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var split := HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 0)
	split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(split)
	for team in 2:
		if team == 1:
			split.add_child(_build_divider())
		var half := Control.new()
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		half.clip_contents = true
		split.add_child(half)
		_halves.append(half)
		_build_half(half, team)
	_debug = PRTheme.label("", 12, Color(0.8, 1.0, 0.8), PRTheme.body_font(700), 4)
	_debug.position = Vector2(8, 90)
	_debug.visible = false
	root.add_child(_debug)


func bind(p_race: PRRaceManager) -> void:
	race = p_race
	_meter.race = race


# --- Building ------------------------------------------------------------------------

func _build_divider() -> Control:
	var div := PanelContainer.new()
	div.custom_minimum_size = Vector2(DIVIDER_WIDTH, 0)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PRTheme.INK
	sb.border_color = PRTheme.NAVY_LIGHT
	sb.border_width_left = 2
	sb.border_width_right = 2
	div.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	div.add_child(col)
	_timer = PRTheme.title("4:00", 22, PRTheme.GOLD)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_timer)
	_meter = PRTowerMeter.new()
	_meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_meter)
	return div


func _build_half(half: Control, team: int) -> void:
	var outer_left := team == 0
	var plate := TeamPlate.new(team)
	_pin_top(plate, outer_left, 8.0)
	half.add_child(plate)
	_plates.append(plate)

	var tag := PRTheme.chip("✕ HINDERED", PRConfig.HINDER_COLOR, 12)
	tag.modulate.a = 0.85
	tag.visible = false
	_pin_top(tag, not outer_left, 10.0)
	half.add_child(tag)
	_hinder_tags.append(tag)

	var banner := PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.offset_top = 110
	banner.offset_bottom = 110
	banner.visible = false
	half.add_child(banner)
	_banners.append(banner)
	var bl := PRTheme.title("", 24, PRTheme.WHITE)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(bl)
	_banner_labels.append(bl)

	var alert := PanelContainer.new()
	alert.add_theme_stylebox_override("panel", PRTheme.fill(Color(PRConfig.HINDER_COLOR, 0.85), PRTheme.LEAN, 12, 1))
	alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	alert.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alert.grow_vertical = Control.GROW_DIRECTION_BEGIN
	alert.offset_top = -26
	alert.offset_bottom = -26
	alert.visible = false
	half.add_child(alert)
	_alerts.append(alert)
	var al := PRTheme.title("", 15, PRTheme.WHITE)
	alert.add_child(al)
	_alert_labels.append(al)


## Pins a control to a top corner of its half.
static func _pin_top(c: Control, left: bool, margin: float) -> void:
	c.anchor_left = 0.0 if left else 1.0
	c.anchor_right = c.anchor_left
	c.offset_left = margin if left else -margin
	c.offset_right = c.offset_left
	c.offset_top = margin
	c.offset_bottom = margin
	c.grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN


# --- Per-frame update --------------------------------------------------------------------

func _process(delta: float) -> void:
	for team in 2:
		_tick(team, delta)
	if race == null:
		return
	var racing := race.state in [PRRaceManager.State.COUNTDOWN, PRRaceManager.State.RACING, PRRaceManager.State.PAUSED]
	for team in 2:
		_plates[team].visible = racing
		if racing:
			_plates[team].refresh(race, team)
		var enemy := race.buddies[1 - team]
		_hinder_tags[team].visible = racing and enemy.mode == PRConfig.Mode.HINDER and not enemy.is_safe_zone()


func _tick(team: int, delta: float) -> void:
	if _banner_time[team] > 0.0:
		_banner_time[team] -= delta
		_banners[team].modulate.a = clampf(_banner_time[team] / 0.25, 0.0, 1.0)
		if _banner_time[team] <= 0.0:
			_banners[team].visible = false
	if _alert_time[team] > 0.0:
		_alert_time[team] -= delta
		_alerts[team].modulate.a = 0.55 + 0.45 * absf(sin(_alert_time[team] * 12.0))
		if _alert_time[team] <= 0.0:
			_alerts[team].visible = false


# --- API ---------------------------------------------------------------------------------

func set_time(seconds: float) -> void:
	var s := maxi(ceili(seconds), 0)
	@warning_ignore("integer_division")
	_timer.text = "%d:%02d" % [s / 60, s % 60]
	_timer.add_theme_color_override("font_color", PRConfig.HINDER_COLOR if s <= 15 else PRTheme.GOLD)


## A short slanted banner in one team's view ("CHECKPOINT 3", "STUNNED!").
func show_message(team: int, text: String, seconds := 1.1, color := PRTheme.WHITE) -> void:
	_banner_labels[team].text = text
	_banner_labels[team].add_theme_color_override("font_color", PRTheme.text_on(color))
	_banners[team].add_theme_stylebox_override("panel", PRTheme.fill(Color(color, 0.92), PRTheme.LEAN, 18, 2))
	_banners[team].visible = true
	_banners[team].modulate.a = 1.0
	_banner_time[team] = seconds
	PRTheme.wipe_in(_banners[team])


## A flashing alert near the bottom of one team's view ("TRAP!").
func show_alert(team: int, text: String, seconds := 1.0) -> void:
	_alert_labels[team].text = text
	_alerts[team].visible = true
	_alert_time[team] = seconds


func hide_alert(team: int) -> void:
	_alerts[team].visible = false
	_alert_time[team] = 0.0


func toggle_debug() -> void:
	_debug.visible = not _debug.visible


func is_debug_visible() -> bool:
	return _debug.visible


func set_debug_text(text: String) -> void:
	_debug.text = text


# --- Team plate ----------------------------------------------------------------------------

## The see-through plate in a team's top outer corner. Built once; refresh()
## only changes texts, colours and bar values.
class TeamPlate extends PanelContainer:
	var _team := 0
	var _effects: HBoxContainer
	var _effect_chips := {}
	var _run_icon: Label
	var _run_meter: ProgressBar
	var _run_state: Label
	var _mode_chip: PanelContainer
	var _mode_label: Label
	var _mode := -1
	var _switch: HBoxContainer
	var _switch_key: Label
	var _barrel: ProgressBar
	var _trap: ProgressBar
	var _hinder_bits: HBoxContainer
	var _bud_icon: Label
	var _bud_meter: ProgressBar
	var _bud_state: Label

	func _init(team: int) -> void:
		_team = team
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color := PRConfig.team_color(team)
		add_theme_stylebox_override("panel", PRTheme.panel(color, PRTheme.NAVY, PRHud.PLATE_ALPHA, PRTheme.LEAN, 4))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(col)

		var head := _hbox(8)
		col.add_child(head)
		head.add_child(PRTheme.title(PRConfig.team_name(team).to_upper(), 18, color))
		_effects = _hbox(4)
		head.add_child(_effects)
		for e in [["spree", "SPREE", PRTheme.GOLD], ["boost", "BOOST", PRTheme.SKY], ["invert", "⇆ FLIPPED", PRConfig.HINDER_COLOR], ["paint", "PAINTED", PRConfig.HINDER_COLOR], ["dance", "♫ DANCING", PRConfig.HINDER_COLOR]]:
			var c := PRTheme.chip(e[1], e[2], 11)
			c.visible = false
			_effects.add_child(c)
			_effect_chips[e[0]] = c

		var run := _hbox(5)
		col.add_child(run)
		run.add_child(PRTheme.label("RUN", 11, PRTheme.MUTED, PRTheme.display_font()))
		_run_icon = PRTheme.label("", 13, PRTheme.WHITE, PRTheme.display_font())
		run.add_child(_run_icon)
		_run_meter = PRTheme.meter(color, 54.0, 5.0)
		_run_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		run.add_child(_run_meter)
		_run_state = PRTheme.label("", 11, PRTheme.WHITE, PRTheme.display_font())
		run.add_child(_run_state)

		var bud := _hbox(5)
		col.add_child(bud)
		bud.add_child(PRTheme.label("BUD", 11, PRTheme.MUTED, PRTheme.display_font()))
		_mode_chip = PanelContainer.new()
		_mode_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mode_label = PRTheme.label("", 11, PRTheme.INK, PRTheme.display_font())
		_mode_chip.add_child(_mode_label)
		bud.add_child(_mode_chip)
		_switch = _hbox(2)
		var cap := PRTheme.keycap("?", 10)
		_switch_key = cap.get_child(0) as Label
		_switch.add_child(cap)
		_switch.add_child(PRTheme.label("⇄", 12, PRTheme.WHITE))
		bud.add_child(_switch)
		_hinder_bits = _hbox(3)
		_hinder_bits.add_child(PRTheme.label("●", 10, PRTheme.MUTED))
		_barrel = PRTheme.meter(PRConfig.HINDER_COLOR, 22.0, 4.0)
		_barrel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hinder_bits.add_child(_barrel)
		_hinder_bits.add_child(PRTheme.label("▲", 10, PRTheme.MUTED))
		_trap = PRTheme.meter(PRConfig.HINDER_COLOR, 22.0, 4.0)
		_trap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hinder_bits.add_child(_trap)
		bud.add_child(_hinder_bits)
		_bud_icon = PRTheme.label("", 13, PRTheme.WHITE, PRTheme.display_font())
		bud.add_child(_bud_icon)
		_bud_meter = PRTheme.meter(PRTheme.GOLD, 34.0, 5.0)
		_bud_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bud.add_child(_bud_meter)
		_bud_state = PRTheme.label("", 11, PRTheme.WHITE, PRTheme.display_font())
		bud.add_child(_bud_state)

	func refresh(race: PRRaceManager, team: int) -> void:
		var r := race.runners[team]
		var b := race.buddies[team]
		_effect_chips["spree"].visible = race.spree[team]
		_effect_chips["boost"].visible = race.boost[team]
		_effect_chips["invert"].visible = r.invert_time > 0.0
		_effect_chips["paint"].visible = r.is_painted()
		_effect_chips["dance"].visible = r.is_dancing()

		var p := r.power
		_run_icon.text = PRMajors.icon(p.major)
		_run_meter.value = p.ratio()
		if p.is_active():
			_run_state.text = "ON"
			_run_state.add_theme_color_override("font_color", PRTheme.GOLD)
		elif p.can_use():
			_run_state.text = "READY"
			_run_state.add_theme_color_override("font_color", PRTheme.WHITE)
		else:
			_run_state.text = "%ds" % ceili(p.cooldown)
			_run_state.add_theme_color_override("font_color", PRTheme.MUTED)

		if b.mode != _mode:
			_mode = b.mode
			var mc := PRConfig.mode_color(_mode)
			_mode_chip.add_theme_stylebox_override("panel", PRTheme.fill(mc, PRTheme.LEAN, 7, 0))
			_mode_label.text = "%s %s" % [PRConfig.mode_icon(_mode), PRConfig.mode_name(_mode)]
			_mode_label.add_theme_color_override("font_color", PRTheme.text_on(mc))
			PRTheme.pop(_mode_chip, 0.2)
		_switch.visible = b.can_switch() and b.stun_time <= 0.0
		_switch_key.text = b.key_name("mode")
		_hinder_bits.visible = _mode == PRConfig.Mode.HINDER
		_barrel.value = 1.0 - clampf(b.drop_cooldown / PRConfig.DROP_COOLDOWN, 0.0, 1.0)
		_trap.value = 1.0 - clampf(b.trap_cooldown / PRConfig.TRAP_COOLDOWN, 0.0, 1.0)
		_bud_icon.text = PRMajors.icon(b.major)
		_bud_meter.value = b.power_ratio()
		if b.stun_time > 0.0:
			_set_bud_state("STUNNED", PRConfig.HINDER_COLOR)
		elif b.hex_time > 0.0:
			_set_bud_state("CURSED", PRConfig.HINDER_COLOR)
		elif b.power_armed:
			_set_bud_state("ARMED", PRTheme.GOLD)
		elif b.power_cooldown <= 0.0:
			_set_bud_state("READY", PRTheme.WHITE)
		else:
			_set_bud_state("%ds" % ceili(b.power_cooldown), PRTheme.MUTED)

	func _set_bud_state(text: String, color: Color) -> void:
		_bud_state.text = text
		_bud_state.add_theme_color_override("font_color", color)

	static func _hbox(sep: int) -> HBoxContainer:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", sep)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return h
