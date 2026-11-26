extends Node
## Stress and leak check (ST-01 to ST-03): for a long stretch both Buddies drop
## barrels and power barrels of every major and spring traps, both Runners spam
## their powers and the pause menu opens and closes. Afterwards nothing may be
## left behind: no barrels, paint, bursts or clones, no orphan nodes, and the
## node count back where it started.
## Run:  godot --headless --fixed-fps 60 --path board res://Minigames/PlatformRace/race/tests/stress_test.tscn

const RACE_SCENE := preload("res://Minigames/PlatformRace/race/platform_race.tscn")
const SECONDS := 40

var failures := 0
var race: PRRaceManager


func _ready() -> void:
	race = RACE_SCENE.instantiate()
	race.allow_scene_change = false
	race.auto_ready = true
	add_child(race)
	for i in 400:
		await get_tree().physics_frame
		if race.state == PRRaceManager.State.RACING:
			break
	# Both Runners sit in hinderable sections; the clock never runs out.
	for team in 2:
		race.runners[team].place_at(race.courses[team].get_checkpoint(4).global_position, 4)
	# Open the pause menu once first: its buttons are built on first show and reused.
	await _toggle_pause()
	await _frames(30)
	var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var before := _paths(race)
	var barrels := 0
	var max_live := 0
	for i in SECONDS * 60:
		race.race_time = 0.0
		var frame := i % 120
		for team in 2:
			var b := race.buddies[team]
			b.stun_time = 0.0
			if frame == 10 + team * 7:
				b.major = (floori(i / 120.0) + team) % PRMajors.COUNT
				b.power_cooldown = 0.0
				b.arm_power()
			if frame % 20 == team * 3:
				b.drop_cooldown = 0.0
				b.dropper.marker_x = randf_range(-3.0, 0.5)
				if b.try_drop() == "":
					barrels += 1
			if frame == 60:
				b.trap_cooldown = 0.0
				b.try_trap()
			var r := race.runners[team]
			if frame == 30 + team * 11:
				r.power.setup(r, (floori(i / 120.0) + 3 + team) % PRMajors.COUNT)
				r.power.enemy_buddy = race.buddies[1 - team]
				r.power.activate()
				r.power.activate() # History: the second press jumps back
			if r.checkpoint_index < 4 or r.global_position.y < race.courses[team].get_checkpoint(4).global_position.y - 2.0:
				r.place_at(race.courses[team].get_checkpoint(4).global_position, 4)
		if i % 600 == 300:
			await _toggle_pause()
		max_live = maxi(max_live, get_tree().get_nodes_in_group(&"pr_barrels").size())
		await get_tree().physics_frame
	# Let every effect run out (paint lasts longest), then count.
	await _frames(int(PRMajors.PAINT_TIME * 60) + 120)
	var left := get_tree().get_nodes_in_group(&"pr_barrels").size()
	var leftovers := 0
	for team in 2:
		for c in race.courses[team].get_children():
			if c is PRBarrel or c is PRPaintZone or c is PRBurst:
				leftovers += 1
	_check("ST-01", barrels > 100 and left == 0 and leftovers == 0 and max_live < 30,
		"%d barrels dropped (at most %d in the air at once): none left behind, no paint or effects left" % [barrels, max_live])
	var nodes1 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	if OS.get_environment("STRESS_TRACE") != "":
		var after := _paths(race)
		for p in after:
			if not before.has(p):
				print("    new node: ", p)
		for p in before:
			if not after.has(p):
				print("    gone node: ", p)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check("ST-02", orphans == 0 and absf(nodes1 - nodes0) <= 2, "node count %d → %d after %d s of chaos, orphan nodes %d" % [nodes0, nodes1, SECONDS, orphans])
	_check("ST-03", race.state == PRRaceManager.State.RACING and not get_tree().paused, "the race is still running normally (state %s)" % PRRaceManager.State.keys()[race.state])
	print("RESULT: %s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	race.queue_free()
	await _frames(3)
	OS.delay_msec(150)
	await _frames(2)
	get_tree().quit(0 if failures == 0 else 1)


## Opens the pause menu and closes it again.
func _toggle_pause() -> void:
	for n in 2:
		Input.action_press(&"pr2_pause")
		await get_tree().physics_frame
		Input.action_release(&"pr2_pause")
		await _frames(10)


## Every node path under `root`, internal children included.
func _paths(root: Node) -> Dictionary:
	var out := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out[str(root.get_path_to(n)) + ":" + n.get_class()] = true
		stack.append_array(n.get_children(true))
	return out


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(id: String, ok: bool, detail: String) -> void:
	print("%s %s  %s" % ["PASS" if ok else "FAIL", id, detail])
	if not ok:
		failures += 1
