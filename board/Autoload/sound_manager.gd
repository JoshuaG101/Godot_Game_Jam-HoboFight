extends Node

var sfx_hop: AudioStreamWAV
var sfx_coin: AudioStreamWAV
var sfx_lose_coin: AudioStreamWAV
var sfx_star: AudioStreamWAV
var sfx_roll: AudioStreamWAV
var sfx_event: AudioStreamWAV
var sfx_click: AudioStreamWAV

var music_bosanova: AudioStream = preload("res://music/bosanova.wav")
var music_mix: AudioStream = preload("res://music/mix.wav")
var sfx_dice_roll_faster: AudioStream = preload("res://music/dice roll faster.wav")

var bgm_player: AudioStreamPlayer = null
var dice_roll_player: AudioStreamPlayer = null

func _ready() -> void:
	init_sfx()
	set_volume(1.0)
	_init_players()

func _init_players() -> void:
	if bgm_player == null:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.name = "BGMPlayer"
		bgm_player.bus = "Master"
		add_child(bgm_player)
		bgm_player.finished.connect(_on_bgm_finished)

	if dice_roll_player == null:
		dice_roll_player = AudioStreamPlayer.new()
		dice_roll_player.name = "DiceRollPlayer"
		dice_roll_player.bus = "Master"
		add_child(dice_roll_player)

func _on_bgm_finished() -> void:
	if bgm_player and bgm_player.stream:
		bgm_player.play()

func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not stream:
		return
	# Only allow real .wav audio files
	if not (stream is AudioStreamWAV):
		return
	var res_path: String = stream.resource_path.to_lower()
	if res_path != "" and not res_path.ends_with(".wav"):
		return

	if bgm_player == null:
		_init_players()
	if bgm_player.stream == stream and bgm_player.playing:
		return
	bgm_player.stream = stream
	bgm_player.volume_db = volume_db
	bgm_player.play()

func stop_music() -> void:
	if bgm_player and bgm_player.playing:
		bgm_player.stop()

func play_dice_rolling(volume_db: float = 0.0) -> void:
	if dice_roll_player == null:
		_init_players()
	if sfx_dice_roll_faster and sfx_dice_roll_faster is AudioStreamWAV:
		dice_roll_player.stream = sfx_dice_roll_faster
		dice_roll_player.volume_db = volume_db -200
		dice_roll_player.play()

func stop_dice_rolling() -> void:
	if dice_roll_player and dice_roll_player.playing:
		var tween = create_tween()
		tween.tween_property(dice_roll_player, "volume_db", -35.0, 0.15)
		tween.tween_callback(dice_roll_player.stop)

func play_sound(stream: AudioStream, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not stream:
		return
	# Only allow .wav audio
	if not (stream is AudioStreamWAV):
		return
	var res_path: String = stream.resource_path.to_lower()
	if res_path != "" and not res_path.ends_with(".wav"):
		return

	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func set_volume(val: float) -> void:
	# val from 0.0 to 1.0 (Master Bus)
	if val <= 0.001:
		AudioServer.set_bus_mute(0, true)
		AudioServer.set_bus_volume_db(0, -80.0)
	else:
		AudioServer.set_bus_mute(0, false)
		var db = linear_to_db(val)
		AudioServer.set_bus_volume_db(0, db)

func get_volume() -> float:
	if AudioServer.is_bus_mute(0):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(0))

# Procedurally generate a wav sound stream
func create_tone_wav(frequencies: Array, duration: float, wave_type: String = "sine", decay: float = 5.0) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var total_samples: int = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_samples * 2) # 16-bit mono

	for i in range(total_samples):
		var t = float(i) / sample_rate
		var freq_idx = mini(int((float(i) / total_samples) * frequencies.size()), frequencies.size() - 1)
		var freq: float = float(frequencies[freq_idx])
		
		var sample_val: float = 0.0
		var phase = t * freq * TAU
		if wave_type == "sine":
			sample_val = sin(phase)
		elif wave_type == "square":
			sample_val = 0.6 if sin(phase) >= 0.0 else -0.6
		elif wave_type == "triangle":
			sample_val = asin(sin(phase)) * (2.0 / PI)
		elif wave_type == "noise":
			sample_val = randf_range(-0.7, 0.7)

		var envelope: float = exp(-decay * t)
		sample_val *= envelope

		var int_sample: int = clampi(int(sample_val * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, int_sample)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_data
	return wav

func init_sfx() -> void:
	# Only .wav sound files are enabled; procedural synth placeholder tones are disabled
	pass

func play_hop() -> void:
	if sfx_hop == null:
		init_sfx()
	play_sound(sfx_hop, randf_range(0.95, 1.05), -2.0)

func play_coin() -> void:
	if sfx_coin == null:
		init_sfx()
	play_sound(sfx_coin, 1.0, 0.0)

func play_lose_coin() -> void:
	if sfx_lose_coin == null:
		init_sfx()
	play_sound(sfx_lose_coin, 1.0, -2.0)

func play_star() -> void:
	if sfx_star == null:
		init_sfx()
	play_sound(sfx_star, 1.0, 2.0)

func play_roll() -> void:
	play_dice_rolling(0.0)

func play_event() -> void:
	if sfx_event == null:
		init_sfx()
	play_sound(sfx_event, 1.0, 0.0)

func play_click() -> void:
	if sfx_click == null:
		init_sfx()
	play_sound(sfx_click, 1.0, -2.0)
