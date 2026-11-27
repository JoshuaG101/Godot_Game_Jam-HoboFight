class_name Train
extends Area3D

@export var speed: float = 36.0                # meters per second
@export var track_half_length: float = 30.0    # drives between x = -30 and +30, off both ends of the floor
@export var wait_time: float = 6.0             # seconds parked between passes
@export var warning_time: float = 2.0          # the track flashes red for this long before a pass
@export var knockback_strength: float = 40.0   # push strength; distance is about strength² / 60
@export var forward_push: float = 1.0          # how much a hit sends players along the train's direction
@export var sideways_push: float = 0.7         # how much it sends them sideways, away from the track
@export var track: MeshInstance3D              # the track strip that flashes as a warning

const TRACK_COLOR := Color(0.2, 0.2, 0.22)
const WARNING_COLOR := Color(1.0, 0.15, 0.1)

var direction: float = 1.0       # +1 = driving toward +X, -1 = toward -X
var moving: bool = false
var wait_left: float = 0.0
var flash_time: float = 0.0
var already_hit: Array = []      # players already launched on this pass
var track_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("hazards")   # lets the match manager stop arena hazards when the match ends
	position.x = -track_half_length   # start parked off the left end
	wait_left = wait_time
	body_entered.connect(_on_body_entered)

	# Give the track its own material so we can change its color from code
	if track != null:
		track_material = StandardMaterial3D.new()
		track_material.albedo_color = TRACK_COLOR
		track.material_override = track_material


# HOST DECIDES (online: only the host moves the train; clients just see where it is)
func _physics_process(delta: float) -> void:
	if moving:
		position.x += direction * speed * delta

		# Reached the far end: park there and get ready to come back
		if position.x * direction >= track_half_length:
			moving = false
			wait_left = wait_time
			direction = -direction
	else:
		wait_left -= delta
		if wait_left <= 0.0:
			moving = true
			already_hit.clear()

	_update_track_color(delta)


# Track is dark normally, flashes red before a pass, and stays red while the train is out.
func _update_track_color(delta: float) -> void:
	if track_material == null:
		return
	if moving:
		track_material.albedo_color = WARNING_COLOR
	elif wait_left <= warning_time:
		flash_time += delta
		var flash := 0.5 + 0.5 * sin(flash_time * 20.0)
		track_material.albedo_color = TRACK_COLOR.lerp(WARNING_COLOR, flash)
	else:
		track_material.albedo_color = TRACK_COLOR


# HOST DECIDES (online: only the host applies hits)
func _on_body_entered(body: Node3D) -> void:
	if not moving or body in already_hit:
		return
	if not body.has_method("receive_unblockable_hit"):
		return
	already_hit.append(body)

	# Launch along the train's direction, and sideways away from the track's center line
	var side := signf(body.global_position.z - global_position.z)
	if side == 0.0:
		side = 1.0
	var push := Vector3(direction * forward_push, 0.0, side * sideways_push)
	body.receive_unblockable_hit(push, knockback_strength)
