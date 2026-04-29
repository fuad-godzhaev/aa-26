class_name SteeringBehaviors
extends RefCounted

# Pure steering primitives. Every function returns a steering force
# (desired_velocity - current_velocity). No side effects, no gizmos.

# Per-agent wander memory; one instance lives on each wandering agent.
class WanderState extends RefCounted:
	var angle: float = 0.0
	var pitch: float = 0.0       # vertical component for 3D wander
	var jitter: float = 3.0      # radians/sec of random walk
	var radius: float = 1.2      # wander circle radius
	var distance: float = 2.5    # circle projection ahead of the agent


static func seek(from_pos: Vector3, target_pos: Vector3, velocity: Vector3, max_speed: float) -> Vector3:
	var desired := (target_pos - from_pos).normalized() * max_speed
	return desired - velocity


static func flee(from_pos: Vector3, threat_pos: Vector3, velocity: Vector3, max_speed: float) -> Vector3:
	var desired := (from_pos - threat_pos).normalized() * max_speed
	return desired - velocity


static func arrive(from_pos: Vector3, target_pos: Vector3, velocity: Vector3, max_speed: float, slowing_distance: float) -> Vector3:
	var to_target := target_pos - from_pos
	var dist := to_target.length()
	if dist < 0.001:
		return -velocity
	var ramped := (dist / maxf(slowing_distance, 0.001)) * max_speed
	var clamped := minf(ramped, max_speed)
	var desired := (to_target / dist) * clamped
	return desired - velocity


static func pursue(from_pos: Vector3, velocity: Vector3, max_speed: float, target_pos: Vector3, target_velocity: Vector3) -> Vector3:
	var lead := (target_pos - from_pos).length() / maxf(max_speed, 0.001)
	return seek(from_pos, target_pos + target_velocity * lead, velocity, max_speed)


# Pursue a point held at a fixed world-space offset from the moving target.
static func offset_pursue(from_pos: Vector3, velocity: Vector3, max_speed: float, target_pos: Vector3, target_velocity: Vector3, offset: Vector3) -> Vector3:
	var lead := (target_pos - from_pos).length() / maxf(max_speed, 0.001)
	return seek(from_pos, target_pos + target_velocity * lead + offset, velocity, max_speed)


# Hold a standoff point behind the target, out of its facing direction.
static func standoff(from_pos: Vector3, velocity: Vector3, max_speed: float, target_pos: Vector3, target_forward: Vector3, distance: float, slowing_distance: float) -> Vector3:
	var point := target_pos - target_forward.normalized() * distance
	return arrive(from_pos, point, velocity, max_speed, slowing_distance)


# Dock onto a partner (used when the twins fuse).
static func dock(from_pos: Vector3, partner_pos: Vector3, velocity: Vector3, max_speed: float, slowing_distance: float) -> Vector3:
	return arrive(from_pos, partner_pos, velocity, max_speed, slowing_distance)


static func separation(from_pos: Vector3, velocity: Vector3, max_speed: float, neighbour_positions: Array, radius: float) -> Vector3:
	var push := Vector3.ZERO
	var count := 0
	for n in neighbour_positions:
		var away: Vector3 = from_pos - n
		var d := away.length()
		if d > 0.0 and d < radius:
			push += away.normalized() / d
			count += 1
	if count == 0:
		return Vector3.ZERO
	var desired := (push / count).normalized() * max_speed
	return desired - velocity


# Match the average heading of nearby neighbours (Boids flocking).
static func alignment(velocity: Vector3, max_speed: float, neighbour_velocities: Array) -> Vector3:
	if neighbour_velocities.is_empty():
		return Vector3.ZERO
	var avg := Vector3.ZERO
	for v in neighbour_velocities:
		avg += v
	avg /= float(neighbour_velocities.size())
	if avg.length() < 0.001:
		return Vector3.ZERO
	var desired := avg.normalized() * max_speed
	return desired - velocity


# Seek the centroid of nearby neighbours (Boids flocking).
static func cohesion(from_pos: Vector3, velocity: Vector3, max_speed: float, neighbour_positions: Array) -> Vector3:
	if neighbour_positions.is_empty():
		return Vector3.ZERO
	var centroid := Vector3.ZERO
	for p in neighbour_positions:
		centroid += p
	centroid /= float(neighbour_positions.size())
	return seek(from_pos, centroid, velocity, max_speed)


# Stateful: mutates `state.angle` to produce a smooth random heading.
static func wander(state: WanderState, forward: Vector3, velocity: Vector3, max_speed: float, delta: float) -> Vector3:
	state.angle += randf_range(-state.jitter, state.jitter) * delta
	var centre := forward.normalized() * state.distance
	var offset := Vector3(cos(state.angle), 0.0, sin(state.angle)) * state.radius
	var desired := (centre + offset).normalized() * max_speed
	return desired - velocity


# 3D wander: adds a gently bounded vertical component.
static func wander3d(state: WanderState, forward: Vector3, velocity: Vector3, max_speed: float, delta: float) -> Vector3:
	state.angle += randf_range(-state.jitter, state.jitter) * delta
	# Vertical drifts slowly and shallowly so it glides, not bobs.
	state.pitch += randf_range(-state.jitter, state.jitter) * 0.2 * delta
	state.pitch = clampf(state.pitch, -0.35, 0.35)
	var centre := forward.normalized() * state.distance
	var offset := Vector3(cos(state.angle), sin(state.pitch), sin(state.angle)) * state.radius
	var desired := (centre + offset).normalized() * max_speed
	return desired - velocity


# Steer clear of spheres in the path. `obstacles` is an Array of Vector4
# (xyz = world centre, w = radius). Only obstacles ahead within
# `look_ahead` along the velocity are considered.
static func avoid_spheres(from_pos: Vector3, velocity: Vector3, max_speed: float, obstacles: Array, look_ahead: float) -> Vector3:
	if velocity.length() < 0.001:
		return Vector3.ZERO
	var dir := velocity.normalized()
	var steer := Vector3.ZERO
	for o in obstacles:
		var centre := Vector3(o.x, o.y, o.z)
		var to_o := centre - from_pos
		var ahead := dir.dot(to_o)
		if ahead < 0.0 or ahead > look_ahead:
			continue
		var nearest := from_pos + dir * ahead
		var gap := nearest.distance_to(centre)
		var safe: float = o.w + 1.0
		if gap < safe:
			var push := nearest - centre
			if push.length() < 0.001:
				push = dir.cross(Vector3.UP)
			steer += push.normalized() * ((safe - gap) / safe)
	if steer == Vector3.ZERO:
		return Vector3.ZERO
	return steer.normalized() * max_speed
