extends Area3D


# Called when the node enters the card is added to the scene.
func _ready() -> void:
	# Connect the collision detection signal.
	body_entered.connect(_on_body_entered)


# Called when a physics body enters the card's area.
func _on_body_entered(body: Node3D) -> void:
	#check if the object is a player.
	if body is CharacterBody3D and body.has_method("collect_card"):
		
		# Increase the player's card counter.
		body.collect_card()
		# Display a message for testing purpose.
		print("Player collected a card!")
		
		# Remove the collected card from the scene.
		queue_free()
