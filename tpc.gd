extends Camera3D

func _process(delta: float) -> void:
	global_position = lerp(global_position, $"../boid/cam_target".global_position, delta *5 )
	look_at($"../boid".global_position)
