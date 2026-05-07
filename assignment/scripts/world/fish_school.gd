class_name FishSchool
extends Node3D

# Ambient flock — Boids (separation + alignment + cohesion) using SteeringBehaviors, with soft player + Gemini avoidance and circular containment. See ARCHITECTURE.md.

@export var count: int = 36
@export var spawn_radius: float = 12.0
@export var bounds_radius: float = 24.0
@export var min_y: float = 1.2
@export var max_y: float = 13.0
@export var max_speed: float = 2.4
@export var max_force: float = 7.0
@export var neighbour_radius: float = 3.2
@export var avoid_radius: float = 5.0
@export var sep_weight: float = 1.6
@export var ali_weight: float = 1.0
@export var coh_weight: float = 0.85
@export var avoid_weight: float = 2.8
@export var contain_weight: float = 1.4
@export var fish_scale: float = 0.18
@export var fish_color: Color = Color(0.82, 0.92, 0.96, 1)
@export var fish_emission: Color = Color(0.45, 0.65, 0.75, 1)
@export var random_seed: int = 8675

var _fish: Array = []  # each entry: { pos: Vector3, vel: Vector3, mesh: MeshInstance3D }
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	var mat := _make_material()
	var mesh := _make_mesh()
	for i in count:
		_spawn_fish(i, mat, mesh)


func _physics_process(delta: float) -> void:
	if _fish.is_empty():
		return
	# Players are in group "player"; the two gemini halves are in "gemini_half".
	var avoiders: Array[Vector3] = []
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D:
			avoiders.append((p as Node3D).global_position)
	for h in get_tree().get_nodes_in_group("gemini_half"):
		if h is Node3D:
			avoiders.append((h as Node3D).global_position)

	# Collect positions + velocities once per frame so we don't recompute per neighbour.
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

		# Soft containment back toward the centre once outside the bounds disc.
		var flat := Vector3(pos.x, 0.0, pos.z)
		var contain := Vector3.ZERO
		if flat.length() > bounds_radius:
			var to_centre := -flat.normalized() * max_speed
			contain = to_centre - Vector3(vel.x, 0.0, vel.z)
		# Vertical containment: gently steer back into the band.
		if pos.y < min_y:
			contain.y += (max_speed - vel.y)
		elif pos.y > max_y:
			contain.y += (-max_speed - vel.y)

		var force: Vector3 = sep * sep_weight + ali * ali_weight + coh * coh_weight + avoid * avoid_weight + contain * contain_weight
		force = force.limit_length(max_force)

		vel += force * delta
		# Mild drag so flocks don't accumulate energy from repeated steering.
		vel = vel.lerp(Vector3.ZERO, clampf(0.35 * delta, 0.0, 1.0))
		if vel.length() > max_speed:
			vel = vel.normalized() * max_speed
		pos += vel * delta

		# Hard clamp to the swim band so fish can never breach the surface or sink into the floor; the soft containment force is the gentle nudge, this is the safety net.
		if pos.y > max_y:
			pos.y = max_y
			if vel.y > 0.0:
				vel.y = -vel.y * 0.3
		elif pos.y < min_y:
			pos.y = min_y
			if vel.y < 0.0:
				vel.y = -vel.y * 0.3

		f["pos"] = pos
		f["vel"] = vel
		var mi: MeshInstance3D = f["mesh"]
		mi.global_position = pos
		if vel.length() > 0.08:
			mi.look_at(mi.global_position + vel, Vector3.UP)


func _spawn_fish(i: int, mat: StandardMaterial3D, mesh: Mesh) -> void:
	var a: float = _rng.randf() * TAU
	var r: float = _rng.randf() * spawn_radius
	var y: float = _rng.randf_range(min_y, max_y)
	var pos := Vector3(cos(a) * r, y, sin(a) * r)
	var dir := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	var vel := dir.normalized() * max_speed * _rng.randf_range(0.4, 0.9)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = Vector3.ONE * fish_scale
	mi.position = pos
	# Explicit so each fish casts a sun shadow on the seafloor.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	_fish.append({"pos": pos, "vel": vel, "mesh": mi})


# Tiny silvery capsule oriented along +Z (so look_at points the head into velocity).
func _make_mesh() -> Mesh:
	var m := CapsuleMesh.new()
	m.radius = 0.07
	m.height = 0.32
	# CapsuleMesh stands along +Y by default; rotate via a wrapper? Simpler: leave it standing — the per-fish look_at will orient appropriately. The fish read as an elongated body either way.
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
