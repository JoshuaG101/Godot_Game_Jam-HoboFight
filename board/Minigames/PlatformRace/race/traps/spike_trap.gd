@tool
class_name PRSpikeTrap
extends PRTrap
## Spikes hidden in a chimney wall. When sprung the wall panel glows for the
## warning, then spikes shoot out for 0.5 s and knock any Runner in front of
## them off the wall (they drop to the chimney base). The node's origin is the
## centre of the danger area, against the wall.

@export var size := Vector3(1.6, 3.0, 3):
	set(value):
		size = value
		_rebuild()
## Which way the spikes point (and push): -1 = to the left, +1 = to the right.
@export_range(-1, 1, 2) var push_dir := -1:
	set(value):
		push_dir = value
		_rebuild()

var _area: Area3D
var _panel: MeshInstance3D
var _panel_mat: StandardMaterial3D
var _spikes: Node3D
var _out := 0.0
var _knocked: Array[PRRunner] = []


func _ready() -> void:
	super._ready()
	if display_name == "Trap":
		display_name = "Wall spikes"
	_rebuild()


func active_time() -> float:
	return PRConfig.SPIKES_OUT


func reset_time() -> float:
	return 0.3


func get_warning_point() -> Vector3:
	return global_position + Vector3(float(push_dir) * 0.4, size.y * 0.5 + 0.6, 1.6)


func _on_warn() -> void:
	_panel_mat.emission = PRConfig.HINDER_COLOR


func _warn_tick(_delta: float) -> void:
	_panel_mat.emission_energy_multiplier = 0.8 + 2.2 * absf(sin(_time * 14.0))
	_set_out(0.12 * absf(sin(_time * 20.0)))


func _on_activate() -> void:
	_knocked.clear()
	PRSfx.emit(self, "spikes", 0.0, 0.05)


func _active_tick(delta: float) -> void:
	_out = minf(_out + delta / 0.08, 1.0)
	_set_out(_out)
	for r in _runners_in(_area):
		if r in _knocked:
			continue
		_knocked.append(r)
		r.knock(Vector3(float(push_dir) * PRConfig.SPIKES_KNOCK.x, PRConfig.SPIKES_KNOCK.y, 0))


func _on_deactivate() -> void:
	_panel_mat.emission_energy_multiplier = 0.0


func _reset_tick(delta: float, time_up: bool) -> bool:
	_out = maxf(_out - delta / 0.2, 0.0)
	_set_out(_out)
	return time_up and _out <= 0.0


func _set_out(amount: float) -> void:
	# Spikes slide out of the wall along push_dir.
	_spikes.position.x = -float(push_dir) * 0.55 + float(push_dir) * 0.8 * amount


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _area == null:
		PRBlock.free_stale_internal_children(self)
		_area = _make_area(size)
		_panel = MeshInstance3D.new()
		add_child(_panel, false, Node.INTERNAL_MODE_FRONT)
		_panel_mat = PRTrap.glow_material(PRConfig.HINDER_COLOR, 0.0)
		_panel_mat.albedo_color = Color(0.2, 0.17, 0.16)
		_spikes = Node3D.new()
		add_child(_spikes, false, Node.INTERNAL_MODE_FRONT)
	(_area.get_child(0) as CollisionShape3D).shape.size = size
	# A dark iron panel on the wall face behind the spikes.
	var wall_x := -float(push_dir) * size.x * 0.5
	var pm := BoxMesh.new()
	pm.size = Vector3(0.06, size.y, 2.6)
	_panel.mesh = pm
	_panel.material_override = _panel_mat
	_panel.position = Vector3(wall_x, 0, 0)
	for c in _spikes.get_children():
		c.queue_free()
	var iron := PRDevice.make_material(Color(0.62, 0.62, 0.68), 0.85, 0.3)
	var rows := maxi(int(size.y / 0.55), 2)
	for i in rows:
		for j in 3:
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.17
			cm.height = 0.7
			cm.radial_segments = 8
			cone.mesh = cm
			cone.material_override = iron
			# Point the cone along push_dir.
			cone.rotation_degrees = Vector3(0, 0, -90.0 * float(push_dir))
			cone.position = Vector3(wall_x, -size.y * 0.5 + 0.3 + i * (size.y - 0.6) / maxf(rows - 1, 1), -0.9 + j * 0.9)
			_spikes.add_child(cone)
	_set_out(0.0)
