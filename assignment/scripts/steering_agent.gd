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
@export var draw_gizmos: bool = true

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
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	speed = velocity.length()
	if speed > 0.001:
		var temp_up := global_basis.y.lerp(Vector3.UP + accel * banking, delta * 5.0)
		look_at(global_position - velocity, temp_up)
	global_position += velocity * delta

	if draw_gizmos:
		DebugDraw3D.draw_arrow(global_position, global_position + velocity, Color.CORNFLOWER_BLUE, 0.1)
		DebugDraw3D.draw_arrow(global_position, global_position + force, Color.RED, 0.1)
