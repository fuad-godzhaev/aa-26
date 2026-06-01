# Asset sources & licences — Noctiluca gemina (aa26)

All third-party assets are CC0 / royalty-free with no attribution required; credits
are listed anyway. Original work (the creature, shaders, generator scripts, scene)
is the author's.

## Audio (`assignment/audio/`)
| File | Source | Licence |
|---|---|---|
| `gemini_voice.ogg` | Wikimedia Commons — *Humpbackwhale2.ogg* (creature voice; played 3D, pitch-shifted per FSM mode) | CC0 1.0 |
| `ui_click.wav`, `ui_hover.wav` | Kenney *UI Audio* (`click1`, `rollover1`), via github.com/Calinou/kenney-ui-audio | CC0 1.0 |
| `amb_underwater.wav` | Procedurally synthesised (Python) — looping underwater rumble bed | Original / CC0 |
| `breath_in.wav`, `breath_out.wav` | Procedurally synthesised — regulator inhale/exhale + bubbles | Original / CC0 |
| `splash.wav` | Procedurally synthesised — surface-crossing splash | Original / CC0 |

Note: the lure-hum / strike-whoosh slots are covered by pitch-shifting the creature
voice per hunt state rather than dedicated samples (see `creature_audio.gd`).

## Creature
- `assignment/models/castor.glb`, `pollux.glb` — original model (Blender), the fused
  Castor/Pollux twin; an original interpretation inspired by Subnautica's "Foureye".
  Static meshes; animated procedurally by steering + `two_eye.gd`.

## 3D models & textures (CC0)
- Poly Haven (polyhaven.com) — `cannon` textures, `rock_pitted_mossy` (rock arches).
- Sketchfab CC0 — `creepvine`/kelp source (kelp textures in `assets/textures/kelp/`).
- Itch.io CC0 low-poly fish pack — `PolyPackFish` atlas (fish1-4, shark), background
  fish species glbs (clownfish, blue/yellow tang, angelfish, parrotfish, butterflyfish).
- `GroundSand005` — CC0 seabed PBR texture set (repacked for Terrain3D).

## Engine addons
- Terrain3D (TokisanGames), debug_draw_3d, sky_3d, TerraBrush, Godot MCP Pro — per
  their own licences in `addons/`.

## Visual reference
- Subnautica series (visual inspiration only; the creature is an original design).
