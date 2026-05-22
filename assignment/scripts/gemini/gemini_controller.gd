class_name GeminiController
extends Node3D

# M3 brain. Owns the two halves (Castor = striker, Pollux = distractor),
# the Blackboard + Behaviour Tree, and the fuse/split hunt FSM. The node
# itself never moves; it tracks a logical "centre" the fused pair flies,
# and commands each half every frame. Halves live in the scene root so
# they steer in world space when split.

const TWO_EYE := preload("res://assignment/scenes/two_eye.tscn")
const PREY := preload("res://assignment/scenes/prey.tscn")

# NONE = fused. ENCIRCLE = Castor arcs out of sight to a hide spot.
# LURE = Pollux displays/mesmerises while Castor waits hidden.
# STRIKE = mesmerised kill (Castor bursts from hide).
# CHASE = prey spotted Castor and bolted; Castor runs it down (stamina-
# limited) while Pollux herds it back. REFUSE = re-fuse.
enum Hunt { NONE, ENCIRCLE, LURE, STRIKE, CHASE, REFUSE }

@export var player: PlayerProbe
@export var home: Node3D
@export var draw_gizmos: bool = true

@export var max_speed: float = 5.0
@export var formation_gap: float = 0.45
# Belly-to-belly dock offset in fused state: small vertical-only stack so the
# two halves overlap and read as one organism (Castor above, Pollux below).
@export var dock_gap: float = 0.1
@export var detect_prey_radius: float = 13.0
@export var hunger_to_hunt: float = 0.4
@export var lose_distance: float = 28.0
@export var hunt_cooldown: float = 6.0
@export var standoff_dist: float = 4.5
@export var hold_dist: float = 2.2
@export var hold_speed: float = 1.6
@export var hold_time: float = 1.4
@export var capture_dist: float = 1.1
@export var fuse_dist: float = 1.0
@export var encircle_radius: float = 6.0
@export var encircle_speed: float = 2.6
@export var hide_below: float = 1.4
@export var spot_dist: float = 5.0
@export var spot_cone: float = 0.35
@export var chase_stamina: float = 10.0
@export var corner_dist: float = 3.5
@export var encircle_timeout: float = 5.0
@export var cruise_altitude: float = 4.0

var bb: Blackboard
var _bt: BehaviorTree.BTNode
var _castor: TwoEye
var _pollux: TwoEye
var _audio: CreatureAudio

var _c_pos: Vector3
var _c_vel: Vector3 = Vector3.ZERO
var _wander := SteeringBehaviors.WanderState.new()

var _hunt: int = Hunt.NONE
var _target: Node3D
var _hold_t: float = 0.0
var _flash_t: float = 0.0
var _hunt_cd: float = 0.0
var _front: Vector3 = Vector3.FORWARD
var _enc_ang: float = 0.0
var _chase_t: float = 0.0
var _last_sound: String = ""
var _hud: Label


func _ready() -> void:
	bb = Blackboard.new()
	_build_tree()
	_c_pos = global_position
	# The scene tree is still instantiating; spawning siblings now is
	# rejected ("parent busy"). Defer until the tree is settled.
	_setup.call_deferred()


func _setup() -> void:
	# Drop the M2 single-body visual; the halves replace it.
	for n in ["Body", "Collision", "CamTarget"]:
		var old := get_node_or_null(n)
		if old:
			old.free()

	var root := get_parent()
	_castor = TWO_EYE.instantiate()
	_pollux = TWO_EYE.instantiate()
	root.add_child(_castor)
	root.add_child(_pollux)
	_castor.role = TwoEye.Role.STRIKER
	_pollux.role = TwoEye.Role.DISTRACTOR
	_castor.max_speed = max_speed
	_pollux.max_speed = max_speed * 0.95
	_castor.global_position = _c_pos + Vector3.UP * formation_gap
	_pollux.global_position = _c_pos - Vector3.UP * formation_gap
	_castor.set_glow(Color(0.2, 0.09, 0.03), Color(0.98, 0.6, 0.2), 1.4, 0.5)
	_pollux.set_glow(Color(0.03, 0.16, 0.2), Color(0.15, 0.85, 0.95), 1.4, 0.5)

	var spawner := PreySpawner.new()
	spawner.prey_scene = PREY
	root.add_child(spawner)
	if home:
		spawner.global_position = home.global_position

	# Let Prey perceive the player without per-fish wiring.
	if player:
		player.add_to_group("player")

	_audio = CreatureAudio.new()
	add_child(_audio)

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_color_override("font_color", Color.WHITE)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(_hud)


func _build_tree() -> void:
	var hunger_thr := hunger_to_hunt
	var flee := BehaviorTree.Sequence.new()
	flee.children = [
		BehaviorTree.Condition.new(func(b): return b.wariness > 0.5, "scared"),
		BehaviorTree.Action.new(func(b): return _go(b, "flee"), "flee"),
	]
	var hunt := BehaviorTree.Sequence.new()
	hunt.children = [
		BehaviorTree.Condition.new(
			func(b): return b.has_prey and b.hunger > hunger_thr and b.wariness < 0.4 and not b.tired(),
			"hungry+prey"),
		BehaviorTree.Action.new(func(b): return _go(b, "hunt"), "hunt"),
	]
	var rest := BehaviorTree.Sequence.new()
	rest.children = [
		BehaviorTree.Condition.new(func(b): return b.wants_rest() and b.wariness < 0.2, "tired"),
		BehaviorTree.Action.new(func(b): return _go(b, "rest"), "rest"),
	]
	var investigate := BehaviorTree.Sequence.new()
	investigate.children = [
		BehaviorTree.Condition.new(func(b): return b.has_player and b.player_dist < 9.0 and b.player_speed <= 2.4, "near_calm"),
		BehaviorTree.Action.new(func(b): return _go(b, "investigate"), "investigate"),
	]
	var wander := BehaviorTree.Action.new(func(b): return _go(b, "wander"), "wander")
	var root := BehaviorTree.Selector.new()
	root.children = [flee, hunt, rest, investigate, wander]
	_bt = root


func _go(b: Blackboard, m: String) -> int:
	b.mode = m
	return BehaviorTree.RUNNING


func _nearest_prey() -> Node3D:
	var best: Node3D = null
	var bd := detect_prey_radius
	for p in get_tree().get_nodes_in_group("prey"):
		var n := p as Node3D
		var d := _c_pos.distance_to(n.global_position)
		if d < bd:
			bd = d
			best = n
	return best


func _perceive() -> void:
	if player:
		bb.has_player = true
		bb.player_pos = player.sense_position()
		bb.player_speed = player.sense_speed()
		bb.player_dist = _c_pos.distance_to(bb.player_pos)
		var near := clampf((6.0 - bb.player_dist) / 6.0, 0.0, 1.0)
		var fast := clampf(bb.player_speed / 4.0, 0.0, 1.0)
		bb.threat = near * fast
	else:
		bb.has_player = false
		bb.threat = 0.0
	if _target == null or not is_instance_valid(_target):
		_target = _nearest_prey()
	bb.has_prey = _target != null and is_instance_valid(_target)


func _physics_process(delta: float) -> void:
	if _castor == null or _pollux == null:
		return
	_perceive()
	bb.update(delta)
	_bt.tick(bb)

	# Post-hunt cooldown: don't re-split the instant a hunt ends.
	if _hunt == Hunt.NONE and _hunt_cd > 0.0:
		_hunt_cd = maxf(_hunt_cd - delta, 0.0)
		if bb.mode == "hunt":
			bb.mode = "wander"

	var hunting := bb.mode == "hunt" and bb.has_prey
	if _hunt == Hunt.NONE and hunting:
		_hunt = Hunt.ENCIRCLE
		_chase_t = 0.0
		if _target and is_instance_valid(_target) and _castor:
			var b := (_castor.global_position - _target.global_position)
			_enc_ang = atan2(b.z, b.x)
	if _hunt != Hunt.NONE and (bb.wariness > 0.6 or not bb.has_prey):
		_abort_hunt()

	if _hunt == Hunt.NONE:
		_fused_step(delta)
	else:
		_hunt_step(delta)

	_update_audio()
	_update_hud()
	if draw_gizmos:
		_draw()


# --- Fused: fly the centre by the BT mode, dock both halves to it -------
func _fused_step(delta: float) -> void:
	var f := Vector3.ZERO
	match bb.mode:
		"flee":
			f = SteeringBehaviors.flee(_c_pos, bb.player_pos, _c_vel, max_speed) * 2.0
		"investigate":
			var to_me := _c_pos - bb.player_pos
			if to_me.length() < 0.01:
				to_me = Vector3.FORWARD
			var tang := to_me.normalized().cross(Vector3.UP).normalized()
			f = (tang * max_speed * 0.5 - to_me.normalized() * (to_me.length() - 3.0) * 0.5) - _c_vel
		"rest":
			var anchor := home.global_position if home else _c_pos
			f = SteeringBehaviors.arrive(_c_pos, anchor, _c_vel, max_speed, 4.0) * 0.6
		_:
			f = SteeringBehaviors.wander3d(_wander, _heading(), _c_vel, max_speed, delta)

	var dy := cruise_altitude - _c_pos.y
	if absf(dy) > 2.5:
		f.y += (signf(dy) * max_speed - _c_vel.y) * 0.9

	_integrate_centre(f, delta)

	# Fused: dock vertically-stacked belly-to-belly so the pair reads as one organism.
	var up := Vector3.UP * dock_gap
	_command(_castor, "dock", _c_pos + up, Vector3.ZERO)
	_command(_pollux, "dock", _c_pos - up, Vector3.ZERO)
	var w: float = bb.wariness
	_castor.set_glow(Color(0.2, 0.09, 0.03), Color(0.98, 0.6, 0.2), lerpf(1.3, 5.0, w), lerpf(0.5, 0.18, w))
	_pollux.set_glow(Color(0.03, 0.16, 0.2), Color(0.15, 0.85, 0.95), lerpf(1.3, 5.0, w), lerpf(0.5, 0.18, w))


# --- Split hunt: Pollux lures + signals, Castor stalks + strikes --------
func _hunt_step(delta: float) -> void:
	if _hunt == Hunt.REFUSE:
		# Re-fuse to the same tight belly-to-belly stack used in fused state.
		_command(_castor, "dock", _c_pos + Vector3.UP * dock_gap, Vector3.ZERO)
		_command(_pollux, "dock", _c_pos - Vector3.UP * dock_gap, Vector3.ZERO)
		# Satisfied re-fuse flash, decaying.
		if _flash_t > 0.0:
			_flash_t = maxf(_flash_t - delta, 0.0)
			var fp := 1.0 + _flash_t * 6.0
			_castor.set_glow(Color(0.2, 0.09, 0.03), Color(1.0, 0.7, 0.3), 1.4, fp)
			_pollux.set_glow(Color(0.03, 0.16, 0.2), Color(0.3, 1.0, 1.0), 1.4, fp)
		var cd := _castor.global_position.distance_to(_c_pos + Vector3.UP * dock_gap)
		var pd := _pollux.global_position.distance_to(_c_pos - Vector3.UP * dock_gap)
		if cd < fuse_dist and pd < fuse_dist:
			# Re-attach and keep gliding: carry the pair's momentum into
			# the fused centre instead of stalling at the dock point.
			_c_vel = (_castor.velocity + _pollux.velocity) * 0.5
			_hunt = Hunt.NONE
		return

	var prey := _target as Node3D
	var ppos: Vector3 = prey.global_position
	var pvel: Vector3 = (prey as SteeringAgent).velocity if prey is SteeringAgent else Vector3.ZERO
	# Smooth the prey-facing direction; raw velocity jitters from wander.
	var raw_front := pvel.normalized() if pvel.length() > 0.1 else (ppos - _pollux.global_position).normalized()
	_front = _front.lerp(raw_front, clampf(delta * 3.0, 0.0, 1.0))
	if _front.length() < 0.01:
		_front = Vector3.FORWARD
	var front := _front.normalized()

	# Centre trails the pair so lose_distance is measured from the action.
	_c_pos = _c_pos.lerp((_castor.global_position + _pollux.global_position) * 0.5, clampf(delta * 2.5, 0.0, 1.0))

	var hide := ppos - front * standoff_dist + Vector3.DOWN * hide_below
	var to_cas := _castor.global_position - ppos
	# Prey "sees" Castor if it is close AND inside the prey's forward cone.
	var spotted := to_cas.length() < spot_dist and to_cas.normalized().dot(front) > spot_cone
	prey.set("lure_pos", _pollux.global_position)

	match _hunt:
		Hunt.ENCIRCLE:
			# Pollux hangs back; prey not yet mesmerised. Castor arcs around
			# at range toward the "behind" bearing, fast and out of sight.
			prey.set("lure_active", false)
			_command(_pollux, "dock", ppos + front * 3.0 + Vector3.UP * 1.0, Vector3.ZERO)
			_enc_ang += encircle_speed * delta * _enc_dir(front)
			var ring := ppos + Vector3(cos(_enc_ang), 0.0, sin(_enc_ang)) * encircle_radius + Vector3.DOWN * (hide_below * 0.5)
			_command(_castor, "dock", ring, Vector3.ZERO)
			_chase_t += delta
			var behind := to_cas.normalized().dot(front) < -0.4
			if (behind and _castor.global_position.distance_to(hide) < encircle_radius * 0.7) or _chase_t > encircle_timeout:
				_hunt = Hunt.LURE
				_chase_t = 0.0
			if spotted:
				_hunt = Hunt.CHASE
				_chase_t = 0.0
		Hunt.LURE:
			# Pollux displays in front (fin-shake handled in TwoEye); Castor
			# waits hidden behind/below for the hold signal.
			_command(_pollux, "lure", ppos + front * 1.6, Vector3.ZERO)
			prey.set("lure_active", true)
			_command(_castor, "dock", hide, Vector3.ZERO)
			var held := _pollux.global_position.distance_to(ppos) < hold_dist and pvel.length() < hold_speed
			_hold_t = (_hold_t + delta) if held else maxf(_hold_t - delta, 0.0)
			if _hold_t >= hold_time:
				_hunt = Hunt.STRIKE
			# Spotted Castor, or saw through the lure after lure_attention.
			if spotted or bool(prey.get("bolted")):
				prey.set("lure_active", false)
				_hunt = Hunt.CHASE
				_chase_t = 0.0
		Hunt.STRIKE:
			_command(_pollux, "lure", ppos + front * 1.6, Vector3.ZERO)
			_command(_castor, "strike", ppos, pvel)
			if _castor.global_position.distance_to(ppos) < capture_dist:
				_capture(ppos)
				return
			if spotted or bool(prey.get("bolted")):
				prey.set("lure_active", false)
				_hunt = Hunt.CHASE
				_chase_t = 0.0
		Hunt.CHASE:
			# Prey bolted. Castor runs it down (stamina-limited); Pollux
			# gets on the far side to herd it back toward Castor.
			prey.set("lure_active", false)
			_chase_t += delta
			_command(_castor, "strike", ppos, pvel)
			var herd := ppos + (ppos - _castor.global_position).normalized() * corner_dist
			_command(_pollux, "dock", herd, Vector3.ZERO)
			if _castor.global_position.distance_to(ppos) < capture_dist:
				_capture(ppos)
				return
			if _chase_t >= chase_stamina:
				_abort_hunt()
				return

	if _c_pos.distance_to(ppos) > lose_distance:
		_abort_hunt()
		return

	var luring := _hunt == Hunt.LURE
	_pollux.set_glow(Color(0.03, 0.16, 0.2), Color(0.2, 1.0, 1.0), 3.5 if luring else 2.0, 0.7 if luring else 0.4)
	var cbright := 0.8 if (_hunt == Hunt.STRIKE or _hunt == Hunt.CHASE) else 0.2
	_castor.set_glow(Color(0.2, 0.09, 0.03), Color(1.0, 0.5, 0.15), 2.0, cbright)


func _capture(at: Vector3) -> void:
	_spawn_burst(at)
	if is_instance_valid(_target) and _target.has_method("captured"):
		_target.captured()
	_target = null
	bb.hunger = maxf(bb.hunger - 0.5, 0.0)
	bb.energy = maxf(bb.energy - 0.15, 0.0)
	_hold_t = 0.0
	_flash_t = 0.5
	_hunt_cd = hunt_cooldown
	_hunt = Hunt.REFUSE


func _abort_hunt() -> void:
	if is_instance_valid(_target) and _target.has_method("captured"):
		_target.set("lure_active", false)
	_target = null
	_hold_t = 0.0
	_hunt_cd = hunt_cooldown
	_hunt = Hunt.REFUSE


func _command(half: TwoEye, mode: String, target: Vector3, aux: Vector3) -> void:
	half.cmd_mode = mode
	half.cmd_target = target
	half.cmd_aux = aux


func _heading() -> Vector3:
	if _c_vel.length() > 0.05:
		return _c_vel.normalized()
	return Vector3.FORWARD


# Shortest-arc spin direction to bring Castor's bearing behind the prey.
func _enc_dir(front: Vector3) -> float:
	var target := atan2(-front.z, -front.x)
	var d := wrapf(target - _enc_ang, -PI, PI)
	return signf(d) if absf(d) > 0.05 else 0.0


func _integrate_centre(force: Vector3, delta: float) -> void:
	_c_vel += force.limit_length(20.0) * delta
	_c_vel = _c_vel.lerp(Vector3.ZERO, clampf(0.8 * delta, 0.0, 1.0))
	if _c_vel.length() > max_speed:
		_c_vel = _c_vel.normalized() * max_speed
	_c_pos += _c_vel * delta
	_c_pos.y = clampf(_c_pos.y, 0.8, 18.0)
	var flat := Vector3(_c_pos.x, 0.0, _c_pos.z)
	if flat.length() > 26.0:
		flat = flat.normalized() * 26.0
		_c_pos.x = flat.x
		_c_pos.z = flat.z


# TODO(placeholder): coded GPUParticles3D capture burst; promote to an authored particle scene during polish. See ARCHITECTURE.md §9.
func _spawn_burst(at: Vector3) -> void:
	var fx := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -1.0, 0)
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	fx.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	fx.draw_pass_1 = mesh
	fx.amount = 40
	fx.lifetime = 0.9
	fx.one_shot = true
	fx.explosiveness = 0.95
	fx.emitting = true
	get_parent().add_child(fx)
	fx.global_position = at
	get_tree().create_timer(2.0).timeout.connect(fx.queue_free)


func _update_audio() -> void:
	var snd := bb.mode
	# Lure = the "look at me" attention call (curious cue); the chase/
	# strike = the wary cue. TODO(placeholder): a dedicated lure/dance
	# SFX + a hunt row in CreatureAudio.MODE_SOUND.
	if _hunt == Hunt.LURE:
		snd = "investigate"
	elif _hunt != Hunt.NONE:
		snd = "flee"
	if snd != _last_sound:
		_last_sound = snd
		if _audio:
			_audio.set_mode(snd)


func _state_name() -> String:
	match _hunt:
		Hunt.ENCIRCLE:
			return "HUNT:encircle"
		Hunt.LURE:
			return "HUNT:lure"
		Hunt.STRIKE:
			return "HUNT:strike"
		Hunt.CHASE:
			return "HUNT:chase"
		Hunt.REFUSE:
			return "REFUSE"
	return bb.mode


func _update_hud() -> void:
	if _hud == null:
		return
	var prey_n := get_tree().get_nodes_in_group("prey").size()
	var tgt := "yes" if (_target and is_instance_valid(_target)) else "no"
	_hud.text = "GEMINI  state=%s   E=%.2f  H=%.2f  W=%.2f%s\nCastor cmd=%s    Pollux cmd=%s\nPREY  alive=%d  target=%s  hold=%.1f/%.1f" % [
		_state_name(), bb.energy, bb.hunger, bb.wariness,
		("  cd=%.1f" % _hunt_cd) if _hunt_cd > 0.0 else "",
		_castor.cmd_mode if _castor else "-",
		_pollux.cmd_mode if _pollux else "-",
		prey_n, tgt, _hold_t, hold_time,
	]


func _draw() -> void:
	var col := Color.SEA_GREEN
	if _hunt != Hunt.NONE:
		col = Color.CRIMSON
	elif bb.mode == "flee":
		col = Color.ORANGE_RED
	elif bb.mode == "investigate":
		col = Color.GOLD
	elif bb.mode == "rest":
		col = Color.MEDIUM_PURPLE
	DebugDraw3D.draw_sphere(_c_pos, 0.4, col)
	# Per-half gizmos so both are visible whether fused or split.
	if _castor:
		var ccol := Color.RED if (_hunt == Hunt.STRIKE or _hunt == Hunt.CHASE) else Color.ORANGE
		DebugDraw3D.draw_sphere(_castor.global_position, 0.5, ccol)
		DebugDraw3D.draw_line(_c_pos, _castor.global_position, Color.ORANGE)
	if _pollux:
		var pcol := Color.AQUA if _hunt != Hunt.NONE else Color.CYAN
		DebugDraw3D.draw_sphere(_pollux.global_position, 0.5, pcol)
		DebugDraw3D.draw_line(_c_pos, _pollux.global_position, Color.CYAN)
	if _castor and _pollux:
		DebugDraw3D.draw_line(_castor.global_position, _pollux.global_position, Color.DIM_GRAY)
	if _target and is_instance_valid(_target):
		DebugDraw3D.draw_sphere(_target.global_position, 0.6, Color.YELLOW)
		if (_hunt == Hunt.STRIKE or _hunt == Hunt.CHASE) and _castor:
			DebugDraw3D.draw_line(_castor.global_position, _target.global_position, Color.RED)
