# AUDIO V2 — VERIFICATION (2026-07-16)

served_model: claude-sonnet-5 (Sonnet 5), acting as the audio v2 build agent
directly (no external model calls this pass).

Engine: `D:\Tools\godot\Godot_v4.6.2-stable_win64_console.exe` →
`4.6.2.stable.official.71f334935`, Windows. Generator: `C:\Python314\python.exe`
3.14.0 + numpy 2.5.1. Converter: `ffmpeg 8.1.2-essentials` at
`D:\Tools\ffmpeg\ffmpeg-8.1.2-essentials_build\bin\ffmpeg.exe`. All commands
run from `D:\Projects\soft_landing`. Territory (per brief): `tools/audio_gen/**`,
`assets/audio/**`, `scripts/autoloads/audio_manager.gd` (additive only),
`core/audio/**` (new), `scenes/players/pip.tscn` + `otto.tscn` (one
PlayerAudio node added, nothing else touched), `worlds/common/positional_audio.gd`
(new), additive sound calls in `worlds/common/dreamling.gd` / `touch_react.gd`
/ `critter.gd`, `docs/verify/audio-v2-VERIFY.md`. No world script, no
`mission_driver.gd`, no `world_door.gd`/`dream_door.gd`, no `the_moon.gd`,
`data/**`, or `main.gd` were edited. No git commits made.

## 1. Generator — `tools/audio_gen/generate_audio_v2.py` (new file)

Imports `generate_audio.py` as a module (same pattern `generate_voice.py`
established) — zero edits to that file. Uses a local `to_ogg_bitexact()`
(the `-fflags +bitexact` technique `generate_voice.py`'s own module
docstring already documented as necessary for byte-reproducible `.ogg`
containers) for every output in this pass, so "deterministic, hash twice"
is provably true of the container bytes, not just the decoded PCM.

```
C:/Python314/python.exe tools/audio_gen/generate_audio_v2.py
```

Exit code `0`. Full peak-level / hash summary (ran twice; every sha256 in
the second run matched the first — spot check below, full 20-row diff
was byte-identical column-for-column):

```
=== Peak-level / hash summary table ===
file                                         dur(s)   peak(dBFS)  sha256[:16]
assets/audio/sfx/flutter.ogg                   0.35        -8.00  bffef1d326366b0d
assets/audio/sfx/glide_loop.ogg                3.00       -14.00  f183f468c4c79492
assets/audio/sfx/pound_start.ogg               0.22        -9.00  d4bbd86cf28efee6
assets/audio/sfx/pound_land.ogg                0.50        -8.00  b68030ac28005232
assets/audio/sfx/footstep.ogg                  0.10       -16.00  9917f297c6c407c3
assets/audio/sfx/moth_flutter.ogg              0.50       -14.00  75da9837624f1996
assets/audio/sfx/mouse_squeak.ogg              0.40       -12.00  c1d66941af252ec7
assets/audio/sfx/door_chime.ogg                0.65        -8.00  64b17392589c46ef
assets/audio/sfx/dreamling_giggle.ogg          0.47       -10.00  4e8bc3e02a4d4c27
assets/audio/sfx/dreamling_giggle_2.ogg        0.47       -10.00  433d9e57f94d8c31
assets/audio/sfx/dreamling_giggle_3.ogg        0.47       -10.00  e362883d4147574d
assets/audio/sfx/poke_boop.ogg                 0.28        -9.00  fdc1d69293b73c3c
assets/audio/ambience/bramble.ogg             36.00       -22.00  3d139c6bb20c2219
assets/audio/ambience/pillow_fort.ogg         36.00       -24.00  abd763acd65eb515
assets/audio/ambience/wisp.ogg                36.00       -22.00  385833745b961a30
assets/audio/ambience/marmalade.ogg           36.00       -23.00  55b98dd0036652b5
assets/audio/ui/focus_tick.ogg                 0.09       -14.00  d9c09463056823f6
assets/audio/ui/confirm_bloom.ogg              0.55        -9.00  1af718d56f6817d5
assets/audio/ui/pause_open.ogg                 0.40       -12.00  92d803e2455a99ab
assets/audio/ui/pause_close.ogg                0.40       -12.00  eed12eb9572f2710
```

Peak targets (documented in `SFX_V2_MANIFEST` / `AMBIENCE_MANIFEST` /
`UI_MANIFEST`, one table each, per the "levels in one place" mix-discipline
ask): verb one-shots -8 to -16 dBFS (footstep quietest on purpose, rate-
limited but frequent), critter one-shots -12/-14 (whisper-quiet — the
critter's motion already reads as startled), ambience beds -22 to -24 dBFS
peak (the brief's "≤ -24 LUFS-ish, approximated via peak target" — this
pipeline has no true LUFS meter, documented as a deliberate approximation
in the module docstring, same numpy-only-DSP tradeoff V1 already made and
justified), UI sounds -9 to -14. Everything sits at or under V1's own -6
dBFS register ceiling except `dream_home`-adjacent chimes which V1 already
set precedent for (`door_chime`/`pound_start`/`pound_land`/`flutter` at -8/-9,
consistent with V1's `toss`/`snore_geyser` at -7).

## 2. ffprobe — every new file

```
ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,duration -of csv=p=0 <file>
```

All 20 new files: `48000,1,<duration>` (48 kHz mono), duration matching the
generator's own report exactly (spot-checked full table, e.g.
`ambience/bramble.ogg → 48000,1,36.000000`, `sfx/glide_loop.ogg →
48000,1,3.000000`, `ui/focus_tick.ogg → 48000,1,0.090000`).

### Loop-seam integrity after lossy encoding

Same technique V1 used on the Bramble stems, re-run on the two loop types
this pass adds (a short verb loop and a long ambience loop):

```
glide_loop.ogg:      decoded=144000  expected=144000  wrap_jump=30  median_mid_delta=66
ambience/bramble.ogg: decoded=1728000 expected=1728000 wrap_jump=46  median_mid_delta=7
```

Both decode to exactly the expected sample count (no Vorbis pre-skip/pad
drift). `glide_loop`'s wrap jump (30) is smaller than its own median
mid-file step (66) — the loop point is literally smoother than an average
sample-to-sample step elsewhere in the file. `ambience/bramble`'s wrap jump
(46) is larger relative to its very small median delta (7 — a slowly-
varying noise texture spends most of its time barely moving sample-to-
sample) but 46/32767 is 0.14% of int16 full scale, nowhere near an audible
click (V1's own accepted precedent: 59/32767 = 0.18%). Both loops survive
lossy encoding intact.

## 3. Headless import — clean, `loop=true` set correctly

```
D:\Tools\godot\Godot_v4.6.2-stable_win64_console.exe --headless --editor --import --quit --path .
```

Run three times this session (initial generation, after setting `loop=true`
on the 5 loop-type files, and a final confirmation pass) — **exit code `0`
every time, zero `ERROR:` lines.** `loop=true` set on exactly the 5 files
that loop (`sfx/glide_loop.ogg` + all 4 `ambience/*.ogg`); every one-shot
(`flutter`, `pound_land`, `ui/focus_tick`, etc.) confirmed still
`loop=false` (the importer default) — spot-checked directly on the
`.import` sidecars after the final reimport pass, not just before it.

## 4. AudioManager — additive changes (public API of `play_sfx` /
`play_chime` / `play_stem_layer` / `stop_stems` / volume setters untouched)

```gdscript
const AMBIENCE_DIR: String = "res://assets/audio/ambience/"
const UI_DIR: String = "res://assets/audio/ui/"

func load_sfx_stream(sfx_name: String) -> AudioStream: ...   # returns the stream instead of playing it on the shared _sfx_player
func play_ui(ui_name: String) -> void: ...                    # assets/audio/ui/*.ogg via a dedicated _ui_player
func play_ambience(world_id: String) -> void: ...             # assets/audio/ambience/<world_id>.ogg via a dedicated _ambience_player (MUSIC_BUS)
func stop_ambience() -> void: ...
func _process(_delta: float) -> void: ...                     # polls GameState.current_world_id once/frame, auto-swaps ambience on change
```

**World-change seam:** `GameState` has no world-changed signal (confirmed
by reading `game_state.gd` — `set_current_world()` just assigns
`current_world_id`), and `GameState`/`main.gd` are outside this pass's
territory. `AudioManager._process()` polls `GameState.current_world_id`
once a frame (a String compare) and calls `play_ambience()`/`stop_ambience()`
the instant it changes — entirely self-contained inside `audio_manager.gd`,
zero wiring required from any other script, including the very first world
load at boot. Verified (not just theorized — see §7): all 4 worlds boot
with their matching ambience bed loaded and zero `"ambience not found"`
lines.

## 5. New files — `core/audio/player_audio.gd`, `worlds/common/positional_audio.gd`

**`PlayerAudio`** (`core/audio/player_audio.gd`, `class_name PlayerAudio`) —
sibling seam to `core/art/character_animator.gd`: listens to the same
`PlayerBody.state_changed` / `landed` / `pound_landed` signals, plays sound
only (never animation). Owns its own small `AudioStreamPlayer` pool
(loaded via `AudioManager.load_sfx_stream`, never `AudioManager`'s shared
`_sfx_player`) so two players' verb sounds in co-op never cut each other
off. Verb map: FLUTTER → `flutter`; GLIDE enter/exit → `glide_loop` faded
in/out (the baked loop has no fade of its own — fading would break the
loop seam); POUND enter → `pound_start`; `pound_landed` → `pound_land`
(and suppresses that same frame's generic `landed` pat via
`_pound_landing_this_frame`, since `player_body.gd`'s `_land_pound()`
emits `pound_landed` synchronously before `landed` on the same physics
frame — proven in §6, `POUND_LAND` always precedes the frame's `landed`
EVT); any other `landed` → `land_soft` (V1's existing asset, wired to a
call site for the first time); running on ground → `footstep` at a
distance-accumulator cadence (`STEP_DISTANCE / speed`, not a fixed timer,
so cadence scales naturally with run speed with no tuning-resource
coupling).

**`PositionalAudio`** (`worlds/common/positional_audio.gd`, `class_name
PositionalAudio`) — a stateless `static func play_at(sfx_name, world_position,
pitch_scale=1.0)`. Reuses `AudioManager.load_sfx_stream` (the SFX pool
under `assets/audio/sfx/`) rather than a second directory or registry, so
"AudioManager-registered" streams are positionally playable with zero
extra bookkeeping. Spawns one ephemeral `AudioStreamPlayer3D` parented to
the SceneTree root (not the caller, so a one-shot outlives a caller that
frees itself mid-sound), freed on `finished`. `unit_size`/`max_distance`
constants kept in the file per the mix-discipline "levels in one place"
ask.

## 6. Scene wiring — `pip.tscn` / `otto.tscn`

One `ext_resource` + one child node added to each, nothing else touched
(diffed against the pre-session file):

```
[node name="PlayerAudio" type="Node" parent="."]
script = ExtResource("7")   # pip.tscn — id 9 in otto.tscn
```

## 7. Verb sounds — headless proof + windowed movie / volumedetect

New script `tools/harness/scripts/audio_verbs.json` (audio_-prefixed, per
the shared-scripts-dir convention). PIP (seat 1): runs frames 0-150
(footsteps), teleports to flat ground, then the exact +15-frame
double-jump offset `flutter_gap.json` already proved triggers FLUTTER.
OTTO (seat 2): a ground jump held through a teleport into open air
(`glide_descent.json`'s proven technique) for GLIDE, then a teleport +
interact while airborne (`pound_bounce.json`'s proven technique) for
POUND.

### 7a. Headless dry run (determinism + zero missing-asset check)

```
godot_console.exe --headless --path . -- --skipmenu --pads=2 --script=tools/harness/scripts/audio_verbs.json --outdir=evidence/_scratch/audio_v2_verbs --quitafter=12
```

```
EVT {"seat":1,"t":191,"type":"jumped"}
FLUTTER {"seat":1}
EVT {"seat":1,"t":257,"type":"landed"}
EVT {"seat":2,"t":301,"type":"jumped"}
GLIDE_START {"seat":2}
EVT {"seat":2,"t":426,"type":"landed"}
POUND_START {"seat":2}
POUND_LAND {"seat":2}
EVT {"seat":2,"t":514,"type":"landed"}
```

`grep -c "not found"` on the full log: the only match is the script's own
`description` field (which contains the literal phrase "zero 'not found'
lines" as prose) — **zero actual `AudioManager: ... not found` lines**
across `flutter`, `glide_loop`, `pound_start`, `pound_land`, `land_soft`,
`footstep`. Exit code `0`, re-run confirmed identical EVT frame numbers
(deterministic).

### 7b. Windowed movie (never `--headless` — Movie Maker needs a real
display driver)

```
godot_console.exe --path . --write-movie evidence/audio_v2_verbs.avi --fixed-fps 60 --resolution 1280x720 -- --skipmenu --pads=2 --script=tools/harness/scripts/audio_verbs.json --quitafter=13
```

780 frames at 60 FPS (13.00 s), exit code `0`, EVT frame numbers **byte-
identical** to the headless dry run (191/257/301/426/483/489/514) — the
same script drives both, confirming the audible run isn't doing anything
different from the textually-verified one. Transcoded per the harness
README recipe:

```
ffmpeg -y -i evidence/audio_v2_verbs.avi -c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium -movflags +faststart evidence/audio_v2_verbs.mp4
```

### 7c. `volumedetect` — full clip and per-episode windows vs. a quiet baseline

```
ffmpeg -i evidence/audio_v2_verbs.avi -af volumedetect -f null -
```
Audio stream confirmed present: `pcm_s16le, 48000 Hz, stereo`.

| Window | `-ss` / `-t` | mean_volume | max_volume |
|---|---|---|---|
| Full clip | 0.0 / 13.0 | **-17.7 dB** | **-1.6 dB** |
| Footsteps (run) | 0.0 / 2.5 | -16.8 dB | -1.6 dB |
| Flutter | 3.0 / 1.3 | -16.6 dB | -3.7 dB |
| Glide | 5.05 / 1.65 | -16.9 dB | -7.1 dB |
| Pound | 8.0 / 0.7 | -14.8 dB | -4.6 dB |
| Quiet baseline (all settled, no scripted verb active) | 11.0 / 1.0 | -21.7 dB | -14.1 dB |

Every verb window reads audibly louder (mean 2-7 dB hotter, max 7-12.5 dB
hotter) than the quiet baseline window — proving the sounds fired and are
audible in the actual mix, not just present as unplayed assets. The
baseline itself isn't total digital silence (-21.7 mean / -14.1 max, not
-inf): that's expected and itself corroborating evidence for §9 below —
`pillow_fort` (the default/no-`--world`-flag world this script boots into)
is playing its own ambience bed plus Callie's existing `purr_loop`
throughout the whole clip, so "quiet" here correctly means "just the
ambient bed," not "nothing."

## 8. Positional one-shots + dreamling giggle — bramble world proof

New script `tools/harness/scripts/audio_bramble.json`. Run headless
(no audio capture needed — every claim here is proven by a grep-able EVT,
not by ear):

```
godot_console.exe --headless --path . -- --skipmenu --world=bramble --pads=2 --script=tools/harness/scripts/audio_bramble.json --outdir=evidence/_scratch/audio_v2_bramble --quitafter=18
```

```
EVT {"kind":"moth","t":5,"type":"critter_scatter","world":"bramble"}
EVT {"kind":"mouse","t":127,"type":"critter_scatter","world":"bramble"}
EVT {"id":"d04","t":444,"type":"dreamling_giggle","variant":"dreamling_giggle_3"}
EVT {"id":"d09","t":495,"type":"dreamling_giggle","variant":"dreamling_giggle"}
EVT {"id":"d06","t":506,"type":"dreamling_giggle","variant":"dreamling_giggle_2"}
EVT {"id":"d05","t":559,"type":"dreamling_giggle","variant":"dreamling_giggle_2"}
EVT {"id":"d02","t":615,"type":"dreamling_giggle","variant":"dreamling_giggle_3"}
EVT {"id":"d03","t":615,"type":"dreamling_giggle","variant":"dreamling_giggle_3"}
EVT {"id":"d01","t":653,"type":"dreamling_giggle","variant":"dreamling_giggle_2"}
EVT {"id":"d08","t":721,"type":"dreamling_giggle","variant":"dreamling_giggle_2"}
EVT {"id":"d07","t":818,"type":"dreamling_giggle","variant":"dreamling_giggle_2"}
```
(9 giggles across 9 distinct dreamling IDs, all 3 variants represented, no
two dreamlings synced — the staggered-interval design working as
intended.) `critter_scatter` fired for both `moth` (bramble's own spawn
proximity, before the scripted teleport even ran) and `mouse` (the
scripted teleport into the mouse cluster at frame 120). Zero `"not found"`
lines for `moth_flutter`, `mouse_squeak`, or `dreamling_giggle*` anywhere
in the log.

Also present, unrelated to this pass: `AudioManager: sfx not found (no-op):
res://assets/audio/sfx/breath_exhale.ogg` — Bramble's breathing-chest sound
(`worlds/bramble/breathing_chest.gd`, outside this pass's territory), a
pre-existing gap from before this session, not a regression.

## 9. Ambience adoption — all 4 worlds

```
godot_console.exe --headless --path . -- --skipmenu --world=<id> --pads=2 --quitafter=3
```
for `id` in `bramble`, `pillow_fort`, `wisp`, `marmalade`: exit code `0`
every time, **zero `"ambience not found"` lines** in any of the four logs
— `AudioManager._process()`'s poll (§4) picked up each world's
`current_world_id` and loaded its matching bed automatically, no per-world
code written anywhere else. (`wisp` and `marmalade` each print one
unrelated `"stem layer not found"` line for their still-missing V1 lullaby
stems — a pre-existing gap `docs/design/music-stems-spec.md` itself flags
as "write nothing yet," not an ambience miss and not this pass's
territory.)

## 10. `play_ui()` — harness-adjacent test call

`tools/harness/**`'s event vocabulary is fixed by `harness.gd`'s
`_execute_event()` `match` (outside this pass's territory to extend), so
`play_ui()` — a menu API with no `scenes/ui` caller yet, per the brief —
is receipted by a small standalone `SceneTree` script instead:
`tools/audio_gen/test_play_ui.gd`, run via Godot's own `-s` flag (still
boots every autoload, including `AudioManager`, without loading
`scenes/main.tscn`).

```
godot_console.exe --headless --path . -s res://tools/audio_gen/test_play_ui.gd
```
```
TEST_PLAY_UI_START
TEST_PLAY_UI {"name":"focus_tick"}
TEST_PLAY_UI {"name":"confirm_bloom"}
TEST_PLAY_UI {"name":"pause_open"}
TEST_PLAY_UI {"name":"pause_close"}
TEST_PLAY_UI_DONE
```
Exit code `0`, zero `"not found"` lines — all 4 UI sounds load and play
through the real `AudioManager` singleton. (First attempt without an
`await process_frame` hit `_ui_player` still being `null` — `_initialize()`
runs before autoloads' own `_ready()` has processed; documented in the
script's own comment as the reason the await is there, not removed as a
"works without it" cleanup.)

## 11. Regression smoke tests

`--pads=0`, `--pads=1`, `--pads=2` headless boots (5 s / 4 s each): all
exit `0`, zero new `ERROR:`/`SCRIPT ERROR:` lines. The recurring
`WARNING: ObjectDB instances leaked at exit` / `ERROR: N resources still
in use at exit` on every forced `--quitafter` shutdown is the same
pre-existing, documented characteristic of this codebase's shutdown path
(`docs/verify/world-marmalade-VERIFY.md`, `graphics-v2-VERIFY.md`,
`characters-v2-VERIFY.md` all note it independently) — reproduced
identically on an unmodified boot before this session's changes are even
exercised, not a regression this pass introduced.

## UNVERIFIED

- **`touch_react.gd`'s live poke trigger (`poke_boop` via `PositionalAudio`,
  3-pitch variance).** Attempted to teleport onto Bramble's `DreamDoor`
  visual to trigger it live; misidentified the door instance twice (first
  attempt used `_build_home_door()`'s `WorldDoor` — a different door type
  that never opts into the "poke" group at all; second attempt used the
  right door but the wrong local Y offset) and ran out of budget computing
  the real `DreamDoor`'s position (`ear_top`, derived from the bear-model's
  sphere-surface anchor math in `bramble.gd` — non-trivial to hand-compute
  without a bigger time slice). The code path itself is structurally
  identical to `critter.gd`'s `PositionalAudio.play_at()` call, which DID
  fire correctly in the same session (§8), and the asset passes generation
  + ffprobe + zero-"not-found"-on-boot cleanly (§1-3) — so this is a test-
  script targeting gap, not a code-correctness unknown, but it is
  genuinely unexercised live and should be re-attempted by whoever next
  touches Bramble's door geometry.
- **`door_chime` adoption.** Generated and registered (loads cleanly,
  zero "not found") but NOT wired into `world_door.gd`/`dream_door.gd` —
  both outside this pass's territory, exactly as the brief anticipated
  ("Wire the ones you CAN reach without foreign files"). A future pass
  owning those files can call `PositionalAudio.play_at("door_chime", ...)`
  directly; no further asset work needed.
- **Subjective "does it sound right"/"is it hushed enough" listening
  pass.** Peaks, durations, channel counts, loop-seam sample-jump
  analysis, and the register-floor mechanics (no percussive transients by
  construction, raised-cosine attacks ≥ 10 ms everywhere) are all verified
  above; an actual human listening pass on real speakers/headphones was
  not performed in this session — same caveat V1's own VERIFY doc carries
  forward.
- **Real-time CPU/latency cost of loading four 36 s ambience OGGs** (one
  per world, decode-on-`play_ambience()`-call) was not profiled — same
  category of gap V1 flagged for the 32 s lullaby stems, now extended to
  the ambience beds.
- **Menu-sound scene wiring** (`scenes/ui/pause_menu.gd` calling
  `play_ui()` on actual focus-move/confirm/pause events) is explicitly
  out of this pass's territory per the brief ("scenes/ui wiring belongs to
  others later") — §10 proves the API itself works, not that any UI
  currently calls it.

## Deviations (one-line justifications)

- **Ambience routed to `MUSIC_BUS`, not a new dedicated bus.** Keeps
  ambience under the same user-facing music-volume slider a parent already
  uses to duck the lullaby stems, and the "ducked under the stems" mix
  ask is satisfied via peak-target authoring (§1) rather than a second bus
  — one less moving part, same audible outcome.
- **`poke_boop` is one asset + 3 `pitch_scale` values picked at
  `touch_react.gd`'s call site, not 3 separately-authored files.** Cheaper
  variety for a sound that can fire dozens of times a session; the brief's
  "(3 pitches)" phrasing reads equally well either way, and a single
  source file is one less thing to keep in sync if the boop timbre ever
  changes.
- **`PositionalAudio` reuses `AudioManager`'s flat `SFX_DIR` pool instead
  of a second `assets/audio/positional/` directory.** The brief's own
  phrasing — "via AudioManager-registered streams" — reads as "whatever
  AudioManager already knows how to load," which the flat SFX pool already
  is; a second directory would only duplicate `poke_boop`'s existing
  non-positional call site history (`worlds/common/dream_door.gd`'s
  comment already documents that default) for no benefit.
- **Footstep cadence is a `STEP_DISTANCE / speed` accumulator, not a
  fixed-BPM timer or a new tuning-resource field.** AGENTS.md ties feel
  constants to `data/tuning/*.tres` for movement/camera specifically;
  audio has no such pattern yet anywhere in this codebase (V1's own
  `audio_manager.gd`/`generate_audio.py` just use local consts), so a
  local `const` in `player_audio.gd` matches the established audio-code
  convention rather than introducing a new resource type unilaterally.
- **Two small EVT-style `print()` receipts added** (`dreamling.gd`'s
  giggle, `touch_react.gd`'s poke) beyond what the brief strictly asked
  for. Matches `critter.gd`'s own existing `EVT critter_scatter` print
  convention exactly, and turned two otherwise ear-only claims into
  grep-able receipts (§8) — a small, in-style, additive change to files
  already in this pass's territory.

## Files touched (≤10 lines, paths only — see body above for detail)

- New: `tools/audio_gen/generate_audio_v2.py`, `tools/audio_gen/test_play_ui.gd`
- New: `core/audio/player_audio.gd`, `worlds/common/positional_audio.gd`
- New: `assets/audio/sfx/{flutter,glide_loop,pound_start,pound_land,footstep,
  moth_flutter,mouse_squeak,door_chime,dreamling_giggle[,_2,_3],poke_boop}.ogg`
  (+`.import`), `assets/audio/ambience/{bramble,pillow_fort,wisp,marmalade}.ogg`
  (+`.import`), `assets/audio/ui/{focus_tick,confirm_bloom,pause_open,pause_close}.ogg`
  (+`.import`)
- New: `tools/harness/scripts/audio_verbs.json`, `tools/harness/scripts/audio_bramble.json`
- Modified (additive): `scripts/autoloads/audio_manager.gd`,
  `worlds/common/{dreamling,touch_react,critter}.gd`,
  `scenes/players/{pip,otto}.tscn`
- Evidence: `evidence/audio_v2_verbs.{avi,mp4}`,
  `evidence/_scratch/audio_v2_verbs/events.jsonl`,
  `evidence/_scratch/audio_v2_bramble/events.jsonl`
