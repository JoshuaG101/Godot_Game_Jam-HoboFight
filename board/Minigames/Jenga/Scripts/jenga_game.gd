extends Node3D

const BLOCK_SCENE: PackedScene = preload(
	"res://Minigames/Jenga/Scenes/jenga_block.tscn"
)

const BLOCK_LENGTH: float = 1.5
const BLOCK_WIDTH: float = 0.5
const BLOCK_HEIGHT: float = 0.5
const BLOCK_GAP: float = 0.025

const LAYER_COUNT: int = 8
const BLOCKS_PER_LAYER: int = 3

func _ready() -> void:
	$Camera3D.current = true
	$Camera3D.look_at(Vector3(0,2,0), Vector3.UP)
	
	build_tower()

func build_tower() -> void:
	for layer in range(LAYER_COUNT):
		for i in range(BLOCKS_PER_LAYER):
			var block = BLOCK_SCENE.instantiate()
			add_child(block)
			
			var height = (BLOCK_HEIGHT + BLOCK_GAP) / 2.0
			height += layer * (BLOCK_HEIGHT + BLOCK_GAP)
			
			if layer % 2 == 0:
				block.position = Vector3(
					0,
					height,
					(i-1) * (BLOCK_WIDTH + BLOCK_GAP)
					)
			else:
				block.position = Vector3(
					(i - 1) * (BLOCK_WIDTH + BLOCK_GAP),
					height,
					0
				)
				block.rotation.y = PI /2.0
						
			
