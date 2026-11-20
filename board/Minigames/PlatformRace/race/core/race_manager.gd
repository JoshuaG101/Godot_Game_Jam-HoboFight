class_name PRRaceManager
extends Node3D
## PlatformRace root. Runs the match flow, the race timer, win / timeout / draw,
## HELP BOOST and SPREE, and the end-of-race choices. Joins the other parts
## together with signals. PlatformRace is standalone: it uses no board-game
## systems (later the main game can hand it a roster with majors already set).
##
## Flow: SIDES (controllers pick seats) → MAJORS (everyone picks a major) →
##       VERSUS → COUNTDOWN → RACING ⇄ PAUSED → RESULTS →
##       Rematch (same seats and majors) / Change sides & majors / Quit

signal state_changed(state: int)
signal race_finished(result: Dictionary)
## Emitted instead of reloading when allow_scene_change is off (tests).
signal restart_requested(roster: Dictionary, skip_select: bool)
signal quit_requested

enum State { SIDES, MAJORS, VERSUS, COUNTDOWN, RACING, PAUSED, RESULTS }

const MODELS: Array[PackedScene] = [
	preload("res://Minigames/PlatformRace/scenes/skeleton_rogue.tscn"),
	preload("res://Minigames/PlatformRace/scenes/skeleton_mage.tscn"),
]
## Carries the roster across a scene reload (Rematch / Change sides).
const META_KEY := &"pr_platform_race_next"
## Starting majors so a quick start still shows four different powers.
const DEFAULT_MAJORS: Array[int] = [PRMajors.Major.ART, PRMajors.Major.MUSIC, PRMajors.Major.HISTORY, PRMajors.Major.COMPUTER_SCIENCE]

## Tests turn this off so the scene never reloads or quits.
@export var allow_scene_change := true
## Show the side select and major select first (skipped on Rematch).
@export var show_select := true
## Tests: skip the menus and start the countdown at once (keyboard seats).
@export var auto_ready := false

@onready var input: PRInput = $Input
@onready var sfx: PRSfx = $Sfx
@onready var courses: Array[PRCourse] = [$World/CourseBlue, $World/CourseGold]
@onready var runners: Array[PRRunner] = [$RunnerBlue, $RunnerGold]
@onready var buddies: Array[PRBuddy] = [$BuddyBlue, $BuddyGold]
@onready var cameras: Array[PRRaceCamera] = [
	$Views/Split/ViewBlue/SubViewport/CameraBlue,
	$Views/Split/ViewGold/SubViewport/CameraGold,
]
@onready var hud: PRHud = $HUD
@onready var overlays: PROverlays = $Overlays

var roster: PRRoster
var state := State.SIDES
var time_left := PRConfig.TIME_LIMIT
var race_time := 0.0
## {kind: "win"|"timeout"|"draw", winner: team or -1, reason: String, time: float}
var result := {}
var boost: Array[bool] = [false, false]
var spree: Array[bool] = [false, false]
## Checkpoints taken first in a row.
var streak: Array[int] = [0, 0]
var finish_times: Array[float] = [-1.0, -1.0]

var _state_time := 0.0
var _last_count := -1
## [team, physics frame] for every finish this tick; resolved next tick.
var _finish_events: Array = []
## Race time at which each team reached each checkpoint index.
var _checkpoint_times: Array[Dictionary] = [{}, {}]
var _resume_time := 0.0
var _results_menu_on := false


func _ready() -> void:
	# The root keeps running while paused (menus); gameplay nodes pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path in ["World", "RunnerBlue", "RunnerGold", "BuddyBlue", "BuddyGold", "Views", "HUD"]:
		get_node(path).process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = false

	var carry: Dictionary = get_tree().root.get_meta(META_KEY, {})
	if get_tree().root.has_meta(META_KEY):
		get_tree().root.remove_meta(META_KEY)
	if carry.has("roster"):
		roster = PRRoster.from_dict(carry["roster"])
	else:
		roster = PRRoster.keyboard_only()
		roster.majors = DEFAULT_MAJORS.duplicate()
	input.bind_roster(roster)
	overlays.bind(input, roster)

	for team in 2:
		var course := courses[team]
		course.set_team(team)
		var r := runners[team]
		r.setup(team, MODELS[team], "", roster.runner_major(team))
		r.place_at(course.get_start_position(), 1)
		var cp1 := course.get_checkpoint(1)
		if cp1:
			cp1.set_reached(true)
		r.finished.connect(_on_runner_finished)
		r.checkpoint_reached.connect(_on_checkpoint_reached)
		r.respawn_started.connect(func(t: int) -> void: hud.show_message(t, "RESPAWN", 0.8, PRTheme.NAVY_LIGHT))
		r.respawned.connect(func(_t: int) -> void: sfx.play("respawn", -6.0))
		r.stunned.connect(func(t: int) -> void: hud.show_message(t, "DANCE!" if runners[t].is_dancing() else "STUNNED!", 1.0, PRConfig.HINDER_COLOR))
		r.power.announced.connect(func(t: int, text: String) -> void: hud.show_message(t, text, 1.0, PRTheme.GOLD))
		cameras[team].setup(r, course.get_center_x(), course.global_position.y + course.bottom_y, course.global_position.y + course.top_y)
		_checkpoint_times[team][1] = 0.0
		for trap in course.get_traps():
			trap.warned.connect(_on_trap_warned)
	for team in 2:
		var b := buddies[team]
		b.input = input
		b.setup(team, courses[team], courses[1 - team], runners[team], runners[1 - team], cameras[1 - team], roster.buddy_major(team))
		b.mode_changed.connect(_on_mode_changed)
		b.hinder_used.connect(_on_hinder_used)
	_apply_roster()
	hud.bind(self)
	hud.set_time(time_left)
	input.device_lost.connect(_on_device_lost)
	input.device_restored.connect(_on_device_restored)
	overlays.menu_chosen.connect(_on_menu_chosen)
	overlays.sides.confirmed.connect(_on_sides_confirmed)
	overlays.majors.confirmed.connect(_on_majors_confirmed)
	overlays.majors.back_requested.connect(func() -> void: _enter(State.SIDES))

	if auto_ready:
		_enter(State.COUNTDOWN)
	elif carry.get("skip_select", false) or not show_select:
		_enter(State.VERSUS)
	else:
		_enter(State.SIDES)


## Hands every seat's major to its Runner power or Buddy.
func _apply_roster() -> void:
	for team in 2:
		var r := runners[team]
		r.assign_major(roster.runner_major(team), PRMajors.short_name(roster.runner_major(team)))
		r.power.enemy_buddy = buddies[1 - team]
		buddies[team].major = roster.buddy_major(team)


# --- State machine -----------------------------------------------------------------------

func _enter(next: State) -> void:
	var prev := state
	state = next
	_state_time = 0.0
	match state:
		State.SIDES:
			overlays.hide_all()
			overlays.sides.open(input, roster.devices)
			_set_controls(false)
		State.MAJORS:
			overlays.sides.close()
			overlays.majors.open(input, roster)
			_set_controls(false)
		State.VERSUS:
			overlays.hide_all()
			overlays.show_versus(roster)
			sfx.play("go", -8.0)
			_set_controls(false)
		State.COUNTDOWN:
			overlays.hide_all()
			_last_count = -1
			_set_controls(false)
		State.RACING:
			get_tree().paused = false
			overlays.show_pause(false)
			overlays.hide_notice()
			if prev == State.COUNTDOWN:
				overlays.show_big("GO!", PRTheme.GOLD, 0.8)
				sfx.play("go")
				sfx.start_music()
			_set_controls(true)
		State.PAUSED:
			get_tree().paused = true
		State.RESULTS:
			_results_menu_on = false
			_set_controls(false)
	state_changed.emit(state)


func _set_controls(on: bool) -> void:
	for team in 2:
		runners[team].controls_enabled = on and not runners[team].has_finished
		buddies[team].active = on


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"pr2_debug"):
		hud.toggle_debug()
	if hud.is_debug_visible():
		hud.set_debug_text(_debug_text())
	match state:
		State.RACING:
			if Input.is_action_just_pressed(&"pr2_pause"):
				overlays.show_pause(true)
				_enter(State.PAUSED)
		State.PAUSED:
			_process_paused()
		State.RESULTS:
			if not _results_menu_on and _state_time >= PRConfig.RESULTS_INPUT_DELAY:
				_results_menu_on = true
				overlays.enable_results_menu()


func _process_paused() -> void:
	var lost := input.first_lost_seat()
	if lost >= 0:
		# A pad is unplugged: Enter moves that seat to the keyboard.
		if Input.is_action_just_pressed(&"pr2_confirm"):
			input.move_seat_to_keyboard(lost)
		return
	if _resume_time > 0.0:
		return
	if overlays.is_controls_visible():
		return
	if Input.is_action_just_pressed(&"pr2_pause") or Input.is_action_just_pressed(PRInput.menu_action("back")):
		_enter(State.RACING)


func _physics_process(delta: float) -> void:
	_state_time += delta
	match state:
		State.VERSUS:
			if _state_time >= PRConfig.VERSUS_TIME:
				_enter(State.COUNTDOWN)
		State.COUNTDOWN:
			var remaining := PRConfig.COUNTDOWN_TIME - _state_time
			var count := ceili(remaining)
			if count != _last_count and count > 0:
				_last_count = count
				overlays.show_big(str(count), PRTheme.WHITE, 0.9)
				sfx.play("countdown")
			if remaining <= 0.0:
				_enter(State.RACING)
		State.RACING:
			if not _finish_events.is_empty():
				_resolve_finish()
				return
			race_time += delta
			time_left = maxf(PRConfig.TIME_LIMIT - race_time, 0.0)
			hud.set_time(time_left)
			_update_catchup()
			if time_left <= 0.0:
				_resolve_timeout()
		State.PAUSED:
			if _resume_time > 0.0:
				_resume_time -= delta
				if _resume_time <= 0.0:
					_enter(State.RACING)


# --- Menus ---------------------------------------------------------------------------------

func _on_sides_confirmed(devices: Array) -> void:
	for slot in PRConfig.SLOT_COUNT:
		roster.devices[slot] = int(devices[slot])
	input.bind_roster(roster)
	print(input.describe())
	_enter(State.MAJORS)


func _on_majors_confirmed(picks: Array) -> void:
	for slot in PRConfig.SLOT_COUNT:
		roster.majors[slot] = int(picks[slot])
	_apply_roster()
	print(roster.describe())
	_enter(State.VERSUS)


func _on_menu_chosen(id: String) -> void:
	match id:
		"resume":
			if state == State.PAUSED:
				_enter(State.RACING)
		"restart", "rematch":
			restart(true)
		"setup":
			restart(false)
		"quit":
			quit()


## Reloads the race. skip_select = true keeps everyone's seat and major
## (Rematch / Restart); false goes back to the side select.
func restart(skip_select: bool) -> void:
	if not allow_scene_change:
		restart_requested.emit(roster.to_dict(), skip_select)
		return
	get_tree().paused = false
	get_tree().root.set_meta(META_KEY, {"roster": roster.to_dict(), "skip_select": skip_select})
	get_tree().reload_current_scene()


func quit() -> void:
	if not allow_scene_change:
		quit_requested.emit()
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Board/Board.tscn")


# --- Race events -----------------------------------------------------------------------------

func _on_runner_finished(team: int) -> void:
	_finish_events.append([team, Engine.get_physics_frames()])
	finish_times[team] = race_time


func _on_checkpoint_reached(team: int, index: int) -> void:
	if not _checkpoint_times[team].has(index):
		_checkpoint_times[team][index] = race_time
	var other := 1 - team
	if runners[other].checkpoint_index < index:
		streak[team] += 1
		streak[other] = 0
	else:
		streak[team] = 0
	var cp := courses[team].get_checkpoint(index)
	if cp:
		cp.set_reached(true)
	sfx.play("checkpoint")
	hud.show_message(team, "CHECKPOINT %d" % index, 1.1, PRTheme.GOLD)


func _on_mode_changed(team: int, mode: int) -> void:
	if not buddies[team].active:
		return
	if mode == PRConfig.Mode.HELP:
		sfx.play("mode_help", -4.0)
	else:
		hud.show_alert(1 - team, "✕ %s BUDDY ATTACKS" % PRConfig.team_name(team).to_upper(), 1.2)
		sfx.play("mode_hinder", -4.0)


func _on_hinder_used(team: int, what: String) -> void:
	if what == "backfire":
		hud.show_message(team, "BACKFIRE!", 1.2, PRConfig.HINDER_COLOR)


func _on_trap_warned(trap: PRTrap) -> void:
	hud.show_alert(trap.team, "TRAP!  %s" % trap.display_name.to_upper(), PRConfig.TRAP_WARNING + 0.4)


## HELP BOOST for a team a whole checkpoint behind; SPREE for the leader.
func _update_catchup() -> void:
	for team in 2:
		var gap := runners[team].checkpoint_index - runners[1 - team].checkpoint_index
		var s := gap >= PRConfig.CATCHUP_GAP
		var b := -gap >= PRConfig.CATCHUP_GAP
		if s != spree[team]:
			spree[team] = s
			runners[team].set_spree(s)
			if s:
				hud.show_message(team, "ON A SPREE!", 1.6, PRTheme.GOLD)
				sfx.play("spree")
		if b != boost[team]:
			boost[team] = b
			courses[team].set_boost(b)
			runners[team].power.boosted = b
			buddies[team].boosted = b
			if b:
				hud.show_message(team, "HELP BOOST!", 1.6, PRTheme.SKY)
				sfx.play("boost")


func _resolve_finish() -> void:
	var first_frame: int = _finish_events[0][1]
	var teams: Array[int] = []
	for ev in _finish_events:
		if ev[1] == first_frame and not teams.has(ev[0]):
			teams.append(ev[0])
	_finish_events.clear()
	if teams.size() >= 2:
		_end_race("draw", -1, "Both Runners finished on the same tick")
	else:
		_end_race("win", teams[0], "%s Runner reached the top first" % PRConfig.team_name(teams[0]))


## Timeout: highest checkpoint wins; if equal, whoever reached it first; if
## that is equal too, the highest standing point; otherwise a draw.
func _resolve_timeout() -> void:
	var a := runners[0]
	var b := runners[1]
	if a.checkpoint_index != b.checkpoint_index:
		var w := 0 if a.checkpoint_index > b.checkpoint_index else 1
		_end_race("timeout", w, "Time! %s got further (checkpoint %d)" % [PRConfig.team_name(w), runners[w].checkpoint_index])
		return
	var idx := a.checkpoint_index
	var ta: float = _checkpoint_times[0].get(idx, INF)
	var tb: float = _checkpoint_times[1].get(idx, INF)
	if idx > 1 and absf(ta - tb) > 0.05:
		var w := 0 if ta < tb else 1
		_end_race("timeout", w, "Time! %s reached checkpoint %d first" % [PRConfig.team_name(w), idx])
		return
	if a.best_floor_y != b.best_floor_y:
		var w := 0 if a.best_floor_y > b.best_floor_y else 1
		_end_race("timeout", w, "Time! %s climbed higher" % PRConfig.team_name(w))
		return
	_end_race("draw", -1, "Time! Dead even")


## Ends the race. kind: "win", "timeout" or "draw".
func _end_race(kind: String, winner: int, reason: String) -> void:
	if state == State.RESULTS:
		return
	result = {"kind": kind, "winner": winner, "reason": reason, "time": race_time}
	print("[PlatformRace] Result: %s" % str(result))
	for team in 2:
		runners[team].set_spree(false)
		if winner < 0 or team == winner:
			runners[team].hold_animation(&"Cheer")
		else:
			runners[team].hold_animation(&"Death_B")
	sfx.play("win" if winner >= 0 else "countdown")
	_show_results()
	race_finished.emit(result)
	_enter(State.RESULTS)


func _show_results() -> void:
	var winner: int = result["winner"]
	var title := "DRAW!" if winner < 0 else "%s WINS!" % PRConfig.team_name(winner).to_upper()
	var accent := PRTheme.WHITE if winner < 0 else PRConfig.team_color(winner)
	var reached := ["", ""]
	for team in 2:
		if finish_times[team] >= 0.0:
			reached[team] = "FINISH %s" % PRTheme.time_text(finish_times[team])
		else:
			reached[team] = "Checkpoint %d" % runners[team].checkpoint_index
	var rows := [
		["Got to", reached[0], reached[1]],
		["Falls", runners[0].falls, runners[1].falls],
		["Times stunned", runners[0].stuns, runners[1].stuns],
		["Runner powers used", runners[0].power.uses, runners[1].power.uses],
		["Barrels landed", "%d / %d" % [buddies[0].stats["barrel_hits"], buddies[0].stats["barrels"]], "%d / %d" % [buddies[1].stats["barrel_hits"], buddies[1].stats["barrels"]]],
		["Power barrels", buddies[0].stats["specials"], buddies[1].stats["specials"]],
		["Traps sprung", buddies[0].stats["traps"], buddies[1].stats["traps"]],
	]
	overlays.show_results({
		"title": title,
		"color": accent,
		"reason": result["reason"],
		"time": PRTheme.time_text(result["time"]),
		"rows": rows,
	})


# --- Pads -----------------------------------------------------------------------------------------

func _on_device_lost(slot: int) -> void:
	if state == State.MAJORS:
		input.move_seat_to_keyboard(slot)
		overlays.majors.open(input, roster)
		return
	if state != State.RACING and state != State.PAUSED:
		return
	overlays.show_pause(false)
	overlays.show_notice("CONTROLLER UNPLUGGED", "Reconnect the %s's controller, or press Enter to play that seat on the keyboard:\n%s" % [PRRoster.role_name(slot), PRInput.keyboard_legend(slot)])
	if state == State.RACING:
		_enter(State.PAUSED)


func _on_device_restored(_slot: int) -> void:
	if input.first_lost_seat() >= 0:
		return
	overlays.hide_notice()
	if state == State.PAUSED:
		overlays.show_big("1", PRTheme.WHITE, 0.9)
		_resume_time = 1.0


func _debug_text() -> String:
	var lines: PackedStringArray = ["F1 debug   state %s   t %.1f   fps %d" % [State.keys()[state], race_time, Engine.get_frames_per_second()]]
	for team in 2:
		var r := runners[team]
		lines.append("%s runner  pos (%.1f, %.1f)  vel (%.1f, %.1f)  floor %s  cp %d  stun %.1f" % [
			PRConfig.team_name(team), r.global_position.x - courses[team].global_position.x, r.global_position.y,
			r.velocity.x, r.velocity.y, r.is_on_floor(), r.checkpoint_index, r.stun_time])
		lines.append("   input: %s / %s" % [input.device_name(PRRoster.slot_for(team, 0)), input.device_name(PRRoster.slot_for(team, 1))])
		var b := buddies[team]
		lines.append("   buddy: %s  target %s  drop %.1f  trap %.1f  power %.1f%s" % [PRConfig.mode_name(b.mode), b.help_target.display_name if b.help_target else "-", b.drop_cooldown, b.trap_cooldown, b.power_cooldown, " ARMED" if b.power_armed else ""])
	return "\n".join(lines)
