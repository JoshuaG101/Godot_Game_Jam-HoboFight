class_name Player
extends CharacterBody3D

const PlayerClass = preload("res://Minigames/Sword_Fight/player_class.gd")
const Ability = preload("res://Minigames/Sword_Fight/Abilities/ability.gd")
const DashAbility = preload("res://Minigames/Sword_Fight/Abilities/dash_ability_religion.gd")
const UndoAbility = preload("res://Minigames/Sword_Fight/Abilities/undo_ability_cs.gd")
const ArtilleryAbility = preload("res://Minigames/Sword_Fight/Abilities/artillery_ability_history.gd")
const RouletteAbility = preload("res://Minigames/Sword_Fight/Abilities/roulette_ability_music.gd")

# Announced once when this player is out of the match.
signal defeated(player: Node3D)
# Announced when a hit actually lands (not deflected). Used for effects.
signal was_hit(strength: float)

@export var player_id: int = 1          # 1 or 2, picks which input actions to read
@export var player_class: PlayerClass.Type = PlayerClass.Type.NONE   # decides this player's ability
@export var speed: float = 6.0          # meters per second
@export var turn_speed: float = 12.0    # how fast the player turns to face movement
@export var fall_limit_y: float = -8.0  # falling below this height means defeat

var knockback: Vector3 = Vector3.ZERO   # extra push from hits, decays over time
var is_defeated: bool = false

# Input state: the movement code only reads these, never the keyboard directly.
var input_dir: Vector2 = Vector2.ZERO
var attack_pressed: bool = false
var deflect_pressed: bool = false
var ability_pressed: bool = false

# Dash state (started by the Religion ability)
var dash_velocity: Vector3 = Vector3.ZERO
var dash_left: float = 0.0

# The ability that goes with this player's class (null if the class has none yet)
var ability: Ability = null

# Temporary power and speed modifiers (e.g. from Music Roulette)
var power_effect: float = 1.0
var power_effect_timer: float = 0.0
var speed_effect: float = 1.0
var speed_effect_timer: float = 0.0

var character_model: Node3D = null
var anim_player: AnimationPlayer = null
var current_action_lock: float = 0.0

# Sword and Deflect have their own scripts (sword.gd, deflect.gd)
@onready var sword: Sword = $Sword
@onready var deflect: Deflect = $Deflect


func _get_game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/GameState")


func _ready() -> void:
	add_to_group("players")   # lets the match manager find every player
	_setup_inputs()
	var gs = _get_game_state()
	if gs:
		var idx = player_id - 1
		if idx >= 0 and idx < gs.player_data.size():
			var m_id = gs.player_data[idx].get("major_id", "")
			player_class = _map_major_to_player_class(m_id)
	set_player_class(player_class)
	_setup_model()
	_apply_major_powerup()


func _setup_inputs() -> void:
	var p: String = "p%d_" % player_id
	var actions: Array[String] = ["left", "right", "up", "down", "attack", "deflect", "ability"]
	for act: String in actions:
		var action_name: String = p + act
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
		InputMap.add_action(action_name, 0.2)

	# Gamepad axis / buttons for all players
	_add_joy_axis(p + "left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(p + "right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis(p + "up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis(p + "down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button(p + "attack", JOY_BUTTON_X)
	_add_joy_button(p + "deflect", JOY_BUTTON_B)
	_add_joy_button(p + "ability", JOY_BUTTON_Y)
	_add_joy_button(p + "attack", JOY_BUTTON_RIGHT_SHOULDER)

	# Keyboard bindings per player
	match player_id:
		1:
			_add_key(p + "left", KEY_A)
			_add_key(p + "right", KEY_D)
			_add_key(p + "up", KEY_W)
			_add_key(p + "down", KEY_S)
			_add_key(p + "attack", KEY_F)
			_add_key(p + "deflect", KEY_G)
			_add_key(p + "ability", KEY_H)
			_add_key(p + "attack", KEY_SPACE)
		2:
			_add_key(p + "left", KEY_LEFT)
			_add_key(p + "right", KEY_RIGHT)
			_add_key(p + "up", KEY_UP)
			_add_key(p + "down", KEY_DOWN)
			_add_key(p + "attack", KEY_COMMA)
			_add_key(p + "deflect", KEY_PERIOD)
			_add_key(p + "ability", KEY_SLASH)
			_add_key(p + "attack", KEY_ENTER)
		3:
			_add_key(p + "left", KEY_J)
			_add_key(p + "right", KEY_L)
			_add_key(p + "up", KEY_I)
			_add_key(p + "down", KEY_K)
			_add_key(p + "attack", KEY_U)
			_add_key(p + "deflect", KEY_O)
			_add_key(p + "ability", KEY_P)
		4:
			_add_key(p + "left", KEY_KP_4)
			_add_key(p + "right", KEY_KP_6)
			_add_key(p + "up", KEY_KP_8)
			_add_key(p + "down", KEY_KP_5)
			_add_key(p + "attack", KEY_KP_1)
			_add_key(p + "deflect", KEY_KP_2)
			_add_key(p + "ability", KEY_KP_3)
			# Fallback standard keys if no numpad
			_add_key(p + "attack", KEY_Z)
			_add_key(p + "deflect", KEY_X)
			_add_key(p + "ability", KEY_C)


func _add_key(action: String, key: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	InputMap.action_add_event(action, e)


func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = player_id - 1
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)


func _add_joy_button(action: String, button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.device = player_id - 1
	e.button_index = button
	InputMap.action_add_event(action, e)


func _map_major_to_player_class(major_id: String) -> PlayerClass.Type:
	match major_id.to_lower():
		"religion", "philosophy":
			return PlayerClass.Type.RELIGION
		"cs", "computer science":
			return PlayerClass.Type.COMPUTER_SCIENCE
		"history", "business":
			return PlayerClass.Type.HISTORY
		"music", "premed":
			return PlayerClass.Type.MUSIC
		"arts", "art":
			return PlayerClass.Type.ART
		"anthro", "anthropology", "engineering":
			return PlayerClass.Type.ANTHROPOLOGY
	return PlayerClass.Type.NONE


func _setup_model() -> void:
	var gs = _get_game_state()
	var model_scene = gs.get_player_model_scene(player_id) if gs else null
	if model_scene:
		character_model = model_scene.instantiate()
		character_model.name = "CharacterModel"
		character_model.rotation.y = PI # Face forward (-Z)
		character_model.scale = Vector3(1.0, 1.0, 1.0)
		add_child(character_model)
		anim_player = character_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player and gs and gs.has_method("setup_character_idle_animation"):
			gs.setup_character_idle_animation(anim_player)
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
	var p_color = gs.get_player_color(player_id) if gs else (Color.CYAN if player_id == 1 else Color.ORANGE)
	ring_mat.albedo_color = p_color
	ring_mat.emission_enabled = true
	ring_mat.emission = p_color * 1.5
	ring.material_override = ring_mat
	add_child(ring)

	# Overhead badge
	var overhead = Label3D.new()
	overhead.name = "OverheadBadge"
	overhead.text = "P%d %s" % [player_id, gs.get_player_name(player_id) if gs else ""]
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
	var gs = _get_game_state()
	if not gs:
		return
	var idx = player_id - 1
	if idx < 0 or idx >= gs.player_data.size():
		return
	var p_data = gs.player_data[idx]
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
		"business", "history":
			set_meta("knockback_resist", 0.6)
		"arts":
			speed = 6.8
			turn_speed = 18.0
		"engineering", "anthro":
			set_meta("knockback_mult", 1.45)
		"premed", "music":
			if deflect:
				deflect.deflect_duration = 0.45
		"philosophy", "religion":
			set_meta("knockback_resist", 0.5)


func _physics_process(delta: float) -> void:
	gather_input()   # LOCAL PLAYER ONLY (online: remote players get input from the network)
	simulate(delta)

	if current_action_lock > 0.0:
		current_action_lock -= delta

	# Attacking, deflecting and abilities have rules about what can overlap.
	# HOST DECIDES (online: the host validates attack, deflect and ability requests)
	if deflect_pressed and not sword.is_swinging() and not is_dashing():
		deflect.try_deflect()
		play_anim("block", false, 0.08)
		current_action_lock = 0.35
	if attack_pressed and not deflect.is_active() and not is_dashing():
		sword.try_attack()
		play_anim("slash", false, 0.08)
		current_action_lock = 0.35
	if ability_pressed and ability != null:
		ability.try_use()

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
	if InputMap.has_action("p%d_ability" % player_id):
		ability_pressed = Input.is_action_just_pressed("p%d_ability" % player_id)
	else:
		ability_pressed = false


# All movement logic, using only the state variables above.
func simulate(delta: float) -> void:
	if speed_effect_timer > 0.0:
		speed_effect_timer -= delta
		if speed_effect_timer <= 0.0:
			speed_effect = 1.0

	if power_effect_timer > 0.0:
		power_effect_timer -= delta
		if power_effect_timer <= 0.0:
			power_effect = 1.0

	# Map 2D input onto the ground plane (X and Z), slowed while deflecting
	var move := Vector3(input_dir.x, 0.0, input_dir.y) * (speed * speed_effect) * deflect.get_speed_multiplier()

	# A dash replaces normal walking for its short duration
	if dash_left > 0.0:
		dash_left -= delta
		move = dash_velocity

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


func apply_power_effect(mult: float, duration: float) -> void:
	power_effect = mult
	power_effect_timer = duration


func apply_speed_effect(mult: float, duration: float) -> void:
	speed_effect = mult
	speed_effect_timer = duration


func get_power_effect() -> float:
	var atk_mult: float = get_meta("knockback_mult") if has_meta("knockback_mult") else 1.0
	return power_effect * atk_mult


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


# Hits that can't be deflected, such as arena hazards like the train.
# HOST DECIDES (online: only the host applies hits)
func receive_unblockable_hit(direction: Vector3, strength: float) -> void:
	apply_knockback(direction, strength)
	was_hit.emit(strength)   # keeps the camera shake and other hit effects working


# Applies a push to this player.
# HOST DECIDES (online: only the host should call this)
func apply_knockback(direction: Vector3, strength: float) -> void:
	direction.y = 0.0   # keep the push along the ground, never upward
	var resist: float = get_meta("knockback_resist") if has_meta("knockback_resist") else 1.0
	knockback = direction.normalized() * (strength * resist)


# Takes this player out of the match and announces it. Anything can call this:
# the fall check above, and hazards in arenas.
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


# Gives this player a class, and with it that class's ability. Called at startup with
# the Inspector value; the module that assigns classes later can call it too.
# HOST DECIDES (online: the host assigns classes)
func set_player_class(type: PlayerClass.Type) -> void:
	player_class = type

	# Remove the previous class's ability, if there was one
	if ability != null:
		ability.queue_free()
		ability = null

	ability = _create_ability(type)
	if ability != null:
		add_child(ability)


# Which ability goes with which class. Classes without an ability yet return null.
func _create_ability(type: PlayerClass.Type) -> Ability:
	match type:
		PlayerClass.Type.RELIGION:
			return DashAbility.new()
		PlayerClass.Type.COMPUTER_SCIENCE:
			return UndoAbility.new()
		PlayerClass.Type.HISTORY:
			return ArtilleryAbility.new()
		PlayerClass.Type.MUSIC:
			return RouletteAbility.new()
	return null


# Starts a quick burst of movement (used by the dash ability).
func start_dash(direction: Vector3, distance: float, duration: float) -> void:
	direction.y = 0.0
	dash_velocity = direction.normalized() * (distance / duration)
	dash_left = duration


func is_dashing() -> bool:
	return dash_left > 0.0


# Moves this player instantly and cancels all motion (used by Undo).
func teleport_to(target: Vector3) -> void:
	global_position = target
	velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	dash_left = 0.0
