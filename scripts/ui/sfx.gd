class_name Sfx
extends Node
## Small sound bank synthesised at startup, so the game ships no audio files.

const MIX_RATE := 22050
const VOICES := 8

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	_sounds["card"] = _tone(170.0, 0.07, 55.0, 0.75)
	_sounds["tick"] = _tone(880.0, 0.11, 30.0, 0.0)
	_sounds["thud"] = _tone(95.0, 0.2, 18.0, 0.25)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(sound: String, pitch: float = 1.0, volume_db: float = -8.0) -> void:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % VOICES
	player.stream = _sounds[sound]
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


## Plays a tap with a little variation so repeated cards don't sound robotic.
func card_tap() -> void:
	play("card", randf_range(0.85, 1.2), -12.0)


func _tone(frequency: float, duration: float, decay: float, noise: float) -> AudioStreamWAV:
	var sample_count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / MIX_RATE
		var wave := sin(TAU * frequency * t) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		data.encode_s16(i * 2, int(clampf(wave * exp(-t * decay), -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream
