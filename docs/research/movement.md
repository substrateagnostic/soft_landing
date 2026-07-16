# Movement Feel Research — Godot 4 CharacterBody3D Platformer

Research for **soft_landing**, a gentle 3D collectathon platformer for a 4-year-old.
Target engine: **Godot 4.6.x** (siblings run 4.6.2). Compiled July 2026.

> How to read this doc: sourced facts carry an inline URL. Design
> recommendations tuned for a young player are flagged **[REC]**. Anything I
> could not confirm is repeated in the **UNVERIFIED** list at the bottom.

---

## 1. Coyote time and jump buffering (in 3D)

**What they are.** *Coyote time* keeps the jump valid for a short window after
the player walks off a ledge (still on floor last frame, not this frame).
*Jump buffering* remembers a jump press made slightly before landing and fires
it the instant the character touches ground. Together they absorb human
reaction lag and display/input latency — GMTK notes a poorly configured
TV/monitor can add "north of 100 milliseconds of delay," so coyote time is
partly latency compensation, not just generosity
([GMTK Platformer Toolkit — Behind the Code](https://gmtk.itch.io/platformer-toolkit/devlog/395523/behind-the-code)).

**3D is identical to 2D.** The same logic applies unchanged to `CharacterBody3D`:
start a coyote window on the on-floor → off-floor transition, and gate the jump
on `(buffer_active) and (is_on_floor() or coyote_active)`
([KidsCanCode Godot 4 Recipes — Coyote Time](https://kidscancode.org/godot_recipes/4.x/2d/coyote_time/index.html)).

**Timers vs frame counters.** Both work. KidsCanCode expresses the window in
frames but converts to seconds for a one-shot `Timer`
(`wait_time = coyote_frames / 60.0`, with `coyote_frames = 6` → 0.1 s)
([KidsCanCode](https://kidscancode.org/godot_recipes/4.x/2d/coyote_time/index.html)).
The cleaner, frame-rate-independent pattern is a float countdown ticked in
`_physics_process` with `delta`. A timing primer recommends **seconds over
frame counts** precisely because seconds "are easier to tune across" 30/60/120
FPS
([gamineai — Input Buffering & Coyote Time primer](https://gamineai.com/blog/input-buffering-and-coyote-time-in-2d-a-godot-4-and-unity-friendly-timing-primer)).
Do the whole thing inside `_physics_process`: reset `time_since_grounded` when
`is_on_floor()`, reset `time_since_jump_pressed` on press, and evaluate the jump
in one place. On a successful jump, **consume the buffer and reset both timers**
so you don't get an accidental second jump
([gamineai](https://gamineai.com/blog/input-buffering-and-coyote-time-in-2d-a-godot-4-and-unity-friendly-timing-primer)).

**Typical shipped values (by genre):**

| Game type | Coyote | Buffer | Source |
|---|---|---|---|
| Tight/precision platformer | 70–100 ms | 70–110 ms | [gamineai](https://gamineai.com/blog/input-buffering-and-coyote-time-in-2d-a-godot-4-and-unity-friendly-timing-primer) |
| Action platformer | 90–140 ms | 100–150 ms | [gamineai](https://gamineai.com/blog/input-buffering-and-coyote-time-in-2d-a-godot-4-and-unity-friendly-timing-primer) |
| Casual / mobile | 110–170 ms | 120–180 ms | [gamineai](https://gamineai.com/blog/input-buffering-and-coyote-time-in-2d-a-godot-4-and-unity-friendly-timing-primer) |
| Suggested baseline | 100 ms | 120 ms | [gamineai](https://gamineai.com/blog/input-buffering-and-coyote-time-in-2d-a-godot-4-and-unity-friendly-timing-primer) |

The GMTK toolkit's own coyote value sits "typically around 0.2 seconds," with a
tiny lower guard (~0.03 s) so a jump isn't stolen the same frame you leave ground
([GMTK](https://gmtk.itch.io/platformer-toolkit/devlog/395523/behind-the-code)).

**Shifting for a young / novice player. [REC]** Push both windows toward the
top of (and beyond) the casual range. A 4-year-old presses late, presses early,
and presses twice. Generous **coyote ~0.15–0.25 s** and a **long buffer
~0.20–0.25 s** turn most "missed" inputs into successes. These are wide enough
to feel forgiving without visibly breaking physics (a 0.2 s coyote is ~2–3 grid
cells of "magic ledge" at platformer speeds — acceptable for a toddler game,
too loose for a precision game).

---

## 2. Slope handling

Godot exposes floor behavior directly on `CharacterBody3D`
([Godot docs — CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)):

| Property | Default | Meaning |
|---|---|---|
| `floor_max_angle` | `0.7853982` rad (**45°**) | Steepest slope still counted as floor vs wall |
| `floor_snap_length` | `0.1` | Snap distance that keeps the body glued to slopes/stairs when moving down |
| `floor_constant_speed` | `false` | If true, same ground speed regardless of slope angle |
| `floor_stop_on_slope` | `true` | If true, body does not slide when idle on a slope |
| `floor_block_on_wall` | `true` | Blocks floor movement into walls (still allows wall slide) |
| `platform_on_leave` | `ADD_VELOCITY` (0) | Velocity inherited when stepping off a moving platform |
| `platform_floor_layers` | all layers | Which floor bodies act as moving platforms |

**Idle sliding.** With `floor_stop_on_slope = true` (the default) a stationary
body will not creep down a ramp; disabling it makes the body slide down slopes
with no input
([Godot docs](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html);
[Bugnet — CharacterBody3D Sliding Down Slopes When Idle](https://bugnet.io/blog/fix-characterbody3d-sliding-down-slopes-idle-godot)).

**Consistent speed.** `floor_constant_speed = true` removes the "speeds up
downhill / slows uphill" effect so movement feels even on ramps. It relies on a
non-zero `floor_snap_length` to stay glued going *down* a slope
([Godot docs](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)).

**Snap / slide jitter.** The classic jitter is: the collision response nudges
the body slightly off the surface each frame, then snap yanks it back. If
`floor_snap_length` is *shorter* than that per-frame displacement, the body
loses floor contact and starts sliding
([Bugnet](https://bugnet.io/blog/fix-characterbody3d-sliding-down-slopes-idle-godot)).
Fix by increasing `floor_snap_length` so it comfortably exceeds one frame's
vertical move. A known engine issue: at the *top* of an ascending slope the body
can still launch off instead of snapping, even at large snap lengths
([godot#71993](https://github.com/godotengine/godot/issues/71993)) — mostly
cosmetic, worse at high speed. General recipe: set `floor_max_angle` to cover
your steepest walkable slope, keep `floor_stop_on_slope` on, and raise
`floor_snap_length` until contact is stable
([grosan.co.uk — CharacterBody3D Movement Setup & Motion Modes](https://grosan.co.uk/characterbody3d-in-godot-4-movement-setup-and-motion-modes/)).

**Important: don't snap while rising.** Snapping only engages when the body
moves *against* `up_direction`. Standard practice is to zero the snap (or the
engine auto-disables it) on the frame you jump, otherwise the character is
glued down and the jump fails
([Godot docs](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)).

**Moving platforms.** `platform_on_leave` decides inherited velocity when you
step or jump off. Default `ADD_VELOCITY` carries the platform's full velocity
(so you keep momentum). `ADD_UPWARD_VELOCITY` drops the downward component
(nice so a descending platform doesn't yank you down), and `DO_NOTHING` transfers
nothing
([Godot docs](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)).
Platforms should be `AnimatableBody3D`; a `CharacterBody3D` can slide off a
rotating platform if adherence isn't configured
([godot#102763](https://github.com/godotengine/godot/issues/102763);
[Bugnet — Moving Platform Not Following](https://bugnet.io/blog/fix-godot-character-body-3d-moving-platform-not-following)).

---

## 3. Jump arc design

**Fall faster than you rise.** The single highest-value trick. Ascent is floaty
(good for steering mid-air), descent is snappy (good for precise landings) —
achieved by multiplying gravity when `velocity.y < 0`. Super Mario Bros. is the
canonical example
([GMTK](https://gmtk.itch.io/platformer-toolkit/devlog/395523/behind-the-code);
[gamedevbeginner — How to jump in Unity](https://gamedevbeginner.com/how-to-jump-in-unity-with-or-without-physics/)).
In the GMTK toolkit, a `downwardMovementMultiplier` is applied while falling and
set to `1` while rising or stationary
([GMTK](https://gmtk.itch.io/platformer-toolkit/devlog/395523/behind-the-code)).

**Derive gravity from height + time, not by hand.** Rather than guessing a
gravity constant, pick a desired jump *height* and *time-to-apex* and solve:
`gravity = (2 * jump_height) / (time_to_apex^2)` and
`jump_velocity = gravity * time_to_apex`
([GMTK](https://gmtk.itch.io/platformer-toolkit/devlog/395523/behind-the-code)).
This makes tuning intuitive — you dial the *feel* (how high, how long in the
air), and the physics follows.

**Game gravity is not 9.8.** Real gravity feels floaty at game scale; 3D
platformers commonly run **2–3× real** — e.g. a tutorial uses gravity `20.0`
with `jump_force 8.0`
([codingquests — Godot 4 3D Character Controller](https://codingquests.io/blog/godot-4-3d-character-controller-tutorial)).

**Variable jump height (jump cut).** Holding jump longer = higher; releasing
early applies a `jumpCutoff` gravity multiplier (or clamps upward velocity) to
end the rise sooner
([GMTK](https://gmtk.itch.io/platformer-toolkit/devlog/395523/behind-the-code);
[Medium — 2D Platformer Jumping with Variable Heights](https://medium.com/@eveciana21/2d-platformer-jumping-with-variable-heights-b6eb49969558)).
**[REC] Skip variable jump height for a 4-year-old.** It demands a *modulated
hold* — press-and-hold-just-long-enough — which is exactly the fine motor skill
a preschooler lacks. A single fixed-height jump is more predictable and less
frustrating. (Keep the code path stubbed so it's easy to enable later.)

**Apex hang.** Near the top of the arc, briefly reduce gravity (or cap
horizontal-velocity gravity) so the character "floats" for a beat at the apex.
This buys reaction time to line up the landing and reads as generous/joyful.
GMTK's toolkit implements exactly this apex behavior
([GMTK](https://gmtk.itch.io/platformer-toolkit/devlog/395523/behind-the-code)).
**[REC]** A short apex hang is one of the best forgiveness tools for a young
player — it makes airtime feel long and controllable.

**Terminal velocity.** Clamp `velocity.y` to a max fall speed so long drops
don't accumulate uncontrollable speed (and so tunneling/collision misses are
less likely). This is standard cheat-sheet advice
([Medium — Platformer Physics Cheatsheet](https://medium.com/@brazmogu/physics-for-game-dev-a-platformer-physics-cheatsheet-f34b09064558)).

---

## 4. Acceleration / deceleration and turning

**Instant vs curve-based.** Direct assignment (`velocity.x = dir * speed`) is
responsive but reads as "robotic/arcade." Smoothing via `lerp`/`move_toward`
between current and target speed gives weight without mushiness; friction =
how fast you stop, acceleration = how fast you reach top speed, both commonly
expressed 0–1
([Godot forum — lerp for player movement](https://forum.godotengine.org/t/how-can-i-set-lerp-for-player-movement/83024);
[KidsCanCode — Kinematic Friction](https://kidscancode.org/godot_recipes/3.x/physics/kinematic_friction/index.html)).
GMTK separates **ground** and **air** acceleration plus a distinct **turn**
speed applied when reversing direction
([GMTK](https://gmtk.itch.io/platformer-toolkit/devlog/395523/behind-the-code)).

**Rotate toward movement, don't snap.** In 3D you typically move on a plane and
rotate the *mesh* to face travel direction. Snapping instantly "looks robotic";
the standard fix is `rotation.y = lerp_angle(rotation.y, target_angle, k * delta)`
with `k ≈ 8–12`
([codingquests](https://codingquests.io/blog/godot-4-3d-character-controller-tutorial)).
Note `lerp_angle` (handles wrap-around), not plain `lerp`, and keep the
collision body upright — only the visual turns.

**Air control.** Full air control feels floaty; zero feels like "steering a
brick." A `CharacterBody3D` tutorial lerps horizontal velocity toward the input
target in air with a factor **~0.2–0.4 (default 0.3)** as the sweet spot
([codingquests](https://codingquests.io/blog/godot-4-3d-character-controller-tutorial)).

**[REC]** For a toddler: fairly quick ground acceleration (they want the
character to *go* when they push), gentle deceleration (no skidding past ledges),
moderate turn lerp (~10), and generous air control (~0.4–0.6) so mid-air course
correction is easy.

---

## 5. Ground-check nuance (`is_on_floor` with `move_and_slide`)

- **`is_on_floor()` reflects the last `move_and_slide()`.** It is only valid
  *after* you call `move_and_slide()`, and describes that call's result. Read it
  after moving, not before
  ([Godot docs](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)).
- **It can flicker false for a frame** when a jump's upward velocity + snap
  interplay briefly breaks contact — which is exactly *why* coyote time exists.
  Track `was_on_floor` and detect edges rather than trusting a single frame
  ([gamineai](https://gamineai.com/blog/input-buffering-and-coyote-time-in-2d-a-godot-4-and-unity-friendly-timing-primer)).
- **Landing snap.** On the not-on-floor → on-floor transition, zero downward
  velocity (`if on_floor_now and not was_on_floor: velocity.y = 0.0`) so
  accumulated fall speed doesn't cause a jitter or a micro-bounce
  ([Bugnet](https://bugnet.io/blog/fix-characterbody3d-sliding-down-slopes-idle-godot)).
- **Odd-but-true edge cases:** `is_on_floor()` can be `true` while
  `get_last_slide_collision()` is `null` on a downward slope
  ([godot#72069](https://github.com/godotengine/godot/issues/72069)); don't
  assume a slide collision always exists when grounded.
- **Don't cancel snap by accident.** If you want to jump you must temporarily
  set `floor_snap_length = 0` (or rely on upward velocity auto-disabling snap),
  or the body stays glued to the floor and the jump silently fails
  ([Godot docs](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html);
  [godot-proposals#4259](https://github.com/godotengine/godot-proposals/issues/4259)).

---

## 6. Godot 4.5 / 4.6 changes affecting CharacterBody3D

**Jolt is the default 3D physics engine in 4.6.** Jolt shipped natively in 4.4
(behind an experimental label) and, in **4.6, becomes the default for all new
3D projects** — the official notes: "we're confident enough to remove the
experimental label and make Jolt the default physics engine for all new 3D
projects." Existing projects keep their setting; only *new* projects get Jolt
via `project.godot`
([Godot 4.6 release notes](https://godotengine.org/releases/4.6/);
[StraySpark — 4.6 Jolt Migration Guide](https://www.strayspark.studio/blog/godot-46-jolt-physics-migration-guide)).

**What a new 3D project should choose: Jolt.** "If you're starting a new
project, just use Jolt. It's the default for a reason." Benchmarks cite 2–3×
performance in complex scenes
([StraySpark](https://www.strayspark.studio/blog/godot-46-jolt-physics-migration-guide);
[Godot 4.6 release notes](https://godotengine.org/releases/4.6/)). Since
soft_landing targets 4.6.x, **leave the default (Jolt)**.

**Behavioral caveats with Jolt.** Jolt is a drop-in for the same nodes
(`CharacterBody3D`, `RigidBody3D`) but collision resolution is *more precise*, so
"you might notice slightly different behavior on slopes or ledges." Jolt also has
a different default max angular velocity. Migration advice: "Test slope sliding
and edge detection"
([StraySpark](https://www.strayspark.studio/blog/godot-46-jolt-physics-migration-guide)).
Practically: re-tune `floor_snap_length` / `floor_max_angle` feel against Jolt
rather than copying values from a GodotPhysics tutorial verbatim.

**Physics interpolation (3D).** 2D physics interpolation landed in 4.3. For 3D,
the 4.6 release notes do **not** advertise 3D physics interpolation as a new or
default-on feature, and there are open proposals to enable interpolation by
default in new projects and to add 3D physics-step interpolation
([godot-proposals#12950](https://github.com/godotengine/godot-proposals/issues/12950);
[godot-proposals#2753](https://github.com/godotengine/godot-proposals/issues/2753)).
Treat 3D physics interpolation as **available at the node level
(`physics_interpolation_mode`: On/Off/Inherited) but not guaranteed on by
default** — verify in-editor and enable `physics/common/physics_interpolation`
if you run physics below display rate. (See UNVERIFIED.)
Other 4.6 items are unrelated to movement (SSR rewrite, glow reorder, IK return,
Modern editor theme)
([Godot 4.6 release notes](https://godotengine.org/releases/4.6/);
[Jettelly — What shipped in 4.6](https://jettelly.com/blog/godot-4-6-editor-improvements-workflow-changes-and-supporting-tools)).

---

## 7. Starter parameter table (gentle, forgiving, joyful — for a 4-year-old)

**[REC] — recommendation, not a sourced fact.** Values are opinionated starting
points synthesized from the sources above and biased toward forgiveness. Tune in
playtest with Ezra. Units are Godot 3D (meters, m/s, seconds).

| Parameter | Value | Rationale / anchor |
|---|---|---|
| `move_speed` (walk) | 4.0 m/s | ~codingquests walk 3.0 / run 6.0; single gentle speed |
| `acceleration` | ~40 m/s² (reach top speed ~0.1 s) | responsive "goes when I push" |
| `deceleration` | ~25 m/s² (softer stop) | no skidding off ledges |
| `turn_lerp` (mesh) | 10 (× delta, `lerp_angle`) | codingquests 8–12 range |
| `air_control` | 0.5 (lerp factor) | above codingquests 0.3 default — easier mid-air fixes |
| `gravity_rise` | ~18 m/s² | ~2× real; floaty ascent (derive from height/time) |
| `gravity_fall` | ~28 m/s² (≈1.5× rise) | snappy, honest landings (GMTK fall-faster) |
| `jump_height` | ~1.5 m (tune) | derive `jump_velocity` & `gravity_rise` from height+apex |
| `time_to_apex` | ~0.45 s | long, readable hang; solve gravity from this |
| `apex_hang` | reduce gravity ~50% while `abs(velocity.y) < ~2` | GMTK apex float; buys reaction time |
| `terminal_velocity` | ~20 m/s cap on fall | prevents runaway drops |
| `variable_jump_height` | **OFF** | fixed jump; toddlers can't modulate hold |
| `coyote_time` | **0.20 s** | top of casual range + margin; generous ledge grace |
| `jump_buffer` | **0.22 s** | early presses still land the jump |
| `floor_max_angle` | 45° (default) | fine; lower to ~40° if edges feel grabby |
| `floor_snap_length` | 0.4–0.5 | raised from 0.1 default for stable slope contact |
| `floor_constant_speed` | `true` | even speed up/down ramps |
| `floor_stop_on_slope` | `true` (default) | no idle sliding |
| `platform_on_leave` | `ADD_UPWARD_VELOCITY` | descending platforms don't yank the kid down |

---

## Recommendations for soft_landing

1. **Build the forgiveness layer first, tune it wide.** Coyote **0.20 s** +
   buffer **0.22 s**, both as float countdowns in `_physics_process` (seconds,
   not frames, for FPS independence). Gate jump on
   `(buffer > 0) and (is_on_floor() or coyote > 0)`; consume buffer and reset
   both on a successful jump.
2. **Fixed-height jump only.** No variable jump height — it needs modulated
   holds a 4-year-old can't do. Stub the code path for later.
3. **Fall ~1.5× the rise gravity, plus a real apex hang.** Derive `gravity_rise`
   and `jump_velocity` from `jump_height` + `time_to_apex (~0.45 s)` so you tune
   feel, not constants. The long apex is the single biggest "joyful/forgiving"
   lever.
4. **Smooth, generous horizontal movement.** Quick accel, soft decel (won't
   overshoot ledges), `lerp_angle` mesh rotation (~10·delta), air control ~0.5.
5. **Slopes: `floor_constant_speed = true`, `floor_snap_length ≈ 0.4–0.5`,
   `floor_stop_on_slope` on.** Zero snap on the jump frame so jumps aren't
   swallowed. Re-test slope/edge feel *against Jolt* — its collision is more
   precise than tutorial GodotPhysics.
6. **Ground checks: read `is_on_floor()` after `move_and_slide()`, track
   `was_on_floor`,** and zero `velocity.y` on landing to kill micro-bounces.
7. **Stay on Jolt (the 4.6 default).** Don't switch to GodotPhysics. Verify
   whether 3D physics interpolation is on in your `project.godot`; enable it if
   you decouple physics tick from display.
8. **Cap terminal velocity** (~20 m/s) so big drops stay controllable.
9. **Prefer `AnimatableBody3D` moving platforms** with
   `platform_on_leave = ADD_UPWARD_VELOCITY` so a young player is never pulled
   downward on exit.
10. **No fail states in the movement layer:** generous windows, floaty apex,
    capped fall, forgiving edges. Every "miss" should quietly become a success.

---

## UNVERIFIED

- **Exact GMTK gravity multiplier numbers.** The *mechanism*
  (`downwardMovementMultiplier` on fall, `jumpCutoff` on release, rising = 1) is
  sourced, but the toolkit exposes these as tunable sliders; the specific
  "1.5× fall" figure in this doc is my recommendation, not a quoted value.
- **3D physics interpolation default state in Godot 4.6.** The 4.6 release notes
  do not advertise 3D physics interpolation as new/default-on, and open proposals
  (#12950, #2753) imply it is not yet default for new 3D projects. I could not
  confirm the precise shipped state — verify in a real 4.6.2 `project.godot` /
  in-editor before relying on it.
- **Whether Jolt changes `is_on_floor()` timing vs GodotPhysics.** Sources say
  slope/edge *behavior* differs (more precise collision) but I found no explicit
  statement that `is_on_floor()` timing semantics changed. Confirm by testing on
  a real slope in 4.6.2.
- **The starter parameter table as a whole** is a recommendation calibrated for a
  4-year-old, not measured from a shipped title. Treat every number as a
  playtest starting point.
- **`godot#71993` ascending-slope launch bug** status in 4.6/Jolt — the issue was
  filed against an earlier build on GodotPhysics; unverified whether it persists
  under Jolt.
