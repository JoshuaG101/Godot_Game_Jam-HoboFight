class_name PRSfx
extends Node
## Every PlatformRace sound plays through a named slot: PRSfx.play("crash").
##
## Placeholder sounds are generated here. To replace one, drop a file named
## after the slot into race/audio/sfx/ (e.g. crash.ogg or crash.wav) and it is
## used instead, with no code changes. Music works the same way: if
## race/audio/music.ogg (or .wav / .mp3) exists, it loops quietly during the race.

const SFX_DIR := "res://Minigames/PlatformRace/race/audio/sfx/"
const MUSIC_BASE := "res://Minigames/PlatformRace/race/audio/music"
const RATE := 22050
const VOICES := 10

## Slot → recipe. A recipe is a list of notes played one after the other:
## [start Hz, end Hz, seconds, wave, volume, noise amount].
## Waves: "sine", "square", "saw", "tri", "noise".
const RECIPES := {
	"click": [[900.0, 900.0, 0.035, "square", 0.18, 0.0]],
	"switch": [[520.0, 780.0, 0.07, "square", 0.22, 0.0], [780.0, 1040.0, 0.06, "square", 0.18, 0.0]],
	"lift": [[110.0, 150.0, 0.18, "saw", 0.22, 0.1]],
	"bridge": [[220.0, 90.0, 0.22, "tri", 0.35, 0.35]],
	"drop": [[1500.0, 420.0, 0.75, "sine", 0.16, 0.0]],
	"crash": [[180.0, 50.0, 0.38, "noise", 0.55, 1.0]],
	"stun": [[700.0, 260.0, 0.22, "tri", 0.4, 0.0], [1200.0, 1400.0, 0.08, "sine", 0.18, 0.0], [1400.0, 1200.0, 0.08, "sine", 0.18, 0.0]],
	"trap_warn": [[660.0, 660.0, 0.1, "square", 0.2, 0.0], [880.0, 880.0, 0.1, "square", 0.2, 0.0], [660.0, 660.0, 0.1, "square", 0.2, 0.0], [880.0, 880.0, 0.1, "square", 0.2, 0.0]],
	"crumble": [[140.0, 40.0, 0.55, "noise", 0.5, 1.0]],
	"gust": [[300.0, 200.0, 1.2, "noise", 0.28, 1.0]],
	"spikes": [[1400.0, 500.0, 0.12, "square", 0.25, 0.4], [300.0, 200.0, 0.1, "noise", 0.3, 1.0]],
	"checkpoint": [[523.0, 523.0, 0.08, "sine", 0.3, 0.0], [659.0, 659.0, 0.08, "sine", 0.3, 0.0], [784.0, 784.0, 0.16, "sine", 0.3, 0.0]],
	"spree": [[392.0, 392.0, 0.06, "square", 0.2, 0.0], [523.0, 523.0, 0.06, "square", 0.2, 0.0], [659.0, 659.0, 0.06, "square", 0.2, 0.0], [1046.0, 1046.0, 0.2, "square", 0.2, 0.0]],
	"boost": [[392.0, 523.0, 0.18, "sine", 0.3, 0.0], [523.0, 784.0, 0.18, "sine", 0.3, 0.0]],
	"countdown": [[660.0, 660.0, 0.14, "sine", 0.35, 0.0]],
	"go": [[990.0, 990.0, 0.35, "sine", 0.4, 0.0]],
	"win": [[523.0, 523.0, 0.12, "square", 0.22, 0.0], [659.0, 659.0, 0.12, "square", 0.22, 0.0], [784.0, 784.0, 0.12, "square", 0.22, 0.0], [1046.0, 1046.0, 0.4, "square", 0.22, 0.0]],
	"lose": [[392.0, 392.0, 0.18, "tri", 0.3, 0.0], [330.0, 330.0, 0.18, "tri", 0.3, 0.0], [262.0, 220.0, 0.4, "tri", 0.3, 0.0]],
	"mode_help": [[523.0, 784.0, 0.2, "sine", 0.32, 0.0]],
	"mode_hinder": [[330.0, 220.0, 0.25, "saw", 0.22, 0.0]],
	"respawn": [[300.0, 900.0, 0.3, "sine", 0.3, 0.0]],
	"ready": [[784.0, 1046.0, 0.1, "sine", 0.3, 0.0]],
}

var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}
var _music: AudioStreamPlayer


## Plays a slot from anywhere in the race scene (devices, traps, barrels).
static func emit(from: Node, slot: String, volume_db := 0.0, pitch_jitter := 0.0) -> void:
	if from == null or not from.is_inside_tree():
		return
	var s := from.get_tree().get_first_node_in_group(&"pr_sfx") as PRSfx
	if s:
		s.play(slot, volume_db, pitch_jitter)


func _ready() -> void:
	add_to_group(&"pr_sfx")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -14.0
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)


## Stops every sound and drops the cached streams, so nothing keeps playing
## (or stays referenced by the audio server) after the race scene is gone.
func _exit_tree() -> void:
	for p in _voices:
		p.stop()
		p.stream = null
	if _music:
		_music.stop()
		_music.stream = null
	_cache.clear()


## Plays a slot. pitch_jitter adds a little random pitch so repeats sound alive.
func play(slot: String, volume_db := 0.0, pitch_jitter := 0.0) -> void:
	var stream := get_stream(slot)
	if stream == null or not (stream is AudioStreamWAV):
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = stream
	p.volume_db = -6.0 + volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func get_stream(slot: String) -> AudioStream:
	if _cache.has(slot):
		return _cache[slot]
	var stream: AudioStream = null
	for ext: String in ["wav"]:
		var path := SFX_DIR + slot + "." + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_cache[slot] = stream
	return stream


func start_music() -> void:
	if _music.playing:
		return
	for ext: String in ["wav"]:
		var path := MUSIC_BASE + "." + ext
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamWAV:
				var wav := stream as AudioStreamWAV
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				var bytes_per_frame := (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
				@warning_ignore("integer_division")
				wav.loop_end = wav.data.size() / bytes_per_frame
				_music.stream = stream
				_music.play()
				return
				@warning_ignore("integer_division")
				wav.loop_end = wav.data.size() / bytes_per_frame
			_music.stream = stream
			_music.play()
			return


func stop_music() -> void:
	_music.stop()


# --- Placeholder synth -----------------------------------------------------------

static func _synth(notes: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for note in notes:
		var f0: float = note[0]
		var f1: float = note[1]
		var secs: float = note[2]
		var wave: String = note[3]
		var vol: float = note[4]
		var noise: float = note[5]
		var count := int(secs * RATE)
		var phase := 0.0
		var lp := 0.0
		for i in count:
			var t := float(i) / maxf(count - 1, 1)
			var freq := lerpf(f0, f1, t)
			phase = fmod(phase + freq / RATE, 1.0)
			var s := 0.0
			match wave:
				"sine":
					s = sin(phase * TAU)
				"square":
					s = 1.0 if phase < 0.5 else -1.0
				"saw":
					s = phase * 2.0 - 1.0
				"tri":
					s = 1.0 - 4.0 * absf(phase - 0.5)
				"noise":
					s = 0.0
			if noise > 0.0:
				# Low-passed noise; the cut-off follows the note's frequency.
				var k := clampf(freq / 2000.0, 0.02, 0.9)
				lp = lerpf(lp, randf_range(-1.0, 1.0), k)
				s = lerpf(s, lp * 2.0, noise)
			var attack := clampf(float(i) / (0.005 * RATE), 0.0, 1.0)
			var env := attack * pow(1.0 - t, 1.6)
			var v := clampi(int(s * vol * env * 32767.0), -32768, 32767)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
