extends CharacterBody3D

@export var target:Node3D
@export var speed = 2.0

@export var accel:Vector3 = Vector3.ZERO
@export var force:Vector3 = Vector3.ZERO

@export var mass:float = 1.0
@export var max_speed:float = 5.0


func calculate_force():
	var to_target = target.global_position - global_position
	var desired:Vector3 = to_target.normalized() * max_speed
	DebugDraw3D.draw_arrow(global_position, global_position + desired, Color.DARK_ORANGE, 0.1)

	return desired - velocity
	
func _physics_process(delta: float) -> void:
	accel = calculate_force() / mass
	velocity = velocity + accel * delta
	speed = velocity.length()
	if speed > 0:
		look_at(global_position - velocity)
	global_position += velocity * delta
	
	DebugDraw3D.draw_arrow(global_position, global_position + global_basis.z, Color.BURLYWOOD, 0.1)
	DebugDraw3D.draw_arrow(global_position, global_position + velocity, Color.CORNFLOWER_BLUE, 0.1)

	
