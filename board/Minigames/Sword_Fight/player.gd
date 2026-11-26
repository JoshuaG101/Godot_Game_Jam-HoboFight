class_name Player
extends CharacterBody3D

# Announced once when this player is out of the match.
signal defeated(player: Node3D)

@export var player_id: int = 1          # 1 or 2, picks which input actions to read
@export var speed: float = 6.0          # meters per second
@export var turn_speed: float = 12.0    # how fast the player turns to face movement
@export var fall_limit_y: float = -8.0  # falling below this height means defeat

var knockback: Vector3 = Vector3.ZERO   # extra push from hits, decays over time
var is_defeated: bool = false

# Input state: the movement code only reads these, never the keyboard directly.
var input_dir: Vector2 = Vector2.ZERO
var attack_pressed: bool = false
var deflect_pressed: bool = false

var character_model: Node3D = null
var anim_player: AnimationPlayer = null
var current_action_lock: float = 0.0

# Sword and Deflect have their own scripts (sword.gd, deflect.gd)
@onready var sword: Sword = $Sword
@onready var deflect: Deflect = $Deflect


func _ready() -> void:
	add_to_group("players")   # lets the match manager find every player
	_setup_model()
	_apply_major_powerup()


func _setup_model() -> void:
	var model_scene = GameState.get_player_model_scene(player_id) if GameState else null
	if model_scene:
		character_model = model_scene.instantiate()
		character_model.name = "CharacterModel"
		character_model.rotation.y = PI # Face forward (-Z)
		character_model.scale = Vector3(1.0, 1.0, 1.0)
		add_child(character_model)
		anim_player = character_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player and GameState:
			GameState.setup_character_idle_animation(anim_player)
			play_anim("idle", true)
		var mesh_inst = get_node_or_null("MeshInstance3D")
		if mesh_inst:
			mesh_inst.visible = false

	# Add glowing ring under player's feet
	var ring = MeshInstance3D.new()
	ring.name = "PlayerRing"
	var torus = TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.52
	torus.rings = 24
	ring.mesh = torus
	ring.position = Vector3(0, 0.05, 0)
	var ring_mat = StandardMaterial3D.new()
	var p_color = GameState.get_player_color(player_id) if GameState else (Color.CYAN if player_id == 1 else Color.ORANGE)
	ring_mat.albedo_color = p_color
	ring_mat.emission_enabled = true
	ring_mat.emission = p_color * 1.5
	ring.material_override = ring_mat
	add_child(ring)

	# Overhead badge
	var overhead = Label3D.new()
	overhead.name = "OverheadBadge"
	overhead.text = "P%d %s" % [player_id, GameState.get_player_name(player_id) if GameState else ""]
	overhead.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overhead.pixel_size = 0.010
	overhead.position = Vector3(0, 2.1, 0)
	overhead.font_size = 32
	overhead.modulate = p_color
	overhead.outline_size = 8
	overhead.outline_modulate = Color.BLACK
	add_child(overhead)


func play_anim(anim_name: String, loop: bool = false, blend_time: float = 0.15) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	var anim = anim_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if anim_player.current_animation != anim_name or not anim_player.is_playing():
		anim_player.play(anim_name, blend_time)


func _apply_major_powerup() -> void:
	if not GameState:
		return
	var idx = player_id - 1
	if idx < 0 or idx >= GameState.player_data.size():
		return
	var p_data = GameState.player_data[idx]
	var mesh_inst: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh_inst:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = p_data.get("color", Color.WHITE)
		mat.metallic = 0.2
		mat.roughness = 0.4
		mesh_inst.material_override = mat

	var m_id: String = p_data.get("major_id", "")
	match m_id.to_lower():
		"cs":
			speed = 7.2
			turn_speed = 16.0
		"business":
			set_meta("knockback_resist", 0.6)
		"arts":
			speed = 6.8
			turn_speed = 18.0
		"engineering":
			set_meta("knockback_mult", 1.45)
		"premed":
			if deflect:
				deflect.deflect_duration = 0.45
		"philosophy":
			set_meta("knockback_resist", 0.5)


func _physics_process(delta: float) -> void:
	gather_input()   # LOCAL PLAYER ONLY (online: remote players get input from the network)
	simulate(delta)

	if current_action_lock > 0.0:
		current_action_lock -= delta

	# Attacking and deflecting can't overlap.
	# HOST DECIDES (online: the host validates attack and deflect requests)
	if deflect_pressed and not sword.is_swinging():
		deflect.try_deflect()
		play_anim("block", false, 0.08)
		current_action_lock = 0.35
	if attack_pressed and not deflect.is_active():
		sword.try_attack()
		play_anim("slash", false, 0.08)
		current_action_lock = 0.35

	# Update locomotion animation when not performing action
	if current_action_lock <= 0.0 and not is_defeated:
		if is_on_floor() and input_dir.length_squared() > 0.01:
			play_anim("run", true, 0.12)
		else:
			play_anim("idle", true, 0.15)

	# Falling off the arena means defeat
	if global_position.y < fall_limit_y:
		defeat()


# Reads this player's keyboard and stores it in the state variables above.
func gather_input() -> void:
	input_dir = Input.get_vector(
		"p%d_left" % player_id, "p%d_right" % player_id,
		"p%d_up" % player_id, "p%d_down" % player_id)
	# "just_pressed" is true only on the frame the key goes down
	attack_pressed = Input.is_action_just_pressed("p%d_attack" % player_id)
	deflect_pressed = Input.is_action_just_pressed("p%d_deflect" % player_id)


# All movement logic, using only the state variables above.
func simulate(delta: float) -> void:
	# Map 2D input onto the ground plane (X and Z), slowed while deflecting
	var move := Vector3(input_dir.x, 0.0, input_dir.y) * speed * deflect.get_speed_multiplier()

	# Set horizontal velocity only, so gravity (y) isn't overwritten
	velocity.x = move.x + knockback.x
	velocity.z = move.z + knockback.z

	# Fall when not on the ground
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Slow the knockback toward zero
	knockback = knockback.move_toward(Vector3.ZERO, 30.0 * delta)

	# Smoothly turn to face the movement direction
	if input_dir != Vector2.ZERO:
		var target_angle := atan2(-move.x, -move.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)

	# Move, sliding along any collisions
	move_and_slide()


# The one entry point for being hit by a sword. Decides what the hit does.
# HOST DECIDES (online: only the host should run this)
func receive_hit(direction: Vector3, strength: float, attacker: Node3D) -> void:
	# A deflect only works against attackers in front of us
	if deflect.blocks_hit_from(attacker.global_position):
		# Hit cancelled, and the attacker gets a small recoil
		attacker.apply_knockback(-direction, deflect.recoil_strength)
		return
	apply_knockback(direction, strength)
	was_hit.emit(strength)

# Applies a push to this player.
# HOST DECIDES (online: only the host should call this)
func apply_knockback(direction: Vector3, strength: float) -> void:
	direction.y = 0.0   # keep the push along the ground, never upward
	var resist: float = get_meta("knockback_resist") if has_meta("knockback_resist") else 1.0
	knockback = direction.normalized() * (strength * resist)


# Takes this player out of the match and announces it. Anything can call this:
# the fall check above now, and hazards in future arenas.
# HOST DECIDES (online: only the host should declare defeats)
func defeat() -> void:
	if is_defeated:
		return   # only announce once
	is_defeated = true
	defeated.emit(self)
	
# Switches this player in or out of sudden death.
# HOST DECIDES (online: the match manager calls this on the host)
func set_sudden_death(active: bool) -> void:
	deflect.set_enabled(not active)   # no deflecting in sudden death
	sword.set_sudden_death(active)    # stronger, glowing sword

# Announced when a hit actually lands (not deflected). Used for effects.
signal was_hit(strength: float)
