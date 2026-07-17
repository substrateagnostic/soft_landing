# MARMALADE GIANT — VERIFICATION (2026-07-17)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
**served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic), running as
the Marmalade giant/M3 build agent inside a Claude Code session.

Scope: ROADMAP.md M3 — Marmalade gets the giant treatment. A real plush-cat
model becomes the sleeping giant the village nestles against, and the world
gains its signature set piece: THE STRETCH (10/10 dreams → she stretches,
the rooftops shift like plates, opening a new route to a hidden nook).
Territory: `worlds/marmalade/**`, `data/missions/marmalade.json`,
`data/dreamkeepers/marmalade.json`, `tools/harness/scripts/marmalade_*.json`,
this file, `evidence/stills/m3_marmalade/**`. No other files touched
(`data/missions/marmalade.json`/`data/dreamkeepers/marmalade.json` were not
edited — nothing in this pass needed to). No commits made (director
integrates).

---

## What shipped

**The cat over the village (`worlds/marmalade/marmalade.gd
_build_cat_giant()`, replaces the retired `_build_cat_silhouette()`).** The
old visual-only `CatSilhouette` sphere is gone; `CatGiantAnchor` now holds a
`ModelSlot` pointed at `assets/models/meshy/generated/marmalade_cat.glb` (a
curled sleeping plush tabby, already generated + refined this session —
`tools/meshy/forge_report.json` id `marmalade_cat`, status `ok`, credits
30). Anchored at the exact XZ the old silhouette proved out
(`(-34, 0, 0)`, footprint `x:-43..-25`, already hand-verified clear of
every thermal/roof/step/shelf **base** position — see
`docs/verify/world-marmalade-VERIFY.md` (e)), scaled to `target_height=18`
(village-dwarfing: ~7x the ~2.6m house peak). The grey-box fallback
(`Primitive`, a sphere) keeps the D10 contract alive if the GLB is ever
missing. Shadow-casting is turned OFF on the primitive AND (recursively,
once the GLB swaps in synchronously inside the same function call) on the
real model — the exact D22 lesson this file's own header already documents
for the old silhouette, reapplied to the new asset. A subtle always-on
breathing sine (`_process()` in `marmalade.gd`, `±1.5%` y-scale, 6s period,
matching `worlds/bramble/breathing_chest.gd`'s `_rest + sin(t*TAU/period)*
amplitude` convention) runs on `CatGiantAnchor`, suppressed while
`StretchSequence.playing` is true so the two never fight over the same
scale property.

**Soft collision blocker (`_build_cat_collision_blocker()`).** A single
`SphereShape3D` (`CAT_COLLISION_RADIUS=5.5`) so players can't walk inside
her — generous, not mesh-hugging, matching `bramble.gd`'s own
torso-capsule-blocker convention. **Deliberately NOT the same geometry as
the old silhouette** (`(-34,6,0)` r9): a first pass reused that exact
sphere and `tools/props/check_placements.gd` immediately caught d07
(rides the purr thermal's TOP, ~`(-30,5.6,-6)`) FAILing —
`"inside_solid":true` — because the old silhouette's clearance was only
ever checked against thermal/roof **base** positions, never a dreamling's
actual raised pickup point. Re-centered/shrunk to `(-37,5,0)` r5.5,
verified clear by hand (3D point-to-nearest-surface distance) of d07
(3.7m), both purr-thermal columns (>2.1m), and the nearest village houses
(>0.9m). Re-running `check_placements.gd --world=marmalade` after the fix:
all 10/10 PASS again (see Receipts).

**THE STRETCH (`worlds/marmalade/stretch_sequence.gd`, new,
`class_name StretchSequence`).** Mirrors
`worlds/bramble/rollover_sequence.gd`'s proven architecture — DUPLICATED,
not imported (bramble is read-only territory tonight; `purr_thermal.gd`
already set the "copy across world territories" precedent). Trigger:
`GameState.world_completed("marmalade")`, once per save, falls out of the
same existing signal WorldBase already fires at 10/10 — no new completion
logic needed. `--stretch` (Harness flag) force-arms it ~3s after load,
dev/capture only. Safety: every connected player is bubble-lifted
(`core/rescue/bubble_effect.gd`) to the village square BEFORE anything
moves — the four rooftop plates that relocate (`RoofB0-3`) are plain
`StaticBody3D`, not `AnimatableBody3D`, so nothing carries a rider through
the tween. The new nook's ground goes solid FIRST, before any camera/tween
work — the same "never gate new ground behind the full animation length"
lesson `rollover_sequence.gd`'s own header already documents.

The plush cat is a **static mesh** (M3 brief: quadruped, Meshy can't rig),
so the stretch itself is pure `Node3D` transform choreography on
`CatGiantAnchor`: rise (lift 0.6m + pitch -8°, 2s) → arch (scale
`(0.96, 1.08, 0.96)`, 3s) → hold (1s) → resettle to the exact rest
transform (2s) — **8.0s total**, matching the brief. Concurrently
(fire-and-forget, 6s — always shorter than the cat's 8s), `RoofB0-3` tween
from their original `CLUSTER_B` positions to a new rising "chimney-hop"
chain (step vector `(2.6, 2.0, 2.0)` off `SHELF_POSITION`, the card's own
tail-bridge/flank-steps convergence point) ending at a new hidden
`AtticNook` platform (built once at `_ready()`, hidden + collision
disabled, revealed by flipping visibility/collision — bramble's FarMeadow
"toggle, never rebuild" convention). Horizontal gap per hop =
`sqrt(2.6²+2.0²) = 3.28m`, under the 3.5m stick+jump floor law. The nook
carries `lantern` + `cushion` + `moth_small` (all three already existed on
disk — `tools/meshy/manifest.json` target heights 0.5/0.4/0.25 — no new
Meshy generation needed for this deliverable). Letterboxed cine camera:
wide (cat over village) → drift along her body → push to the newly-open
route → push to the nook, ~21s total. Persistence:
`_apply_already_open_state()` — on a revisit after a prior session already
completed the world, the four plates snap straight to their new positions,
the nook is immediately visible/solid, and the cat rests at her exact
sleep transform (she resettles every time; only the permanent
world-geometry change persists — same "the world remembers the
transformation, not the animation" pattern as bramble's rollover).

**Camera hints for the new route + nook.** `StretchRouteHint` (framing the
climb, yaw -60°) and `StretchNookHint` (framing the nook itself) — both
built hidden/disabled alongside the nook geometry, revealed at the same
moment.

---

## Bug found + fixed during this pass: `CollisionShape3D` lookup by name

`marmalade.gd`'s platform helpers (`_add_box_platform` etc.) never set an
explicit `.name` on a `CollisionShape3D` child, and `add_child()`'s
`force_readable_name` parameter defaults to `false` — Godot assigns an
internal auto-generated name (e.g. `@CollisionShape3D@123`) to any unnamed
node rather than the literal string `"CollisionShape3D"`. A first version
of `StretchSequence._index_plates()` looked up each plate's shape via
`body.get_node_or_null("CollisionShape3D")`, which silently returned
`null` for all four plates (confirmed live via a temporary debug print of
`_world.get_children()` — `RoofB0`/`RoofB0Body` were present and correctly
named; the shape simply wasn't reachable by that literal string). Fixed by
finding the shape **by type** instead (`_find_collision_shape()`, walks
`body.get_children()` for the first `CollisionShape3D`), matching this
codebase's other type-walk helpers (e.g. `bramble.gd`'s
`_find_first_mesh`). General lesson for any future world script that reads
a sibling world's platform collision shape by name: don't — walk by type.

## Bug found + fixed during harness-script authoring: the co-op frustum leash

The first `tools/harness/scripts/marmalade_stretch.json` draft teleported
only seat 1 across the new plate chain, leaving seat 2 stationary at the
village square (~85-90m away). `core/coop/seat_manager.gd`'s frustum leash
(`CameraRig.leash_broken` → `SeatManager` bubble-warps the stray player
back beside their partner) fired mid-hold, snapping seat 1's `PLAYER_POS`
back toward spawn — caught live in the poslog (a "solid landing" trail
that suddenly reversed direction). `core/**` is out of this pass's
territory to touch, so the script now moves **both** seats together at
each waypoint (seat 2 offset — not a fix to core, a script-authoring
choice matching how a real two-player session would actually explore
together). A second live bug in the same fix: the first paired-teleport
attempt used a +1.6m Z offset for seat 2 (copied from
`StretchSequence.BUBBLE_LANDING_SPACING`), which walked seat 2 clean off
the edge of each 2.4m-square `RoofB` plate (`marmalade.gd ROOF_SIZE`) —
confirmed by a falling `PLAYER_POS` trail (`y` dropping from ~12 to ~0.4
across four ticks). Reduced to +0.6m for the four small plates (kept
+1.6m only at the 4.5m-square nook, which has room). Final run: all five
waypoints hold for both seats, zero `RESCUE`, one harmless in-place `WARP`
nudge at the very last (nook) landing that settles both seats onto the
platform within the same frame — see Receipts.

---

## Receipts

**Import pass:**
```
godot_console.exe --headless --editor --import --quit --path .
```
Exit code `0`. `Marmalade`, `StretchSequence` (and `Bramble`, from the
sibling agent's concurrent work) all register cleanly as global classes.
Zero script errors, both before and after the final doc-comment edit.

**Headless boot:**
```
godot_console.exe --headless --path . -- --skipmenu --world=marmalade --quitafter=5
```
```
WORLD_READY {"id":"marmalade","objectives":10}
HUD_READY {"pips":10,"world":"marmalade"}
MOON_SAID {"key":"new_area", ...}
EVT {"seat":1,"t":8,"type":"landed"}
EVT {"seat":2,"t":10,"type":"landed"}
```
No script errors or warnings (after the `CollisionShape3D` lookup fix
above — the pre-fix run printed four `push_warning` lines for
RoofB0-3, now silent).

**Placements, ALL worlds:**
```
check_placements.gd                    → PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort","bramble"]}
check_placements.gd -- --world=marmalade → PLACEMENT_SUMMARY {"any_fail":false,"worlds":["marmalade"]}
check_placements.gd -- --world=wisp      → PLACEMENT_SUMMARY {"any_fail":false,"worlds":["wisp"]}
```
Marmalade's 10/10: `d01`-`d05`, `d08`-`d10` ground_gap 0.18-0.62m;
`d06`/`d07` (moving-platform exemption, pre-existing) PASS. **d07 FAILed
once** (`"inside_solid":true`, distance from the old collision-blocker
geometry ~7.2m into a 9m-radius sphere) before the collision-blocker fix
above; re-verified PASS after.

**Missions, ALL worlds with mission data:**
```
check_missions.gd → MISSION_SUMMARY {"any_fail":false,"worlds":["bramble","wisp","marmalade"]}
```
`data/missions/marmalade.json` untouched — `d01`(race)/`d09`(shy) both
PASS, unaffected by this pass (neither pins to a moved plate).

**`finale_marmalade.json` (existing script, unmoved):**
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=marmalade --pads=2 --script=tools/harness/scripts/finale_marmalade.json --quitafter=18
```
`WORLD_READY {"id":"marmalade","objectives":10}`, zero errors/RESCUE —
confirms the existing village-walk atmosphere script is unaffected by the
giant/collision-blocker/stretch changes.

**`tools/harness/scripts/marmalade_stretch.json` (new):**
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=marmalade --pads=2 --stretch --script=tools/harness/scripts/marmalade_stretch.json --poslog=30 --quitafter=40 --outdir=evidence/_scratch/marmalade_stretch_final3
```
Full phase order, exactly as designed:
```
STRETCH {"forced":true,"phase":"start"}
STRETCH {"phase":"nook_revealed"}
STRETCH {"phase":"plates_shifting"}
STRETCH {"phase":"arch"}
STRETCH {"phase":"plates_shifted"}
STRETCH {"phase":"resettle"}
STRETCH {"phase":"route_open"}
STRETCH {"forced":true,"phase":"end"}
```
Both seats bubble-lift to the village square (~`(-60/-58.6, 0.45, 4.0)`)
and hold through the whole choreography — zero `RESCUE` lines (grep count
`0` against the literal `"RESCUE` receipt prefix). PHASE 2
(teleport-assisted, ~22.5s in, same allowance `bramble_ascent.json`'s
Phase 2 used): both seats teleport onto `RoofB0_NEW (20.6,11.6,5.0)` →
`RoofB1_NEW (23.2,13.6,7.0)` → `RoofB2_NEW (25.8,15.6,9.0)` →
`RoofB3_NEW (28.4,17.6,11.0)` → `AtticNook (31.0,19.6,13.0)` in turn, each
pair holding 3s. Every landing holds rock-solid (e.g. seat 1 at
`RoofB2_NEW`: `y=16.3` teleported → `y=16.25` settled → unchanged for the
full 3s hold). One `WARP {"seat":1}` fires at the very last (nook)
landing — a harmless in-place side-nudge (`seat_manager.gd`'s own leash
recovery, landing both seats a few meters apart at `(32.5,20.05,14.6)`/
`(31.0,20.03,14.6)`, both still on the 4.5m nook platform) — confirmed by
the trailing `PLAYER_POS` trail holding steady there for the remaining 5s
of the run. Full event log:
`evidence/_scratch/marmalade_stretch_final3/events.jsonl`.

**Persistence (`_apply_already_open_state()`) — targeted probe:**
`evidence/_scratch/marmalade_persist_check.gd` (throwaway, deleted after
use — territory-legal per the brief's `evidence/_scratch/` exception)
force-set `GameState.dreamlings["marmalade"]["completed"]=true` BEFORE
instantiating `marmalade.tscn`, then read back world state directly:
```
PERSIST_CHECK {"cat_scale":[1.0,1.0,1.0],"nook_visible":true,"roof_b0_pos":[20.6000003814697,11.6000003814697,5.0]}
```
`RoofB0` is immediately at its post-stretch target, `AtticNook` is
visible, and `CatGiantAnchor` rests at scale `(1,1,1)` (she resettles to
sleep every time — only the geometry change persists) — exactly the
intended revisit behavior, with no full 10-dreamling playthrough needed to
prove it.

---

## Stills — the "would a child know?" verdict

- `evidence/stills/m3_marmalade/establishing/shot_240.png` — close spawn
  camera (no `--stretch`): two paw/ear shapes break the roofline right at
  the top of frame, warm marmalade fur clearly readable, paired with the
  Moon's own line ("Here we are. Quiet now — someone big is sleeping
  here."). Reads as "something huge and soft is right there," though
  tightly cropped by the spawn camera's fixed downward pitch (documented
  pre-existing limitation, `world-marmalade-VERIFY.md` (e)).
- `evidence/stills/m3_marmalade/stretch/shot_200.png` — **the real "cat
  over village" wide shot**, from `StretchSequence`'s own `CINE_WIDE_POS`:
  the full curled cat draped over the hill, ten tiny lamplit houses
  clustered at her paws, moon and stars behind her, the rooftop/ridge/ear
  chain trailing off into the distance. Unambiguous — a child would
  absolutely read this as "a giant cat asleep over the village."
- `evidence/stills/m3_marmalade/stretch/shot_340.png` /
  `shot_400.png` — mid-choreography: her striped tail visible in the near
  corner of frame while the camera drifts, the rooftop-plate chain already
  climbing past the ridge/ear mounds toward the (not-yet-visible) nook.
- `evidence/stills/m3_marmalade/stretch/shot_880.png` — route open: the
  relocated plate chain climbing over the ridge/head mounds, the new
  terracotta nook platform visible top-right.
- `evidence/stills/m3_marmalade/stretch/shot_1150.png` — the nook itself:
  lantern post, blush cushion, a tiny moth, the plate chain trailing back
  toward her curled silhouette in the background. Reads clearly as "a
  cozy hidden spot," per the brief.

**Verdict: the establishing read is strong.** `shot_200` in particular is
an honest, unambiguous "giant cat over a village" image — better than the
tight spawn-camera crop, which stays a real, named limitation (see
UNVERIFIED).

---

## UNVERIFIED (honest list)

- **The spawn establishing shot (no `--stretch`) is still tightly
  cropped** — the camera rig's fixed downward pitch (`core/**`, out of
  territory) means the FIRST thing a player sees on a fresh boot is two
  paw/ear shapes at the top of frame, not the full "cat over village" read
  `StretchSequence`'s own cine camera achieves. This is a pre-existing
  limitation (documented in `world-marmalade-VERIFY.md`'s own (e)
  section for the old silhouette) that a real GLB doesn't fix on its own —
  fixing it for real would mean a per-world camera pitch hint, which is
  `core/**` territory.
- **Co-op / solo controller feel for the STRETCH itself was not tested
  with real jump/movement input** — verified via the forced `--stretch`
  flag (no player input needed) plus teleport-assisted landing proofs
  (matching `bramble_ascent.json`'s own precedent for the exact same kind
  of claim), not a scripted live walk/jump traversal of the new chimney-hop
  chain. The 3.28m hop math is computed/checked by hand, not jump-arc
  tested.
- **The rock-tint/disguise treatment bramble's mountain got does not apply
  here** — Marmalade's giant was never meant to be hidden (the world card
  is "an enormous cat asleep across a hillside," visible from the start),
  so this is by design, not a gap — flagging only so a future reader
  doesn't wonder why it's missing.
- **60fps sustained perf**: not instrumented for this pass (same
  pre-existing gap flagged for every other world in
  `docs/verify/gate2-slice-VERIFY.md`).
- **Audio**: `STRETCH` reuses `bear_rollover_rumble`
  (`AudioManager.play_sfx`, fails soft) as a placeholder — no dedicated
  stretch/purr-swell SFX exists yet.
- I did not re-run the full `docs/verify/*-VERIFY.md` regression suite for
  `pillow_fort`/`bramble`/`wisp` beyond `check_placements`/
  `check_missions` (both worlds outside this pass's territory tonight;
  `bramble` in particular was under active concurrent edit by another
  agent — its placements/missions checks came back green at the moment
  this pass ran them, but that's a snapshot, not an exhaustive claim about
  the other agent's own finished work).

---

## Files touched (≤12 lines)

- `worlds/marmalade/marmalade.gd` — retired `_build_cat_silhouette()` →
  `_build_cat_giant()` (real GLB via ModelSlot) + collision blocker +
  ambient breathing `_process()` + `_build_stretch()` wiring.
- `worlds/marmalade/stretch_sequence.gd` — new (THE STRETCH keystone).
- `tools/harness/scripts/marmalade_stretch.json` — new.
- `docs/verify/marmalade-giant-VERIFY.md` — this file.
- `evidence/stills/m3_marmalade/**`, `evidence/_scratch/marmalade_stretch_final3/**` — receipts.
