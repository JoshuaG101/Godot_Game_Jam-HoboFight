class_name PRDropper
extends Node3D
## A hindering Buddy's barrel dropper. A marker slides along the top of the
## ENEMY Runner's view; a dashed guide and a ring show where a barrel would land.
## drop() releases a PRBarrel there. When the Buddy's power is armed the marker
## shows their major's icon.

var buddy: PRBuddy
var course: PRCourse
var target: PRRunner
var camera: PRRaceCamera
var team := 0
## Course-local x of the marker.
var marker_x := 0.0
var shown := false
var land_y := 0.0

var _marker: Node3D
var _arrow: MeshInstance3D
var _icon: Label3D
var _guide: MeshInstance3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _time := 0.0


func setup(p_buddy: PRBuddy, p_team: int, enemy_course: PRCourse, enemy_runner: PRRunner, enemy_camera: PRRaceCamera) -> void:
	buddy = p_buddy
	team = p_team
	course = enemy_course
	target = enemy_runner
	camera = enemy_camera
	top_level = true
	if _marker == null:
		_build()
	reset_marker()


func reset_marker() -> void:
	if target and course:
		marker_x = clampf(target.global_position.x - course.global_position.x, -PRConfig.DROP_MARKER_LIMIT, PRConfig.DROP_MARKER_LIMIT)


func move_marker(dx: float) -> void:
	marker_x = clampf(marker_x + dx, -PRConfig.DROP_MARKER_LIMIT, PRConfig.DROP_MARKER_LIMIT)


## World y just inside the top of the enemy view.
func top_y() -> float:
	return camera.global_position.y + camera.get_half_height() - 1.0


## Drops a barrel. `special` is the Buddy's major for a power barrel, or -1.
func drop(special := -1) -> PRBarrel:
	var b := PRBarrel.new()
	course.add_child(b)
	b.setup(self, course.global_position.x + marker_x, top_y() + 1.2, land_y, target, special)
	PRSfx.emit(self, "drop", -3.0, 0.06)
	return b


## Called by a barrel that hit the Runner.
func on_hit() -> void:
	if buddy:
		buddy.on_barrel_hit()


func _physics_process(delta: float) -> void:
	_time += delta
	visible = shown
	if not shown or camera == null:
		return
	var x := course.global_position.x + marker_x
	var ty := top_y()
	land_y = PRBarrel.ground_below(get_world_3d(), x, ty)
	_marker.global_position = Vector3(x, ty, 1.7)
	_arrow.position.y = -0.55 + 0.1 * sin(_time * 6.0)
	var armed := buddy != null and buddy.power_armed
	_icon.text = PRMajors.icon(buddy.major) if armed else "✕"
	_icon.modulate = PRTheme.GOLD if armed else PRConfig.team_color(team).lightened(0.35)
	var guide_len := maxf(ty - land_y - 0.6, 0.1)
	(_guide.mesh as BoxMesh).size = Vector3(0.06, guide_len, 0.06)
	_guide.global_position = Vector3(x, land_y + 0.3 + guide_len * 0.5, 1.6)
	_ring.global_position = Vector3(x, land_y + 0.35, 0.9)
	_ring_mat.albedo_color.a = 0.35 + 0.15 * sin(_time * 5.0)


func _build() -> void:
	var c := PRConfig.team_color(team)
	_marker = Node3D.new()
	add_child(_marker)
	_icon = Label3D.new()
	_icon.text = "✕"
	_icon.font = PRTheme.display_font()
	_icon.font_size = 96
	_icon.pixel_size = 0.007
	_icon.outline_size = 18
	_icon.outline_modulate = PRTheme.INK
	_icon.modulate = c.lightened(0.35)
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.render_priority = 6
	_marker.add_child(_icon)
	_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.32
	cone.bottom_radius = 0.0
	cone.height = 0.5
	_arrow.mesh = cone
	var am := PRTrap.glow_material(c, 1.5)
	am.no_depth_test = true
	_arrow.material_override = am
	_marker.add_child(_arrow)

	_guide = MeshInstance3D.new()
	_guide.mesh = BoxMesh.new()
	_guide.top_level = true
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(c.r, c.g, c.b, 0.35)
	_guide.material_override = gm
	_guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_guide)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.75
	torus.rings = 24
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.top_level = true
	# Tilted toward the camera so it reads as a ring, not a line.
	_ring.rotation_degrees.x = 65.0
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(c.r, c.g, c.b, 0.4)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
