class_name KelpForest
extends Node3D

# Ring of kelp around the playable-area limit, built from copies of a kelp scene
# (kelp.tscn) that already has its ShaderMaterial baked in. Each copy is randomly
# rotated, tilted, and scaled for variety. An optional cylinder collider per stalk
# turns the ring into a soft turn-back boundary.
#
# Set `kelp_scene` to your kelp.tscn in the inspector. If that scene ALREADY has
# its own collision, set `add_collision = false` to avoid doubling it up.
# The kelp scene's origin should sit at the base of the stalk (+Y up).

@export var kelp_scene: PackedScene

# Preloaded (not referenced by class_name) so a stale global-class cache during
# CLI runs can't break the parse.
const SHARK_SCRIPT := preload("res://assignment/scripts/world/shark.gd")
const REEF_BIOMES := preload("res://assignment/scripts/world/reef_biomes.gd")

@export_group("Ring layout")
@export var ring_radius: float = 27.5
@export var ring_thickness: float = 4.0
@export var count: int = 320
# Number of concentric rings; stalks are spread radially across them.
@export var rings: int = 3
# Base of each stalk sits here (local Y) when reach_surface is off.
@export var base_y: float = -0.4
# Stretch each stalk vertically so its base sits on the seabed plane and its tip
# reaches the water surface, no matter the model's authored height (giant kelp
# grows all the way up). Measured per stalk from its real AABB, so it is robust
# to the model's origin and skinned-mesh AABB quirks.
@export var reach_surface: bool = true
# World Y the stalk bases plant into. Defaults to Ocean.SEABED_Y (the deepest
# point) so no stalk floats above an uneven floor.
@export var seabed_y: float = -30.0
# World Y the stalk tips reach.
@export var surface_y: float = 0.0

@export_group("Per-stalk variation")
@export var scale_min: float = 0.85
@export var scale_max: float = 1.25
@export var yaw_random: bool = true          # random spin around Y so copies don't all face the same way
@export var tilt_max_deg: float = 6.0        # small random lean for a natural look
@export var random_seed: int = 1729

@export_group("Collision")
@export var add_collision: bool = false
@export var collision_radius: float = 0.22
# Height of the collider cylinder (before per-stalk scale). Roughly the stalk height.
@export var collision_height: float = 18.0

@export_group("Patrol predator")
# Spawn a lone shark that patrols OUTSIDE the ring and tracks the diver.
@export var spawn_patrol_shark: bool = true
# How far beyond ring_radius the shark must stay (it can't enter the forest).
@export var shark_clearance: float = 3.0
# Outer patrol limit, measured beyond ring_radius.
@export var shark_outer: float = 22.0

@export_group("Scene build")
# Build the five demonstration biomes + per-biome prey (reef_biomes.gd).
@export var build_biomes: bool = true

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# The ring is the canonical play boundary: agents read its centre + radius.
	add_to_group("play_boundary")
	if kelp_scene == null:
		push_warning("KelpForest: kelp_scene is not set; nothing spawned.")
		return
	_rng.seed = random_seed
	var ocean = get_node_or_null("/root/Ocean")
	if ocean:
		seabed_y = ocean.SEABED_Y       # deepest point -> no stalk floats over uneven floor
		surface_y = ocean.SURFACE_Y
	@warning_ignore("integer_division")
	var per_ring: int = count / maxi(rings, 1)
	var spacing: float = ring_thickness / maxf(float(rings - 1), 1.0) if rings > 1 else 0.0
	for r_idx in rings:
		var r_base: float = ring_radius - ring_thickness * 0.5 + spacing * float(r_idx) if rings > 1 else ring_radius
		for i in per_ring:
			_spawn_stalk(i, per_ring, r_base, r_idx)

	if spawn_patrol_shark:
		# Deferred: spawning a sibling while the parent is still initialising is
		# rejected ("parent busy").
		_spawn_patrol_shark.call_deferred()
	if build_biomes:
		# Deferred too, and queued here (before Gemini's deferred _setup) so it can
		# turn off the controller's den spawner before prey are created.
		_spawn_biomes.call_deferred()


func _spawn_biomes() -> void:
	var b = REEF_BIOMES.new()
	get_tree().current_scene.add_child(b)


func _spawn_patrol_shark() -> void:
	var shark: SteeringAgent = SHARK_SCRIPT.new()
	get_parent().add_child(shark)
	var c := Vector3(global_position.x, 0.0, global_position.z)
	shark.bounds_center = c
	shark.exclude_radius = ring_radius + shark_clearance      # never enters the forest
	shark.bounds_radius = ring_radius + shark_outer           # outer patrol limit
	var mid_y: float = (seabed_y + surface_y) * 0.5
	shark.global_position = c + Vector3(ring_radius + shark_clearance + 6.0, mid_y, 0.0)


# One stalk = a copy of kelp_scene, optionally wrapped in a StaticBody3D collider.
func _spawn_stalk(i: int, per_ring: int, r_base: float, ring_index: int) -> void:
	# Stagger odd rings by half a slot so colliders don't line up into radial gaps.
	var offset: float = (PI / float(per_ring)) if (ring_index % 2 == 1) else 0.0
	var angle: float = TAU * float(i) / float(per_ring) + offset + _rng.randf_range(-0.012, 0.012)
	var r: float = r_base + _rng.randf_range(-0.35, 0.35)

	# Wrapper: StaticBody3D for the boundary collider, or a plain Node3D otherwise.
	var root: Node3D = StaticBody3D.new() if add_collision else Node3D.new()
	root.position = Vector3(cos(angle) * r, base_y, sin(angle) * r)
	add_child(root)

	# Instance the kelp scene (material already baked in) and vary each copy.
	var kelp := kelp_scene.instantiate() as Node3D
	if kelp == null:
		push_warning("KelpForest: kelp_scene root is not a Node3D.")
		root.queue_free()
		return

	var s: float = _rng.randf_range(scale_min, scale_max)
	kelp.scale = Vector3(s, s, s)
	var yaw: float = _rng.randf_range(0.0, TAU) if yaw_random else 0.0
	# Skip the lean when stretching to the surface so the tip lands on the water
	# line; a tall stretched stalk would swing far sideways otherwise.
	var tilt: float = 0.0 if reach_surface else deg_to_rad(tilt_max_deg)
	var rx: float = _rng.randf_range(-tilt, tilt) if tilt > 0.0 else 0.0
	var rz: float = _rng.randf_range(-tilt, tilt) if tilt > 0.0 else 0.0
	kelp.rotation = Vector3(rx, yaw, rz)
	root.add_child(kelp)

	if reach_surface:
		# Scale EVENLY (uniform XYZ) so the stalk keeps its natural proportions
		# instead of the thin Y-only stretch, sized so it spans seabed -> ~surface.
		# A small per-stalk jitter keeps the forest from looking uniform.
		var span: float = surface_y - seabed_y
		var box0 := _world_aabb(kelp)
		if box0.size.y > 0.001:
			var u: float = s * (span / box0.size.y) * _rng.randf_range(0.9, 1.03)
			kelp.scale = Vector3(u, u, u)
		# Re-measure after the even scale and drop the wrapper so the base sits on
		# the seabed plane (no float).
		var box1 := _world_aabb(kelp)
		root.position.y += seabed_y - box1.position.y

	if add_collision:
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = collision_radius
		cs.height = collision_height * s
		col.shape = cs
		# Cylinder is centred on its origin; lift it so its base sits at the stalk base.
		col.position = Vector3(0.0, collision_height * s * 0.5, 0.0)
		root.add_child(col)


# Combined world-space AABB of every MeshInstance3D under `node` (the node must
# already be inside the tree so global transforms are valid).
func _world_aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in _all_nodes(node):
		if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
			var mi := m as MeshInstance3D
			var ta: AABB = mi.global_transform * mi.mesh.get_aabb()
			if first:
				box = ta
				first = false
			else:
				box = box.merge(ta)
	return box


func _all_nodes(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all_nodes(c))
	return out
