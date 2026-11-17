class_name PRBuddy
extends Node
## One Buddy: the Runner's teammate who never runs. Two modes:
##
##   HELP    works the machines in your own Runner's section. Left / Right pick
##           which machine (it glows in your team colour); Action works it
##           (hold for Lifts, press for Rune Steps and Drawbridges).
##   HINDER  Left / Right slide a drop marker over the enemy view, Action drops a
##           barrel (stuns 1 s), Trap springs the trap in the enemy Runner's
##           section. Nothing can be hindered while the enemy is in section 1.
##
## The mode follows your Runner's stage (HELP or HINDER stage), but whenever both
## are possible the Buddy decides: Switch toggles between helping your Runner and
## hindering the enemy. Power arms your major's special barrel for the next drop.
##
## The HUD reads this node's public state; it draws nothing itself except
## through the dropper's 3D marker and the machines' glow.

signal mode_changed(team: int, mode: int)
## what: "barrel" (dropped), "barrel_hit", "trap", "backfire", "armed"
signal hinder_used(team: int, what: String)

var team := 0
## Only true while the race is running.
var active := false
var mode := PRConfig.Mode.HELP
var major := 0
var own_course: PRCourse
var enemy_course: PRCourse
var runner: PRRunner
var enemy_runner: PRRunner
var dropper: PRDropper
## Used for on-screen key names (set by the race manager).
var input: PRInput
var help_target: PRDevice = null
var drop_cooldown := 0.0
var trap_cooldown := 0.0
var power_cooldown := 0.0
## True while the next barrel is this Buddy's special barrel.
var power_armed := false
## HELP BOOST: power recharges faster (set by the race manager).
var boosted := false
## Seconds left of a backfire stun (enemy Anthropology Runner). No actions.
var stun_time := 0.0
## Seconds left on a curse: the next barrel dropped in this time backfires.
var hex_time := 0.0
## A short message on the Buddy's card ("SAFE ZONE", "RELOADING").
var flash := ""
var flash_time := 0.0
var stats := {"barrels": 0, "barrel_hits": 0, "traps": 0, "specials": 0, "backfires": 0}

var _section := -1
## The Buddy picked the current machine by hand; until then the pick follows
## whichever machine is nearest the Runner.
var _picked_by_hand := false


func setup(p_team: int, own: PRCourse, enemy: PRCourse, own_runner: PRRunner, p_enemy_runner: PRRunner, enemy_camera: PRRaceCamera, p_major := 0) -> void:
	team = p_team
	own_course = own
	enemy_course = enemy
	runner = own_runner
	enemy_runner = p_enemy_runner
	major = p_major
	# Run before machines so a held Action moves a Lift in the same physics frame.
	process_physics_priority = -10
	if dropper == null:
		dropper = PRDropper.new()
		dropper.name = "Dropper"
		add_child(dropper)
	dropper.setup(self, team, enemy, p_enemy_runner, enemy_camera)
	_section = -1
	_update_mode()


func _physics_process(delta: float) -> void:
	if own_course == null:
		return
	drop_cooldown = maxf(drop_cooldown - delta, 0.0)
	trap_cooldown = maxf(trap_cooldown - delta, 0.0)
	var recharge := PRConfig.BOOST_POWER_RECHARGE if boosted else 1.0
	power_cooldown = maxf(power_cooldown - delta * recharge, 0.0)
	flash_time = maxf(flash_time - delta, 0.0)
	stun_time = maxf(stun_time - delta, 0.0)
	hex_time = maxf(hex_time - delta, 0.0)
	_update_mode()
	var can_act := active and stun_time <= 0.0
	if can_act and _just("mode"):
		toggle_mode()
	if can_act and _just("power"):
		arm_power()
	if mode == PRConfig.Mode.HELP:
		_help(can_act)
	else:
		_set_help_target(null)
		_hinder(delta, can_act)
	dropper.shown = active and mode == PRConfig.Mode.HINDER and not is_safe_zone()


# --- Mode ----------------------------------------------------------------------------

## True when the own Runner's section has a machine to work.
func can_help() -> bool:
	return runner != null and not runner.has_finished and not help_choices().is_empty()


## True when the enemy Runner can be hindered (not in section 1, not finished).
func can_hinder() -> bool:
	return not is_safe_zone()


## Both modes are possible, so the Buddy gets to choose.
func can_switch() -> bool:
	return can_help() and can_hinder()


func is_safe_zone() -> bool:
	return enemy_runner == null or enemy_runner.checkpoint_index <= 1 or enemy_runner.has_finished


## Toggles HELP ⇄ HINDER. Returns "" on success or the reason it can't.
func toggle_mode() -> String:
	var other := _other(mode)
	if not _possible(other):
		var why := "NOTHING TO WORK HERE" if other == PRConfig.Mode.HELP else "ENEMY IS SAFE"
		show_flash(why)
		return why
	_set_mode(other)
	return ""


func _update_mode() -> void:
	if runner == null:
		return
	var section := runner.checkpoint_index
	if section != _section:
		# New section: start in the mode that fits the stage, if it's possible.
		_section = section
		_picked_by_hand = false
		var stage := PRConfig.stage_for_checkpoint(section)
		if _possible(stage) or not _possible(_other(stage)):
			_set_mode(stage)
		else:
			_set_mode(_other(stage))
	elif not _possible(mode) and _possible(_other(mode)):
		_set_mode(_other(mode))


func _possible(m: int) -> bool:
	return can_help() if m == PRConfig.Mode.HELP else can_hinder()


static func _other(m: int) -> PRConfig.Mode:
	return PRConfig.Mode.HINDER if m == PRConfig.Mode.HELP else PRConfig.Mode.HELP


func _set_mode(m: PRConfig.Mode) -> void:
	if m == mode:
		return
	mode = m
	if mode == PRConfig.Mode.HINDER and dropper:
		dropper.reset_marker()
	mode_changed.emit(team, mode)


# --- HELP ------------------------------------------------------------------------------

## The machines the Buddy can work right now: the own Runner's section, left to right.
func help_choices() -> Array[PRDevice]:
	var out: Array[PRDevice] = []
	if own_course == null or runner == null:
		return out
	for d in own_course.get_devices():
		if d.targetable and d.route_index == runner.checkpoint_index:
			out.append(d)
	out.sort_custom(func(a: PRDevice, b: PRDevice) -> bool: return a.get_target_point().x < b.get_target_point().x)
	return out


## The machine nearest the Runner (Lifts measure to their whole track, so a Lift
## parked at the far end still counts as close to a Runner waiting for it).
func nearest_choice() -> PRDevice:
	var best: PRDevice = null
	var best_d := INF
	var from := runner.global_position + Vector3(0, 1, 0)
	for d in help_choices():
		var dist := d.distance_hint(from)
		if dist < best_d:
			best_d = dist
			best = d
	return best


## Left / Right: pick the previous / next machine. Returns the new pick.
func pick_machine(step: int) -> PRDevice:
	var choices := help_choices()
	if choices.is_empty():
		return null
	var i := choices.find(help_target)
	i = clampi(i + step, 0, choices.size() - 1) if i >= 0 else 0
	_picked_by_hand = true
	_set_help_target(choices[i])
	PRSfx.emit(self, "click", -8.0)
	return help_target


func _help(can_act: bool) -> void:
	if not active:
		# Before the race (and after it) nothing is picked, so no machine glows.
		_set_help_target(null)
		return
	var choices := help_choices()
	if help_target == null or not choices.has(help_target) or not _picked_by_hand:
		_set_help_target(nearest_choice())
	if not can_act or help_target == null:
		return
	if _just("left"):
		pick_machine(-1)
	elif _just("right"):
		pick_machine(1)
	if _just("action"):
		var msg := help_target.press(team)
		if msg != "":
			show_flash(msg)
	if Input.is_action_pressed(PRInput.buddy_action(team, "action")):
		help_target.hold(team)


func _set_help_target(d: PRDevice) -> void:
	if d == help_target:
		return
	if is_instance_valid(help_target):
		help_target.set_worked(false)
	help_target = d
	if help_target:
		help_target.set_worked(true, key_name("action"), help_choices().size() > 1)


## The key or button this Buddy presses for `action` ("action", "trap"...).
func key_name(action: String) -> String:
	if input == null:
		return ""
	return input.key_name(PRRoster.slot_for(team, PRConfig.ROLE_BUDDY), action)


# --- HINDER -----------------------------------------------------------------------------

func _hinder(delta: float, can_act: bool) -> void:
	if not can_act:
		return
	var axis := Input.get_axis(PRInput.buddy_action(team, "left"), PRInput.buddy_action(team, "right"))
	dropper.move_marker(axis * PRConfig.DROP_MARKER_SPEED * delta)
	if _just("action"):
		try_drop()
	if _just("trap"):
		try_trap()


## Returns "" on success, or the rejection shown to the player.
func try_drop() -> String:
	var msg := ""
	if stun_time > 0.0:
		msg = "STUNNED"
	elif is_safe_zone():
		msg = "SAFE ZONE"
	elif drop_cooldown > 0.0:
		msg = "RELOADING"
	if msg != "":
		show_flash(msg)
		return msg
	drop_cooldown = PRConfig.DROP_COOLDOWN
	if hex_time > 0.0:
		_backfire()
		return "BACKFIRE"
	var special := major if power_armed else -1
	dropper.drop(special)
	stats["barrels"] += 1
	if power_armed:
		power_armed = false
		power_cooldown = PRMajors.buddy_cooldown(major)
		stats["specials"] += 1
	hinder_used.emit(team, "barrel")
	return ""


func try_trap() -> String:
	var msg := ""
	var trap := current_enemy_trap()
	if stun_time > 0.0:
		msg = "STUNNED"
	elif is_safe_zone():
		msg = "SAFE ZONE"
	elif trap == null:
		msg = "NO TRAP HERE"
	elif trap_cooldown > 0.0:
		msg = "TRAP RELOADING"
	elif trap.is_busy():
		msg = "TRAP BUSY"
	if msg != "":
		show_flash(msg)
		return msg
	trap.fire(team)
	trap_cooldown = PRConfig.TRAP_COOLDOWN
	stats["traps"] += 1
	hinder_used.emit(team, "trap")
	return ""


func current_enemy_trap() -> PRTrap:
	if enemy_course == null or enemy_runner == null:
		return null
	return enemy_course.get_trap(enemy_runner.checkpoint_index)


func on_barrel_hit() -> void:
	stats["barrel_hits"] += 1
	hinder_used.emit(team, "barrel_hit")


# --- Power ------------------------------------------------------------------------------

## Arms the special barrel. Returns "" on success or the reason it can't.
func arm_power() -> String:
	var msg := ""
	if power_armed:
		msg = "ALREADY ARMED"
	elif power_cooldown > 0.0:
		msg = "POWER %.0fs" % ceilf(power_cooldown)
	if msg != "":
		show_flash(msg)
		return msg
	power_armed = true
	PRSfx.emit(self, "boost", -4.0)
	hinder_used.emit(team, "armed")
	return ""


## 0..1: how charged the power is (1 = ready or armed).
func power_ratio() -> float:
	if power_armed:
		return 1.0
	return 1.0 - clampf(power_cooldown / PRMajors.buddy_cooldown(major), 0.0, 1.0)


## Called by the enemy Anthropology Runner's power.
func hex(seconds: float) -> void:
	hex_time = seconds


func _backfire() -> void:
	hex_time = 0.0
	stun_time = PRMajors.HEX_BUDDY_STUN
	stats["backfires"] += 1
	show_flash("BACKFIRE!")
	PRSfx.emit(self, "stun", -2.0, 0.05)
	hinder_used.emit(team, "backfire")


# --- Shared ----------------------------------------------------------------------------

func show_flash(text: String, seconds := 1.3) -> void:
	flash = text
	flash_time = seconds
	PRSfx.emit(self, "click", -6.0)


func _just(action: String) -> bool:
	return Input.is_action_just_pressed(PRInput.buddy_action(team, action))
