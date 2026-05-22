class_name CloudTracker
extends Node3D

# Re-centres the cloud dome above the active camera every frame.
# Keeps the inverted hemisphere of clouds always overhead in XZ regardless of where the diver swims, while pinning the dome to a fixed altitude so the horizon-relative geometry is stable.

@export var altitude: float = 60.0

func _process(_delta: float) -> void:
	# Active camera may be the desktop player, XR camera, or null during scene load.
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	# Track XZ only; clamp Y to altitude so the dome stays at a consistent sky height.
	global_position = Vector3(cam.global_position.x, altitude, cam.global_position.z)
