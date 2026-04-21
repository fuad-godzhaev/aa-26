class_name KelpForest
extends Node3D

# Procedural ring of dense kelp around the playable area limit; each stalk has a static collider. See ARCHITECTURE.md.

const KELP_SHADER := preload("res://assignment/materials/kelp.gdshader")

@export var ring_radius: float = 28.0
@export var ring_thickness: float = 3.6
@export var count: int = 140
@export var height_min: float = 3.6
@export var height_max: float = 5.4
@export var base_y: float = -0.4
@export var sway_speed: float = 1.0
@export var sway_amount: float = 0.28
@export var kelp_color: Color = Color(0.04, 0.22, 0.12, 1.0)
@export var add_collision: bool = true
@export var collision_radius: float = 0.18
@export var random_seed: int = 1729

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	var mat := _make_material()
	for i in count:
		_spawn_stalk(i, mat)


# Per-instance ShaderMaterial: kelp shader sways the vertices by world position so each stalk reads as out-of-phase automatically.
func _make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = KELP_SHADER
	m.set_shader_parameter("kelp_color", kelp_color)
	m.set_shader_parameter("sway_speed", sway_speed)
	m.set_shader_parameter("sway_amount", sway_amount)
	return m


# One stalk = StaticBody3D + MeshInstance3D + CollisionShape3D (thin upright cylinder).
func _spawn_stalk(i: int, mat: ShaderMaterial) -> void:
	var angle: float = TAU * float(i) / float(count) + _rng.randf_range(-0.025, 0.025)
	var r: float = ring_radius + _rng.randf_range(-ring_thickness * 0.5, ring_thickness * 0.5)
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
