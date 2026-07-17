# D25 — THE MOUNTAIN IS THE BEAR — VERIFICATION (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
**served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic), running as
the mountain/D25 build agent inside a Claude Code session.

Scope: `docs/DECISIONS.md` D25 — Bramble rescales to ~42m and becomes the
world's half-buried central-east massif; an authored ascent path climbs his
back to the summit (ear/DreamDoor); the massif is dressed as terrain
(path-dirt, stones, pines, snow, a cloud ring); the 10/10 finale becomes THE
REVEAL (breath-gust blows the disguise away, mountain dressing tumbles off,
he wakes and sits up). Territory: `worlds/bramble/**`,
`data/missions/bramble.json`, `data/dreamkeepers/bramble.json`,
`tools/harness/scripts/bramble_*.json`, this file,
`evidence/stills/m3_mountain/**`. No other files touched; no commits made
(director integrates).

---

## What shipped

**The massif (`worlds/bramble/bramble.gd` `_build_bear_shell()`).**
`BEAR_SHELL_RIG_STANDING_HEIGHT` 28→42 (+50%, D25). `BEAR_SHELL_POSITION`
moved from the old off-to-the-side (44,0,27) to a sunk, central-east
(38,-5,10) — half-buried (visual mesh sinks with the anchor; the sleep clip
turns out to be a hunched, curled-forward SIT, not a lying pose — confirmed
by still, `evidence/stills/m3_mountain/baseline5_side`). `BEAR_SHELL_YAW_
DEGREES` 0→90: his local forward (verified empirically by still — a camera
south of him at yaw 0 saw his face) now points +X, so his BACK faces -X/
west, toward the spawn approach — arriving players see his back rising up
first, per the brief's ascent framing. The old collision blocker (one lying
capsule) is now a torso-capsule + head-sphere stack matching the sit pose.
The **original haunch → chest → shoulder → paw-ramp → fur-patch mound
chain is untouched** — seven of ten dreamlings (d01/d02/d03/d05/d07/d08/
d09) pin to its exact coordinates (existing harness scripts depend on
them). It now reads as a string of low foothills at the massif's western
base (see stills). The old grey-box Head mound and Ear bump are retired
(`_build_head()` no longer called); `GEYSER_ANCHOR_*`'s Y still derives
from the old `HEAD_CENTER`/`HEAD_RADIUS` sphere math on purpose (d07 pinned
to that formula, not to the mound's rendering).

**The ascent (`_build_ascent()`, new).** Five switchback ramp segments
(`ASCENT_BASE` → `L1` → `L2` → `L3` → `L4` → `ASCENT_SUMMIT`) climbing his
south flank from meadow level (y=0) to a summit platform (y=32-33) beside
his head, entirely clear of the Shoulder mound's footprint and (after a v2
correction) clear of his face. Each ramp is a `PrismMesh` slope (the same
primitive `_add_paw_ramp` already used, generalized to an arbitrary
diagonal via `atan2`), 9m wide; each landing is a flat ledge, 6-9m square.
Per-segment `CameraHint` volumes (yaw matched to that segment's own travel
direction, on-rails-ish framing per D18) plus a bridging hint
(`AscentApproachHint`) closing a real gap between the old meadow hints and
the new trailhead (see Gotcha below). Summit platform carries the relocated
`DreamDoor` (`_build_ear_and_door()`, same function name, new coordinates:
now `ASCENT_SUMMIT`, not the old head-mound ear bump).

**Dreamling relocation (`_build_dreamlings()`).** d04 (was: -Z paw ramp,
"open") and d06 (was: riding the chest, "open") now sit on ascent ledges
(L2, L4). d10 (was: old ear bump, "open") now sits beside the new summit
door, same "offset from the door" convention as before. **d01/d02/d03/d05/
d07/d08/d09 are byte-for-byte unchanged.** The chest itself (trampoline)
stays exactly where it was — a foothill "at his side," per the brief's
explicit allowance — just without a dreamling riding it anymore.

**Mountain dressing (`worlds/bramble/mountain_dressing.gd`, new,
`class_name MountainDressing`).** A registry of stones (at each ascent
waypoint), sparse pines (alternating waypoints), four snow-cap spheres at
the summit, and an 8-cloud ring orbiting slowly at shoulder height (D25:
"at his shoulders"). One `reveal()` API: clouds blow outward + fade
(~1.5s), then every remaining prop detaches and falls (local -Y, a tumble
rotation, a fade), staggered randomly across ~2.5s. Persistence: `_ready()`
checks `GameState.is_world_completed("bramble")` and simply doesn't build
anything on a revisit after completion — "the bear stays revealed forever"
needs no teardown when nothing was ever built. The ascent path itself
(ramps/ledges, in `bramble.gd`) is deliberately **not** part of this
registry — real, permanent collision a player may be standing near
mid-cutscene; only the loose disguise dressing falls away.

**The reveal (`worlds/bramble/rollover_sequence.gd` + `breath_weather.gd`).**
`BreathWeather.force_gust()` (new public method) fires one exhale
(lift/particles/light/audio) on demand without touching `_time`/
`cycle_period` — the ambient cycle keeps ticking underneath, untouched, per
the brief's explicit requirement. `RolloverSequence._play_sequence()` calls
`_trigger_breath_gust()` right after the letterbox comes in
(`_cine_begin()`); `_play_keystone()` calls `_trigger_dressing_reveal()`
(→ `MountainDressing.reveal()`) at the start of the "wake" clip specifically,
so the debris-fall lands during that clip, per the brief. Both cross-file
calls use duck-typed `Object.call()` (not a static `as ClassName` cast) —
matching `core/camera/camera_rig.gd`'s own documented workaround for a
Godot 4.6.2 headless bug resolving members of an externally-`class_name`'d
script fetched at runtime.

**A dev-only free camera (`_build_dev_camera()`, `bramble.gd`).** Inert
unless `--devcam` is passed; reads `--devcam_pos=x,y,z`/`--devcam_look=x,y,z`
so a still can be aimed without a code edit. Built for this pass's blind
placement iteration (`evidence/stills/m3_mountain/`); left in as a
reusable tool for whoever tunes this world next.

**Bug found and fixed, live, not a D25 change itself: `super._ready()`
was missing from `Bramble._ready()`.** It had been stranded as dead code
after a `return` inside an unrelated helper (`_dressing_cone()`, pre-
existing — introduced in the "keystone" commit, unrelated to this pass).
Without it, `WorldBase._ready()` (dreamling signal wiring,
`DreamDoor.returned` connection, mission attachment, critters, the
`WORLD_READY` receipt) never ran for Bramble at all: world completion only
ever worked via the forced `--rollover` dev flag, never via natural 10/10
play, and `DreamDoor` returns never registered. `wisp.gd`/`pillow_fort.gd`
both already call `super._ready()` as the last line of their own `_ready()`
(confirmed by grep) — this restores the same contract for Bramble. Moved
to the correct spot (last line of the real `_ready()`); confirmed live
(`WORLD_READY {"id":"bramble",...}` now prints; see receipts below).

---

## Receipts

**Placements, all 4 worlds:**
```
godot_console.exe --headless --path . --script tools/props/check_placements.gd
→ PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort","bramble"]}
```
(`wisp`/`marmalade` have no `check_placements` default-world entry — same
as before this pass; `--world=bramble` run separately shows all 10
dreamlings, including the three relocated ones, PASS with `ground_gap`
0.16-0.7m.)

**Missions, all 3 worlds with mission data:**
```
godot_console.exe --headless --path . --script tools/props/check_missions.gd
→ MISSION_SUMMARY {"any_fail":false,"worlds":["bramble","wisp","marmalade"]}
```
`data/missions/bramble.json` was **not edited** — d04/d06/d10 are all
"open" archetype (no position-relative waypoint data to update).

**`tools/harness/scripts/bramble_ascent.json` (new).** Phase 1
(un-teleported, from the real spawn, `--pads=2`): Pip walks the meadow
(strafing clear of the old haunch/chest/shoulder mound chain, crossing a
real `CameraHint` gap the ascent's own `AscentApproachHint` now bridges —
see Gotcha below) and climbs Seg0 entirely under camera-relative input, y
0→~5.9 approaching L1 (28,6,32) — proves at least the first switchback
reachable unassisted, no teleport. Phase 2 (teleport-assisted, explicitly
sanctioned by the brief): teleports onto L1/L2/L3/L4/SUMMIT in turn; every
landing holds (no fall) — proves every waypoint is solid ground; short
walking bursts after the L1 and L2 landings show the climb beginning (y
rising) in the correct direction. Zero `RESCUE` lines across the final
run. Command:
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=bramble --pads=2 --script=tools/harness/scripts/bramble_ascent.json --poslog=20 --quitafter=68 --outdir=evidence/_scratch/ascent_final
```

**`tools/harness/scripts/bramble_rollover.json` (updated description) +
`--rollover`:**
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=bramble --pads=2 --rollover --script=tools/harness/scripts/bramble_rollover.json --poslog=60 --quitafter=45 --outdir=evidence/_scratch/rollover_full
```
Receipt order, exactly as designed:
```
ROLLOVER {"forced":true,"phase":"start"}
BREATH {"phase":"force_gust"}
BREATH {"phase":"exhale_start"}
ROLLOVER {"clip":"wake","phase":"keystone"}
DRESSING {"clouds":8,"phase":"reveal_start","props":12}
DRESSING {"phase":"clouds_blown"}
BREATH {"phase":"exhale_end"}
DRESSING {"phase":"debris_falling"}
BREATH {"phase":"exhale_start"}
ROLLOVER {"clip":"breathe","phase":"keystone"}
BREATH {"phase":"exhale_end"}
BREATH {"phase":"exhale_start"}
ROLLOVER {"clip":"toss_turn","phase":"keystone"}
BREATH {"phase":"exhale_end"}
ROLLOVER {"forced":true,"phase":"end"}
```
Both seats float to the far meadow and hold at (-20, 0.45, -52) / (-18.6,
0.43, -52) — unchanged from before this pass. Zero real `RESCUE` lines
(the one grep hit was the word "rescue" inside this very script's own
description string, not an event — double-checked against the raw
`events.jsonl`).

**`finale_home.json`** (unmoved d01/d02, plus the wisp/marmalade sibling
worlds' door/Callie chain): `CALLIE` carried, `DOOR {"to":"bramble"}`,
`WORLD_READY {"id":"bramble","objectives":10}` (previously silent — the
`super._ready()` fix), `dreamling_collected` for both d01 and d02. Passes.

**Spot-checked existing `mission_*.json` scripts for unmoved dreamlings**
(all pass, `dreamling_collected` fires, zero `RESCUE`):
`mission_ride.json` (d05), `mission_shy.json` (d09), `mission_duet.json`
(d08), `mission_geyser_flourish.json` (d07).

**`tools/harness/scripts/bramble_breath_lift.json`** (unchanged behavior):
`BREATH exhale_start` / `exhale_end` both fire, zero `RESCUE`.

---

## Stills — the honest "would a child know?" verdict

- `evidence/stills/m3_mountain/v4_wide_disguised/shot_150.png` — wide
  establishing shot, mountain fully disguised: back rising like a rounded
  hill, dirt-path switchbacks climbing the flank, a spread cloud ring
  drifting near the top, the old shoulder-mound + paw-ramp foothills in
  the foreground.
- `evidence/stills/m3_mountain/reveal/shot_240.png` — mid-reveal, the
  cloud ring visibly blowing outward/fading.
- `evidence/stills/m3_mountain/reveal2/shot_400.png` /
  `evidence/stills/m3_mountain/reveal/shot_360.png` — debris (a pine/stone,
  mid-tumble) falling away from the flank.
- `evidence/stills/m3_mountain/reveal/shot_900.png` — revealed: the bear
  clearly sitting up mid `toss_turn`, ramps still standing as terrain
  around him (by design — see "What shipped").

**Verdict: PARTIAL, honestly.** From the intended play distance and
approach angle (spawn is west of the massif; his back faces west; the
ascent climbs the south flank) the disguise reads well — a first-time
player exploring normally, following the dreamling trail up the switchback
path, is very unlikely to clock "that's a bear" before the reveal. But his
**face is not hidden and is not far from the ascent's own east edge**
(`evidence/stills/m3_mountain/v3_east/shot_150.png`,
`v1_scale_probe3/shot_150.png` — close-up profile shots taken during
placement iteration): a curious child who circles around to the east side
before finishing the world would see an unmistakable teddy-bear face at
close range. I did not add dressing to the face/front specifically (no
brief for a "muzzle" disguise, and doing so risked looking worse, not
better) — this is a real, named gap, not a hidden one. If a future pass
wants a harder guarantee, either block/discourage the east approach
architecturally (a collision nudge, a "nothing back there" framing) or
dress the face itself (a soft rock/moss veil over the snout) would be the
next move.

---

## UNVERIFIED

- **A single continuous, un-teleported camera-relative walk across a
  segment's FULL run length is reliable for Seg0 only.** During iteration,
  the later/steeper switchbacks (tested live via a walk script, not
  shipped as the final receipt) drifted or reversed mid-climb rather than
  completing cleanly — most likely `core/camera/camera_rig.gd`'s velocity-
  leash heading formula (`atan2(vel.x, vel.z)`), which empirically yaws
  the camera to face opposite the direction of travel once a player leaves
  every `CameraHint`'s coverage (confirmed by fixing ONE such gap in-
  territory with `AscentApproachHint` — that fix visibly worked). I did
  not fix `camera_rig.gd` itself (`core/**` is forbidden territory per the
  brief) and did not find a full in-territory workaround for every
  segment in the time available. Every waypoint's ground and every ramp's
  initial climb direction ARE proven (see receipts); a full unassisted
  climb of segments 2-5 specifically is not.
- **The massif's exact real-world dimensions were never measured
  precisely** — Godot doesn't expose a live skinned-mesh AABB for the
  posed (curled-sit) animation, only the T-pose rest AABB (the same one
  `model_slot.gd`/`_build_bear_shell()` already use for scaling), so every
  ascent/dressing coordinate in this pass was calibrated from screenshots
  (including a two-known-height-marker "scale probe" — Pip/Otto placed
  at candidate points, per `evidence/stills/m3_mountain/v1_scale_probe*`)
  and iterated against stills, not analytically derived. Some ramps/
  ledges likely sit a meter or two off his true visual surface in places
  not directly screenshotted.
- **No new Meshy props were generated for this pass** — dressing uses
  primitives only (matches the codebase's existing grey-box convention
  and keeps `reveal()`'s fade/tumble simple — see `mountain_dressing.gd`'s
  header comment on why GLBs were deliberately skipped here).
- I did not re-run the FULL `docs/verify/*-VERIFY.md` regression suite for
  the other three worlds (wisp, marmalade, pillow_fort) beyond
  `check_placements`/`check_missions`/`finale_home.json`'s door chain —
  those worlds were never touched by this pass, so I judged that
  sufficient given the time available, but it is not exhaustive proof.

---

## Gotchas (add to the project ledger)

14. A `CameraHint`-driven world has REAL gaps where neither the local
    `MeadowApproachHint`-style boxes nor a moving-forward velocity leash
    agree on facing — camera_rig.gd's leash (`atan2(vel.x, vel.z)`)
    empirically yaws to face AWAY from travel once no hint is active,
    producing a walk-into-reverse oscillation. Cheapest in-territory fix:
    add a bridging `CameraHint` over the gap (same yaw as its neighbors);
    ties on overlap go to the highest `priority`, so give every hint in a
    chain a real, strictly-ordered priority rather than a shared constant
    — same-priority adjacent hints tie unpredictably at their shared
    boundary and can hold a walking player dead in a corner.
15. `super._ready()` in an overridden `_ready()` is easy to lose silently
    during a merge/refactor — GDScript neither warns on a missing parent
    call nor errors on dead code after a `return`. If a world's
    `WORLD_READY` receipt line is ever missing from a run, check this
    first before anything else.

---

## Files touched (≤12 lines)

- `worlds/bramble/bramble.gd` — massif rescale/reposition/reorient +
  collision, ascent path (new), dreamling relocation (d04/d06/d10), ear/
  door relocation, mountain-dressing wiring, dev camera tool, `super.
  _ready()` bug fix.
- `worlds/bramble/mountain_dressing.gd` — new.
- `worlds/bramble/breath_weather.gd` — `force_gust()` added.
- `worlds/bramble/rollover_sequence.gd` — gust/reveal triggers wired into
  `_play_sequence()`/`_play_keystone()`.
- `tools/harness/scripts/bramble_ascent.json` — new.
- `tools/harness/scripts/bramble_scale_probe.json` — new (dev-only
  calibration tool, not a shipped property).
- `tools/harness/scripts/bramble_rollover.json` — description updated.
- `docs/verify/mountain-m3-VERIFY.md` — this file.
- `evidence/stills/m3_mountain/**`, `evidence/_scratch/**` — receipts.
