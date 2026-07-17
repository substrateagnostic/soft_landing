# HUB POPULATION — VERIFICATION (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
**served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic), running as
the hub-population build agent inside a Claude Code session.

Scope: `docs/research/v2/aliveness_wow.md` Top 12 #11 ("hub-as-visible-
progress-bar": every returned dreamling gets a physical presence in the
fort hub — a small idle animation, one 'notice the player' reaction, no
dialogue tree — Kirby Waddle Dee Town / Astro Crash Site / Spyro Homeworlds
model) and §structure_progression.md §7 ("dynamic, visible growth tied to
collection count, not menus... the hub can itself be a small collectathon").
Currently the fort grows in 3 abstract stages (night-lights/firefly-jar/
mobile) but the dreams themselves never appear — this pass makes every
*individual* returned dream take up residence.

Territory (per brief): `worlds/pillow_fort/pillow_fort.gd`,
`worlds/common/fort_resident.gd` + `fort_resident.tscn` (new files only),
`data/fort_residents/**` (new), `tools/harness/scripts/fort_population.json`
(new), this file, `evidence/stills/m3_hub/**`. Everything else
(`worlds/bramble/**`, `worlds/wisp/**`, `worlds/marmalade/**`, `core/**`,
`scenes/**`, every existing `worlds/common/*` file) was left untouched. No
git commits made.

---

## What shipped

### `worlds/common/fort_resident.gd` (`class_name FortResident`) + `fort_resident.tscn`

A tiny homed dreamling: mirrors `dreamling.gd`'s glowing-orb visual
language (same `SphereMesh` + emissive `StandardMaterial3D` shape) at ~60%
scale (radius 0.105 vs. 0.175) and a warmer honey-gold tone
(`Color("F2C879")`, `pillow_fort.gd`'s own `FORT_GLOW_COLOR`) rather than a
wild dreamling's pale `FFF3C4` — a settled dream reads differently from one
still waiting to be found. Carries **none** of `dreamling.gd`'s collection
machinery (no `Area3D`, no orbit-follow, no `release_to()`); it is never
picked up and never leaves. Two states, entirely local, no world-script
wiring beyond being spawned at an assigned `position` before `add_child()`
(this codebase's established D10 ordering):

- **REST** — gentle vertical bob (`BOB_AMPLITUDE=0.09`, half `dreamling.gd`'s
  0.15) plus a slow drift that never wanders more than `DRIFT_RADIUS` (1.5m)
  from its assigned home — unlike a wild dreamling, a resident never homes
  back to an anchor because it never leaves the anchor's neighborhood.
- **GREET** — a player within `GREET_RADIUS` (3m): emission ramps from 2.0
  to 4.5 (dreamling.gd's full brightness), one happy hop on the visual
  (spring-tween, not the position `_update_bob()` already owns every
  frame), and a rate-limited (3s) positional chime — `PositionalAudio.
  play_at("dreamling_chime", ...)`, the exact sfx name
  `AudioManager.play_chime(1)` maps to (the ladder's lowest, fixed rung),
  played positionally since several residents can plausibly greet within
  the same few frames as a player walks the fort. Eases back to REST 4s
  after the last player leaves.

No collision shape (mirrors `dreamkeeper.gd`'s own reasoning): pure
presence, walk-through, can never block a route regardless of placement —
this is also why `tools/props/check_placements.gd` (which only ever queries
`Dreamling` descendants) never needed to know `FortResident` exists.

Receipt (rate-limited): `RESIDENT {"id":..., "event":"greet"}`.

### `data/fort_residents/spots.json` (new)

30 authored positions around the fort's exterior — window-sill-height nooks
along the west/north blanket walls, flanking the two walkable cushions, and
the shoulders of each world's own door — each tagged `"world"` with its
preferred group: 10 `bramble` (clustered west/south, near the umber
`BrambleDoor` at `(0,0,-9.45)`), 10 `marmalade` (east, near the orange door
at `(9.5,0,-2.0)`), 10 `wisp` (west-of-center, near the silver door at
`(-9.5,0,-2.0)`). Every position was checked programmatically against the
fort's own footprint, both cushions' collision spheres, Callie's cushion,
every existing dressing prop, all 8 fence posts, and all three door trigger
boxes/approach corridors (`BrambleDoorTrigger`/`MarmaladeDoorTrigger`/
`WispDoorTrigger` + their approach strips) — nothing sits inside a solid
box or closer than a documented buffer to a real obstacle (see the
validator script logic recorded below; not committed, scratch-only).

### `worlds/pillow_fort/pillow_fort.gd` — `_build_fort_residents()`

Called from `_ready()` after `_build_dressing()`. Loads `spots.json`, then
for every world already in `GameState.dreamlings` (sorted world ids, sorted
dream ids within each — deterministic across runs against the same save),
spawns one `FortResident` per already-returned dream (`GameState.
returned_ids(world_id)`) up to `FORT_RESIDENT_CAP = 30`. `_claim_spot()`
picks the next free spot tagged for that dream's world; if that group is
exhausted (or untagged), it falls back to any free spot — "overflow goes
anywhere free" per the brief. Also connects `GameState.dream_returned` →
`_spawn_resident_for()` directly (no explicit disconnect needed — this node
is `queue_free()`d on world switch, the same established convention as
`dreamkeeper.gd`'s own `_ready()`), so a dream returned *while this fort
instance happens to be loaded* spawns its resident immediately, matching
`_build_fort_growth()`'s "the fort remembers" framing. Each spawn — initial
batch or live update alike — prints one receipt:
`FORT_RESIDENT_SPAWNED {"world":..., "id":..., "pos":[x,y,z],
"spot_world_tag":...}`.

### `tools/harness/scripts/fort_population.json` (new)

See "Receipts" below for what it proves and exactly how to run it —
including the required save-seeding step, since the harness's JSON
playback format has no "call a GameState method" action (checked
`tools/harness/harness.gd`, out of this pass's territory to extend).

---

## (a) Import pass

```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path .
```
Clean: `FortResident` registers as a global class (`update_scripts_classes`
step lists it alongside `Bramble`/`PillowFort`/`RolloverSequence`), no
compile errors, no missing-dependency warnings.

## (b) `check_placements` — still 4/4 green, `pillow_fort` + `bramble`

```
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd
```
```
PLACEMENT_NOTE pillow_fort has zero dreamlings (nothing to check)
PLACEMENT {"world":"bramble","id":"d10",...,"verdict":"PASS"}   (and d01-d09, all PASS)
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort","bramble"]}
```
Expected and correct: this tool only ever queries `Dreamling` descendants
(duck-typed on script path, see its own header), and `FortResident` is
deliberately not one — a resident can never fail a placement check because
it has no collision to embed in and no ground-gap contract to violate.

## (c) Population wiring — hand-seeded save, direct `pillow_fort` boot

Since the harness JSON format has no "seed GameState" action, and since a
*live* teleport+collect+return round trip through `bramble` was blocked
this session (see UNVERIFIED below), the population wiring itself was
verified the way the brief's own fallback describes: write `user://
save.json` directly (the exact schema `SaveManager._apply_to_game_state()`
reads), boot straight into `pillow_fort`, and read the receipts.

**Gotcha #10 discipline** — the real save was backed up, a seed installed,
the seed run, then the real save restored, every time:
```
$SAVE = "$env:APPDATA\Godot\app_userdata\THE BIG NAP\save.json"
cp $SAVE  <scratch>\save_backup_original.json      # back up
cp <seed> $SAVE                                     # install seed
...run...
cp <scratch>\save_backup_original.json  $SAVE       # restore
```
The seed (`worlds.<id>.returned`, six dreams across all three worlds, to
prove cross-world grouping and the cap/overflow logic in one pass):
```json
{
	"version": 1, "total_dreams": 6, "fort_stage": 2,
	"worlds": {
		"bramble":   {"collected": ["d01","d02","d03"], "completed": false, "returned": ["d01","d02","d03"]},
		"marmalade": {"collected": ["d01"],              "completed": false, "returned": ["d01"]},
		"wisp":      {"collected": ["d01","d02"],         "completed": false, "returned": ["d01","d02"]}
	},
	"settings": {"music_volume":1.0,"sfx_volume":1.0,"voice_mode":"moonsong+tts","camera_manual":false,"camera_sensitivity":1.0}
}
```
```
D:\Tools\godot\godot_console.exe --headless --fixed-fps 60 --path . -- \
  --skipmenu --world=pillow_fort --pads=1 --quitafter=5
```
Receipts — exactly six, correctly grouped, correctly positioned, in the
deterministic sorted order (`bramble` before `marmalade` before `wisp`;
`d01` before `d02` before `d03` within each):
```
FORT_RESIDENT_SPAWNED {"id":"d01","pos":[-2.3,0.5,-4.6],"spot_world_tag":"bramble","world":"bramble"}
FORT_RESIDENT_SPAWNED {"id":"d02","pos":[-3.2,0.5,-5.2],"spot_world_tag":"bramble","world":"bramble"}
FORT_RESIDENT_SPAWNED {"id":"d03","pos":[-3.6,0.5,-6.2],"spot_world_tag":"bramble","world":"bramble"}
FORT_RESIDENT_SPAWNED {"id":"d01","pos":[4.5,0.5,2.0],"spot_world_tag":"marmalade","world":"marmalade"}
FORT_RESIDENT_SPAWNED {"id":"d01","pos":[-4.5,0.5,2.0],"spot_world_tag":"wisp","world":"wisp"}
FORT_RESIDENT_SPAWNED {"id":"d02","pos":[-5.5,0.5,1.0],"spot_world_tag":"wisp","world":"wisp"}
WORLD_READY {"id":"pillow_fort","objectives":0}
```
All three `bramble` residents landed at their group's first three spots
(clustered south-west, near the umber door); `marmalade`'s single resident
at its group's first spot (east); `wisp`'s two at its group's first two
spots (west-of-center) — the fort is visibly a map of where the kindness
came from, as designed.

## (d) Greet property — `tools/harness/scripts/fort_population.json`, `--pads=1`

Same seeded save, `pillow_fort` boot, script walks Pip west then south along
the fort's flank (camera-relative movement, `core/movement/player_body.gd`
`_camera_relative_dir` — confirmed via `--poslog=20` before finalizing the
walk vectors, since pillow_fort's spawn/camera convention needed empirical
confirmation same as every other route-authoring script in this repo):
```
D:\Tools\godot\godot_console.exe --headless --fixed-fps 60 --path . -- \
  --skipmenu --world=pillow_fort --pads=1 \
  --script=tools/harness/scripts/fort_population.json --quitafter=8
```
Four or five distinct greets fired (five in the windowed run tied to the
stills below — d01/d02/d03 of bramble's own three, plus both of wisp's —
four in a separate headless timing pass; bramble's d01 sits at the very
edge of `GREET_RADIUS` from Pip's settled rest spot and crosses it or not
by a hair depending on exact per-run physics settle, see the windowed log)
as Pip's walked path crossed within 3m of each resident (two different
worlds' `d02`s distinguished correctly by their different `pos`/
`spot_world_tag`, confirming the receipt's `id` is per-dream not globally
unique — expected, documented behavior since dream ids repeat across
worlds):
```
RESIDENT {"event":"greet","id":"d01"}   -- wisp's d01 (-4.5,0.5,2.0), Pip passing x≈-3.7..-2.3, z=3.0
RESIDENT {"event":"greet","id":"d02"}   -- wisp's d02 (-5.5,0.5,1.0), Pip passing x≈-3.7, z=3.0
RESIDENT {"event":"greet","id":"d02"}   -- bramble's d02 (-3.2,0.5,-5.2), Pip approaching from the north
RESIDENT {"event":"greet","id":"d03"}   -- bramble's d03 (-3.6,0.5,-6.2), Pip continuing south
RESIDENT {"event":"greet","id":"d01"}   -- bramble's d01 (-2.3,0.5,-4.6), windowed run only (edge-of-radius case above)
```
(Key order in the printed JSON is `event` before `id` — Godot's
`JSON.stringify` on a `Dictionary` literal, alphabetized; identical to every
other receipt in this codebase, e.g. `DREAMKEEPER {"event":"wake","id":...}`
printed the same way from the exact same `{"id":..., "event":...}` literal
shape in `dreamkeeper.gd`. Not a bug, not a deviation from the brief's
`RESIDENT {"id","event":"greet"}` shape.)

## (e) Stills — `evidence/stills/m3_hub/`

Same script, windowed (`--write-movie`-style setup, no `--headless`,
Movie Maker/screenshot requirement per `tools/harness/README.md`):
```
D:\Tools\godot\godot_console.exe --path . --fixed-fps 60 --resolution 1280x720 -- \
  --skipmenu --world=pillow_fort --pads=1 \
  --script=tools/harness/scripts/fort_population.json \
  --shots=40,150,270,340 --outdir=evidence/stills/m3_hub --quitafter=9
```
- `shot_40.png` — the fort moments after boot: six warm honey-gold orbs
  visible around the west/south flank and east door, before Pip has moved.
- `shot_150.png` — mid-walk, Pip near the wisp cluster (greets already
  fired).
- `shot_270.png` — Pip approaching the bramble cluster near the umber door.
- `shot_340.png` — Pip settled at rest beside the bramble cluster.

## (f) `finale_home.json` — still passes on the `pillow_fort` side

```
D:\Tools\godot\godot_console.exe --headless --fixed-fps 60 --path . -- \
  --skipmenu --world=pillow_fort --pads=2 \
  --script=tools/harness/scripts/finale_home.json --quitafter=30
```
`CALLIE_COUNT`, `CALLIE {"state":"napping"}`, `WORLD_READY {"id":"pillow_
fort",...}`, `CALLIE {"seat":1,"state":"carried"}`, `DOOR {"to":"bramble"}`
all fire exactly as before this pass — confirming `_build_fort_residents()`
does not disturb `pillow_fort`'s existing boot sequence, Callie pickup, or
the door-exit flow. (The script's *bramble*-side expectations — `WORLD_
READY bramble`, `collected d01`, `collected d02` — do not fire this
session; see UNVERIFIED, this is not caused by this pass.)

---

## UNVERIFIED

- **The real teleport+collect+return round trip through `bramble` (the
  brief's stated first-choice verification method) could not be run this
  session.** `git status` shows `worlds/bramble/bramble.gd` as modified
  (uncommitted) by a concurrent agent's in-progress D25 "Mountain is the
  Bear" pass. Reading that diff: a `super._ready()` call was left
  **after a `return mesh` statement inside `_dressing_cone()`** — dead,
  unreachable code — meaning the real `_ready()` (which starts at line 126
  and never itself calls `super._ready()`) never invokes `WorldBase._ready()`,
  so `_wire_dreamlings()` never runs for `bramble` at all right now. Proof:
  `WORLD_READY {"id":"bramble",...}` never printed on any boot this
  session (it should, per every other world and per `world_base.gd`'s own
  `_ready()`), and `save_corruption_collect.json` — an existing,
  already-committed, previously-verified script (`docs/verify/
  properties-VERIFY.md` §P4 shows it working: `EVT {"id":"d01","t":62,
  "type":"dreamling_collected","world_id":"bramble"}`) — produces **zero**
  collection receipts when re-run today under identical conditions.
  `worlds/bramble/bramble.gd` is outside this pass's territory
  (`FORBIDDEN: everything else`); not touched, not fixed. Once that stray
  line is corrected, `tools/harness/scripts/fort_population.json`'s
  documented alternative form (teleport onto bramble's d01/d02, carry to
  the ear `DreamDoor` exactly as `gate2_return.json` already proves works,
  exit through `HomeDoor` back to `pillow_fort`) is written correctly
  against the contract and should work unmodified — this was the
  approach attempted first, before the blocker was found and this doc's
  seeded-save method was substituted.
- **The live-update path (`GameState.dream_returned` firing while
  `pillow_fort` is the *currently loaded* scene) was not exercised by an
  actual live boot.** Code-reviewed correct and structurally identical to
  `dreamkeeper.gd`'s own already-proven `GameState.dream_returned.
  connect(_on_dream_returned)` live-cheer wiring, but under the current
  four-world structure a dream can only ever be returned while its *own*
  world's `DreamDoor` is loaded (`bramble`/`marmalade`/`wisp`), never while
  `pillow_fort` itself is the active scene — so there is no reachable
  in-game moment to observe this specific path firing today. This mirrors
  `_build_fort_growth()`'s own existing stage-growth pattern, which is
  likewise build-time-only ("so it's there when you come home") rather
  than truly live; the hook is there, cheap, and correct for if/when a
  future world ever changes that.
- Stills were captured against the hand-seeded save described above, not a
  save produced by real play (per the two points above) — visually
  representative of the shipped system, not a real-playthrough artifact.
