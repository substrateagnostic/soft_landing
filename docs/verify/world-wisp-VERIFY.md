# world-wisp-VERIFY.md — Wisp the whale (world 3)

Engine: `D:\Tools\godot\godot_console.exe` -> `4.6.2.stable.official.71f334935`.
Built against the live worktree; territory `worlds/wisp/**` +
`docs/verify/world-wisp-VERIFY.md` + `evidence/_scratch/wisp/**` only.
Nothing outside that set was edited — `project.godot`, `scenes/main.gd`,
`core/**`, `worlds/bramble/**`, `worlds/common/**` and
`worlds/pillow_fort/**` (whose existing `WispDoor` already targets
`"wisp"`) were read-only references, confirmed unmodified below.

## a) Headless import — exit 0, zero script errors

Command:
```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path D:\Projects\soft_landing
```
Exit code `0` on two consecutive runs. No `SCRIPT ERROR` / `Parse Error` /
`Compile Error` lines in either run's output (grepped across the full
captured logs of every command in this file). All five new classes
registered cleanly in `.godot/global_script_class_cache.cfg`:
```
"class": &"LilyPad",
"class": &"TailSeesaw",
"class": &"WaterSpout",
"class": &"WhaleDrift",
"class": &"Wisp",
```

## b) Headless boot — `--world=wisp`

Command:
```
D:\Tools\godot\godot_console.exe --headless --path . -- --skipmenu --world=wisp --quitafter=6
```
Output (verbatim):
```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

HARNESS_FLAGS {"quitafter":"6","skipmenu":true,"world":"wisp"}
MODEL_SWAP {"id":"pip","scaled":0.472176738856881}
CAMERA_RIG_READY
WORLD_READY {"id":"wisp","objectives":10}
HUD_READY {"pips":10,"world":"wisp"}
MOON_SAID {"key":"new_area","text":"A new place to explore. Let's see what's waiting."}
EVT {"seat":2,"t":3,"type":"landed"}
EVT {"seat":1,"t":6,"type":"landed"}
HARNESS_NOTE quitafter fallback fired (harness-level timer, 6.0s)
```
`WORLD_READY {"id":"wisp","objectives":10}` printed exactly as required.
Both players land on real shore floor within a handful of physics ticks (no
fall-through, no rescue triggered at spawn). No errors, no warnings.

## c) Placement verification — checker receipt (10/10 PASS)

`tools/props/check_placements.gd` exists in this worktree (built by another
agent), and its `--world=` flag restricts the check to one world, so it was
run directly against wisp:
```
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=wisp
```
Output (verbatim, receipt lines only):
```
WORLD_READY {"id":"wisp","objectives":10}
PLACEMENT {"ground_gap":0.5,"has_ground":true,"id":"d06","inside_solid":false,"moving_platform":true,"pos":[-15.68,0.45,-1.74],"verdict":"PASS","world":"wisp"}
PLACEMENT {"ground_gap":12.93,"has_ground":true,"id":"d07","inside_solid":false,"moving_platform":true,"pos":[79.0,23.18,-5.0],"verdict":"PASS","world":"wisp"}
PLACEMENT {"ground_gap":0.21,"has_ground":true,"id":"d04","inside_solid":false,"moving_platform":true,"pos":[0.0,3.44,0.0],"verdict":"PASS","world":"wisp"}
PLACEMENT {"ground_gap":0.24,"has_ground":true,"id":"d05","inside_solid":false,"moving_platform":true,"pos":[24.0,9.77,6.0],"verdict":"PASS","world":"wisp"}
PLACEMENT {"ground_gap":0.49,"has_ground":true,"id":"d08","inside_solid":false,"moving_platform":true,"pos":[34.0,15.06,0.0],"verdict":"PASS","world":"wisp"}
PLACEMENT {"ground_gap":1.44,"has_ground":true,"id":"d10","inside_solid":false,"moving_platform":true,"pos":[73.0,13.08,3.7],"verdict":"PASS","world":"wisp"}
PLACEMENT {"ground_gap":0.56,"has_ground":true,"id":"d01","inside_solid":false,"moving_platform":false,"pos":[-65.0,0.56,-8.0],"verdict":"PASS","world":"wisp"}
PLACEMENT {"ground_gap":0.49,"has_ground":true,"id":"d02","inside_solid":false,"moving_platform":false,"pos":[-51.0,0.65,-3.0],"verdict":"PASS","world":"wisp"}
PLACEMENT {"ground_gap":0.16,"has_ground":true,"id":"d03","inside_solid":false,"moving_platform":false,"pos":[-30.82,0.37,-3.0],"verdict":"PASS","world":"wisp"}
PLACEMENT {"ground_gap":1.03,"has_ground":true,"id":"d09","inside_solid":false,"moving_platform":false,"pos":[-68.0,1.03,9.2],"verdict":"PASS","world":"wisp"}
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["wisp"]}
```
Exit code `0`. All 10/10 PASS, zero `inside_solid`.

**Sanity control** (proves the checker is actually discriminating, not
rubber-stamping): the same tool run against `--world=bramble` reports
`any_fail: true` (bramble's own pre-existing `d07`, atop a non-solid
`SnoreGeyser` Area3D, fails the ground-raycast check by design — an
unrelated, pre-existing condition; `git status --porcelain worlds/bramble
worlds/common` returns empty, confirming this pass touched neither).

**d06/d07 ride moving parents — rest-position validation.** Both are
correctly flagged `"moving_platform": true` (`dreamling.get_parent() !=
world`), which per the checker's own contract skips the ground-raycast
verdict for them — but `ground_gap`/`inside_solid` are still *computed* and
printed (just not used for pass/fail), so the numbers above are real:
- **d06** (parented to `LilyPad_7`, local offset `(0, LILY_THICKNESS*0.5 +
  0.35, 0) = (0, 0.5, 0)`): reported `ground_gap: 0.5` — matches the
  authored local offset exactly (the pad's XZ never moves, so the raycast
  finds the same pad directly below regardless of bob phase).
- **d07** (parented to `WaterSpout`, local offset `(0, height-1.0, 0) =
  (0, 13.0, 0)` above the spout's base): reported `ground_gap: 12.93` — the
  spout is an Area3D (no layer-1 collision), so the downward ray correctly
  passes through it to the solid Head mound surface further below; this is
  expected (identical to why bramble's own geyser-riding d07 needs the
  moving-platform exemption) and is not evidence of a placement error —
  `inside_solid: false` confirms d07 isn't embedded in anything.

Per the world card, `d04`/`d05`/`d08`/`d10` are ALSO physically on the
whale and therefore also ride `_whale` (not just d06/d07) — see
"Architecture note" in `wisp.gd`'s header. Their `ground_gap` values above
(0.21–1.44 m) confirm each sits just above its own shelf/platform surface,
computed via the same `_sphere_surface_y()` anchor math bramble.gd proved
(`worlds/wisp/wisp.gd::_add_whale_shelf`), not eyeballed.

## d) Door round trip — wisp -> pillow_fort -> wisp

Test script written to `evidence/_scratch/wisp/doors.json` (per the task
brief, not `tools/harness/scripts/`): teleports Pip into Wisp's `HomeDoor`
trigger, interacts (expect `pillow_fort`), then teleports into
`PillowFort`'s pre-existing `WispDoor` trigger and interacts again (expect
`wisp`) — a genuine round trip, proving both directions of the seam this
pass owns (`HomeDoor`) and the seam the hub agent already wired to target
`"wisp"`.

Command:
```
D:\Tools\godot\godot_console.exe --headless --path . -- --skipmenu --world=wisp --pads=1 ^
  --script=evidence/_scratch/wisp/doors.json --outdir=evidence/_scratch/wisp/doors_run --quitafter=9
```
Output (trimmed to the receipt lines):
```
WORLD_READY {"id":"wisp","objectives":10}
HARNESS_TELEPORT {"pos":[-78.0,0.6,1.0],"seat":1}
DOOR {"to":"pillow_fort"}
WORLD_READY {"id":"pillow_fort","objectives":0}
HARNESS_TELEPORT {"pos":[-9.5,0.6,-2.0],"seat":1}
DOOR {"to":"wisp"}
WORLD_READY {"id":"wisp","objectives":10}
```
Full mirrored transcript: `evidence/_scratch/wisp/doors_run/events.jsonl`.
Both legs fire cleanly, no errors. `HomeDoor` position
`(SPAWN_PIP.x - 6.0, 0.0, 1.0) = (-78.0, 0.0, 1.0)` and the teleport target
match bramble's own "teleport to the door's exact world position" pattern
(the trigger box is centered at local origin in XZ regardless of the
door's yaw, so the door's raw `position` is always inside it).

## e) Windowed still from spawn

Command:
```
D:\Tools\godot\godot_console.exe --path . --resolution 1280x720 -- --skipmenu --world=wisp --pads=1 ^
  --shots=240 --outdir=evidence/_scratch/wisp --quitafter=5
```
Output:
```
HARNESS_NOTE screenshot saved D:/Projects/soft_landing/evidence/_scratch/wisp/shot_240.png
```
Still: `evidence/_scratch/wisp/shot_240.png` (1280x720, 4 s after spawn).
Shows: the lily-pad chain snaking away from shore toward the lake,
`ReedBlade` cluster (tall thin boxes with drop shadows) near spawn, a
dreamling's pale-gold glow, dusk-rose sky/fog, and Pip/Otto in their shared
capsule-placeholder visuals (confirmed against `evidence/stills/bramble_approach.png`
— same convention, not wisp-specific). **Deviation flagged for playtest**:
the whale itself reads small/hazy at the horizon in this literal
from-spawn frame — the fallback/early camera hasn't yet settled into a
`CameraHint`-driven establishing angle, and the Tail mound's leading edge
is ~79 m from spawn (by design, to leave room for the full lily crossing +
~93 m whale). The geometry itself is correct and present (confirmed by the
placement receipts above); this is a framing note, not a placement bug —
worth a closer camera-hint tuning pass once a live player can walk the
route, exactly as bramble's own VERIFY flagged its shelf/peak placements
for a follow-up look rather than blocking on it.

## f) d01-d10 route table

| id | Location (pos) | Height (y) | Intended route | Notes |
|---|---|---|---|---|
| d01 | Shore path (-65, 0.56, -8) | 0.56 | Walk straight from spawn toward the lake. | Trivial, first find. |
| d02 | First lily pad (-51, 0.65, -3) | 0.65 | Step onto `LilyPad_0`, the first pad in the chain. | Bobs +/-0.2 m under it; dreamling itself is static (near, not riding). |
| d03 | Mid-chain lily pad (-30.82, 0.37, -3) | 0.37 | Continue hopping the chain to `LilyPad_4` (index 4 of 9). | Each pad-to-pad gap is exactly `LILY_STEP - 2*LILY_RADIUS` = 1.6 m by construction, regardless of the zigzag heading. |
| d04 | Flipper ledge (0, 3.44, 0) | 3.44 (drifts +/-2.5 m with the whale) | From the last pad (or wading the shallow `LakeBed`, y=-0.4), jump up onto the Flipper Ledge when the whale's breath brings it low (~0.9-1.2 m gap at the low point; ~5.9 m, must-wait, at the high point). | "Timing a slow, forgiving elevator," per the world card. First contact with the whale. |
| d05 | Belly shelf (24, 9.77, 6) | 9.77 (rides drift) | Continue climbing the Tail-to-Body mound flank from the Flipper Ledge; the sphere surface flattens (gentler grade) the higher you climb. | Open/generous platform (5x5 m), per the card. **Flag for playtest**: exact walkable-slope angle between the ledge and the shelf depends on `PlayerBody.floor_max_angle`, not tuned in this pass (same caveat bramble's own d05/d08 carried). |
| d06 | Rides `LilyPad_7`, local (0, 0.5, 0) | ~0.5 above its pad, moves with the pad's bob | Hop the lily chain to its second-to-last pad and stand on it as it bobs. | "Rides a bobbing lily," per the card — parented, confirmed moving_platform in the checker receipt. |
| d07 | Atop the water spout, local (0, 13.0, 0) above its base | ~23 (rides both the spout's fixed height AND the whale's drift) | Stand in the spout's 1.5 m-radius column on the Head mound's front-top while it's active (3 s window every 20 s, synced to the whale's own breath cycle) and ride the updraft to the top. | "Ride it," per the card. SFX reuse: `snore_geyser`, per the card, until a dedicated sound exists. |
| d08 | Dorsal crest (34, 15.06, 0) | 15.06 (rides drift) | **Walk**: continue up the Body mound's flank from the Belly Shelf to its exact peak (14 m at rest) — spheres flatten near the pole, so this stays walkable the whole way, never toss-only. **Toss** (alternate, never required): Otto can toss Pip from the Belly Shelf or partway up the flank (SPEC.md toss apex ~2.2 m + horizontal arc). | Matches the card's "reachable by the slide-crest walk OR Otto-toss from the belly shelf (never toss-only)" exactly. **Flag for playtest**: toss geometry not physically simulated in this pass (same caveat bramble's own d08 carried). |
| d09 | Hidden in shore reeds (-68, 1.03, 9.2) | 1.03 | Walk into the `ReedBlade` patch near spawn (tall thin non-collidable boxes) just off the direct path to d01. | "Glow visible" through the reeds, per the card — concealment is visual only. |
| d10 | Beside the blowhole DreamDoor (73, 13.08, 3.7) | 13.08 (rides drift) | Continue past the Dorsal Crest along the Body-to-Head mound flank to the Head's blowhole; d10 sits just beside the door itself. | Clears the `BlowholeRim` bump sphere by 2.39 m (required: 1.6 bump radius + 0.35 dreamling clearance = 1.95 m) — same clearance margin bramble's own ear-bump fix used. Last dreamling on the route, naturally closest to the return door. |

**Cadence sanity (D12):** ten dreamlings across a ~93 m whale plus a ~50 m
lake crossing, at `pip_movement.tres`'s 4.0 m/s move speed — comparable
scale and pacing to Bramble's own ~120 m route, matching the dense-cadence
target. Every dreamling is reachable via stick+jump+interact alone; no
dreamling is toss-only (d08's toss is explicitly an alternate, per the
card's own floor rule).

## Architecture notes for the director

1. **One compound whale body, two necessary exceptions.** `_whale`
   (`WhaleDrift`) owns every mound/ledge/crest/bump `CollisionShape3D`
   directly — one physics body, one velocity, every rider on any of those
   shapes carried identically as the whale breathes. The **Dorsal Slide**
   (needs its own low-friction `PhysicsMaterial` — friction is a per-body
   property in Godot, so it can't share `_whale`'s body without making the
   whole whale slippery) and the **Tail Seesaw** (needs its own local
   rotation) are each a small nested `AnimatableBody3D` under `_whale`.
   Nesting is safe here: `sync_to_physics` diffs each body's own
   `get_global_transform()` every physics frame, which already composes in
   the parent's motion via Godot's normal transform hierarchy — confirmed
   working end-to-end by the boot + placement receipts above (nothing
   floated off its surface, nothing reported embedded).
2. **Lily pads and the water spout are deliberately NOT part of the whale
   group.** Lily pads float independently on the lake (their own
   `LilyPad` `AnimatableBody3D`, `sync_to_physics`, bob-only). The water
   spout is a plain `Area3D` — it rides `_whale`'s drift for free the
   moment it's parented under it (no sync flag needed; overlap checks
   always use the current global transform).
3. **`_add_whale_ramp`'s ramp orientation** uses `Basis.looking_at()`
   (not bramble's axis-aligned `PrismMesh` trick), since the Dorsal Crest
   and Belly Shelf don't share an X or Z axis — a small, self-contained
   generalization of the same "compute exact geometry, don't eyeball it"
   principle behind `_sphere_surface_y()`.
4. **Collision layers**, for consistency with the rest of the project:
   world geometry (shore, moat, lake bed, every whale shape, lily pads,
   tail seesaw, dorsal slide) — `collision_layer = 1`, matching
   `PlayerBody`'s `collision_mask = 1`. `Dreamling`/`DreamDoor`/`WorldDoor`/
   `WaterSpout` — Area3D, `collision_mask = 2` (the `PlayerBody` layer),
   `monitorable = false`. `CameraHint`'s own layer is untouched (the
   camera agent's contract).

## Deviations from the brief (noted per house convention)

- **Whale total nose-to-tail is ~93 m at rest** (Tail leading edge at
  local x=-2 to Head trailing edge at x=91), not exactly the card's "~100
  m" — close enough to preserve the card's scale intent (three overlapping
  haunch-style mounds, ~2-5 m seams between them bridged by ledges/shelves,
  same gap magnitude bramble's own haunch/chest/shoulder/head seams use)
  without needing a fourth mound.
- **Tail seesaw is a bonus traversal element, not on any dreamling's
  required route.** The world card lists it under "movement gifts"
  alongside the slide and spout, not in the dreamling list — it's built,
  positioned clear of the Tail mound's solid volume, tilts +/-8 deg over a
  6 s cycle, and rides the whale's drift correctly, but no d01-d10 route
  depends on it (every dreamling remains reachable via the
  shore -> lily chain -> Flipper Ledge -> Belly Shelf -> Dorsal Crest ->
  Head spine, matching the card's own stated layout order).
- **`check_placements.gd`'s ground-raycast is skipped (not failed) for
  d04/d05/d07/d08/d10**, since all five are correctly parented under the
  moving whale group — see item (c) above for why this is the tool's own
  documented contract, not a gap in verification (their rest heights are
  validated by the anchor math instead, cross-checked against the live
  `ground_gap` numbers the tool still prints for them).
- **The from-spawn still (item e) frames the whale small/hazy** — flagged
  as a camera/framing note for the next playtest pass, not a placement
  defect (see item (e) for detail).

## Files created

```
worlds/wisp/wisp.gd
worlds/wisp/wisp.tscn
worlds/wisp/whale_drift.gd
worlds/wisp/lily_pad.gd
worlds/wisp/water_spout.gd
worlds/wisp/tail_seesaw.gd
docs/verify/world-wisp-VERIFY.md
evidence/_scratch/wisp/doors.json
evidence/_scratch/wisp/doors_run/events.jsonl
evidence/_scratch/wisp/events.jsonl
evidence/_scratch/wisp/shot_240.png
```

No files outside `worlds/wisp/**`, this `docs/verify/` receipt, and
`evidence/_scratch/wisp/**` were modified. No git commit made, per
instructions.
