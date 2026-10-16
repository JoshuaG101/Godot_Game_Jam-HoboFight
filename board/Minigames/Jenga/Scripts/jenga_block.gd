extends RigidBody3D


#@export var block_id: int = 0
#@export var can_be_selected:bool = true

#var is_selected:bool = false

func _ready() -> void:
	add_to_group("jenga_blocks")
	
