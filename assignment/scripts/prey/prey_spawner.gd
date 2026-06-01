class_name PreySpawner
extends Node3D

# Keeps a small population of Prey alive around its origin, respawning
# stragglers (the Gemini eats them) on a timer.

@export var prey_scene: PackedScene
@export var count: int = 6
@export var radius: float = 18.0
@export var respawn_time: float = 6.0

var _t: float = 0.0
var _play_center: Vector3
var _play_radius: float = 26.0


func _ready() -> void:
	# Keep prey inside the kelp ring (the play boundary).
	var ring = get_tree().get_first_node_in_group("play_boundary")
	if ring:
		_play_center = Vector3(ring.global_position.x, 0.0, ring.global_position.z)
		_play_radius = maxf(ring.ring_radius - 3.0, 4.0)
	else:
		_play_center = global_position
	for i in count:
		_spawn()


func _process(delta: float) -> void:
	if get_tree().get_nodes_in_group("prey").size() >= count:
		return
	_t += delta
	if _t >= respawn_time:
		_t = 0.0
		_spawn()


func _spawn() -> void:
	if prey_scene == null:
		return
	var p := prey_scene.instantiate() as Node3D
	add_child(p)
	var a := randf() * TAU
	var r := randf_range(4.0, radius)
	p.global_position = global_position + Vector3(cos(a) * r, randf_range(2.0, 7.0), sin(a) * r)
	# Contain prey inside the kelp ring (the play boundary), not origin.
	if p is SteeringAgent:
		(p as SteeringAgent).bounds_center = _play_center
		(p as SteeringAgent).bounds_radius = _play_radius
