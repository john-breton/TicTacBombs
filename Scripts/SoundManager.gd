extends Node

## Procedural sound effects manager — autoloaded as "SoundManager".
## Generates short synth sounds in memory (no .wav files needed).

var _players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS = 8


func _ready():
	for i in range(MAX_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]  # Fallback: reuse first


# ============================================================
#  PUBLIC API
# ============================================================

func play_place_mark():
	if not GameSettings.sound_enabled: return
	_play_tone(600.0, 0.06, -6.0, 0.0)

func play_bomb_found():
	if not GameSettings.sound_enabled: return
	_play_tone(500.0, 0.08, -4.0, 0.0)
	_play_tone(750.0, 0.12, -4.0, 0.09)

func play_explosion():
	if not GameSettings.sound_enabled: return
	_play_noise(0.25, -3.0, 0.0)

func play_gravity_land():
	if not GameSettings.sound_enabled: return
	_play_tone(150.0, 0.08, -8.0, 0.0)

func play_win():
	if not GameSettings.sound_enabled: return
	_play_tone(440.0, 0.12, -5.0, 0.0)
	_play_tone(554.0, 0.12, -5.0, 0.12)
	_play_tone(659.0, 0.12, -5.0, 0.24)
	_play_tone(880.0, 0.2, -4.0, 0.36)

func play_draw():
	if not GameSettings.sound_enabled: return
	_play_tone(400.0, 0.15, -5.0, 0.0)
	_play_tone(300.0, 0.2, -5.0, 0.15)

func play_bomb_arm():
	if not GameSettings.sound_enabled: return
	_play_tone(350.0, 0.1, -6.0, 0.0)

func play_bomb_cancel():
	if not GameSettings.sound_enabled: return
	_play_tone(250.0, 0.08, -8.0, 0.0)


# ============================================================
#  SYNTHESIS
# ============================================================

func _play_tone(freq: float, duration: float, volume_db: float, delay: float):
	if delay > 0:
		await get_tree().create_timer(delay).timeout

	var sample_rate = 22050
	var num_samples = int(sample_rate * duration)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var data = PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t = float(i) / sample_rate
		var envelope = 1.0 - (float(i) / num_samples)  # Linear decay
		envelope = envelope * envelope  # Exponential feel
		var sample = sin(t * freq * TAU) * envelope
		# 8-bit: 0-255 with 128 as center
		data[i] = int(clamp(sample * 100 + 128, 0, 255))

	stream.data = data

	var player = _get_free_player()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _play_noise(duration: float, volume_db: float, delay: float):
	if delay > 0:
		await get_tree().create_timer(delay).timeout

	var sample_rate = 22050
	var num_samples = int(sample_rate * duration)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var data = PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var envelope = 1.0 - (float(i) / num_samples)
		envelope = pow(envelope, 3.0)  # Quick decay for explosion feel
		# Mix noise with low rumble
		var t = float(i) / sample_rate
		var noise = randf_range(-1.0, 1.0)
		var rumble = sin(t * 80.0 * TAU)
		var sample = (noise * 0.6 + rumble * 0.4) * envelope
		data[i] = int(clamp(sample * 100 + 128, 0, 255))

	stream.data = data

	var player = _get_free_player()
	player.stream = stream
	player.volume_db = volume_db
	player.play()
