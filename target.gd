extends Marker3D


func _on_timer_timeout() -> void:
	
	global_position.x = randf_range(-2, +2)
	global_position.z = randf_range(-2, +2)
	pass # Replace with function body.
