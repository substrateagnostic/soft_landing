# moveset-v2-VERIFY.md — D17 moveset ladder (flutter / glide / pound-bounce) + D18 camera nudge

served_model: claude-sonnet-5 (Sonnet 5), acting as the movement build agent
directly (no external model calls this pass).

Engine: `D:\Tools\godot\godot_console.exe` → `4.6.2.stable.official.71f334935`.
All property runs use `--fixed-fps 60` (deterministic — repeat runs produced
byte-identical EVT frames, spot-checked below). All commands run from
`D:\Projects\soft_landing`. Territory: `core/movement/**`, `core/coop/**`,
`core/camera/**`, `project.godot`'s `[input]` section only, and
`tools/harness/scripts/*.json` (new files only — `harness.gd` itself was
read, never edited). `worlds/**`, `core/env/**`, `scenes/**` were read-only.

## a) Headless import — clean

```
godot_console.exe --headless --editor --import --quit --path D:/Projects/soft_landing
```
Output: `[ DONE ] first_scan_filesystem`, `[ DONE ] update_scripts_classes`
(picks up no new `class_name`s — none added), `[ DONE ] loading_editor_layout`.
Exit code `0`, zero script errors, both before and after the frame-ordering
fix described in §f.

## b) Headless boot — clean, both new input actions and D18 camera code present

```
godot_console.exe --headless --path D:/Projects/soft_landing -- --skipmenu --pads=2 --quitafter=4
```
```
HARNESS_FLAGS {"pads":"2","quitafter":"4","skipmenu":true}
EVT {"mode":0,"mode_name":"COOP","t":1,"type":"mode_changed"}
CAMERA_RIG_READY
WORLD_READY {"id":"pillow_fort","objectives":0}
EVT {"seat":1,"t":3,"type":"landed"}
EVT {"seat":2,"t":3,"type":"landed"}
HARNESS_NOTE quitafter fallback fired (harness-level timer, 4.0s)
```
The only errors in a full boot are pre-existing and unrelated to this pass:
`res://core/env/plush_material.tres:8 - Parse Error: Expected 4 arguments
for constructor` inside `pillow_fort.gd`'s `_add_cushion` — `core/env/**` and
`worlds/**` are another agent's in-flight work (visible as untracked in
`git status` before this session started), not touched here, and the error
is unrelated to movement/camera/coop.

## c) FLUTTER property — `tools/harness/scripts/flutter_gap.json`

```
godot_console.exe --headless --path D:/Projects/soft_landing --fixed-fps 60 -- --skipmenu --pads=2 --script=tools/harness/scripts/flutter_gap.json --quitafter=8
```
```
EVT {"seat":1,"t":51,"type":"jumped"}
EVT {"seat":1,"t":106,"type":"landed"}      <- episode A (single jump): 55-frame airtime
EVT {"seat":1,"t":321,"type":"jumped"}
FLUTTER {"seat":1}                          <- second tap, still rising, well before apex
EVT {"seat":1,"t":387,"type":"landed"}      <- episode B (flutter): 66-frame airtime
```
`--poslog=2` peak-height readout (rest Y = 0.45; teleport landed at 0.45
after settling):
```
episode A peak: t=80..82  y=2.02
episode B peak: t=358..362 y=2.55   (poslog=4 run) / y=2.64 (poslog=1 run, finer sampling caught the true peak between samples)
```
PASS: episode B's airtime (66 frames, jumped→landed) exceeds episode A's (55
frames) by 11 frames (183 ms) and its peak height (~2.55–2.64) exceeds
episode A's (~2.02) by ~0.5–0.6 m — matching the tuned
`flutter_height_mult=0.6` boost. Re-ran twice back-to-back: identical EVT
frames both times (51/106/321/387) — deterministic under `--fixed-fps 60`.

Design note (in the script's own `description`): an earlier draft added a
forward-hold to literally cross a gap. Pillow_fort's fort wall sits only
~3.5 m from the chosen spawn point and capped *both* episodes' horizontal
travel at the identical distance, which proved nothing extra — dropped in
favor of the pure-vertical height/airtime proof, which is the
geometry-independent version of the same claim (more hangtime at any
nonzero forward speed is strictly more horizontal reach).

## d) GLIDE property — `tools/harness/scripts/glide_descent.json`

```
godot_console.exe --headless --path D:/Projects/soft_landing --fixed-fps 60 -- --skipmenu --pads=2 --script=tools/harness/scripts/glide_descent.json --quitafter=25
```
```
EVT {"seat":1,"t":102,"type":"landed"}      <- episode A (free fall from y=15): 72-frame airtime
EVT {"seat":1,"t":701,"type":"jumped"}      <- episode B: ground jump while still grounded
GLIDE_START {"seat":1}                      <- fires ~2 ticks after the teleport, once genuinely falling
EVT {"seat":1,"t":1003,"type":"landed"}     <- episode B: 298-frame airtime (from teleport@705) for the SAME 15m drop
```
`--poslog=1` slope sample (Y per tick) immediately after `GLIDE_START`,
teleport@705:
```
t=705 y=15.00
t=706 y=14.99
t=710 y=14.94   (-0.06 over 5 ticks -> ~0.72 m/s, still ramping toward the 3.0 m/s cap)
t=740 y=13.64   (a steady ~0.037/tick = 2.2 m/s once near the cap)
```
Compare episode A's free-fall slope over the same early window (t=30..40,
before terminal velocity is even reached): roughly -0.32/tick ≈ 19 m/s.
PASS: a ~4.1x longer total airtime for an identical 15 m drop, and a
visibly shallower per-tick slope throughout — glide descends far slower
than free fall, capped near the tuned 3.0 m/s.

**Design note — a genuine `is_on_floor()` caching gotcha found while
measuring, flagged for the director (not fixed, out of my file
boundary):** `harness.gd`'s `teleport` dev instrument sets
`global_position`/`velocity` directly and does **not** force a fresh
`move_and_slide()`/floor re-check. `is_on_floor()` is a *cached* result from
the character's last `move_and_slide()` call. Teleporting a grounded
character straight into open air therefore leaves `is_on_floor()` reading
stale-`true` for exactly one more physics tick after the teleport — long
enough to hand out one extra tick of `coyote_time` mid-air. `glide_descent.json`
was deliberately designed around this (press-then-hold *while still
genuinely grounded*, teleport 5 ticks later) rather than fighting it, since
`harness.gd` is outside my edit territory. Anyone writing a future
teleport-then-immediately-jump property test should budget at least
`coyote_time` (12 frames) + 1 of margin between a mid-air teleport and a
jump press, or press-and-confirm-grounded first the way this script does.

## e) POUND-bounce property — `tools/harness/scripts/pound_bounce.json`

```
godot_console.exe --headless --path D:/Projects/soft_landing --fixed-fps 60 -- --skipmenu --pads=2 --script=tools/harness/scripts/pound_bounce.json --quitafter=8
```
```
EVT {"seat":2,"t":61,"type":"jumped"}
POUND_START {"seat":2}
POUND_LAND {"seat":2}
EVT {"seat":2,"t":97,"type":"landed"}       <- Otto's own landing, same tick as POUND_LAND
EVT {"seat":1,"t":162,"type":"landed"}      <- Pip, who never received any input, launched and landed
```
`--poslog=1` on Pip (seat 1), who receives zero scripted input in this run:
```
t=97  y=0.45   (Otto lands/pounds this same tick — no change yet)
t=99  y=0.59   (launch visibly begins 2 ticks later)
t=131..135 y=2.77  (peak — Pip's own normal single-jump apex is ~2.02, see §c episode A)
```
PASS: Pip — grounded the whole script, never touched a button — gets
launched purely by Otto's pound shockwave to ~2.77 (a ~0.75 m higher apex
than Pip's own normal jump), consistent with the tuned
`pound_launch_mult=1.5` (1.5 × Pip's own `jump_height` = 2.25 m gained,
close to the observed ~2.32 m gained above the 0.45 rest Y, the same small
apex-hang-band excess seen throughout — e.g. §c's 2.02 vs the pure-formula
1.5).

**No-race design note:** `carry_toss.gd` already documented itself as the
sole owner of both interact buttons ("so no two scripts can race on the
same button press" — pre-existing docstring). Rather than add a second
script also reading `p1_interact`/`p2_interact` (which would reintroduce
exactly the race it warns about), pound-bounce is wired as the *fallback*
of that same dispatcher: `try_pickup()`/`_try_solo_toss()` now return
`bool`, and only when carry/toss genuinely doesn't apply does the press
fall through to `PlayerBody.try_pound()`. This also gives "not
carrying/carried" for free — `_carrying` already routes to `hop_down()`/
`toss()` first, so pound is structurally unreachable while carrying or
carried, no separate flag needed.

## f) A real bug found and fixed while measuring §d (frame-ordering)

First implementation had `_maybe_start_glide()` run before the jump-buffer
was resolved each frame. Symptom, caught by the glide measurement pass, not
by inspection: a press-and-hold gesture that began while the character was
already falling with zero coyote available produced a spurious one-tick
`GLIDE_START` print immediately superseded by `FLUTTER` the very next tick
— the *physics* outcome was always correct (the flutter's hard velocity
`SET` always overwrote whatever glide had done for that one 16 ms tick), but
the receipt was misleading. Root-caused via tick-by-tick `--poslog=1`
tracing (not guessable from reading the code alone — Godot's
`is_action_just_pressed()` timing relative to a script-injected
`Input.action_press()` fired from the `physics_frame` signal callback did
not behave the way a first read of the docs suggested).

Fix (in `player_body.gd`, my territory): reordered `_physics_process()` so
`_update_jump_buffer()` + `_try_jump()` — the functions that can hard-`SET`
`velocity.y` positive — always run *before* `_maybe_start_glide()`, which
already has a `velocity.y >= 0.0` guard. A same-tick jump/flutter now
naturally blocks glide-entry that same tick without any extra
"was this a fresh press" bookkeeping (an earlier, more fragile attempt at
that bookkeeping is what's replaced here). Re-verified: `flutter_gap.json`
and `glide_descent.json` both re-run clean after the reorder (identical EVT
frames both before-and-after for the flutter script, since that property
never touched the buggy path; the glide script is the one that changed
from noisy to clean).

## g) Moving-platform audit (research flag, D17 item 6)

Read (never edited) `worlds/bramble/breathing_chest.gd` and its placement in
`worlds/bramble/bramble.gd`. Findings:

1. **`BreathingChest` already does the right thing**: `extends
   AnimatableBody3D`, `sync_to_physics = true` set in `_ready()`, position
   driven by `position.y = _rest_y + sin(...)` in `_physics_process()` —
   exactly the pattern `docs/research/v2/movement_feel.md` §5 recommends.
   No fix needed there.
2. **`PlayerBody` (my file) never explicitly set `platform_floor_layers`**,
   relying on the engine default. Set it explicitly to `0xFFFFFFFF` (all
   layers) so velocity inheritance is never silently gated by whatever that
   default actually is — a one-line, defensive addition in my own file.
3. **`platform_on_leave` was `PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY`**
   (vertical-only momentum inheritance on jump-off). For the *current*
   chest — a pure vertical oscillation, zero horizontal velocity ever —
   this is behaviorally identical to the research doc's recommended
   `PLATFORM_ON_LEAVE_ADD_VELOCITY` (full momentum inheritance). Changed to
   `ADD_VELOCITY` anyway, in my own file, to future-proof for any
   horizontally-moving platform a later world adds (a cart, a swing) —
   today's behavior is unchanged, tomorrow's is correct by default.
4. **Empirical confirmation** (not just code-read) that a player actually
   rides the chest, `--world=bramble --pads=1`, teleport onto the chest at
   `(-5, 8.0, 0)`, `--poslog=15`:
   ```
   t=45  y=8.41
   t=75  y=8.55   <- peak (chest rest-top ~7.95 + amplitude 0.6 = 8.55, exact)
   t=225 y=7.35   <- trough (7.95 - 0.6 = 7.35, exact)
   t=375 y=8.55   <- second peak, 300 ticks (5.0s) after the first, matching CHEST_PERIOD=5.0 exactly
   ```
   `x` stayed pinned at `-5.0` the entire run (no drift) — the player rides
   the platform correctly, matching amplitude and period to the decimal.
5. **Carry/toss manual-reposition gotcha** (flagged by the research doc,
   confirmed by code-read, not empirically forced since nothing in the
   current game carries a player onto a moving platform today): `move_and_slide()`
   is what refreshes a `CharacterBody3D`'s internal platform-tracking state.
   `carry_toss.gd`'s `hop_down()`/`toss()`/`_release_from_socket()` set
   `global_position` directly, bypassing `move_and_slide()` for that one
   frame. If a future world ever drops/tosses a player exactly onto a
   moving platform, platform-velocity inheritance would lag by one physics
   tick (16 ms) — imperceptible today, but worth a comment if a world agent
   ever builds a "toss Pip onto the moving cart" puzzle. Documented here per
   the brief's own instruction, not fixed (would require either editing
   `worlds/**`'s use of it or restructuring `carry_toss.gd`'s reposition
   path beyond what this pass needed).

## h) Camera D18 — right-stick nudge

**Verified (headless, code-level):**
- New input actions (`p1_camera_left/right/up/down`,
  `p2_camera_left/right/up/down`, joypad axis 2/3, deadzone 0.3, matching
  the existing move-stick pattern) added to `project.godot`'s `[input]`
  section only.
- `CameraRig._update_camera_nudge()` reads them via `Input.get_vector()`
  (never required — returns `Vector2.ZERO` with no controller, confirmed by
  the clean §b boot with zero errors) and accumulates a clamped
  `_manual_yaw_offset`/`_manual_pitch_offset`, additive on top of the
  existing hint/leash-computed `_yaw`/`_pitch` — hints and the velocity
  leash still fully own the base yaw, satisfying "CameraHint volumes still
  win (blend)" by construction (they're computed exactly as before; the
  nudge just adds a small delta on top).
- Auto-recenter (`camera_recenter_k`, default 2.0, after
  `camera_recenter_delay=1.5s` of stick silence) and the `manual_camera`
  `@export` (disables recenter, options-menu hook) are both present and
  read every physics frame in `_update_camera_nudge()`.
- Full boot (§b) with the new code active for the whole run: zero errors,
  `CAMERA_RIG_READY` prints, camera tracks players normally the entire 4s
  run.
- `docs/verify/corefeel-VERIFY.md`'s old §d ("no Input reads in
  camera_rig.gd") is now stale by design — `docs/DECISIONS.md` D4 already
  documents this exact supersession ("*Right-stick clause superseded
  2026-07-16 → D18*"), so this isn't a regression, it's the planned
  upgrade landing.

**UNVERIFIED-manual:** the actual visual feel/direction of the nudge (does
right-stick-right pan the camera right, does up tilt up, does it feel
"gentle") cannot be exercised through the harness — `harness.gd`'s script
format only expresses `move` (hardcoded to the four `move_left/right/up/down`
actions), `teleport`, `pads`, and generic button press/release; there is no
event type for injecting an arbitrary named action's analog strength
(`p1_camera_left`, etc.), and extending `harness.gd` to add one is outside
my file boundary (`tools/harness/harness.gd` itself is explicitly not mine
to edit — only `tools/harness/scripts/*.json`). The Y-axis sign convention
(negated so stick-up tilts the camera up, matching the existing
`p1_move_up` axis-value convention documented in-code) is implemented per
the "never inverted" floor but has not been confirmed with a real gamepad.
**Next step for whoever picks this up:** plug in a controller, boot with
`--skipmenu --pads=1` (no `--headless`), nudge the right stick, eyeball it.

## i) Regression — `tools/harness/scripts/prop_switch_rescue.json` still PASS

```
godot_console.exe --headless --path D:/Projects/soft_landing --fixed-fps 60 -- --skipmenu --pads=1 --script=tools/harness/scripts/prop_switch_rescue.json --poslog=20 --quitafter=15
```
```
RESCUE {"seat":1}     <- once, at t=180, after the bramble->pillow_fort switch + fall
PLAYER_POS {"seat":1,"t":200,"x":-58.3,...}   -> recovers toward fort spawn coords over the float
...
EVT {"seat":1,"t":366,"type":"landed"}
RESCUE {"seat":1}     <- second fall (t=700) also rescues cleanly, no loop
EVT {"seat":1,"t":886,"type":"landed"}
```
Exactly one `RESCUE` per fall, both recover to fort-spawn-region coordinates
(final resting `PLAYER_POS` well within `|x|<14, |z|<14, y>0`), matching the
script's own documented PASS criteria — rescue is unaffected by the D17/D18
changes.

**Bonus regression** (not one of the three named scripts, but `carry_toss.gd`'s
dispatcher was directly restructured for §e, so worth confirming):
`tools/harness/scripts/gate2_toss.json` still produces exactly `CARRY {}` /
`TOSS {}` with no spurious `POUND_START` anywhere in the run — the
pickup-succeeds path still short-circuits before ever reaching
`try_pound()`.

## Deviations from the brief (house convention)

- **Pound-bounce is symmetric (either Pip or Otto can pound), not
  Otto-exclusive.** The brief text I was given says "tap interact while
  airborne (and not carrying/carried) → ... any partner/player within ~3m
  who is grounded gets launched" — generic language, no character
  restriction. (The *research* doc, `movement_feel.md`, had speculated
  "Otto's verb" as one option among several, not a requirement.) Symmetric
  keeps the implementation simpler (no carrier-role plumbing) and is
  consistent with the co-op floor's general egalitarian design (both seats
  already own jump/interact contextually). Easy to restrict to Otto later
  by adding a `seat == 2` check in `try_pound()` if the director wants the
  asymmetric-verb framing instead.
- **Buddy AI does not use flutter for gap-following.** Explicitly permitted
  as "nice-to-have, skip if fragile" — `buddy_ai.gd` untouched.
- **`_flutter_eligible()`/`_maybe_start_glide()` list `GLIDE`/`FLUTTER` as
  valid source states** even though, per §f's analysis, a fresh tap can only
  ever be observed by the buffer after a release (glide always exits to
  `FALLING` before a new press registers) — kept for defensiveness/future
  input models (e.g. a hypothetical simultaneous multi-touch source) rather
  than trimmed, since it's free and harmless.
- **`platform_on_leave`/`platform_floor_layers` changed** in `player_body.gd`
  as part of the moving-platform audit (§g) — not explicitly one of the
  three named deliverables, but directly requested by "if something's
  wrong there, document the exact fix" and squarely inside my own file.

## @export fields added

`core/movement/movement_tuning.gd` (both `data/tuning/pip_movement.tres`
and `data/tuning/otto_movement.tres` updated with matching values —
existing fields untouched): `flutter_height_mult` (0.6), `flutter_duration`
(0.18), `glide_gravity_mult` (0.4), `glide_terminal_velocity` (3.0),
`glide_air_control_mult` (1.3), `pound_hang_duration` (0.15),
`pound_drop_speed` (14.0), `pound_radius` (3.0), `pound_launch_mult` (1.5).

`core/camera/camera_rig.gd`: `camera_nudge_yaw_degrees_per_sec` (90.0),
`camera_nudge_pitch_degrees_per_sec` (40.0), `camera_nudge_max_yaw_degrees`
(60.0), `camera_nudge_max_pitch_degrees` (20.0), `camera_recenter_delay`
(1.5), `camera_recenter_k` (2.0), `manual_camera` (false).

## Files touched

`core/movement/player_body.gd`, `core/movement/movement_tuning.gd`,
`core/coop/carry_toss.gd`, `core/camera/camera_rig.gd`, `project.godot`
(`[input]` section only), `data/tuning/pip_movement.tres`,
`data/tuning/otto_movement.tres`, `tools/harness/scripts/flutter_gap.json`
(new), `tools/harness/scripts/glide_descent.json` (new),
`tools/harness/scripts/pound_bounce.json` (new), this file (new).
`buddy_ai.gd`, `seat_manager.gd`, `camera_hint.gd`, `harness.gd`, all
`worlds/**`, all `scenes/**` — read only, unmodified.

## UNVERIFIED

- Right-stick nudge visual feel/direction/sensitivity (§h) — needs a real
  gamepad; the harness cannot express an analog-axis script event without
  editing `harness.gd`, which is out of territory.
- `manual_camera=true`'s full-manual behavior — implemented and reads
  correctly (no auto-recenter path taken when true, confirmed by code
  inspection) but likewise not exercisable headless.
- The one-tick platform-velocity-inheritance lag on a manual reposition
  (§g.5) — a real, narrow, currently-inert edge case (nothing in the
  shipped game tosses a player onto a moving platform yet); documented, not
  built into a regression test since there is no current world scenario
  that exercises it.
