extends CharacterBody3D

@export var target:Node3D
@export var speed = 2.0

@export var accel:Vector3 = Vector3.ZERO
@export var force:Vector3 = Vector3.ZERO

@export var mass:float = 1.0
@export var max_speed:float = 5.0
@export var slowing_distance:float = 5

@export var banking:float = 0.1

@export var seek_enabled:bool = false
@export var arrive_enabled:bool = false
@export var path_follow_enabled:bool = false
@export var player_steering_enabled:bool = false

@export var path:Path3D

func arrive():
	var to_target = target.global_position - global_position
	var dist = to_target.length()
	# var distt1 = target.global_position.distance_to(global_position)
	var ramped = (dist / slowing_distance) * max_speed
	var clamped = min(ramped, max_speed)
	var desired = (to_target / dist) * clamped
	
	DebugDraw3D.draw_sphere(target.global_position, slowing_distance, Color.CYAN)
	
	return desired - velocity


func seek():
	var to_target = target.global_position - global_position
	var desired:Vector3 = to_target.normalized() * max_speed
	DebugDraw3D.draw_arrow(global_position, global_position + desired, Color.DARK_ORANGE, 0.1)

	return desired - velocity

func player_steering():
	pass

func follow_path():
	pass

func calculate_force():
	var f:Vector3
	if seek_enabled:
		f += seek()
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
	velocity = velocity + accel * delta
	speed = velocity.length()
	if speed > 0:
		var temp_up = global_basis.y.lerp(Vector3.UP + accel * banking, delta * 5)
		look_at(global_position - velocity, temp_up)
	global_position += velocity * delta
	
	# DebugDraw3D.draw_arrow(global_position, global_position + global_basis.z, Color.BURLYWOOD, 0.1)
	DebugDraw3D.draw_arrow(global_position, global_position + velocity, Color.CORNFLOWER_BLUE, 0.1)
	DebugDraw3D.draw_arrow(global_position, global_position + global_basis.y * 5, Color.RED)
	
