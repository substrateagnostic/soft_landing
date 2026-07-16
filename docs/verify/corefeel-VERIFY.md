# corefeel-VERIFY.md — core-feel build (state machine, camera, rescue, co-op)

Engine: `D:\Tools\godot\godot_console.exe` → `4.6.2.stable.official.71f334935`.
Built against the live worktree while `worlds/**` and `tools/harness/**` were
being built concurrently by other agents (their files are read, never
written, in everything below).

## a) Headless import

Command:
```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path D:\Projects\soft_landing
```
Output (trimmed): `[ DONE ] first_scan_filesystem`, `[ DONE ]
loading_editor_layout`, exit code `0`. Zero script errors on the final
(post-fix) pass.

## b) Headless boot — CameraRig instantiates, no errors

Command:
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --quitafter=4
```
Output (verbatim, final clean pass):
```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

HARNESS_FLAGS {"quitafter":"4","skipmenu":true}
CAMERA_RIG_READY
WORLD_READY {"id":"pillow_fort","objectives":0}
MOON_SAID {"key":"new_area","text":"A new place to explore. Let's see what's waiting."}
EVT {"seat":1,"t":2,"type":"landed"}
EVT {"seat":2,"t":2,"type":"landed"}
HARNESS_NOTE quitafter fallback fired (harness-level timer, 4.0s)
```
`CAMERA_RIG_READY` (printed from `CameraRig._ready()`) confirms the rig
instantiated under `CameraRigSlot` and initialized (SpringArm3D shape/mask,
both players excluded from its collision cast). Both players land on the
real `pillow_fort` world's floor within 2 physics frames of spawn — clean
integration against another agent's already-built world.

## c) Property — rescue (`--testfall`)

`SoftLanding._ready()` starts a 1s timer behind `Harness.flag("testfall",
false)` that teleports Pip to `(0, -30, 0)`; a `--testfall`-gated listener
on `player_rescued` prints Pip's final Y so the receipt proves recovery, not
just that the RESCUE line printed.

Command:
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --testfall=true --quitafter=6
```
Output (verbatim, trimmed to the relevant lines):
```
HARNESS_FLAGS {"quitafter":"6","skipmenu":true,"testfall":"true"}
CAMERA_RIG_READY
WORLD_READY {"id":"pillow_fort","objectives":0}
MOON_SAID {"key":"new_area","text":"A new place to explore. Let's see what's waiting."}
EVT {"seat":1,"t":2,"type":"landed"}
EVT {"seat":2,"t":2,"type":"landed"}
RESCUE {"seat":1}
AudioManager: sfx not found (no-op): res://assets/audio/sfx/bubble_catch.ogg
TESTFALL_RESULT {"above_floor":true,"seat":1,"y":1.45018577575684}
EVT {"seat":1,"t":246,"type":"landed"}
HARNESS_NOTE quitafter fallback fired (harness-level timer, 6.0s)
```
`RESCUE {"seat":1}` prints the instant the fall-below-floor is detected
(`global_position.y < rescue_floor_y`, wired from
`pillow_fort.rescue_floor_y()` via `main.gd._setup_coop()`). Pip is caught
in a `BubbleEffect`, floated back to the last sampled safe-ground position
over 2.5s, popped, and control restored — `TESTFALL_RESULT` proves the
final Y (`1.45`) is above the rescue floor, and the trailing `landed` EVT
confirms Pip is standing on real ground again, not just floating. Missing
`bubble_catch.ogg` fails soft (`AudioManager`'s documented no-op path) —
expected, no SFX assets exist yet.

## d) Grep — no right-stick, no Input reads in camera_rig.gd

Commands:
```
rg "axis.*[23]|RIGHT_X|RIGHT_Y|right_stick|right stick" D:\Projects\soft_landing\core --glob "*.gd"
rg "Input\." D:\Projects\soft_landing\core\camera
rg "\"axis\":\s*[23]" D:\Projects\soft_landing\project.godot
```
Output: no matches in any of the three (the one `Input` hit in
`core/camera/` is the doc-comment line "NEVER reads Input.", not a call).
`camera_rig.gd` reads only `PlayerBody.velocity`/`.global_position` and
physics-space queries (`intersect_point`, `intersect_ray`) — no joypad axis
2/3 anywhere in `core/` or `project.godot`'s `[input]` section.

## Extra integration smoke test (not a required item, run for confidence)

Command:
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --script=tools/harness/scripts/first_steps.json --quitafter=8
```
Notable output: both `seat 1` (real input) and `seat 2` (Otto) fire a
`jumped` EVT at the same physics frame when Pip jumps at frame 190 — solo
mode (no simulated pads) puts Otto under `BuddyAI`, and `_on_pip_jumped()`
correctly mirrors the jump since Otto is grounded and within
`jump_mirror_distance` of Pip. No script errors for the full 8s run,
confirming `PlayerBody`, `CameraRig`, `BuddyAI`, and `SoftLanding` all run
clean together against the real `pillow_fort` world.

## Bugs found and fixed during this pass

1. **`camera_hint.gd`: `Member "priority" redefined (original in native
   class 'Area3D')`.** The pre-existing scaffold declared
   `@export var priority: int = 0` on a script extending `Area3D` —
   `Area3D` already has a native `priority: int` property (used for area
   processing order). Godot 4.6.2 treats the re-declaration as a hard
   compile error. Fix: removed the redundant `@export`; the SPEC.md
   contract ("priority int") is satisfied by the inherited native property
   as-is, with zero change needed to the worlds agent's
   `hint.priority = 0` code in `pillow_fort.gd`.
2. **Reproducible Godot 4.6.2 headless GDScript bug: `Could not resolve
   external class member "priority"`** when a script accesses a typed
   instance member of an externally-`class_name`'d class through a value
   obtained at runtime (a physics query result, in `camera_rig.gd`'s case)
   during a `--headless` (non-editor) run. Confirmed independently by the
   parallel worlds-agent's own minimal repro scripts in
   `worlds/_scratch_test/` (same failure on a throwaway `HintCopy` class
   with nothing else in common). Worked around in `camera_rig.gd` by
   reading `CameraHint`'s `yaw_degrees`/`blend_time`/`priority` via
   `Object.get("...")` (dynamic property lookup) instead of static typed
   member access — this sidesteps the compiler's external-member
   resolution path entirely and is unaffected by whatever triggers the
   underlying engine bug.

## Deviations from the brief (noted per house convention)

- **Two-stage yaw damping.** The brief names three yaw-related constants
  (`position_k`, `yaw_k`, and an explicit `k 0.8` for the velocity-leash
  fallback) without fully specifying how they compose. Implemented as:
  an inner leash-target heading eased toward Pip's velocity heading at
  `leash_k` (0.8, heavily damped, "no jitter when circling"), and the
  rig's actual yaw eases toward whichever target is active — the leash
  target at `yaw_k` (2.0), or a `CameraHint`'s `yaw_degrees` at a rate
  derived from that hint's own `blend_time` — so all three named rates do
  distinct, meaningful work.
- **Added `pitch_k` (@export, default 3.0) to `CameraRig`.** The brief
  specifies pitch *targets* (base -35°, gap -50°) but no pitch smoothing
  rate; per AGENTS.md ("all feel numbers MUST be @export"), added a
  dedicated export rather than silently reusing `position_k`.
- **`main.gd`'s `_pip`/`_otto` `@onready` vars retyped `CharacterBody3D` ->
  `PlayerBody`.** Needed for static-typed calls into the new API
  (`register_players`, `carry_toss.setup`, etc.); no behavior change,
  within the licensed `main.gd` edit scope.
- **Frustum-leash margin test** (`_is_outside_frustum_by_margin` in
  `camera_rig.gd`) assumes `Camera3D.get_frustum()` returns outward-facing
  plane normals (positive `Plane.distance_to(point)` = outside) — standard
  Godot convention, but no headless test exercises real co-op
  out-of-frustum geometry (would need two simulated pads plus a world with
  room to separate players), so this path is code-reviewed but not
  property-tested in this pass.
- **BubbleEffect is shared** by `soft_landing.gd` (rescue), `seat_manager.gd`
  (frustum-leash warp), and `buddy_ai.gd` (>12m lag warp, via
  `SeatManager.warp_player_to`) — one visual vocabulary for every "gentle
  catch," per the brief's explicit instruction that leash-warp "same visual
  as rescue."

## @export fields added

`core/movement/movement_tuning.gd` (existing fields untouched):
`stretch_scale`, `squash_scale`, `squash_duration`, `squash_spring_decay`.

`core/camera/camera_rig.gd` (new script, all exports): `position_k`,
`yaw_k`, `leash_k`, `pitch_k`, `arm_length`, `base_pitch_degrees`,
`gap_pitch_degrees`, `vertical_dead_zone`, `pip_weight_coop`,
`otto_weight_coop`, `leash_speed_threshold`, `pitch_probe_ahead`,
`pitch_probe_height`, `gap_probe_distance`, `frustum_margin`,
`frustum_leash_time`, `sphere_cast_radius`, `sphere_cast_margin`.

`core/coop/carry_toss.gd`: `carry_range`, `toss_up_velocity`,
`toss_forward_velocity`, `hop_down_lift`.

`core/coop/buddy_ai.gd`: `follow_distance`, `jump_mirror_distance`,
`lag_warp_distance`, `stop_threshold`.

`core/rescue/bubble_effect.gd`: `float_duration`, `lift_height`,
`pop_scale_time`.

`core/readability/blob_shadow.gd`: `max_distance`, `footprint`,
`shadow_alpha`. `core/readability/landing_ring.gd`: `min_scale`,
`max_scale`, `height_for_max_scale`, `ray_length`, `ring_color`.
