class_name TwoEye
extends SteeringAgent

# One half of the Gemini. It is "dumb": GeminiController issues a command
# (mode + target + aux) every frame and TwoEye just steers to satisfy it.
# Roles only differ in colour + which commands the controller sends.

enum Role { STRIKER, DISTRACTOR }

# Optional pre-authored glow material. If left null a UNIQUE one is built per
# instance at _ready, so Castor amber and Pollux cyan never share + fight.
@export var glow_material: ShaderMaterial
# Rotate the visual so its nose runs down the agent forward (-Z). The castor /
# pollux meshes are modelled along +X, so 90 deg; the old single mesh = 0.
@export var model_yaw_deg: float = 0.0
# The old two_eye used ONE mesh for both halves and flipped the lower one
# belly-up. castor/pollux are separate, already-correct models, so leave off.
@export var invert_when_distractor: bool = false

const GLOW_SHADER := preload("res://assignment/assets/shaders/glow.gdshader")

# Skeletal swim constants (used only if the model actually has a skeleton).
const SWIM_RATE := 10.472
const SWIM_TAIL_AMP := 0.20944
const SWIM_MID_AMP := 0.10472
const SWIM_MID_PHASE := 1.5708
# Gentle whole-body yaw wag for static (boneless) halves so they still feel alive.
const WAG_RATE := 6.0
const WAG_AMP := 0.06

var role: int = Role.STRIKER: set = _set_role
var cmd_mode: String = "dock"          # dock | lure | strike | free
var cmd_target: Vector3 = Vector3.ZERO
var cmd_aux: Vector3 = Vector3.ZERO    # strike: target velocity to lead

var _wander := SteeringBehaviors.WanderState.new()
var _weave: float = 0.0
var _disp_t: float = 0.0
var _swim_t: float = 0.0
var _tail_bone: int = -1
var _mid_bone: int = -1
var _base_yaw: float = 0.0

var _disp_body: Node3D
var _skel: Skeleton3D
var _glow_parts: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("gemini_half")
	# Visual wrapper = the model root (first Node3D child), e.g. the glb instance.
	for c in get_children():
		if c is Node3D:
			_disp_body = c as Node3D
			break
	_base_yaw = deg_to_rad(model_yaw_deg)
	# Build a unique glow material unless one was authored in the scene.
	if glow_material == null:
		glow_material = ShaderMaterial.new()
		glow_material.shader = GLOW_SHADER
	# Apply the role glow to the lume parts (body, fins, eyes, esca); leave the
	# structural teeth / illicium with their imported material.
	for m in _find_meshes(self):
		var nm := m.name.to_lower()
		if nm.contains("teeth") or nm.contains("illicium"):
			continue
		m.material_override = glow_material
		_glow_parts.append(m)
	# Skeleton is optional (the castor/pollux halves are static meshes).
	_skel = _find_skeleton(self)
	if _skel != null:
		_tail_bone = _skel.find_bone("tail")
		_mid_bone = _skel.find_bone("mid")
	_apply_role_orientation()


# Pollux swims inverted: roll 180 deg around the body's forward axis so dorsal points
# down + belly points up + forward direction stays the same. Using rotation.x = PI would
# also flip the forward axis, leaving Pollux facing backward relative to Castor.
func _apply_role_orientation() -> void:
	if _disp_body == null:
		return
	var roll: float = PI if (invert_when_distractor and role == Role.DISTRACTOR) else 0.0
	_disp_body.rotation = Vector3(0.0, _base_yaw, roll)


func _set_role(value: int) -> void:
	role = value
	# Role may be assigned before or after _ready; re-apply on every change.
	if is_inside_tree():
		_apply_role_orientation()


# Mating-dance Z-roll + skeletal swim yaw cycle.
func _process(delta: float) -> void:
	_disp_t += delta * (12.0 if cmd_mode == "lure" else 3.0)
	_swim_t += delta
	if _disp_body != null:
		var luring := cmd_mode == "lure"
		# Lure mating-dance Z-roll.
		_disp_body.rotation.z = sin(_disp_t) * (0.5 if luring else 0.04)
		# Static (boneless) halves: wag the whole body in yaw so it still swims.
		if _skel == null:
			_disp_body.rotation.y = _base_yaw + sin(_swim_t * WAG_RATE) * WAG_AMP
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


func _find_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in _walk(n):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append(c as MeshInstance3D)
	return out


func _find_skeleton(n: Node) -> Skeleton3D:
	for c in _walk(n):
		if c is Skeleton3D:
			return c as Skeleton3D
	return null


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
