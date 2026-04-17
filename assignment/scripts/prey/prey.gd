class_name Prey
extends SteeringAgent

# A small forage fish. Wanders and schools loosely, flees the Gemini
# halves, but is drawn toward an active lure (Pollux mesmerising it).

@export var fear_radius: float = 5.0
@export var player_fear_radius: float = 6.0
@export var lure_radius: float = 8.0
@export var school_radius: float = 2.0
# How long the fish stays fixated on Pollux after it sees the lure;
# after this it sees through the trick and bolts.
@export var lure_attention: float = 3.0

var lure_active: bool = false
var lure_pos: Vector3 = Vector3.ZERO
# Read by GeminiController: true once the fish has seen through the lure.
var bolted: bool = false

var _wander := SteeringBehaviors.WanderState.new()
var _lure_t: float = 0.0


func _ready() -> void:
	add_to_group("prey")


func _compute_steering(delta: float) -> Vector3:
	var pos := global_position
	var f := SteeringBehaviors.wander3d(_wander, forward(), velocity, max_speed, delta)

	var seeing_lure := lure_active and pos.distance_to(lure_pos) < lure_radius
	if seeing_lure:
		_lure_t += delta
	else:
		_lure_t = 0.0
	# Fixated only for `lure_attention` seconds; then it sees the trick.
	var mesmerised := seeing_lure and _lure_t < lure_attention
	bolted = seeing_lure and not mesmerised

	if mesmerised:
		# Drift toward the lure instead of fleeing it.
		f += SteeringBehaviors.arrive(pos, lure_pos, velocity, max_speed, 2.5) * 1.4
	else:
		if bolted:
			# Saw through it -> bolt hard away from Pollux.
			f += SteeringBehaviors.flee(pos, lure_pos, velocity, max_speed) * 2.6
		for h in get_tree().get_nodes_in_group("gemini_half"):
			var hp: Vector3 = (h as Node3D).global_position
			if pos.distance_to(hp) < fear_radius:
				f += SteeringBehaviors.flee(pos, hp, velocity, max_speed) * 2.2

	# Always wary of the player, even while mesmerised by the lure.
	for pl in get_tree().get_nodes_in_group("player"):
		var pp: Vector3 = (pl as Node3D).global_position
		if pos.distance_to(pp) < player_fear_radius:
			f += SteeringBehaviors.flee(pos, pp, velocity, max_speed) * 2.0

	var others: Array = []
	for p in get_tree().get_nodes_in_group("prey"):
		if p != self:
			others.append((p as Node3D).global_position)
	f += SteeringBehaviors.separation(pos, velocity, max_speed, others, school_radius)
	return f


func captured() -> void:
	queue_free()
