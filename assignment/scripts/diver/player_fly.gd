class_name PlayerFly
extends CharacterBody3D

# Embodied diver: input -> body motion via move_and_slide + camera modulation + spawns rig children. See ARCHITECTURE.md §5d.

const DIVER_BREATHING := preload("res://assignment/scripts/diver/diver_breathing.gd")
const DIVER_HANDS := preload("res://assignment/scripts/diver/diver_hands.gd")
const DIVER_GOGGLES := preload("res://assignment/scripts/diver/diver_goggles.gd")

enum SwimPose { IDLE, FORWARD, BACK, LEFT, RIGHT }

@export var move_speed: float = 4.5
@export var boost_mult: float = 2.0
@export var look_sensitivity: float = 0.0025
@export var accel: float = 5.5
@export var drag: float = 1.4
@export var idle_bob_amp: float = 0.04
@export var stroke_bob_amp: float = 0.075
@export var stroke_roll_amp: float = 0.035
@export var breath_lift_amp: float = 0.035
@export var lean_response: float = 2.5
@export var lean_pitch_forward: float = -0.18
@export var lean_pitch_back: float = 0.14
@export var lean_roll_side: float = 0.26
@export var stroke_speed_idle: float = 0.4
@export var stroke_speed_forward: float = 1.2
@export var stroke_speed_back: float = 0.8
@export var stroke_speed_side: float = 0.55
@export var underwater_cutoff_hz: float = 1800.0
@export var fog_density_shallow: float = 0.025
@export var fog_density_deep: float = 0.06
# Vertical span (m) from surface down to the deepest seabed, used to scale depth fog.
@export var fog_depth_span: float = 30.0
# Below this Y the depth gradient kicks in; above it the diver is in air.
@export var surface_y: float = 0.0
@export var fog_density_above_water: float = 0.004
# Hard clamp on swim altitude. Allow the diver's head to poke through (head_poke meters above surface) but no flying further.
@export var head_poke: float = 0.5
# Backstop just below the deepest seabed (-30); terrain collision is the real floor.
@export var min_swim_y: float = -31.0

@export_group("Goggles")
@export var goggles_visible: bool = true
# Lens half-axes in aspect-compensated UV; defaults sized so the dark mask covers ~10% of the screen.
@export var goggles_lens_size: Vector2 = Vector2(0.56, 0.66)
# Distance from screen centre to each lens centre (compensated UV).
@export var goggles_lens_offset: float = 0.32
@export var goggles_feather: float = 0.06
@export var goggles_mask_color: Color = Color(0.012, 0.018, 0.022, 1.0)

# Local-frame intent (+x right, +y up, +z forward). Read by DiverHands.
var input_axes: Vector3 = Vector3.ZERO
# `velocity` is inherited from CharacterBody3D and read by move_and_slide.
# Smoothed 0..1 load drives breath rate, stroke speed bias, bob amplitude.
var exertion: float = 0.0
var is_sprinting: bool = false
# One of SwimPose, classified each frame from input_axes.
var swim_pose: int = SwimPose.IDLE
# Breaststroke cycle progress; wraps 0..1 at the pose-dependent Hz.
var stroke_phase: float = 0.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _idle_t: float = 0.0
var _lean_pitch: float = 0.0
var _lean_roll: float = 0.0
var _breath: Node
var _goggles: Node
var _env: WorldEnvironment
var _settings

@onready var _cam := get_node_or_null("Camera3D") as Camera3D
@onready var _cam_base_pos: Vector3 = _cam.position if _cam else Vector3.ZERO
@onready var _cam_base_rot: Vector3 = _cam.rotation if _cam else Vector3.ZERO


func _ready() -> void:
	# Mouse capture + ESC are owned by the pause menu now.
	_install_underwater_bus()
	_env = _find_env(get_tree().current_scene)
	var ocean = get_node_or_null("/root/Ocean")
	if ocean:
		surface_y = ocean.SURFACE_Y
		min_swim_y = ocean.SEABED_Y - 1.0
		fog_depth_span = ocean.SURFACE_Y - ocean.SEABED_Y
	_settings = get_node_or_null("/root/Settings")
	if _settings:
		_settings.changed.connect(_apply_settings)
	if _cam:
		_breath = DIVER_BREATHING.new()
		_cam.add_child(_breath)
		_cam.add_child(DIVER_HANDS.new())
	_goggles = DIVER_GOGGLES.new()
	_goggles.set("lens_size", goggles_lens_size)
	_goggles.set("lens_offset", goggles_lens_offset)
	_goggles.set("feather", goggles_feather)
	_goggles.set("mask_color", goggles_mask_color)
	_goggles.visible = goggles_visible
	add_child(_goggles)
	_apply_settings()


# Pull FOV + look sensitivity from the Settings autoload (no-op if absent).
func _apply_settings() -> void:
	if _settings == null:
		return
	look_sensitivity = _settings.look_sensitivity
	if _cam:
		_cam.fov = _settings.fov


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clampf(_pitch - event.relative.y * look_sensitivity, -1.4, 1.4)
		rotation = Vector3(_pitch, _yaw, 0.0)


func _physics_process(delta: float) -> void:
	_read_input()
	is_sprinting = Input.is_key_pressed(KEY_SHIFT)

	var dir := transform.basis.x * input_axes.x \
		+ Vector3.UP * input_axes.y \
		- transform.basis.z * input_axes.z
	if dir.length_squared() > 0.0001:
		dir = dir.normalized()
	var spd := move_speed * (boost_mult if is_sprinting else 1.0)
	var desired := dir * spd

	velocity = velocity.lerp(desired, clampf(accel * delta, 0.0, 1.0))
	if dir.length_squared() < 0.0001:
		velocity = velocity.lerp(Vector3.ZERO, clampf(drag * delta, 0.0, 1.0))
	# move_and_slide integrates by `velocity` and resolves collisions with
	# the floor + kelp colliders; velocity is updated to the post-slide value.
	move_and_slide()
	# Clamp swim altitude after movement so the diver can poke their head out at the surface but can't actually fly.
	var max_y: float = surface_y + head_poke
	if global_position.y > max_y:
		global_position.y = max_y
		if velocity.y > 0.0:
			velocity.y = 0.0
	elif global_position.y < min_swim_y:
		global_position.y = min_swim_y
		if velocity.y < 0.0:
			velocity.y = 0.0

	var effort: float = clampf(velocity.length() / maxf(move_speed, 0.001), 0.0, 1.0)
	if is_sprinting:
		effort = clampf(effort * 1.25, 0.0, 1.0)
	exertion = lerpf(exertion, effort, clampf(delta * 1.8, 0.0, 1.0))

	swim_pose = _classify_pose(input_axes)
	stroke_phase = fposmod(stroke_phase + _stroke_hz() * delta, 1.0)

	_apply_camera(delta)
	_apply_depth_fog()


func _read_input() -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		v.z += 1.0
	if Input.is_key_pressed(KEY_S):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_key_pressed(KEY_E):
		v.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		v.y -= 1.0
	input_axes = v


# Vertical-only input (Q/E) reads as IDLE so we don't carry a side-lean while just ascending/descending.
func _classify_pose(axes: Vector3) -> int:
	var horiz := Vector2(axes.x, axes.z)
	if horiz.length_squared() < 0.001:
		return SwimPose.IDLE
	if absf(axes.z) >= absf(axes.x):
		return SwimPose.FORWARD if axes.z > 0.0 else SwimPose.BACK
	return SwimPose.RIGHT if axes.x > 0.0 else SwimPose.LEFT


func _stroke_hz() -> float:
	match swim_pose:
		SwimPose.FORWARD:
			return stroke_speed_forward + exertion * 0.6
		SwimPose.BACK:
			return stroke_speed_back
		SwimPose.LEFT, SwimPose.RIGHT:
			return stroke_speed_side
	return stroke_speed_idle


# Target (pitch, roll) lean per pose; mouse stays authoritative for look direction.
func _lean_target() -> Vector2:
	match swim_pose:
		SwimPose.FORWARD:
			return Vector2(lean_pitch_forward, 0.0)
		SwimPose.BACK:
			return Vector2(lean_pitch_back, 0.0)
		SwimPose.LEFT:
			return Vector2(0.0, lean_roll_side)
		SwimPose.RIGHT:
			return Vector2(0.0, -lean_roll_side)
	return Vector2.ZERO


# Stroke-coupled bob + breath lift + pose lean on the camera's base local transform.
func _apply_camera(delta: float) -> void:
	if _cam == null:
		return

	var tgt := _lean_target()
	var k: float = clampf(lean_response * delta, 0.0, 1.0)
	_lean_pitch = lerpf(_lean_pitch, tgt.x, k)
	_lean_roll = lerpf(_lean_roll, tgt.y, k)

	var bp: float = 0.0
	if _breath and _breath.has_method("phase"):
		bp = float(_breath.call("phase"))
	var breath_lift := sin(bp * TAU) * breath_lift_amp * (0.6 + 0.4 * exertion)

	var theta: float = stroke_phase * TAU
	var move_mix: float = clampf(exertion * 2.0, 0.0, 1.0)
	var stroke_bob_y: float = sin(theta) * stroke_bob_amp * move_mix
	var stroke_roll_z: float = cos(theta) * stroke_roll_amp * move_mix

	_idle_t += delta * 0.7
	var idle_bob_y: float = sin(_idle_t) * idle_bob_amp * (1.0 - move_mix)

	_cam.position = _cam_base_pos + Vector3(0.0, idle_bob_y + stroke_bob_y + breath_lift, 0.0)
	_cam.rotation = _cam_base_rot + Vector3(_lean_pitch, 0.0, _lean_roll + stroke_roll_z)


func _apply_depth_fog() -> void:
	if _env == null or _env.environment == null:
		return
	# Above the water surface: thin air-fog (SurfaceTransition still handles the audio + splash events).
	if global_position.y > surface_y:
		_env.environment.fog_density = fog_density_above_water
		return
	# 0 at the surface, 1 at the deepest seabed.
	var depth: float = clampf((surface_y - global_position.y) / fog_depth_span, 0.0, 1.0)
	_env.environment.fog_density = lerpf(fog_density_shallow, fog_density_deep, depth)


# Idempotent: adds a low-pass to the Master bus at runtime so no .tres edit is needed.
func _install_underwater_bus() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter:
			return
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = underwater_cutoff_hz
	AudioServer.add_bus_effect(bus, lp)


func _find_env(n: Node) -> WorldEnvironment:
	if n is WorldEnvironment:
		return n
	for c in n.get_children():
		var r := _find_env(c)
		if r:
			return r
	return null
