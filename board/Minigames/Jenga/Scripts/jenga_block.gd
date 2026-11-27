
extends RigidBody3D

@export_range(1, 10) var removal_difficulty: int = 1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var selection_material: StandardMaterial3D
var probability_material: StandardMaterial3D
var safest_material: StandardMaterial3D

var is_selected: bool = false
var probability_highlighted: bool = false
var safest_highlighted: bool = false


func _ready() -> void:
	add_to_group("jenga_blocks")

	# Bright Gold/Cyan/Yellow glow: normal block selection.
	selection_material = StandardMaterial3D.new()
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_material.albedo_color = Color(1.0, 0.9, 0.2, 0.85)
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.emission_enabled = true
	selection_material.emission = Color(1.0, 0.85, 0.1) * 2.5
	selection_material.emission_energy_multiplier = 2.0
	selection_material.rim_enabled = true
	selection_material.rim = 1.0

	# Red: high removal difficulty.
	probability_material = StandardMaterial3D.new()
	probability_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	probability_material.albedo_color = Color(1.0, 0.15, 0.15, 0.85)
	probability_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	probability_material.emission_enabled = true
	probability_material.emission = Color(1.0, 0.1, 0.1) * 2.0

	# Green: safest available block.
	safest_material = StandardMaterial3D.new()
	safest_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	safest_material.albedo_color = Color(0.15, 1.0, 0.3, 0.85)
	safest_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	safest_material.emission_enabled = true
	safest_material.emission = Color(0.1, 1.0, 0.2) * 2.0


func set_selected(value: bool) -> void:
	is_selected = value
	update_highlight()


func set_probability_highlight(value: bool) -> void:
	probability_highlighted = value
	update_highlight()


func set_safest_highlight(value: bool) -> void:
	safest_highlighted = value
	update_highlight()


func update_highlight() -> void:
	if is_selected:
		mesh_instance.material_overlay = selection_material
	elif probability_highlighted:
		mesh_instance.material_overlay = probability_material
	elif safest_highlighted:
		mesh_instance.material_overlay = safest_material
	else:
		mesh_instance.material_overlay = null


func modify_difficulty(amount: int) -> void:
	removal_difficulty = clampi(
		removal_difficulty + amount,
		1,
		10
	)
