# CHARACTER ANIMATION (D19) — VERIFICATION (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe` ->
`4.6.2.stable.official.71f334935`), Windows.
**served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic), running as
the character animation build agent inside a Claude Code session.

Scope: D19 (`docs/DECISIONS.md`) — rig + animate Pip and Otto from the
already-downloaded Meshy assets (`assets/models/meshy/rigged/{pip,otto}/`),
build an AnimationTree-driven locomotion/jump/fall/gesture system, extend
the ModelSlot import seam for rigged scenes, keep procedural squash-stretch
alive on top, add Callie visual-life polish and the face-camera-at-rest
polish item — per `docs/research/v2/character_pipeline.md`.

Built against a live worktree while parallel agents worked on
`core/movement/player_body.gd` (moveset ladder — new `flutter_gap.json`/
`glide_descent.json`/`pound_bounce.json` harness scripts confirm new
PlayerBody states landed during this pass), `core/coop/carry_toss.gd`,
`scenes/main.gd`, `worlds/**`, `scenes/ui/**`, `core/env/**`,
`data/tuning/*.tres`, and more. None of those files were touched by this
pass; every boot/harness run below is against whatever the live working
tree looked like at run time, so it also incidentally proves this feature
survives that concurrent churn.

---

## What shipped

1. **Animation merge tool** — `tools/import/merge_character_anims.gd`
   (`godot_console.exe --headless --path . --script
   tools/import/merge_character_anims.gd`). Loads
   `assets/models/meshy/rigged/<char>/rigged.glb` (mesh + Skeleton3D, 24
   bones, standard `Hips/LeftUpLeg/.../Spine/Head/...` names) plus each
   `anim_<clip>.glb`, and for every character produces:
   - `scenes/players/rigs/<char>_rig.tscn` — the rig with a single
     `AnimationPlayer` whose default (`""`) `AnimationLibrary` holds every
     clip under a clean name.
   - `scenes/players/rigs/<char>_anim_lib.tres` — that same library saved
     standalone.
   - Pip: `idle, walk, run, fall, wave, cheer, pickup, sleep, dance, jump,
     skip`. Otto: same set with `carry` instead of `skip`. Loop flags match
     the brief exactly (idle/walk/run/fall/sleep/skip/carry =
     `LOOP_LINEAR`; jump/wave/cheer/pickup/dance = `LOOP_NONE`).
   - **Root-motion neutralization**: every clip's `Hips` `TYPE_POSITION_3D`
     track has real baked mocap-style translation (confirmed by direct
     inspection — walk/run/jump all translate the hip bone). The merge tool
     freezes X/Z to the first key's value on every key (keeps the natural Y
     bob/squat, removes net horizontal drift) so playback never fights
     `CharacterBody3D`'s own movement — see the tool's own
     `_neutralize_root_horizontal_motion()` docstring for the exact
     property-name inspection that led to this.
   - No BoneMap/`SkeletonProfileHumanoid` retargeting needed or built: every
     per-clip GLB was generated from the *same* Meshy `rig_task_id`
     (`tools/meshy/rig_forge.py`), so all clips share one identical
     skeleton — retargeting (the research doc's §4) is machinery for
     pulling in a *different*-skeleton source (e.g. Mixamo) later; not
     exercised here, documented as such in the tool's header.

2. **`RiggedModelSlot`** (`core/art/rigged_model_slot.gd`, `class_name
   RiggedModelSlot extends ModelSlot`) — points at
   `scenes/players/rigs/<model_id>_rig.tscn` instead of
   `assets/models/meshy/generated/<id>.glb`; same silent-no-op/primitive-
   fallback contract as `ModelSlot` if the rig scene is missing. Emits
   `rig_ready(rig_root, anim_player)` (and exposes `has_rig()` /
   `rig_root` / `anim_player` for the "already happened" half of the
   sibling-`_ready()`-ordering race) once instanced.
   **Real bug found and fixed during this pass** (see §Bug below):
   `RiggedModelSlot` does **not** reuse `ModelSlot._compute_local_aabb()`
   for scaling — that walk is correct for static props but silently
   produces a ~100x-oversized character for a skinned rig. Documented
   in-line in the script; full trace in §Bug.

3. **`CharacterAnimator`** (`core/art/character_animator.gd`) — one added
   under each player's `Visual` node (sibling of `RiggedModelSlot`).
   Builds an `AnimationNodeBlendTree` **procedurally** the first time its
   `RiggedModelSlot` reports a rig, from whichever clips that rig's
   `AnimationLibrary` actually contains (nothing hard-codes "Pip has skip,
   Otto has carry" — confirmed live: Pip's boot receipt lists gestures
   `[wave, cheer, pickup, dance, sleep, skip]`, Otto's lists `[wave, cheer,
   pickup, dance, sleep]` plus a `Carry` **body** input Pip's rig doesn't
   have):
   - `Locomotion`: `AnimationNodeBlendSpace1D` (idle @ 0, walk @
     `move_speed * 0.5`, run @ `move_speed`), driven every physics frame by
     `Vector2(velocity.x, velocity.z).length()` (exponentially smoothed) —
     horizontal speed is a true continuous 0..move_speed range (analog
     stick magnitude), not a discrete gait switch.
   - `BodyTransition`: `AnimationNodeTransition` switching between
     `Locomotion` / `Jump` / `Fall` / (`Carry`, Otto only) — chosen every
     physics frame by `_resolve_body_target()` from `PlayerBody.state`.
     Uses `AnimationNodeTransition`, not a hand-built
     `AnimationNodeStateMachine` graph: it's the officially-simpler node for
     "game code picks the current clip by name every frame," and avoids
     depending on `AnimationNodeStateMachine`'s undocumented-for-4.6.2
     "Any State" wildcard-transition behavior, which this pass did not
     verify exists.
   - `GestureSelect` + `GestureOneShot`: any of
     `wave/cheer/pickup/dance/sleep/skip` present on the rig become a
     fireable one-shot overlay (`play_gesture(name)`), full-body blend
     (`MIX_MODE_BLEND`, 0.15s/0.2s fade in/out), fired manually via the
     `verify_character_stills.gd` tool below (see §UNVERIFIED — no
     in-repo gameplay caller yet, `core/coop/**` is outside this task's
     territory).
   - **Unknown-state fallback** (brief: PlayerBody's `State` enum "MAY GAIN
     NEW ONES like glide/pound"): `_resolve_body_target()`'s `match` covers
     every state that exists today by name (`GROUNDED/CARRIED/BUBBLED` ->
     Locomotion, `RISING/APEX` -> Jump, `FALLING` -> Fall, `TOSSED` ->
     velocity-sign heuristic); the `_` default branch uses only
     `CharacterBody3D.is_on_floor()`, so a state this script has never
     heard of still degrades to Locomotion or Fall instead of erroring —
     directly relevant this pass, since a parallel moveset agent was adding
     new states (`flutter_gap`/`glide_descent`/`pound_bounce` harness
     scripts) concurrently.
   - Root motion OFF, exactly per D19/research-doc §6: the AnimationTree
     only ever selects/blends clips; `CharacterBody3D` position/velocity is
     never read or written here.
   - Squash-stretch verified surviving: `PlayerBody._update_squash_stretch()`
     scales the `Visual` node (this script's parent) every physics frame;
     `CharacterAnimator` never touches `Visual.scale`, only the
     `AnimationTree`'s bone poses inside the rig — two independent
     transform channels, confirmed composing correctly in every screenshot
     below (e.g. `otto_carry_pip.png` shows Otto's pickup-squash and his
     walk-cycle pose at once).
   - **Face-camera-at-rest** (polish item): until the first real movement
     (`velocity` exceeds a small epsilon or `state != GROUNDED`),
     `Visual.rotation.y` eases toward whatever camera is active; latches
     permanently the instant `player_body.gd`'s own
     `_apply_horizontal_movement()` starts writing that same property, so
     they never fight. Verified numerically (§4 below), not just visually.

4. **Callie visual-life polish** (`core/companion/callie.gd`) — behavior
   logic (pickup/set-down/mew targeting/purring/cooldowns) untouched:
   - Breathing scale bob: pre-existing (`_process_napping`, unchanged).
   - **New**: a slow yaw micro-sway while `NAPPING` (`sway_period=7.3s`,
     `±3°`, deliberately off-period from the 5s breath cycle so the two
     never lock into one mechanical-looking loop), re-anchored to whatever
     yaw she's currently facing each time `NAPPING` is (re)entered.
   - **New**: a brief scale pulse (`_play_perk_pulse()`, same tween-squash
     idiom as the existing `_play_flop_tween()`) on every `_play_mew()`
     call — a one-line addition at the end of that existing function, nothing
     upstream of it (targeting/cooldown/audio) changed.

5. **Verification tooling** (`tools/import/verify_character_stills.gd`,
   kept as a re-runnable tool, not scratch) — instantiates the *real*
   `pip.tscn`/`otto.tscn` scenes directly under a bare `SceneTree` root
   (same pattern as `tools/props/check_placements.gd`), drives them via
   `PlayerBody.set_virtual_input()`/`request_jump()`, and captures 7
   close-up PNGs under a hand-placed camera — the game's own world camera
   (bramble's establishing shots) puts characters at a few pixels, useless
   for an "is this skinned, not T-posed" check.

---

## 1. Boot clean

```
D:\Tools\godot\godot_console.exe --path . -- --skipmenu --quitafter=8
```

```
MODEL_SWAP {"id":"pip","rigged":true,"scaled":1.00000009271835}
CHARACTER_ANIMATOR_READY {"body_inputs":["Locomotion","Jump","Fall"],"gestures":["wave","cheer","pickup","dance","sleep","skip"],"player":"Pip"}
MODEL_SWAP {"id":"otto","rigged":true,"scaled":1.00000022007874}
CHARACTER_ANIMATOR_READY {"body_inputs":["Locomotion","Jump","Fall","Carry"],"gestures":["wave","cheer","pickup","dance","sleep"],"player":"Otto"}
MODEL_SWAP {"id":"lantern","scaled":0.262320410476045}
MODEL_SWAP {"id":"cushion","scaled":0.638011298671118}
MODEL_SWAP {"id":"cushion","scaled":0.549398618300129}
MODEL_SWAP {"id":"callie","scaled":0.162508841691823}
CALLIE_COUNT {"count":1}
CALLIE {"state":"napping"}
WORLD_READY {"id":"pillow_fort","objectives":0}
```

No `SCRIPT ERROR` lines. Prop `MODEL_SWAP`s (lantern/cushion/callie) keep
their old, unaffected scale values — the static `ModelSlot` path is
provably untouched.

## 2. Close-up character stills (skinning / pose / no-T-pose)

```
D:\Tools\godot\godot_console.exe --path . --resolution 960x540 --fixed-fps 60 --script tools/import/verify_character_stills.gd
```

7 PNGs in `evidence/stills/v2_characters/`, one `VERIFY_SHOT` receipt line
each with the exact `PlayerBody.state` at capture time:

| File | `player_state` | What it shows |
|---|---|---|
| `pip_idle_closeup.png` | 0 (GROUNDED) | Pip in a relaxed idle pose — arms down/bent, **not** a T-pose |
| `pip_walk_closeup.png` | 0 | mid-stride walk pose, partial-stick speed |
| `pip_run_closeup.png` | 0 | leaning-forward run pose, full-stick speed — visibly distinct from walk |
| `pip_jump_closeup.png` | 1 (RISING) | legs tucked, mid-air, landing ring visible below |
| `pip_fall_closeup.png` | 3 (FALLING) | crouched/tucked falling pose, clearly different from jump |
| `pip_wave_gesture_closeup.png` | 0 | `play_gesture("wave")` fired mid-air-recovery — head/torso turned, distinct from idle |
| `otto_run_closeup.png` | 0 | Otto (bear onesie) mid-stride run, ears/muzzle detail visible |

Distinct, correctly-posed silhouettes across idle/walk/run/jump/fall confirm
the `AnimationTree` is actually switching/blending clips, not stuck on one
pose or the bind pose.

## 3. In-game carry/toss (real gameplay, not the isolated harness)

```
D:\Tools\godot\godot_console.exe --path . --resolution 1280x720 -- --skipmenu --world=pillow_fort --pads=2 --script=tools/harness/scripts/gate2_toss.json --shots=125,220,290 --outdir=evidence/stills/v2_characters --quitafter=15
```

```
HARNESS_EVENT {"action":"interact","frame":110,"seat":2,"type":"press"}
CARRY {}
...
HARNESS_EVENT {"action":"interact","frame":130,"seat":2,"type":"press"}
TOSS {}
```

`otto_carry_pip.png` (captured 15 frames after `CARRY`) shows Otto in his
`Carry` body-input pose (visibly different arm/torso carriage than plain
walk) with Pip correctly perched via `CarrySocket`, **and** Otto's own
pickup squash-stretch pulse still visible on top of the skeletal pose — the
"squash-stretch is a layer on top of skeletal, not instead of" requirement,
proven in one frame, in real gameplay, not a synthetic test. No script
errors through `CARRY` -> `TOSS` -> Otto's own jump -> Pip walking off.

## 4. Face-camera-at-rest — numeric verification

Isolated headless test (a real ground plane + a stationary `pip.tscn`
instance + a camera placed at world `(-3, 0.6, 0)` relative to Pip, i.e.
directly to his left, expected yaw = -90°):

```
initial rotation.y=0.0
... 90 physics frames later ...
rotation.y (deg)=-89.9999820139107   -> converged (within 0.0001° of -90°)
```

Then feeding `set_virtual_input(Vector2(1.0, 0.0))` (movement in world +X,
expected yaw = 90°): `rotation.y` reads 85.3° after 20 frames and continues
converging toward 90° — confirms the latch hands off cleanly to
`player_body.gd`'s own rotation control the instant real movement starts,
per the "read-only integration, never fights it mid-game" design.

## 5. Placement-check regression (props/dreamlings untouched)

```
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=pillow_fort
```

```
PLACEMENT_NOTE pillow_fort has zero dreamlings (nothing to check)
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort"]}
```

`any_fail: false`. (`pillow_fort` itself has no dreamlings to check — same
as the pre-existing baseline; this run's purpose is proving the `ModelSlot`/
world-loading path this task's changes sit next to didn't regress.)

---

## Bug found and fixed this pass: skinned-mesh AABB double-scaling

**Symptom**: first close-up render showed an unrecognizable, blurry,
massively oversized blob filling the frame at any camera distance under
~4m.

**Root cause**: `ModelSlot._compute_local_aabb()` (used for the static prop
path) walks every ancestor `Node3D.transform` from the model root down to
each `MeshInstance3D` and multiplies `mesh.get_aabb()` by the accumulated
transform — correct for a static prop hierarchy. For the merged rig,
`RiggedModelSlot` was initially reusing that exact method via
`super._swap_in()`. Direct inspection
(`Armature.transform` printed) showed the glTF importer bakes a `0.01`
import-time scale onto the `Armature` node (a common Blender/FBX-export
unit-conversion artifact) — but that scale is **already accounted for** by
the skin's bind-pose-inverse matrices at render time; the skinning pipeline
does not additionally consult `Armature`'s or `Skeleton3D`'s own node
`.transform` the way a static child mesh would. Multiplying it into the
AABB computation a second time silently double-counted it: `mesh.get_aabb()`
returns ~0.9m (matching the `height_meters: 0.9` Meshy was rigged at, per
`tools/meshy/rig_forge.py`), but the walk's extra `× 0.01` from `Armature`
made `_compute_local_aabb()` report `~0.009m`, producing a `target_height /
0.009 ≈ 100x` scale factor — i.e. a life-sized child rendering as a ~90m
giant.

**Fix**: `RiggedModelSlot._swap_in()` no longer calls
`super._swap_in()`/`_compute_local_aabb()`. It reads `mesh.get_aabb()`
directly off the found skinned `MeshInstance3D` with **no** ancestor
transform multiplication, then applies the same
scale/ground/hide-primitives/add_child sequence `ModelSlot` uses. Confirmed
by an isolated before/after test (`rig.scale = 1.0` vs. `100.0` on the raw
merged scene, screenshotted from a fixed camera): scale `1.0` -> correctly
life-sized small figure at 4m distance; scale `100.0` -> the exact
oversized-blurry-blob symptom, reproduced on demand. Post-fix, live boot
receipts read `"scaled":1.00000009271835` (Pip) / `1.00000022007874`
(Otto) — i.e. Meshy's `height_meters`-rigged output needs ~no correction,
and the AABB read still self-corrects if a future rig isn't pre-scaled
exactly (it's a measurement, not a hardcoded `1.0`).

This is the single most load-bearing finding of this pass — without the
close-up verification tool, this would have shipped as invisible/off-screen
giant characters in every real playtest camera angle.

---

## Files created / edited

**Created**: `core/art/character_animator.gd`, `core/art/rigged_model_slot.gd`
(+ `.uid` sidecars), `scenes/players/rigs/{pip,otto}_rig.tscn`,
`scenes/players/rigs/{pip,otto}_anim_lib.tres`,
`tools/import/merge_character_anims.gd`,
`tools/import/verify_character_stills.gd` (+ `.uid` sidecars),
`evidence/stills/v2_characters/*` (10 PNGs + `events.jsonl`), this file.

**Edited**: `core/companion/callie.gd` (visual-life polish only, see §5
diff scope above), `scenes/players/pip.tscn` / `scenes/players/otto.tscn`
(renamed the `ModelSlot` node to `RiggedModelSlot` with the new script,
added a `CharacterAnimator` sibling — same `model_id`/`target_height`/
`ground_offset_y` values as before).

**Not touched**: everything under `core/movement/**`, `core/coop/**`,
`scenes/main.gd`, `worlds/**`, `scripts/autoloads/**`, `project.godot` (all
forbidden per brief) — confirmed via `git status` inspection before
finishing; the concurrent changes visible there this pass belong to other
agents.

---

## UNVERIFIED

- **`play_gesture()` has no gameplay caller yet.** Firing wave/cheer/pickup/
  dance from an actual game event (dreamling catch, rescue, carry pickup)
  would require editing `core/coop/**` / `worlds/**`, both outside this
  task's territory. The API (`CharacterAnimator.play_gesture(name) ->
  bool`, `is_gesture_active()`, `gesture_finished` signal) is built and
  manually exercised (the wave shot above), but not wired to gameplay.
- **`AnimationNodeStateMachine` "Any State" transitions** were deliberately
  not used/tested (see §"BodyTransition" above) — `AnimationNodeTransition`
  was chosen instead specifically to avoid depending on unverified
  behavior. If a future pass wants a true state-machine graph (e.g. for
  scripted cutscene `travel()` calls), that's new ground, not a gap in this
  one.
- **Intermittent `ERROR: 2 resources still in use at exit`** on process
  quit: observed on some `--quitafter` runs, absent on immediate retries
  under identical flags, and present even on a boot with the AnimationTree
  system barely touched (single frame). Not isolated to a specific
  resource type via `--verbose` (generic engine-teardown message, no named
  resource). Did not reproduce reliably enough to attribute to this pass's
  code with confidence; flagging rather than claiming it's pre-existing or
  claiming it's fixed.
- **Foot IK, `SpringBoneSimulator3D` on onesie ears, `LookAtModifier3D`**
  (research doc §7) — explicitly scoped as "nice-to-have polish, safe to
  defer" by the research doc itself; not built this pass.
- **Otto's `carry` clip vs. Pip's `skip` clip were not visually compared
  side-by-side against Meshy's web preview** — only verified structurally
  (loop flags, presence in the built `AnimationTree`, and `carry` actually
  engaging in real gameplay per §3). No claim beyond that.
