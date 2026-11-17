@tool
class_name PRTorch
extends Node3D
## A wall torch: the fantasy pack's metal torch, a small flame and a warm,
## flickering light. Decoration only. Place it against the back wall.

const MODEL := preload("res://Minigames/PlatformRace/assets/fantasy_assets/Exports/glTF/Torch_Metal.gltf")

@export var light_range := 6.0
@export var energy := 1.4

var _light: OmniLight3D
var _time := 0.0
var _seed := 0.0


func _ready() -> void:
	var model := MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * 1.8
	add_child(model, false, Node.INTERNAL_MODE_FRONT)
	var flame := CPUParticles3D.new()
	flame.amount = 16
	flame.lifetime = 0.45
	flame.position = Vector3(0, 0.72, 0.55)
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.08
	flame.direction = Vector3(0, 1, 0)
	flame.spread = 12.0
	flame.gravity = Vector3(0, 1.0, 0)
	flame.initial_velocity_min = 0.4
	flame.initial_velocity_max = 0.8
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	flame.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	grad.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	flame.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	quad.material = m
	flame.mesh = quad
	add_child(flame, false, Node.INTERNAL_MODE_FRONT)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.28)
	_light.omni_range = light_range
	_light.light_energy = energy
	_light.omni_attenuation = 1.3
	_light.position = Vector3(0, 0.9, 0.9)
	add_child(_light, false, Node.INTERNAL_MODE_FRONT)
	_seed = randf() * 10.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_light.light_energy = energy * (1.0 + 0.12 * sin(_time * 11.0 + _seed) + 0.08 * sin(_time * 23.0 + _seed * 2.0))
