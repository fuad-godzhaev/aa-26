class_name Gemini
extends SteeringAgent

# M1: the fused organism ("Pleo"). Calmly wanders the reef, stays loosely
# tethered to home, and flees a near + fast player. Its bioluminescent glow
# pulse reflects its wariness. The split into Castor/Pollux arrives in M3;
# this class hosts the BehaviorTree from M2.

@export var player: PlayerProbe
@export var home: Node3D
@export var glow_material: ShaderMaterial

@export var flee_radius: float = 6.0
@export var scare_speed: float = 4.0
@export var home_radius: float = 11.0
@export var wander_weight: float = 1.0
@export var flee_weight: float = 2.0
@export var tether_weight: float = 1.7

var _wander := SteeringBehaviors.WanderState.new()
var _wariness: float = 0.0


func _compute_steering(delta: float) -> Vector3:
	var pos := global_position
	var force := SteeringBehaviors.wander(_wander, forward(), velocity, max_speed, delta) * wander_weight

	# Soft tether so it keeps to the reef instead of drifting away.
	if home and pos.distance_to(home.global_position) > home_radius:
		force += SteeringBehaviors.arrive(pos, home.global_position, velocity, max_speed, slowing_distance) * tether_weight
		if draw_gizmos:
			DebugDraw3D.draw_sphere(home.global_position, home_radius, Color.DARK_SLATE_GRAY)

	# Wariness: flee a player that is both close and moving fast.
	var threat := 0.0
	if player:
		var pp: Vector3 = player.sense_position()
		var d: float = pos.distance_to(pp)
		var scared: bool = d < flee_radius and player.sense_speed() > scare_speed
		if scared:
			force += SteeringBehaviors.flee(pos, pp, velocity, max_speed) * flee_weight
			threat = 1.0
		if draw_gizmos:
			DebugDraw3D.draw_sphere(pos, flee_radius, Color.ORANGE_RED if scared else Color.SEA_GREEN)
			DebugDraw3D.draw_line(pos, pp, Color.WHITE_SMOKE)

	_wariness = move_toward(_wariness, threat, delta * (3.0 if threat > 0.0 else 0.5))
	_update_glow()
	return force


# Calm = slow, strong teal pulse; wary = fast, dim flicker.
func _update_glow() -> void:
	if glow_material == null:
		return
	glow_material.set_shader_parameter("pulse_speed", lerpf(1.2, 5.0, _wariness))
	glow_material.set_shader_parameter("pulse_strength", lerpf(0.55, 0.18, _wariness))
