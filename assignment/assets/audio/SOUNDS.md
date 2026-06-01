# Sound design — placeholders to replace

`creature_audio.gd` plays one looping 3D voice that follows the Behaviour
Tree mode. The files below are **silent valid-WAV placeholders** so the
audio pipeline works now; swap each for a real sample (same filename, any
WAV/OGG) with no code change. Loop is forced in code.

| File | BT mode | What it should convey |
|------|---------|-----------------------|
| `PLACEHOLDER_breathing.wav` | creature `wander` | calm idle "breathing"/soft bioluminescent hum |
| `PLACEHOLDER_curious.wav`   | creature `investigate` | inquisitive chirps/clicks toward the player |
| `PLACEHOLDER_wary.wav`      | creature `flee` | low alarmed hum / fast pulse |
| `PLACEHOLDER_rest.wav`      | creature `rest` | very slow, sleepy low drone |
| `PLACEHOLDER_breath_in.wav` (M4) | diver inhale beat | regulator inhale; volume scales with exertion |
| `PLACEHOLDER_breath_out.wav` (M4) | diver exhale beat | regulator exhale (bubbles emit on this beat) |
| `PLACEHOLDER_splash.wav` (M5) | surface-crossing event | one-shot water splash, fires both up and down |
| `PLACEHOLDER_ambient.wav` (M5) | global ambient bed | looped underwater rumble / distant whales |

When replacing, prefer CC0 / CC-BY sources (e.g. freesound.org) and record
the source + licence here and in the project README — the marking scheme
explicitly rewards referenced sources.

| File | Real source (fill in) | Licence |
|------|-----------------------|---------|
| breathing | _TBD_ | _TBD_ |
| curious | _TBD_ | _TBD_ |
| wary | _TBD_ | _TBD_ |
| rest | _TBD_ | _TBD_ |
| breath_in | _TBD_ | _TBD_ |
| breath_out | _TBD_ | _TBD_ |
| splash | _TBD_ | _TBD_ |
| ambient | _TBD_ | _TBD_ |
