@tool
class_name PRGustTrap
extends PRTrap
## A wall vent. When sprung it glows for the warning, then blows every Runner in
## its area sideways for 1.5 s. Running into it is slow; standing still lets it
## carry you. The node's origin is the centre of the wind area.

@export var size := Vector3(7, 6, 3):
	set(value):
		size = value
		_rebuild()
## Which way the wind blows: -1 = to the left, +1 = to the right.
@export_range(-1, 1, 2) var push_dir := -1:
	set(value):
		push_dir = value
		_rebuild()

var _area: Area3D
var _vent: MeshInstance3D
var _grille: Array[MeshInstance3D] = []
var _vent_mat: StandardMaterial3D
var _streaks: CPUParticles3D


func _ready() -> void:
	super._ready()
	if display_name == "Trap":
		display_name = "Wind gust"
	_rebuild()


func active_time() -> float:
	return PRConfig.GUST_TIME


func get_warning_point() -> Vector3:
	return _vent.global_position + Vector3(0, 1.2, 1.0)


func _warn_tick(_delta: float) -> void:
	_vent_mat.emission_energy_multiplier = 1.0 + 2.0 * absf(sin(_time * 14.0))


func _on_warn() -> void:
	_vent_mat.emission = PRConfig.HINDER_COLOR


func _on_activate() -> void:
	_streaks.emitting = true
	_vent_mat.emission = Color(0.8, 0.9, 1.0)
	_vent_mat.emission_energy_multiplier = 2.0
	PRSfx.emit(self, "gust", 0.0, 0.05)


func _active_tick(_delta: float) -> void:
	for r in _runners_in(_area):
		r.apply_wind(float(push_dir) * PRConfig.GUST_SPEED)


func _on_deactivate() -> void:
	_streaks.emitting = false
	_vent_mat.emission = Color(0.25, 0.3, 0.35)
	_vent_mat.emission_energy_multiplier = 0.3


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _area == null:
		PRBlock.free_stale_internal_children(self)
		_area = _make_area(size)
		_vent = MeshInstance3D.new()
		add_child(_vent, false, Node.INTERNAL_MODE_FRONT)
		_vent_mat = PRTrap.glow_material(Color(0.25, 0.3, 0.35), 0.3)
		_vent_mat.albedo_color = Color(0.18, 0.18, 0.2)
		_vent_mat.metallic = 0.6
		for i in 4:
			var g := MeshInstance3D.new()
			g.material_override = PRDevice.make_material(Color(0.1, 0.1, 0.11), 0.7, 0.4)
			add_child(g, false, Node.INTERNAL_MODE_FRONT)
			_grille.append(g)
		_streaks = CPUParticles3D.new()
		_streaks.emitting = false
		_streaks.amount = 60
		_streaks.lifetime = 0.7
		_streaks.local_coords = false
		_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_streaks.gravity = Vector3.ZERO
		_streaks.spread = 4.0
		_streaks.initial_velocity_min = 9.0
		_streaks.initial_velocity_max = 13.0
		var quad := QuadMesh.new()
		quad.size = Vector2(1.1, 0.05)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.albedo_color = Color(0.9, 0.95, 1.0, 0.55)
		quad.material = qm
		_streaks.mesh = quad
		add_child(_streaks, false, Node.INTERNAL_MODE_FRONT)
	(_area.get_child(0) as CollisionShape3D).shape.size = size
	# The vent sits on the side the wind comes from, against the back wall.
	var vx := -float(push_dir) * (size.x * 0.5 - 0.3)
	var vm := BoxMesh.new()
	vm.size = Vector3(0.5, 1.6, 0.4)
	_vent.mesh = vm
	_vent.material_override = _vent_mat
	_vent.position = Vector3(vx, 0, -1.3)
	for i in _grille.size():
		var gm := BoxMesh.new()
		gm.size = Vector3(0.56, 0.08, 0.45)
		_grille[i].mesh = gm
		_grille[i].position = Vector3(vx, -0.55 + i * 0.37, -1.28)
	_streaks.position = Vector3(0, 0, 0.2)
	_streaks.emission_box_extents = Vector3(size.x * 0.5, size.y * 0.45, 0.6)
	_streaks.direction = Vector3(float(push_dir), 0, 0)
