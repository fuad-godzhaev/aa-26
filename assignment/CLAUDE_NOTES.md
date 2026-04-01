# CLAUDE_NOTES.md — fast nav map (concise, for Claude)

Working notes for navigating/editing this assignment. Keep terse. Update the
**Status** line and **File map** whenever structure changes.

## Status

- Branch: `AA_Assignment`. Current milestone: **M0 complete** (foundation).
- Next: **M1** on `feature/reef-and-body` — fused Gemini body + reef scene +
  glow shader + flee/wander/arrive. Switch `project.godot` `run/main_scene`
  to `res://assignment/scenes/reef.tscn` when M1 lands.

## File map (assignment/)

- `scripts/steering_behaviors.gd` — `class_name SteeringBehaviors`
  (`extends RefCounted`). Pure static force functions: seek, flee, arrive,
  pursue, offset_pursue, standoff, dock, separation, wander. Inner class
  `WanderState` holds per-agent wander memory. No side effects, no gizmos.
- `scripts/steering_agent.gd` — `class_name SteeringAgent`
  (`extends CharacterBody3D`). Force→accel→velocity integration, banked
  `look_at`, velocity/force gizmos. Subclasses override
  `_compute_steering(delta) -> Vector3`. `forward()` = `-global_basis.z`.
- `scripts/bt/` — (empty) Behavior Tree core lands in M2.
- `scenes/`, `materials/`, `audio/` — (empty) populated from M1.

## Reuse from root scaffold (read-only reference)

- `boid.gd` — original integration + gizmo pattern (already refactored into
  the two scripts above; convention: `look_at(pos - velocity, up)`).
- `path_drawer.gd` — `DebugDraw3D.draw_line` loop pattern.
- `tpc.gd` — chase camera (`lerp` to a `cam_target` Marker3D).
- `target.gd` — timer-driven random relocate (basis for prey wander/spawn).

## Editing rules

- New code → `assignment/...` only. Never touch root scaffold or
  `assignment.md`.
- Single-line comments only; explain in `ARCHITECTURE.md` same commit.
- Each milestone: feature branch off `AA_Assignment`, meaningful commits,
  merge back. Target ~30+ commits total (project-management is graded).
- Keep a runnable build at every milestone (2.1 floor). Verify in the Godot
  4.6 editor with gizmos on.

## Key decisions (don't relitigate)

- 3D PC, player interaction abstracted via `PlayerProbe` for later XR.
- Brain = Steering + Behavior Tree; LLM only via `Mind` interface in M4.
- Assets: CSG for all milestones; optional Blender mesh swap in M3.
- Twins asymmetric: Pollux = distractor/lure + emits `strike_signal`;
  Castor = striker, waits for signal then darts in.
