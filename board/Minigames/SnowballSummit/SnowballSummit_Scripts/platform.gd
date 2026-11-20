extends StaticBody3D

@export var min_scale := 0.1
@export var shrink_speed := 0.04   # scale lost per second
@export var start_delay := 3.0

var delay: float


func _ready() -> void:
	delay = start_delay


func _physics_process(delta: float) -> void:
	if delay > 0.0:
		delay -= delta
		return
	var s: float = max(scale.x - shrink_speed * delta, min_scale)
	scale = Vector3(s, 1.0, s)
