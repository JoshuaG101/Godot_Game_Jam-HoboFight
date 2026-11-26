class_name PRMenuList
extends VBoxContainer
## A vertical list of slanted options (pause menu, results). Up / Down move,
## Accept picks, with the keyboard, any pad, or the mouse. Emits `chosen`.
## Reads the pr2_menu_* actions, which only matter while a menu is open.

signal chosen(id: String)

const WIDTH := 300.0

## Ignores input while false (e.g. the first moments of the results screen).
var enabled := true
var index := 0

var _ids: Array[String] = []
var _buttons: Array[Button] = []


func _init() -> void:
	add_theme_constant_override("separation", 6)


## items: [[id, label], ...]
func set_items(items: Array, start := 0) -> void:
	PRTheme.clear(self)
	_ids.clear()
	_buttons.clear()
	for i in items.size():
		var b := Button.new()
		b.text = str(items[i][1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(WIDTH, 38)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", PRTheme.display_font())
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_on_pressed.bind(i))
		b.mouse_entered.connect(select.bind(i))
		add_child(b)
		_ids.append(str(items[i][0]))
		_buttons.append(b)
		PRTheme.wipe_in(b, 0.04 * i)
	index = clampi(start, 0, maxi(items.size() - 1, 0))
	_restyle()


func select(i: int) -> void:
	if i == index or i < 0 or i >= _buttons.size():
		return
	index = i
	_restyle()
	PRTheme.pop(_buttons[index], 0.06)
	PRSfx.emit(self, "click", -10.0)


func selected_id() -> String:
	return _ids[index] if index < _ids.size() else ""


func _process(_delta: float) -> void:
	if not enabled or not is_visible_in_tree() or _buttons.is_empty():
		return
	if Input.is_action_just_pressed(PRInput.menu_action("down")):
		select((index + 1) % _buttons.size())
	elif Input.is_action_just_pressed(PRInput.menu_action("up")):
		select((index - 1 + _buttons.size()) % _buttons.size())
	elif Input.is_action_just_pressed(PRInput.menu_action("accept")):
		_on_pressed(index)


func _on_pressed(i: int) -> void:
	if not enabled:
		return
	index = i
	_restyle()
	PRSfx.emit(self, "click", -4.0)
	chosen.emit(_ids[i])


func _restyle() -> void:
	for i in _buttons.size():
		var b := _buttons[i]
		var on := i == index
		var sb := PRTheme.fill(PRTheme.GOLD if on else Color(PRTheme.NAVY, 0.85), PRTheme.LEAN, 22, 4)
		if not on:
			sb.border_color = PRTheme.NAVY_LIGHT
			sb.border_width_left = 3
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, sb)
		var fc := PRTheme.INK if on else PRTheme.WHITE
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, fc)
