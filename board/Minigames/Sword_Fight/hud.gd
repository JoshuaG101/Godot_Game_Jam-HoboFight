extends CanvasLayer

const PlayerClass = preload("res://Minigames/Sword_Fight/player_class.gd")
const Ability = preload("res://Minigames/Sword_Fight/Abilities/ability.gd")

# Drag the MatchManager node into this slot in the Inspector
@export var match_manager: MatchManager

var tint: ColorRect
var timer_label: Label
var banner_label: Label
var ability_row: HBoxContainer
var ability_labels: Dictionary = {}   # player_id -> Label


# LOCAL ONLY: purely cosmetic (online: every player's machine runs its own copy)
func _ready() -> void:
	if not match_manager:
		match_manager = get_node_or_null("../MatchManager")

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

	if match_manager:
		match_manager.sudden_death_started.connect(_on_sudden_death_started)


# _process runs every rendered frame, which suits cosmetic updates like this one
func _process(_delta: float) -> void:
	if not match_manager:
		return
	if match_manager.sudden_death:
		timer_label.text = "SUDDEN DEATH"
	else:
		var seconds_left := int(ceil(match_manager.get_time_left()))
		timer_label.text = "%d:%02d" % [floori(seconds_left / 60.0), seconds_left % 60]

	_update_ability_labels()


func _on_sudden_death_started() -> void:
	# Keep the red tint on for the rest of the match
	tint.color = Color(1.0, 0.05, 0.0, 0.22)

	# Flash the SUDDEN DEATH! banner, hold it, and fade it out
	var tween := create_tween()
	tween.tween_property(banner_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(banner_label, "modulate:a", 0.0, 0.5)


func _update_ability_labels() -> void:
	# Add a label for any player that doesn't have one yet
	for player in get_tree().get_nodes_in_group("players"):
		if not ability_labels.has(player.player_id):
			var label := Label.new()
			label.add_theme_font_size_override("font_size", 20)
			ability_row.add_child(label)
			ability_labels[player.player_id] = label

		var label: Label = ability_labels[player.player_id]
		label.text = _format_player_status(player)


func _format_player_status(player: Node3D) -> String:
	var class_name_str := PlayerClass.display_name(player.player_class)
	var ability: Ability = player.ability

	# No class or no ability assigned
	if ability == null:
		return "P%d: %s" % [player.player_id, class_name_str]

	var ability_name := ability.get_ability_name()

	# Cooldown counting down, or ready to use
	var cd_text: String
	if ability.cooldown_left > 0.0:
		cd_text = "%ds" % int(ceil(ability.cooldown_left))
	else:
		cd_text = "READY"

	var text := "P%d: %s | %s [%s]" % [player.player_id, class_name_str, ability_name, cd_text]

	# Abilities can add extra text (e.g. Roulette shows what genre was rolled)
	if ability.has_method("get_status_text"):
		var extra: String = ability.get_status_text()
		if extra != "":
			text += "  (%s)" % extra

	return text
