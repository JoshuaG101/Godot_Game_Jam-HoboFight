extends RigidBody3D

@export_range(1, 10) var removal_difficulty: int = 1
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var selection_material: StandardMaterial3D
var hover_material: StandardMaterial3D
var is_selected_state: bool = false

func _ready() -> void:
	add_to_group("jenga_blocks")
	
	selection_material = StandardMaterial3D.new()
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_material.albedo_color = Color(1.0, 0.85, 0.15, 0.8)
	
	hover_material = StandardMaterial3D.new()
	hover_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hover_material.albedo_color = Color(0.4, 0.8, 1.0, 0.5)

func set_selected(value: bool) -> void:
	is_selected_state = value
	if not mesh_instance:
		return
	if value:
		mesh_instance.material_overlay = selection_material
	else:
		mesh_instance.material_overlay = null

func set_hovered(value: bool) -> void:
	if is_selected_state or not mesh_instance:
		return
	if value:
		mesh_instance.material_overlay = hover_material
	else:
		mesh_instance.material_overlay = null

func modify_difficulty(amount: int) -> void:
	removal_difficulty = clampi(removal_difficulty + amount, 1, 10)
