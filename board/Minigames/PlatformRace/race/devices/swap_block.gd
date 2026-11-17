@tool
class_name PRSwapBlock
extends StaticBody3D
## One rune stone of a PRSwapSteps device. Belongs to set 0 (◆ violet) or set 1
## (● lime). Only the device's solid set collides. A block never turns solid
## inside a Runner: it waits, flickering, until nobody overlaps it.

@export var size := Vector3(1.5, 0.6, 3):
	set(value):
		size = value
		_rebuild()
@export_range(0, 1) var set_id := 0:
	set(value):
		set_id = value
		_rebuild()

var want_solid := true
var is_solid := true

var _mesh: MeshInstance3D
var _rune: Label3D
var _shape: CollisionShape3D
var _mat: StandardMaterial3D
var _waiting := false
var _time := 0.0


func _ready() -> void:
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		PRBlock.free_stale_internal_children(self)
		_mesh = MeshInstance3D.new()
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
		_shape = CollisionShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
		_rune = Label3D.new()
		_rune.font_size = 96
		_rune.pixel_size = 0.006
		_rune.outline_size = 14
		add_child(_rune, false, Node.INTERNAL_MODE_FRONT)
		_mat = StandardMaterial3D.new()
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.emission_enabled = true
		_mat.roughness = 0.4
	var box := BoxMesh.new()
	box.size = size
	_mesh.mesh = box
	_mesh.material_override = _mat
	var shape := BoxShape3D.new()
	shape.size = size
	_shape.shape = shape
	_rune.text = PRConfig.SWAP_ICONS[set_id]
	_rune.position = Vector3(0, 0, size.z * 0.5 + 0.02)
	_apply()


func get_color() -> Color:
	return PRConfig.SWAP_COLORS[set_id]


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_waiting = false
	if want_solid and not is_solid:
		if _runner_inside():
			_waiting = true
		else:
			is_solid = true
			_apply()
	elif not want_solid and is_solid:
		is_solid = false
		_apply()
	if _waiting:
		_mat.albedo_color.a = 0.25 + 0.35 * absf(sin(_time * 18.0))


func _runner_inside() -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = size * Vector3(0.98, 0.98, 0.98)
	params.shape = shape
	params.transform = global_transform
	params.collision_mask = PRConfig.LAYER_RUNNER
	params.collide_with_areas = false
	return not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## Sets whether this block should be solid. `instant` skips the occupancy wait
## (used at race start, when nobody can be inside).
func set_wanted(on: bool, instant := false) -> void:
	want_solid = on
	if instant:
		is_solid = on
		_apply()


func _apply() -> void:
	if _mat == null:
		return
	var c := get_color()
	var solid_look := true if Engine.is_editor_hint() else is_solid
	collision_layer = PRConfig.LAYER_WORLD if solid_look else 0
	if solid_look:
		_mat.albedo_color = Color(c.r, c.g, c.b, 0.97)
		_mat.emission = c
		_mat.emission_energy_multiplier = 0.45
		_rune.modulate = Color(1, 1, 1, 0.95)
	else:
		_mat.albedo_color = Color(c.r, c.g, c.b, 0.16)
		_mat.emission = c
		_mat.emission_energy_multiplier = 0.15
		_rune.modulate = Color(c.r, c.g, c.b, 0.45)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if solid_look else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
