class_name EyeTracker
extends Node3D

# Per-eye tracker: smoothly look at nearest "player"/"prey" target inside radius.
# Falls back to a small idle yaw wobble when no target is in range.

@export var track_radius: float = 18.0
@export var rotation_speed: float = 4.0
@export var groups: Array[String] = ["player", "prey"]
@export var idle_wobble_amount: float = 0.04
@export var idle_wobble_speed: float = 0.7

# Local accumulator for the idle wobble sine.
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta

	# Find nearest Node3D member across all configured groups within radius.
	var nearest: Node3D = null
	var nearest_d2: float = track_radius * track_radius
	var my_pos: Vector3 = global_position
	for g in groups:
		for n in get_tree().get_nodes_in_group(g):
			var t3 := n as Node3D
			if t3 == null:
				continue
			if t3 == self:
				continue
			var d2: float = my_pos.distance_squared_to(t3.global_position)
			if d2 < nearest_d2:
				nearest_d2 = d2
				nearest = t3

	# Weight in [0,1]; smoothing factor for the per-frame slerp.
	var w: float = clamp(rotation_speed * delta, 0.0, 1.0)

	# Parent's global basis is used to convert a desired global basis into our local space.
	# transform.basis is stored in PARENT-local coords; computing the look in global coords
	# and inverse-multiplying by the parent's global basis gives the equivalent local basis.
	var parent_global_basis: Basis = Basis.IDENTITY
	var p := get_parent()
	if p is Node3D:
		parent_global_basis = (p as Node3D).global_transform.basis

	if nearest != null:
		var dir: Vector3 = nearest.global_position - my_pos
		# Guard against degenerate / parallel-to-UP direction vectors.
		if dir.length_squared() > 0.0001:
			var up_ref: Vector3 = Vector3.UP
			if absf(dir.normalized().dot(Vector3.UP)) > 0.99:
				up_ref = Vector3.FORWARD
			var to_global: Basis = Basis.looking_at(dir, up_ref).orthonormalized()
			# Convert the desired global basis into parent-local space.
			var to_local: Basis = (parent_global_basis.inverse() * to_global).orthonormalized()
			var from_local: Basis = transform.basis.orthonormalized()
			transform.basis = from_local.slerp(to_local, w)
			return

	# Idle: small yaw wobble around the eye's local up.
	var idle_local: Basis = Basis().rotated(Vector3.UP, sin(_t * idle_wobble_speed) * idle_wobble_amount).orthonormalized()
	var cur_local: Basis = transform.basis.orthonormalized()
	transform.basis = cur_local.slerp(idle_local, w)
