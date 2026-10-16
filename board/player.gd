extends Node3D

@export var current_space: BoardNode3D
@export var move_speed: float = 4.0 # Higher is faster

var is_moving: bool = false

func _ready() -> void:
	if not current_space:
		push_error("Player has no Current Space assigned in the Inspector!")
		return
		
	# Snap to the starting space immediately when the game loads
	global_position = current_space.global_position


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept") and not is_moving:
		if not current_space:
			print("Cannot move: current_space is missing!")
			return
			
		var dice_roll = randi_range(1, 6)
		print("Rolled a: ", dice_roll)
		move_steps(dice_roll)


func move_steps(steps: int) -> void:
	is_moving = true
	
	for i in range(steps):
		var next_options = current_space.get_next_spaces()
		
		if next_options.is_empty():
			print("Reached the end of the path early!")
			break
			
		current_space = next_options[0]
		
		# Smoothly move to the next space's position in 3D space
		await tween_to_position(current_space.global_position)
		
	is_moving = false
	print("Finished moving! Landed on space type: ", current_space.space_type)
	trigger_space_event()


func tween_to_position(target_pos: Vector3) -> void:
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, 1.0 / move_speed).set_trans(Tween.TRANS_SINE)
	await tween.finished


func trigger_space_event() -> void:
	match current_space.space_type:
		BoardNode3D.SpaceType.BLUE:
			print("Gained 3 coins!")
		BoardNode3D.SpaceType.RED:
			print("Lost 3 coins!")
		BoardNode3D.SpaceType.EVENT:
			print("Triggering random board event...")
		BoardNode3D.SpaceType.STAR:
			print("You can buy a star here!")
