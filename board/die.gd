extends RigidBody3D

@onready var raycasts = $Raycasts.get_children()

var start_pos: Vector3
var jump_force: float = 6.0       
var horizontal_drift: float = 2.0 
var roll_strength: float = 18.0   

var is_rolling: bool = false 
var roll_time: float = 0.0
var settle_timer: float = 0.0
var has_reported_roll: bool = false

signal roll_finished(value: int)

# Fallback geometric face normals in local space for 100% reliable detection
var face_normals: Dictionary = {
	1: Vector3.UP,       # Top face
	6: Vector3.DOWN,     # Bottom face
	5: Vector3.RIGHT,    # Right face
	3: Vector3.LEFT,     # Left face
	4: Vector3.FORWARD,  # Front face
	2: Vector3.BACK      # Back face
}

func _ready() -> void:
	start_pos = global_position
	
	var phys_mat = PhysicsMaterial.new()
	phys_mat.bounce = 0.1
	phys_mat.friction = 0.7
	physics_material_override = phys_mat
	
	linear_damp = 1.8
	angular_damp = 1.8
	
	if not sleeping_state_changed.is_connected(_on_sleeping_state_changed):
		sleeping_state_changed.connect(_on_sleeping_state_changed)

func _roll() -> void:
	SoundManager.play_roll()
	sleeping = false
	freeze = false
	transform.origin = start_pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Random initial orientation
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
	roll_time = 0.0
	settle_timer = 0.0
	has_reported_roll = false
	print("Die rolled! Rolling in progress...")

func _physics_process(delta: float) -> void:
	if not is_rolling or has_reported_roll:
		return
		
	roll_time += delta
	
	# Only start monitoring settle after die has launched into the air
	if roll_time > 0.4:
		var speed = linear_velocity.length()
		var ang_speed = angular_velocity.length()
		
		if speed < 0.2 and ang_speed < 0.4:
			settle_timer += delta
			if settle_timer > 0.35:
				_finalize_roll()
				return
		else:
			settle_timer = 0.0
			
		# Fallback max roll duration so the game never gets stuck
		if roll_time > 2.5:
			_finalize_roll()

func _on_sleeping_state_changed() -> void:
	if sleeping and is_rolling and not has_reported_roll:
		_finalize_roll()

func _finalize_roll() -> void:
	if has_reported_roll:
		return
	has_reported_roll = true
	is_rolling = false
	freeze = true
	
	var result_val: int = detect_face_value()
	print("[Die] Rolled value: %d" % result_val)
	
	# Spawn a punchy 3D visual popup above the die
	spawn_roll_popup(result_val)
	
	roll_finished.emit(result_val)

func detect_face_value() -> int:
	# 1. Try raycasts
	for raycast in raycasts:
		if raycast is RayCast3D and raycast.is_colliding():
			var val = raycast.get("opposite_side")
			if val != null and int(val) in range(1, 7):
				return int(val)
				
	# 2. Geometric dot product fallback: which local face normal points up globally?
	var best_face: int = 1
	var best_dot: float = -999.0
	for face_num in face_normals:
		var local_vec: Vector3 = face_normals[face_num]
		var global_vec: Vector3 = global_transform.basis * local_vec
		var dot: float = global_vec.dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best_face = face_num
			
	return best_face

func spawn_roll_popup(val: int) -> void:
	var popup = Label3D.new()
	popup.text = str(val)
	popup.font_size = 72
	popup.pixel_size = 0.015
	popup.modulate = Color(1.0, 0.9, 0.2)
	popup.outline_size = 12
	popup.outline_modulate = Color(0, 0, 0, 0.9)
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.global_position = global_position + Vector3(0, 1.2, 0)
	get_parent().add_child(popup)
	
	var tw = popup.create_tween()
	tw.set_parallel(true)
	tw.tween_property(popup, "position:y", popup.position.y + 1.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(popup.queue_free)
