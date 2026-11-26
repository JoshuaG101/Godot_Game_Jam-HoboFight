extends MeshInstance3D

@export var start_size := 0.6
@export var max_size := 2.0
@export var growth_per_meter := 0.06
@export var feet_offset := -1.0
@export var gap := 0.3
@export var launch_speed := 14.0
@export var fire_cooldown := 2.5
@export var lifetime := 10.0

@export var base_knockback := 6.0
@export var knockback_per_size := 8.0
@export var knockback_lift := 2.0

@onready var player := get_parent() as CharacterBody3D

var size: float
var last_pos: Vector3
var _cooldown := 0.0


func _ready() -> void:
	size = start_size
	last_pos = player.global_position
	_apply_size()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

	var moved := player.global_position - last_pos
	moved.y = 0.0
	last_pos = player.global_position

	if player.is_on_floor() and moved.length() > 0.001:
		size = minf(size + moved.length() * growth_per_meter, max_size)
		_apply_size()


func release() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = fire_cooldown

	var ball_size := size
	var radius := mesh.get_aabb().size.x * 0.5 * ball_size

	# Work out the launch direction and spawn position BEFORE resetting the ball
	var spawn_pos := global_position
	var forward := spawn_pos - player.global_position
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -player.global_transform.basis.z
		forward.y = 0.0
	forward = forward.normalized()

	# Build the physics ball
	var body := RigidBody3D.new()
	body.mass = ball_size * 2.0
	body.linear_damp = 0.2
	body.angular_damp = 0.2
	body.can_sleep = false
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.add_to_group("snowballs")

	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	pm.bounce = 0.1
	body.physics_material_override = pm

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	body.add_child(col)

	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = material_override
	vis.scale = Vector3.ONE * ball_size
	body.add_child(vis)

	# Add to the level (not the player), place and launch
	player.get_parent().add_child(body)
	body.global_position = spawn_pos
	body.add_collision_exception_with(player)
	body.linear_velocity = forward * launch_speed

	print("launch dir=", forward, " vel=", body.linear_velocity)

	# Knock-back on hit (each player hit once per ball)
	var owner_player := player
	var already_hit := []
	body.body_entered.connect(func(other: Node) -> void:
		if other in already_hit:
			return
		already_hit.append(other)
		_on_ball_hit(body, other, owner_player, ball_size)
	)

	get_tree().create_timer(lifetime).timeout.connect(body.queue_free)

	# Start a new small ball
	size = start_size
	_apply_size()


func _on_ball_hit(body: RigidBody3D, other: Node, owner_player: Node, ball_size: float) -> void:
	if not (other is CharacterBody3D) or other == owner_player:
		return
	if not is_instance_valid(body):
		return

	var dir: Vector3 = other.global_position - body.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = body.linear_velocity
		dir.y = 0.0
	dir = dir.normalized()

	var strength := base_knockback + ball_size * knockback_per_size
	other.velocity += dir * strength + Vector3.UP * knockback_lift


func _apply_size() -> void:
	scale = Vector3.ONE * size
	position = Vector3(0, feet_offset + size, -(size + gap))
