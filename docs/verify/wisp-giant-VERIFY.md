# wisp-giant-VERIFY.md — Wisp gets the giant treatment (ROADMAP M3)

Engine: `D:\Tools\godot\godot_console.exe` -> `4.6.2.stable.official.71f334935`.
**served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic), running as
the Wisp-giant build agent inside a Claude Code session, single run,
2026-07-16/17.

Territory: `worlds/wisp/**`, `docs/verify/wisp-giant-VERIFY.md`,
`evidence/stills/m3_wisp/**`, `tools/harness/scripts/wisp_dive.json`.
Nothing outside that set was edited — `worlds/bramble/**` (read-only
reference), `worlds/marmalade/**`, `core/**`, `worlds/common/**`,
`data/missions/wisp.json`, `data/dreamkeepers/wisp.json`, `project.godot`
were either read-only references or not touched at all (no dreamling/
mission/dreamkeeper change was needed for this pass).

## Deliverable 1 — the whale in the sky

`assets/models/meshy/generated/wisp_whale_b.glb` swapped in via a plain
`ModelSlot` (no rig — static sculpt, animated by transform per the task
brief) at a new `WhaleShellAnchor`, nested under the existing `_whale`
(`WhaleDrift`) compound body so it rides the drift/dive exactly like every
other shape already on it (`worlds/wisp/wisp.gd::_build_whale_shell()`).

- GLB local AABB, measured via `tools/meshy/preview_model.tscn`
  (`evidence/stills/m3_wisp/preview/`): `(x=0.873, y=0.544, z=1.906)` —
  long axis is local Z.
- `WHALE_SHELL_TARGET_HEIGHT = 25.0` m → confirmed at boot via
  `MODEL_SWAP {"id":"wisp_whale_b","scaled":45.9531811123107}` → length ≈
  87.6 m, width ≈ 40.1 m, height = 25 m exactly. Anchored at
  `(40.0, -3.0, 0.0)`, the midpoint of the old Tail(x=7)/Head(x=73) span, so
  the model roughly envelops the existing ~93 m mound chain without moving
  a single dreamling/shelf/ledge coordinate.
- **Orientation bug caught live and fixed**: a first pass at
  `WHALE_SHELL_YAW_DEGREES = 90.0` put the model's NOSE toward the
  shore/tail end and its FLUKES toward the blowhole/head end — backwards
  (`evidence/stills/m3_wisp/whale_check/shot_30.png`). `-90.0` corrected it
  (`evidence/stills/m3_wisp/whale_check2/shot_30.png`,
  `whale_check3/shot_30.png`): local +Z is this GLB's FLUKE end, opposite of
  bramble's own rig convention — noted so a future model swap in this world
  doesn't assume the same sign.
- Once the swap lands, the old primitive Tail/Body/Head sphere VISUALS are
  hidden (`_tail_visual/_body_visual/_head_visual`, set `visible = false`);
  their COLLISION, and every shelf/ledge/crest/rim built on top of them
  (`FlipperLedge`/`BellyShelf`/`DorsalCrest`/`BlowholeRim`/the dorsal
  slide), is completely untouched — same "oversized, non-mesh-hugging
  collision the visible giant merely stands generously inside of" pattern
  bramble's own `_build_bear_shell()` established. If `wisp_whale_b.glb`
  were ever missing, `slot.get_child_count() > 0` stays false and the
  primitive mounds remain visible — the zero-GLBs-required floor holds.
- **TailSeesaw** ("tail_bridge" in the task brief — Wisp has no marmalade-
  style `TailBridge`/`arc_position()`; confirmed by a repo-wide grep. This
  world's actual bonus tail element is the rocking seesaw plank,
  `worlds/wisp/tail_seesaw.gd`): shape/collision/position kept byte-for-byte
  identical, only re-skinned to a cream tone (`F0EAD9`, pulled from the
  GLB's own belly color) so it reads as part of the new whale.
- Whale-reads verdict (own eyes): **yes** — `whale_check2/shot_30.png` and
  `whale_check3/shot_30.png` read unambiguously as a big sleeping plush
  whale (closed eye, smiling mouth, lifted flukes, tucked fin, cream belly)
  at a scale that dwarfs the lily-pad chain and the shore in the same frame.

## Deliverable 2 — THE DIVE (`worlds/wisp/dive_sequence.gd`, new)

Architecture mirrors `worlds/bramble/rollover_sequence.gd` (read-only
reference) point for point: same trigger contract
(`GameState.world_completed("wisp")` / `--dive` force flag, `FORCED_DELAY`
= 3 s), same cinematic-camera/letterbox vocabulary (**duplicated into this
file per the task brief's explicit one-night exception** — generalizing it
into `core/` is an M4 card, flagged here and in `NEXT_STEPS.md`), same
bubble-lift-before-anything-moves safety rule, same "build hidden once,
reveal by flip" convention for permanent new geometry.

Timeline (all receipted, `wisp_dive.json` headless run below):
1. **start** (t≈180f/3s, forced): letterbox+cine camera come up wide
   (whale + lake in one frame); every connected player is bubble-lifted
   (`core/rescue/bubble_effect.tscn`, same shared vocabulary rollover_
   sequence.gd already reuses) to a pre-existing, already-solid shore point
   (`DIVE_LANDING`) — off the whale before it moves at all.
2. Whale descends 9 m over 8 s (`WhaleDrift.begin_settle()`, new public
   method — tweens `_rest_y` itself rather than fighting `_physics_
   process`'s own per-frame `position.y` write, so the whale keeps
   breathing, at a shrinking residual amplitude, all the way down instead
   of freezing mid-tween). Camera slow-follows down in parallel.
3. **settled** (t≈660f): camera pushes toward the newly-flooded shore area;
   the flood-route group's collision goes solid immediately (rollover_
   sequence.gd's own "ground goes solid FIRST" lesson, applied here even
   though nothing is actually racing it — nobody is ever near the flood
   zone during the transition, confirmed by design: the bubble-lift target
   is the pre-existing Shore slab, not new ground); the lake surface plane
   and the flood-route group both tween up in parallel over 4 s (the
   "rising water" spectacle — cushions visibly emerge).
4. **routes_open** (t≈900f): 5 new floating cushion-pads (reused `LilyPad`
   class, blush/cream/sage palette) + a new mossy islet with 3 dressing
   props (stone_soft/moon_daisy/lantern) are fully risen and standable.
5. 3 s camera hold, letterbox out, **end** (t≈1080f).
6. Persistence: a revisit after a prior session's dive applies the settled/
   risen state directly, no animation (`_apply_already_dived_state()` /
   `WhaleDrift.settle_immediately()`), matching D14 + rollover_sequence.gd's
   own `_apply_already_open_state()` convention exactly.

### Safety

- Every player is bubble-lifted to `DIVE_LANDING = (-72.0, 0.5, -6.0)` —
  the pre-existing Shore slab, solid since world load — **before** the
  whale or the water moves. Unlike Bramble's far-meadow reveal (new ground,
  timing-sensitive), there is no equivalent race here: nobody is ever near
  the flood zone while it rises.
- "Shore stays dry": the flood route (`FLOOD_CUSHION_POSITIONS`, x:-53..-34,
  z:12..16; islet at x:-27, z:15.5) sits entirely inside the lake's own
  footprint (`LAKE_CENTER=(-21,0)`, `LAKE_SIZE=(68,40)` → x:-55..13,
  z:-20..20) — never over the Shore slab (x:-87..-55). This holds by
  construction (spatial separation), not by cutscene timing.
- Hop gaps: shore edge → cushion 0 ≈ 2 m; cushion-to-cushion edge gaps
  (radius 1.7 m each) computed by hand at 2.0 / 2.0 / 2.4 / 1.5 m;
  cushion 4 → islet ≈ overlapping/1.5 m. All comfortably under the brief's
  3.5 m single-jump-reach cap.

## Deliverable 3 — flood-route validity

Confirmed by the safety section above (gap table) and live-tested below via
teleport-assisted hops with continuous `PLAYER_POS` receipts.

## Deliverable 4 — camera hints

`FloodRouteHint` (priority 3, covering the cushion span) and `IsletHint`
(priority 4, covering the islet footprint) added inside `FloodRoute`,
collision-disabled until reveal, same pattern as `wisp.gd`'s own
`_build_camera_hints()` / rollover_sequence.gd's `_add_camera_hint_far_
meadow()`.

## Deliverable 5 — receipts

### a) Headless import — exit 0, zero script errors

```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path .
```
Exit `0` on two consecutive runs (one captured to file and grepped for
`error|SCRIPT ERROR|Parse Error` — zero matches). New class `DiveSequence`
registered cleanly alongside the existing `WhaleDrift`/`Wisp`/`Marmalade`.

### b) Headless boot — `--world=wisp`

```
D:\Tools\godot\godot_console.exe --headless --path . -- --skipmenu --world=wisp --quitafter=6
```
`WORLD_READY {"id":"wisp","objectives":10}` printed. `MODEL_SWAP
{"id":"wisp_whale_b","scaled":45.9531811123107}` confirms the giant swap.
No `SCRIPT ERROR`/`Parse Error`. (An `ObjectDB instances leaked at exit` /
`2 resources still in use at exit` warning appears — **confirmed pre-
existing**: reproduced identically on an untouched `pillow_fort` boot, not
introduced by this pass.)

### c) Placement + mission sanity — all worlds green

```
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=wisp
```
`PLACEMENT_SUMMARY {"any_fail":false,"worlds":["wisp"]}` — all 10/10
dreamlings PASS, identical `ground_gap`/`moving_platform` shape to the
pre-existing `world-wisp-VERIFY.md` baseline (giant-treatment visuals don't
touch collision, confirmed).

```
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=marmalade
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_missions.gd
```
`PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort","bramble"]}`
(pillow_fort has zero dreamlings, N/A); `{"any_fail":false,"worlds":
["marmalade"]}`; `MISSION_SUMMARY {"any_fail":false,"worlds":["bramble",
"wisp","marmalade"]}`. All four worlds green.

### d) THE DIVE property — `tools/harness/scripts/wisp_dive.json` (new)

```
D:\Tools\godot\godot_console.exe --headless --path . -- --skipmenu --world=wisp --pads=1 --dive ^
  --script=tools/harness/scripts/wisp_dive.json --poslog=30 --outdir=evidence/stills/m3_wisp/dive_run --quitafter=21
```
Phase receipts, in order, at the expected frames:
```
DIVE {"forced":true,"phase":"start"}       (t≈180-210)
DIVE {"phase":"settled"}                   (t≈660-690)
DIVE {"phase":"routes_open"}               (t≈900-930)
DIVE {"forced":true,"phase":"end"}         (t≈1080-1110)
```
Seat 1 (Pip) is bubble-lifted from spawn along a smooth arc (y: 0.45 → 1.5
→ 0.45) and lands exactly at `DIVE_LANDING = (-72.0, 0.45, -6.0)`; seat 2
(Otto) lands at `(-70.6, 0.43, -6.0)` — exactly `DIVE_LANDING +
(BUBBLE_LANDING_SPACING, 0, 0)`. Six teleport-assisted hops
(`HARNESS_TELEPORT`) across every flood cushion and onto the islet, all
scheduled after `routes_open`, each followed by a `PLAYER_POS` confirming a
safe landing:
```
(-53.0, 0.56, 12.0) -> (-48.5, 0.78, 15.0) -> (-43.5, 0.42, 13.0) ->
(-38.5, 0.65, 16.0) -> (-34.0, 0.72, 14.0) -> (-27.0, 0.85, 15.5)
```
Y never drops below `0.42` or exceeds `0.85` across the whole hop chain —
nowhere near `RESCUE_FLOOR_Y = -8.0` — and the final islet position holds
rock-stable (`(-27.0, 0.85, 15.5)`, unchanged) across 5 further poslog
samples (150 frames / 2.5 s). Zero `RESCUE` lines fired anywhere in the
run; two `WARP {"seat":2}` lines are Otto's normal buddy-AI leash-catch-up
(seat_manager.gd), not a rescue. Zero `SCRIPT ERROR`/`Parse Error`.

**Playtest note (not a bug, not this pass's territory to fix)**: solo-mode
buddy AI (Otto) tracking Pip's teleports partially waded through the
shallow `LakeBed` (observed `y≈0.03`, mid-route) instead of reliably
hopping pad-to-pad. This is pre-existing buddy-AI pathing behavior,
unrelated to the new geometry, and is safe regardless — the world card
itself documents the lake bed as "walkable... waist-deep... OK to skip in
v1." Flagged for a future playtest/pathing pass, not blocking.

### e) Existing wisp harness script — regression check

```
D:\Tools\godot\godot_console.exe --headless --path . -- --skipmenu --world=wisp --pads=2 ^
  --script=tools/harness/scripts/finale_wisp.json --outdir=evidence/stills/m3_wisp/finale_wisp_run --quitafter=15
```
`WORLD_READY {"id":"wisp","objectives":10}` prints, all 8 scripted events
fire (`HARNESS_EVENT` receipts for every move/jump), zero errors.
(`fort_population.json` also references `wisp` — but only via pre-seeded
save data for hub-population greet checks; it boots `pillow_fort`, not
`wisp`, so it isn't a wisp-world regression surface and wasn't re-run here.)

### f) Stills

| File | Shows |
|---|---|
| `evidence/stills/m3_wisp/preview/shot_{30,90,150,210}.png` | Raw `wisp_whale_b.glb` orbit, isolated (AABB measurement) |
| `evidence/stills/m3_wisp/whale_check/shot_30.png` | **v1** — orientation bug (nose toward shore, backwards) |
| `evidence/stills/m3_wisp/whale_check2/shot_30.png` | **v2** — corrected wide profile, whale-reads verdict shot |
| `evidence/stills/m3_wisp/whale_check3/shot_30.png` | Closer profile, confirms the small BlowholeRim bump + WaterSpout column read as natural details, not artifacts |
| `evidence/stills/m3_wisp/shot_220.png` | THE DIVE — whale wide, cine start (letterboxed) |
| `evidence/stills/m3_wisp/shot_450.png` | THE DIVE — mid-descent (letterboxed) |
| `evidence/stills/m3_wisp/shot_920.png` | THE DIVE — routes open, wide (letterboxed): new blush/cream cushion cluster + mossy islet visible in the foreground, settled whale in the background |
| `evidence/stills/m3_wisp/shot_1000.png` | THE DIVE — routes open, held (letterboxed) |
| `evidence/stills/m3_wisp/shot_1150.png` | Islet close-up, devcam, captured AFTER `_cine_end()` restored normal control — letterbox gone, flood state persists, islet + a dressing prop clearly visible |

## UNVERIFIED / honest deviations

- Whale anchor position/scale/yaw were tuned by eye across 3 still
  iterations, not derived by exact surface-matching against the retired
  sphere-mound geometry — same "not mesh-hugging, generous enough to read
  as resting against him" bar bramble's own ascent-ramp note already
  accepts for its rigged bear.
- `FlipperLedge`/`BellyShelf`/`DorsalCrest`/`BlowholeRim` stay simple grey
  boxes riding on the new mesh — not re-textured to visually blend with
  the whale's hide. A future polish pass could re-skin them (same
  observation bramble's own ascent ramps carry, unresolved there too).
- No dedicated video/movie receipt was captured for THE DIVE — this pass's
  deliverable list asked for stills specifically ("stills: whale wide...,
  mid-dive, routes open, islet"), not a video; a `--write-movie` receipt
  would be a natural follow-up alongside a couch playtest.
- The cine-camera/letterbox code is duplicated into `worlds/wisp/dive_
  sequence.gd` rather than shared with `worlds/bramble/rollover_sequence.
  gd` — deliberate per the task brief ("acceptable tonight"); generalizing
  it into `core/` is an M4 card.
- The islet's `lantern` prop glow isn't distinctly visible in the far/wide
  stills (small, distant, night lighting) — confirmed present via the
  `MODEL_SWAP {"id":"lantern",...}` boot receipt and its authored position
  instead of a close visual read; a dedicated close-up devcam shot on the
  lantern specifically would be a quick follow-up if the producer wants a
  tighter look.

## Files touched

```
worlds/wisp/wisp.gd            (whale shell swap, tail seesaw recolor, dive wiring, devcam)
worlds/wisp/whale_drift.gd     (begin_settle() / settle_immediately())
worlds/wisp/dive_sequence.gd   (new)
tools/harness/scripts/wisp_dive.json          (new)
docs/verify/wisp-giant-VERIFY.md              (new, this file)
evidence/stills/m3_wisp/**                    (new, this file's receipts)
```

No files outside `worlds/wisp/**`, this `docs/verify/` receipt,
`tools/harness/scripts/wisp_dive.json`, and `evidence/stills/m3_wisp/**`
were modified. No git commit made, per instructions.
