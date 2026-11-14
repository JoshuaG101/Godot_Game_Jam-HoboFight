extends CanvasLayer

# Drag the MatchManager node into this slot in the Inspector
@export var match_manager: MatchManager

var tint: ColorRect
var timer_label: Label
var banner_label: Label


# LOCAL ONLY: purely cosmetic (online: every player's machine runs its own copy)
func _ready() -> void:
	assert(match_manager != null, "Assign the Match Manager in the Inspector")
	# Red tint over the whole screen, invisible until sudden death
	tint = ColorRect.new()
	tint.color = Color(1.0, 0.0, 0.0, 0.0)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Countdown across the top of the screen
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 36)
	add_child(timer_label)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	# Big banner in the middle, invisible until sudden death
	banner_label = Label.new()
	banner_label.text = "SUDDEN DEATH!"
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 96)
	banner_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	banner_label.modulate.a = 0.0
	add_child(banner_label)
	banner_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	match_manager.sudden_death_started.connect(_on_sudden_death_started)


# _process runs every rendered frame, which suits cosmetic updates like this one
func _process(_delta: float) -> void:
	if match_manager.sudden_death:
		timer_label.text = "SUDDEN DEATH"
	else:
		var seconds_left := int(ceil(match_manager.get_time_left()))
		timer_label.text = "%d:%02d" % [floori(seconds_left / 60.0), seconds_left % 60]


func _on_sudden_death_started() -> void:
	# Banner: fade in, hold, fade out
	var banner_tween := create_tween()
	banner_tween.tween_property(banner_label, "modulate:a", 1.0, 0.15)
	banner_tween.tween_interval(1.2)
	banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.5)

	# Tint: a bright red flash that settles into a faint red tint
	tint.color.a = 0.45
	var tint_tween := create_tween()
	tint_tween.tween_property(tint, "color:a", 0.12, 0.8)
