class_name FishSchool
extends Node3D

# One tightly-grouped ambient fish school. Place several FishSchool nodes in the scene at different positions; each spawns ~count fish around its own origin and Boids-flocks them within a small bounds radius around that origin. Fish softly avoid the player and gemini_half (steering), and each fish carries an AnimatableBody3D collider so the diver bumps off them as a fallback. See ARCHITECTURE.md.

@export var count: int = 12
@export var spawn_radius: float = 3.0
@export var bounds_radius: float = 5.5
@export var min_y_offset: float = -2.0
@export var max_y_offset: float = 2.0
@export var max_speed: float = 2.0
@export var max_force: float = 6.0
@export var neighbour_radius: float = 3.5
@export var avoid_radius: float = 4.0
@export var sep_weight: float = 1.4
@export var ali_weight: float = 1.1
# Stronger cohesion so each school stays tightly grouped instead of dispersing.
@export var coh_weight: float = 1.6
@export var avoid_weight: float = 2.8
@export var contain_weight: float = 1.6
@export var fish_scale: float = 0.8
@export var collider_radius: float = 0.18
@export var collision_layer: int = 1
@export var collision_mask: int = 1
@export var fish_color: Color = Color(0.82, 0.92, 0.96, 1)
@export var fish_emission: Color = Color(0.45, 0.65, 0.75, 1)
@export var random_seed: int = 8675

var _center: Vector3
var _fish: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	# Each school is anchored to its node's global position at startup; containment pulls strays back toward this point, not the world origin.
	_center = global_position
	var mat := _make_material()
	var mesh := _make_mesh()
	for i in count:
		_spawn_fish(mat, mesh)


func _physics_process(delta: float) -> void:
	if _fish.is_empty():
		return
	# Soft avoidance of both the diver and gemini halves; the per-fish collider is a fallback so an inattentive diver still bumps the school instead of phasing through it.
	var avoiders: Array[Vector3] = []
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D:
			avoiders.append((p as Node3D).global_position)
	for h in get_tree().get_nodes_in_group("gemini_half"):
		if h is Node3D:
			avoiders.append((h as Node3D).global_position)

	var positions: Array[Vector3] = []
	var velocities: Array[Vector3] = []
	for f in _fish:
		positions.append(f["pos"])
		velocities.append(f["vel"])

	for i in _fish.size():
		var f: Dictionary = _fish[i]
		var pos: Vector3 = f["pos"]
		var vel: Vector3 = f["vel"]

		var n_pos: Array = []
		var n_vel: Array = []
		for j in _fish.size():
			if i == j:
				continue
			var d: float = pos.distance_to(positions[j])
			if d < neighbour_radius:
				n_pos.append(positions[j])
				n_vel.append(velocities[j])

		var sep := SteeringBehaviors.separation(pos, vel, max_speed, n_pos, neighbour_radius)
		var ali := SteeringBehaviors.alignment(vel, max_speed, n_vel)
		var coh := SteeringBehaviors.cohesion(pos, vel, max_speed, n_pos)

		var avoid := Vector3.ZERO
		for a in avoiders:
			var d2: float = pos.distance_to(a)
			if d2 < avoid_radius and d2 > 0.001:
				avoid += (pos - a).normalized() * ((avoid_radius - d2) / avoid_radius)
		if avoid.length() > 0.001:
			avoid = avoid.normalized() * max_speed - vel

		# Soft containment back toward the school's own centre.
		var offset := pos - _center
		var flat := Vector3(offset.x, 0.0, offset.z)
		var contain := Vector3.ZERO
		if flat.length() > bounds_radius:
			var to_centre := -flat.normalized() * max_speed
			contain = to_centre - Vector3(vel.x, 0.0, vel.z)
		# Vertical band is also relative to the centre.
		var rel_y := pos.y - _center.y
		if rel_y < min_y_offset:
			contain.y += (max_speed - vel.y)
		elif rel_y > max_y_offset:
			contain.y += (-max_speed - vel.y)

		var force: Vector3 = sep * sep_weight + ali * ali_weight + coh * coh_weight + avoid * avoid_weight + contain * contain_weight
		force = force.limit_length(max_force)

		vel += force * delta
		vel = vel.lerp(Vector3.ZERO, clampf(0.35 * delta, 0.0, 1.0))
		if vel.length() > max_speed:
			vel = vel.normalized() * max_speed
		pos += vel * delta

		# Hard clamp so fish never escape their school's volume.
		var clamped_flat := Vector3(pos.x - _center.x, 0.0, pos.z - _center.z)
		if clamped_flat.length() > bounds_radius:
			var n := clamped_flat.normalized()
			pos.x = _center.x + n.x * bounds_radius
			pos.z = _center.z + n.z * bounds_radius
			var outward := vel.dot(Vector3(n.x, 0.0, n.z))
			if outward > 0.0:
				vel -= Vector3(n.x, 0.0, n.z) * outward
		if pos.y - _center.y > max_y_offset:
			pos.y = _center.y + max_y_offset
			if vel.y > 0.0:
				vel.y = -vel.y * 0.3
		elif pos.y - _center.y < min_y_offset:
			pos.y = _center.y + min_y_offset
			if vel.y < 0.0:
				vel.y = -vel.y * 0.3

		f["pos"] = pos
		f["vel"] = vel
		var body: AnimatableBody3D = f["body"]
		body.global_position = pos
		if vel.length() > 0.08:
			body.look_at(body.global_position + vel, Vector3.UP)


func _spawn_fish(mat: StandardMaterial3D, mesh: Mesh) -> void:
	var a: float = _rng.randf() * TAU
	var r: float = _rng.randf() * spawn_radius
	var y_off: float = _rng.randf_range(min_y_offset, max_y_offset)
	var pos := _center + Vector3(cos(a) * r, y_off, sin(a) * r)
	var dir := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	var vel := dir.normalized() * max_speed * _rng.randf_range(0.4, 0.9)

	var body := AnimatableBody3D.new()
	body.position = pos
	body.scale = Vector3.ONE * fish_scale
	body.collision_layer = collision_layer
	body.collision_mask = collision_mask
	body.sync_to_physics = false
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = collider_radius
	col.shape = shape
	body.add_child(col)
	add_child(body)
	_fish.append({"pos": pos, "vel": vel, "body": body})


func _make_mesh() -> Mesh:
	var m := CapsuleMesh.new()
	m.radius = 0.07
	m.height = 0.32
	return m


func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fish_color
	mat.metallic = 0.4
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = fish_emission
	mat.emission_energy_multiplier = 0.6
	return mat
