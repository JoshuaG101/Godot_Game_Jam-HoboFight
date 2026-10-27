extends Node3D

@export var current_space: BoardNode3D
@export var dice: RigidBody3D # Drag your Die RigidBody3D here in the Inspector
@export var move_speed: float = 4.0 # Higher is faster

var is_moving: bool = false
var is_rolling: bool = false

func _ready() -> void:
	if not current_space:
		push_error("Player has no Current Space assigned in the Inspector!")
		return
		
	# Snap to the starting space immediately when the game loads
	global_position = current_space.global_position
	
	if dice:
		# Connect to the die's signal so we receive the rolled number when it stops
		dice.roll_finished.connect(_on_dice_roll_finished)
	else:
		push_error("Player is missing the Dice reference in the Inspector!")


func _input(event: InputEvent) -> void:
	# Press spacebar to start a turn (if we aren't already moving or rolling)
	if event.is_action_pressed("ui_accept") and not is_moving and not is_rolling:
		if dice:
			is_rolling = true
			dice._roll() # Trigger the physical die roll


func _on_dice_roll_finished(roll_value: int) -> void:
	is_rolling = false
	print("Physical die rolled a: ", roll_value)
	move_steps(roll_value)


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
