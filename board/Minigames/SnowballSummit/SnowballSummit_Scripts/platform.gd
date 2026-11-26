extends StaticBody3D

@export var min_scale := 0.25
@export var shrink_speed := 0.015   # scale lost per second
@export var start_delay := 8.0

var delay: float


func _ready() -> void:
	delay = start_delay


func _physics_process(delta: float) -> void:
	if delay > 0.0:
		delay -= delta
		return
	var s: float = max(scale.x - shrink_speed * delta, min_scale)
	scale = Vector3(s, 1.0, s)
