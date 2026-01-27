extends MeshInstance3D

func _ready() -> void:
	pass
	
func  _process(delta: float) -> void:
	rotate_x(delta)	
	rotate_z(delta)
	# translate(Vector3.FORWARD * delta)
	
	# position
	# rotation
	# scale
	# position.x += delta
	# scale.y += delta
	
	global_position +=  Vector3.FORWARD * delta
	
	# DebugDraw3D.draw_arrow()
	
	$"../../pos_label".text = "Position: " + str(position)
