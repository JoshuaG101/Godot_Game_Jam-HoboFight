extends CanvasLayer

# Drag the MatchManager node into this slot in the Inspector
@export var match_manager: MatchManager

var tint: ColorRect
var timer_label: Label
var banner_label: Label
var ability_row: HBoxContainer
var ability_labels: Dictionary = {}   # player_id -> Label


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

	# A row along the bottom with one label per player (class, ability, cooldown)
	ability_row = HBoxContainer.new()
	ability_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ability_row.add_theme_constant_override("separation", 80)
	add_child(ability_row)
	ability_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ability_row.grow_vertical = Control.GROW_DIRECTION_BEGIN   # grow upward, not off-screen
	ability_row.offset_bottom = -12.0

	match_manager.sudden_death_started.connect(_on_sudden_death_started)


# _process runs every rendered frame, which suits cosmetic updates like this one
func _process(_delta: float) -> void:
	if match_manager.sudden_death:
		timer_label.text = "SUDDEN DEATH"
	else:
		var seconds_left := int(ceil(match_manager.get_time_left()))
		timer_label.text = "%d:%02d" % [floori(seconds_left / 60.0), seconds_left % 60]

	_update_ability_labels()


func _update_ability_labels() -> void:
	var players := get_tree().get_nodes_in_group("players")
	players.sort_custom(func(a, b): return a.player_id < b.player_id)

	for player in players:
		var id: int = player.player_id

		# Create this player's label the first time we see them
		if not ability_labels.has(id):
			var label := Label.new()
			label.add_theme_font_size_override("font_size", 22)
			ability_row.add_child(label)
			ability_labels[id] = label

		var text := "P%d: %s" % [id, PlayerClass.display_name(player.player_class)]
		var ability: Ability = player.ability
		if ability != null:
			if ability.cooldown_left > 0.0:
				text += "\n%s  %.1fs" % [ability.get_ability_name(), ability.cooldown_left]
			else:
				text += "\n%s  READY" % ability.get_ability_name()
		ability_labels[id].text = text


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
