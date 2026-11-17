extends Node
## Headless checks for every major power (PW-01 to PW-12): the six Runner powers
## and the six Buddy power barrels, plus cooldowns.
## Run:  godot --headless --fixed-fps 60 --path board res://Minigames/PlatformRace/race/tests/powers_test.tscn

const RACE_SCENE := preload("res://Minigames/PlatformRace/race/platform_race.tscn")
const M := PRMajors.Major

var failures := 0
var race: PRRaceManager
var blue: PRRunner
var gold: PRRunner
var course: PRCourse
## Gold's Buddy: it hinders Blue in every test.
var enemy: PRBuddy


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
	enemy = race.buddies[1]
	race.buddies[0].active = false
	await _test_art_runner()
	await _test_anthropology_runner()
	await _test_music_runner()
	await _test_history_runner()
	await _test_religion_runner()
	await _test_cs_runner()
	await _test_art_buddy()
	await _test_anthropology_buddy()
	await _test_music_buddy()
	await _test_history_buddy()
	await _test_religion_buddy()
	await _test_cs_buddy()
	print("RESULT: %s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	race.queue_free()
	await _frames(3)
	OS.delay_msec(150)
	await _frames(2)
	get_tree().quit(0 if failures == 0 else 1)


# --- Helpers ----------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(id: String, ok: bool, detail: String) -> void:
	print("%s %s  %s" % ["PASS" if ok else "FAIL", id, detail])
	if not ok:
		failures += 1


## Puts Blue on the open chimney base (barrels reach it) with a fresh power.
func _setup_blue(runner_major: int) -> void:
	blue.power.setup(blue, runner_major)
	blue.power.enemy_buddy = enemy
	blue.place_at(course.get_checkpoint(4).global_position, 4)
	gold.place_at(race.courses[1].get_checkpoint(2).global_position, 2)
	enemy.stun_time = 0.0
	enemy.hex_time = 0.0
	enemy.drop_cooldown = 0.0
	enemy.power_cooldown = 0.0
	enemy.power_armed = false
	await _frames(20)
	race.cameras[0].snap()
	await _frames(2)


## Drops a Gold barrel `offset` units beside Blue. With `special` the Buddy's
## power is armed first. Returns the barrel.
func _drop(offset := 0.0, special := -1) -> PRBarrel:
	enemy.drop_cooldown = 0.0
	if special >= 0:
		enemy.major = special
		enemy.power_cooldown = 0.0
		enemy.arm_power()
	enemy.dropper.marker_x = blue.global_position.x - course.global_position.x + offset
	await _frames(2)
	var before := get_tree().get_nodes_in_group(&"pr_barrels").size()
	enemy.try_drop()
	var barrels := get_tree().get_nodes_in_group(&"pr_barrels")
	return barrels[barrels.size() - 1] as PRBarrel if barrels.size() > before else null


## Waits until the Runner is stunned or the frames run out.
func _wait_stun(frames := 90) -> bool:
	for i in frames:
		await get_tree().physics_frame
		if blue.is_stunned():
			return true
	return false


func _clear_status() -> void:
	await _frames(int(PRMajors.DANCE_STUN * 60) + 10)
	blue.invert_time = 0.0


# --- Runner powers ----------------------------------------------------------------------------------

func _test_art_runner() -> void:
	await _setup_blue(M.ART)
	blue.power.activate()
	var up := blue.power.shield_time > 0.0
	var stuns := blue.stuns
	await _drop()
	var stunned := await _wait_stun()
	_check("PW-01", up and not stunned and blue.stuns == stuns and blue.power.shield_time <= 0.0, "Paint Shield blocks a barrel and is used up (stunned %s)" % stunned)
	await _clear_status()


func _test_anthropology_runner() -> void:
	await _setup_blue(M.ANTHROPOLOGY)
	blue.power.activate()
	var hexed := enemy.hex_time > 0.0
	var before := get_tree().get_nodes_in_group(&"pr_barrels").size()
	var msg := enemy.try_drop()
	var after := get_tree().get_nodes_in_group(&"pr_barrels").size()
	_check("PW-02", hexed and msg == "BACKFIRE" and enemy.stun_time > 0.0 and after == before and enemy.try_drop() == "STUNNED",
		"Read the Room: the enemy Buddy's next barrel backfires and stuns them (%s, stun %.1f s)" % [msg, enemy.stun_time])
	enemy.stun_time = 0.0


func _test_music_runner() -> void:
	await _setup_blue(M.MUSIC)
	# Run on the long S1 floor.
	blue.place_at(course.global_position + Vector3(-6.0, 0.05, 0), 1)
	await _frames(10)
	blue.power.activate()
	Input.action_press(PRInput.runner_action(0, "right"))
	var top := 0.0
	for i in 40:
		await get_tree().physics_frame
		top = maxf(top, blue.velocity.x)
	Input.action_release(PRInput.runner_action(0, "right"))
	_check("PW-03", top > blue.max_speed * 1.3, "Tempo raises run speed to %.1f (normal %.1f)" % [top, blue.max_speed])
	await _frames(int(PRMajors.TEMPO_TIME * 60))


func _test_history_runner() -> void:
	await _setup_blue(M.HISTORY)
	var a := blue.global_position
	blue.power.activate()
	blue.place_at(course.global_position + Vector3(-3.0, 35.05, 0), 4) # the sill, outside the CP4 trigger
	await _frames(5)
	blue.power.activate()
	await _frames(3)
	var back := blue.global_position.distance_to(a)
	_check("PW-04", back < 0.3 and blue.checkpoint_index == 4 and blue.power.cooldown > 0.0, "Bookmark jumps back to the clone (%.2f away) and then recharges" % back)


func _test_religion_runner() -> void:
	await _setup_blue(M.RELIGION)
	var stuns := blue.stuns
	var b := await _drop()
	# Pray just before the barrel arrives.
	var prayed := false
	for i in 90:
		await get_tree().physics_frame
		if not prayed and b and b._y - blue.global_position.y < 3.6:
			blue.power.activate()
			prayed = true
		if blue.is_stunned():
			break
	_check("PW-05", prayed and blue.stuns == stuns and blue.power.cooldown <= PRMajors.FAITH_SUCCESS_COOLDOWN + 0.01,
		"a timed Leap of Faith lets the barrel through and leaves only %.1f s of cooldown" % blue.power.cooldown)
	await _clear_status()


func _test_cs_runner() -> void:
	await _setup_blue(M.COMPUTER_SCIENCE)
	var b := await _drop()
	await _frames(6)
	blue.power.activate()
	var y0 := b._y
	await _frames(60)
	var held := absf(b._y - y0) < 0.01 and b.is_frozen()
	await _frames(int(PRMajors.FREEZE_TIME * 60) + 60)
	_check("PW-06a", held and not is_instance_valid(b) or held and b._done, "Hack freezes a falling barrel, which falls again afterwards")
	await _clear_status()
	# No barrel yet: the hack waits for the next one.
	await _setup_blue(M.COMPUTER_SCIENCE)
	blue.power.activate()
	var armed := blue.power.hack_armed_time > 0.0
	var nb := await _drop()
	_check("PW-06b", armed and nb != null and nb.is_frozen(), "an early Hack freezes the next barrel dropped")
	await _frames(int(PRMajors.FREEZE_TIME * 60) + 90)
	await _clear_status()


# --- Buddy power barrels ----------------------------------------------------------------------------

func _test_art_buddy() -> void:
	await _setup_blue(M.MUSIC)
	# Land it beside the Runner (inside the chimney) so it splashes the floor.
	await _drop(-1.4, M.ART)
	var zone: PRPaintZone = null
	for i in 90:
		await get_tree().physics_frame
		for c in course.get_children():
			if c is PRPaintZone:
				zone = c
		if zone:
			break
	var cooled := enemy.power_cooldown > 0.0 and not enemy.power_armed
	var painted := false
	if zone:
		blue.place_at(Vector3(zone.global_position.x, zone.global_position.y + 0.05, 0), 4)
		await _frames(5)
		painted = blue.is_painted()
	_check("PW-07", zone != null and painted and cooled, "Paint Bomb splashes paint that paints the Runner, and the power recharges (%.0f s)" % enemy.power_cooldown)
	await _frames(int(PRMajors.PAINT_TIME * 60) + 10)
	_check("PW-07b", not is_instance_valid(zone), "the paint dries up and frees itself")


func _test_anthropology_buddy() -> void:
	await _setup_blue(M.MUSIC)
	await _drop(0.0, M.ANTHROPOLOGY)
	var hit := await _wait_stun()
	_check("PW-08", hit and blue.invert_time > 0.0, "Culture Shock: the hit flips the Runner's controls (%.1f s)" % blue.invert_time)
	await _clear_status()


func _test_music_buddy() -> void:
	await _setup_blue(M.MUSIC)
	await _drop(0.0, M.MUSIC)
	var hit := await _wait_stun()
	_check("PW-09", hit and blue.is_dancing() and blue.stun_time > PRConfig.STUN_TIME, "Drop the Beat: a longer stun (%.1f s) and the Runner dances" % blue.stun_time)
	await _clear_status()


func _test_history_buddy() -> void:
	await _setup_blue(M.MUSIC)
	# Aimed 1.3 units off: a plain barrel would miss, a tracking one still hits.
	await _drop(-1.3, M.HISTORY)
	var hit := await _wait_stun()
	_check("PW-10", hit, "Study the Past: the barrel tracks the Runner and hits from 1.3 units off")
	await _clear_status()


func _test_religion_buddy() -> void:
	await _setup_blue(M.MUSIC)
	# Lands 1.4 units off: no direct hit, but the blessing reaches the Runner.
	await _drop(1.4, M.RELIGION)
	var hit := await _wait_stun()
	_check("PW-11", hit, "Blessing: the barrel's area stun reaches a Runner it didn't touch")
	await _clear_status()


func _test_cs_buddy() -> void:
	await _setup_blue(M.MUSIC)
	seed(4242) # the jumps are random; a fixed seed keeps the test repeatable
	var b := await _drop(0.0, M.COMPUTER_SCIENCE)
	var xs := {}
	for i in 40:
		await get_tree().physics_frame
		if not is_instance_valid(b) or b._done:
			break
		xs[snappedf(b.x, 0.01)] = true
	_check("PW-12", xs.size() >= 2, "Glitch: the barrel jumps sideways as it falls (%d positions)" % xs.size())
	await _clear_status()
