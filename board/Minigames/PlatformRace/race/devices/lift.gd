@tool
class_name PRLift
extends PRDevice
## A platform on a fixed track. The node's origin is the TOP-CENTRE of the
## platform at the start of the track; `track` is the offset to the other end.
## The owning Buddy holds Action to move it; it turns around at each end.
## With auto_move it runs on its own (a moving platform nobody controls).
##
## Anti-crush: track ends leave headroom (level rule), and a sensor under the
## platform stops it moving down onto a Runner.

@export var platform_size := Vector3(3, 0.5, 3):
	set(value):
		platform_size = value
		_rebuild()
@export var track := Vector3(0, 8, 0):
	set(value):
		track = value
		_rebuild()
@export var speed := 3.5
@export var auto_move := false
@export var end_dwell := 0.35

## Distance travelled along the track (0 = start).
var travel := 0.0
var blocked_below := false

var _dir := 1.0
var _dwell := 0.0
var _held_frame := -100
var _moving_sound_cd := 0.0
var _platform: AnimatableBody3D
var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _trim: MeshInstance3D
var _rail: MeshInstance3D
var _sensor: Area3D
var _sensor_shape: CollisionShape3D

static var _wood_mat: StandardMaterial3D
static var _stone_mat: StandardMaterial3D


func _ready() -> void:
	super._ready()
	_rebuild()
	if not Engine.is_editor_hint():
		register_mesh(_mesh)
		register_mesh(_trim)
		if PRConfig.DEBUG_AUTO_LIFTS:
			auto_move = true


func get_target_point() -> Vector3:
	if _platform:
		return _platform.global_position + Vector3(0, 0.6, 0)
	return global_position


func get_platform_body() -> AnimatableBody3D:
	return _platform


func hold(_buddy_team: int) -> void:
	_held_frame = Engine.get_physics_frames()


func is_driven() -> bool:
	return auto_move or Engine.get_physics_frames() - _held_frame <= 1


func current_speed() -> float:
	return speed * (PRConfig.BOOST_LIFT_MULT if boosted else 1.0)


## Distance to the closest point of the whole track, so a Lift parked at the
## far end still counts as near a Runner waiting at the other end.
func distance_hint(from: Vector3) -> float:
	var a := global_position + Vector3(0, 0.6, 0)
	var b := a + track
	var ab := b - a
	var t := clampf((from - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return from.distance_to(a + ab * t)


func get_prompt_3d(key: String) -> String:
	return "HOLD %s" % key


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _platform == null:
		return
	blocked_below = false
	_moving_sound_cd = maxf(_moving_sound_cd - delta, 0.0)
	if is_driven():
		if _dwell > 0.0:
			_dwell -= delta
		else:
			var length := track.length()
			var step := current_speed() * delta * _dir
			var moving_down := track.normalized().y * step < -0.0001
			if moving_down and _runner_below():
				blocked_below = true
			else:
				travel = clampf(travel + step, 0.0, length)
				if not auto_move and _moving_sound_cd <= 0.0:
					_moving_sound_cd = 0.45
					_sfx("lift")
				if _dir > 0.0 and travel >= length:
					_dir = -1.0
					_dwell = end_dwell
				elif _dir < 0.0 and travel <= 0.0:
					_dir = 1.0
					_dwell = end_dwell
	_platform.position = _platform_local(travel)


func _sfx(slot: String) -> void:
	PRSfx.emit(self, slot, -8.0, 0.05)


func _runner_below() -> bool:
	for body in _sensor.get_overlapping_bodies():
		if body is PRRunner:
			return true
	return false


func _platform_local(t: float) -> Vector3:
	var dir := track.normalized() if track.length() > 0.001 else Vector3.ZERO
	return dir * t + Vector3(0, -platform_size.y * 0.5, 0)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _platform == null:
		PRBlock.free_stale_internal_children(self)
		_platform = AnimatableBody3D.new()
		_platform.sync_to_physics = true
		_platform.collision_layer = 4 # PRConfig.LAYER_DEVICES
		_platform.collision_mask = 0
		add_child(_platform, false, Node.INTERNAL_MODE_FRONT)
		_shape = CollisionShape3D.new()
		_platform.add_child(_shape)
		_mesh = MeshInstance3D.new()
		_platform.add_child(_mesh)
		_trim = MeshInstance3D.new()
		_platform.add_child(_trim)
		_sensor = Area3D.new()
		_sensor.collision_layer = 0
		_sensor.collision_mask = 2 # PRConfig.LAYER_RUNNER
		_sensor.monitorable = false
		_platform.add_child(_sensor)
		_sensor_shape = CollisionShape3D.new()
		_sensor.add_child(_sensor_shape)
		_rail = MeshInstance3D.new()
		var rail_mat := StandardMaterial3D.new()
		rail_mat.albedo_color = Color(0.06, 0.05, 0.05, 0.75)
		rail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rail.material_override = rail_mat
		_rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_rail, false, Node.INTERNAL_MODE_FRONT)
	var box := BoxShape3D.new()
	box.size = platform_size
	_shape.shape = box
	var mesh := BoxMesh.new()
	mesh.size = platform_size
	_mesh.mesh = mesh
	_mesh.material_override = _body_material()
	var trim := BoxMesh.new()
	trim.size = Vector3(platform_size.x + 0.04, 0.16, 0.14)
	_trim.mesh = trim
	_trim.position = Vector3(0, platform_size.y * 0.5 - 0.08, platform_size.z * 0.5 + 0.03)
	_trim.material_override = _trim_material()
	var sensor_box := BoxShape3D.new()
	sensor_box.size = Vector3(platform_size.x - 0.1, 0.45, 1.0)
	_sensor_shape.shape = sensor_box
	_sensor_shape.position = Vector3(0, -platform_size.y * 0.5 - 0.3, 0)
	# Rail: a dark strip behind the platform showing the whole track.
	var length := track.length()
	var rail := BoxMesh.new()
	var horizontal := absf(track.x) > absf(track.y)
	rail.size = Vector3(length + platform_size.x, 0.3, 0.1) if horizontal else Vector3(0.5, length + platform_size.y, 0.1)
	_rail.mesh = rail
	_rail.position = track * 0.5 + Vector3(0, -platform_size.y * 0.5, -platform_size.z * 0.5 - 0.15)
	_platform.position = _platform_local(travel)


## Wooden planks for Buddy lifts, plain stone for moving platforms.
func _body_material() -> StandardMaterial3D:
	if auto_move:
		if _stone_mat == null:
			_stone_mat = PRDevice.make_material(Color(0.5, 0.5, 0.56), 0.0, 0.9)
		return _stone_mat
	if _wood_mat == null:
		_wood_mat = StandardMaterial3D.new()
		_wood_mat.albedo_texture = PRBlock.get_texture(PRBlock.Look.WOOD)
		_wood_mat.uv1_triplanar = true
		_wood_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
		_wood_mat.roughness = 0.85
	return _wood_mat


func _trim_material() -> StandardMaterial3D:
	var c := Color(0.7, 0.7, 0.7) if Engine.is_editor_hint() else PRConfig.team_color(team)
	if auto_move:
		c = Color(0.85, 0.75, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 0.7
	return mat


## Re-applies the team colour once PRCourse has set `team`.
func refresh_team() -> void:
	if _trim:
		_trim.material_override = _trim_material()
