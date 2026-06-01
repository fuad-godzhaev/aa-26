class_name Shark
extends SteeringAgent

# Lone predator patrolling the open water OUTSIDE the kelp ring, tracking the
# diver as they swim around inside. It cannot enter the forest: SteeringAgent's
# _contain holds it in the annulus [exclude_radius, bounds_radius] about the ring
# centre (both set by whoever spawns it). With no diver to track it wanders the
# annulus. Builds its own visual from the shark .glb so it can be spawned in code.

const SHARK_MODEL := preload("res://assignment/models_baked/fishes/shark1.tscn")

# The model's nose runs along its local +X; rotate so it points down the agent's
# forward (-Z). Flip by 180 if it ends up swimming tail-first.
@export var model_yaw_deg: float = 90.0
@export var model_scale: float = 1.0
@export var track_speed: float = 4.0
@export var wander_speed: float = 2.2

var _player: Node3D
var _wander := SteeringBehaviors.WanderState.new()


func _ready() -> void:
	add_to_group("shark")
	var m := SHARK_MODEL.instantiate() as Node3D
	if m != null:
		m.rotation = Vector3(0.0, deg_to_rad(model_yaw_deg), 0.0)
		m.scale = Vector3.ONE * model_scale
		add_child(m)


func _compute_steering(delta: float) -> Vector3:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player != null and is_instance_valid(_player):
		# Hunt the diver. The inner wall (exclude_radius) stops the shark at the
		# kelp, so it presses along the forest edge nearest the player.
		max_speed = track_speed
		return SteeringBehaviors.seek(global_position, _player.global_position, velocity, max_speed)
	# No diver sensed: cruise the annulus.
	max_speed = wander_speed
	return SteeringBehaviors.wander3d(_wander, forward(), velocity, max_speed, delta)
