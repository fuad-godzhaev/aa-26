class_name Blackboard
extends RefCounted

# Shared state the Behaviour Tree reads and the agent writes. Holds the
# drives (needs), the latest perception, and the BT's chosen mode.

# Needs, 0..1.
var hunger: float = 0.2
var energy: float = 1.0
var wariness: float = 0.0

# Perception, refreshed by the agent every physics frame.
var has_player: bool = false
var player_pos: Vector3 = Vector3.ZERO
var player_speed: float = 0.0
var player_dist: float = INF
var threat: float = 0.0

# Arbitration output, set by BT actions, consumed by the agent.
var mode: String = "wander"

# Tunables.
var hunger_rate: float = 0.012
var energy_drain: float = 0.02
var energy_drain_active: float = 0.08
var energy_recover: float = 0.16
var wariness_attack: float = 3.0
var wariness_decay: float = 0.4


func update(delta: float) -> void:
	hunger = clampf(hunger + hunger_rate * delta, 0.0, 1.0)

	if mode == "rest":
		energy = clampf(energy + energy_recover * delta, 0.0, 1.0)
	else:
		var drain := energy_drain
		if mode == "flee" or mode == "hunt":
			drain += energy_drain_active
		energy = clampf(energy - drain * delta, 0.0, 1.0)

	var rate := wariness_attack if threat > wariness else wariness_decay
	wariness = move_toward(wariness, threat, rate * delta)


func tired() -> bool:
	return energy < 0.25


func rested() -> bool:
	return energy > 0.9
