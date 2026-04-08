class_name SteeringAgent
extends CharacterBody3D

# Kinematic base for every moving creature (Gemini halves and prey).
# Owns force->accel->velocity integration, banked orientation and gizmos.
# Subclasses override _compute_steering() to supply the per-frame force.

@export var mass: float = 1.0
@export var max_speed: float = 5.0
@export var max_force: float = 20.0
@export var slowing_distance: float = 4.0
@export var banking: float = 5.0
# Water drag: fraction of speed bled off per second. Damps the
# force-vs-velocity oscillation and gives an underwater glide.
@export var drag: float = 0.8
@export var draw_gizmos: bool = true

# Hard containment so manual integration cannot leave the reef volume.
# (Per-obstacle avoidance around rocks/corals is a steering behavior in M2.)
@export var min_altitude: float = 0.7
@export var max_altitude: float = 18.0
@export var bounds_radius: float = 26.0

var speed: float = 0.0


# Godot's forward is -Z; this is the agent's facing direction.
func forward() -> Vector3:
	return -global_basis.z


# Override in subclasses. Return the summed steering force for this frame.
func _compute_steering(_delta: float) -> Vector3:
	return Vector3.ZERO


func _physics_process(delta: float) -> void:
	var force := _compute_steering(delta).limit_length(max_force)
	var accel := force / mass
	velocity += accel * delta
	velocity = velocity.lerp(Vector3.ZERO, clampf(drag * delta, 0.0, 1.0))
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	speed = velocity.length()
	# Only re-orient with enough speed, and skip when travelling almost
	# straight up/down (look_at degenerates when dir ~ up -> spin/jitter).
	if speed > 0.05:
		var dir := velocity / speed
		if absf(dir.dot(Vector3.UP)) < 0.95:
			var temp_up := global_basis.y.lerp(Vector3.UP + accel * banking, delta * 5.0)
			look_at(global_position + velocity, temp_up)
	global_position += velocity * delta
	_contain()

	if draw_gizmos:
		DebugDraw3D.draw_arrow(global_position, global_position + velocity, Color.CORNFLOWER_BLUE, 0.1)
		DebugDraw3D.draw_arrow(global_position, global_position + force, Color.RED, 0.1)


# Clamp into the reef volume and shed the velocity component that would
# push past the boundary, so it skims edges instead of sticking/jittering.
func _contain() -> void:
	# Gentle restitution (not a hard zero) so it eases off the boundary
	# instead of stick-slip jittering against it.
	if global_position.y < min_altitude:
		global_position.y = min_altitude
		if velocity.y < 0.0:
			velocity.y *= -0.15
	elif global_position.y > max_altitude:
		global_position.y = max_altitude
		if velocity.y > 0.0:
			velocity.y *= -0.15

	var flat := Vector3(global_position.x, 0.0, global_position.z)
	var r := flat.length()
	if r > bounds_radius:
		var n := flat / r
		global_position.x = n.x * bounds_radius
		global_position.z = n.z * bounds_radius
		var outward := velocity.dot(n)
		if outward > 0.0:
			velocity -= n * outward
