extends MeshInstance3D

@export var start_size := 0.6
@export var max_size := 4.0
@export var growth_per_meter := 0.06
@export var feet_offset := -1.0   # how far below the player's origin the floor is
@export var gap := 0.3            # space between player and ball

@onready var player := get_parent() as CharacterBody3D

var size: float
var last_pos: Vector3


func _ready() -> void:
	size = start_size
	last_pos = player.global_position
	_apply_size()


func _physics_process(_delta: float) -> void:
	var moved := player.global_position - last_pos
	moved.y = 0.0
	last_pos = player.global_position

	if player.is_on_floor() and moved.length() > 0.001:
		size = minf(size + moved.length() * growth_per_meter, max_size)
		_apply_size()


func _apply_size() -> void:
	scale = Vector3.ONE * size
	# Local position: in front of the player, bottom of the ball on the floor
	position = Vector3(0, feet_offset + size, -(size + gap))
