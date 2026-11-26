@tool
class_name PRSpikes
extends Area3D
## A permanent spike strip at the bottom of a pit. Touching it respawns the
## Runner at their checkpoint. The node's origin is the centre of the strip's
## base; the spikes point up.

@export var size := Vector3(5, 0.7, 3):
	set(value):
		size = value
		_rebuild()

var _shape: CollisionShape3D
var _mm: MultiMeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # PRConfig.LAYER_RUNNER
	monitorable = false
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var runner := body as PRRunner
	if runner and not runner.is_respawning():
		runner.start_respawn()
		PRSfx.emit(self, "spikes", -3.0, 0.1)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		PRBlock.free_stale_internal_children(self)
		_shape = CollisionShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
		_mm = MultiMeshInstance3D.new()
		add_child(_mm, false, Node.INTERNAL_MODE_FRONT)
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, size.z)
	_shape.shape = box
	_shape.position = Vector3(0, size.y * 0.5, 0)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = size.y
	cone.radial_segments = 6
	cone.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.55, 0.6)
	mat.metallic = 0.8
	mat.roughness = 0.35
	cone.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	var nx := maxi(int(size.x / 0.42), 1)
	var nz := maxi(int(size.z / 0.6), 1)
	mm.instance_count = nx * nz
	var k := 0
	for i in nx:
		for j in nz:
			var x := -size.x * 0.5 + (i + 0.5) * size.x / nx
			var z := -size.z * 0.5 + (j + 0.5) * size.z / nz
			var h := 0.75 + 0.25 * float((i * 7 + j * 3) % 4) / 3.0
			mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(1, h, 1)), Vector3(x, size.y * 0.5 * h, z)))
			k += 1
	_mm.multimesh = mm
