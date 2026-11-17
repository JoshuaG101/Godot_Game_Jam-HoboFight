@tool
class_name PRCrumbleTrap
extends PRTrap
## A stone you can stand on, with visible cracks. When sprung it shakes for the
## warning, falls away, and comes back after 3 s, but never inside a Runner.
## The node's origin is the centre of the stone.

@export var size := Vector3(1.5, 0.6, 3):
	set(value):
		size = value
		_rebuild()

var _body: StaticBody3D
var _shape: CollisionShape3D
var _visual: Node3D
var _mesh: MeshInstance3D
var _cracks: Array[MeshInstance3D] = []
var _fall_v := 0.0
var _mat: StandardMaterial3D


func _ready() -> void:
	super._ready()
	if display_name == "Trap":
		display_name = "Crumbling stone"
	_rebuild()


func active_time() -> float:
	return PRConfig.CRUMBLE_FALL


func reset_time() -> float:
	return PRConfig.CRUMBLE_RETURN


func get_warning_point() -> Vector3:
	return global_position + Vector3(0, 1.4, 1.6)


func _warn_tick(_delta: float) -> void:
	_visual.position = Vector3(randf_range(-0.07, 0.07), randf_range(-0.04, 0.04), 0)
	_mat.albedo_color = Color(0.8, 0.72, 0.62).lerp(PRConfig.HINDER_COLOR, 0.35 + 0.25 * sin(_time * 30.0))


func _on_activate() -> void:
	_body.collision_layer = 0
	_fall_v = 0.0
	PRSfx.emit(self, "crumble", 0.0, 0.08)


func _active_tick(delta: float) -> void:
	_fall_v += 30.0 * delta
	_visual.position.y -= _fall_v * delta
	_visual.rotation.z += delta * 2.0
	_mat.albedo_color.a = clampf(_t / PRConfig.CRUMBLE_FALL, 0.0, 1.0)


func _on_deactivate() -> void:
	_visual.visible = false


func _reset_tick(_delta: float, time_up: bool) -> bool:
	if not time_up:
		return false
	if _runner_inside():
		return false
	_restore()
	return true


func _restore() -> void:
	_visual.visible = true
	_visual.position = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	_mat.albedo_color = Color(0.8, 0.72, 0.62, 1.0)
	_body.collision_layer = PRConfig.LAYER_WORLD


func _runner_inside() -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = size * 0.98
	params.shape = shape
	params.transform = global_transform
	params.collision_mask = PRConfig.LAYER_RUNNER
	return not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _body == null:
		PRBlock.free_stale_internal_children(self)
		_body = StaticBody3D.new()
		_body.collision_layer = PRConfig.LAYER_WORLD
		_body.collision_mask = 0
		add_child(_body, false, Node.INTERNAL_MODE_FRONT)
		_shape = CollisionShape3D.new()
		_body.add_child(_shape)
		_visual = Node3D.new()
		add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
		_mesh = MeshInstance3D.new()
		_visual.add_child(_mesh)
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = PRBlock.get_texture(PRBlock.Look.STONE)
		_mat.uv1_triplanar = true
		_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
		_mat.albedo_color = Color(0.8, 0.72, 0.62)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.9
		var crack_mat := PRDevice.make_material(Color(0.1, 0.07, 0.05), 0.0, 1.0)
		for i in 3:
			var c := MeshInstance3D.new()
			c.material_override = crack_mat
			_visual.add_child(c)
			_cracks.append(c)
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	_mesh.material_override = _mat
	# Three dark crack lines on the front face so players learn to spot it.
	var angles := [35.0, -40.0, 15.0]
	var xs := [-0.25, 0.15, 0.45]
	for i in _cracks.size():
		var cm := BoxMesh.new()
		cm.size = Vector3(size.y * 0.9, 0.05, 0.02)
		_cracks[i].mesh = cm
		_cracks[i].position = Vector3(xs[i] * size.x, 0, size.z * 0.5 + 0.012)
		_cracks[i].rotation_degrees = Vector3(0, 0, 90.0 + angles[i])
