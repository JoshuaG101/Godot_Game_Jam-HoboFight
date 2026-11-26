extends Node3D
## Headless movement checks for the Runner (design doc §8.2, PH-01 to PH-06).
## Run:  godot --headless --fixed-fps 60 --path board res://Minigames/PlatformRace/race/tests/runner_test.tscn
## Exits with code 0 when every check passes, 1 otherwise.

const RUNNER_SCENE := preload("res://Minigames/PlatformRace/race/runner/runner.tscn")
const BLOCK_SCENE := preload("res://Minigames/PlatformRace/race/course/block.tscn")
const LIFT_SCENE := preload("res://Minigames/PlatformRace/race/devices/lift.tscn")

var input: PRInput
var runner: PRRunner
var failures := 0


func _ready() -> void:
	input = PRInput.new()
	add_child(input)
	_build_room()
	runner = RUNNER_SCENE.instantiate()
	add_child(runner)
	runner.setup(0, null, "T")
	runner.controls_enabled = true
	await _run_all()
	print("RESULT: %s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	get_tree().quit(0 if failures == 0 else 1)


func _run_all() -> void:
	await _test_jump_heights()
	await _test_running_jump()
	await _test_coyote()
	await _test_buffer()
	await _test_same_wall()
	await _test_chimney()
	await _test_lift()


# --- Room ---------------------------------------------------------------------
# Floor A: x[-30, 0] top 0. Ledge B: x[0, 10] top 3 (for coyote / buffer tests).
# Chimney at x = 50: left wall full height, right wall starting 2.8 up.
# Single wall at x = 80 (same-wall test). Lift at x = 110.

func _build_room() -> void:
	_block(Vector3(-15, -0.5, 0), Vector3(30, 1, 3))
	_block(Vector3(5, 2.5, 0), Vector3(10, 1, 3))
	_block(Vector3(25, -0.5, 0), Vector3(30, 1, 3)) # floor right of the ledge, top 0
	# Chimney: interior x[48.5, 51.5]
	_block(Vector3(50, -0.5, 0), Vector3(6, 1, 3))
	_block(Vector3(48, 10, 0), Vector3(1, 20, 3), true)
	_block(Vector3(52, 11.4, 0), Vector3(1, 17.2, 3), true)
	# Single wall: floor + wall on the left at x[79, 80]
	_block(Vector3(85, -0.5, 0), Vector3(14, 1, 3))
	_block(Vector3(79.5, 10, 0), Vector3(1, 20, 3), true)
	# Lift test
	_block(Vector3(110, -0.5, 0), Vector3(10, 1, 3))
	var lift: PRLift = LIFT_SCENE.instantiate()
	lift.name = "TestLift"
	lift.position = Vector3(110, 0.5, 0)
	lift.track = Vector3(0, 6, 0)
	lift.auto_move = false
	lift.end_dwell = 10.0
	add_child(lift)


func _block(center: Vector3, size: Vector3, wall := false) -> void:
	var b: PRBlock = BLOCK_SCENE.instantiate()
	b.position = center
	b.size = size
	b.allow_wall_jump = wall
	add_child(b)


# --- Input helpers ------------------------------------------------------------

func _press(action: String) -> void:
	Input.action_press(PRInput.runner_action(0, action))


func _release(action: String) -> void:
	Input.action_release(PRInput.runner_action(0, action))


func _release_all() -> void:
	for a in PRInput.RUNNER_ACTIONS:
		_release(a)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _place(pos: Vector3) -> void:
	_release_all()
	runner.place_at(pos, 1)
	runner.checkpoint_position = Vector3(pos.x, -100, 0) # disable the fall rule
	await _frames(20)


func _check(id: String, ok: bool, detail: String) -> void:
	print("%s %s  %s" % ["PASS" if ok else "FAIL", id, detail])
	if not ok:
		failures += 1


# --- Tests --------------------------------------------------------------------

func _test_jump_heights() -> void:
	await _place(Vector3(-10, 0, 0))
	var base := runner.global_position.y
	await get_tree().physics_frame
	_press("jump")
	await _frames(1)
	_release("jump")
	var peak := base
	for i in 90:
		await get_tree().physics_frame
		peak = maxf(peak, runner.global_position.y)
	var tap := peak - base
	_check("PH-01a", tap > 0.9 and tap < 1.6, "tap jump height %.2f (target ≈1.2)" % tap)

	await _place(Vector3(-10, 0, 0))
	await get_tree().physics_frame
	_press("jump")
	peak = base
	for i in 90:
		await get_tree().physics_frame
		peak = maxf(peak, runner.global_position.y)
	_release("jump")
	var hold := peak - base
	_check("PH-01b", hold > 2.6 and hold < 3.0, "held jump height %.2f (target ≈2.8)" % hold)


func _test_running_jump() -> void:
	await _place(Vector3(-28, 0, 0))
	_press("right")
	await _frames(45) # reach full speed
	var start_x := runner.global_position.x
	_press("jump")
	await get_tree().physics_frame
	var left_floor := false
	var land_x := start_x
	for i in 120:
		await get_tree().physics_frame
		if not runner.is_on_floor():
			left_floor = true
		elif left_floor:
			land_x = runner.global_position.x
			break
	_release_all()
	var dist := land_x - start_x
	_check("PH-01c", dist > 6.0 and dist < 7.2, "running jump distance %.2f (target ≈6.6), speed %.1f" % [dist, runner.max_speed])


func _test_coyote() -> void:
	# Walk off the right edge of the ledge (x = 10, top 3) and jump 0.08 s later.
	await _place(Vector3(7, 3, 0))
	_press("right")
	var off_frame := -1
	for i in 120:
		await get_tree().physics_frame
		if not runner.is_on_floor() and runner.global_position.x > 9.5:
			off_frame = i
			break
	await _frames(4) # ≈0.067 s more, ~0.08 s after leaving the floor
	_press("jump")
	await _frames(2)
	var vy := runner.velocity.y
	_release_all()
	_check("PH-02", off_frame >= 0 and vy > 5.0, "jump 0.08 s after leaving the ledge: vy = %.1f" % vy)
	await _frames(60)


func _test_buffer() -> void:
	# Drop from the ledge onto the floor (top 0) and press jump ~0.1 s before landing.
	await _place(Vector3(12, 3, 0))
	runner.global_position = Vector3(12, 4.5, 0)
	await get_tree().physics_frame
	var pressed := false
	var jumped_on_landing := false
	for i in 120:
		await get_tree().physics_frame
		var y := runner.global_position.y
		var vy := runner.velocity.y
		# Time to land ≈ y / |vy|; press when ~0.1 s away.
		if not pressed and vy < -0.1 and y / -vy < 0.1:
			_press("jump")
			await get_tree().physics_frame
			_release("jump")
			pressed = true
		if pressed and runner.velocity.y > 5.0:
			jumped_on_landing = true
			break
	_check("PH-03", pressed and jumped_on_landing, "buffered jump fired on landing: %s" % jumped_on_landing)
	_release_all()
	await _frames(90)


func _test_same_wall() -> void:
	# Jump at the single wall, wall jump off it, steer back into the same wall and try again.
	await _place(Vector3(81.5, 0, 0))
	_press("left")
	_press("jump")
	await _frames(12)
	_release("jump")
	var first := await _wait_wall_jump(30)
	_release_all()
	await _frames(8)
	_press("left")
	var touching := false
	for i in 60:
		await get_tree().physics_frame
		if runner._probe_wall() == 1 and not runner.is_on_floor():
			touching = true
			break
	_press("jump")
	await _frames(2)
	_release("jump")
	var vy_after := runner.velocity.y
	var second := vy_after > 9.0
	_release_all()
	_check("PH-04", first and touching and not second, "first wall jump %s, back on the same wall %s, second jump refused: %s (vy %.1f)" % [first, touching, not second, vy_after])
	await _frames(90)


func _wait_wall_jump(max_frames: int) -> bool:
	for i in max_frames:
		await get_tree().physics_frame
		if runner._probe_wall() != 0 and not runner.is_on_floor():
			# Input.action_press() registers on the NEXT physics frame, so check after two.
			_press("jump")
			await _frames(2)
			_release("jump")
			return runner.velocity.y > 9.0
	return false


func _test_chimney() -> void:
	# Bot climbs the 3-wide chimney by alternating walls; count jumps to rise 11.2.
	await _place(Vector3(50, 0, 0))
	var jumps := 0
	_press("left")
	_press("jump")
	await _frames(10)
	_release("jump")
	var climbed := false
	var peak := 0.0
	for i in 600:
		await get_tree().physics_frame
		var wall := runner._probe_wall()
		var last: int = runner._last_wall_side
		# Steer toward the wall opposite the one just used.
		var steer := last if last != 0 else -1
		if steer > 0:
			_release("left")
			_press("right")
		else:
			_release("right")
			_press("left")
		if wall != 0 and wall != last and not runner.is_on_floor():
			_press("jump")
			await get_tree().physics_frame
			_release("jump")
			jumps += 1
		peak = maxf(peak, runner.global_position.y)
		if runner.global_position.y >= 11.2:
			climbed = true
			break
	_release_all()
	_check("PH-05", climbed and jumps <= 8, "climbed 11.2 in %d wall jumps (target ≈6), peak %.1f" % [jumps, peak])
	await _frames(60)


func _test_lift() -> void:
	# Stand on an auto lift, ride it up, then jump off at the top.
	var lift := get_node("TestLift") as PRLift
	lift.auto_move = false
	lift.travel = 0.0
	lift._dir = 1.0
	lift._dwell = 0.0
	await _place(Vector3(110, 0.6, 0))
	lift.auto_move = true
	var rode := false
	var peak := 0.0
	for i in 240:
		await get_tree().physics_frame
		if runner.is_on_floor() and runner.global_position.y > 3.0:
			rode = true
			break
	_check("PH-06a", rode, "carried up by the lift, standing at y = %.2f" % runner.global_position.y)
	# Jump while the lift is still rising: the lift's speed should be added.
	var base := runner.global_position.y
	_press("jump")
	for i in 90:
		await get_tree().physics_frame
		peak = maxf(peak, runner.global_position.y)
	_release_all()
	_check("PH-06b", peak - base > 3.0, "jump off a rising lift rose %.2f (a normal jump is 2.87)" % (peak - base))
