extends Path3D

func _process(delta: float) -> void:
	for i in range(curve.point_count - 1):
		var p1 = global_transform * curve.get_point_position(i)
		var p2 = global_transform * curve.get_point_position(i + 1)
		DebugDraw3D.draw_line(p1, p2, Color.AQUAMARINE)
