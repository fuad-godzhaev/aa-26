class_name CreatureAudio
extends Node3D

# State-driven 3D creature voice. One looping whale-song stream (CC0 — Wikimedia
# Commons "Humpbackwhale2.ogg") whose PITCH shifts with the BT mode, played from
# an AudioStreamPlayer3D so it loudens as Gemini nears the diver.

const VOICE_PATH := "res://assignment/audio/gemini_voice.ogg"

# Per-mode pitch so each behaviour reads a little different on the one sample.
const MODE_PITCH := {
	"wander": 1.0,
	"investigate": 1.12,   # curious: brighter
	"flee": 0.85,          # wary / hunting: lower, ominous
	"rest": 0.8,           # calm, slow
}

var _player: AudioStreamPlayer3D
var _voice: AudioStream


func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.unit_size = 8.0
	_player.max_distance = 40.0
	_player.volume_db = -5.0
	add_child(_player)
	if ResourceLoader.exists(VOICE_PATH):
		_voice = load(VOICE_PATH)
		if _voice is AudioStreamOggVorbis:
			(_voice as AudioStreamOggVorbis).loop = true
		_player.stream = _voice


func set_mode(mode: String) -> void:
	if _voice == null:
		return
	_player.pitch_scale = MODE_PITCH.get(mode, 1.0)
	if not _player.playing:
		_player.play()
