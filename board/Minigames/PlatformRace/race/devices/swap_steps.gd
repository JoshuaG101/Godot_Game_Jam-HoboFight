@tool
class_name PRSwapSteps
extends PRDevice
## A set of rune stones in two sets, ◆ violet and ● lime (PRSwapBlock children).
## Only one set is solid at a time. The owning Buddy presses Action to switch.

## The set that is solid when the race starts (0 = violet, 1 = lime).
@export_range(0, 1) var start_set := 0

var solid_set := 0

var _blocks: Array[PRSwapBlock] = []


func _ready() -> void:
	super._ready()
	solid_set = start_set
	for c in get_children():
		if c is PRSwapBlock:
			_blocks.append(c)
	if Engine.is_editor_hint():
		return
	for b in _blocks:
		b.set_wanted(b.set_id == solid_set, true)
		var mesh := b.get_child(0, true) as MeshInstance3D
		if mesh:
			register_mesh(mesh)


func get_target_point() -> Vector3:
	if _blocks.is_empty():
		return global_position + target_offset
	var sum := Vector3.ZERO
	for b in _blocks:
		sum += b.global_position
	return sum / _blocks.size() + Vector3(0, 0.5, 0)


func press(_buddy_team: int) -> String:
	solid_set = 1 - solid_set
	for b in _blocks:
		b.set_wanted(b.set_id == solid_set)
	PRSfx.emit(self, "switch", -2.0, 0.04)
	changed.emit(self)
	return ""


func get_prompt_3d(key: String) -> String:
	return "SWITCH %s" % key


func get_blocks() -> Array[PRSwapBlock]:
	return _blocks
