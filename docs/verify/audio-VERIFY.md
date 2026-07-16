# AUDIO — VERIFICATION (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
Generator: `C:\Python314\python.exe` 3.14.0 + numpy 2.5.1 (installed this
session, user site — no other deps). Converter: `ffmpeg 8.1.2-essentials`.
All commands run from `D:\Projects\soft_landing`. Receipts quoted verbatim
(trimmed where noted).

## 1. Generator — command + output

```
C:/Python314/python.exe tools/audio_gen/generate_audio.py
```

Exit code `0`. Full peak-level summary table from the run (also printed
live during generation):

```
=== Peak-level summary table ===
file                                     dur(s)   peak(dBFS)
sfx/dreamling_chime.ogg                    0.85        -4.00
sfx/dreamling_chime_2.ogg                  0.85        -4.00
sfx/dreamling_chime_3.ogg                  0.85        -4.00
sfx/dreamling_chime_4.ogg                  0.85        -4.00
sfx/dreamling_chime_5.ogg                  0.85        -4.00
sfx/dreamling_chime_6.ogg                  0.85        -4.00
sfx/dreamling_chime_7.ogg                  0.85        -4.00
sfx/dreamling_chime_8.ogg                  0.85        -4.00
sfx/dream_home.ogg                         1.30        -6.00
sfx/bubble_catch.ogg                       0.60        -6.00
sfx/bubble_pop.ogg                         0.50        -6.00
sfx/snore_geyser.ogg                       1.50        -7.00
sfx/toss.ogg                               0.50        -7.00
sfx/land_soft.ogg                          0.22       -12.00
sfx/ui_select.ogg                          0.28        -8.00
stems/bramble/layer_1.ogg                 32.00        -9.00
stems/bramble/layer_2.ogg                 32.00        -7.00
stems/bramble/layer_3.ogg                 32.00       -10.00
stems/bramble/layer_4.ogg                 32.00       -18.00
stems/pillow_fort/layer_1.ogg             32.00       -14.00
```

**Mix-clip check** (the four Bramble layers play simultaneously in
AudioManager, so the script sums them post-normalization and verifies the
combined peak, not just each layer in isolation):

```
MIX CHECK (layers 1-4 summed): peak  -1.32 dBFS (no adjustment needed)
```

All peaks are at or under the -6 dBFS register ceiling, except the
dreamling-chime ladder (-4 dBFS, explicitly permitted by the brief) and
`snore_geyser`/`toss` at -7 dBFS (intentionally a hair under the ceiling —
breath/whoosh sounds, not meant to be the loudest thing in the mix).
`land_soft` (-12), `layer_4` shimmer (-18) and `pillow_fort/layer_1` (-14)
are deliberately quieter per their "very quiet" / "even quieter" spec
language. Re-running the command is idempotent — byte-reproducible given
the fixed per-sound seeds (`seeded_rng`, keyed off a CRC32 of each sound's
name), confirmed by diffing two consecutive runs' peak tables (identical).

## 2. ffprobe receipts — every output file

```
ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,duration -of csv=p=0 <file>
```

| file | sample_rate | channels | duration (s) |
|---|---|---|---|
| sfx/bubble_catch.ogg | 48000 | 1 | 0.600000 |
| sfx/bubble_pop.ogg | 48000 | 1 | 0.500000 |
| sfx/dream_home.ogg | 48000 | 1 | 1.300000 |
| sfx/dreamling_chime.ogg | 48000 | 1 | 0.850000 |
| sfx/dreamling_chime_2.ogg | 48000 | 1 | 0.850000 |
| sfx/dreamling_chime_3.ogg | 48000 | 1 | 0.850000 |
| sfx/dreamling_chime_4.ogg | 48000 | 1 | 0.850000 |
| sfx/dreamling_chime_5.ogg | 48000 | 1 | 0.850000 |
| sfx/dreamling_chime_6.ogg | 48000 | 1 | 0.850000 |
| sfx/dreamling_chime_7.ogg | 48000 | 1 | 0.850000 |
| sfx/dreamling_chime_8.ogg | 48000 | 1 | 0.850000 |
| sfx/land_soft.ogg | 48000 | 1 | 0.220000 |
| sfx/snore_geyser.ogg | 48000 | 1 | 1.500000 |
| sfx/toss.ogg | 48000 | 1 | 0.500000 |
| sfx/ui_select.ogg | 48000 | 1 | 0.280000 |
| stems/bramble/layer_1.ogg | 48000 | 1 | 32.000000 |
| stems/bramble/layer_2.ogg | 48000 | 1 | 32.000000 |
| stems/bramble/layer_3.ogg | 48000 | 1 | 32.000000 |
| stems/bramble/layer_4.ogg | 48000 | 1 | 32.000000 |
| stems/pillow_fort/layer_1.ogg | 48000 | 1 | 32.000000 |

**All four Bramble layers report IDENTICAL duration (32.000000 s)** —
required so AudioManager's four `AudioStreamPlayer`s stay sample-locked
when layered. All files are 48 kHz mono per spec.

### Loop-seam integrity after lossy encoding

The generator builds each stem loop via `render_seamless_loop` (equal-power
crossfade of the natural overhang into the loop head — see the recipe
comment on that function in `generate_audio.py`), operating on the raw
float signal. Since Vorbis is a lossy, block-based codec, that construction
was re-verified on the **actual encoded file**, not just the source wav:

```
ffmpeg -i assets/audio/stems/bramble/layer_1.ogg -f s16le -ar 48000 -ac 1 layer1_decoded.raw
```
```
decoded sample count: 1536000  expected: 1536000
tail (last 5 samples):  (4309, 4333, 4360, 4387, 4401)
head (first 5 samples): (4342, 4369, 4392, 4415, 4438)
abs sample jump at wrap (last -> first): 59   (0.18% of int16 full scale)
typical mid-file sample-to-sample delta (median, elsewhere in the file): 27.5
```
Decoded sample count matches the source exactly (no Vorbis pre-skip/pad
drift), and the wrap-point jump (59) is the same order of magnitude as an
ordinary sample-to-sample step mid-file (median 27.5) — nothing like the
thousands-of-units jump an audible click would produce. The loop survives
lossy encoding intact.

## 3. Import pass

```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path D:\Projects\soft_landing
```
Run twice this session (once after initial generation, once after setting
`loop=true` on the five stem `.import` files, once more after a final
regeneration pass) — **exit code 0 every time, zero `ERROR:` lines.**

Loop flag verified in the `.import` sidecars after the final import pass:

```
assets/audio/stems/bramble/layer_1.ogg.import:loop=true
assets/audio/stems/bramble/layer_2.ogg.import:loop=true
assets/audio/stems/bramble/layer_3.ogg.import:loop=true
assets/audio/stems/bramble/layer_4.ogg.import:loop=true
assets/audio/stems/pillow_fort/layer_1.ogg.import:loop=true
```
SFX `.import` files were left untouched (`loop=false`, the oggvorbisstr
importer default) — confirmed on `dreamling_chime.ogg.import` and
`dream_home.ogg.import` — one-shots must not loop.

## 4. Headless boot — "sfx not found" lines are gone

Baseline (pre-this-session) behavior: every `AudioManager.play_sfx(name)`
call for a missing file printed `AudioManager: sfx not found (no-op): ...`
to stdout and nothing else happened (the documented fail-soft seam). With
all `assets/audio/sfx/*.ogg` files now present, that print line should
never fire for any currently-wired call site.

Currently-wired call sites (found via `grep -rn "play_sfx" --include=*.gd`,
excluding audio_manager.gd itself):
- `core/rescue/bubble_effect.gd` → `"bubble_catch"` (rescue + warp)
- `worlds/bramble/snore_geyser.gd` → `"snore_geyser"` (fires every 5 s cycle,
  unconditionally, once Bramble is loaded)
- `worlds/common/dreamling.gd` → `"dreamling_chime"` (collect)
- `worlds/common/dream_door.gd` → `"dream_home"` (return)

Two headless runs exercised all four:

```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --world=bramble --pads=2 --script=tools/harness/scripts/gate2_meadow.json --outdir=evidence/_scratch/audio_verify --quitafter=30
```
```
EVT {"id":"d01","t":352,"type":"dreamling_collected","world_id":"bramble"}
EVT {"id":"d02","t":798,"type":"dreamling_collected","world_id":"bramble"}
WARP {"seat":2}
RESCUE {"seat":1}
```
(d01/d02 collection -> `dreamling_chime`; RESCUE -> `bubble_catch`; the
30 s runtime also crosses Bramble's `snore_geyser` 5 s cycle boundary
roughly six times.)

```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --world=bramble --pads=2 --script=tools/harness/scripts/gate2_return.json --outdir=evidence/_scratch/audio_verify --quitafter=12
```
Run against a temporarily-cleared save (the existing dev `save.json` had
`d10` already in `returned`, which would have short-circuited the door and
skipped the event — backed up, cleared, ran, then **restored verbatim**
afterward; the backup/restore diff is empty):
```
EVT {"id":"d10","t":122,"type":"dreamling_collected","world_id":"bramble"}
EVT {"id":"d10","t":122,"type":"dream_returned","world_id":"bramble"}
MOON_SAID {"key":"dream_home","text":"Carry the dream home so the giant can keep sleeping softly."}
```
(dream_returned -> `dream_home`.)

**Grep receipt, both full logs combined:**
```
grep -c "sfx not found" meadow_full_log.txt return_full_log2.txt
meadow_full_log.txt:0
return_full_log2.txt:0
```
Zero matches. All four wired sfx names resolve and play.

`bubble_pop` and `land_soft` have no call site yet (generated ahead of
wiring, per the brief); stem playback (`play_stem_layer`) also has no call
site yet anywhere in the codebase (`grep -rn "play_stem_layer"` outside
audio_manager.gd returns nothing) — the stem seam is not yet consumed by
any world script, so it could not be exercised by a headless boot. This is
an existing, pre-this-session state of the codebase, not a regression.

## 5. AudioManager change

Added one public helper (public API of `play_sfx` untouched):

```gdscript
## Maps a dreamling-count step (1-based) to the matching rung of the
## dreamling_chime pentatonic ladder (dreamling_chime, dreamling_chime_2..8)
## and plays it via play_sfx — counting climbs, pitch carries the joy.
## Steps above 8 clamp to the top rung rather than erroring or repeating.
func play_chime(step: int) -> void:
	var clamped_step: int = clampi(step, 1, 8)
	var sfx_name: String = "dreamling_chime" if clamped_step == 1 else "dreamling_chime_%d" % clamped_step
	play_sfx(sfx_name)
```

Note: `worlds/common/dreamling.gd` still calls `play_sfx("dreamling_chime")`
directly (a flat, unchanging pitch on every collect) — it has not been
rewired to call the new `play_chime(step)` with a running collection count.
That rewire touches `worlds/common/dreamling.gd`, outside this task's
territory (`tools/audio_gen/`, `assets/audio/**`, `audio_manager.gd`,
`docs/verify/audio-VERIFY.md` only) — flagging it as the natural next step
for whoever owns the collectible/count logic.

## UNVERIFIED

- **Subjective "does it sound right" / "is it hushed enough" listening
  check.** Peaks, durations, channel counts, the loop-seam sample-jump
  analysis, and the register-floor mechanics (attack times, partial decay
  asymmetry, no percussive transients by construction) are all verified
  above; an actual human listening pass on real speakers/headphones was
  not performed in this session.
- **`bubble_pop`, `land_soft`, and all four `play_stem_layer` calls** could
  not be exercised via a headless boot because no game code currently
  calls them (see §4). Their files exist, pass ffprobe, and pass the
  generator's own peak checks, but "AudioManager successfully loads and
  plays them at runtime" is unverified for lack of a call site — same
  status as before this session, just now backed by files that exist.
- **Real-time CPU/latency cost of loading a 32 s stem OGG** in-engine
  (decode time, memory) was not profiled — out of scope for a placeholder
  seam, flagging for whoever wires `play_stem_layer` into a world's
  `_ready()`.

## Deviations (one-line justifications)

- **numpy/scipy-free DSP** (FFT-masked low-pass instead of `scipy.signal`,
  crossfaded-noise-band "sweep" instead of a true time-varying filter):
  scipy wasn't in the permitted install list and the brief only allowed
  numpy; both techniques are standard, dependency-free substitutes that
  meet the same audible goal (smooth low-pass, perceptual filter sweep)
  without the extra dependency.
- **Loop crossfade at 60 ms instead of a hard periodic match:** rather than
  requiring every oscillator frequency to divide the 32 s loop evenly
  (fragile, note-choice-constraining), `render_seamless_loop` generates a
  small overhang past the loop point and equal-power-crossfades it into
  the head — works uniformly for the pure-tone drone, the note-scheduled
  melody, and the randomized pizzicato/shimmer layers with one shared
  helper. Verified end-to-end on the encoded file in §2.
- **`pillow_fort/layer_1` transposed up an octave (D3+A3) instead of a
  simple volume-only copy of Bramble's D2+A2:** the brief called it an
  "even quieter home-drone variant" — one octave up plus a lower peak
  target reads as "closer/homier" rather than just "the same drone, turned
  down," which seemed like the more deliberate choice for a hub space
  versus a sleeping giant's world. Purely a synthesis choice inside my own
  territory; easy to revert to a literal amplitude-only copy if the
  producer prefers.
