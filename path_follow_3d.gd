extends PathFollow3D

func _physics_process(delta: float) -> void:
	 # Or use absolute distance
	progress += 2 * delta  # units per second
