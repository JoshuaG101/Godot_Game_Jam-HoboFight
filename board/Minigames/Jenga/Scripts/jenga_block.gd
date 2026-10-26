extends RigidBody3D


@export_range(1,10) var removal_difficulty: int =1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


var selection_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("jenga_blocks")
	
	selection_material = StandardMaterial3D.new()
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_material.albedo_color = Color(1.0,0.8,0.1)
	

func set_selected(value:bool) -> void:
	
	if value:
		mesh_instance.material_overlay = selection_material
	else:
		mesh_instance.material_overlay = null

func modify_difficulty(amount:int) -> void:
	removal_difficulty = clampi(
		removal_difficulty + amount,
		1,
		10
	)
