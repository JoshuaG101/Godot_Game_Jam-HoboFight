class_name PRRunner
extends CharacterBody3D
## The platforming character. Moves along X in the X–Y plane (Z is locked).
## The alternating wall jump is ported from the prototype's LocalPlayer.gd.
## Power uses the Runner's major power (PRRunnerPower child). Enemy power barrels
## can flip the controls, paint the floor (slow, low jumps) or make them dance.

signal checkpoint_reached(team: int, index: int)
signal finished(team: int)
signal respawn_started(team: int)
signal respawned(team: int)
signal jumped(team: int)
signal stunned(team: int)

@export var team := 0
@export var model_scene: PackedScene

@export_group("Run")
@export var max_speed := 8.0
@export var ground_accel := 60.0
@export var ground_decel := 70.0
@export var air_accel := 40.0
@export var air_decel := 18.0

@export_group("Jump")
@export var jump_velocity := 12.0
@export var gravity_up := 26.0
@export var gravity_down := 40.0
@export var max_fall_speed := 22.0
## Releasing jump while rising multiplies upward speed by this (short hop).
@export var jump_cut_multiplier := 0.45
## The cut is never applied before this much time has passed (tap ≈ 1.2 high).
@export var min_jump_hold := 0.08
@export var coyote_time := 0.10
@export var jump_buffer := 0.12

@export_group("Wall jump")
@export var wall_jump_velocity_y := 11.0
@export var wall_jump_push := 7.5
## Blocks steering right after a wall jump (from the prototype).
@export var wall_jump_lock := 0.18
## Max fall speed while pushing into a wall. 0 turns wall sliding off.
@export var wall_slide_max_fall := 5.0
## How far to look sideways for a wall.
@export var wall_probe := 0.12
## Grace period after leaving a wall during which a wall jump still counts.
@export var wall_coyote := 0.08

@export_group("Respawn")
@export var respawn_delay := 1.0
## Falling this far below the current checkpoint triggers a respawn.
@export var fall_margin := 3.0
@export var manual_respawn_hold := 1.0

@export_group("Look")
@export var turn_speed := 14.0

var controls_enabled := false
var has_finished := false
var checkpoint_index := 0
var checkpoint_position := Vector3.ZERO
## Highest standing height reached, floored to whole units (timeout tiebreak).
var best_floor_y := 0
## Last spot the Runner stood on static ground.
var last_safe_position := Vector3.ZERO
## 0..1 progress of the manual-respawn hold, for the HUD.
var respawn_hold_ratio := 0.0
## Seconds of stun left (a barrel hit). No control while > 0.
var stun_time := 0.0
## Times this Runner respawned / was stunned (results screen).
var falls := 0
var stuns := 0
## The major power. Created in _ready, configured by setup().
var power: PRRunnerPower
## Seconds left with left and right swapped (Culture Shock barrel).
var invert_time := 0.0

var _coyote := 0.0
var _buffer := 0.0
var _lock := 0.0
var _jumping := false
var _jump_time := 0.0
var _jump_cut_done := false
var _last_wall_side := 0
var _wall_seen := 0
var _wall_timer := 0.0
var _respawn_timer := -1.0
var _respawn_hold := 0.0
var _safe_timer := 0.0
var _facing := 1.0
var _model: Node3D
var _anim: AnimationPlayer
var _anim_lock := 0.0
var _forced_anim: StringName = &""
## Wind from a gust trap: horizontal speed added this physics frame.
var _wind := 0.0
var _wind_frame := -10
## After a spike knock, wall jumps are refused for a moment.
var _no_wall_time := 0.0
var _stars: Label3D
var _flame: CPUParticles3D
## Physics frame of the last apply_paint() (paint only lasts while you stand in it).
var _paint_frame := -10
## Dancing while stunned by a Drop the Beat barrel.
var _dancing := false

@onready var _model_slot: Node3D = $ModelSlot
@onready var _ring: MeshInstance3D = $TeamRing
@onready var _tag: Label3D = $Tag


func _ready() -> void:
	axis_lock_linear_z = true
	collision_layer = PRConfig.LAYER_RUNNER
	collision_mask = PRConfig.RUNNER_MASK
	floor_snap_length = 0.3
	platform_on_leave = PLATFORM_ON_LEAVE_ADD_VELOCITY
	if model_scene and _model == null:
		set_model(model_scene)
	power = PRRunnerPower.new()
	power.name = "Power"
	add_child(power)
	power.setup(self, 0)
	_build_effects()
	_apply_team_look()


func setup(p_team: int, p_model: PackedScene, tag_text: String, major := 0) -> void:
	team = p_team
	if p_model:
		set_model(p_model)
	_tag.text = tag_text
	_tag.font = PRTheme.display_font()
	power.setup(self, major)
	_apply_team_look()


func set_model(scene: PackedScene) -> void:
	if _model:
		_model.queue_free()
	_model = scene.instantiate() as Node3D
	_model.rotation.y = 0.0
	_model.scale = Vector3(0.9, 0.9, 0.9)
	_model_slot.add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		var gs = get_node_or_null("/root/GameState") if is_inside_tree() else null
		if gs and gs.has_method("setup_character_idle_animation"):
			gs.setup_character_idle_animation(_anim)
		else:
			_setup_idle_animation(_anim)
	_model_slot.rotation.y = PI * 0.5 * _facing


func _setup_idle_animation(anim_player: AnimationPlayer) -> void:
	if not anim_player or not anim_player.has_animation("jump"):
		return
	if anim_player.has_animation("idle"):
		return
	var jump_anim = anim_player.get_animation("jump")
	if not jump_anim:
		return
	var idle_anim = Animation.new()
	idle_anim.length = 0.5
	idle_anim.loop_mode = Animation.LOOP_LINEAR
	for t in range(jump_anim.get_track_count()):
		var track_path = jump_anim.track_get_path(t)
		var track_type = jump_anim.track_get_type(t)
		if jump_anim.track_get_key_count(t) > 0:
			var idx = idle_anim.add_track(track_type)
			idle_anim.track_set_path(idx, track_path)
			var val = jump_anim.track_get_key_value(t, 0)
			idle_anim.track_insert_key(idx, 0.0, val)
	var lib = anim_player.get_animation_library("")
	if lib:
		lib.add_animation("idle", idle_anim)


## Puts the Runner at a checkpoint without any respawn delay (race start).
func place_at(pos: Vector3, index: int) -> void:
	checkpoint_index = index
	checkpoint_position = pos
	last_safe_position = pos
	best_floor_y = floori(pos.y)
	# Cancel any respawn still pending from before.
	_respawn_timer = -1.0
	if _model_slot:
		_model_slot.visible = true
	invert_time = 0.0
	_teleport(pos)


func reach_checkpoint(index: int, pos: Vector3) -> void:
	if has_finished or index <= checkpoint_index:
		return
	checkpoint_index = index
	checkpoint_position = pos
	checkpoint_reached.emit(team, index)


func finish() -> void:
	if has_finished:
		return
	has_finished = true
	controls_enabled = false
	finished.emit(team)


func is_respawning() -> bool:
	return _respawn_timer >= 0.0


func start_respawn() -> void:
	if is_respawning() or has_finished:
		return
	_respawn_timer = respawn_delay
	velocity = Vector3.ZERO
	stun_time = 0.0
	_model_slot.visible = false
	falls += 1
	respawn_started.emit(team)


## The tag over the head and the major power (after the major select).
func assign_major(major: int, tag_text: String) -> void:
	_tag.text = tag_text
	power.setup(self, major)


## Knocked flat by a barrel: no control for `seconds`, no knockback. With
## `dance` the Runner dances instead of lying dazed (Drop the Beat).
## Returns false if the Runner can't be stunned right now.
func stun(seconds: float, dance := false) -> bool:
	if is_respawning() or has_finished or stun_time > 0.0:
		return false
	stun_time = seconds
	velocity.x = 0.0
	if velocity.y > 0.0:
		velocity.y = 0.0
	_buffer = 0.0
	_jumping = false
	stuns += 1
	_dancing = dance
	var anim := &"Cheer" if dance else &"Hit_B"
	_forced_anim = anim
	_anim_lock = seconds
	_play(anim, 0.05)
	stunned.emit(team)
	return true


## Asked by a barrel touching the Runner: "faith" (it passes through),
## "shield" (it breaks harmlessly) or "" (it hits).
func defend_against_barrel() -> String:
	return power.defend() if power else ""


## Culture Shock: left and right swap for `seconds`.
func invert_controls(seconds: float) -> void:
	invert_time = maxf(invert_time, seconds)


## Called every physics frame by a paint puddle the Runner stands in.
func apply_paint() -> void:
	_paint_frame = Engine.get_physics_frames()


func is_painted() -> bool:
	return Engine.get_physics_frames() - _paint_frame <= 1


func is_dancing() -> bool:
	return _dancing and stun_time > 0.0


## Bookmark: jump back to a saved spot (keeps the current checkpoint).
func return_to(pos: Vector3) -> void:
	if is_respawning() or has_finished:
		return
	_teleport(pos)
	play_one_shot(&"Spawn_Air", 0.4)


func is_stunned() -> bool:
	return stun_time > 0.0


## Thrown by wall spikes: sets the velocity, blocks steering briefly and
## refuses wall jumps for a moment so the Runner really drops.
func knock(v: Vector3) -> void:
	if is_respawning() or has_finished:
		return
	velocity = Vector3(v.x, v.y, 0.0)
	_lock = 0.35
	_no_wall_time = 0.45
	_wall_timer = 0.0
	_wall_seen = 0
	_jumping = false
	play_one_shot(&"Hit_A", 0.35)


## Called every physics frame by a gust trap while the Runner is in its area.
func apply_wind(speed: float) -> void:
	_wind = speed
	_wind_frame = Engine.get_physics_frames()


## Flame trail while this Runner's team is on a spree.
func set_spree(on: bool) -> void:
	if _flame:
		_flame.emitting = on


func play_one_shot(anim: StringName, seconds: float) -> void:
	_forced_anim = anim
	_anim_lock = seconds
	_play(anim, 0.1)


## Plays an animation until told otherwise (results screen).
func hold_animation(anim: StringName) -> void:
	_forced_anim = anim
	_anim_lock = INF
	_play(anim, 0.15)


# --- Physics ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_no_wall_time = maxf(_no_wall_time - delta, 0.0)
	if is_respawning():
		_process_respawn(delta)
		return
	var was_stunned := stun_time > 0.0
	stun_time = maxf(stun_time - delta, 0.0)
	invert_time = maxf(invert_time - delta, 0.0)
	if _stars:
		_stars.visible = stun_time > 0.0 and not _dancing
		_stars.rotation.y += delta * 6.0
	if was_stunned and stun_time <= 0.0:
		_anim_lock = 0.0
		_dancing = false

	var on_floor := is_on_floor()
	var can_act := controls_enabled and stun_time <= 0.0
	var axis := _read_axis() if stun_time <= 0.0 else 0.0
	var jump_pressed := can_act and Input.is_action_just_pressed(PRInput.runner_action(team, "jump"))
	var jump_held := can_act and Input.is_action_pressed(PRInput.runner_action(team, "jump"))
	if can_act and Input.is_action_just_pressed(PRInput.runner_action(team, "power")):
		power.activate()
	var painted := is_painted()
	var speed := max_speed * power.speed_multiplier() * (PRMajors.PAINT_SPEED if painted else 1.0)

	if on_floor:
		_coyote = coyote_time
		_last_wall_side = 0
		if velocity.y <= 0.0:
			_jumping = false
	else:
		_coyote -= delta

	_buffer = jump_buffer if jump_pressed else _buffer - delta

	# Wall contact (only matters in the air).
	var wall := 0
	if not on_floor and _no_wall_time <= 0.0:
		wall = _probe_wall()
		if wall != 0:
			_wall_seen = wall
			_wall_timer = wall_coyote
		else:
			_wall_timer -= delta

	# Gravity: lighter while rising, heavier while falling.
	if not on_floor:
		velocity.y -= (gravity_up if velocity.y > 0.0 else gravity_down) * delta
		var pushing_into_wall := wall != 0 and absf(axis) > 0.1 and signf(axis) == -float(wall)
		if wall_slide_max_fall > 0.0 and pushing_into_wall and velocity.y < -wall_slide_max_fall:
			velocity.y = -wall_slide_max_fall
		velocity.y = maxf(velocity.y, -max_fall_speed)

	# Jumps (buffered), coyote time, then alternating wall jumps.
	if _buffer > 0.0:
		if on_floor or _coyote > 0.0:
			_do_jump()
		elif _wall_timer > 0.0 and _wall_seen != 0 and _wall_seen != _last_wall_side:
			_do_wall_jump(_wall_seen)

	# Variable jump height.
	if _jumping:
		_jump_time += delta
		if not _jump_cut_done and not jump_held and _jump_time >= min_jump_hold and velocity.y > 0.0:
			velocity.y *= jump_cut_multiplier
			_jump_cut_done = true

	# Horizontal movement. A gust shifts the target speed: running into it is
	# slow, standing still lets it carry you.
	var wind := _wind if Engine.get_physics_frames() - _wind_frame <= 1 else 0.0
	if _lock > 0.0:
		_lock -= delta
	else:
		var target := axis * speed + wind
		var rate: float
		var steering := absf(axis) > 0.01 or absf(wind) > 0.01
		if on_floor:
			rate = ground_accel if steering else ground_decel
		else:
			rate = air_accel if steering else air_decel
		if steering and signf(target) != signf(velocity.x) and absf(velocity.x) > 0.1:
			rate = maxf(rate, ground_decel if on_floor else air_accel)
		velocity.x = move_toward(velocity.x, target, rate * delta)
	velocity.z = 0.0

	move_and_slide()

	if is_on_floor():
		var standing_y := floori(global_position.y + 0.05)
		best_floor_y = maxi(best_floor_y, standing_y)
		_safe_timer -= delta
		if _safe_timer <= 0.0 and _standing_on_static():
			last_safe_position = global_position
			_safe_timer = 0.25

	_check_respawn_rules(delta)
	_update_look(delta, axis)


func _read_axis() -> float:
	if not controls_enabled:
		return 0.0
	var axis := Input.get_axis(PRInput.runner_action(team, "left"), PRInput.runner_action(team, "right"))
	return -axis if invert_time > 0.0 else axis


func _do_jump() -> void:
	# A rising lift's speed is added on top by platform_on_leave = ADD_VELOCITY.
	velocity.y = jump_velocity * (PRMajors.PAINT_JUMP if is_painted() else 1.0)
	_buffer = 0.0
	_coyote = 0.0
	_jumping = true
	_jump_time = 0.0
	_jump_cut_done = false
	_play(&"Jump_Start", 0.05)
	_anim_lock = 0.2
	_forced_anim = &"Jump_Start"
	jumped.emit(team)


func _do_wall_jump(wall_side: int) -> void:
	velocity.y = wall_jump_velocity_y
	velocity.x = float(wall_side) * wall_jump_push
	_last_wall_side = wall_side
	_lock = wall_jump_lock
	_buffer = 0.0
	_wall_timer = 0.0
	_jumping = true
	_jump_time = 0.0
	_jump_cut_done = true # wall jumps always get full height, so climbing is consistent
	_facing = float(wall_side)
	_play(&"Jump_Start", 0.05)
	_anim_lock = 0.2
	_forced_anim = &"Jump_Start"
	jumped.emit(team)


## Returns +1 if there is a jumpable wall on the left (its normal points +X),
## -1 if there is one on the right, 0 if none.
func _probe_wall() -> int:
	for dir in [-1.0, 1.0]:
		var col := KinematicCollision3D.new()
		# Up to 4 contacts: a ledge can sit right on top of a chimney wall.
		if test_move(global_transform, Vector3(dir * wall_probe, 0.0, 0.0), col, 0.001, false, 4):
			for i in col.get_collision_count():
				var n := col.get_normal(i)
				if absf(n.x) >= 0.7 and _is_jumpable(col.get_collider(i)):
					return 1 if n.x > 0.0 else -1
	return 0


static func _is_jumpable(collider: Object) -> bool:
	return collider != null and collider.get("allow_wall_jump") == true


func _standing_on_static() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.7 and c.get_collider() is PRBlock:
			return true
	return false


func _check_respawn_rules(delta: float) -> void:
	if global_position.y < checkpoint_position.y - fall_margin:
		start_respawn()
		return
	if controls_enabled and stun_time <= 0.0 and Input.is_action_pressed(PRInput.runner_action(team, "respawn")):
		_respawn_hold += delta
		if _respawn_hold >= manual_respawn_hold:
			_respawn_hold = 0.0
			start_respawn()
	else:
		_respawn_hold = 0.0
	respawn_hold_ratio = clampf(_respawn_hold / manual_respawn_hold, 0.0, 1.0)


func _process_respawn(delta: float) -> void:
	_respawn_timer -= delta
	if _respawn_timer > 0.0:
		return
	_respawn_timer = -1.0
	invert_time = 0.0
	_teleport(checkpoint_position)
	_model_slot.visible = true
	play_one_shot(&"Spawn_Air", 0.5)
	respawned.emit(team)


func _teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_coyote = 0.0
	_buffer = 0.0
	_lock = 0.0
	_jumping = false
	_last_wall_side = 0
	_wall_timer = 0.0
	_respawn_hold = 0.0
	_no_wall_time = 0.0
	stun_time = 0.0
	_dancing = false
	reset_physics_interpolation()


# --- Look ---------------------------------------------------------------------

## Stun stars over the head and the spree flame trail.
func _build_effects() -> void:
	_stars = Label3D.new()
	_stars.text = "✦  ✦  ✦"
	_stars.font = PRTheme.body_font(900)
	_stars.font_size = 64
	_stars.pixel_size = 0.006
	_stars.modulate = Color(1.0, 0.92, 0.35)
	_stars.outline_size = 10
	_stars.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_stars.rotation_degrees.x = -70.0
	_stars.position = Vector3(0, 2.35, 0)
	_stars.no_depth_test = true
	_stars.visible = false
	add_child(_stars)

	_flame = CPUParticles3D.new()
	_flame.emitting = false
	_flame.amount = 40
	_flame.lifetime = 0.55
	_flame.local_coords = false
	_flame.position = Vector3(0, 1.0, 0)
	_flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flame.emission_sphere_radius = 0.45
	_flame.direction = Vector3(0, 1, 0)
	_flame.spread = 25.0
	_flame.gravity = Vector3(0, 2.0, 0)
	_flame.initial_velocity_min = 0.6
	_flame.initial_velocity_max = 1.4
	_flame.scale_amount_min = 0.5
	_flame.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_flame.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	grad.set_color(1, Color(0.9, 0.15, 0.05, 0.0))
	_flame.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.vertex_color_use_as_albedo = true
	quad.material = fm
	_flame.mesh = quad
	add_child(_flame)

func _apply_team_look() -> void:
	if not is_node_ready():
		return
	var c := PRConfig.team_color(team)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	_ring.material_override = mat
	_tag.modulate = c.lightened(0.25)


func _update_look(delta: float, axis: float) -> void:
	if absf(axis) > 0.1 and _lock <= 0.0:
		_facing = signf(axis)
	if is_dancing():
		_model_slot.rotation.y += delta * 9.0
	else:
		_model_slot.rotation.y = lerp_angle(_model_slot.rotation.y, PI * 0.5 * _facing, minf(turn_speed * delta, 1.0))

	if _anim_lock > 0.0:
		_anim_lock -= delta
		if _anim_lock > 0.0 and _forced_anim != &"":
			return
	var want: StringName = &"idle"
	if has_finished:
		want = &"victory"
	elif not is_on_floor():
		want = &"jump"
	elif absf(velocity.x) > 0.6:
		want = &"run"
	_play(want, 0.15)


func _resolve_anim_name(anim: StringName) -> StringName:
	if _anim == null:
		return &""
	if _anim.has_animation(anim):
		return anim
	match anim:
		&"Idle", &"idle":
			if _anim.has_animation(&"idle"): return &"idle"
			if _anim.has_animation(&"Idle"): return &"Idle"
		&"Running_A", &"run":
			if _anim.has_animation(&"run"): return &"run"
		&"Jump_Start", &"Jump_Idle", &"jump":
			if _anim.has_animation(&"jump"): return &"jump"
		&"Cheer", &"victory":
			if _anim.has_animation(&"victory"): return &"victory"
		&"Hit_A", &"Hit_B", &"block":
			if _anim.has_animation(&"block"): return &"block"
		&"push":
			if _anim.has_animation(&"push"): return &"push"
		&"slash":
			if _anim.has_animation(&"slash"): return &"slash"
	return &""


func _play(anim: StringName, blend: float) -> void:
	if _anim == null:
		return
	var resolved := _resolve_anim_name(anim)
	if resolved == &"":
		if _anim.is_playing() and _anim.current_animation == &"run":
			_anim.stop()
		return
	if resolved == &"run" or resolved == &"idle":
		var a = _anim.get_animation(resolved)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
	if _anim.current_animation != resolved or not _anim.is_playing():
		_anim.play(resolved, blend)
