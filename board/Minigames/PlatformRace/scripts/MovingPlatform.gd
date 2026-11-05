
extends AnimatableBody3D

@export var speed: float = 3.0
@export var platform_depth: float = 4.53
@export var wall_clearance: float = 0.1

@onready var wall_ray: RayCast3D = $WallRay

var direction: float = 1.0


func _ready() -> void:
	wall_ray.enabled = true
	wall_ray.collision_mask = 2
	wall_ray.exclude_parent = true


func _physics_process(delta: float) -> void:
	var detection_distance := platform_depth / 2.0 + speed * delta + wall_clearance

	wall_ray.target_position = Vector3(
		0.0, 0.0, direction * detection_distance
	)
	wall_ray.force_raycast_update()

	if wall_ray.is_colliding():
		direction *= -1.0

	global_position.z += direction * speed * delta
