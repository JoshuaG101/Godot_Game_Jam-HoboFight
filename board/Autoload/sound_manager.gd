extends Node

var sfx_hop: AudioStreamWAV
var sfx_coin: AudioStreamWAV
var sfx_lose_coin: AudioStreamWAV
var sfx_star: AudioStreamWAV
var sfx_roll: AudioStreamWAV
var sfx_event: AudioStreamWAV
var sfx_click: AudioStreamWAV

func _ready() -> void:
	init_sfx()

func play_sound(stream: AudioStream, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not stream:
		return
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

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
	if sfx_hop == null:
		sfx_hop = create_tone_wav([280.0, 420.0], 0.12, "triangle", 10.0)
		sfx_coin = create_tone_wav([987.77, 1318.51], 0.35, "sine", 4.0) # B5 -> E6
		sfx_lose_coin = create_tone_wav([260.0, 190.0, 140.0], 0.3, "square", 6.0)
		sfx_star = create_tone_wav([523.25, 659.25, 783.99, 1046.50], 0.6, "sine", 2.5) # C5, E5, G5, C6
		sfx_roll = create_tone_wav([120.0, 180.0, 100.0], 0.25, "noise", 4.0)
		sfx_event = create_tone_wav([440.0, 554.37, 659.25, 880.0], 0.5, "triangle", 3.0)
		sfx_click = create_tone_wav([600.0, 900.0], 0.08, "sine", 12.0)

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
	if sfx_roll == null:
		init_sfx()
	play_sound(sfx_roll, randf_range(0.9, 1.2), 0.0)

func play_event() -> void:
	if sfx_event == null:
		init_sfx()
	play_sound(sfx_event, 1.0, 0.0)

func play_click() -> void:
	if sfx_click == null:
		init_sfx()
	play_sound(sfx_click, 1.0, -2.0)
