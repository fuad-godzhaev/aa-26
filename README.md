# Gemini — *Noctiluca gemina*

> An autonomous, twin-bodied bioluminescent reef predator for the TU Dublin
> **Autonomous Agents 2026** assignment. A creature with a mind of its own:
> it hunts, lures, gets curious, gets spooked, tires out, and goes home to rest —
> all driven by its own needs, with no scripted sequences.

**Author:** Fuad Godzhaev D20124630· **Module:** Autonomous Agents 2026 (Bryan Duggan) · **Engine:** Godot 4.6.2 (Forward+, GDScript)

---

## 1. Demo video


[![Gemini gameplay](https://img.youtube.com/vi/yA_7xuaNlWg/hqdefault.jpg)](https://youtu.be/yA_7xuaNlWg)

https://youtu.be/yA_7xuaNlWg


---

## 2. Overview

**Gemini** is a first-person underwater "creature observatory." You are a diver in a
small bright-shallows reef; the star is **Gemini**, an artificial lifeform that behaves
autonomously. The brief asks for *"a virtual creature with a mind of its own that can
autonomously achieve tasks and goals based on its needs"* and to *"manipulate the user
into believing the lifeform is alive."* Gemini does this through a layered AI brain —
**steering behaviours + a needs-driven Blackboard + a Behaviour Tree + a split/fuse hunt
state machine** — wrapped in a stylised, glowing presentation so its bioluminescence
reads as the one living, intentional thing in the scene.

It runs on **PC (Forward+ desktop)** from the Godot editor.

---

## 3. The creature — identity & personality

Gemini (*Noctiluca gemina*, "the twin nightlight") is **two creatures that act as one**,
inspired by the Subnautica 2 "Foureye" but an original design:

| Half | Glow | Role | Behaviour |
|------|------|------|-----------|
| **Castor** | warm amber | **Striker** | Arcs out of sight to a hide spot, waits for the signal, then bursts in to capture. |
| **Pollux** | cool cyan | **Distractor** | Weaves in front of prey with a mesmerising display; when the prey is held, sends Castor the strike signal. |
| **"Pleo" (fused)** | slow teal pulse | default | Both halves lock belly-to-belly and glide as one, with a heartbeat-like pulse. |

Its **personality** comes from its drives, not a script:

- **Calm / curious** — by default it wanders the reef; it brightens and drifts toward a
  *slow, gentle* diver out of curiosity.
- **Wary** — it dims and retreats from a *fast or crowding* diver.
- **Predatory** — when hungry and prey is near, the halves split and run a coordinated
  lure-and-ambush hunt.
- **Tired** — as energy drops it disengages and returns to a "home" rock to dock, re-fuse
  and rest, then resumes once rested.

Emission is the creature's signature: **only Gemini (and the ground caustics) glow**, so
even in a colourful reef the eye reads it first as the living thing.

---

## 4. How to run & controls

### Requirements
- **Godot 4.6.2-stable** (Forward+). No C# — pure GDScript.
- The repo's `addons/` (Terrain3D, Debug Draw 3D, etc.) ship with the project; enable them if Godot prompts.

### Run
Click on Gemini.exe in the build folder located on this google drive: https://drive.google.com/drive/folders/1-q98r88wNVFm8gHYboXMGfV6NR7vw2GN?usp=drive_link. 
Start Game to get into the scene. 
Or open the Godot project and press F5.

### Controls (diver)
| Input | Action |
|-------|--------|
| **W / S** | Swim forward / back (relative to look) |
| **A / D** | Strafe left / right |
| **E / Q** | Ascend / descend |
| **Mouse** | Look |
| **Shift** | Boost (sprint) |
| **Esc** | Pause / resume (opens the menu) |

### Menu & settings
The same menu serves the boot screen and the in-game pause (a blurred freeze-frame).
Settings: **Field of View**, **Master Volume**, **Underwater Distortion**, **Look
Sensitivity**, plus **Reset to Defaults**. Values persist to `user://settings.cfg`.

---

## 5. Features

**Autonomy & interactivity**
- A self-written **steering library** (seek, flee, arrive, 3D wander) + the **Boids triad** (separation / alignment / cohesion) for fish schools.
- A **needs model** (hunger / energy / wariness) that perceives the player and prey and sets the creature's mood.
- A **Behaviour Tree** that arbitrates between *flee → hunt → rest → investigate → wander*.
- A **split/fuse hunt FSM** (`ENCIRCLE → LURE → STRIKE / CHASE → REFUSE`) where the two halves coordinate.
- A first-person **embodied diver** with procedural breaststroke hands, breathing, and a goggle mask — the diver is itself an interactive autonomous-ish rig.

**Visuals & sound**
- Custom **soft-toon** shaders for sand, rock, kelp/coral, props, metal and fish; an animated **caustic** light web; emissive **bioluminescence** on Gemini.
- A three-layer **underwater look**: a toon water-surface ceiling, distance fog, and a fullscreen post-process (refraction wobble + blue shift + vignette that deepens with depth).
- **Glow/bloom** tuned so only the creature and caustics bloom.
- **Particle** capture-burst effect; **GPU bubble** exhale on the diver's breath.
- A boot/pause **menu** with a live blur shader; SFX on a low-pass "underwater" master bus.
- **Forward+ desktop rendering** with volumetric god-rays and a caustic light projector.

---

## 6. How it works — the autonomous brain

The AI is deliberately split into **small, single-responsibility classes** (a nod to the
course's SOLID material) so the decision logic, the motion, and the per-half commands stay
separate and testable. The brain = **Steering + Blackboard/Needs + Behaviour Tree + a hunt
FSM**.

### 6.1 Steering (the motion layer)
`SteeringBehaviors` is a pure, static **force library** (Craig Reynolds' model): `seek`,
`flee`, `arrive`, a 3D `wander`, plus the **Boids** triad. `SteeringAgent` is a kinematic
integrator base class (applies forces, caps speed, banks into turns, draws debug gizmos)
that both the Gemini halves and the prey subclass. This keeps *how a thing moves* separate
from *what it decides to do*.

### 6.2 Needs & perception (the Blackboard)
`Blackboard` is a shared scratchpad holding the drives **hunger / energy / wariness**, a
perception snapshot (player position/speed/distance, nearest prey, threat), the current
`mode` string, and small hysteresis helpers like `wants_rest()` so the creature doesn't
flip-flop between states.

### 6.3 Arbitration (the Behaviour Tree)
`BehaviorTree` is a tiny generic framework — `Selector`, `Sequence`, `Condition`,
`Action`. Gemini's tree is a top-level **Selector** trying, in priority order:

```
flee        (wariness high)        → run from the diver
hunt        (hungry + prey + calm) → enter the split-hunt FSM
rest        (low energy + safe)    → return home to dock/re-fuse
investigate (calm, slow player near)→ curious approach
wander                              → idle figure-eight cruise
```

### 6.4 The split/fuse hunt (the FSM)
When the tree picks `hunt`, `GeminiController` drives a state machine over the two halves:

```
NONE (fused)
   │  hungry + prey in range
   ▼
ENCIRCLE ── Castor arcs out of the prey's view to a hide spot
   │  hidden & in position
   ▼
LURE ────── Pollux displays in front; prey is mesmerised & held
   │  held long enough          │ prey bolts / spots Castor
   ▼                            ▼
STRIKE ─── Castor bursts in    CHASE ─── stamina-limited run-down,
   │  capture                  │         Pollux herds it back
   ▼                            ▼
REFUSE ◄──────────── capture / abort / lose distance
   │  halves re-dock belly-to-belly
   ▼
NONE
```

Each half (`TwoEye`) is intentionally "dumb": it just follows a `cmd_mode`/`cmd_target`
the controller sets each frame, so all the intelligence lives in one place.

### 6.5 The "alive" illusion
Per the brief ("make the user believe it's alive"): eye tracking toward the player/target
(`EyeTracker`), a breathing-rate audio pulse and mood-driven calls (`CreatureAudio`),
glow brightness/rate that rises with wariness and flashes on a successful capture, and a
figure-eight idle wander so it's never perfectly still.

### 6.6 The diver (player rig)
`PlayerFly` is an embodied first-person diver: WASD/QE + mouse + Shift, with accel/drag and
`move_and_slide` so it bumps off geometry; it owns a stroke clock that drives **procedural
breaststroke hands** (`DiverHands`), **breathing** with an exhale bubble burst
(`DiverBreathing`), and a **goggle mask** vignette (`DiverGoggles`). `PlayerProbe`
abstracts "where is the player and how is it moving" so the creature code depends only on the player's sensed
position and speed, not on the concrete diver rig.

### 6.7 Class map
| Class | File | Responsibility |
|-------|------|----------------|
| `SteeringBehaviors` | `scripts/steering_behaviors.gd` | Static force library + Boids triad |
| `SteeringAgent` | `scripts/steering_agent.gd` | Kinematic integration, banking, gizmos |
| `Blackboard` | `scripts/blackboard.gd` | Needs (hunger/energy/wariness) + perception + mode |
| `BehaviorTree` | `scripts/bt/behavior_tree.gd` | Selector / Sequence / Condition / Action |
| `GeminiController` | `scripts/gemini/gemini_controller.gd` | Fuse/split, hunt FSM, BT host |
| `TwoEye` | `scripts/gemini/two_eye.gd` | One command-driven half (role + glow) |
| `EyeTracker`, `CreatureAudio` | `scripts/gemini/` | Eye aim + mood-driven sound |
| `Prey`, `PreySpawner` | `scripts/prey/` | Forage fish (steering + lure susceptibility + flee) |
| `PlayerFly`, `PlayerProbe` | `scripts/diver/` | Embodied diver + player-rig abstraction seam |
| `DiverHands`, `DiverBreathing`, `DiverGoggles` | `scripts/diver/` | Procedural animation + FX |
| `KelpForest`, `FishSchool`, `SurfaceTransition`, `CloudTracker` | `scripts/world/` | Environment generators / triggers |
| `Ocean` (autoload) | `scripts/ocean.gd` | Developer source-of-truth: world constants + shader globals |
| `Settings` (autoload) | `scripts/settings.gd` | Player options, persisted to `user://settings.cfg` |

---

## 7. Visuals & sound (Groovyness)

- **Shared style.** Every opaque surface runs through a soft-toon, matte treatment and a
  single shared **depth-tint** so the whole scene cools together with depth. The tint band
  and palette live in **one place** (`Ocean`) and are pushed to all shaders as global
  uniforms via `ocean_globals.gdshaderinc`, so there are no per-material copies to drift.
- **Custom shaders** (`assignment/assets/shaders/`): `sand_caustics` (world-projected sand
  + a `TIME`-animated Worley caustic web), `rock_arch` (triplanar, no UVs, algae on
  upward faces), `organic_sway` (kelp/coral sway with `BACKLIGHT` translucency),
  `stylized_prop` / `stylized_metal` / `stylized_fish`, `glow` (Gemini's emission), and a
  `water_surface` toon shader.
- **The underwater feel is three layers**, not one: (1) a subdivided water-surface plane
  ceiling, (2) `WorldEnvironment` fog for distance murk, (3) a fullscreen `ColorRect`
  post-process (`underwater_canvas` + `underwater_effect.gd`) that wobbles, blue-shifts and
  vignettes the screen, deepening as you descend.
- **Sound:** mood-driven creature calls + breathing, a master-bus low-pass that engages
  underwater, and ambient/transition cues.

---

## 8. Project structure

```
assignment/
  scenes/        boot.tscn (main) → reef.tscn
  scripts/
    steering_behaviors.gd  steering_agent.gd  blackboard.gd  bt/behavior_tree.gd
    diver/   gemini/   prey/   world/
    ocean.gd   settings.gd   pause_menu.gd
  assets/
    shaders/   textures/   audio/   materials/
  models/        sourced + procedural meshes (polyhaven / sketchfab / itch / blender)
  models_baked/  baked creature + prey + fish scenes
addons/          Terrain3D, Debug Draw 3D, Sky3D, CSG tools, git plugin, …
aa_course_material/  the brief + lecture notes (reference)
```

A `MANIFEST.txt` records how each generated asset was produced; `DESIGN_DOC.md` the visual/asset bible.

---

## 9. Development & project management

- **Branches:** `AA_Assignment` (the main milestone line) and `feature/visual-core` (the
  environment/visual work), with feature branches merged in per milestone.
- **Milestones:** M0 framework → M1 steering → M2 single-body creature → M3 split/fuse hunt
  brain → M4 diver embodiment → M5 reef/visual polish. (M6 optional LLM dialogue, day/night
  cycle, and an HFSM migration are stretch goals.)
- **Validation:** scripts are checked headless before commit
  (`Godot … --headless --check-only --script …`) and smoke-run with `--quit-after`.

---

## 10. Known issues & future work

Honest current limitations (it runs on PC in/near the 2.1 "some glitches" band):

- **Creature altitude:** the controller's centre-clamp still uses the project's earlier
  coordinate space, so Gemini can sit too high in the water column until its clamp is
  re-pointed at the `Ocean` constants. (Same for the kelp ring's base height.)
- **Missing meshes:** several background-fish `.blend/.glb` files and one prop's textures
  aren't imported yet, so those agents are placeholders.
- **Depth-tint band** can over-cool the shallows at the deepest point; the band is a single
  tunable in `ocean.gd`.
- The boot/pause **menu transitions** are verified at the boot screen; the in-game blur and
  slider round-trip want a final play-through check.

**Future work:** finish the asset set and biome seeding so the creature visibly walks its
hunt → tunnel → kelp → den tour; an optional **LLM** dialogue layer; and a **day/night** cycle.

---

## 11. References & credits


**Techniques & course material**
- Craig W. Reynolds — *Steering Behaviors for Autonomous Characters* (1999): <https://www.red3d.com/cwr/steer/> — basis for seek/flee/arrive/wander.
- Craig W. Reynolds — *Boids* (1987): <https://www.red3d.com/cwr/boids/> — separation/alignment/cohesion for the fish schools.
- Bryan Duggan (skooter500) — Autonomous Agents 2026 course material and starter repos (`miniature-rotary-phone`, `hands`).
- Behaviour Trees — standard game-AI pattern (Selector/Sequence/Condition/Action).

**Engine & addons** (bundled under `addons/`; see each addon's `README`/`LICENSE`):
- **Godot Engine 4.6.2** (MIT).
- **Terrain3D** — TokisanGames (MIT).
- **Debug Draw 3D** — Dmitriy Salnikov (MIT).
- **Sky3D**, **CSG Terrain**, **CSG Toolkit**, **GDT Terrain**, **TerraBrush**, **godot-git-plugin** — third-party Godot addons; authors/licences in `addons/<name>/`.

**Shaders & assets**
- *Stylized Toon Water* by **Thundergecko8**, godotshaders.com (MIT) — adapted for the water surface (alpha blend instead of additive, palette-mapped bands, added `water_alpha`).
- **Poly Haven** (CC0) — rock/boulder textures & meshes.
- **Quaternius** (CC0) — stylized fish.
- **Sketchfab** — `cannon_01`, `creepvine`, kelp models (licence per asset page; see `MANIFEST.txt`).
- **itch.io** — fish pack, sand texture.
- **EMODnet Bathymetry** — optional real-bathymetry path for the seabed heightmap.

**Inspiration**
- *Subnautica* / *Subnautica 2* (Unknown Worlds Entertainment) — Gemini is an **original** design inspired by the "Foureye".

**Tools & assistance**
- Godot 4.6.2, Blender, Terrain3D Addon for Godot, and the project's own procedural Python generators (terrain, meshes, textures — see `MANIFEST.txt`).
- *AI assistance:* — see the full disclosure in §14.

---

## 12. What I learned (reflection)

- **It's all shaders?** Starting this project, I was foolishly thinking that water is a mesh 
	covering the entire playable area, or at least the player's camera. And it took me a while 
	to realize: "Wait, it's all just fog and some fancy shaders?". So here's a meme that perfectly
	represents that moment of truth: ![Alt text](https://imgflip.com/i/at91ln)

- **Separate the layers or the AI becomes unmanageable.** Splitting *how it moves*
  (steering), *what it wants* (needs/Blackboard), *what it decides* (Behaviour Tree) and
  *how the hunt sequences* (FSM) meant each piece could be reasoned about and debugged on
  its own. Collapsing them into one script earlier had made the behaviour impossible to
  tune.
- **A convincing "alive" feeling is cheaper than realistic AI.** Eye tracking, a breathing
  pulse, glow that responds to mood, and never being perfectly still did more for the
  illusion of life than any single clever algorithm.
- **One source of truth prevents whole categories of bugs.** A surface-height value living
  in two files drifted out of sync and broke the water/fog; moving shared world constants
  into one `Ocean` autoload (read by both GDScript *and* shaders via global uniforms) made
  that class of bug impossible to recreate.
- **Engine-specific gotchas cost real time** — e.g. GDScript won't compile member access on
  a statically-typed `Node` autoload reference, and the editor's script validator
  false-positives on `class_name` files; learning to validate headless instead saved a lot
  of guessing.
- **Decouple the player from the AI.** Abstracting the player behind `PlayerProbe` meant
  the creature depends only on *where the player is and how fast it's moving*, not on the
  concrete diver rig — so the player rig can change without touching the brain.

---

## 13. AI usage disclosure

This project was built with help from an AI assistant (Anthropic's Claude),
used as a pair-programmer, reviewer and tutor throughout development. I've laid out the foundation,
directed the work, made the design decisions, and integrated, tested and debugged everything in the
submission. Specifically, AI was used for:

- **Design & Brainstorming** — developing the creature concept and identity, and shaping the AI behaviour/
- **Gameplay & AI code** —  reviewing and refactoring the GDScript, diagnosing and fixing compile and runtime warnings/errors/bugs, adding extra features based on detailed and interactive prompts.
- **Tooling & assets** — writing the procedural Python generators (meshes, textures) used in some of the assets for quick prototyping and background stuff.
- **Documentation** — writing comments, Github commit summaries, and helping finalize this README based on my notes.

I have worked to understand the techniques used (steering behaviours, Boids, Behaviour
Trees, finite-state machines, and the shader maths), and I believe I've achieved my goal.
