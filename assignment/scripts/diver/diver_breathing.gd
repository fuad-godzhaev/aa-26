class_name DiverBreathing
extends Node3D

# Breath cycle generator + regulator SFX + exhale bubbles. See ARCHITECTURE.md §5d.

const BREATH_IN_PATH := "res://assignment/audio/PLACEHOLDER_breath_in.wav"
const BREATH_OUT_PATH := "res://assignment/audio/PLACEHOLDER_breath_out.wav"

@export var idle_period: float = 4.8
@export var sprint_period: float = 1.9
@export var bubble_count: int = 16
@export var bubble_lifetime: float = 1.6
# Mask position offset relative to camera origin (down + slightly forward).
@export var mask_offset: Vector3 = Vector3(0.0, -0.06, -0.22)

var _phase: float = 0.0
var _prev_phase: float = 0.0
var _diver: Node
var _in_stream: AudioStream
var _out_stream: AudioStream

@onready var _audio := AudioStreamPlayer3D.new()
@onready var _bubbles := _make_bubbles()


func _ready() -> void:
	add_child(_audio)
	add_child(_bubbles)
	_bubbles.position = mask_offset
	_audio.position = mask_offset
	# get_parent() = Camera3D; its parent = PlayerFly.
	_diver = get_parent().get_parent() if get_parent() else null
	# Tolerant load so a missing placeholder never trips --check-only.
	if ResourceLoader.exists(BREATH_IN_PATH):
		_in_stream = load(BREATH_IN_PATH)
	if ResourceLoader.exists(BREATH_OUT_PATH):
		_out_stream = load(BREATH_OUT_PATH)


# Phase: 0=inhale onset, 0.5=exhale onset, wraps. Read by PlayerFly for camera lift.
func phase() -> float:
	return _phase


func _process(delta: float) -> void:
	var ex: float = 0.0
	if _diver and "exertion" in _diver:
		ex = float(_diver.get("exertion"))
	var period: float = lerpf(idle_period, sprint_period, ex)
	_prev_phase = _phase
	_phase = fposmod(_phase + delta / maxf(period, 0.1), 1.0)

	# Crossing 0.5 = exhale onset; wrapping past 1.0 = inhale onset.
	if _prev_phase < 0.5 and _phase >= 0.5:
		_beat_exhale(ex)
	if _prev_phase > _phase:
		_beat_inhale(ex)


func _beat_inhale(ex: float) -> void:
	if _in_stream:
		_audio.stream = _in_stream
		_audio.volume_db = lerpf(-14.0, -3.0, ex)
		_audio.play()


func _beat_exhale(ex: float) -> void:
	if _out_stream:
		_audio.stream = _out_stream
		_audio.volume_db = lerpf(-14.0, -3.0, ex)
		_audio.play()
	_bubbles.restart()
	_bubbles.emitting = true


func _make_bubbles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	# World-space upward "gravity" so bubbles rise regardless of head tilt.
	m.gravity = Vector3(0.0, 1.4, 0.0)
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 22.0
	m.initial_velocity_min = 0.4
	m.initial_velocity_max = 0.9
	m.damping_min = 0.6
	m.damping_max = 1.0
	m.scale_min = 0.4
	m.scale_max = 1.0
	m.scale_curve = _scale_curve()
	p.process_material = m
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.amount = bubble_count
	p.lifetime = bubble_lifetime
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.emitting = false
	return p


func _scale_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.5))
	c.add_point(Vector2(1.0, 1.8))
	var t := CurveTexture.new()
	t.curve = c
	return t
