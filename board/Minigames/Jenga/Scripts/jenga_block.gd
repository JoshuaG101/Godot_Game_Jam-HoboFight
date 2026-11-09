
extends RigidBody3D

@export_range(1, 10) var removal_difficulty: int = 1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var selection_material: StandardMaterial3D
var probability_material: StandardMaterial3D

var is_selected: bool = false
var probability_highlighted: bool = false


func _ready() -> void:
	add_to_group("jenga_blocks")

	# Yellow material for normal block selection.
	selection_material = StandardMaterial3D.new()
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_material.albedo_color = Color(1.0, 0.8, 0.1)

	# Red material for Probability Command.
	probability_material = StandardMaterial3D.new()
	probability_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	probability_material.albedo_color = Color(1.0, 0.1, 0.1)


func set_selected(value: bool) -> void:
	is_selected = value
	update_highlight()


func set_probability_highlight(value: bool) -> void:
	probability_highlighted = value
	update_highlight()


func update_highlight() -> void:
	if is_selected:
		mesh_instance.material_overlay = selection_material
	elif probability_highlighted:
		mesh_instance.material_overlay = probability_material
	else:
		mesh_instance.material_overlay = null


func modify_difficulty(amount: int) -> void:
	removal_difficulty = clampi(
		removal_difficulty + amount,
		1,
		10
	)
