# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Godot **4.6** project — the scaffold for the **Autonomous Agents 2026**
assignment (`assignment.md`). Deliverable: an autonomous, "alive" creature.
The root `.gd`/`.tscn` files are starter steering-demo code from
`skooter500/miniature-rotary-phone` and are kept as an untouched reference
sandbox. **All assignment work lives under `assignment/`.**

The creature: *Noctiluca gemina* "the Gemini" — a bioluminescent underwater
twin that glides as one fused organism and splits into an asymmetric
predator pair (Pollux lures + signals, Castor strikes) to hunt, then refuses.

## Conventions (must follow)

- Work on branch **`AA_Assignment`**; milestone work on `feature/*` branches
  that branch from and merge back into it.
- Everything we create goes under **`assignment/`**
  (`scripts/`, `scripts/bt/`, `scenes/`, `materials/`, `audio/`).
- Do **not** modify the root scaffold (`boid.gd`, `seek.tscn`, `tpc.gd`,
  `path_*.gd`, `target.gd`, ...) or `assignment.md`/`life.jpg`. Read them for
  reference and reuse patterns only.
- **Single-line comments only** in code. All detailed prose goes in
  `assignment/ARCHITECTURE.md`, updated in the same commit as the code.
- Keep `DebugDraw3D` gizmos on every steering vector / perception radius /
  BT state — the rubric explicitly rewards this.

## Engine / running

- Godot **4.6**, Mobile renderer, Jolt physics, GDScript only.
- Caveat: `.vscode/settings.json` points Godot Tools at a 4.4.1 mono build;
  use a real 4.6 editor. Do not edit `project.godot`/`.vscode` except the
  planned `run/main_scene` switch in M1.
- Run: open in the Godot 4.6 editor, F5. Sandbox scene = root `seek.tscn`;
  the assignment scene (from M1) = `assignment/scenes/reef.tscn`. No tests —
  verify by running and watching gizmos.

## Where to look

- **Plan / milestones / fallback ladder:**
  `C:\Users\wirex\.claude\plans\familiarize-yourself-with-the-jiggly-cook.md`
- **Fast nav map + current status:** `assignment/CLAUDE_NOTES.md`
- **Detailed architecture (every class/script/scene):**
  `assignment/ARCHITECTURE.md`
- **The brief & marking scheme:** `assignment.md`

## Architecture (target ~8-9 SOLID classes)

`SteeringAgent` (base: integration + gizmos) + `SteeringBehaviors` (pure
force library) → `TwoEye` (one half) → `GeminiController` (fuse/split, role
signal, BT host) driven by a lean `BehaviorTree` + `Blackboard/Needs`,
reacting to `PlayerProbe` (XR-ready), hunting `Prey`. Presentation: glow
shader, particles, `CreatureAudio`. LLM (`Mind` interface, NobodyWho) is an
optional final extra. See `assignment/ARCHITECTURE.md` for details.
