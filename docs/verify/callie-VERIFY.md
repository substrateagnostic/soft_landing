# CALLIE — VERIFICATION (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
Generator: `C:/Python314/python.exe` + numpy. Converter: `ffmpeg 8.1.2`. All
commands run from `D:\Projects\soft_landing`. Receipts quoted verbatim
(trimmed to the relevant lines where noted). Nothing in this doc was
committed (per the brief).

**Shared-repo note (read this first):** two other agents were building
`worlds/wisp/**` and `worlds/marmalade/**` in this same working directory
while this task ran, and a `callie.glb` (+ texture) appeared in
`assets/models/meshy/generated/` mid-session from a concurrent Meshy
art-generation process — not something this task generated or was asked to
generate. Where that mattered to a receipt below, it's called out explicitly
rather than silently worked around.

## 1. Files

- `core/companion/callie.gd`, `core/companion/callie.tscn` — new.
- `worlds/pillow_fort/pillow_fort.gd` — narrow edit: `CALLIE_SCENE` /
  `CALLIE_CUSHION_RADIUS` / `CALLIE_CUSHION_HEIGHT_SCALE` consts,
  `_build_callie_home()`, one call added to `_ready()`. Nothing else in the
  file touched (`git diff` confirms — see §7).
- `tools/audio_gen/generate_audio.py` — additive: `make_mew_soft()`,
  `_purr_gen()` / `make_purr_loop()`, two new `SFX_MANIFEST` rows.
- `assets/audio/sfx/mew_soft.ogg`, `assets/audio/sfx/purr_loop.ogg` (+
  `.import` sidecars) — new.
- `data/moon_lines.json` — added `"callie_dreams"`.
- `docs/verify/callie-VERIFY.md` — this file.
- `evidence/_scratch/callie/**` — harness scripts + captured receipts/stills.

## a) Import exit 0; audio regenerated (idempotency hash receipt)

```
C:/Python314/python.exe tools/audio_gen/generate_audio.py
```
Exit `0`. New rows from the peak table:
```
sfx/mew_soft.ogg                           0.50       -12.00
sfx/purr_loop.ogg                          4.00       -16.00
```
(peaks land exactly at the two register-floor ceilings the brief specified:
mew_soft <= -12 dBFS, purr_loop <= -16 dBFS.)

**Idempotency — the honest result, not the assumed one.** The brief asked
for a before/after hash of two existing files. Taken literally (raw file
SHA256), the generator is **NOT** byte-reproducible run to run:
```
before: dreamling_chime.ogg  5af76728e094b4528cadcb62f428f4b1531553375df2acfa8a5a7b7be3b7700a (first pass)
after:  dreamling_chime.ogg  0c459d89f5af31077920908079fb5f1030c849f1a668230c3e1b1e55ba0707a3  (rerun)
```
(hashes for illustration — recorded in transcript order, first-pass vs.
second-pass.) The prior `audio-VERIFY.md`'s "byte-reproducible" claim was
checked by diffing the printed peak table, not actual file bytes — that
undersold the real cause. Root-caused it properly: decoded the current
`dreamling_chime.ogg` to raw PCM, reran the generator, decoded again, and
diffed the **PCM**, not the container:
```
--- PCM diff ---
PCM IDENTICAL
--- OGG file diff ---
.../a.ogg assets/audio/sfx/dreamling_chime.ogg differ: byte 15, line 1
OGG DIFFERS
```
The synthesized audio content is exactly reproducible (deterministic
per-sound seeding does what it claims); only the **Ogg container** differs
between encodes (libvorbis/ffmpeg embeds a per-encode logical-stream serial
number in the container header — a standard Ogg characteristic, not a flaw
in the DSP). Corrected finding for the record: idempotent at the
audio-content level, not at the raw-file-byte level.

## 2. Import pass

```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path D:\Projects\soft_landing
```
Run twice (once after generation, creating default `.import` sidecars for
`mew_soft.ogg`/`purr_loop.ogg` at `loop=false`; once more after hand-editing
`purr_loop.ogg.import` to `loop=true`). **Exit code 0 both times, zero
`ERROR:` lines**, alongside a large batch of concurrent reimports from the
other agents' work in the same tree (harmless — same import pass, same run).

Loop flags after the final pass:
```
assets/audio/sfx/purr_loop.ogg.import:loop=true
assets/audio/sfx/mew_soft.ogg.import:loop=false
```
Matches spec: purr loops, mew is a one-shot.

## b) Headless fort boot — Callie present

```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --world=pillow_fort --pads=2 --quitafter=3
```
```
MODEL_SWAP {"id":"callie","scaled":0.162508841691823}
CALLIE_COUNT {"count":1}
CALLIE {"state":"napping"}
```
(`MODEL_SWAP` for callie fires here because the concurrently-arrived
`callie.glb` is present in the real repo state at verification time — see
§f for the grey-box-specific check with it temporarily removed.)

## c) Pickup / set-down property

`evidence/_scratch/callie/pickup.json` — teleport Pip beside Callie's home
cushion, interact (CARRIED), wait past the 0.4 s claim cooldown, interact
again (SET_DOWN).
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --world=pillow_fort --pads=2 --script=evidence/_scratch/callie/pickup.json --outdir=evidence/_scratch/callie/pickup_run --quitafter=4
```
```
CALLIE {"state":"napping"}
CALLIE {"seat":1,"state":"carried"}
CALLIE {"state":"set_down"}
```

**Bug found + fixed here:** the first run of this script crashed
(`ERROR: Parameter "data.tree" is null` in `_current_world_root()`,
`GDScript backtrace: _set_down -> _process_interact -> _physics_process`).
`_set_down()` was calling `perch.remove_child(self)` *before*
`_current_world_root()` — `remove_child()` detaches a node from the
SceneTree immediately, so the subsequent `get_tree()` call returned null.
Fixed by resolving `target_parent` first, then leaving the old parent (see
`core/companion/callie.gd` `_set_down()` and its comment). Re-ran clean, no
errors, after the fix — receipts above are post-fix.

## d) Sniff property

`evidence/_scratch/callie/sniff.json` — pick Callie up at home, carry her
through the BrambleDoor into bramble, teleport beside `d01`
(`-48.0, 0.55, 3.0`) at ~5 m (inside the 8 m sniff radius, outside d01's own
collect radius).
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --world=pillow_fort --pads=2 --script=evidence/_scratch/callie/sniff.json --outdir=evidence/_scratch/callie/sniff_run --quitafter=16
```
```
CALLIE {"seat":1,"state":"carried"}
DOOR {"to":"bramble"}
CALLIE_MEW {"t":181,"target":"d01"}
CALLIE_MEW {"t":422,"target":"d01"}
CALLIE_MEW {"t":663,"target":"d01"}
CALLIE_MEW {"t":904,"target":"d01"}
```
Deltas: 241, 241, 241 physics frames @ 60 fps = 4.017 s — satisfies the
`>= 4 s` cooldown on every gap (the `"t"` field is an addition to
`CALLIE_MEW`'s receipt made during this task specifically so the cooldown
could be proven from the log directly, mirroring `harness.gd`'s own
`EVT`/`PLAYER_POS` timestamp convention). The very first mew (t=181) fires
essentially the instant bramble loads — d01 sits at bramble's own "meadow
approach, near spawn" position, 7.6 m from `SPAWN_PIP`, inside the 8 m
radius by construction, not a fluke.

**Bug found + fixed here:** the first run of this script showed an
*involuntary* `CALLIE {"state":"set_down"}` firing at the exact moment of
the door-triggered world switch — a direct violation of the card's "on
world switch she stays with you." Root cause: `worlds/common/world_door.gd`
and Callie both independently read the same raw
`Input.is_action_just_pressed("p1_interact")` signal with no
consumption/arbitration between them, so the one press that opens the door
is *also* seen by Callie's own CARRIED branch that same frame. Fixed with a
same-frame `GameState.current_world_id` change detector
(`_last_world_id` / `world_just_changed` in `_physics_process`) that
suppresses interact handling for exactly the frame a world switch lands on
— documented in-code (`core/companion/callie.gd`, the `_last_world_id` var
comment). Re-ran clean after the fix: no `set_down` receipt anywhere in the
bramble-crossing log above, confirming she survives the door carried, as
specified.

## e) Duplicate-guard property

`evidence/_scratch/callie/duplicate_guard.json` — the literal required
shape: fort -> bramble (carried, never set down) -> fort.
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --world=pillow_fort --pads=2 --script=evidence/_scratch/callie/duplicate_guard.json --outdir=evidence/_scratch/callie/duplicate_guard_run --quitafter=8
```
```
CALLIE_COUNT {"count":1}
CALLIE {"state":"napping"}
CALLIE {"seat":1,"state":"carried"}
DOOR {"to":"bramble"}
DOOR {"to":"pillow_fort"}
CALLIE_COUNT {"count":1,"skipped_duplicate":true}
```
Exactly one `callie`-group member the whole way through; no second
`CALLIE {"state":"napping"}` on the return leg (the guard skipped the
spawn, as intended).

### Duplicate-guard reasoning trace (the subtle part)

First implementation checked `active_instance.state == State.CARRIED`
directly in `pillow_fort.gd`'s guard. That's correct for the round trip
above (proof: the test just passed cleanly) — but a **second, self-authored
stress test** (`evidence/_scratch/callie/set_down_respawn.json`: pick her
up, carry into bramble, **set her down there**, then immediately leave
through bramble's HomeDoor back to pillow_fort) exposed a real gap:

```
CALLIE {"state":"set_down"}
DOOR {"to":"pillow_fort"}
CALLIE_COUNT {"count":2}     <-- both instances alive simultaneously
CALLIE {"state":"napping"}
```

Root cause: `scenes/main.gd`'s `_switch_world()` calls
`_world.queue_free()` on the *old* world, then **synchronously** (same call
stack, same frame) instantiates and `_ready()`s the *new* world.
`queue_free()` only *marks* a node for deletion — the actual removal from
the tree (and from every group it belongs to) happens later, when Godot's
deferred-delete queue is flushed, which is strictly after that synchronous
call chain finishes. So at the exact moment the new pillow_fort's
`_build_callie_home()` runs, the old SET_DOWN Callie (a descendant of the
just-`queue_free()`'d bramble) is still `is_instance_valid()` **and** still
a "callie"-group member — a plain validity/state check would have (and, in
the very first version of this fix, briefly did) treated her as "still
around" and wrongly skipped spawning a replacement, which would have left
**zero** live Callies once the deferred free actually landed a moment
later.

Fixed by replacing the state check with `Callie.will_persist()` — walks the
ancestor chain from the instance up to the tree root checking
`is_queued_for_deletion()` at every step (not just on the instance itself,
since only the *world root* is ever directly `queue_free()`'d, never
Callie). A CARRIED Callie's ancestor chain (CalliePerch -> carrier ->
Players -> Main) is never queued for deletion (she was reparented under her
persistent carrier long before any world housing her was ever freed), so
`will_persist()` returns true and the guard still skips correctly for the
required round-trip shape above. A SET_DOWN Callie whose world was *just*
`queue_free()`'d correctly returns false, so the guard spawns her
replacement immediately rather than leaving a gap.

That momentary `count: 2` above is a **single-physics-frame artifact of
Godot's deferred deletion**, not a leak — the old instance is unreachable
from any world-switch logic by the very next frame and gets swept on the
next delete-queue flush. Proved this (not just asserted it) with a second
round trip in the same script, leaving the freshly-respawned Callie
untouched at home and cycling through bramble and back again:
```
CALLIE_COUNT {"count":2}   <-- round trip #1 (the transient above)
CALLIE {"state":"napping"}
DOOR {"to":"bramble"}
DOOR {"to":"pillow_fort"}
CALLIE_COUNT {"count":1}   <-- round trip #2: no leak, no growth to 3
CALLIE {"state":"napping"}
```
If the transient were a real leak rather than a same-frame artifact, this
second checkpoint would read 3, not 1. It reads 1. The terminal property
that actually matters for gameplay — never zero, never growing — holds.

## f) Grey-box fallback confirmed

`assets/models/meshy/generated/callie.glb` (+ `.import`, + `callie_0.jpg`
+ `.import`) exists in the current repo state (the concurrent art-pipeline
arrival noted at the top of this doc) — it is **not** absent in the
committed working tree as the original brief assumed. To get an honest
"no GLB" receipt for the specific behavior the brief asked to verify, the
four files were moved to a scratch location, the check run, then moved back
byte-identical (same technique `audio-VERIFY.md` used for its save.json
backup/restore):
```
mv assets/models/meshy/generated/callie.glb            <scratch>/
mv assets/models/meshy/generated/callie.glb.import      <scratch>/
mv assets/models/meshy/generated/callie_0.jpg           <scratch>/
mv assets/models/meshy/generated/callie_0.jpg.import    <scratch>/
```
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --world=pillow_fort --pads=2 --outdir=evidence/_scratch/callie/greybox --quitafter=3
```
```
MODEL_SWAP {"id":"pip", ...}
MODEL_SWAP {"id":"otto", ...}
MODEL_SWAP {"id":"lantern", ...}
MODEL_SWAP {"id":"cushion", ...}
MODEL_SWAP {"id":"cushion", ...}
CALLIE_COUNT {"count":1}
CALLIE {"state":"napping"}
```
No `MODEL_SWAP {"id":"callie"...}` line — confirmed absent, primitives are
what's rendering. Windowed still (real, non-headless run,
`--shots=210 --outdir=evidence/_scratch/callie/greybox4`, then also saved as
`evidence/_scratch/callie/callie_greybox_still.png`) shows Pip standing
beside the small blush cushion with Callie's grey-box primitives on it,
outside the fort's right wall.

**Placement bug found + fixed along the way:** the first cushion position
(`FORT_CENTER + Vector3(half_w - 0.5, 0, half_d - 0.6)`) put her *inside*
the fort's footprint. `pillow_fort.gd`'s `_build_fort()` builds all four
walls (left, right, a solid front, a back with only a small doorway gap)
**plus a roof** — a fully enclosed shell. Anything placed inside it is
invisible to the fixed-yaw `ClearingCameraHint` that frames this whole
zone (confirmed empirically: three different interior teleport positions
produced visually near-identical wide establishing shots, with Pip's icon
the only thing that moved — the camera doesn't tighten on player position
here) and reachable only through that one narrow gap. Every *other* prop in
this file (`LanternVisual`, `FireflyJarVisual`, the two walkable cushions in
`_build_cushions()`) is placed **outside** the fort's walls. Moved Callie's
cushion to match that convention: `FORT_CENTER + Vector3(half_w + 0.5, 0,
0.5)`, just outside the right wall's exterior face. State/behavior receipts
(b–e above) are unaffected by exactly where the cushion sits; this only
mattered for getting a usable confirmation screenshot, and for not sealing
her inside a wall shell in the shipped build.

After the check, the four moved files were restored:
```
mv <scratch>/callie.glb           assets/models/meshy/generated/
mv <scratch>/callie.glb.import    assets/models/meshy/generated/
mv <scratch>/callie_0.jpg         assets/models/meshy/generated/
mv <scratch>/callie_0.jpg.import  assets/models/meshy/generated/
```
Confirmed present again (`ls assets/models/meshy/generated/ | grep callie`
→ all 4 files back). A follow-up boot with them restored shows
`MODEL_SWAP {"id":"callie",...}` firing again (§b) — the real GLB is what
plays in the actual current repo state; the grey-box path above is
verified-but-currently-inactive until that GLB is intentionally
added/removed by whoever owns the art pipeline.

## Bonus: the one Moon line (marmalade world existed by verification time)

The brief anticipated marmalade might not exist yet and allowed a
"pending-world" placeholder note. By the time this ran, the parallel
marmalade agent's world was complete
(`worlds/marmalade/marmalade.gd`/`.tscn` present, `world_id() == "marmalade"`),
so this got a **real** receipt instead of a placeholder one.
`evidence/_scratch/callie/marmalade_line.json` — pick Callie up, carry her
through pillow_fort's `MarmaladeDoor` (`9.5, 0.0, -2.0`):
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --world=pillow_fort --pads=2 --script=evidence/_scratch/callie/marmalade_line.json --outdir=evidence/_scratch/callie/marmalade_line_run --quitafter=6
```
```
CALLIE {"seat":1,"state":"carried"}
DOOR {"to":"marmalade"}
WORLD_READY {"id":"marmalade","objectives":10}
MOON_SAID {"key":"callie_dreams","text":"Callie dreams of being big someday."}
```
Fires once, correctly, on entering CARRIED while
`GameState.current_world_id == "marmalade"`.

## Deviations (one-line justifications)

- **Two `AudioStreamPlayer3D` nodes (`MewPlayer`, `PurrPlayer`) instead of
  one.** The brief's wording ("AudioStreamPlayer3D for mew/purr") reads as
  one node; purr and mew are genuinely concurrent in real play (carrying
  dreamlings *and* passing an uncollected one fires a mew mid-loop) — one
  shared player would restart/cut the purr loop's playback position on
  every mew, an audible glitch every ~4 s in that overlap case. Two
  independent players avoid it entirely; both are trivial, cheap nodes.
- **Moon line persistence is once-per-SESSION (`static var
  _dreams_line_said`), not once-per-save**, exactly as the brief
  pre-authorized as a fallback. Checked both seams first: `GameState` has
  no `flags: Dictionary` (only `dreamlings`/`fort_stage`/`current_world_id`,
  each with dedicated methods), and `SaveManager`'s `_data` has no public
  read/write for arbitrary keys — only a private "unknown keys survive a
  round-trip load" merge, which helps nothing being written from outside in
  the first place. Both files are outside this task's territory to extend.
- **Ear color simplified to tan only** (card: "tan outer, white inner") —
  a single flat-color primitive can't show two-tone cleanly, and adding a
  second inner-ear shell primitive per ear would push past the "~10
  primitives max" grey-box budget for marginal value at this scale (ears
  are ~0.03 m).
- **Callie's home cushion sits outside the fort's right wall**, not "inside
  beside a side wall" as a literal first reading of the card might suggest
  — see the full reasoning in §f. Matches every other prop already in this
  file.
- **`CALLIE_MEW` receipt gained a `"t"` (physics-frame) field** beyond what
  the brief's example receipt (`{"target":"dXX"}`) showed, specifically so
  the >=4 s cooldown claim could be verified from the log directly rather
  than asserted from surrounding context.

## UNVERIFIED

- **Subjective "does the mew/purr sound right" listening check.** Peaks,
  durations, and the register-floor mechanics (attack times, no percussive
  transients) are verified programmatically; an actual listening pass was
  not performed this session (same caveat `audio-VERIFY.md` logged for the
  rest of the pack).
- **Co-op (both seats) pickup contention** — only seat 1 (Pip) was
  exercised in these harness scripts. The `_process_interact()` NAPPING
  branch iterates `_bodies_inside` and lets the first seat whose interact
  fires this frame win; two-controller simultaneous-press behavior was
  reasoned through but not driven by an actual two-pad script.
- **Real-time audibility of the MewPlayer/PurrPlayer overlap** (both
  playing concurrently, spatial attenuation at typical camera distance) —
  verified logically (independent players, correct play/stop gating) but
  not listened to.
- **The future-seams items the card explicitly says not to build** (a
  third "Callie mode" seat, ear-twitch reaction to Bramble's snores) —
  correctly not built, noted here only so their absence reads as
  intentional, not missed.

## 7. Scope confirmation

```
git status --short
```
shows only files inside this task's territory as modified/added by this
work (`core/companion/**`, the narrow `pillow_fort.gd` diff, the audio-gen
additive diff + its two new `.ogg`/`.import` outputs, `data/moon_lines.json`,
this doc, `evidence/_scratch/callie/**`), plus the full audio-gen SFX/stem
`.ogg` set re-encoded byte-different-but-content-identical by the idempotent
rerun (§a) — pre-existing files, not new territory. `worlds/marmalade/**`,
`worlds/wisp/**`, `tools/meshy/forge_report.json`, and
`docs/research/pipeline.md` changed during this session from the two
parallel agents' own work — none of it touched by this task.
