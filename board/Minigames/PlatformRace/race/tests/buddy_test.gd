extends Node
## Headless checks for the Buddy (BD-01 to BD-06): the mode follows the Runner's
## stage, the Buddy chooses HELP or HINDER when both are possible, machine
## picking (and the Lift stuck at the top of S5), barrels stun without
## knockback, the S1 safe zone, every trap, and HELP BOOST / SPREE.
## Run:  godot --headless --fixed-fps 60 --path board res://Minigames/PlatformRace/race/tests/buddy_test.tscn

const RACE_SCENE := preload("res://Minigames/PlatformRace/race/platform_race.tscn")

var failures := 0
var race: PRRaceManager
var blue: PRRunner
var gold: PRRunner
var course: PRCourse


func _ready() -> void:
	race = RACE_SCENE.instantiate()
	race.allow_scene_change = false
	race.auto_ready = true
	add_child(race)
	for i in 400:
		await get_tree().physics_frame
		if race.state == PRRaceManager.State.RACING:
			break
	blue = race.runners[0]
	gold = race.runners[1]
	course = race.courses[0]
	await _test_modes()
	await _test_choice()
	await _test_picking()
	await _test_safe_zone()
	await _test_barrel()
	await _test_traps()
	await _test_boost()
	print("RESULT: %s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	# Free the race, then give the audio thread real time to drop its sounds
	# (headless tests run far faster than real time).
	race.queue_free()
	await _frames(3)
	OS.delay_msec(150)
	await _frames(2)
	get_tree().quit(0 if failures == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(id: String, ok: bool, detail: String) -> void:
	print("%s %s  %s" % ["PASS" if ok else "FAIL", id, detail])
	if not ok:
		failures += 1


func _at(runner: PRRunner, local: Vector3, cp: int) -> void:
	var c := race.courses[runner.team]
	runner.place_at(c.global_position + local, cp)


func _cp(runner: PRRunner, index: int) -> void:
	var c := race.courses[runner.team]
	runner.place_at(c.get_checkpoint(index).global_position, index)


func _reset_cooldowns() -> void:
	for b in race.buddies:
		b.drop_cooldown = 0.0
		b.trap_cooldown = 0.0
		b.stun_time = 0.0


static func _name(n: Node) -> String:
	return str(n.name) if n else "none"


func _dev(c: PRCourse, node_name: String) -> PRDevice:
	return c.get_node("Devices/" + node_name) as PRDevice


# --- BD-01: the mode follows the stage -----------------------------------------------------

func _test_modes() -> void:
	var b := race.buddies[0]
	var seen: Array[int] = []
	b.mode_changed.connect(func(_t: int, m: int) -> void: seen.append(m))
	_cp(gold, 2) # the enemy can be hindered
	var got: PackedStringArray = []
	var ok := true
	for i in range(1, 7):
		_cp(blue, i)
		await _frames(3)
		got.append("CP%d %s" % [i, PRConfig.mode_name(b.mode)])
		if b.mode != PRConfig.stage_for_checkpoint(i):
			ok = false
	_check("BD-01a", ok, "entering a section starts the Buddy in that stage's mode: %s" % ", ".join(got))
	_check("BD-01b", seen.size() >= 5, "mode_changed fired on every switch (%d times)" % seen.size())


# --- BD-02: choosing HELP or HINDER ---------------------------------------------------------

func _test_choice() -> void:
	var b := race.buddies[0]
	_cp(gold, 2)
	_cp(blue, 3) # a HELP stage with machines, and the enemy can be hindered
	await _frames(3)
	var both := b.can_switch()
	var first := b.toggle_mode()
	var after_first := b.mode
	Input.action_press(PRInput.buddy_action(0, "mode"))
	await _frames(2)
	Input.action_release(PRInput.buddy_action(0, "mode"))
	await _frames(2)
	_check("BD-02a", both and first == "" and after_first == PRConfig.Mode.HINDER and b.mode == PRConfig.Mode.HELP,
		"in a HELP stage with the enemy past S1 the Buddy can switch (toggle → HINDER, Switch key → HELP)")
	_cp(blue, 2) # a HINDER stage: no machines to work
	await _frames(3)
	var refused := b.toggle_mode()
	_check("BD-02b", not b.can_switch() and refused != "" and b.mode == PRConfig.Mode.HINDER,
		"in a HINDER stage there is nothing to help with, so the switch is refused (%s)" % refused)
	_cp(blue, 3)
	await _frames(3)
	b.toggle_mode()
	_cp(gold, 1) # the enemy goes back to the safe zone: HINDER is no longer possible
	await _frames(3)
	_check("BD-02c", b.mode == PRConfig.Mode.HELP, "a Buddy hindering a Runner who returns to S1 falls back to HELP (%s)" % PRConfig.mode_name(b.mode))


# --- BD-03: picking machines (and the Lift stuck at the top of S5) ----------------------------

func _test_picking() -> void:
	var b := race.buddies[0]
	_cp(gold, 1)
	var d1 := _dev(course, "D1")
	var d2 := _dev(course, "D2")
	var l2 := _dev(course, "L2") as PRLift
	_cp(blue, 5)
	await _frames(3)
	var near_cp := b.help_target
	# The reported bug: the Runner waits at the bottom of L2 while it is parked at
	# the top. The Buddy must target L2, not the nearer-looking drawbridge.
	l2.travel = l2.track.length()
	_at(blue, Vector3(4.5, 52.05, 0), 5)
	await _frames(3)
	var near_lift := b.help_target
	_check("BD-03a", near_cp == d1 and near_lift == l2 and l2.is_worked() and not d1.is_worked(),
		"auto-pick follows the Runner: D1 at the checkpoint, L2 (parked at the top) at its foot: %s, %s" % [_name(near_cp), _name(near_lift)])
	# Holding Action brings the parked Lift back down.
	var top := l2.travel
	Input.action_press(PRInput.buddy_action(0, "action"))
	await _frames(90)
	Input.action_release(PRInput.buddy_action(0, "action"))
	await _frames(3)
	_check("BD-03b", top - l2.travel > 2.5, "holding Action drives the parked L2 down (%.1f → %.1f)" % [top, l2.travel])
	# Left / Right pick by hand, left to right: D2, D1, L2.
	var choices := b.help_choices()
	b.pick_machine(-1)
	var p1 := b.help_target
	b.pick_machine(-1)
	var p2 := b.help_target
	_at(blue, Vector3(-1.0, 52.05, 0), 5) # right next to D1
	await _frames(3)
	var kept := b.help_target
	_check("BD-03c", choices == [d2, d1, l2] and p1 == d1 and p2 == d2 and kept == d2 and d2.is_worked(),
		"Left picks D1 then D2, and a hand-picked machine stays picked as the Runner moves")
	_cp(blue, 6)
	await _frames(3)
	_cp(blue, 5)
	await _frames(3)
	_check("BD-03d", b.help_target == d1, "a new section goes back to auto-picking (%s)" % _name(b.help_target))
	l2.travel = 0.0


# --- BD-04: safe zone ---------------------------------------------------------------------------

func _test_safe_zone() -> void:
	_reset_cooldowns()
	var b := race.buddies[1] # Gold hinders Blue while Gold is in S2.
	_cp(gold, 2)
	_cp(blue, 1)
	await _frames(3)
	var drop := b.try_drop()
	var trap := b.try_trap()
	_check("BD-04", drop == "SAFE ZONE" and trap == "SAFE ZONE" and not b.dropper.shown, "no hindering while Blue is in S1 (drop: %s, trap: %s)" % [drop, trap])


# --- BD-05: barrels ------------------------------------------------------------------------------

func _test_barrel() -> void:
	_reset_cooldowns()
	var b := race.buddies[1]
	_cp(gold, 2)
	# The chimney base: open sky above, so the barrel reaches the Runner. (Ledges
	# overhead stop barrels, which is how Runners take cover.)
	_cp(blue, 4)
	await _frames(10)
	b.dropper.reset_marker()
	await _frames(2)
	var x0 := blue.global_position.x
	var msg := b.try_drop()
	var stunned := false
	for i in 80:
		await get_tree().physics_frame
		if blue.is_stunned():
			stunned = true
			break
	var vx := blue.velocity.x
	await _frames(20)
	var drift := absf(blue.global_position.x - x0)
	_check("BD-05a", msg == "" and stunned and absf(vx) < 0.01 and drift < 0.1 and blue.is_on_floor(), "a barrel on the Runner stuns with no knockback (stunned %s, vx %.2f, drift %.2f)" % [stunned, vx, drift])
	_check("BD-05b", b.stats["barrel_hits"] == 1 and b.try_drop() == "RELOADING", "the hit is counted and the dropper reloads (%.1f s)" % b.drop_cooldown)
	await _frames(int(PRConfig.STUN_TIME * 60) + 5)
	_check("BD-05c", not blue.is_stunned(), "stun wears off after %.1f s" % PRConfig.STUN_TIME)


# --- BD-06: traps -----------------------------------------------------------------------------------

func _fire_trap_on_blue(section: int, local_pos: Vector3) -> PRTrap:
	_reset_cooldowns()
	var b := race.buddies[1]
	_cp(gold, 2)
	_at(blue, local_pos, section)
	await _frames(5)
	var trap := course.get_trap(section)
	var msg := b.try_trap()
	if msg != "":
		print("    trap refused: ", msg)
	return trap


func _test_traps() -> void:
	# S2 crumbling stone: a Runner standing on it falls and respawns at CP2.
	var falls := blue.falls
	var crumble: PRTrap = await _fire_trap_on_blue(2, Vector3(-1.0, 14.45, 0))
	var warned := crumble.phase == PRTrap.Phase.WARNING
	await _frames(int((PRConfig.TRAP_WARNING + 0.1) * 60))
	var active := crumble.phase != PRTrap.Phase.IDLE and crumble.phase != PRTrap.Phase.WARNING
	for i in 150:
		await get_tree().physics_frame
		if blue.falls > falls:
			break
	_check("BD-06a", warned and active and blue.falls > falls, "crumbling stone warns, then drops the Runner (fell %s)" % (blue.falls > falls))
	# It must not come back inside a Runner: park the Runner where the stone was.
	await _frames(70)
	var inside := course.global_position + Vector3(-1.0, 13.8, 0)
	blue.place_at(inside, 2)
	var held := true
	for i in int(PRConfig.CRUMBLE_RETURN * 60) + 30:
		blue.global_position = inside
		blue.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if crumble.phase == PRTrap.Phase.IDLE:
			held = false
	_cp(blue, 2)
	for i in 60:
		await get_tree().physics_frame
		if crumble.phase == PRTrap.Phase.IDLE:
			break
	_check("BD-06b", held and crumble.phase == PRTrap.Phase.IDLE, "the stone waits while a Runner is inside, then returns")
	_check("BD-06c", race.buddies[1].try_trap() == "TRAP RELOADING", "trap cooldown applies (%.1f s)" % race.buddies[1].trap_cooldown)

	# S3 wind gust: a Runner standing on a rune step is pushed right.
	var rs := course.get_node("Devices/RuneSteps") as PRSwapSteps
	if rs.solid_set != 1:
		rs.press(0)
	await _frames(5)
	var gust: PRTrap = await _fire_trap_on_blue(3, Vector3(-0.75, 29.65, 0))
	var x0 := blue.global_position.x
	await _frames(int((PRConfig.TRAP_WARNING + 0.5) * 60))
	var pushed := blue.global_position.x - x0
	_check("BD-06d", gust != null and pushed > 0.5, "wind gust pushes a standing Runner sideways (%.2f)" % pushed)
	await _frames(120)

	# S4 wall spikes: a Runner against the wall is knocked away from it.
	var spot := Vector3(-6.4, 44.0, 0)
	var spikes: PRTrap = await _fire_trap_on_blue(4, spot)
	var knocked := false
	for i in int((PRConfig.TRAP_WARNING + 0.4) * 60):
		blue.global_position = course.global_position + spot
		if i < int(PRConfig.TRAP_WARNING * 60) - 2:
			blue.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if blue.velocity.x > 3.0:
			knocked = true
			break
	_check("BD-06e", spikes != null and knocked, "wall spikes knock the Runner away from the wall (vx %.1f)" % blue.velocity.x)
	await _frames(60)

	# S5 crumbling ledge and S6 gust exist and fire.
	var ledge: PRTrap = await _fire_trap_on_blue(5, Vector3(4.5, 52.05, 0))
	_check("BD-06f", ledge != null and ledge.phase == PRTrap.Phase.WARNING, "S5 crumbling ledge fires")
	await _frames(300)
	var g6: PRTrap = await _fire_trap_on_blue(6, Vector3(-4.0, 60.05, 0))
	_check("BD-06g", g6 != null and g6.phase == PRTrap.Phase.WARNING, "S6 wind gust fires")
	await _frames(150)


# --- BD-07: boost and spree ---------------------------------------------------------------------------

func _test_boost() -> void:
	_cp(blue, 4)
	_cp(gold, 2)
	await _frames(5)
	var l1g := _dev(race.courses[1], "L1") as PRLift
	var l1b := _dev(course, "L1") as PRLift
	var d1g := _dev(race.courses[1], "D1") as PRDrawbridge
	var ok := race.boost[1] and not race.boost[0] and race.spree[0] and not race.spree[1]
	ok = ok and is_equal_approx(l1g.current_speed(), PRConfig.LIFT_SPEED * PRConfig.BOOST_LIFT_MULT) and is_equal_approx(l1b.current_speed(), PRConfig.LIFT_SPEED)
	ok = ok and is_equal_approx(d1g._hold_time(), PRConfig.BRIDGE_HOLD_BOOSTED)
	ok = ok and gold.power.boosted and race.buddies[1].boosted and not blue.power.boosted
	_check("BD-07a", ok, "Gold (2 checkpoints behind) gets HELP BOOST: lift %.2f, bridge %.0f s, faster powers; Blue is on a spree" % [l1g.current_speed(), d1g._hold_time()])
	# Boosted bridge: no cooldown after it retracts.
	d1g.press(1)
	await _frames(int((PRConfig.BRIDGE_SLIDE * 2 + PRConfig.BRIDGE_HOLD_BOOSTED) * 60) + 10)
	_check("BD-07b", d1g.phase == PRDrawbridge.Phase.IN, "boosted drawbridge has no cooldown (phase %s)" % PRDrawbridge.Phase.keys()[d1g.phase])
	_cp(gold, 4)
	await _frames(5)
	_check("BD-07c", not race.boost[1] and not race.spree[0] and is_equal_approx(l1g.current_speed(), PRConfig.LIFT_SPEED) and not gold.power.boosted, "boost and spree end when the gap closes")
