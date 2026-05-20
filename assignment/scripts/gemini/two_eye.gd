class_name TwoEye
extends SteeringAgent

# One half of the Gemini. It is "dumb": GeminiController issues a command
# (mode + target + aux) every frame and TwoEye just steers to satisfy it.
# Roles only differ in colour + which commands the controller sends.

enum Role { STRIKER, DISTRACTOR }

@export var glow_material: ShaderMaterial

# Swim cycle constants: 0.6 s loop, tail yaw ±12 deg, mid yaw ±6 deg, mid offset ~90 deg.
const SWIM_RATE := 10.472
const SWIM_TAIL_AMP := 0.20944
const SWIM_MID_AMP := 0.10472
const SWIM_MID_PHASE := 1.5708

var role: int = Role.STRIKER
var cmd_mode: String = "dock"          # dock | lure | strike | free
var cmd_target: Vector3 = Vector3.ZERO
var cmd_aux: Vector3 = Vector3.ZERO    # strike: target velocity to lead

var _wander := SteeringBehaviors.WanderState.new()
var _weave: float = 0.0
var _disp_t: float = 0.0
var _swim_t: float = 0.0
var _tail_bone: int = -1
var _mid_bone: int = -1

@onready var _disp_body := get_node_or_null("Body") as Node3D
@onready var _skel := get_node_or_null("Body/Skeleton3D") as Skeleton3D
@onready var _body_mesh := get_node_or_null("Body/BodyMesh") as MeshInstance3D


func _ready() -> void:
	add_to_group("gemini_half")
	# Bind the procedural foureye ArrayMesh to the skinned MeshInstance3D.
	if _body_mesh != null:
		_body_mesh.mesh = TwoEyeMesh.build()
	# Cache bone indices for cheap per-frame skeletal swim pose updates.
	if _skel != null:
		_tail_bone = _skel.find_bone("tail")
		_mid_bone = _skel.find_bone("mid")


# Mating-dance Z-roll + skeletal swim yaw cycle.
func _process(delta: float) -> void:
	_disp_t += delta * (12.0 if cmd_mode == "lure" else 3.0)
	_swim_t += delta
	if _disp_body != null:
		var luring := cmd_mode == "lure"
		_disp_body.rotation.z = sin(_disp_t) * (0.5 if luring else 0.04)
	# Skeletal swim: sinusoidal yaw on tail + mid bones, mid offset by ~90 deg.
	if _skel != null:
		var phase: float = _swim_t * SWIM_RATE
		if _tail_bone >= 0:
			_skel.set_bone_pose_rotation(_tail_bone, Quaternion(Vector3.UP, sin(phase) * SWIM_TAIL_AMP))
		if _mid_bone >= 0:
			_skel.set_bone_pose_rotation(_mid_bone, Quaternion(Vector3.UP, sin(phase + SWIM_MID_PHASE) * SWIM_MID_AMP))


func _compute_steering(delta: float) -> Vector3:
	match cmd_mode:
		"dock":
			return SteeringBehaviors.arrive(global_position, cmd_target, velocity, max_speed, 1.5) * 2.0
		"lure":
			# Hover just off the prey and weave to mesmerise it. The weave
			# axis is WORLD-space (perpendicular to the approach), not the
			# body basis — using global_basis.x fed orientation back into
			# the weave and made Pollux spin.
			_weave += delta * 3.0
			var base := SteeringBehaviors.arrive(global_position, cmd_target, velocity, max_speed, 2.0)
			var to_t := cmd_target - global_position
			var lateral := to_t.cross(Vector3.UP)
			if lateral.length() < 0.01:
				lateral = Vector3.RIGHT
			return base + lateral.normalized() * sin(_weave) * max_speed * 0.3
		"strike":
			return SteeringBehaviors.pursue(global_position, velocity, max_speed, cmd_target, cmd_aux) * 1.6
		_:
			return SteeringBehaviors.wander3d(_wander, forward(), velocity, max_speed, delta)


func set_glow(base_col: Color, glow_col: Color, pulse_speed: float, pulse_strength: float) -> void:
	if glow_material == null:
		return
	glow_material.set_shader_parameter("base_color", base_col)
	glow_material.set_shader_parameter("glow_color", glow_col)
	glow_material.set_shader_parameter("pulse_speed", pulse_speed)
	glow_material.set_shader_parameter("pulse_strength", pulse_strength)
