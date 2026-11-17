@tool
class_name PRFinishGate
extends Area3D
## The finish line. The origin sits on the floor in the middle of the arch.

@export var width := 3.0:
	set(value):
		width = value
		_rebuild()
@export var height := 3.2:
	set(value):
		height = value
		_rebuild()

var team := 0

var _shape: CollisionShape3D
var _parts: Array[MeshInstance3D] = []
var _banner: Label3D


func _ready() -> void:
	collision_layer = 8 # PRConfig.LAYER_TRIGGERS
	collision_mask = 2 # PRConfig.LAYER_RUNNER
	monitorable = false
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var runner := body as PRRunner
	if runner != null and runner.team == team:
		runner.finish()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		PRBlock.free_stale_internal_children(self)
		_shape = CollisionShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.84, 0.2)
		mat.metallic = 0.6
		mat.roughness = 0.35
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.75, 0.1)
		mat.emission_energy_multiplier = 0.4
		for i in 3:
			var m := MeshInstance3D.new()
			m.mesh = BoxMesh.new()
			m.material_override = mat
			add_child(m, false, Node.INTERNAL_MODE_FRONT)
			_parts.append(m)
		_banner = Label3D.new()
		_banner.text = "FINISH"
		_banner.font = PRTheme.display_font()
		_banner.modulate = Color(1.0, 0.92, 0.6)
		_banner.font_size = 96
		_banner.pixel_size = 0.006
		_banner.outline_size = 16
		add_child(_banner, false, Node.INTERNAL_MODE_FRONT)
	var box := BoxShape3D.new()
	box.size = Vector3(width - 0.6, height, 3)
	_shape.shape = box
	_shape.position = Vector3(0, height * 0.5, 0)
	(_parts[0].mesh as BoxMesh).size = Vector3(0.3, height, 0.6)
	_parts[0].position = Vector3(-width * 0.5, height * 0.5, -1.0)
	(_parts[1].mesh as BoxMesh).size = Vector3(0.3, height, 0.6)
	_parts[1].position = Vector3(width * 0.5, height * 0.5, -1.0)
	(_parts[2].mesh as BoxMesh).size = Vector3(width + 0.3, 0.35, 0.6)
	_parts[2].position = Vector3(0, height, -1.0)
	_banner.position = Vector3(0, height - 0.55, -0.9)
