extends SceneTree
## Checks the real Rematch / Change sides path, which reloads the scene and
## carries the roster across (RM-01 to RM-03), and that reloading again and
## again doesn't leak objects or nodes (RM-04). A SceneTree script, because it
## has to survive the scene being reloaded.
## Run:  godot --headless --fixed-fps 60 --path board -s res://Minigames/PlatformRace/race/tests/rematch_test.gd

const SCENE := "res://Minigames/PlatformRace/race/platform_race.tscn"
const RELOADS := 6

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file(SCENE)
	await _frames(5)
	var race: PRRaceManager = current_scene
	_check("RM-01", race != null and race.state == PRRaceManager.State.SIDES, "a fresh start shows the side select")
	race.roster.majors.assign([5, 4, 3, 2])
	race.restart(true)
	await _frames(6)
	race = current_scene
	_check("RM-02", race != null and race.state == PRRaceManager.State.VERSUS and race.roster.majors == [5, 4, 3, 2] and race.runners[0].power.major == 5 and race.buddies[1].major == 2,
		"Rematch reloads straight to the VS screen with the same majors %s" % str(race.roster.majors if race else []))
	race.restart(false)
	await _frames(6)
	race = current_scene
	_check("RM-03", race != null and race.state == PRRaceManager.State.SIDES and race.roster.majors == [5, 4, 3, 2],
		"Change sides & majors goes back to the side select and remembers the majors")

	# Let everything settle, then reload many times: object and node counts must
	# come back to where they were.
	await _frames(30)
	var objects0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in RELOADS:
		(current_scene as PRRaceManager).restart(true)
		await _frames(40)
	(current_scene as PRRaceManager).restart(false)
	await _frames(30)
	var objects1 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes1 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check("RM-04", absf(objects1 - objects0) < 60 and nodes1 == nodes0 and orphans == 0,
		"%d reloads: objects %d → %d, nodes %d → %d, orphan nodes %d" % [RELOADS, objects0, objects1, nodes0, nodes1, orphans])
	print("RESULT: %s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	current_scene.queue_free()
	await _frames(3)
	OS.delay_msec(150)
	await _frames(2)
	quit(0 if failures == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(id: String, ok: bool, detail: String) -> void:
	print("%s %s  %s" % ["PASS" if ok else "FAIL", id, detail])
	if not ok:
		failures += 1
