@tool
class_name PRCheckpoint
extends Area3D
## A checkpoint. The node's origin is where the Runner respawns, so put it on
## static ground (never on a lift or swap block). The trigger box can be larger
## than the banner, so the checkpoint counts as soon as the Runner enters it.
##
## The banner shows the section number and its stage (✚ HELP white or
## ✕ HINDER red). Its brazier lights up when the Runner reaches it.

@export var index := 1:
	set(value):
		index = value
		_rebuild()
## Trigger size and its offset from the origin.
@export var trigger_size := Vector3(3, 3, 3):
	set(value):
		trigger_size = value
		_rebuild()
@export var trigger_offset := Vector3(0, 1.5, 0):
	set(value):
		trigger_offset = value
		_rebuild()
## Where the banner pole stands, relative to the origin.
@export var flag_offset := Vector3(0, 0, -1.2):
	set(value):
		flag_offset = value
		_rebuild()

var team := 0
var reached := false

var _shape: CollisionShape3D
var _pole: MeshInstance3D
var _cloth: MeshInstance3D
var _cloth_mat: StandardMaterial3D
var _icon: Label3D
var _name: Label3D
var _bowl: MeshInstance3D
var _fire: CPUParticles3D
var _light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	collision_layer = 8 # PRConfig.LAYER_TRIGGERS
	collision_mask = 2 # PRConfig.LAYER_RUNNER
	monitorable = false
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func set_reached(on: bool) -> void:
	reached = on
	if _fire:
		_fire.emitting = on
		_light.visible = on


func refresh() -> void:
	_rebuild()


func _on_body_entered(body: Node3D) -> void:
	var runner := body as PRRunner
	if runner == null or runner.team != team:
		return
	if index > runner.checkpoint_index:
		runner.reach_checkpoint(index, global_position)
		set_reached(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not reached or _light == null:
		return
	_time += delta
	_light.light_energy = 1.6 + 0.35 * sin(_time * 13.0) + 0.2 * sin(_time * 7.3)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		PRBlock.free_stale_internal_children(self)
		_shape = CollisionShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
		_pole = MeshInstance3D.new()
		add_child(_pole, false, Node.INTERNAL_MODE_FRONT)
		_cloth = MeshInstance3D.new()
		add_child(_cloth, false, Node.INTERNAL_MODE_FRONT)
		_icon = Label3D.new()
		add_child(_icon, false, Node.INTERNAL_MODE_FRONT)
		_name = Label3D.new()
		add_child(_name, false, Node.INTERNAL_MODE_FRONT)
		_bowl = MeshInstance3D.new()
		add_child(_bowl, false, Node.INTERNAL_MODE_FRONT)
		_fire = _make_fire()
		add_child(_fire, false, Node.INTERNAL_MODE_FRONT)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.62, 0.3)
		_light.omni_range = 5.5
		_light.light_energy = 1.6
		_light.visible = false
		add_child(_light, false, Node.INTERNAL_MODE_FRONT)

		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.06
		pole_mesh.bottom_radius = 0.08
		pole_mesh.height = 3.0
		_pole.mesh = pole_mesh
		_pole.material_override = PRBlock.material_for(PRBlock.Look.IRON)
		_cloth_mat = StandardMaterial3D.new()
		_cloth_mat.roughness = 1.0
		_cloth_mat.emission_enabled = true
		_cloth.material_override = _cloth_mat
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.38
		bowl.bottom_radius = 0.18
		bowl.height = 0.3
		_bowl.mesh = bowl
		_bowl.material_override = PRBlock.material_for(PRBlock.Look.IRON)
		for l in [_icon, _name]:
			var lab := l as Label3D
			lab.outline_size = 14
			lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			lab.double_sided = false
	var box := BoxShape3D.new()
	box.size = trigger_size
	_shape.shape = box
	_shape.position = trigger_offset

	var stage := PRConfig.stage_for_checkpoint(index)
	var jc := PRConfig.mode_color(stage)
	_pole.position = flag_offset + Vector3(-0.55, 1.5, 0)
	var cm := BoxMesh.new()
	cm.size = Vector3(1.05, 1.35, 0.05)
	_cloth.mesh = cm
	_cloth.position = flag_offset + Vector3(0.0, 2.25, 0)
	_cloth_mat.albedo_color = PRTheme.NAVY_LIGHT if stage == PRConfig.Mode.HELP else jc.darkened(0.35)
	_cloth_mat.emission = jc
	_cloth_mat.emission_energy_multiplier = 0.12
	_icon.text = "%s%d" % [PRConfig.mode_icon(stage), index]
	_icon.font = PRTheme.display_font()
	_icon.font_size = 84
	_icon.pixel_size = 0.0055
	_icon.modulate = Color.WHITE
	_icon.position = flag_offset + Vector3(0.0, 2.45, 0.04)
	_name.text = PRConfig.mode_name(stage)
	_name.font = PRTheme.body_font(900)
	_name.font_size = 44
	_name.pixel_size = 0.0055
	_name.modulate = jc
	_name.position = flag_offset + Vector3(0.0, 1.88, 0.04)
	_bowl.position = flag_offset + Vector3(0.45, 0.15, 0.2)
	_fire.position = _bowl.position + Vector3(0, 0.2, 0)
	_light.position = _bowl.position + Vector3(0, 0.8, 0.6)
	set_reached(reached)


func _make_fire() -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.emitting = false
	f.amount = 24
	f.lifetime = 0.6
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 0.18
	f.direction = Vector3(0, 1, 0)
	f.spread = 15.0
	f.gravity = Vector3(0, 1.5, 0)
	f.initial_velocity_min = 0.5
	f.initial_velocity_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	f.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.45, 1.0))
	grad.set_color(1, Color(0.95, 0.25, 0.05, 0.0))
	f.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	quad.material = m
	f.mesh = quad
	return f
