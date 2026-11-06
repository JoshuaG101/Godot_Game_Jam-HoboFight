class_name BoardNode3D
extends Node3D

enum SpaceType { BLUE, RED, EVENT, STAR, SHOP }
@export var space_type: SpaceType = SpaceType.BLUE
@export var next_nodes: Array[NodePath] = []

var star_marker: Node3D = null

func _ready() -> void:
	apply_space_visuals()

func apply_space_visuals() -> void:
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst:
		var mat = StandardMaterial3D.new()
		match space_type:
			SpaceType.BLUE:
				mat.albedo_color = Color(0.18, 0.52, 0.95) # Royal Blue
				mat.roughness = 0.4
			SpaceType.RED:
				mat.albedo_color = Color(0.92, 0.22, 0.22) # Crimson Red
				mat.roughness = 0.4
			SpaceType.EVENT:
				mat.albedo_color = Color(0.15, 0.82, 0.38) # Emerald Green
				mat.roughness = 0.4
			SpaceType.STAR:
				mat.albedo_color = Color(1.0, 0.85, 0.15) # Shimmering Gold
				mat.metallic = 0.6
				mat.roughness = 0.2
				mat.emission_enabled = true
				mat.emission = Color(0.35, 0.28, 0.05)
			SpaceType.SHOP:
				mat.albedo_color = Color(0.68, 0.25, 0.85) # Purple
				mat.roughness = 0.4

		mesh_inst.material_override = mat

	# Add floating 3D text/symbol indicator above tile
	var label = get_node_or_null("TileLabel") as Label3D
	if not label:
		label = Label3D.new()
		label.name = "TileLabel"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.008
		label.position = Vector3(0, 0.35, 0)
		label.font_size = 36
		label.outline_size = 8
		label.outline_modulate = Color(0, 0, 0, 0.8)
		add_child(label)

	match space_type:
		SpaceType.BLUE:
			label.text = "+3"
			label.modulate = Color(0.8, 0.95, 1.0)
		SpaceType.RED:
			label.text = "-3"
			label.modulate = Color(1.0, 0.8, 0.8)
		SpaceType.EVENT:
			label.text = "?"
			label.modulate = Color(0.8, 1.0, 0.8)
		SpaceType.STAR:
			label.text = "★"
			label.modulate = Color(1.0, 0.95, 0.3)
			label.font_size = 48
			spawn_star_trophy()
		SpaceType.SHOP:
			label.text = "SHOP"
			label.modulate = Color(0.9, 0.7, 1.0)

func spawn_star_trophy() -> void:
	if star_marker:
		return
	star_marker = Node3D.new()
	star_marker.name = "StarTrophy"
	star_marker.position = Vector3(0, 1.2, 0)
	
	var mesh_inst = MeshInstance3D.new()
	var prism = PrismMesh.new()
	prism.size = Vector3(0.5, 0.5, 0.3)
	mesh_inst.mesh = prism
	
	var star_mat = StandardMaterial3D.new()
	star_mat.albedo_color = Color(1.0, 0.88, 0.1)
	star_mat.metallic = 0.8
	star_mat.roughness = 0.2
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.5, 0.4, 0.05)
	mesh_inst.material_override = star_mat
	
	star_marker.add_child(mesh_inst)
	add_child(star_marker)

func _process(delta: float) -> void:
	if star_marker:
		star_marker.rotate_y(delta * 2.0)
		star_marker.position.y = 1.2 + sin(Time.get_ticks_msec() * 0.003) * 0.15

func pulse() -> void:
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)

# Returns actual Node instances for pathfinding/branching
func get_next_spaces() -> Array[BoardNode3D]:
	var nodes: Array[BoardNode3D] = []
	for path in next_nodes:
		var node = get_node_or_null(path)
		if node is BoardNode3D:
			nodes.append(node)
	return nodes
