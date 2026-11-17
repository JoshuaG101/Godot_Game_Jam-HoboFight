@tool
class_name PRTrap
extends Node3D
## Base class for the traps a hindering Buddy springs on the enemy tower:
## crumbling stone, wind gust and wall spikes. One trap per section (S1 has none).
##
## Lifecycle: IDLE → WARNING (0.8 s: glow, "!", sound) → ACTIVE → RESETTING → IDLE.
## The warning is always shown, so a Runner can see it coming.

signal warned(trap: PRTrap)
signal fired(trap: PRTrap)

enum Phase { IDLE, WARNING, ACTIVE, RESETTING }

@export var display_name := "Trap"
## The section (1–6) this trap belongs to. It fires when the enemy Runner is there.
@export_range(1, 6) var section := 2

## The team whose tower this is (the victim). Set by PRCourse.
var team := 0
var course: Node3D
var phase := Phase.IDLE
## The team that sprang it.
var attacker := -1

var _t := 0.0
var _time := 0.0
var _warn_label: Label3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_warn_label = Label3D.new()
	_warn_label.text = "!"
	_warn_label.font = PRTheme.display_font()
	_warn_label.font_size = 160
	_warn_label.pixel_size = 0.008
	_warn_label.outline_size = 24
	_warn_label.modulate = PRConfig.HINDER_COLOR.lightened(0.2)
	_warn_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_warn_label.no_depth_test = true
	_warn_label.render_priority = 6
	_warn_label.visible = false
	add_child(_warn_label, false, Node.INTERNAL_MODE_BACK)


func is_busy() -> bool:
	return phase != Phase.IDLE


## Springs the trap. Returns false if it is already busy.
func fire(attacker_team: int) -> bool:
	if is_busy():
		return false
	attacker = attacker_team
	phase = Phase.WARNING
	_t = PRConfig.TRAP_WARNING
	_warn_label.visible = true
	_on_warn()
	PRSfx.emit(self, "trap_warn", -2.0)
	warned.emit(self)
	return true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	match phase:
		Phase.WARNING:
			_t -= delta
			_warn_label.global_position = get_warning_point() + Vector3(0, 0.15 * sin(_time * 14.0), 0)
			_warn_label.scale = Vector3.ONE * (1.0 + 0.2 * absf(sin(_time * 12.0)))
			_warn_tick(delta)
			if _t <= 0.0:
				_warn_label.visible = false
				phase = Phase.ACTIVE
				_t = active_time()
				_on_activate()
				fired.emit(self)
		Phase.ACTIVE:
			_t -= delta
			_active_tick(delta)
			if _t <= 0.0:
				phase = Phase.RESETTING
				_t = reset_time()
				_on_deactivate()
		Phase.RESETTING:
			_t -= delta
			if _reset_tick(delta, _t <= 0.0):
				phase = Phase.IDLE


# --- Hooks for subclasses ---------------------------------------------------------------

func active_time() -> float:
	return 0.5


func reset_time() -> float:
	return 0.0


## Where the warning "!" floats (world space).
func get_warning_point() -> Vector3:
	return global_position + Vector3(0, 2.0, 1.6)


func _on_warn() -> void:
	pass


func _warn_tick(_delta: float) -> void:
	pass


func _on_activate() -> void:
	pass


func _active_tick(_delta: float) -> void:
	pass


func _on_deactivate() -> void:
	pass


## Called while resetting; return true when the trap is ready again.
func _reset_tick(_delta: float, time_up: bool) -> bool:
	return time_up


# --- Shared helpers -------------------------------------------------------------------------

func _runners_in(area: Area3D) -> Array[PRRunner]:
	var out: Array[PRRunner] = []
	for b in area.get_overlapping_bodies():
		if b is PRRunner and (b as PRRunner).team == team:
			out.append(b)
	return out


func _make_area(size: Vector3, offset := Vector3.ZERO) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = PRConfig.LAYER_RUNNER
	area.monitorable = false
	add_child(area, false, Node.INTERNAL_MODE_FRONT)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	area.add_child(shape)
	return area


static func glow_material(color: Color, energy := 1.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
