class_name PRPaintZone
extends Node3D
## A puddle of paint left by an Art Buddy's Paint Bomb. While the Runner stands
## in it they run slower and jump lower. It fades away after PAINT_TIME.

const COLORS: Array[Color] = [Color("#46C2FF"), Color("#F5B940"), Color("#FF3B55")]

var target: PRRunner
var _time_left := PRMajors.PAINT_TIME
var _mat: StandardMaterial3D


func setup(p_target: PRRunner, world_x: float, ground_y: float) -> void:
	target = p_target
	global_position = Vector3(world_x, ground_y, 0)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLORS[randi() % COLORS.size()]
	_mat.roughness = 0.25
	_mat.metallic_specular = 0.8
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# A few overlapping flat blobs read as a splash.
	for i in 4:
		var blob := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.height = 0.04
		var r := PRMajors.PAINT_WIDTH * (0.25 if i == 0 else 0.16)
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.radial_segments = 14
		blob.mesh = cyl
		blob.material_override = _mat
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var spread := PRMajors.PAINT_WIDTH * 0.32
		blob.position = Vector3(0.0 if i == 0 else randf_range(-spread, spread), 0.03 + i * 0.004, randf_range(-0.6, 0.6))
		blob.scale = Vector3(1.6, 1, 1.0) if i == 0 else Vector3.ONE
		add_child(blob)
	PRSfx.emit(self, "crumble", -6.0, 0.2)


## True while `runner` stands in the paint.
func covers(runner: PRRunner) -> bool:
	var p := runner.global_position - global_position
	return absf(p.x) <= PRMajors.PAINT_WIDTH * 0.5 + 0.3 and p.y > -0.4 and p.y < 0.8


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if target and covers(target):
		target.apply_paint()
	_mat.albedo_color.a = clampf(_time_left / 0.6, 0.0, 0.9)
	if _time_left <= 0.0:
		queue_free()
