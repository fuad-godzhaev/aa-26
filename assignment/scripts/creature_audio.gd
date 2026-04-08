class_name CreatureAudio
extends Node3D

# State-driven 3D audio. One looping voice whose stream follows the BT
# mode. Streams are PLACEHOLDER_*.wav silent stubs (see
# assignment/audio/SOUNDS.md) — swap for real samples, no code change.

const MODE_SOUND := {
	"wander": "breathing",
	"investigate": "curious",
	"flee": "wary",
	"rest": "rest",
}

var _player: AudioStreamPlayer3D
var _streams: Dictionary = {}


func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.unit_size = 6.0
	add_child(_player)
	for mode in MODE_SOUND:
		_streams[mode] = _try_load(MODE_SOUND[mode])


func _try_load(snd: String) -> AudioStream:
	var path := "res://assignment/audio/PLACEHOLDER_%s.wav" % snd
	if not ResourceLoader.exists(path):
		return null
	var s: Resource = load(path)
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return s as AudioStream


func set_mode(mode: String) -> void:
	var s: AudioStream = _streams.get(mode, null)
	if s == null:
		_player.stop()
		return
	if _player.stream == s and _player.playing:
		return
	_player.stream = s
	_player.play()
