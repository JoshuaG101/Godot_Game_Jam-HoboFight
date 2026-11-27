class_name ArtilleryStrike
extends Node3D

# Set by the ability that creates the strike (before it enters the scene)
var radius: float = 3.5
var delay: float = 1.5
var knockback_strength: float = 24.0

var time_left: float = 0.0
var warning_mesh: MeshInstance3D
var warning_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("hazards")   # the match manager freezes hazards when the match ends
	time_left = delay

	# A flat red disc on the ground that shows where the shells will land
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04

	warning_material = StandardMaterial3D.new()
	warning_material.albedo_color = Color(1.0, 0.1, 0.05, 0.35)
	warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	warning_mesh = MeshInstance3D.new()
	warning_mesh.mesh = disc
	warning_mesh.material_override = warning_material
	add_child(warning_mesh)


# HOST DECIDES (online: only the host decides when the shells land)
func _physics_process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		_land()
		return

	# The disc pulses faster as the impact gets closer
	var urgency := 1.0 - time_left / delay
	var pulse := 0.5 + 0.5 * sin(urgency * urgency * 40.0)
	warning_material.albedo_color.a = 0.2 + 0.3 * pulse


func _land() -> void:
	set_physics_process(false)
	remove_from_group("hazards")   # let the flash finish even if the match ends right now

	# Launch everyone inside the blast, outward from the center (this includes the caster)
	for target in get_tree().get_nodes_in_group("players"):
		var offset: Vector3 = target.global_position - global_position
		if absf(offset.y) > 3.0:
			continue   # already falling away, or far above
		offset.y = 0.0
		if offset.length() > radius:
			continue
		if offset.length() < 0.01:
			offset = Vector3.RIGHT   # dead center: any direction will do
		target.receive_unblockable_hit(offset, knockback_strength)

	# Flash: a bright orange ball swells and fades, then the strike removes itself
	warning_mesh.visible = false

	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0

	var ball_material := StandardMaterial3D.new()
	ball_material.albedo_color = Color(1.0, 0.55, 0.1, 0.8)
	ball_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var blast := MeshInstance3D.new()
	blast.mesh = ball
	blast.material_override = ball_material
	blast.scale = Vector3.ONE * 0.2
	add_child(blast)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(blast, "scale", Vector3.ONE, 0.25)
	tween.tween_property(ball_material, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)
