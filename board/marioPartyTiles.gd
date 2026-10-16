class_name BoardNode3D
extends Node3D

enum SpaceType { BLUE, RED, EVENT, STAR, SHOP }
@export var space_type: SpaceType = SpaceType.BLUE
@export var next_nodes: Array[NodePath] = []

# Returns actual Node instances for pathfinding/branching
func get_next_spaces() -> Array[BoardNode3D]:
	var nodes: Array[BoardNode3D] = []
	for path in next_nodes:
		var node = get_node_or_null(path)
		if node is BoardNode3D:
			nodes.append(node)
	return nodes
