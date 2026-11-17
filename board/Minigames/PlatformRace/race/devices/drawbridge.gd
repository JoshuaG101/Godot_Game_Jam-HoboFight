@tool
class_name PRDrawbridge
extends PRDevice
## A wooden bridge that slides out of the back wall (along Z) over a pit.
## The node's origin is the TOP-CENTRE of the bridge when it is out.
##
## Press Action: it slides out (0.4 s), stays out 4 s (6 s with HELP BOOST),
## blinks for its last second, slides back in, then has a 2 s cooldown (none
## with HELP BOOST). It only turns solid once fully out and nobody overlaps it,
## so it can never appear inside a Runner.

enum Phase { IN, SLIDING_OUT, OUT, SLIDING_IN, COOLDOWN }

@export var length := 4.5:
	set(value):
		length = value
		_rebuild()
@export var thickness := 0.4:
	set(value):
		thickness = value
		_rebuild()
@export var depth := 3.0:
	set(value):
		depth = value
		_rebuild()

var phase := Phase.IN
## 0 = hidden in the back wall, 1 = fully out.
var slide := 0.0
var time_left := 0.0
var is_solid := false

var _body: StaticBody3D
var _shape: CollisionShape3D
var _plank: Node3D
var _deck: MeshInstance3D
var _bands: Array[MeshInstance3D] = []
var _slot: MeshInstance3D
var _warned := false
var _blink := 0.0

static var _wood: StandardMaterial3D
static var _iron: StandardMaterial3D


func _ready() -> void:
	super._ready()
	_rebuild()
	if not Engine.is_editor_hint():
		register_mesh(_deck)
		slide = 0.0
		_place()


func get_target_point() -> Vector3:
	return global_position + Vector3(0, 0.4, 0)


func press(_buddy_team: int) -> String:
	match phase:
		Phase.IN:
			phase = Phase.SLIDING_OUT
			_warned = false
			PRSfx.emit(self, "bridge", 0.0, 0.05)
			changed.emit(self)
			return ""
		Phase.SLIDING_OUT, Phase.OUT:
			return "ALREADY OUT"
		Phase.SLIDING_IN:
			return "RETRACTING"
		Phase.COOLDOWN:
			return "COOLDOWN %.1fs" % time_left
	return ""


func get_prompt_3d(key: String) -> String:
	match phase:
		Phase.IN:
			return "PRESS %s" % key
		Phase.SLIDING_OUT, Phase.OUT:
			return "%.0f" % ceilf(_out_left())
	return "…"


func _out_left() -> float:
	if phase == Phase.SLIDING_OUT:
		return _hold_time()
	return maxf(time_left, 0.0)


func _hold_time() -> float:
	return PRConfig.BRIDGE_HOLD_BOOSTED if boosted else PRConfig.BRIDGE_HOLD


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match phase:
		Phase.SLIDING_OUT:
			slide = minf(slide + delta / PRConfig.BRIDGE_SLIDE, 1.0)
			if slide >= 1.0:
				phase = Phase.OUT
				time_left = _hold_time()
		Phase.OUT:
			time_left -= delta
			if not is_solid and not _runner_inside():
				is_solid = true
			if time_left <= PRConfig.BRIDGE_WARN and not _warned:
				_warned = true
				PRSfx.emit(self, "bridge", -4.0, 0.0)
			if time_left <= 0.0:
				phase = Phase.SLIDING_IN
				is_solid = false
		Phase.SLIDING_IN:
			slide = maxf(slide - delta / PRConfig.BRIDGE_SLIDE, 0.0)
			if slide <= 0.0:
				var cd := 0.0 if boosted else PRConfig.BRIDGE_COOLDOWN
				if cd > 0.0:
					phase = Phase.COOLDOWN
					time_left = cd
				else:
					phase = Phase.IN
		Phase.COOLDOWN:
			time_left -= delta
			if time_left <= 0.0:
				phase = Phase.IN
	if phase != Phase.OUT:
		is_solid = false
	_body.collision_layer = PRConfig.LAYER_WORLD if is_solid else 0
	# Blink during the last second, and while waiting for a Runner to move.
	_blink += delta
	var vis := true
	if phase == Phase.OUT and (time_left <= PRConfig.BRIDGE_WARN or not is_solid):
		vis = fmod(_blink, 0.2) < 0.13
	_plank.visible = vis or slide < 1.0
	_place()


func _runner_inside() -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, thickness, depth) * 0.98
	params.shape = shape
	params.transform = _body.global_transform
	params.collision_mask = PRConfig.LAYER_RUNNER
	return not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## Slides the plank: fully out sits at z = 0, fully in hides behind the back wall.
func _place() -> void:
	if _plank == null:
		return
	var hidden_z := -(depth + 1.6)
	# Shown fully out in the editor so the level is easy to lay out.
	var s := 1.0 if Engine.is_editor_hint() else slide
	_plank.position = Vector3(0, -thickness * 0.5, lerpf(hidden_z, 0.0, ease(s, 0.6)))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _body == null:
		PRBlock.free_stale_internal_children(self)
		_body = StaticBody3D.new()
		_body.collision_layer = 0
		_body.collision_mask = 0
		add_child(_body, false, Node.INTERNAL_MODE_FRONT)
		_shape = CollisionShape3D.new()
		_body.add_child(_shape)
		_plank = Node3D.new()
		add_child(_plank, false, Node.INTERNAL_MODE_FRONT)
		_deck = MeshInstance3D.new()
		_plank.add_child(_deck)
		for i in 3:
			var band := MeshInstance3D.new()
			_plank.add_child(band)
			_bands.append(band)
		_slot = MeshInstance3D.new()
		add_child(_slot, false, Node.INTERNAL_MODE_FRONT)
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.albedo_texture = PRBlock.get_texture(PRBlock.Look.WOOD)
		_wood.uv1_triplanar = true
		_wood.uv1_scale = Vector3(0.6, 0.6, 0.6)
		_wood.roughness = 0.85
		_iron = PRDevice.make_material(Color(0.22, 0.22, 0.25), 0.7, 0.4)
	var box := BoxShape3D.new()
	box.size = Vector3(length, thickness, depth)
	_shape.shape = box
	_body.position = Vector3(0, -thickness * 0.5, 0)
	var deck := BoxMesh.new()
	deck.size = Vector3(length, thickness, depth)
	_deck.mesh = deck
	_deck.material_override = _wood
	for i in _bands.size():
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, thickness + 0.06, depth + 0.04)
		_bands[i].mesh = bm
		_bands[i].material_override = _iron
		_bands[i].position = Vector3(lerpf(-length * 0.5 + 0.3, length * 0.5 - 0.3, i / 2.0), 0, 0)
	# A dark slot in the back wall where the bridge comes out.
	var sm := BoxMesh.new()
	sm.size = Vector3(length + 0.3, thickness + 0.3, 0.1)
	_slot.mesh = sm
	_slot.material_override = PRDevice.make_material(Color(0.03, 0.02, 0.02), 0.0, 1.0)
	_slot.position = Vector3(0, -thickness * 0.5, -2.95)
	_place()
