class_name PRCourse
extends Node3D
## One team's tower. Placed twice in platform_race.tscn (Blue at x = 0, Gold
## at x = 200). Owns the checkpoints, devices, traps and finish gate, tells each
## of them which team it belongs to, and builds the castle back wall.

@export var team := 0
## Camera limits in course-local Y.
@export var bottom_y := -3.0
@export var top_y := 56.0
## Arched windows on the back wall (course-local x, y of the window centre).
@export var windows: PackedVector2Array = PackedVector2Array()

var _checkpoints: Array[PRCheckpoint] = []
var _devices: Array[PRDevice] = []
var _traps: Array[PRTrap] = []
var _gates: Array[PRFinishGate] = []

static var _window_mat: ShaderMaterial


func _ready() -> void:
	_collect(self)
	_checkpoints.sort_custom(func(a: PRCheckpoint, b: PRCheckpoint) -> bool: return a.index < b.index)
	set_team(team)
	_build_backdrop()


func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is PRCheckpoint:
			_checkpoints.append(child)
		elif child is PRDevice:
			_devices.append(child)
		elif child is PRTrap:
			_traps.append(child)
		elif child is PRFinishGate:
			_gates.append(child)
		_collect(child)


func set_team(p_team: int) -> void:
	team = p_team
	for cp in _checkpoints:
		cp.team = team
		cp.refresh()
	for d in _devices:
		d.team = team
		d.course = self
		if d.has_method("refresh_team"):
			d.refresh_team()
	for t in _traps:
		t.team = team
		t.course = self
	for gate in _gates:
		gate.team = team


func get_checkpoints() -> Array[PRCheckpoint]:
	return _checkpoints


func get_checkpoint(index: int) -> PRCheckpoint:
	for cp in _checkpoints:
		if cp.index == index:
			return cp
	return null


func get_start_position() -> Vector3:
	var cp := get_checkpoint(1)
	return cp.global_position if cp else global_position


func get_checkpoint_count() -> int:
	return _checkpoints.size()


## Devices in route order (section 1 → 6, then bottom to top).
func get_devices() -> Array[PRDevice]:
	var list := _devices.duplicate()
	list.sort_custom(func(a: PRDevice, b: PRDevice) -> bool:
		if a.route_index != b.route_index:
			return a.route_index < b.route_index
		return a.get_target_point().y < b.get_target_point().y)
	return list


func get_traps() -> Array[PRTrap]:
	return _traps


## The trap in a section, or null (section 1 has none).
func get_trap(section: int) -> PRTrap:
	for t in _traps:
		if t.section == section:
			return t
	return null


func get_finish_gate() -> PRFinishGate:
	return _gates[0] if not _gates.is_empty() else null


## Course-local [bottom, top] heights of each section, S1 first. A section runs
## from its checkpoint to the next one; S6 runs to the finish gate.
func get_section_bounds() -> Array:
	var out := []
	for i in _checkpoints.size():
		var lo := _checkpoints[i].position.y
		var hi: float
		if i + 1 < _checkpoints.size():
			hi = _checkpoints[i + 1].position.y
		elif not _gates.is_empty():
			hi = _gates[0].position.y
		else:
			hi = lo + 8.0
		out.append([lo, hi])
	return out


## HELP BOOST for this tower's machinery (the trailing team).
func set_boost(on: bool) -> void:
	for d in _devices:
		d.set_boost(on)


func get_center_x() -> float:
	return global_position.x


# --- Back wall -----------------------------------------------------------------------

func _build_backdrop() -> void:
	var back := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(19, top_y - bottom_y + 10, 0.5)
	back.mesh = mesh
	back.position = Vector3(0, (top_y + bottom_y) * 0.5, -3.25)
	var mat := PRBlock.material_for(PRBlock.Look.DARK).duplicate() as StandardMaterial3D
	mat.albedo_color = Color(0.36, 0.33, 0.4).lerp(PRConfig.team_color(team), 0.1)
	mat.uv1_scale = Vector3(0.33, 0.33, 0.33)
	# Shadows on the back wall read as extra platforms, so it doesn't receive any.
	mat.disable_receive_shadows = true
	back.material_override = mat
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(back, false, Node.INTERNAL_MODE_BACK)
	for w in windows:
		_add_window(w)
	# Team banners hang down the back wall on both sides.
	for side in [-1.0, 1.0]:
		var y := 4.0
		while y < top_y - 4.0:
			_add_banner(Vector3(side * 6.2, y, -2.95))
			y += 13.0


func _add_window(at: Vector2) -> void:
	var frame := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(2.0, 3.0, 0.12)
	frame.mesh = fm
	frame.material_override = PRBlock.material_for(PRBlock.Look.TRIM)
	frame.position = Vector3(at.x, at.y, -2.97)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(frame, false, Node.INTERNAL_MODE_BACK)
	var glass := MeshInstance3D.new()
	var gm := QuadMesh.new()
	gm.size = Vector2(1.6, 2.6)
	glass.mesh = gm
	glass.material_override = _window_material()
	glass.position = Vector3(at.x, at.y, -2.9)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass, false, Node.INTERNAL_MODE_BACK)
	# Mullions.
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 2.6, 0.05)
	bar.mesh = bm
	bar.material_override = PRBlock.material_for(PRBlock.Look.IRON)
	bar.position = Vector3(at.x, at.y, -2.86)
	add_child(bar, false, Node.INTERNAL_MODE_BACK)
	var bar2 := bar.duplicate() as MeshInstance3D
	bar2.rotation_degrees.z = 90.0
	bar2.scale = Vector3(1, 0.62, 1)
	add_child(bar2, false, Node.INTERNAL_MODE_BACK)


## A dusk sky seen through a window: orange at the bottom, purple at the top,
## with an arched top cut out of the quad.
static func _window_material() -> ShaderMaterial:
	if _window_mat:
		return _window_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec2 uv = UV;
	// Arched top: a half circle across the full width (quad is 1.6 x 2.6).
	float arch_y = 0.31;
	if (uv.y < arch_y && length(vec2(uv.x - 0.5, (uv.y - arch_y) * 1.625)) > 0.5) {
		discard;
	}
	vec3 top = vec3(0.30, 0.20, 0.45);
	vec3 mid = vec3(0.85, 0.42, 0.38);
	vec3 low = vec3(1.0, 0.68, 0.32);
	float t = uv.y;
	vec3 col = t < 0.55 ? mix(top, mid, t / 0.55) : mix(mid, low, (t - 0.55) / 0.45);
	ALBEDO = col * 1.25;
}
"""
	_window_mat = ShaderMaterial.new()
	_window_mat.shader = sh
	return _window_mat


func _add_banner(at: Vector3) -> void:
	var c := PRConfig.team_color(team)
	var cloth := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.1, 3.2, 0.05)
	cloth.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c.darkened(0.25)
	mat.roughness = 1.0
	cloth.material_override = mat
	cloth.position = at
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloth, false, Node.INTERNAL_MODE_BACK)
	var trim := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.3, 0.12, 0.12)
	trim.mesh = tm
	trim.material_override = PRBlock.material_for(PRBlock.Look.TRIM)
	trim.position = at + Vector3(0, 1.62, 0.05)
	add_child(trim, false, Node.INTERNAL_MODE_BACK)
	var crest := Label3D.new()
	crest.text = "✦"
	crest.font_size = 120
	crest.pixel_size = 0.006
	crest.modulate = PRTheme.GOLD
	crest.outline_size = 0
	crest.position = at + Vector3(0, 0.6, 0.04)
	add_child(crest, false, Node.INTERNAL_MODE_BACK)
