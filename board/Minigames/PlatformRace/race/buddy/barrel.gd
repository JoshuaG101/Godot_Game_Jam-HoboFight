class_name PRBarrel
extends Node3D
## A falling barrel from a hindering Buddy. A ring marks where it will land.
## Hitting the Runner stuns them with no knockback, so it can never make them
## fall. It breaks on the Runner or on landing.
##
## A power barrel (`special` = the Buddy's major) adds an effect:
##   ART          splashes paint where it breaks (slow, short jumps)
##   ANTHROPOLOGY a hit flips the Runner's controls
##   MUSIC        a hit stuns longer and makes the Runner dance
##   HISTORY      steers toward the Runner while it falls
##   RELIGION     stuns everything around where it breaks
##   COMPUTER_SCIENCE  jumps left and right while it falls
##
## Runner powers can answer it: a Paint Shield blocks it, a timed Leap of Faith
## lets it pass through, and a Hack freezes it in the air.

const MODEL := preload("res://Minigames/PlatformRace/assets/fantasy_assets/Exports/glTF/Barrel.gltf")
const HIT_HALF_WIDTH := 0.95

var dropper: PRDropper
var target: PRRunner
## The Buddy's major for a power barrel, or -1 for a plain one.
var special := -1
var x := 0.0
var start_y := 0.0
var land_y := 0.0
## Seconds left frozen by a Hack.
var frozen_time := 0.0

var _t := 0.0
var _y := 0.0
var _gravity := 30.0
var _done := false
## Passed through the Runner thanks to a Leap of Faith: it can't hit again.
var _passed := false
var _glitch_timer := 0.0
var _pivot: Node3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _icon: Label3D
var _freeze_fx: Label3D


func setup(p_dropper: PRDropper, p_x: float, p_start_y: float, p_land_y: float, p_target: PRRunner, p_special := -1) -> void:
	dropper = p_dropper
	x = p_x
	start_y = p_start_y
	land_y = p_land_y
	target = p_target
	special = p_special
	_y = start_y
	# Constant fall acceleration that reaches the predicted landing in DROP_FALL_TIME.
	var drop := maxf(start_y - (land_y + 0.5), 1.0)
	_gravity = 2.0 * drop / (PRConfig.DROP_FALL_TIME * PRConfig.DROP_FALL_TIME)
	global_position = Vector3(x, start_y, 0)
	add_to_group(&"pr_barrels")
	_build()
	if target and target.power and target.power.consume_hack():
		freeze(PRMajors.FREEZE_TIME)


## The team whose tower this barrel is falling on.
func victim_team() -> int:
	return target.team if target else -1


func freeze(seconds: float) -> void:
	if _done:
		return
	frozen_time = maxf(frozen_time, seconds)
	_freeze_fx.visible = true


func is_frozen() -> bool:
	return frozen_time > 0.0


## World y of the first surface (world or machines) below (px, from_y).
static func ground_below(world: World3D, px: float, from_y: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(px, from_y, 0), Vector3(px, from_y - 80.0, 0), PRConfig.LAYER_WORLD | PRConfig.LAYER_DEVICES)
	var hit := world.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return from_y - 80.0
	return (hit["position"] as Vector3).y


func _physics_process(delta: float) -> void:
	if _done:
		return
	if frozen_time > 0.0:
		frozen_time -= delta
		_pivot.position.x = randf_range(-0.05, 0.05)
		if frozen_time <= 0.0:
			_freeze_fx.visible = false
			_pivot.position.x = 0.0
		return
	_steer(delta)
	# The ground is measured from where the barrel is now, before it moves, so a
	# fast barrel can't skip through a thin ledge.
	var ground := ground_below(get_world_3d(), x, _y + 0.4)
	_t += delta
	_y = start_y - 0.5 * _gravity * _t * _t
	global_position = Vector3(x, _y, 0)
	_pivot.rotation.z += delta * 8.0
	var k := clampf(_t / PRConfig.DROP_FALL_TIME, 0.0, 1.0)
	_ring.global_position = Vector3(x, ground + 0.4, 0.9)
	var s := lerpf(1.5, 0.85, k)
	_ring.scale = Vector3(s, 1, s)
	_ring_mat.albedo_color.a = lerpf(0.35, 0.95, k)
	if _touching_target():
		match target.defend_against_barrel():
			"faith":
				_passed = true
			"shield":
				_break(global_position)
				return
			_:
				if _hit_target():
					return
	if _y <= ground + 0.5:
		_land(Vector3(x, ground, 0))
	elif _y < start_y - 120.0:
		_finish()


## HISTORY barrels steer toward the Runner; CS barrels glitch sideways.
func _steer(delta: float) -> void:
	if target == null:
		return
	var center := dropper.course.global_position.x if dropper and dropper.course else x
	if special == PRMajors.Major.HISTORY:
		x = move_toward(x, target.global_position.x, PRMajors.HOMING_SPEED * delta)
	elif special == PRMajors.Major.COMPUTER_SCIENCE:
		_glitch_timer -= delta
		if _glitch_timer <= 0.0:
			_glitch_timer = PRMajors.GLITCH_STEP
			x = clampf(x + randf_range(-PRMajors.GLITCH_JUMP, PRMajors.GLITCH_JUMP), center - PRConfig.DROP_MARKER_LIMIT, center + PRConfig.DROP_MARKER_LIMIT)
			_pivot.visible = randf() > 0.25


func _touching_target() -> bool:
	if _passed or target == null or target.is_respawning():
		return false
	var rp := target.global_position
	return absf(rp.x - x) < HIT_HALF_WIDTH and _y - 0.5 < rp.y + 2.0 and _y + 0.5 > rp.y


## Returns true when the barrel broke on the Runner.
func _hit_target() -> bool:
	var seconds := PRMajors.DANCE_STUN if special == PRMajors.Major.MUSIC else PRConfig.STUN_TIME
	if not target.stun(seconds, special == PRMajors.Major.MUSIC):
		return false
	if special == PRMajors.Major.ANTHROPOLOGY:
		target.invert_controls(PRMajors.INVERT_TIME)
	if dropper:
		dropper.on_hit()
	PRSfx.emit(self, "stun", 0.0, 0.05)
	_break(target.global_position)
	return true


func _land(at: Vector3) -> void:
	_break(at)


## Breaks the barrel, with the area effects of a power barrel at `at`.
func _break(at: Vector3) -> void:
	if special == PRMajors.Major.ART:
		_splash_paint(at)
	elif special == PRMajors.Major.RELIGION:
		_blessing(at)
	_finish()


func _splash_paint(at: Vector3) -> void:
	if dropper == null or dropper.course == null:
		return
	var zone := PRPaintZone.new()
	dropper.course.add_child(zone)
	zone.setup(target, at.x, PRBarrel.ground_below(get_world_3d(), at.x, at.y + 0.6))


func _blessing(at: Vector3) -> void:
	var ring := PRBurst.new()
	get_parent().add_child(ring)
	ring.setup(at, PRMajors.BLESS_RADIUS, PRTheme.GOLD)
	if target == null or target.is_respawning() or target.is_stunned():
		return
	var feet := target.global_position
	if Vector2(feet.x - at.x, feet.y + 1.0 - at.y).length() > PRMajors.BLESS_RADIUS:
		return
	if target.defend_against_barrel() != "":
		return
	if target.stun(PRConfig.STUN_TIME):
		if dropper:
			dropper.on_hit()
		PRSfx.emit(self, "stun", 0.0, 0.05)


func _finish() -> void:
	_done = true
	remove_from_group(&"pr_barrels")
	PRSfx.emit(self, "crash", -2.0, 0.12)
	_ring.visible = false
	_pivot.visible = false
	_icon.visible = false
	_freeze_fx.visible = false
	var bits := CPUParticles3D.new()
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.amount = 12
	bits.lifetime = 0.8
	bits.local_coords = false
	bits.direction = Vector3(0, 1, 0)
	bits.spread = 70.0
	bits.initial_velocity_min = 3.0
	bits.initial_velocity_max = 7.0
	bits.gravity = Vector3(0, -22, 0)
	bits.angular_velocity_min = -400
	bits.angular_velocity_max = 400
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.08, 0.14)
	bm.material = PRBlock.material_for(PRBlock.Look.WOOD)
	bits.mesh = bm
	add_child(bits)
	bits.emitting = true
	get_tree().create_timer(1.0, false).timeout.connect(queue_free)


func _build() -> void:
	var model := MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * 1.25
	model.position = Vector3(0, -0.55, 0)
	_pivot = Node3D.new()
	add_child(_pivot)
	_pivot.add_child(model)
	var ring_color := PRConfig.HINDER_COLOR
	if special >= 0:
		ring_color = PRTheme.GOLD
		_glow(model)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.85
	torus.rings = 24
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.top_level = true
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = ring_color
	_ring_mat.no_depth_test = true
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	# Tilted toward the camera so it reads as a ring, not a line.
	_ring.rotation_degrees.x = 65.0
	_ring.global_position = Vector3(x, land_y + 0.4, 0.9)
	_icon = _make_label(PRMajors.icon(special) if special >= 0 else "", PRTheme.GOLD, 0.9, 72)
	_freeze_fx = _make_label("HACKED", PRTheme.SKY, 0.0, 44)
	_freeze_fx.visible = false


func _make_label(text: String, color: Color, y: float, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = PRTheme.display_font()
	l.font_size = size
	l.pixel_size = 0.007
	l.outline_size = 14
	l.outline_modulate = PRTheme.INK
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 6
	l.position = Vector3(0, y, 0.8)
	add_child(l)
	return l


## A gold shimmer over a power barrel so it reads as special.
static func _glow(model: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(PRTheme.GOLD, 0.35)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = mat
