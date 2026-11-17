class_name PRBurst
extends MeshInstance3D
## A quick expanding ring that shows the reach of an area effect (Blessing) or a
## power going off. Frees itself.

const DURATION := 0.45

var _radius := 1.0
var _t := 0.0
var _mat: StandardMaterial3D


func setup(at: Vector3, radius: float, color: Color) -> void:
	_radius = radius
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	mesh = torus
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = color
	_mat.no_depth_test = true
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	global_position = at + Vector3(0, 0.3, 0.6)
	rotation_degrees.x = 80.0
	scale = Vector3.ONE * 0.2


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var s := lerpf(0.2, _radius, 1.0 - pow(1.0 - k, 3.0))
	scale = Vector3(s, 1.0, s)
	_mat.albedo_color.a = 1.0 - k
	if k >= 1.0:
		queue_free()
