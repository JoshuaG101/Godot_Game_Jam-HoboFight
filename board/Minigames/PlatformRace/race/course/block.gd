@tool
class_name PRBlock
extends StaticBody3D
## Static course geometry. Set `size` in the inspector (Front view) and the mesh
## and collision box follow. The node's origin is the centre of the box.
##
## Looks are castle placeholders with generated textures (stone, brick, wood).
## Walkable stone gets a lighter capstone on top so players can read where to
## stand; brick means "you can wall jump here".

enum Look { AUTO, STONE, BRICK, DARK, TRIM, STANDIN, WOOD, IRON }

@export var size := Vector3(2, 1, 3):
	set(value):
		size = value.max(Vector3(0.05, 0.05, 0.05))
		_rebuild()
## Runners can wall jump off this block. Only chimney walls should allow it;
## AUTO look shows these as brick so players can read them.
@export var allow_wall_jump := false:
	set(value):
		allow_wall_jump = value
		_rebuild()
@export var look := Look.AUTO:
	set(value):
		look = value
		_rebuild()
## Turn off for decoration that should not collide.
@export var solid := true:
	set(value):
		solid = value
		_rebuild()
## Lighter capstone on top of walkable stone. AUTO-off for tall walls.
@export var cap := true:
	set(value):
		cap = value
		_rebuild()

const TINTS := {
	Look.STONE: Color(0.78, 0.78, 0.84),
	Look.BRICK: Color(1.0, 1.0, 1.0),
	Look.DARK: Color(0.42, 0.4, 0.46),
	Look.TRIM: Color(0.95, 0.85, 0.62),
	Look.STANDIN: Color(0.85, 0.35, 0.85),
	Look.WOOD: Color(1.0, 1.0, 1.0),
	Look.IRON: Color(0.35, 0.36, 0.4),
}
const CAP_COLOR := Color(0.86, 0.78, 0.62)

static var _materials := {}
static var _textures := {}
static var _cap_material: StandardMaterial3D

var _mesh: MeshInstance3D
var _cap: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 1 # PRConfig.LAYER_WORLD
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree() and _mesh == null:
		return
	if _mesh == null:
		PRBlock.free_stale_internal_children(self)
		_mesh = MeshInstance3D.new()
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
		_cap = MeshInstance3D.new()
		_cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_cap, false, Node.INTERNAL_MODE_FRONT)
		_shape = CollisionShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var box := BoxMesh.new()
	box.size = size
	_mesh.mesh = box
	var which := _resolved_look()
	_mesh.material_override = material_for(which)
	var shape := BoxShape3D.new()
	shape.size = size
	_shape.shape = shape
	_shape.disabled = not solid
	var show_cap := cap and solid and which == Look.STONE and size.y <= 1.6 and size.x >= 0.9
	_cap.visible = show_cap
	if show_cap:
		var cm := BoxMesh.new()
		cm.size = Vector3(size.x + 0.06, 0.16, size.z + 0.06)
		_cap.mesh = cm
		_cap.position = Vector3(0, size.y * 0.5 - 0.06, 0)
		_cap.material_override = _cap_mat()


func _resolved_look() -> Look:
	if look != Look.AUTO:
		return look
	return Look.BRICK if allow_wall_jump else Look.STONE


## The editor re-creates a @tool script's instance when the script is saved,
## which resets cached child references (_mesh, _shape...) while the generated
## internal children stay in the tree. Call this before re-creating them so
## they are not duplicated on every save. Editor only: at runtime, subclasses
## may already have added their own internal children in _ready().
static func free_stale_internal_children(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var regular := node.get_children()
	for c in node.get_children(true):
		if not regular.has(c):
			node.remove_child(c)
			c.free()


static func material_for(which: Look) -> StandardMaterial3D:
	if _materials.has(which):
		return _materials[which]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TINTS.get(which, Color.GRAY)
	mat.roughness = 0.92
	if which == Look.STANDIN:
		mat.albedo_color.a = 0.85
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elif which != Look.TRIM and which != Look.IRON:
		mat.albedo_texture = get_texture(which)
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if which == Look.IRON:
		mat.metallic = 0.7
		mat.roughness = 0.45
	_materials[which] = mat
	return mat


static func _cap_mat() -> StandardMaterial3D:
	if _cap_material == null:
		_cap_material = StandardMaterial3D.new()
		_cap_material.albedo_color = CAP_COLOR
		_cap_material.albedo_texture = get_texture(Look.STONE)
		_cap_material.uv1_triplanar = true
		_cap_material.uv1_world_triplanar = true
		_cap_material.uv1_scale = Vector3(1.0, 1.0, 1.0)
		_cap_material.roughness = 0.8
	return _cap_material


## Generated placeholder textures (128 × 128, tiling). Stone and dark stone are
## big blocks, brick is small red bricks, wood is planks.
static func get_texture(which: Look) -> Texture2D:
	if which == Look.DARK:
		which = Look.STONE
	if _textures.has(which):
		return _textures[which]
	var img := Image.create(128, 128, true, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + int(which)
	match which:
		Look.BRICK:
			_masonry(img, rng, 32, 16, Color(0.72, 0.4, 0.3), Color(0.78, 0.74, 0.66), 0.12)
		Look.WOOD:
			_planks(img, rng)
		_:
			_masonry(img, rng, 64, 32, Color(0.66, 0.66, 0.7), Color(0.36, 0.35, 0.38), 0.08)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[which] = tex
	return tex


static func _masonry(img: Image, rng: RandomNumberGenerator, bw: int, bh: int, base: Color, mortar: Color, vary: float) -> void:
	@warning_ignore("integer_division")
	var rows := 128 / bh
	@warning_ignore("integer_division")
	var cols := 128 / bw
	var shade := {}
	for r in rows:
		for c in cols + 1:
			shade[Vector2i(r, c)] = rng.randf_range(1.0 - vary, 1.0 + vary)
	for y in 128:
		@warning_ignore("integer_division")
		var r := y / bh
		@warning_ignore("integer_division")
		var off := (bw / 2) if r % 2 == 1 else 0
		for x in 128:
			var xx := (x + off) % 128
			@warning_ignore("integer_division")
			var c := xx / bw
			var in_mortar := (y % bh) < 2 or (xx % bw) < 2
			var col: Color
			if in_mortar:
				col = mortar
			else:
				var s: float = shade[Vector2i(r, c)]
				var n := rng.randf_range(-0.035, 0.035)
				# A soft bevel: lighter top edge, darker bottom edge of each block.
				var edge := 0.0
				if (y % bh) < 4:
					edge = 0.06
				elif (y % bh) > bh - 4:
					edge = -0.07
				col = Color(base.r * s + n + edge, base.g * s + n + edge, base.b * s + n + edge)
			img.set_pixel(x, y, col)


static func _planks(img: Image, rng: RandomNumberGenerator) -> void:
	var ph := 16
	var base := Color(0.55, 0.36, 0.22)
	var shade := []
	@warning_ignore("integer_division")
	for i in 128 / ph:
		shade.append(rng.randf_range(0.85, 1.12))
	for y in 128:
		@warning_ignore("integer_division")
		var p := y / ph
		for x in 128:
			var seam := (y % ph) < 1 or ((x + p * 37) % 128) < 1
			var grain := 0.05 * sin(float(x) * 0.15 + float(y % ph) * 0.9 + p * 2.0)
			var n := rng.randf_range(-0.03, 0.03)
			var s: float = shade[p]
			var col := Color(base.r * s + grain + n, base.g * s + grain * 0.7 + n, base.b * s + grain * 0.5 + n)
			if seam:
				col = col.darkened(0.55)
			img.set_pixel(x, y, col)
