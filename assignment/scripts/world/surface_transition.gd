class_name SurfaceTransition
extends Node3D

# Detect the diver crossing the water-surface plane and toggle the at-the-surface effects: Master-bus low-pass on/off + splash GPUParticles3D + placeholder splash SFX. Fog is owned by PlayerFly (it handles the above-vs-under branch by depth). See ARCHITECTURE.md §5e + §9.

# TODO(placeholder): replace PLACEHOLDER_splash.wav with a real splash/foley sample.
const SPLASH_PATH := "res://assignment/audio/PLACEHOLDER_splash.wav"

@export var surface_y: float = 18.0
@export var hysteresis: float = 0.4
@export var splash_count: int = 80
@export var splash_lifetime: float = 1.2

var _player: Node3D
var _is_underwater: bool = true
var _bus: int = -1
var _lp_idx: int = -1
var _splash_stream: AudioStream

@onready var _splash_audio := AudioStreamPlayer3D.new()


func _ready() -> void:
	add_child(_splash_audio)
	_bus = AudioServer.get_bus_index("Master")
	if _bus >= 0:
		for i in AudioServer.get_bus_effect_count(_bus):
			if AudioServer.get_bus_effect(_bus, i) is AudioEffectLowPassFilter:
				_lp_idx = i
				break
	if ResourceLoader.exists(SPLASH_PATH):
		_splash_stream = load(SPLASH_PATH)
	# Player joins the "player" group from GeminiController's _setup, which is deferred — retry until it shows up.
	call_deferred("_resolve_player")


func _resolve_player() -> void:
	var ps := get_tree().get_nodes_in_group("player")
	if not ps.is_empty() and ps[0] is Node3D:
		_player = ps[0]
		_is_underwater = _player.global_position.y < surface_y


func _process(_delta: float) -> void:
	if _player == null:
		_resolve_player()
		return
	var y: float = _player.global_position.y
	if _is_underwater and y > surface_y + hysteresis:
		_go_above()
	elif not _is_underwater and y < surface_y - hysteresis:
		_go_under()


# Player just broke the surface from below: kill the underwater low-pass + splash.
func _go_above() -> void:
	_is_underwater = false
	_set_lowpass(false)
	_emit_splash()


# Player dropped back below the surface: re-enable the underwater low-pass + splash.
func _go_under() -> void:
	_is_underwater = true
	_set_lowpass(true)
	_emit_splash()


func _set_lowpass(enable: bool) -> void:
	if _bus < 0 or _lp_idx < 0:
		return
	AudioServer.set_bus_effect_enabled(_bus, _lp_idx, enable)


func _emit_splash() -> void:
	if _player == null:
		return
	var at := Vector3(_player.global_position.x, surface_y, _player.global_position.z)
	_play_splash(at)
	_spawn_splash(at)


func _play_splash(at: Vector3) -> void:
	if _splash_stream == null:
		return
	_splash_audio.global_position = at
	_splash_audio.stream = _splash_stream
	_splash_audio.play()


# One-shot upward burst of small white spheres; queue_free after a couple of seconds.
func _spawn_splash(at: Vector3) -> void:
	var fx := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 28.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 6.0
	m.gravity = Vector3(0.0, -8.0, 0.0)
	m.scale_min = 0.4
	m.scale_max = 1.0
	fx.process_material = m
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.96, 1.0, 0.9)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	fx.draw_pass_1 = mesh
	fx.amount = splash_count
	fx.lifetime = splash_lifetime
	fx.one_shot = true
	fx.explosiveness = 0.95
	fx.emitting = true
	get_tree().current_scene.add_child(fx)
	fx.global_position = at
	get_tree().create_timer(splash_lifetime + 1.0).timeout.connect(fx.queue_free)
