extends Marker3D


func _on_timer_timeout() -> void:
	
	global_position.x = randf_range(-5, +5)
	global_position.z = randf_range(-5, +5)
	pass # Replace with function body.
