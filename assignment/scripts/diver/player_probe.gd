class_name PlayerProbe
extends Node3D

# XR-ready abstraction of "the player" for the creature to perceive.
# On PC `source` is the fly rig; in XR it would wrap the headset/hands.
# The creature never reads input directly, only this probe.

@export var source: Node3D
@export var draw_gizmos: bool = true

var velocity: Vector3 = Vector3.ZERO
var _last_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	if source:
		_last_pos = source.global_position


func _physics_process(delta: float) -> void:
	if source == null or delta <= 0.0:
		return
	var p := source.global_position
	velocity = (p - _last_pos) / delta
	_last_pos = p
	if draw_gizmos:
		DebugDraw3D.draw_sphere(p, 0.4, Color.YELLOW)


func sense_position() -> Vector3:
	return source.global_position if source else global_position


func sense_velocity() -> Vector3:
	return velocity


func sense_speed() -> float:
	return velocity.length()


# 0 = calm/still, 1 = at/above scare_speed. Feeds the wariness need later.
func threat_level(scare_speed: float) -> float:
	return clampf(sense_speed() / maxf(scare_speed, 0.001), 0.0, 1.0)
