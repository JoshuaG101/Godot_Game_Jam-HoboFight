@tool
class_name PRDevice
extends Node3D
## Base class for the machinery a Buddy works in HELP mode: Lifts, Rune Steps
## and Drawbridges. Handles the "picked by your Buddy" glow (team colour), the
## floating key prompt and the help text. Subclasses implement press() / hold()
## and their own visuals.

## Emitted by subclasses (Drawbridge, Swap Steps) when their state flips.
@warning_ignore("unused_signal")
signal changed(device: PRDevice)

@export var display_name := "Device"
## The section (1–6) this device belongs to. A Buddy only works devices in
## their own Runner's current section.
@export_range(1, 6) var route_index := 1
## False for machinery that runs by itself (moving platforms).
@export var targetable := true
## Where the key prompt floats, relative to the device origin.
@export var target_offset := Vector3(0, 1, 0)

## Team that owns this device (set by PRCourse).
var team := 0
var course: Node3D
## HELP BOOST for the trailing team (set by PRCourse.set_boost).
var boosted := false

var _worked := false
var _key := ""
## More than one machine to pick from: the prompt shows ◀ ▶.
var _can_cycle := false
var _overlay: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _prompt: Label3D
var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	_prompt = Label3D.new()
	_prompt.font = PRTheme.display_font()
	_prompt.font_size = 56
	_prompt.pixel_size = 0.0075
	_prompt.outline_size = 14
	_prompt.outline_modulate = PRTheme.INK
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.render_priority = 5
	_prompt.visible = false
	add_child(_prompt, false, Node.INTERNAL_MODE_BACK)


# --- Called by the Buddy --------------------------------------------------------------

## The point the prompt floats over.
func get_target_point() -> Vector3:
	return global_position + target_offset


## How far this machine is from `from`, for picking the one nearest the Runner.
func distance_hint(from: Vector3) -> float:
	return get_target_point().distance_to(from)


## Action pressed. Returns a short rejection message, or "" if it worked.
func press(_buddy_team: int) -> String:
	return ""


## Action held this physics frame.
func hold(_buddy_team: int) -> void:
	pass


## Short text floating over the device, e.g. "HOLD S".
func get_prompt_3d(key: String) -> String:
	return key


## Turns the "your Buddy picked this" glow and prompt on or off.
func set_worked(on: bool, key := "", can_cycle := false) -> void:
	_worked = on
	_key = key
	_can_cycle = can_cycle
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = _overlay if on else null
	if _prompt:
		_prompt.visible = on


func is_worked() -> bool:
	return _worked


func set_boost(on: bool) -> void:
	boosted = on


# --- Helpers for subclasses ----------------------------------------------------------

func register_mesh(mesh: MeshInstance3D) -> void:
	_meshes.append(mesh)
	if _overlay and _worked:
		mesh.material_overlay = _overlay


static func make_material(color: Color, metallic := 0.2, roughness := 0.6) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if not _worked:
		return
	var c := PRConfig.team_color(team)
	c.a = 0.18 + 0.16 * (0.5 + 0.5 * sin(_time * TAU * 1.6))
	_overlay.albedo_color = c
	var text := get_prompt_3d(_key)
	_prompt.text = "◀ %s ▶" % text if _can_cycle else text
	_prompt.modulate = PRConfig.team_color(team).lightened(0.35)
	_prompt.global_position = get_target_point() + Vector3(0, 1.3 + 0.12 * sin(_time * 4.0), 1.6)
