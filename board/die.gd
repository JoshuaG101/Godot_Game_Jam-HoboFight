extends RigidBody3D

@onready var raycasts = $Raycasts.get_children()

var start_pos
var jump_force = 5.0       
var horizontal_drift = 2.0 
var roll_strength = 15.0   

var is_rolling = false 

signal roll_finished(value)


func _ready():
	start_pos = global_position
	
	var phys_mat = PhysicsMaterial.new()
	phys_mat.bounce = 0.05
	phys_mat.friction = 0.8
	physics_material_override = phys_mat
	
	linear_damp = 2.0
	angular_damp = 2.0
	
	# CRITICAL: Connect the built-in signal to your function via code!
	if not sleeping_state_changed.is_connected(_on_sleeping_state_changed):
		sleeping_state_changed.connect(_on_sleeping_state_changed)


func _roll():
	sleeping = false
	freeze = false
	transform.origin = start_pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	transform.basis = Basis(Vector3.RIGHT, randf_range(0, 2 * PI))
	transform.basis = Basis(Vector3.UP, randf_range(0, 2 * PI)) * transform.basis
	transform.basis = Basis(Vector3.FORWARD, randf_range(0, 2 * PI)) * transform.basis
	
	var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var impulse = (random_dir * horizontal_drift) + (Vector3.UP * jump_force)
	
	apply_central_impulse(impulse)
	
	angular_velocity = Vector3(
		randf_range(-1, 1),
		randf_range(-1, 1),
		randf_range(-1, 1)
	).normalized() * roll_strength
	
	is_rolling = true
	print("Die rolled! Waiting for it to stop...")


func _on_sleeping_state_changed() -> void:
	if sleeping and is_rolling:
		print("Die went to sleep. Checking raycasts...")
		var landed_on_side = false
		for raycast in raycasts:
			if raycast.is_colliding():
				print("Raycast hit! Landed on side value: ", raycast.opposite_side)
				roll_finished.emit(raycast.opposite_side)
				is_rolling = false
				landed_on_side = true
				break
		
		if !landed_on_side:
			print("Missed all raycasts, giving a tiny nudge...")
			apply_central_impulse(Vector3(0, 0.5, 0))
