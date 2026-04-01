# Gemini — Codebase Architecture & Design

Detailed, human-facing documentation of the Autonomous Agents 2026
assignment. This is a **living document**: every code change is accompanied
by an update here in the same commit. Code carries only single-line
comments; the explanation lives here.

---

## 1. The brief and the creature

The assignment (`/assignment.md`) asks for an autonomous, anthropomorphic,
"alive" lifeform that interacts with its surroundings and the player, with a
brain built from steering behaviors / FSM / Behavior Trees / LLM.

**The creature — *Noctiluca gemina*, "the Gemini".** A bioluminescent
deep-water organism that is actually two creatures, inspired by Subnautica
2's *Foureye*:

- **Pollux** — lower half, cool cyan glow, swims inverted. Role
  **Distractor**: in a hunt it weaves slowly in front of prey with a bright
  pulsing glow that holds the prey's attention, then emits a `strike_signal`
  when the prey is held (low speed / aligned long enough).
- **Castor** — upper half, warm amber glow, upright. Role **Striker**: peels
  wide via offset-pursue to a standoff position out of the prey's facing,
  waits for `strike_signal`, then darts in to capture.
- **Fused ("Pleo")** — the default calm state: the pair locks belly-to-belly
  and glides as one, glow blended to a slow teal heartbeat pulse.

The "alive" illusion is state-driven: curious figure-eight wandering with
eye tracking and a breathing chime; brightening and approaching a slow
player; dimming and retreating from a fast/bright one; the split-hunt
sequence; settling by a glow-coral to "sleep" when idle or low on energy.

## 2. Design pillars / locked decisions

- **3D on PC**, with all player interaction read through a `PlayerProbe`
  abstraction so a later XR (Quest) port needs no creature-code changes.
- **Brain = Steering + Behavior Tree.** A `Blackboard`/`Needs` model
  (hunger, energy, wariness) gates BT branches to produce autonomy. An LLM
  ("thought barks" via NobodyWho) is an *optional* final extra, isolated
  behind a `Mind` interface so the BT works fully without it.
- **Grade target 1, with a 2.1 fallback at every milestone** — each
  milestone ends in a runnable, demonstrable state.
- **Assets:** CSG for all milestones (the rubric explicitly allows
  "low poly and programmery"); an optional Blender mesh swap in M3.
- **Environment:** a small reef set-piece (CSG terrain, kelp, glow corals,
  ambient marine-snow particles).
- **Twins are asymmetric** in both look and role (see above).

## 3. Repository layout

```
/                         course-provided scaffold (READ-ONLY reference)
  assignment.md           the brief + marking scheme
  boid.gd, seek.tscn      steering demo (refactored into assignment/scripts)
  tpc.gd, path_*.gd, ...   reusable patterns
  CLAUDE.md               concise, auto-loaded Claude guidance
assignment/               ALL assignment work lives here
  scripts/                game logic (one class per file)
    steering_behaviors.gd
    steering_agent.gd
    bt/                    Behavior Tree core (from M2)
  scenes/                 .tscn scenes (from M1)
  materials/              shaders/materials (from M1)
  audio/                  sound assets (from M2)
  ARCHITECTURE.md         this document
  CLAUDE_NOTES.md         terse Claude nav map + status
```

The root scaffold and `assignment.md` are never modified. The only planned
edit outside `assignment/` is switching `project.godot` `run/main_scene` to
the reef scene in M1.

## 4. Class architecture (target ~8-9 cohesive classes)

Single Responsibility throughout; behaviors are pure and reusable; the agent
integrates; the controller decides; presentation is separate.

| Class | File | Responsibility |
|-------|------|----------------|
| `SteeringBehaviors` | `scripts/steering_behaviors.gd` | Pure force library + `WanderState` |
| `SteeringAgent` | `scripts/steering_agent.gd` | Kinematic integration, banking, gizmos |
| `TwoEye` | (M1) | One half: agent + visuals + glow + role |
| `GeminiController` | (M2) | Fuse/split state, role assignment, `strike_signal`, BT host |
| `BehaviorTree` + nodes | (M2) `scripts/bt/` | Selector/Sequence/Condition/Action |
| `Blackboard` / `Needs` | (M2) | hunger / energy / wariness + perception |
| `Prey` + `PreySpawner` | (M3) | Reactive forage fish (wander/flee/lured) |
| `PlayerProbe` | (M1) | XR-ready player position/velocity/light source |
| `CreatureAudio` + glow shader | (M1-M2) | State-driven sound and emission |
| `Mind` (interface) + NobodyWho | (M4, optional) | LLM thought barks |

**Behavior Tree priority (root selector):**
`Flee` (player threat) > `Hunt` (Split → assign roles → Pollux lure+signal /
Castor standoff+strike → Refuse) > `Investigate` (non-threatening player) >
`Wander` (default fused glide) > `Rest` (idle/low energy → glow-coral sleep).
A hunt aborts cleanly (prey escapes the lure radius, or a player scare)
back through Refuse to Flee/Wander.

## 5. Implemented so far — M0 (Foundation)

Branch `AA_Assignment` created; `assignment/` tree scaffolded; the
monolithic root `boid.gd` refactored into two SOLID pieces. The root
`boid.gd`/`seek.tscn` are left intact as a sandbox.

### `SteeringBehaviors` (`scripts/steering_behaviors.gd`)

`class_name SteeringBehaviors extends RefCounted`. A library of **pure
static** functions, each returning a steering force
`desired_velocity - current_velocity`. No node access, no `DebugDraw3D`,
no hidden state — trivially testable and reusable by every agent.

- `seek(from_pos, target_pos, velocity, max_speed)` — straight-line approach.
- `flee(from_pos, threat_pos, velocity, max_speed)` — inverse of seek.
- `arrive(from_pos, target_pos, velocity, max_speed, slowing_distance)` —
  seek that ramps speed down inside `slowing_distance` (from `boid.gd`).
- `pursue(from_pos, velocity, max_speed, target_pos, target_velocity)` —
  seeks the target's predicted future position (lead ∝ distance/max_speed).
- `offset_pursue(..., offset)` — pursue a point held at a world-space
  `offset` from the moving target (Castor's flanking approach).
- `standoff(..., target_forward, distance, slowing_distance)` — arrive at a
  point `distance` behind the target along `-target_forward` (Castor's hold
  position, out of the prey's facing).
- `dock(from_pos, partner_pos, ...)` — arrive onto a partner (the twins
  fusing); thin wrapper over `arrive`.
- `separation(from_pos, velocity, max_speed, neighbour_positions, radius)` —
  inverse-distance-weighted push away from nearby neighbours.
- `wander(state, forward, velocity, max_speed, delta)` — smooth random walk;
  mutates `state.angle`. The only stateful function; its state is the
  `WanderState` inner class (`angle`, `jitter`, `radius`, `distance`) so the
  randomness persists per-agent across frames without coupling to a node.

Convention: `from_pos`/`velocity`/`max_speed` describe the steering agent;
remaining params describe the target. Forces are summed and clamped by the
caller (`SteeringAgent`), not here.

### `SteeringAgent` (`scripts/steering_agent.gd`)

`class_name SteeringAgent extends CharacterBody3D`. The kinematic base for
**every** moving creature (Gemini halves and prey). It owns the integration
loop and debugging; it does *not* decide behavior.

- Exports: `mass`, `max_speed`, `max_force`, `slowing_distance`, `banking`,
  `draw_gizmos`.
- `forward()` → `-global_basis.z` (Godot's forward axis).
- `_compute_steering(delta) -> Vector3` — virtual hook returning
  `Vector3.ZERO`; **subclasses override it** to sum `SteeringBehaviors`
  calls. This replaces `boid.gd`'s boolean-flag soup
  (`seek_enabled`/`arrive_enabled`/...) with polymorphism (Open/Closed).
- `_physics_process(delta)` — clamps force to `max_force`,
  `accel = force/mass`, integrates velocity (clamped to `max_speed`) and
  position, and orients via `look_at(global_position - velocity, up)` with
  the banking lerp (preserving `boid.gd`'s feel). Draws velocity (blue) and
  force (red) `DebugDraw3D` arrows when `draw_gizmos` is on.

**Why the refactor:** `boid.gd` mixed behavior selection, the force library,
integration and rendering in one script with toggle flags — not extensible
to two role-differentiated creatures plus prey. The split gives a pure
testable force library, a reusable integrator, and a polymorphic extension
point for each creature type.

## 6. Milestone roadmap

- **M0 ✅ Foundation** — branch, `assignment/` tree, `SteeringBehaviors` +
  `SteeringAgent`, the three docs.
- **M1 — Fused creature + reef** (`feature/reef-and-body`, ~2.1 floor):
  `TwoEye`, fused Gemini CSG body, `PlayerProbe`, reef blockout (CSG
  terrain, kelp w/ sine-sway shader, glow corals), marine-snow particles,
  bioluminescent glow shader, wander/arrive/flee, gizmos. Switch
  `run/main_scene` to `assignment/scenes/reef.tscn`.
- **M2 — Brain** (`feature/behavior-tree`, ~2.1): `BehaviorTree` core +
  `Blackboard/Needs`, Investigate/Rest branches, procedural fin/tail sway +
  eye tracking + state-driven glow pulse, `CreatureAudio`.
- **M3 — Asymmetric hunt** (`feature/split-hunt`, grade 1): `Prey` +
  spawner, split mechanic, Pollux lure+signal / Castor standoff+strike →
  refuse, strike particles, abort handling, polish, optional Blender mesh,
  PC build + YouTube video, README template + reflection, ~30+ commits.
- **M4 — Optional extra** (`feature/llm-mind`): NobodyWho LLM behind a
  `Mind` interface for short thought barks.

## 7. Verification

No automated tests. Per milestone: open the active scene (root `seek.tscn`
through M0, `assignment/scenes/reef.tscn` from M1) in the Godot 4.6 editor
and watch the `DebugDraw3D` gizmos. M3 end-to-end check: flees a fast/bright
player; investigates a slow one; splits when prey is within detection radius
and hunger is high enough; Pollux holds prey and emits `strike_signal`;
Castor strikes only on the signal; the pair refuses; rests at a glow-coral
when energy is low; hunt aborts cleanly when prey escapes. Finally export
and test the **PC build** (not just the editor) before recording the video.
