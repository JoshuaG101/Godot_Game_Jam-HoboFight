extends Node
## Headless checks for the race flow: side select → major select → VS →
## countdown → race, pad seats (each pad drives only the seat it picked),
## keyboard layout, pause and the controls page, checkpoint spawns, camera
## framing, spike pits, win / timeout / draw, the results menu, and clean-up.
## Run:  godot --headless --fixed-fps 60 --path board res://Minigames/PlatformRace/race/tests/race_flow_test.tscn

const RACE_SCENE := preload("res://Minigames/PlatformRace/race/platform_race.tscn")

var failures := 0
var race: PRRaceManager
var _restart: Array = []


func _ready() -> void:
	await _test_flow()
	_test_keys()
	_test_pad_seats()
	await _test_pause()
	await _test_checkpoint_spawns()
	await _test_camera()
	await _test_spike_pits()
	await _test_win_and_menu()
	await _start_race()
	await _test_timeout_draw()
	race.queue_free()
	await _frames(3)
	_check("FL-09", not InputMap.has_action(&"pr2_r0_jump") and not InputMap.has_action(&"pr2_b1_action") and not InputMap.has_action(&"pr2_menu_up"), "pr2_* actions removed after the scene exits")
	print("RESULT: %s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	OS.delay_msec(150)
	await _frames(2)
	get_tree().quit(0 if failures == 0 else 1)


func _make_race(auto: bool) -> void:
	if race:
		race.queue_free()
		await _frames(2)
	race = RACE_SCENE.instantiate()
	race.allow_scene_change = false
	race.auto_ready = auto
	race.restart_requested.connect(func(roster: Dictionary, skip: bool) -> void: _restart = [roster, skip])
	add_child(race)
	await _frames(2)


func _start_race() -> void:
	await _make_race(true)
	for i in 400:
		await get_tree().physics_frame
		if race.state == PRRaceManager.State.RACING:
			break
	_check("FL-01g", race.state == PRRaceManager.State.RACING, "auto-ready race reaches RACING")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(3)
	Input.action_release(action)
	await _frames(2)


func _check(id: String, ok: bool, detail: String) -> void:
	print("%s %s  %s" % ["PASS" if ok else "FAIL", id, detail])
	if not ok:
		failures += 1


# --- Flow ------------------------------------------------------------------------------

func _test_flow() -> void:
	await _make_race(false)
	_check("FL-01a", race.state == PRRaceManager.State.SIDES and race.overlays.sides.visible, "starts on the side select")
	# Headless runs have no pads: the keyboard plays every seat; Enter continues.
	await _tap(&"pr2_confirm")
	_check("FL-01b", race.state == PRRaceManager.State.MAJORS and race.overlays.majors.visible and race.roster.devices == [-1, -1, -1, -1],
		"Enter with no controllers puts all four seats on the keyboard and opens the major select")
	# Blue Runner browses two to the right (A/D), everyone locks in.
	var start: int = race.overlays.majors.picks[0]
	await _tap(PRInput.seat_action(0, "right"))
	await _tap(PRInput.seat_action(0, "right"))
	var picked := wrapi(start + 2, 0, PRMajors.COUNT)
	for slot in PRConfig.SLOT_COUNT:
		await _tap(PRInput.seat_confirm(slot))
	_check("FL-01c", race.overlays.majors.all_locked(), "every seat locks in with its own confirm key")
	for i in 120:
		await get_tree().physics_frame
		if race.state != PRRaceManager.State.MAJORS:
			break
	_check("FL-01d", race.state == PRRaceManager.State.VERSUS and race.roster.majors[0] == picked and race.runners[0].power.major == picked,
		"all locked → VS screen, and the Blue Runner's power is the major they picked (%s)" % PRMajors.major_name(picked))
	for i in 400:
		await get_tree().physics_frame
		if race.state == PRRaceManager.State.RACING:
			break
	_check("FL-01e", race.state == PRRaceManager.State.RACING, "VS → countdown → RACING")


func _test_keys() -> void:
	# No physical key may drive two gameplay actions. Menu actions are only read
	# while a menu is open, so they may share keys.
	var seen_by := {}
	var clashes: PackedStringArray = []
	for action in InputMap.get_actions():
		var a := String(action)
		if not a.begins_with("pr2_") or a.begins_with("pr2_menu_"):
			continue
		for ev in InputMap.action_get_events(action):
			var key := ev as InputEventKey
			if key == null:
				continue
			var id := "%s/%d" % [OS.get_keycode_string(key.physical_keycode), key.location]
			if seen_by.has(id) and seen_by[id] != action:
				clashes.append("%s: %s + %s" % [id, seen_by[id], action])
			seen_by[id] = action
	_check("FL-02a", clashes.is_empty(), "no key drives two PlatformRace actions %s" % str(clashes))
	var want := {
		PRInput.runner_action(0, "left"): KEY_A, PRInput.runner_action(0, "right"): KEY_D, PRInput.runner_action(0, "jump"): KEY_W,
		PRInput.runner_action(1, "left"): KEY_LEFT, PRInput.runner_action(1, "right"): KEY_RIGHT, PRInput.runner_action(1, "jump"): KEY_UP,
	}
	var wrong: PackedStringArray = []
	for action in want:
		var evs := InputMap.action_get_events(action)
		if evs.size() != 1 or (evs[0] as InputEventKey).physical_keycode != want[action]:
			wrong.append(String(action))
	_check("FL-02b", wrong.is_empty(), "Runner 1 (Blue) is on WASD, Runner 2 (Gold) on the arrow keys %s" % str(wrong))


## The side select with two pretend pads (ids 0 and 1), then the bindings.
func _test_pad_seats() -> void:
	var sides := PRSideSelect.new()
	add_child(sides)
	sides.open(race.input, [])
	sides.cursors = {
		0: {"col": PRSideSelect.COL_CENTER, "role": 0, "locked": false},
		1: {"col": PRSideSelect.COL_CENTER, "role": 0, "locked": false},
		2: {"col": PRSideSelect.COL_CENTER, "role": 0, "locked": false},
	}
	sides.move(0, -1) # pad 0 → Blue side, Runner
	var ok0 := sides.lock(0)
	sides.move(1, 1) # pad 1 → Gold side, Runner
	var blocked := not sides.can_confirm()
	sides.lock(1)
	sides.move(2, -1) # pad 2 → Blue side: the Runner seat is taken, so Buddy
	var auto_buddy := sides.seat_of(2) == PRRoster.SLOT_BLUE_BUDDY
	sides.back(2) # changes its mind and sits out
	var devices := sides.devices()
	_check("FL-03a", ok0 and blocked and auto_buddy and sides.can_confirm() and devices == [0, -1, 1, -1],
		"pads pick sides: unlocked pads block Continue, a taken seat moves you to Buddy, a pad in the middle sits out (%s)" % str(devices))
	sides.close()
	sides.free()
	# Bind it: each pad drives only its own seat; the other seats stay on keys.
	var roster := PRRoster.new()
	roster.devices.assign(devices)
	race.input.bind_roster(roster)
	var problems: PackedStringArray = []
	for slot in PRConfig.SLOT_COUNT:
		var is_runner := PRRoster.slot_role(slot) == PRConfig.ROLE_RUNNER
		for a in PRInput.RUNNER_ACTIONS if is_runner else PRInput.BUDDY_ACTIONS:
			for ev in InputMap.action_get_events(PRInput.seat_action(slot, a)):
				var pad_event := ev is InputEventJoypadButton or ev is InputEventJoypadMotion
				if devices[slot] == PRRoster.KEYBOARD and pad_event:
					problems.append("%s has a pad event" % PRInput.seat_action(slot, a))
				elif devices[slot] != PRRoster.KEYBOARD and (not pad_event or ev.device != devices[slot]):
					problems.append("%s not only pad %d" % [PRInput.seat_action(slot, a), devices[slot]])
	_check("FL-03b", problems.is_empty(), "a pad drives only the seat it picked; keyboard seats ignore pads %s" % str(problems))
	race.input.bind_roster(race.roster)


func _test_pause() -> void:
	await _tap(&"pr2_pause")
	_check("FL-04a", race.state == PRRaceManager.State.PAUSED and get_tree().paused and race.overlays.is_pause_visible(), "Esc pauses the race")
	await _tap(PRInput.menu_action("down")) # → CONTROLS
	await _tap(PRInput.menu_action("accept"))
	_check("FL-04b", race.overlays.is_controls_visible(), "the pause menu opens the controls page")
	await _tap(PRInput.menu_action("back"))
	_check("FL-04c", race.overlays.is_pause_visible() and race.state == PRRaceManager.State.PAUSED, "Back returns to the pause menu")
	await _tap(&"pr2_pause")
	_check("FL-04d", race.state == PRRaceManager.State.RACING and not get_tree().paused, "Esc again resumes")


# --- Course ---------------------------------------------------------------------------------

func _test_checkpoint_spawns() -> void:
	# Every checkpoint must be a spot where the Runner stands on static ground.
	var r := race.runners[0]
	var course := race.courses[0]
	var bad: PackedStringArray = []
	for cp in course.get_checkpoints():
		r.place_at(cp.global_position + Vector3(0, 0.05, 0), cp.index)
		await _frames(20)
		var ok := r.is_on_floor() and absf(r.global_position.y - cp.global_position.y) < 0.2 and r._standing_on_static()
		if not ok:
			bad.append("CP%d (y %.2f, floor %s)" % [cp.index, r.global_position.y, r.is_on_floor()])
	_check("FL-05", bad.is_empty() and course.get_checkpoint_count() == PRConfig.SECTION_COUNT, "all six checkpoints are standable static ground %s" % str(bad))
	r.place_at(course.get_start_position(), 1)
	await _frames(10)


func _test_camera() -> void:
	var cam := race.cameras[0]
	var other := race.courses[1].global_position
	var fails: PackedStringArray = []
	for y in [0.0, 15.0, 30.0, 45.0, 60.0, 74.0]:
		race.runners[0].place_at(Vector3(0, y, 0), 1)
		cam.snap()
		await _frames(2)
		var cy := cam.global_position.y
		for x in [-7.0, 7.0]:
			if not cam.is_position_in_frustum(Vector3(x, cy, 1.5)):
				fails.append("edge x=%.0f not visible at y=%.0f" % [x, y])
		if cam.is_position_in_frustum(other + Vector3(-8, cy, 0)):
			fails.append("other course visible at y=%.0f" % y)
	var vp := cam.get_viewport().get_visible_rect().size
	_check("FL-06", fails.is_empty(), "view %dx%d shows full width, never the other course %s" % [vp.x, vp.y, str(fails)])
	race.runners[0].place_at(race.courses[0].get_start_position(), 1)
	cam.snap()
	await _frames(5)


func _test_spike_pits() -> void:
	var r := race.runners[0]
	var course := race.courses[0]
	# Drop points just above each spike strip, clear of moving platforms.
	var cases := [[2, Vector3(-3.0, 11.0, 0)], [5, Vector3(2.0, 51.5, 0)]]
	var bad: PackedStringArray = []
	for c in cases:
		var idx: int = c[0]
		var cp := course.get_checkpoint(idx)
		r.place_at(cp.global_position, idx)
		await _frames(5)
		r.global_position = course.global_position + (c[1] as Vector3)
		var falls_before := r.falls
		var ok := false
		for i in 200:
			await get_tree().physics_frame
			if r.is_respawning():
				continue
			if r.falls > falls_before and r.global_position.distance_to(cp.global_position) < 0.3:
				ok = true
				break
		if not ok:
			bad.append("S%d pit → (%.1f, %.1f)" % [idx, r.global_position.x - course.global_position.x, r.global_position.y])
	_check("FL-07", bad.is_empty(), "spike pits in S2 and S5 respawn at that section's checkpoint %s" % str(bad))


# --- Results --------------------------------------------------------------------------------

func _test_win_and_menu() -> void:
	var gate := race.courses[0].get_finish_gate()
	race.runners[0].place_at(gate.global_position + Vector3(0, 0.1, 0), 6)
	for i in 30:
		await get_tree().physics_frame
		if race.state == PRRaceManager.State.RESULTS:
			break
	var ok: bool = race.state == PRRaceManager.State.RESULTS and race.result.get("winner") == 0
	_check("FL-08a", ok and race.overlays.is_results_visible(), "Blue finishing first → results, winner %s" % race.result.get("winner"))
	# The menu ignores input for RESULTS_INPUT_DELAY, then Accept picks REMATCH.
	_restart = []
	await _tap(PRInput.menu_action("accept"))
	var early := _restart.is_empty()
	await _frames(int(PRConfig.RESULTS_INPUT_DELAY * 60) + 5)
	await _tap(PRInput.menu_action("accept"))
	_check("FL-08b", early and _restart.size() == 2 and _restart[1] == true and _restart[0]["majors"] == race.roster.majors,
		"after the delay, REMATCH restarts with the same seats and majors")
	await _tap(PRInput.menu_action("down"))
	_restart = []
	await _tap(PRInput.menu_action("accept"))
	_check("FL-08c", _restart.size() == 2 and _restart[1] == false, "CHANGE SIDES & MAJORS goes back to the side select")


func _test_timeout_draw() -> void:
	race.race_time = PRConfig.TIME_LIMIT - 0.05
	for i in 30:
		await get_tree().physics_frame
		if race.state == PRRaceManager.State.RESULTS:
			break
	_check("FL-08d", race.result.get("kind") == "draw", "timeout with equal progress → %s" % race.result.get("kind"))
