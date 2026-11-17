class_name PRTowerMeter
extends Control
## The race tower in the centre divider: the six sections (✚ HELP stages white,
## ✕ HINDER stages red), the finish at the top, and both Runners at their
## current heights. Shows who is winning at a glance.

var race: PRRaceManager

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if race == null or race.courses.is_empty():
		return
	var course := race.courses[0]
	var bounds := course.get_section_bounds()
	if bounds.is_empty():
		return
	var font := PRTheme.display_font()
	var top := 22.0
	var bottom := size.y - 8.0
	var x0 := 10.0
	var x1 := size.x - 10.0
	var lo: float = bounds[0][0]
	var hi: float = bounds[bounds.size() - 1][1]
	var span := maxf(hi - lo, 1.0)
	var map := func(y: float) -> float: return lerpf(bottom, top, clampf((y - lo) / span, 0.0, 1.0))

	draw_rect(Rect2(x0, top, x1 - x0, bottom - top), Color(PRTheme.NAVY, 0.9))
	for i in bounds.size():
		var stage := PRConfig.stage_for_checkpoint(i + 1)
		var c := PRConfig.mode_color(stage)
		var ya: float = map.call(bounds[i][0])
		var yb: float = map.call(bounds[i][1])
		draw_rect(Rect2(x0, yb, x1 - x0, ya - yb), Color(c, 0.12))
		draw_line(Vector2(x0, ya), Vector2(x1, ya), Color(c, 0.7), 1.5)
		draw_string(font, Vector2(x0 + 2, ya - 3), "%s%d" % [PRConfig.mode_icon(stage), i + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(c, 0.9))
	# Finish banner at the top.
	draw_rect(Rect2(x0, top - 16, x1 - x0, 13), PRTheme.GOLD)
	draw_string(font, Vector2(x0, top - 6), "FINISH", HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, 9, PRTheme.INK)

	for team in 2:
		if team >= race.runners.size():
			continue
		var r := race.runners[team]
		var ly := r.global_position.y - race.courses[team].global_position.y
		var y: float = map.call(ly)
		var lane_x := lerpf(x0, x1, 0.3 if team == 0 else 0.7)
		var col := PRConfig.team_color(team)
		if race.spree[team]:
			draw_circle(Vector2(lane_x, y), 11.0 + 2.5 * sin(_time * 10.0), Color(PRTheme.GOLD, 0.4))
		draw_circle(Vector2(lane_x, y), 8.0, col)
		draw_arc(Vector2(lane_x, y), 8.0, 0, TAU, 24, PRTheme.INK, 2.0, true)
		draw_string(font, Vector2(lane_x - 10, y + 4), PRMajors.icon(r.power.major) if r.power else "", HORIZONTAL_ALIGNMENT_CENTER, 20, 9, PRTheme.INK)
