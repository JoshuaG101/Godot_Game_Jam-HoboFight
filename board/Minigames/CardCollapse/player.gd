extends CharacterBody3D
# Number of cards currently held by the player.
var card_count: int = 0

# Reference to the card counter in our GameUI
@onready var card_counter: Label = $"../Game UI/CardCounter"

# Reference to ArenaBlocks
@onready var arena_blocks = $"../ArenaBlocks"


# Reference to the Game Over label in the UI
@onready var game_over_label: Label = $"../Game UI/GameOverLabel"


func _ready() -> void:
	print("CardCounter found: ", card_counter)

# Add a card to the player's collection.
func collect_card() -> void:
	
	card_count += 1
	
	#Display the updated number of cards.
	print("Player cards: ", card_count)
	
	# Update the text displayed on the screen.
	card_counter.text = "Cards: " + str(card_count)
	
	
	if card_count >= 2:
		var random_block = arena_blocks.get_random_block()

		if random_block != "":
			print("Selected block: ", random_block)
			await arena_blocks.warn_block(random_block)
			arena_blocks.collapse_block(random_block)

		
# Movement speed of the player.
# @export allows us to modify this value in Godot's Inspector.
@export var speed: float = 5.0

# Gravity force applied to the player when not on the ground.
var gravity: float = 9.8

# Called every physics frame to handle player movement.
# delta represents the time elapsed since the previous frame.
func _physics_process(delta):
	
	# Apply gravity only when the player is in the air.
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Initialize the movement direction with no movement.
	var direction = Vector3.ZERO
		
	# Move forward along the negative Z axis.
	if Input.is_key_pressed(KEY_W):
		direction.z -= 1
			
	# Move backward along the positive Z axis.
	if Input.is_key_pressed(KEY_S):
		direction.z += 1
			
	# Move left along the negative X axis.
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1
			
	# Move right along the positive X axis.
	if Input.is_key_pressed(KEY_D):
		direction.x += 1
			
	# Normalize direction to prevent faster diagonal movement.
	direction = direction.normalized()
		
	# Apply horizontal movement based on direction and speed.
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
		
	# Move the player while handling collisions with the environment.
	move_and_slide()
	
	# Check if the player has fallen below the arena
	if global_position.y < -5.0:
		# Display the Game Over message
		game_over_label.text = "GAME OVER"
		game_over_label.show()

		# Log the player's defeat
		print("GAME OVER! Player fell off the arena.")

		# Stop processing the player's physics
		set_physics_process(false)

	

	
	
