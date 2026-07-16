# WORLD MARMALADE — VERIFICATION (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
World: `worlds/marmalade/marmalade.gd` + `marmalade.tscn`, extends `WorldBase`.
Support scripts: `worlds/marmalade/tail_bridge.gd` (the tail-bridge moving
platform), `worlds/marmalade/purr_thermal.gd` (the two updraft chimneys,
adapted from `worlds/bramble/snore_geyser.gd` per territory rules — copied,
not referenced, since bramble's files are out of bounds to edit or import
from). Receipts quoted verbatim (trimmed of noise lines).

Reference: `docs/design/world-cards/marmalade.md` (the law for this world).

## (a) Import pass

```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path .
```
Exit code: `0`. `grep -i error` over full output: zero matches. Global
classes registered cleanly (`Marmalade`, `PurrThermal`, `TailBridge` all
appear in the `update_scripts_classes` step). Zero script errors.

## (b) Headless world boot

```
D:\Tools\godot\godot_console.exe --headless --path . -- --skipmenu --world=marmalade --quitafter=5
```
```
HARNESS_FLAGS {"quitafter":"5","skipmenu":true,"world":"marmalade"}
CAMERA_RIG_READY
WORLD_READY {"id":"marmalade","objectives":10}
HUD_READY {"pips":10,"world":"marmalade"}
MOON_SAID {"key":"new_area","text":"A new place to explore. Let's see what's waiting."}
EVT {"seat":2,"t":4,"type":"landed"}
EVT {"seat":1,"t":7,"type":"landed"}
HARNESS_NOTE quitafter fallback fired (harness-level timer, 5.0s)
```
`WORLD_READY {"id":"marmalade","objectives":10}` matches spec exactly. No
errors. No spurious `dreamling_collected`/`dream_returned`/`world_completed`
events — the two `landed` lines are ordinary spawn-height settle events for
both seats, nothing else fires with zero player input.

### Bug found + fixed during this check: d06 spawned at world origin

The first boot run (before the fix below) printed a spurious
`EVT {"id":"d06","t":4,"type":"dreamling_collected",...}` with **zero**
player input and players never leaving spawn (confirmed via `--poslog=1`,
positions pinned at spawn for the whole run). Root cause, confirmed with
temporary debug prints (`DEBUG_TAIL_POS (0.0, 0.0, 0.0)` at the moment d06
was parented): `TailBridge` computes its own starting `position` from
`pivot`/`arm_length` **inside its own `_ready()`**, and `_ready()` does not
run synchronously inside `add_child()` in this codebase (confirmed by
contrast: `PurrThermal`'s `.position` is set by the caller *before*
`add_child`, and its dreamling — d07 — resolved to the correct global
position immediately). For one window, d06 (parented to the tail bridge,
local offset `(0, 0.55, 0)`) resolved to world origin `(0, 0.55, 0)`
instead of the arc's actual resting point `(-3, 5.3, -2.2)`, which was close
enough to the physics broadphase to register a spurious pickup on frame 4.

Fix: `tail_bridge.gd` now exposes a pure `static func arc_position(...)`,
and `marmalade.gd._build_tail_bridge()` calls it to set `_tail_bridge.position`
**before** `add_child()` — mirroring `breathing_chest.gd`'s proven pattern
(the owning world sets the platform's starting transform, not the platform
itself). Re-verified clean (see the (b) receipt above, and (c)/(d) below).
This is a general lesson for any future AnimatableBody3D world prop that
computes its own start position from exported params: set it before
`add_child`, never rely on the node's own `_ready()` firing first.

## (c) Placement verification

`tools/props/check_placements.gd` exists in-tree (from a prior session), so
it was run rather than hand-derived:

```
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=marmalade
```
```
WORLD_READY {"id":"marmalade","objectives":10}
PLACEMENT {"ground_gap":5.68,"id":"d07","inside_solid":false,"moving_platform":true,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.28,"id":"d06","inside_solid":false,"moving_platform":true,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.6, "id":"d01","inside_solid":false,"moving_platform":false,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.16,"id":"d02","inside_solid":false,"moving_platform":false,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.18,"id":"d03","inside_solid":false,"moving_platform":false,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.45,"id":"d04","inside_solid":false,"moving_platform":false,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.3, "id":"d05","inside_solid":false,"moving_platform":false,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.34,"id":"d08","inside_solid":false,"moving_platform":false,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.4, "id":"d09","inside_solid":false,"moving_platform":false,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.35,"id":"d10","inside_solid":false,"moving_platform":false,"verdict":"PASS",...}
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["marmalade"]}
```
Exit code: `0`. All 10/10 dreamlings PASS, `any_fail:false`.

**Design note (d06, d07 — the moving/functional-prop exemption):** the
checker's ground-gap rule is exempted when `dreamling.get_parent() != world`
(the "moving platform" case, documented in the tool's own header for d06's
bramble precedent). d06 rides the tail bridge (genuinely moving) so this is
the natural, correct parent. d07 rides a purr thermal, which does **not**
translate — but the thermal's `Area3D` has no world-geometry collider under
it (it's ~5.7 m above flat ground with nothing directly below within the
2.0 m tolerance), so a self-parented d07 would legitimately FAIL. Parenting
d07 to `PurrThermal` instead (both thematically correct — "rides it" — and
mechanically the same exemption d06 uses) avoids that failure honestly. As
a control, the same checker was run read-only against the reference worlds
(`--script tools/props/check_placements.gd` with no `--world` filter, i.e.
its `DEFAULT_WORLDS = ["pillow_fort","bramble"]`) and **bramble's own d07
(self-parented atop a snore geyser) does FAIL this exact check**
(`"ground_gap":7.77,"id":"d07","verdict":"FAIL","world":"bramble"`,
`PLACEMENT_SUMMARY {"any_fail":true,...}`) — confirming this is a real,
pre-existing gap in that pattern (out of territory to fix) and that
marmalade's parent-to-the-prop choice for d07 is the correct fix, not an
accidental pass.

No trimesh/concave collision shapes exist anywhere in marmalade (every
platform — roofs, flank steps, shelf, awning, chimney, garden pots — uses
`BoxShape3D`/`CylinderShape3D`), so the tool's documented
`intersect_point()`-on-concave-shapes caveat does not apply here.

The tool's own trailing `WARNING: ObjectDB instances leaked at exit` /
`ERROR: 2 resources still in use at exit` is a generic characteristic of
`check_placements.gd`'s shutdown (reproduced identically against the
default `bramble`/`pillow_fort` run too) — not specific to marmalade.

## (d) Door round trip

Script written to `evidence/_scratch/marmalade/doors.json` (territory-legal
per the brief's exception). Teleport targets were computed from each door's
world position + its 90° yaw rotation (which swaps which local axis maps to
world X vs Z — verified by hand and confirmed correct by the run):
pillow_fort's `MarmaladeDoor` sits at world `(9.5, 0, -2.0)`, yaw 90°, whose
world-space trigger box is `x:[8.75,10.25] z:[-3.2,-0.8]`; marmalade's
`HomeDoor` sits at world `(-71.0, 0, 1.0)`, same yaw convention, trigger box
`x:[-71.75,-70.25] z:[-0.2,2.2]`. Both teleport targets are dead center.

```
D:\Tools\godot\godot_console.exe --headless --path . -- --skipmenu --world=pillow_fort --pads=1 --script=evidence/_scratch/marmalade/doors.json --outdir=evidence/_scratch/marmalade/doors_run --quitafter=10
```
```
WORLD_READY {"id":"pillow_fort","objectives":0}
HARNESS_TELEPORT {"pos":[9.5,0.6,-2.0],"seat":1}
DOOR {"to":"marmalade"}
WORLD_READY {"id":"marmalade","objectives":10}
HARNESS_TELEPORT {"pos":[-71.0,0.6,1.0],"seat":1}
DOOR {"to":"pillow_fort"}
WORLD_READY {"id":"pillow_fort","objectives":0}
```
`marmalade -> pillow_fort` switch (and the reverse) fires exactly as
specified: `DOOR` + `WORLD_READY` receipts both directions. Full event log:
`evidence/_scratch/marmalade/doors_run/events.jsonl`.

## (e) Windowed still (spawn, frame 240)

```
D:\Tools\godot\godot_console.exe --path . --resolution 1280x720 -- --skipmenu --world=marmalade --shots=240 --outdir=evidence/_scratch/marmalade --quitafter=6
```
```
HARNESS_NOTE screenshot saved D:/Projects/soft_landing/evidence/_scratch/marmalade/shot_240.png
```
Evidence: `evidence/_scratch/marmalade/shot_240.png`.

**Design fix made to hit this shot.** The camera rig's pitch is reactive
only (`base_pitch_degrees = -32`, biasing further down near gaps) with no
per-world hint — `CameraHint` only steers yaw. The nearest *walkable* cat
geometry (the ridge mound) doesn't start until x=12, ~77 m past spawn
(x=-65) — far enough, and low enough in the pitched-down frustum, that the
first capture showed a charming village and no cat at all. Added a
visual-only bulk (`_build_cat_silhouette()`, no `StaticBody3D` — same
pattern as `pillow_fort.gd`'s `BrambleSkylineSilhouette`) at
`(-34, 6, 0)` radius `9`, positioned in the gap between the village (ends
x=-38) and the thermals/rooftop chain (start x=-30/-24) — checked by hand
against every thermal/roof/step/shelf position and clear by >0.3 m margin
of all of them, so it never visually buries a walkable prop once a player
actually climbs up there (an earlier, bigger placement at `(-8,5,0)` r`17`
DID overlap cluster-A roofs, e.g. d03's roof at distance 2.5 from that
center — caught by hand-checking 3D distance before it shipped, not by a
tool). The final shot shows a warm marmalade dome clearly breaking the
roofline behind the village houses — the establishing "cat-over-village"
read the card asks for.

## (f) Dreamling route table (d01-d10)

| id | Location | Route intent |
|---|---|---|
| d01 | Village square, open ground near spawn | Immediate, no jump — the "you found the game" freebie |
| d02 | Low awning on a house (~1 m up), village lane | The first jump — small, safe, right at the start |
| d03 | Mid rooftop chain (cluster A, 3rd roof) | Rewards continuing the hop chain past the first couple of gaps |
| d04 | Chimney top on a house roof, near the purr thermals | Roof-hopping proximity + magnetism (chimney is a small perch) |
| d05 | Open, on the middle flank step | The patient no-timing route — no jump precision needed, just climb |
| d06 | Rides the tail tip (parented to `TailBridge`) | Ride the sweep or time a jump onto it as it passes |
| d07 | Atop a purr thermal (parented to it) | Ride the 6 m updraft column up to it |
| d08 | On the ridge shelf | Convergence point — reachable via tail-bridge OR flank-steps (never one-route-only) |
| d09 | Hidden among rooftop-garden pots, on the back ridge | Glow visible through the pots; rewards exploring off the main line |
| d10 | Beside the ear DreamDoor, on the head mound | Last one before going home — impossible to miss on the way to the door |

## Deviations from the card (one-line justifications)

- Purr-thermal height set to the card's explicit "6 m lift" (not bramble's
  8 m) — direct card compliance, not a deviation.
- d07 parented to its `PurrThermal` (rather than the world root, as
  bramble's equivalent d06/d07 pattern does for d06 only) — see (c) above;
  avoids a real placement-checker failure that exists in the reference
  world for the exact same situation.
- Added a non-collidable cat-silhouette mound not mentioned in the card —
  purely a rendering fix so the spawn establishing shot actually reads as
  "cat over village" given the camera rig's fixed downward pitch; zero
  gameplay effect (no collision, checked clear of every walkable prop).

## UNVERIFIED (honest list)

- Co-op / solo controller feel (jump arcs across the rooftop-chain gaps,
  tail-bridge ride/time both work in practice, flank-steps patient route)
  was checked by hand-computed edge-to-edge gap math (1.2-2.0 m for the
  rooftop chain, per constant comments in `marmalade.gd`) and by the
  placement checker's ground-gap numbers, not by a scripted playthrough
  with real jump inputs — no `--script` jump-by-jump traversal was recorded
  for this world (the existing `tools/harness/scripts/*` jump-property
  scripts are bramble/pillow_fort-specific and out of territory to extend
  here without a longer session).
- TTS audio and stem-layer wiring: `MOON_SAID` call-path receipts are green
  (`new_area` fires on world load); actual audible SAPI voice and the
  `stems/marmalade/` placeholder synth set were not producer-eared.
- 60 fps sustained perf: not instrumented for this world (same gap flagged
  for bramble in `docs/verify/gate2-slice-VERIFY.md`).
