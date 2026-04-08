# Sound design — placeholders to replace

`creature_audio.gd` plays one looping 3D voice that follows the Behaviour
Tree mode. The files below are **silent valid-WAV placeholders** so the
audio pipeline works now; swap each for a real sample (same filename, any
WAV/OGG) with no code change. Loop is forced in code.

| File | BT mode | What it should convey |
|------|---------|-----------------------|
| `PLACEHOLDER_breathing.wav` | `wander` | calm idle "breathing"/soft bioluminescent hum |
| `PLACEHOLDER_curious.wav`   | `investigate` | inquisitive chirps/clicks toward the player |
| `PLACEHOLDER_wary.wav`      | `flee` | low alarmed hum / fast pulse |
| `PLACEHOLDER_rest.wav`      | `rest` | very slow, sleepy low drone |

When replacing, prefer CC0 / CC-BY sources (e.g. freesound.org) and record
the source + licence here and in the project README — the marking scheme
explicitly rewards referenced sources.

| File | Real source (fill in) | Licence |
|------|-----------------------|---------|
| breathing | _TBD_ | _TBD_ |
| curious | _TBD_ | _TBD_ |
| wary | _TBD_ | _TBD_ |
| rest | _TBD_ | _TBD_ |
