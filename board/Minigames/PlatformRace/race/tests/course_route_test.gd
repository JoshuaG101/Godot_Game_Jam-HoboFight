extends Node
## Plays the Blue course start to finish with a scripted Runner bot, working the
## HELP machines the way the Buddy would, to prove every section can be
## completed (RT-01). Then checks that the Rune Steps and the Drawbridge can't be
## skipped without the Buddy (RT-02).
## Run:  godot --headless --fixed-fps 60 --path board res://Minigames/PlatformRace/race/tests/course_route_test.tscn
## Set ROUTE_TRACE=1 to print every move.

const RACE_SCENE := preload("res://Minigames/PlatformRace/race/platform_race.tscn")

var failures := 0
var race: PRRaceManager
var r: PRRunner
var course: PRCourse
var _t0 := 0
var _total := 0.0


func _ready() -> void:
	race = RACE_SCENE.instantiate()
	race.allow_scene_change = false
	race.auto_ready = true
	add_child(race)
	for i in 400:
		await get_tree().physics_frame
		if race.state == PRRaceManager.State.RACING:
			break
	r = race.runners[0]
	course = race.courses[0]
	# Keep the other team's Buddy from interfering.
	race.buddies[1].active = false
	var ok := true
	ok = ok and await _section("S1 crate, ledge + lift (HELP)", _s1, 2)
	ok = ok and await _section("S2 rampart hops (HINDER)", _s2, 3)
	ok = ok and await _section("S3 rune steps (HELP)", _s3, 4)
	ok = ok and await _section("S4 chimney (HINDER)", _s4, 5)
	ok = ok and await _section("S5 drawbridges + lift (HELP)", _s5, 6)
	ok = ok and await _section("S6 final climb (HINDER)", _s6, -1)
	print("     bot total %.1f s (time limit %.0f s)" % [_total, PRConfig.TIME_LIMIT])
	await _test_cant_skip()
	print("RESULT: %s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	# Free the race and let the audio server drop its sounds before quitting.
	# Free the race, then give the audio thread real time to drop its sounds
	# (headless tests run far faster than real time).
	race.queue_free()
	await _frames(3)
	OS.delay_msec(150)
	await _frames(2)
	get_tree().quit(0 if failures == 0 else 1)


func _section(label: String, body: Callable, expect_cp: int) -> bool:
	race.race_time = 0.0 # keep the time limit out of the way
	_t0 = Engine.get_physics_frames()
	await body.call()
	_steer(0)
	_release(&"jump")
	var secs := (Engine.get_physics_frames() - _t0) / 60.0
	_total += secs
	var ok: bool
	if expect_cp > 0:
		ok = r.checkpoint_index >= expect_cp
	else:
		ok = r.has_finished
	print("%s %-34s %5.1f s   cp %d   at (%.1f, %.1f)" % ["PASS" if ok else "FAIL", label, secs, r.checkpoint_index, _x(), r.global_position.y])
	if not ok:
		failures += 1
	return ok


# --- Sections -----------------------------------------------------------------

func _s1() -> void:
	await _walk_to(-1.9)
	await _hop_onto(-0.3, 1.2)
	_lap("crate")
	await _jump_to(2.8, 3.0)
	_lap("ledge")
	await _walk_to(5.4)
	var l1 := _dev("L1") as PRLift
	await _drive(l1, l1.track.length())
	_lap("lift")
	await _walk_to(2.5)


func _s2() -> void:
	await _walk_to(1.5)
	await _jump_to(-1.0, 14.4)
	_lap("crumble")
	await _jump_to(-3.75, 15.0)
	_lap("step")
	var ap1 := _dev("AP1") as PRLift
	await _wait_until(func() -> bool: return ap1.travel < 0.1, 900)
	await _hop_onto(-6.0, 16.2)
	_lap("on AP1")
	await _ride(ap1, func() -> bool: return ap1.travel > ap1.track.length() - 0.05, 0.0)
	await _jump_to(-2.75, 22.8)
	_lap("ledge A")
	await _walk_to(-1.95)
	await _jump_to(2.25, 24.2)
	_lap("ledge B")
	await _walk_to(2.85)
	await _jump_to(5.5, 25.6)


func _s3() -> void:
	var rs := _dev("RuneSteps") as PRSwapSteps
	await _walk_to(4.5)
	# Buddy: make the blue (set 0) steps solid.
	if rs.solid_set != 0:
		rs.press(0)
	await _frames(10)
	await _hop_onto(1.75, 27.8)
	_lap("SW1")
	# Sets: SW1 blue, SW2 + SW3 gold, SW4 blue. Once the feet clear the next
	# step, the Buddy switches sets; SW2 → SW3 is the same set.
	await _rune_jump(rs, -0.75, 29.6)
	_lap("SW2")
	await _walk_to(-0.4)
	await _hop_onto(1.75, 31.4)
	_lap("SW3")
	await _walk_to(1.4)
	await _rune_jump(rs, -0.75, 33.2)
	_lap("SW4")
	await _walk_to(-1.1)
	await _jump_to(-3.4, 35.0)
	await _walk_to(-5.5)


func _s4() -> void:
	await _climb(52.0, -1.75, -1)


func _s5() -> void:
	var d1 := _dev("D1") as PRDrawbridge
	d1.press(0)
	await _wait_until(func() -> bool: return d1.is_solid, 120)
	await _walk_to(4.5)
	_lap("bridge 1")
	var l2 := _dev("L2") as PRLift
	await _walk_to(6.0)
	await _drive(l2, l2.track.length())
	_lap("lift")
	await _walk_to(3.5)
	var d2 := _dev("D2") as PRDrawbridge
	d2.press(0)
	await _wait_until(func() -> bool: return d2.is_solid, 120)
	await _walk_to(-4.0)


func _s6() -> void:
	var ap2 := _dev("AP2") as PRLift
	var ap3 := _dev("AP3") as PRLift
	await _wait_until(func() -> bool: return ap2.travel < 0.1, 900)
	await _walk_to(-6.0)
	_lap("on AP2")
	await _ride(ap2, func() -> bool: return ap2.travel > ap2.track.length() - 0.05, 0.0)
	await _jump_to(-2.25, 67.4)
	_lap("ledge A")
	await _walk_to(-1.4)
	await _wait_until(func() -> bool: return ap3.travel < 0.1, 900)
	await _hop_onto(0.5, 69.0)
	_lap("on AP3")
	await _ride(ap3, func() -> bool: return ap3.travel > ap3.track.length() - 0.05, 0.0)
	await _jump_to(6.0, 70.8)
	_lap("ledge B")
	await _walk_to(5.4)
	await _jump_to(1.5, 72.6)
	_lap("ledge C")
	await _walk_to(0.9)
	await _jump_to(-2.25, 74.4)
	await _frames(20)


# --- RT-02: HELP machines can't be skipped -------------------------------------------

func _test_cant_skip() -> void:
	# The race ended when the bot finished; give the Runner control back.
	r.has_finished = false
	r.controls_enabled = true
	r._anim_lock = 0.0
	# Rune Steps with the Buddy idle (gold set solid): the first blue step is
	# not there, so the Runner must not reach the chimney.
	var rs := _dev("RuneSteps") as PRSwapSteps
	if rs.solid_set != 1:
		rs.press(0)
	await _frames(10)
	var cp3 := course.get_checkpoint(3)
	r.place_at(cp3.global_position, 3)
	await _frames(10)
	await _walk_to(4.5)
	await _hop_onto(1.75, 27.8)
	await _hop_onto(-0.75, 29.6)
	await _frames(30)
	_check("RT-02a", r.checkpoint_index == 3 and r.global_position.y < 29.0, "without switching, the Rune Steps can't be climbed (cp %d, y %.1f)" % [r.checkpoint_index, r.global_position.y])
	# Drawbridge left in: a full running jump across the pit must fail.
	var d1 := _dev("D1") as PRDrawbridge
	await _wait_until(func() -> bool: return d1.phase == PRDrawbridge.Phase.IN, 900)
	var cp5 := course.get_checkpoint(5)
	r.place_at(cp5.global_position + Vector3(-1.0, 0, 0), 5)
	await _frames(10)
	var falls := r.falls
	_steer(1)
	await _frames(14)
	_press(&"jump")
	for i in 120:
		await get_tree().physics_frame
		if r.is_respawning() or r.is_on_floor() and i > 10:
			break
	_release(&"jump")
	_steer(0)
	await _frames(90)
	var crossed := _x() > 3.8 and r.global_position.y > 51.5 and r.falls == falls
	_check("RT-02b", not crossed, "without the drawbridge, the pit can't be jumped (x %.1f, y %.1f, fell %s)" % [_x(), r.global_position.y, r.falls > falls])


# --- Bot helpers --------------------------------------------------------------

func _check(id: String, ok: bool, detail: String) -> void:
	print("%s %s  %s" % ["PASS" if ok else "FAIL", id, detail])
	if not ok:
		failures += 1


func _lap(what: String) -> void:
	if OS.get_environment("ROUTE_TRACE") != "":
		print("    %-9s %5.2f s  at (%.2f, %.2f)  cp %d" % [what, (Engine.get_physics_frames() - _t0) / 60.0, _x(), r.global_position.y, r.checkpoint_index])


func _x() -> float:
	return r.global_position.x - course.global_position.x


func _dev(node_name: String) -> Node:
	return course.get_node("Devices/" + node_name)


func _press(a: StringName) -> void:
	Input.action_press(PRInput.runner_action(0, String(a)))


func _release(a: StringName) -> void:
	Input.action_release(PRInput.runner_action(0, String(a)))


func _steer(dir: int) -> void:
	if dir < 0:
		_release(&"right")
		_press(&"left")
	elif dir > 0:
		_release(&"left")
		_press(&"right")
	else:
		_release(&"left")
		_release(&"right")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _walk_to(x: float, max_frames := 400) -> void:
	for i in max_frames:
		await get_tree().physics_frame
		var dx := x - _x()
		if absf(dx) < 0.15:
			break
		# Ease off near the target so the bot doesn't overshoot.
		_steer(int(signf(dx)) if absf(dx) > 0.6 or absf(r.velocity.x) < 3.0 else 0)
	_steer(0)
	await _frames(12)


## Jump straight up, steer over the target once the feet clear its top, land.
func _hop_onto(center_x: float, top_y: float) -> void:
	_press(&"jump")
	var airborne := false
	for i in 150:
		await get_tree().physics_frame
		if r.global_position.y > top_y + 0.05:
			var dx := center_x - _x()
			_steer(int(signf(dx)) if absf(dx) > 0.25 else 0)
		if not r.is_on_floor():
			airborne = true
		elif airborne and r.velocity.y <= 0.0:
			break
	_release(&"jump")
	_steer(0)
	await _frames(10)


## A running jump: steer toward the target from the start, stop over it.
func _jump_to(center_x: float, top_y: float) -> void:
	_press(&"jump")
	var airborne := false
	for i in 150:
		await get_tree().physics_frame
		var dx := center_x - _x()
		var over := r.global_position.y > top_y + 0.05
		_steer(int(signf(dx)) if absf(dx) > 0.3 or not over else 0)
		if not r.is_on_floor():
			airborne = true
		elif airborne and r.velocity.y <= 0.0:
			break
	_release(&"jump")
	_steer(0)
	await _frames(10)


## A jump between Rune Steps: the Buddy switches sets once the feet clear the
## next step's top, then the bot steers onto it.
func _rune_jump(rs: PRSwapSteps, center_x: float, top_y: float) -> void:
	_press(&"jump")
	var switched := false
	var airborne := false
	for i in 150:
		await get_tree().physics_frame
		var y := r.global_position.y
		if not switched and y > top_y + 0.1:
			rs.press(0)
			switched = true
		var dx := center_x - _x()
		var over := y > top_y + 0.05
		_steer(int(signf(dx)) if absf(dx) > 0.3 or not over else 0)
		if not r.is_on_floor():
			airborne = true
		elif airborne and switched and r.velocity.y <= 0.0:
			break
	_release(&"jump")
	_steer(0)
	await _frames(10)


## Hold a Lift (as its Buddy would) until it has travelled `to`.
func _drive(lift: PRLift, to: float) -> void:
	for i in 600:
		lift.hold(0)
		await get_tree().physics_frame
		if lift.travel >= to - 0.01:
			break
	await _frames(15)


## Stay on a moving platform (near its centre + offset) until cond is true.
func _ride(lift: PRLift, cond: Callable, offset: float) -> void:
	for i in 900:
		await get_tree().physics_frame
		var px := lift.get_platform_body().global_position.x - course.global_position.x + offset
		var dx := px - _x()
		_steer(int(signf(dx)) if absf(dx) > 0.2 else 0)
		if cond.call():
			break
	_steer(0)
	await _frames(5)


## Alternating wall-jump climb. first_dir is the first wall to jump at (+1 =
## right). The bot steers away from the wall it just used; once a jump clears
## exit_y it carries the Runner onto the exit ledge.
func _climb(exit_y: float, exit_x: float, first_dir: int) -> void:
	_steer(first_dir)
	_press(&"jump")
	await _frames(8)
	_release(&"jump")
	for i in 1500:
		await get_tree().physics_frame
		var y := r.global_position.y
		if r.is_on_floor() and y >= exit_y - 0.2:
			break
		var last: int = r._last_wall_side
		_steer(last if last != 0 else first_dir)
		var wall := r._probe_wall()
		if r.is_on_floor() or (wall != 0 and wall != last):
			_press(&"jump")
			await get_tree().physics_frame
			_release(&"jump")
	await _walk_to(exit_x)
