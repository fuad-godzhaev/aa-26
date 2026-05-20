class_name TwoEyeMesh
extends Node

# Procedural skin-weighted ArrayMesh for one Gemini half.
# Foureye-butterflyfish silhouette: flat-bodied (wider X than Y), tapered ends.
# Coordinate frame: +Z forward, head at z=-0.6, tail at z=+0.6, +Y up.
# Skinned to a 3-bone Skeleton3D (root, mid, tail) built elsewhere.

# Bone metadata exposed for the skeleton + animation builder to read.
const BONE_NAMES := ["root", "mid", "tail"]
const BONE_POSITIONS := [Vector3(0, 0, -0.4), Vector3(0, 0, 0.0), Vector3(0, 0, 0.4)]

# Body extents.
const BODY_LENGTH := 1.2
const HALF_LENGTH := 0.6
const X_HALF := 0.225
const Y_HALF := 0.15

# Ring layout: 7 z-rings between the two point caps, 8 verts per ring.
const RING_Z := [-0.45, -0.25, -0.10, 0.00, 0.10, 0.25, 0.45]
const RING_SEGMENTS := 8


# Returns a fully populated ArrayMesh with one PRIMITIVE_TRIANGLES surface.
static func build() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()

	# Head point cap at z = -0.6.
	var head_idx := verts.size()
	verts.push_back(Vector3(0, 0, -HALF_LENGTH))
	uvs.push_back(Vector2(0.5, 0.0))
	_push_weights(bones, weights, -HALF_LENGTH)

	# Body rings.
	var ring_start: Array[int] = []
	for ri in RING_Z.size():
		var z: float = RING_Z[ri]
		ring_start.append(verts.size())
		# Taper profile: bell-shaped, fattest at z = 0, slim at ends.
		# t in [0,1] where 0 = end, 1 = middle.
		var t: float = 1.0 - abs(z) / HALF_LENGTH
		# Smooth widening curve; keeps cross-section non-zero at all rings.
		var taper: float = sqrt(clampf(t, 0.0, 1.0))
		var rx: float = X_HALF * taper
		var ry: float = Y_HALF * taper
		for s in RING_SEGMENTS:
			var ang: float = TAU * float(s) / float(RING_SEGMENTS)
			var lx: float = rx * cos(ang)
			var ly: float = ry * sin(ang)
			verts.push_back(Vector3(lx, ly, z))
			# Cylindrical UV: U from angle, V from z along body length.
			var u: float = fposmod(atan2(ly, lx) / TAU + 1.0, 1.0)
			var v: float = (z + HALF_LENGTH) / BODY_LENGTH
			uvs.push_back(Vector2(u, v))
			_push_weights(bones, weights, z)

	# Tail point cap at z = +0.6.
	var tail_idx := verts.size()
	verts.push_back(Vector3(0, 0, HALF_LENGTH))
	uvs.push_back(Vector2(0.5, 1.0))
	_push_weights(bones, weights, HALF_LENGTH)

	# Triangles: head fan -> first ring.
	var first_ring: int = ring_start[0]
	for s in RING_SEGMENTS:
		var a := first_ring + s
		var b := first_ring + (s + 1) % RING_SEGMENTS
		# Outward winding (CCW when viewed from outside) so normals face out.
		indices.push_back(head_idx)
		indices.push_back(b)
		indices.push_back(a)

	# Quad strips between adjacent rings.
	for ri in RING_Z.size() - 1:
		var r0: int = ring_start[ri]
		var r1: int = ring_start[ri + 1]
		for s in RING_SEGMENTS:
			var sn := (s + 1) % RING_SEGMENTS
			var a := r0 + s
			var b := r0 + sn
			var c := r1 + s
			var d := r1 + sn
			# Two triangles, outward-facing winding.
			indices.push_back(a)
			indices.push_back(b)
			indices.push_back(d)
			indices.push_back(a)
			indices.push_back(d)
			indices.push_back(c)

	# Tail fan: last ring -> tail point.
	var last_ring: int = ring_start[ring_start.size() - 1]
	for s in RING_SEGMENTS:
		var a := last_ring + s
		var b := last_ring + (s + 1) % RING_SEGMENTS
		indices.push_back(tail_idx)
		indices.push_back(a)
		indices.push_back(b)

	# Per-vertex normals: average adjacent face normals, normalize.
	var normals := _compute_normals(verts, indices)

	# Assemble surface arrays (13-element layout per Mesh.ARRAY_*).
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# Skin-weight assignment by local z. Smooth blend across the two zone borders
# at z = -0.2 and z = +0.2 so deformation does not crease.
static func _push_weights(bones: PackedInt32Array, weights: PackedFloat32Array, z: float) -> void:
	var w_root := 0.0
	var w_mid := 0.0
	var w_tail := 0.0
	if z <= -0.2:
		# Head zone: root dominant, weight 1.0 at z=-0.6 down to 0.5 at z=-0.2.
		var t: float = clampf((z + 0.6) / 0.4, 0.0, 1.0)
		w_root = lerpf(1.0, 0.5, t)
		w_mid = 1.0 - w_root
	elif z >= 0.2:
		# Tail zone: tail dominant, weight 0.5 at z=+0.2 up to 1.0 at z=+0.6.
		var t: float = clampf((z - 0.2) / 0.4, 0.0, 1.0)
		w_tail = lerpf(0.5, 1.0, t)
		w_mid = 1.0 - w_tail
	else:
		# Mid zone: mid dominant, 1.0 at z=0 falling to 0.5 at zone edges,
		# blending with the neighbour bone on the appropriate side.
		var f: float = clampf(abs(z) / 0.2, 0.0, 1.0)
		w_mid = lerpf(1.0, 0.5, f)
		var neighbour := 1.0 - w_mid
		if z < 0.0:
			w_root = neighbour
		else:
			w_tail = neighbour

	# Normalise defensively (lerp math should already sum to 1.0).
	var total := w_root + w_mid + w_tail
	if total > 0.0:
		w_root /= total
		w_mid /= total
		w_tail /= total

	bones.push_back(0)
	bones.push_back(1)
	bones.push_back(2)
	bones.push_back(0)
	weights.push_back(w_root)
	weights.push_back(w_mid)
	weights.push_back(w_tail)
	weights.push_back(0.0)


# Compute outward-facing per-vertex normals by accumulating face normals.
static func _compute_normals(verts: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in normals.size():
		normals[i] = Vector3.ZERO
	var tri_count := indices.size() / 3
	for t in tri_count:
		var i0 := indices[t * 3 + 0]
		var i1 := indices[t * 3 + 1]
		var i2 := indices[t * 3 + 2]
		var v0 := verts[i0]
		var v1 := verts[i1]
		var v2 := verts[i2]
		var fn := (v1 - v0).cross(v2 - v0)
		var len := fn.length()
		if len > 0.0:
			fn /= len
		normals[i0] += fn
		normals[i1] += fn
		normals[i2] += fn
	for i in normals.size():
		var n := normals[i]
		if n.length() > 0.0:
			normals[i] = n.normalized()
		else:
			normals[i] = Vector3.UP
	return normals
