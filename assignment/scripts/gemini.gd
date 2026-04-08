class_name Gemini
extends SteeringAgent

# M2: the fused organism, now brain-driven. A Behaviour Tree picks a mode
# from the Blackboard (needs + perception); _compute_steering turns that
# mode into a steering force, blended with a home tether and obstacle
# avoidance. Glow and body animation react to the mode. Split into
# Castor/Pollux + Hunt branch arrive in M3.

@export var player: PlayerProbe
@export var home: Node3D
@export var glow_material: ShaderMaterial

@export var flee_radius: float = 6.0
@export var scare_speed: float = 4.0
@export var investigate_radius: float = 9.0
@export var investigate_distance: float = 3.0
@export var home_radius: float = 11.0
@export var wander_weight: float = 1.0
@export var flee_weight: float = 2.0
@export var tether_weight: float = 1.7
@export var avoid_weight: float = 2.4
@export var avoid_look_ahead: float = 5.0
@export var cruise_altitude: float = 4.0
@export var depth_band: float = 2.5
@export var depth_weight: float = 0.9
@export var orbit_speed: float = 0.55
@export var curiosity_time: float = 7.0
@export var curiosity_cooldown: float = 5.0

var _inspect_t: float = 0.0
var _bored_t: float = 0.0
var _wander := SteeringBehaviors.WanderState.new()
var bb: Blackboard
var _bt: BehaviorTree.BTNode
var _obstacles: Array = []
var _audio: CreatureAudio
var _last_mode: String = ""

@onready var _body := get_node_or_null("Body") as Node3D
@onready var _tail := get_node_or_null("Body/Tail") as Node3D
var _tail_base: Transform3D
var _anim_t: float = 0.0


func _ready() -> void:
	bb = Blackboard.new()
	_build_tree()
	_collect_obstacles()
	if _tail:
		_tail_base = _tail.transform
	_audio = CreatureAudio.new()
	add_child(_audio)


func _build_tree() -> void:
	# Capture tunables into locals so the leaf lambdas close over values.
	var inv_r := investigate_radius
	var calm_speed := scare_speed * 0.6

	var flee := BehaviorTree.Sequence.new()
	flee.children = [
		BehaviorTree.Condition.new(func(b): return b.wariness > 0.5, "scared"),
		BehaviorTree.Action.new(func(b): return _go(b, "flee"), "flee"),
	]
	var rest := BehaviorTree.Sequence.new()
	rest.children = [
		BehaviorTree.Condition.new(func(b): return b.tired() and b.wariness < 0.2, "tired"),
		BehaviorTree.Action.new(func(b): return _go(b, "rest"), "rest"),
	]
	var investigate := BehaviorTree.Sequence.new()
	investigate.children = [
		BehaviorTree.Condition.new(
			func(b): return b.has_player and b.player_dist < inv_r and b.player_speed <= calm_speed,
			"player_near_calm"),
		BehaviorTree.Action.new(func(b): return _go(b, "investigate"), "investigate"),
	]
	var wander := BehaviorTree.Action.new(func(b): return _go(b, "wander"), "wander")

	var root := BehaviorTree.Selector.new()
	root.children = [flee, rest, investigate, wander]
	_bt = root


func _go(b: Blackboard, m: String) -> int:
	b.mode = m
	return BehaviorTree.RUNNING


func _collect_obstacles() -> void:
	_obstacles = []
	var p := get_parent()
	if p == null:
		return
	for c in p.get_children():
		if c == self:
			continue
		var n := String(c.name)
		if n.begins_with("Rock") or n.begins_with("Coral"):
			var c3 := c as Node3D
			if c3 == null:
				continue
			var r := 1.3
			if c is CSGSphere3D:
				r = (c as CSGSphere3D).radius * maxf(c3.scale.x, c3.scale.z)
			var gp := c3.global_position
			_obstacles.append(Vector4(gp.x, gp.y, gp.z, r))


func _perceive() -> void:
	if player:
		bb.has_player = true
		bb.player_pos = player.sense_position()
		bb.player_speed = player.sense_speed()
		bb.player_dist = global_position.distance_to(bb.player_pos)
		var near := clampf((flee_radius - bb.player_dist) / flee_radius, 0.0, 1.0)
		var fast := clampf(bb.player_speed / scare_speed, 0.0, 1.0)
		bb.threat = near * fast
	else:
		bb.has_player = false
		bb.threat = 0.0


func _compute_steering(delta: float) -> Vector3:
	_perceive()
	bb.update(delta)
	_bt.tick(bb)
	_apply_curiosity(delta)

	var pos := global_position
	var f := Vector3.ZERO
	match bb.mode:
		"flee":
			f = SteeringBehaviors.flee(pos, bb.player_pos, velocity, max_speed) * flee_weight
		"investigate":
			f = _orbit_player(pos)
		"rest":
			var anchor := home.global_position if home else pos
			f = SteeringBehaviors.arrive(pos, anchor, velocity, max_speed, slowing_distance) * 0.6
		_:
			f = SteeringBehaviors.wander3d(_wander, forward(), velocity, max_speed, delta) * wander_weight

	if home and pos.distance_to(home.global_position) > home_radius:
		f += SteeringBehaviors.arrive(pos, home.global_position, velocity, max_speed, slowing_distance) * tether_weight

	if _obstacles.size() > 0:
		f += SteeringBehaviors.avoid_spheres(pos, velocity, max_speed, _obstacles, avoid_look_ahead) * avoid_weight

	# Keep to a mid-water cruising depth so it rarely grinds the floor/
	# ceiling clamp (the source of vertical jitter).
	var dy := cruise_altitude - pos.y
	if absf(dy) > depth_band:
		f.y += (signf(dy) * max_speed - velocity.y) * depth_weight

	if bb.mode != _last_mode:
		_last_mode = bb.mode
		if _audio:
			_audio.set_mode(bb.mode)

	_update_glow()
	if draw_gizmos:
		_draw_perception()
	return f


# Curiosity is finite: it inspects for a while, gets bored and drifts off
# (even if the player stays still), then can re-engage after a cooldown.
# Stops the "stares forever until the player moves" passivity.
func _apply_curiosity(delta: float) -> void:
	if _bored_t > 0.0:
		_bored_t -= delta
		if bb.mode == "investigate":
			bb.mode = "wander"
	if bb.mode == "investigate":
		_inspect_t += delta
		if _inspect_t >= curiosity_time:
			_inspect_t = 0.0
			_bored_t = curiosity_cooldown
			bb.mode = "wander"
	else:
		_inspect_t = maxf(_inspect_t - delta * 0.5, 0.0)


# Active inspection: circle the player at the standoff radius with a gentle
# bob, easing the radius — always moving, never a frozen stare.
func _orbit_player(pos: Vector3) -> Vector3:
	var to_me := pos - bb.player_pos
	var dist := to_me.length()
	if dist < 0.001:
		to_me = Vector3.FORWARD
		dist = 1.0
	var radial := to_me / dist
	var tangent := radial.cross(Vector3.UP)
	if tangent.length() < 0.001:
		tangent = radial.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var radial_err := dist - investigate_distance
	var desired := tangent * max_speed * orbit_speed
	desired -= radial * clampf(radial_err, -1.5, 1.5) * max_speed * 0.5
	desired.y += sin(_anim_t * 1.3) * max_speed * 0.15
	return desired - velocity


# Tail sway scaled by speed + a gentle body turn toward the player while
# investigating (procedural "looking at you"). Richer rig in M3.
func _process(delta: float) -> void:
	_anim_t += delta * (2.0 + speed)
	if _tail:
		var s := sin(_anim_t)
		_tail.transform = _tail_base * Transform3D(Basis(Vector3.UP, 0.5 * s), Vector3.ZERO)
	if _body == null or bb == null:
		return
	var target_yaw := 0.0
	if bb.mode == "investigate" and bb.has_player:
		var local := global_transform.basis.inverse() * (bb.player_pos - global_position)
		target_yaw = clampf(atan2(local.x, -local.z), -0.6, 0.6)
	_body.rotation.y = lerp_angle(_body.rotation.y, target_yaw, delta * 4.0)


# Calm = slow strong teal pulse; wary = fast dim; rest = very slow, dim.
func _update_glow() -> void:
	if glow_material == null:
		return
	var w: float = bb.wariness if bb else 0.0
	var sp := lerpf(1.3, 5.0, w)
	var st := lerpf(0.55, 0.18, w)
	if bb and bb.mode == "rest":
		sp = 0.7
		st = 0.25
	glow_material.set_shader_parameter("pulse_speed", sp)
	glow_material.set_shader_parameter("pulse_strength", st)


func _draw_perception() -> void:
	var pos := global_position
	var col := Color.SEA_GREEN
	match bb.mode:
		"flee":
			col = Color.ORANGE_RED
		"investigate":
			col = Color.GOLD
		"rest":
			col = Color.MEDIUM_PURPLE
	DebugDraw3D.draw_sphere(pos, flee_radius, col)
	if bb.has_player:
		DebugDraw3D.draw_line(pos, bb.player_pos, Color.WHITE_SMOKE)
	for o in _obstacles:
		DebugDraw3D.draw_sphere(Vector3(o.x, o.y, o.z), o.w, Color.DIM_GRAY)
