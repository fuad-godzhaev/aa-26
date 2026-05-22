extends Node3D

# Inspection-only helper: configures the two TwoEye instances under us, freezes
# their process loops so they sit still for screenshots, and assigns roles so
# Pollux inverts via the role-setter in two_eye.gd.

func _ready() -> void:
	var castor := $Castor
	var pollux := $Pollux
	if castor:
		if "role" in castor:
			castor.role = 0
		castor.set_process(false)
		castor.set_physics_process(false)
	if pollux:
		if "role" in pollux:
			pollux.role = 1
		pollux.set_process(false)
		pollux.set_physics_process(false)
