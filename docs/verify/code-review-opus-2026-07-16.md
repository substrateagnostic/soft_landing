# Code Review — THE BIG NAP (sub-director, Opus 4.8)

Date: 2026-07-16 · Reviewer: Opus 4.8 (sub-director) · Scope: pre-public-push
review of movement, camera, readability, rescue, co-op, scenes, autoloads,
worlds, harness. REVIEW ONLY — nothing was edited.

Method: read every file in the brief plus `core/world_contract.gd`,
`scenes/players/*.tscn`, `scenes/main.tscn`, `project.godot`. Top findings were
re-traced against the source (not pattern-matched) before ranking. Three other
agents are editing audio / UI / properties in parallel; drift noted, not fought.

## Summary

| Severity | Count |
|---|---|
| CRITICAL | 1 |
| REAL | 4 |
| NIT | 9 |

Verdict: **one push-blocker** (a rescue-loop soft-lock reachable by the game's
own front-door navigation). It is a ~10-line fix. Everything else is either
recoverable-in-play or cosmetic. With finding #1 fixed and #2/#3 ideally
addressed, this is push-ready for a personal/OSS public repo.

---

## Findings (most severe first)

### CRITICAL-1 — Stale rescue history survives world switch → infinite bubble soft-lock
Files: `core/rescue/soft_landing.gd:29-34,74-94,97-110` · `scenes/main.gd:179-192`

`SoftLanding` keeps `_pip_history` / `_otto_history` as a ring buffer of safe
grounded positions. `main._switch_world()` frees the old world, loads the new
one, re-places players, and updates `rescue_floor_y` — but **never clears the
history**, and `SoftLanding` exposes no reset. There is no history reset
anywhere in the project (grep-confirmed).

Failure scenario (reachable in one door press — the "go home" direction):
1. Play Bramble; Pip's history fills with Bramble coordinates
   (x roughly -61..54, e.g. the spawn/meadow region near x=-50).
2. Walk into the Bramble `HomeDoor` and exit to `pillow_fort`
   (`main.gd:173-176` → `_switch_world("pillow_fort")`).
3. Pillow Fort's playable clearing is only 25×25 centred on origin
   (`pillow_fort.gd:11`, x/z ∈ [-12.5, 12.5]); `rescue_floor_y` = -10.
4. Within the first ~2 s (before 4 new grounded samples accumulate), Pip runs
   off the clearing edge. `_rescue()` picks `history[size-4]` — still a Bramble
   coordinate like (-50, 0.5, 0), which in Pillow Fort is **over the void**.
5. Bubble floats Pip to that stale point (+1 m), pops, Pip falls again. While
   falling/bubbled Pip is never `is_on_floor()`, so **no new sample is
   appended**, so `history[size-4]` is unchanged → the next rescue targets the
   exact same void point → **rescue repeats forever.** No input escapes it; in
   solo this is the child's only character. Hard soft-lock, app-close only.

Direction matters: pillow_fort→bramble is accidentally survivable (Bramble's
meadow is huge and covers the origin region where Pillow coords land), but
bramble→pillow_fort is the killer, and that is the literal "return to the fort"
action a 4-year-old will take constantly. This is the single worst outcome for
this audience — a looping, no-escape state — so it blocks push.

Minimal fix: add `func reset_history() -> void` to `SoftLanding` that clears
both arrays, zeroes both sample timers, and seeds each array with the player's
current (freshly-placed) spawn position; call it from `_switch_world()` right
after `_place_players()`. Seeding the spawn also guarantees the empty-history
branch below never fires.

---

### REAL-2 — Carried player is eligible for its own rescue and pollutes safe-history with airborne points
File: `core/rescue/soft_landing.gd:77,90-94` · `scenes/players/otto.tscn:44-45`

Neither the history-sampling guard (`:77` samples whenever `is_on_floor() and
state != BUBBLED`) nor the fall-check guard (`:91` returns only for `rescuing`
or `BUBBLED`) excludes the **CARRIED** state. A carried Pip has collision off
and its `_physics_process` early-returns (`player_body.gd:77-81`), so it never
calls `move_and_slide()` and `is_on_floor()` stays **stale-true** from before
the pickup.

Two concrete failures:
- **Airborne "safe" samples.** While Pip rides Otto's `CarrySocket`
  (offset +0.5 m, `otto.tscn:45`), stale-true `is_on_floor()` makes
  `SoftLanding` record Pip's carried, off-ground position as a safe spot. If
  Otto carries Pip over/near a ledge, those samples sit over the drop; after a
  hop-down + fall, the rescue restores Pip to an airborne/void point.
- **Double-rescue of a carried Pip.** If Otto walks off a cliff while carrying,
  Pip's fall-check (`:93`) is live. Only the 0.5 m socket offset keeps Pip
  above the plane on the frame Otto crosses it (worst case Otto at
  `floor - 0.33 m` for terminal 20 m/s at 60 Hz → Pip at `floor + 0.17 m`).
  Margin ≈ 0.17 m: it holds for the shipped socket/tick/terminal, but any lower
  socket, higher terminal, or lower tick rate flips it into Pip and Otto being
  bubbled to two different positions while Pip is still parented to Otto's
  socket — a genuinely broken, tween-fighting state.

Minimal fix: gate both the sampling and the fall-check on
`player.state == PlayerBody.State.GROUNDED` (a carried/tossed/bubbled player is
never SoftLanding's responsibility). This also hardens the `is_on_floor()`
staleness class generally.

---

### REAL-3 — Static `_orbit_groups` leaks freed dreamlings across world switches
File: `worlds/common/dreamling.gd:33,141-155,213` · `worlds/common/dream_door.gd:41-53`

`Dreamling._orbit_groups` is a `static var Dictionary` keyed by carrier
instance-id. A following dreamling is **not** reparented — it stays a child of
the world and orbits by setting `global_position`. `Dreamling` has no
`_exit_tree`/cleanup (grep-confirmed), so when a dreamling is freed with its
world, it never runs `_leave_orbit_group()`.

Failure scenario:
1. In Bramble, collect a dreamling (now orbiting Pip) but do **not** return it;
   walk into the `HomeDoor` and exit. `_world.queue_free()` frees the orbiting
   dreamling, leaving a **freed-instance entry** in `_orbit_groups[pip_id]`.
   The carrier (Pip) survives the switch, so its instance-id — and that stale
   entry — persist in the static dict.
2. Any later collection by the same player appends to that same array
   (`:143-145`): orbit spacing (`count = group.size()`, `:163`) now counts a
   ghost, and `Dreamling.carried_by()` (`:213`) returns an array that includes
   the freed instance.
3. `DreamDoor._schedule_release()` then calls `dreamling.leave_orbit_early()`
   on that freed object (`dream_door.gd:44`) **before** its `is_instance_valid`
   guard (`:50`) — a call on a previously-freed instance → error spam, and the
   collect/return accounting (the game's whole loop) miscounts.

Note the neighbouring behaviour is *correct*: only RETURNED dreams are filtered
on re-entry (`world_base.gd:66-72`), so a collected-but-not-returned dreamling
respawns and is fully re-collectable — carried-out progress is **recoverable**,
not lost. Only the static-dict hygiene is broken.

Minimal fix: add `func _exit_tree() -> void: _leave_orbit_group()` to
`Dreamling` (safe for IDLE dreamlings — `_leave_orbit_group` early-returns when
`_carrier == null`).

---

### REAL-4 — Door interact is polled alongside carry/return, so one press fires two actions
File: `worlds/common/world_door.gd:77-81` · `core/coop/carry_toss.gd:45-61` · `worlds/common/dream_door.gd:25-31`

`WorldDoor._physics_process` fires an exit on *either* seat's `interact` when
*any* player stands inside, polled every frame. `CarryToss._physics_process`
and `DreamDoor` poll the same buttons the same frame with no shared ownership.

Failure scenarios (recoverable — not stranding — but they violate the "never
confuse a 4-year-old" floor):
- Otto (carrying Pip) stands in the `HomeDoor` and P1 presses interact →
  `CarryToss` hops Pip down **and** `WorldDoor` switches worlds, same press.
- Solo mode: buddy-Otto wanders into the doorway while following; the child
  presses interact to do anything → an unexpected world switch.

Minimal fix: give `WorldDoor` a short dwell/confirm, or route interact through a
single owner per player per frame (e.g. `WorldDoor` ignores the press on any
frame a carry/return also consumed it, or requires the stick-neutral player to
hold briefly).

---

## NIT batch (style / low-severity / perf)

- **Dead code:** `PlayerBody.set_control_enabled()` (`player_body.gd:231`) has
  no callers anywhere; special states gate via early-return instead. Remove or
  wire it.
- **Weak receipts:** `carry_toss.gd:91,107` print `"CARRY {}"` / `"TOSS {}"` —
  empty braces, unlike `RESCUE`/`WARP`/`DOOR` which emit `{"seat":…}` JSON.
  Greppable but data-free; make them `{"seat": _pip.seat}` for parity with the
  harness receipt convention.
- **Redundant saves:** `GameState.return_dream()` (`game_state.gd:45-47`) can
  drive up to three `SaveManager.save_game()` writes per return (fort-stage
  save + the `dream_returned` signal handler + the explicit call);
  `mark_world_completed()` double-saves similarly. Harmless, but needless disk
  churn on every collectible.
- **Physics engine not pinned:** `project.godot` has no `[physics]` section, yet
  D1 states slope/movement numbers are tuned against Jolt. It currently relies
  on the environment default. Pin `physics/3d/physics_engine` explicitly so a
  different default can't silently change feel.
- **Reparent target drift:** `carry_toss.gd:128-129` returns Pip to
  `current_scene` (Main root) on toss/hop-down, not to the `Players` node it
  came from. Harmless (Pip works anywhere), but asymmetric with pickup.
- **Geyser ignores player state:** `snore_geyser.gd:93-98` sets `velocity.y` on
  any body still in `_bodies_inside` regardless of CARRIED/BUBBLED (whose
  `body_exited` may not fire when collision is dropped) → a leftover upward
  velocity applied on the frame the player exits the special state. Cosmetic.
  Add an `is state GROUNDED/RISING/APEX/FALLING` check.
- **Per-frame allocations (all trivial on PC target, flagged for the record):**
  `dreamling._nearest_player()` calls `get_tree().get_nodes_in_group()` every
  physics frame per dreamling — at 10 dreamlings ≈ 600 array allocs/s + ~1200
  distance ops/s (`dreamling.gd:108`); `camera_rig._find_active_hint()`
  allocates a `PhysicsPointQueryParameters3D` + result array each frame
  (`camera_rig.gd:194-199`); `_is_outside_frustum_by_margin()` allocates the
  6-plane frustum array each frame (`camera_rig.gd:269`). None matter at this
  scale; the dreamling group query is the only one worth an early-out later
  (e.g. skip when no player moved within radius).
- **`_is_overridden` contract check** (`world_base.gd:53-58`) assumes
  `get_script_method_list()` includes the inherited stub declaration; if a
  Godot build returns leaf-only methods it would false-warn. Warning-only, no
  gameplay impact — worth a one-line verify against 4.6.2 behaviour.
- **`landing_ring` / `dream_door` / `world_door` run `_process`/`_physics_process`
  while idle** (early-return after a cheap check). Fine, but the landing ring
  could `set_physics_process(false)` while grounded to shave two raycasts/frame.

---

## What is solid

The movement core is genuinely well-built and worth calling out: gravity is
derived from `jump_height`/`time_to_apex` (never hand-set, D3), coyote/buffer
are float-seconds not frames, the apex-hang window is real, and the fixed jump
correctly *stacks* the breathing chest's lift — `platform_on_leave =
ADD_UPWARD_VELOCITY` is applied by `move_and_slide()` *after* `_try_jump()` sets
`velocity.y`, so the SPEC's "chest launches must inherit lift" holds without the
jump clobbering it (`player_body.gd:57-58,175-184`). The state machine is clean
and every feel number lives in `MovementTuning` as `@export` — zero magic
numbers in the movement path.

The rescue/warp/leash systems share one `BubbleEffect` vocabulary and guard
against stacking well: `warp_player_to` and `_track_and_check` both short-circuit
on `BUBBLED`, and a leash-break during a rescue correctly no-ops rather than
double-bubbling. `BubbleEffect` is parented to `current_scene` (Main), so it
survives world switches instead of being freed mid-tween. Signal lifecycle
across switches is correct by construction — world-owned connections die with
the freed world, while player/camera/manager wiring is established once and
reused. The save system quarantines corrupt files to `save.bak.json`, preserves
unknown keys for forward-compat, and never surfaces a scary message — exactly
the floor. And the readability kit is honest: the blob shadow is a zero-per-frame
projected decal, right stick is never read, camera yaw is two-stage damped.
Static typing and `@export` discipline are thorough across the whole tree.
