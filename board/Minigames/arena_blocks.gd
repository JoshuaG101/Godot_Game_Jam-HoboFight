

extends Node3D

func _ready() -> void:
	pass


func warn_block(block_name: String) -> void:
	var block = get_node_or_null(block_name)

	if block == null:
		return

	var mesh = block.get_node("BlockMesh")

	var warning_material = StandardMaterial3D.new()
	warning_material.albedo_color = Color.RED

	mesh.material_override = warning_material

	print("Warning: ", block_name)

	await get_tree().create_timer(2.0).timeout


func collapse_block(block_name: String) -> void:
	var block = get_node_or_null(block_name)

	if block != null:
		block.queue_free()
		print("Block collapsed: ", block_name)


func get_random_block() -> String:
	var available_blocks = []

	for block in get_children():
		if block is StaticBody3D:
			available_blocks.append(block.name)

	if available_blocks.is_empty():
		return ""

	return available_blocks.pick_random()
