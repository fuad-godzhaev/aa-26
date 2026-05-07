class_name KelpForest
extends Node3D

# Procedural ring of dense kelp around the playable area limit; each stalk has a static collider. See ARCHITECTURE.md.

const KELP_SHADER := preload("res://assignment/materials/kelp.gdshader")

@export var ring_radius: float = 27.5
@export var ring_thickness: float = 4.0
@export var count: int = 320
# Number of concentric rings; total stalks = count * rings spread radially.
@export var rings: int = 3
# Stalks grow up to the waterline (~y=18 with seafloor top at y=-0.5).
@export var height_min: float = 16.0
@export var height_max: float = 18.4
@export var base_y: float = -0.4
@export var sway_speed: float = 1.0
# Sway is anchored at the base and scales with mesh-local Y, so very tall stalks have very large absolute sway. Reduced compared to the short kelp to keep tip travel sane.
@export var sway_amount: float = 0.06
@export var kelp_color: Color = Color(0.05, 0.24, 0.13, 1.0)
@export var add_collision: bool = true
@export var collision_radius: float = 0.22
@export var random_seed: int = 1729

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	var mat := _make_material()
	# Spread stalks across multiple concentric rings so the forest is dense in depth, not just along one circle.
	var per_ring: int = int(count / maxi(rings, 1))
	var spacing: float = ring_thickness / maxf(float(rings - 1), 1.0) if rings > 1 else 0.0
	for r_idx in rings:
		var r_base: float = ring_radius - ring_thickness * 0.5 + spacing * float(r_idx) if rings > 1 else ring_radius
		for i in per_ring:
			_spawn_stalk(i, mat, r_base, r_idx)


# Per-instance ShaderMaterial: kelp shader sways the vertices by world position so each stalk reads as out-of-phase automatically.
func _make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = KELP_SHADER
	m.set_shader_parameter("kelp_color", kelp_color)
	m.set_shader_parameter("sway_speed", sway_speed)
	m.set_shader_parameter("sway_amount", sway_amount)
	return m


# One stalk = StaticBody3D + MeshInstance3D + CollisionShape3D (thin upright cylinder).
func _spawn_stalk(i: int, mat: ShaderMaterial, r_base: float, ring_index: int) -> void:
	var per_ring: int = int(count / maxi(rings, 1))
	# Stagger adjacent rings by half a slot so colliders don't line up into radial gaps.
	var offset: float = (PI / float(per_ring)) if (ring_index % 2 == 1) else 0.0
	var angle: float = TAU * float(i) / float(per_ring) + offset + _rng.randf_range(-0.012, 0.012)
	var r: float = r_base + _rng.randf_range(-0.35, 0.35)
	var h: float = _rng.randf_range(height_min, height_max)
	var pos := Vector3(cos(angle) * r, base_y + h * 0.5, sin(angle) * r)

	var body: Node3D
	if add_collision:
		body = StaticBody3D.new()
	else:
		body = Node3D.new()
	body.position = pos
	add_child(body)

	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.04
	mesh.bottom_radius = 0.08
	mesh.height = h
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)

	if add_collision:
		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = collision_radius
		cs.height = h
		col.shape = cs
		body.add_child(col)
