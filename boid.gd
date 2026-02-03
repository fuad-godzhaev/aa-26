extends CharacterBody3D

@export var target:Node3D
@export var speed = 2.0

@export var accel:Vector3 = Vector3.ZERO
@export var force:Vector3 = Vector3.ZERO

@export var mass:float = 1.0
@export var max_speed:float = 5.0
@export var slowing_distance:float = 5

#func calculate_force():
#	var to_target = target.global_position - global_position
#	var desired:Vector3 = to_target.normalized() * max_speed
#	DebugDraw3D.draw_arrow(global_position, global_position + desired, Color.DARK_ORANGE, 0.1) # To Target Vector (Desired)
#
#	return desired - velocity

func arrive():
	var to_target = target.global_position - global_position # DISTANCE FROM TARGET TO US
	var dist = to_target.length() # Calculate length of to_target aka distance
	#var dist1 = target.global_position.distance_to(global_position) # One-line implementation
	
	var ramped = (dist / slowing_distance) * max_speed
	var clamped = min(ramped, max_speed)
	
	var desired = (to_target/ dist) * clamped
	
	DebugDraw3D.draw_sphere(target.global_position, slowing_distance, Color.CYAN)
	
	return desired - velocity

func seek():
	var to_target = target.global_position - global_position
	var desired:Vector3 = to_target.normalized() * max_speed
	DebugDraw3D.draw_arrow(global_position, global_position + desired, Color.DARK_ORANGE, 0.1) # To Target Vector (Desired)

	return desired - velocity
	
func _physics_process(delta: float) -> void:
	var force = arrive()
	accel = arrive() / mass
	velocity = velocity + accel * delta
	speed = velocity.length()
	if speed > 0:
		look_at(global_position - velocity)
	global_position += velocity * delta
	
	#DebugDraw3D.draw_arrow(global_position, global_position + global_basis.z, Color.BURLYWOOD, 0.1)
	DebugDraw3D.draw_arrow(global_position, global_position + velocity, Color.CORNFLOWER_BLUE, 0.1) # Current Velocity
	DebugDraw3D.draw_arrow(global_position, global_position + force * 10, Color.RED, 0.1) # Current Velocity

	
