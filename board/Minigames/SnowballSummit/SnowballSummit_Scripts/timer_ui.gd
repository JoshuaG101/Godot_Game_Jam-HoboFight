extends CanvasLayer

@export var round_time := 60.0
@export var autostart := true

signal time_up

var time_left: float
var running := false
var label: Label


func _ready() -> void:
	time_left = round_time

	label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = 20
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.3))
	label.add_theme_constant_override("outline_size", 12)
	add_child(label)

	_update_label()
	if autostart:
		start()


func start() -> void:
	time_left = round_time
	running = true


func _process(delta: float) -> void:
	if not running:
		return
	time_left = max(time_left - delta, 0.0)
	_update_label()
	if time_left <= 0.0:
		running = false
		time_up.emit()


func _update_label() -> void:
	var secs := int(ceil(time_left))
	label.text = "%d:%02d" % [secs / 60, secs % 60]
	# Turn red and pulse in the last 10 seconds
	if time_left <= 10.0 and running:
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		var pulse := 1.0 + 0.1 * sin(Time.get_ticks_msec() / 100.0)
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2(pulse, pulse)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.scale = Vector2.ONE
