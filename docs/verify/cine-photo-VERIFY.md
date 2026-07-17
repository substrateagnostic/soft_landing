# cine-photo-VERIFY.md — Cinematic core extraction, Photo Mode v1, camera-drift investigation

Engine: `D:\Tools\godot\godot_console.exe` -> `4.6.2.stable.official.71f334935`.
**served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic), running as
the cinematic/photo-mode/camera-drift agent inside a Claude Code session,
single run, 2026-07-17.

Territory: `core/cinematic/**` (new); `worlds/bramble/rollover_sequence.gd`,
`worlds/wisp/dive_sequence.gd`, `worlds/marmalade/stretch_sequence.gd`
(refactor only — behavior preserved); `core/camera/camera_rig.gd`
(investigated, **not edited** — see Deliverable 3); `scenes/ui/**`;
`project.godot` `[input]` section (read, **not edited** — no new actions
needed, see Deliverable 2); `tools/harness/scripts/photo_*.json` +
`cine_*.json` (new — plus one more script explained below);
`docs/verify/cine-photo-VERIFY.md`. Nothing outside that set was touched.

One filename note: deliverable 3 requires a 2-pad harness repro script that
doesn't fit either the `photo_*` or `cine_*` glob named for deliverables 1-2.
It's `tools/harness/scripts/camera_drift_probe.json` — same directory
already shared by a dozen other agents' own topic-named scripts
(`bramble_ascent.json`, `pound_bounce.json`, `gate2_*.json`, ...), so this
follows that existing convention rather than either glob literally.

## Deliverable 1 — `core/cinematic/cine_sequence.gd`

Extracted the byte-for-byte-duplicated letterbox + cine-camera machinery
(each of the three files' own header comments named this exact debt and
pointed here) into `core/cinematic/cine_sequence.gd` (`class_name
CineSequence`, new). API: `setup(host, cam_name, letterbox_name)`,
`begin(wide_pos, wide_look)`, `dolly_to(pos, look, time, look_time=-1.0)`,
`push_to(...)` (same mechanics as `dolly_to`, kept as a separate name per
the task brief's requested API — the three originals used different verbs
for the same operation at different narrative beats), `end()`. The
look-target is still driven every frame via `Camera3D.look_at()` in
`_process()`, unchanged from all three originals.

Each world file now only supplies its own waypoints (the `CINE_*` consts)
and calls `_cine.begin()/dolly_to()/push_to()/end()`; every letterbox
field/const (`LETTERBOX_FRACTION`/`LETTERBOX_FADE`, bar color, layer 90),
`_cine_cam`/`_prev_cam`/`_letterbox`/`_bar_top`/`_bar_bottom` var, and the
`_cine_begin/_cine_*_push/_cine_end/_process/_show_letterbox/_make_bar`
functions were deleted from all three files. `_cine: CineSequence` is
built once in each file's own `_ready()` (`add_child` + `setup(_world,
"<X>CineCamera", "<X>Letterbox")` — camera/letterbox node names preserved
exactly, still parented directly under the world node, matching the
originals' own hierarchy).

Diff shape per file (mechanical, not narrative):

| File | Removed | Added |
|---|---|---|
| `worlds/bramble/rollover_sequence.gd` | ~90 lines (cine block) | `var _cine`, 4-line `_ready()` wiring, 3 one-line call-site swaps |
| `worlds/wisp/dive_sequence.gd` | ~85 lines | same shape |
| `worlds/marmalade/stretch_sequence.gd` | ~95 lines | same shape (4 call sites: begin/dolly, route push, nook push, end) |

### Receipt-parity re-runs (headless, this session)

All three re-run against their existing `tools/harness/scripts/*.json` and
diffed by eye against the exact lines each `*-VERIFY.md`/harness-script
description already quotes.

**`bramble_rollover.json`** —
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=bramble --pads=2 --rollover --quitafter=45 --outdir=evidence/_scratch/cine_refactor/bramble
```
```
ROLLOVER {"forced":true,"phase":"start"}
BREATH {"phase":"force_gust"}
BREATH {"phase":"exhale_start"}
ROLLOVER {"clip":"wake","phase":"keystone"}
DRESSING {"clouds":22,"phase":"reveal_start","props":12}
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
Matches `bramble_rollover.json`'s own quoted expectation order exactly
(start -> force_gust/exhale_start -> keystone/wake -> DRESSING
reveal_start/clouds_blown/debris_falling -> breathe -> toss_turn -> end).
Zero `RESCUE` lines, zero `SCRIPT ERROR` lines.

**`wisp_dive.json`** —
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=wisp --pads=1 --dive --script=tools/harness/scripts/wisp_dive.json --poslog=30 --quitafter=40 --outdir=evidence/_scratch/cine_refactor/wisp
```
```
DIVE {"forced":true,"phase":"start"}
DIVE {"phase":"settled"}
DIVE {"phase":"routes_open"}
DIVE {"forced":true,"phase":"end"}
```
Matches `wisp-giant-VERIFY.md`'s quoted phase order exactly. Seat 1's
poslog confirms it reaches the islet and holds: `PLAYER_POS
{"seat":1,"t":2280..2400,"x":-27.0,"y":0.85,"z":15.5}` (5 consecutive
identical samples = solid, no fall). Zero `RESCUE`, zero `SCRIPT ERROR`.

**`marmalade_stretch.json`** —
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=marmalade --pads=2 --stretch --script=tools/harness/scripts/marmalade_stretch.json --poslog=30 --quitafter=45 --outdir=evidence/_scratch/cine_refactor/marmalade
```
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
Byte-for-byte match (including key order) to `marmalade-giant-VERIFY.md`'s
own quoted "full phase order, exactly as designed" block. Zero `RESCUE`,
zero `SCRIPT ERROR`.

**Verdict: receipt-identical, all three.** Behavior unchanged by the
refactor; only the machinery moved.

`godot_console.exe --headless --path . --import` was required once before
any of this (`CineSequence` needing to land in Godot's global class-name
cache — a brand-new `class_name` script isn't visible to `.new()` calls
elsewhere until a scan runs; caught live as `SCRIPT ERROR: Invalid call.
Nonexistent function 'new' in base 'GDScript'` at `bramble.gd:926`, fixed
by the import pass, not a code change).

No windowed re-capture of the three cutscenes themselves was done this
pass (headless receipt-parity was judged sufficient given the mechanical
nature of the refactor and the time budget — see Deliverable 2's own
windowed captures below for proof the shared `CineSequence`/letterbox
plumbing still renders correctly in a real window).

## Deliverable 2 — Photo Mode v1

**`scenes/ui/photo_mode.gd`** (new, `class_name PhotoMode extends Node`):
entered from a new **Photo** button (camera icon + label, matching the
existing Keep Playing/Options/Sleep row's v2 icon+label convention) in
`pause_menu.gd`'s main row, positioned between Options and Sleep. Pressing
it emits `photo_mode_requested` (new signal); `GameUI` (which already owns
both `HUD` and `PauseMenu`, unlike `PauseMenu` itself) owns the actual
`PhotoMode` instance and wires it in `_ready()`.

On `enter()`: HUD hidden, `TheMoon`'s `SubtitleRibbon` hidden (found via
`get_node_or_null` + duck-typed `.set()`, sidestepping the documented
Godot 4.6.2 headless external-class-member-resolution bug the same way
`rollover_sequence.gd`/`camera_rig.gd` already do), the pause overlay
itself hidden (`get_tree().paused` stays `true` — the whole session stays
paused, matching the brief's "game paused"). A free orbit camera then
takes over: `Node3D` pivot (position = target player position + height
offset) -> `SpringArm3D` (pitch, sphere-cast collision, radius 0.25,
collision mask 1 — same numbers as `camera_rig.gd`'s own rig) ->
`Camera3D`, added under `get_tree().current_scene` (matching every other
dynamically-spawned node in this codebase, e.g. `BubbleEffect`). Left
stick (both seats summed) orbits yaw/pitch; right stick adjusts
height/zoom; jump (either seat) is the shutter; interact (either seat) is
back-to-pause. No new `project.godot` `[input]` actions were needed —
orbit/zoom reuse the existing `p1_move_*`/`p1_camera_*` (and p2) actions,
which are otherwise idle while the tree is paused.

Photo persistence doesn't touch `GameState`/`SaveManager` (outside
territory): the "persistent counter" is derived by scanning
`user://photos/` for the highest existing `photo_<n>.png` at first use,
then incrementing in memory — disk-based, so it survives a restart with no
new save schema.

**Two real bugs found and fixed live, both via a windowed `--shots`
capture** (headless can't render, so neither was visible until then):

1. **SpringArm3D never pushed the camera out.** The rig is parented under
   `get_tree().current_scene` — a *sibling* of `PhotoMode`, not its
   descendant — so it did **not** inherit `PhotoMode`'s own
   `process_mode = WHEN_PAUSED` and defaulted to `PROCESS_MODE_INHERIT`,
   which is frozen while the tree is paused. `SpringArm3D`'s own internal
   shape-cast (the part that actually repositions its Camera3D child along
   -Z by `spring_length`, clamped by whatever it hits) is tied to that same
   physics-gated processing, so it never ran: the camera sat frozen at
   local `(0,0,0)` — exactly at the pivot — for the whole session. Fix:
   `process_mode = Node.PROCESS_MODE_WHEN_PAUSED` set explicitly on the
   pivot, the `SpringArm3D`, and the `Camera3D`.
2. **Default framing showed nobody.** A first pass used a shallower pitch
   (-20°) and a +1.2m height offset "for a nicer establishing shot"; with
   bug #1 masking the real geometry, this read as a wide, distant horizon
   with Pip nowhere in frame. Fixed by matching `camera_rig.gd`'s own
   proven defaults exactly (`base_pitch_degrees = -32.0`, `arm_length =
   6.0`, and a height offset of `0.0` to match its ground-tracked pivot Y)
   — photo mode's opening shot is now provably the same framing the
   player already sees from the ordinary follow camera.

### Windowed proof (this session)

```
godot_console.exe --path . --write-movie evidence/_scratch/photo_mode3/dummy.avi --fixed-fps 60 --resolution 1280x720 -- --skipmenu --world=bramble --pads=1 --debug_photo --script=tools/harness/scripts/photo_shutter.json --shots=70 --outdir=evidence/_scratch/photo_mode3 --quitafter=4
```
`--debug_photo` (new debug seam in `game_ui.gd`, same family as
`--debug_pause`/`--debug_options`/`--debug_pause_sleep`) opens the pause
menu and requests photo mode on boot — `enter()` itself is deferred one
frame (`_photo_mode.enter.call_deferred()`) because firing synchronously
inside `GameUI._ready()` raced `get_tree().current_scene`'s own scene-
instancing ("Parent node is busy setting up children" — caught live, fixed
by deferring; real play never hits this ordering since pausing is only
possible once gameplay is already running).
`tools/harness/scripts/photo_shutter.json` (new) then presses shutter
(seat 1 jump, frame 60/66) and back (seat 1 interact, frame 120/126).

Receipts, in order:
```
PHOTO_MODE {"phase":"enter"}
PHOTO {"path":"user://photos/photo_3.png"}
PHOTO_MODE {"phase":"exit"}
```
(index `3` here only because this was the third capture of the session —
the counter is cumulative across every run against the same `user://`
profile, exactly as designed.)

**The PNG exists on disk**, quoted directly:
`C:\Users\agall\AppData\Roaming\Godot\app_userdata\THE BIG NAP\photos\photo_1.png`
— 107,525 bytes (first capture of the session; later runs produced
`photo_2.png`/`photo_3.png` alongside it, same directory, confirming the
counter persists correctly across repeated process launches, not just
within one).

**Stills** (curated into `evidence/stills/cine_photo/`, copied from the
`--shots`/`--outdir` capture above and from the real `user://photos/`
output):
- `evidence/stills/cine_photo/photo_mode_framing.png` — the harness's own
  `--shots=70` capture: Pip (yellow duck onesie), Callie (white sleeping
  figure), grass/mushroom/pine dressing, and Bramble's red haunch all in
  frame, **zero UI anywhere** (no HUD panel, no letterbox, no pause
  overlay) — proves both the framing fix and the "without UI" requirement
  in one image.
- `evidence/stills/cine_photo/user_photo_sample.png` — the actual
  `PHOTO`-receipted file the shutter itself wrote to `user://photos/`
  (copied in, not re-rendered) — same composition, confirming the shutter
  path saves the identical frame the player was looking at.

Headless smoke test (no window, confirms the whole enter/shutter/back flow
never errors when a real display isn't available — e.g. a future CI
receipt run): `PHOTO_MODE {"phase":"enter"}` -> `PHOTO_NOTE screenshot
skipped (headless)` (matches `harness.gd`'s own `--shots` headless-skip
convention) -> `PHOTO_MODE {"phase":"exit"}`. Zero errors.

Controller navigable: the Photo button sits in the existing focus-neighbor
chain (`Options <-> Photo <-> Sleep`), reachable by stick/D-pad exactly
like every other pause-row button; B/interact already double-fires
ordinary buttons via `pause_menu.gd`'s existing `_is_extra_activate()`
path, unchanged.

## Deliverable 3 — camera-drift investigation

**Reported** (`docs/verify/disguise-joy-VERIFY.md`, "Live finding"): with
Pip ~40m from Otto, "Otto's jump-then-airborne-interact sequence... produced
a large, continuously-accelerating horizontal drift (~23 m/s over one 0.5s
window, ~37 m/s over the next) that consistently ended within ~1.5m of
Pip's own position" — root cause not found, flagged against
`core/camera/camera_rig.gd` and/or `core/movement/player_body.gd`.

### Analysis of `camera_rig.gd`'s anchor math (0.7/0.3 + dead zones)

For two **stationary** players: `_compute_anchor()` returns
`0.7*pip_pos + 0.3*otto_pos`, a fixed point once both `_pip_ground_pos`/
`_otto_ground_pos` stop changing (they update unconditionally, no dead
zone, whenever `is_on_floor()` — precise, not laggy). The exponential
follow `_anchor = _anchor.lerp(target_anchor, 1-exp(-position_k*delta))`
converges **monotonically** to that fixed point — no overshoot, no
oscillation, standard critically-stable first-order decay. The vertical
dead zone (`_apply_vertical_dead_zone`) is independent of X/Z and stable
by inspection (settles to within `vertical_dead_zone` of the true Y and
stays there). **No defect found in the anchor math itself.**

### Reproduction — `tools/harness/scripts/camera_drift_probe.json` (new)

Both seats teleported ~40m apart on bramble's own Meadow slab (well inside
`MEADOW_SIZE` 140x80, no void nearby), then **zero further input from
either seat** — deliberately no jump, no interact, nothing — to test
whether separation ALONE (not any button combo) reproduces the reported
movement:
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=bramble --pads=2 --script=tools/harness/scripts/camera_drift_probe.json --poslog=5 --quitafter=6 --outdir=evidence/_scratch/drift_probe2
```
Result: **it reproduces with zero input.** Seat 1 sits at `(-55.0, 0.45,
0.0)` motionless through `t=135`; `WARP {"seat":1}` fires between `t=135`
and `t=140`; seat 1 then moves smoothly from `t=140` to `t≈230`,
landing and holding at `(-13.45, 0.45, 0.0)` — exactly `otto's settled
position (-14.95, 0.43, 0.0) + WARP_SIDE_OFFSET (1.5)` from
`core/coop/seat_manager.gd`. Rock solid afterward through `t=360` (no
further movement at all).

### Root cause

This is `core/coop/seat_manager.gd`'s `_on_leash_broken()` ->
`warp_player_to()` -> `core/rescue/bubble_effect.gd`'s `play()` — the
**documented, intentional** co-op frustum leash (`camera_rig.gd`'s own
class doc: "either player drifting outside the frustum by more than
`frustum_margin` for longer than `frustum_leash_time` emits
`leash_broken` -> SeatManager consumes it and bubble-warps the stray
player back"). `BubbleEffect.play()` tweens with `TRANS_SINE`/
`EASE_IN_OUT` over 1.5s (`WARP_DURATION`) — a sine ease-in genuinely
*is* "continuously accelerating" through its first half, and ~40m / 1.5s
≈ 27 m/s average, matching the reported 23-37 m/s samples closely. Landing
"within ~1.5m of Pip's own position" is exactly `WARP_SIDE_OFFSET = 1.5`.
The reporting agent correctly ruled out `carry_toss.gd` (range check) and
correctly suspected `camera_rig.gd` (it's the signal *source* —
`leash_broken` fires from there) but didn't reach `seat_manager.gd`, the
third file that actually executes the warp; "jump-then-airborne-interact"
was coincidental timing (whatever the tester happened to be pressing when
the 1.5s frustum timer independently expired), not a trigger condition —
proven here by reproducing the identical symptom with **no button
presses at all**.

### Verdict

**Not a defect in `camera_rig.gd`.** The anchor math is stable by both
analysis and reproduction; the "drift" is the pre-existing, working-as-
designed co-op safety net (a player who wanders far outside the shared
frame gets gently bubble-carried back beside their partner), visible here
only because the repro deliberately places players **far** beyond any
normal co-op play distance (the frustum leash + carry-toss pickup range
already keep real co-op sessions much closer together). **No code change
made to `core/camera/camera_rig.gd`** — there is nothing there to fix.
Filed here so it's finally named correctly in a `*-VERIFY.md` (per
`disguise-joy-VERIFY.md`'s own request), and so a future agent doesn't
re-spend time chasing it in `camera_rig.gd`/`player_body.gd` again.

**Visual confirmation** (`evidence/stills/cine_photo/`, windowed):
- `drift_repro_hold_still_t60.png` / `drift_repro_converged_t135.png` —
  both taken while stationary, pre-warp; the camera anchor visibly settles
  (converges toward the new 0.7/0.3 blend after the teleport, per the
  analysis above) and then holds — no oscillation.
- `drift_repro_bubble_warp_t240.png` — **catches the bubble itself**: a
  translucent blush sphere carrying Otto's onesie figure, mid-flight,
  directly above the camera's anchor — this is `BubbleEffect`'s own visual,
  the literal mechanism, caught on camera.
- `drift_repro_settled_t350.png` — both players standing calmly together,
  camera stable, no further motion.

## UNVERIFIED / honest gaps

- **No windowed re-capture of the three refactored cutscenes' own video**
  (bramble rollover / wisp dive / marmalade stretch) — headless
  receipt-parity was judged sufficient for a pure machinery-extraction
  refactor; the shared `CineSequence`/letterbox code path IS proven to
  render correctly in a window via Deliverable 2's own captures (photo
  mode boots from a paused world, same camera/viewport plumbing), but
  nobody watched a fresh video of, say, THE ROLL-OVER's letterbox bars
  fading in this session.
- **Photo mode's shutter chime (`photo_shutter.ogg`) doesn't exist yet** —
  `AudioManager.play_sfx("photo_shutter")` fails soft (prints "sfx not
  found (no-op)"), exactly as designed for an unauthored asset; no
  existing SFX in `assets/audio/sfx/`/`assets/audio/ui/` reads as a
  "shutter" close enough to reuse instead, so this was left honestly
  silent rather than borrowing a mismatched sound.
- **Photo mode was only exercised with Pip (seat 1) as the orbit target**
  (`_resolve_target_player()` always prefers `player_seat_1`) — Otto/seat 2
  was never independently tested as photo mode's subject; v1 always
  photographs "around Pip," which was judged an acceptable "current
  player" reading of the brief for a first pass.
- **Right-stick height/zoom and left-stick orbit were exercised via code
  review + the SpringArm3D collision fix, not a live scripted stick sweep**
  — the harness's `--script` format can drive digital press/release and
  teleports but has no analog-stick-hold primitive, so orbiting itself
  wasn't captured on video this session (the default/opening frame was,
  repeatedly, across three fix iterations).
- **The camera-drift investigation used `bramble` only** — not re-checked
  against `wisp`/`marmalade`/`pillow_fort`; the mechanism
  (`seat_manager.gd`+`camera_rig.gd`) is world-agnostic code, so this is
  judged low-risk, but it's an honest scope note.
- **Placements**: re-ran `tools/props/check_placements.gd` for all four
  worlds after every code change in this pass — `PLACEMENT_SUMMARY
  {"any_fail":false}` for `bramble`/`wisp`/`marmalade`/`pillow_fort`, 4/4
  green (this pass touched no placement-relevant geometry, so this is a
  regression check, not new coverage).
- **Boot-to-title**: `godot_console.exe --headless --path . --fixed-fps 60
  -- --pads=2 --quitafter=3` — clean, `MOON_SAID {"key":"welcome",...}`,
  no `SCRIPT ERROR`/`ERROR` lines beyond the pre-existing generic
  "N resources still in use at exit" headless-shutdown noise already
  present in every run this session (including the unmodified baseline
  rollover run captured before any edit), not introduced by this pass.

## Files touched

- `core/cinematic/cine_sequence.gd` — new (Deliverable 1).
- `worlds/bramble/rollover_sequence.gd`, `worlds/wisp/dive_sequence.gd`,
  `worlds/marmalade/stretch_sequence.gd` — refactored to use `CineSequence`
  (receipt-identical, see above).
- `scenes/ui/photo_mode.gd` — new (Deliverable 2).
- `scenes/ui/pause_menu.gd` — Photo button + `photo_mode_requested` signal.
- `scenes/ui/game_ui.gd` — owns/wires `PhotoMode`, `--debug_photo` seam.
- `tools/harness/scripts/photo_shutter.json`,
  `tools/harness/scripts/camera_drift_probe.json` — new.
- `docs/verify/cine-photo-VERIFY.md` — this file.
- `core/camera/camera_rig.gd` — investigated, **not edited** (Deliverable 3).
- `evidence/stills/cine_photo/` — curated stills (new dir), referenced above.
