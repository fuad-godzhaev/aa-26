class_name DiverHands
extends Node3D

# Parametric breaststroke hands. Consumes PlayerFly.swim_pose + stroke_phase. See ARCHITECTURE.md §5d.

@export var glide_z: float = -0.48          # hands fully extended forward
@export var chest_z: float = -0.14          # hands tucked under chest
@export var rest_x: float = 0.32            # idle-pose hand X at the side
@export var stroke_lateral_max: float = 0.40
@export var stroke_dip: float = 0.10
@export var pose_lerp: float = 8.0

var _diver: Node
var _smoothed_left := Transform3D.IDENTITY
var _smoothed_right := Transform3D.IDENTITY

@onready var _left := _make_hand()
@onready var _right := _make_hand()


func _ready() -> void:
	add_child(_left)
	add_child(_right)
	_diver = get_parent().get_parent() if get_parent() else null


func _process(delta: float) -> void:
	if _diver == null:
		return
	var pose: int = int(_diver.get("swim_pose"))
	var phase: float = float(_diver.get("stroke_phase"))
	var ex: float = float(_diver.get("exertion"))

	var lp := _hand_transform(pose, phase, ex, true)
	var rp := _hand_transform(pose, phase, ex, false)
	# Smooth across pose transitions so hands never pop.
	var k: float = clampf(pose_lerp * delta, 0.0, 1.0)
	_smoothed_left = _smoothed_left.interpolate_with(lp, k)
	_smoothed_right = _smoothed_right.interpolate_with(rp, k)
	_left.transform = _smoothed_left
	_right.transform = _smoothed_right


# sx mirrors X for left vs right hand.
func _hand_transform(pose: int, phase: float, ex: float, is_left: bool) -> Transform3D:
	var sx: float = -1.0 if is_left else 1.0
	match pose:
		PlayerFly.SwimPose.FORWARD:
			return _breaststroke(phase, sx, 1.0, ex)
		PlayerFly.SwimPose.BACK:
			# Same path reversed in time + wider — pushes water forward to reverse.
			return _breaststroke(fposmod(1.0 - phase, 1.0), sx, 1.18, ex * 0.7)
		PlayerFly.SwimPose.LEFT, PlayerFly.SwimPose.RIGHT:
			# Side strokes use idle drift; the visible side motion is PlayerFly's roll lean.
			return _idle_drift(phase, sx)
	return _idle_drift(phase, sx)


# Phase 0..0.5 = stroke (out-sweep + in-sweep); 0.5..1.0 = recovery (hands together, shoot forward).
func _breaststroke(phase: float, sx: float, lateral_mult: float, ex: float) -> Transform3D:
	var lat_max: float = stroke_lateral_max * lateral_mult
	var x_norm: float
	var z_norm: float
	if phase < 0.5:
		var sp: float = phase * 2.0
		x_norm = sin(sp * PI)
		z_norm = sp
	else:
		var rp: float = (phase - 0.5) * 2.0
		x_norm = 0.10
		z_norm = 1.0 - rp
	var t := Transform3D.IDENTITY
	t.origin = Vector3(
		sx * (0.06 + x_norm * (lat_max - 0.06)),
		-0.30 - x_norm * stroke_dip,
		lerpf(glide_z, chest_z, z_norm),
	)
	var wrist_pitch := deg_to_rad(-15.0 + x_norm * 40.0)
	var wrist_yaw := deg_to_rad(20.0 * sx * x_norm)
	t.basis = Basis.from_euler(Vector3(wrist_pitch, wrist_yaw, deg_to_rad(-6.0 * sx)))
	return t


# Slow drift with hands at sides; used for IDLE and side strokes.
func _idle_drift(phase: float, sx: float) -> Transform3D:
	var theta: float = phase * TAU
	var sway_x: float = sin(theta + (PI if sx < 0.0 else 0.0)) * 0.025
	var sway_y: float = cos(theta * 0.7 + (PI if sx < 0.0 else 0.0)) * 0.015
	var t := Transform3D.IDENTITY
	t.origin = Vector3(
		sx * (rest_x + sway_x),
		-0.30 + sway_y,
		0.04,
	)
	t.basis = Basis.from_euler(Vector3(deg_to_rad(-10.0), deg_to_rad(12.0 * sx), 0.0))
	return t


# Forearm cylinder + fist sphere; muted wetsuit blue.
func _make_hand() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.36, 0.5, 1.0)
	mat.metallic = 0.05
	mat.roughness = 0.45
	var arm := CSGCylinder3D.new()
	arm.radius = 0.045
	arm.height = 0.36
	arm.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	arm.position = Vector3(0.0, 0.0, 0.18)
	arm.material = mat
	root.add_child(arm)
	var hand := CSGSphere3D.new()
	hand.radius = 0.07
	hand.position = Vector3.ZERO
	hand.material = mat
	root.add_child(hand)
	return root
