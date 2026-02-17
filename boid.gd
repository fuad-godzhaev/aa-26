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

<<<<<<< Updated upstream
func seek():
	var to_target = target.global_position - global_position
=======

func seek(target:Vector3):
	var to_target = target - global_position
>>>>>>> Stashed changes
	var desired:Vector3 = to_target.normalized() * max_speed
	DebugDraw3D.draw_arrow(global_position, global_position + desired, Color.DARK_ORANGE, 0.1) # To Target Vector (Desired)

	return desired - velocity
<<<<<<< Updated upstream
	
func _physics_process(delta: float) -> void:
	var force = arrive()
	accel = arrive() / mass
=======

func player_steering():
	var direction = Vector3.ZERO
	var velocity = Input.get_vector("Left", "Right", "Up", "Down")
	
	if Input.is_action_pressed("Right"):
		direction.x += 1
	if Input.is_action_pressed("Left"):
		direction.x -= 1
	if Input.is_action_pressed("Down"):
		direction.z += 1
	if Input.is_action_pressed("Up"):
		direction.z -= 1
		
	force.x = direction.x * speed
	force.z = direction.z * speed
	var strength = Input.get_action_strength("accelerate")
	
	DebugDraw3D.draw_arrow(global_position, global_position + velocity + direction, Color.YELLOW)
	
	return strength

var current_waypoint = 0

func follow_path():
	var target = path.global_transform * path.curve.get_point_position(current_waypoint)
	var dist = target.distance_to(global_position)
	
	if dist < 0.5:
		current_waypoint = (current_waypoint + 1) % path.curve.point_count
	return seek(target)

func calculate_force():
	var f:Vector3
	if seek_enabled:
		f += seek(target.global_position)
	if arrive_enabled:
		f += arrive()
	if path_follow_enabled:
		f += follow_path()
	if player_steering_enabled:
		f += player_steering()
	return f
		
	
	
func _physics_process(delta: float) -> void:
	var force = calculate_force()
	
	DebugDraw3D.draw_arrow(global_position, global_position + force * 10, Color.RED, 0.1)
	accel = force / mass
>>>>>>> Stashed changes
	velocity = velocity + accel * delta
	speed = velocity.length()
	
	if speed > 0:
		look_at(global_position - velocity)
	global_position += velocity * delta
	
<<<<<<< Updated upstream
	#DebugDraw3D.draw_arrow(global_position, global_position + global_basis.z, Color.BURLYWOOD, 0.1)
	DebugDraw3D.draw_arrow(global_position, global_position + velocity, Color.CORNFLOWER_BLUE, 0.1) # Current Velocity
	DebugDraw3D.draw_arrow(global_position, global_position + force * 10, Color.RED, 0.1) # Current Velocity

=======
	# DebugDraw3D.draw_arrow(global_position, global_position + global_basis.z, Color.BURLYWOOD, 0.1)
	DebugDraw3D.draw_arrow(global_position, global_position + velocity, Color.CORNFLOWER_BLUE, 0.1)
	DebugDraw3D.draw_arrow(global_position, global_position + global_basis.y * 5, Color.RED)
	DebugDraw3D.draw_arrow(global_position, global_position + force, Color.YELLOW)
>>>>>>> Stashed changes
	
