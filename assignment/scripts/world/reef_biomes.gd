extends Node3D

# Builds the five demonstration biomes (DESIGN_DOC §11 / SCENE_PLAN) around the
# kelp-ring play area using ONLY models that exist in models_baked, and seeds prey
# per biome so Gemini's hunt FSM is provoked as the diver tours the reef.
#
# Spawned in code (by KelpForest) rather than hand-placed in reef.tscn because the
# godot-mcp-pro editor path was unavailable this session; positions are still data
# here (the dictionaries below) so they stay tunable. Everything grounds onto the
# visible seabed via a measured AABB, so it is robust to each model's origin.

const CORAL := preload("res://assignment/models_baked/coral.tscn")
const TUNNEL := preload("res://assignment/models_baked/tunnel.tscn")
const ARCH_TALL := preload("res://assignment/models_baked/arch_tall.tscn")
const KELP := preload("res://assignment/models_baked/kelp.tscn")
const CANNON := preload("res://assignment/models_baked/cannon.tscn")
const MAST := preload("res://assignment/models_baked/mast.tscn")
const PREY := preload("res://assignment/models_baked/prey.tscn")
const PREY_SPAWNER := preload("res://assignment/scripts/prey/prey_spawner.gd")

# Visible seabed top (the floor mostly sits ~-27; Ocean.SEABED_Y = -30 is the
# deepest point the kelp plants into).
const FLOOR_Y := -27.0

var _rng := RandomNumberGenerator.new()
var _center: Vector3 = Vector3(127.8, 0.0, 128.0)
var _ring_r: float = 28.0


func _ready() -> void:
	_rng.seed = 20240601
	var ring = get_tree().get_first_node_in_group("play_boundary")
	if ring:
		_center = Vector3(ring.global_position.x, 0.0, ring.global_position.z)
		_ring_r = ring.ring_radius

	# We distribute prey per-biome below, so turn off the controller's single
	# den spawner to avoid doubling up.
	var gem = get_tree().get_first_node_in_group("gemini")
	if gem:
		gem.spawn_internal_prey = false

	# --- biome landmarks (offsets are from the ring centre) -------------------
	# N: Coral Garden (the split/ambush money shot)
	_coral_garden(_off(0.0, -14.0))
	# SW: Arch + Tunnel (constrained nav) — beside the existing Arch
	_tunnel(_off(-9.0, -7.0))
	# S: Kelp Pocket (slalom / flush) — clear of the SE player spawn
	_kelp_pocket(_off(0.0, 13.0))
	# NW: Hero Rock / Den (dock + rest) — at the existing Home marker
	_den(_off(-8.0, 5.0))
	# A small wreck near the den for curiosity / set-dressing
	_wreck(_off(-2.0, 9.0))

	# --- prey per biome (DESIGN_DOC §11) --------------------------------------
	_prey(_off(0.0, -14.0), 4, 3.0)    # coral: tight school
	_prey(_off(0.0, 13.0), 3, 4.0)     # kelp pocket: hidden
	_prey(_off(-9.0, -7.0), 2, 5.0)    # arch/tunnel: loners
	_prey(_off(-8.0, 5.0), 1, 2.0)     # den: lone hunger-vs-dock fish

	_frame_player()


func _off(dx: float, dz: float) -> Vector3:
	return _center + Vector3(dx, 0.0, dz)


# --- biome builders ----------------------------------------------------------

func _coral_garden(at: Vector3) -> void:
	for i in 6:
		var a := TAU * float(i) / 6.0 + _rng.randf_range(-0.35, 0.35)
		var rad := _rng.randf_range(1.4, 4.6)
		_ground(CORAL, at + Vector3(cos(a) * rad, 0.0, sin(a) * rad), _rng.randf() * TAU, _rng.randf_range(0.7, 1.7))


func _kelp_pocket(at: Vector3) -> void:
	for i in 24:
		var a := _rng.randf() * TAU
		var rad := _rng.randf_range(0.4, 5.2)
		_ground(KELP, at + Vector3(cos(a) * rad, 0.0, sin(a) * rad), _rng.randf() * TAU, _rng.randf_range(0.8, 1.6))


func _tunnel(at: Vector3) -> void:
	_ground(TUNNEL, at, deg_to_rad(90.0), 0.85)


func _den(at: Vector3) -> void:
	_ground(ARCH_TALL, at, deg_to_rad(35.0), 1.35)


func _wreck(at: Vector3) -> void:
	_ground(CANNON, at, deg_to_rad(20.0), 1.0)
	_ground(MAST, at + Vector3(2.2, 0.0, 1.0), deg_to_rad(55.0), 1.0)


# Instance `scene`, place it at the x/z, then drop it so its measured base sits on
# the seabed. Returns the instance.
func _ground(scene: PackedScene, pos: Vector3, yaw: float, scl: float) -> Node3D:
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return null
	inst.rotation.y = yaw
	inst.scale = Vector3.ONE * scl
	inst.position = Vector3(pos.x, 0.0, pos.z)
	add_child(inst)
	var box := _world_aabb(inst)
	if box.size != Vector3.ZERO:
		inst.position.y += FLOOR_Y - box.position.y
	else:
		inst.position.y = FLOOR_Y   # CSG / mesh-less props: best-effort
	return inst


func _prey(at: Vector3, cnt: int, rad: float) -> void:
	var sp = PREY_SPAWNER.new()
	sp.prey_scene = PREY
	sp.count = cnt
	sp.radius = rad
	# Set BEFORE add_child: the spawner spawns prey in its own _ready.
	sp.position = Vector3(at.x, FLOOR_Y + 6.0, at.z)
	add_child(sp)


func _frame_player() -> void:
	var pr = get_tree().current_scene.get_node_or_null("PlayerRig")
	if pr == null:
		return
	# SE edge, just below the surface, looking NW across the open stage.
	var spawn := _center + Vector3(_ring_r * 0.6, 0.0, _ring_r * 0.6)
	spawn.y = -6.0
	pr.global_position = spawn
	pr.look_at(Vector3(_center.x, -11.0, _center.z), Vector3.UP)
	var yaw: float = pr.rotation.y
	pr.rotation = Vector3(0.0, yaw, 0.0)
	pr.set("_yaw", yaw)   # player_fly rebuilds rotation from _yaw on first look


# Combined world AABB of every MeshInstance3D under `node` (must be in the tree).
func _world_aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in _all(node):
		if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
			var mi := m as MeshInstance3D
			var ta: AABB = mi.global_transform * mi.mesh.get_aabb()
			if first:
				box = ta
				first = false
			else:
				box = box.merge(ta)
	return box


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out
