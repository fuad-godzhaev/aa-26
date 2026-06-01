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
# Defaults are surface-0/seabed world values; at runtime the Ocean autoload
# overrides the altitude band + radius. bounds_center is the horizontal centre
# of the containment cylinder (the reef is placed well off origin, so a fixed
# origin clamp would yank every agent to (0,0)) and is set by the spawner.
@export var min_altitude: float = -29.0
@export var max_altitude: float = -1.0
@export var bounds_radius: float = 26.0
@export var bounds_center: Vector3 = Vector3.ZERO
# If > 0, the agent is ALSO kept OUTSIDE this radius of bounds_center (an inner
# wall). Used for the shark so it patrols the annulus outside the kelp ring and
# cannot cross into the forest.
@export var exclude_radius: float = 0.0

var speed: float = 0.0
var _bounds_resolved: bool = false


# Pull the vertical band from the Ocean autoload once (kept lazy because
# subclasses override _ready without chaining to a base _ready). The horizontal
# radius + centre are left to the spawner (they vary: inside vs outside the ring).
func _resolve_bounds() -> void:
	_bounds_resolved = true
	var ocean = get_node_or_null("/root/Ocean")
	if ocean:
		min_altitude = ocean.SEABED_Y + 1.0
		max_altitude = ocean.SURFACE_Y - 1.0


# Godot's forward is -Z; this is the agent's facing direction.
func forward() -> Vector3:
	return -global_basis.z


# Override in subclasses. Return the summed steering force for this frame.
func _compute_steering(_delta: float) -> Vector3:
	return Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not _bounds_resolved:
		_resolve_bounds()
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

	var flat := Vector3(global_position.x - bounds_center.x, 0.0, global_position.z - bounds_center.z)
	var r := flat.length()
	if r > bounds_radius:
		var n := flat / r
		global_position.x = bounds_center.x + n.x * bounds_radius
		global_position.z = bounds_center.z + n.z * bounds_radius
		var outward := velocity.dot(n)
		if outward > 0.0:
			velocity -= n * outward
	elif exclude_radius > 0.0 and r < exclude_radius:
		# Inner wall: shove back out and shed the inward velocity component.
		var n := (flat / r) if r > 0.001 else Vector3.RIGHT
		global_position.x = bounds_center.x + n.x * exclude_radius
		global_position.z = bounds_center.z + n.z * exclude_radius
		var inward := velocity.dot(-n)
		if inward > 0.0:
			velocity += n * inward
