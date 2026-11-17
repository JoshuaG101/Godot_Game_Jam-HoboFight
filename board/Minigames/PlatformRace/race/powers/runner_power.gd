class_name PRRunnerPower
extends Node3D
## A Runner's major power. Press Power to use it; it then recharges.
##
##   ART          Paint Shield   blocks the next barrel (lasts SHIELD_TIME)
##   ANTHROPOLOGY Read the Room  the enemy Buddy's next barrel within HEX_TIME
##                               backfires and stuns them instead
##   MUSIC        Tempo          run TEMPO_SPEED× faster for TEMPO_TIME
##   HISTORY      Bookmark       first press leaves a clone, a second press within
##                               CLONE_TIME jumps you back to it
##   RELIGION     Leap of Faith  for FAITH_WINDOW a barrel passes through you;
##                               timed right, it recharges almost at once
##   COMPUTER_SCIENCE Hack       freezes every barrel over your tower for
##                               FREEZE_TIME (or the next one, within HACK_ARM_TIME)
##
## Lives under the Runner, so its visuals (shield, halo, notes) follow them.

## A short line for the HUD ("SHIELD UP", "BLESSED!").
signal announced(team: int, text: String)

var runner: PRRunner
var major := 0
## The enemy Buddy (Anthropology curses them). Set by the race manager.
var enemy_buddy: PRBuddy
var cooldown := 0.0
## HELP BOOST: recharges faster (set by the race manager).
var boosted := false
## How many times the power was used (results screen).
var uses := 0

var shield_time := 0.0
var tempo_time := 0.0
var faith_time := 0.0
var hack_armed_time := 0.0
var clone_time := 0.0

var _clone: Node3D
var _shield_fx: MeshInstance3D
var _halo_fx: MeshInstance3D
var _notes_fx: Label3D
var _time := 0.0


func setup(p_runner: PRRunner, p_major: int) -> void:
	runner = p_runner
	major = p_major
	cooldown = 0.0
	_clear_effects()
	if _shield_fx == null:
		_build_fx()


## True when pressing Power would do something.
func can_use() -> bool:
	return cooldown <= 0.0 or (major == PRMajors.Major.HISTORY and _clone != null)


## Uses the power. Returns the HUD line, or "" if it isn't ready.
func activate() -> String:
	if not can_use():
		return ""
	var text := ""
	match major:
		PRMajors.Major.ART:
			shield_time = PRMajors.SHIELD_TIME
			text = "PAINT SHIELD"
		PRMajors.Major.ANTHROPOLOGY:
			if enemy_buddy:
				enemy_buddy.hex(PRMajors.HEX_TIME)
			text = "READ THE ROOM"
		PRMajors.Major.MUSIC:
			tempo_time = PRMajors.TEMPO_TIME
			text = "TEMPO!"
		PRMajors.Major.HISTORY:
			if _clone == null:
				_place_clone()
				uses += 1
				return _announce("BOOKMARKED")
			runner.return_to(_clone.global_position)
			_remove_clone()
			text = "BACK IN TIME"
		PRMajors.Major.RELIGION:
			faith_time = PRMajors.FAITH_WINDOW
			text = ""
		PRMajors.Major.COMPUTER_SCIENCE:
			if _freeze_barrels() == 0:
				hack_armed_time = PRMajors.HACK_ARM_TIME
				text = "HACK READY"
			else:
				text = "HACKED!"
	cooldown = PRMajors.runner_cooldown(major)
	uses += 1
	PRSfx.emit(self, "boost", -3.0, 0.05)
	return _announce(text)


## Asked by a barrel touching the Runner. "faith": let it pass through,
## "shield": it breaks harmlessly, "": it hits.
func defend() -> String:
	if faith_time > 0.0:
		# Perfect timing: the window closes and the power is nearly ready again.
		faith_time = 0.0
		cooldown = minf(cooldown, PRMajors.FAITH_SUCCESS_COOLDOWN)
		_announce("BLESSED!")
		return "faith"
	if shield_time > 0.0:
		shield_time = 0.0
		_announce("BLOCKED!")
		return "shield"
	return ""


## The next barrel dropped on this tower is frozen (an armed Hack).
func consume_hack() -> bool:
	if hack_armed_time <= 0.0:
		return false
	hack_armed_time = 0.0
	_announce("HACKED!")
	return true


func speed_multiplier() -> float:
	return PRMajors.TEMPO_SPEED if tempo_time > 0.0 else 1.0


## 0..1: how charged the power is (1 = ready).
func ratio() -> float:
	return 1.0 - clampf(cooldown / PRMajors.runner_cooldown(major), 0.0, 1.0)


## True while an effect of the power is running (shield up, clone placed...).
func is_active() -> bool:
	return shield_time > 0.0 or tempo_time > 0.0 or faith_time > 0.0 or hack_armed_time > 0.0 or _clone != null


func _physics_process(delta: float) -> void:
	_time += delta
	var recharge := PRConfig.BOOST_POWER_RECHARGE if boosted else 1.0
	# A placed clone pauses the recharge until it is used or expires.
	if _clone == null:
		cooldown = maxf(cooldown - delta * recharge, 0.0)
	shield_time = maxf(shield_time - delta, 0.0)
	tempo_time = maxf(tempo_time - delta, 0.0)
	faith_time = maxf(faith_time - delta, 0.0)
	hack_armed_time = maxf(hack_armed_time - delta, 0.0)
	if _clone:
		clone_time -= delta
		_clone.visible = clone_time > 1.0 or fmod(clone_time, 0.2) < 0.12
		if clone_time <= 0.0:
			_remove_clone()
			cooldown = PRMajors.runner_cooldown(major)
	_shield_fx.visible = shield_time > 0.0
	_halo_fx.visible = faith_time > 0.0
	_notes_fx.visible = tempo_time > 0.0
	if _notes_fx.visible:
		_notes_fx.position.y = 2.5 + 0.15 * sin(_time * 10.0)
	if _halo_fx.visible:
		_halo_fx.rotation.y += delta * 6.0


func _announce(text: String) -> String:
	if text != "" and runner:
		announced.emit(runner.team, text)
	return text


func _clear_effects() -> void:
	shield_time = 0.0
	tempo_time = 0.0
	faith_time = 0.0
	hack_armed_time = 0.0
	_remove_clone()


func _freeze_barrels() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"pr_barrels"):
		var b := node as PRBarrel
		if b and b.victim_team() == runner.team:
			b.freeze(PRMajors.FREEZE_TIME)
			count += 1
	return count


# --- History clone -------------------------------------------------------------------

func _place_clone() -> void:
	_clone = Node3D.new()
	_clone.top_level = true
	add_child(_clone)
	_clone.global_position = runner.global_position
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	body.mesh = capsule
	body.position = Vector3(0, 0.95, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(PRConfig.team_color(runner.team), 0.35)
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clone.add_child(body)
	var icon := _label("⧗", PRTheme.WHITE, 2.3)
	_clone.add_child(icon)
	clone_time = PRMajors.CLONE_TIME


func _remove_clone() -> void:
	if _clone:
		_clone.queue_free()
		_clone = null
		clone_time = 0.0


# --- Visuals -------------------------------------------------------------------------

func _build_fx() -> void:
	# Paint shield: a bright painted disc over the head.
	_shield_fx = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.08
	_shield_fx.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.albedo_color = PRConfig.team_color(runner.team)
	sm.emission_enabled = true
	sm.emission = PRConfig.team_color(runner.team)
	sm.emission_energy_multiplier = 0.6
	_shield_fx.material_override = sm
	_shield_fx.position = Vector3(0, 2.25, 0)
	_shield_fx.rotation_degrees.x = 20.0
	_shield_fx.visible = false
	add_child(_shield_fx)
	# Leap of Faith: a gold halo.
	_halo_fx = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.48
	_halo_fx.mesh = torus
	_halo_fx.material_override = PRTrap.glow_material(PRTheme.GOLD, 2.0)
	_halo_fx.position = Vector3(0, 2.3, 0)
	_halo_fx.visible = false
	add_child(_halo_fx)
	# Tempo: bouncing music notes.
	_notes_fx = _label("♫  ♪", PRTheme.GOLD, 2.5)
	_notes_fx.visible = false
	add_child(_notes_fx)


static func _label(text: String, color: Color, y: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = PRTheme.display_font()
	l.font_size = 64
	l.pixel_size = 0.007
	l.outline_size = 12
	l.outline_modulate = PRTheme.INK
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0, y, 0)
	return l
