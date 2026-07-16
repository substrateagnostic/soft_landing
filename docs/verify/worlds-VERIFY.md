# worlds-VERIFY.md — Pillow Fort (hub) + Bramble (first world)

Engine: `D:\Tools\godot\godot_console.exe` -> `4.6.2.stable.official.71f334935`.
Built against the live worktree while `core/**`, `scenes/**` (core-feel agent)
and `tools/harness/**` (harness agent) were being built concurrently by other
agents — everything in `worlds/**` below is new; nothing outside `worlds/**`
was edited.

## a) Headless import — exit 0, zero script errors

Command:
```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path D:\Projects\soft_landing
```
Output (trimmed, final clean pass):
```
[ DONE ] first_scan_filesystem
[   0% ] update_scripts_classes | Started Registering global classes... (2 steps)
[   0% ] update_scripts_classes | Bramble
[  33% ] update_scripts_classes | PillowFort
[ DONE ] update_scripts_classes
[ DONE ] loading_editor_layout
```
Exit code `0`. (Only `Bramble`/`PillowFort` show as *new* classes on this
incremental pass — `Dreamling`, `DreamDoor`, `WorldBase`, `WorldDoor` were
already registered from an earlier pass in this same session; a from-scratch
import registers all six `worlds/**` classes with the same zero-error result.)

## b) Headless boot — `--world=pillow_fort`

Command:
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --world=pillow_fort --quitafter=4
```
Output (verbatim):
```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

HARNESS_FLAGS {"quitafter":"4","skipmenu":true,"world":"pillow_fort"}
CAMERA_RIG_READY
WORLD_READY {"id":"pillow_fort","objectives":0}
MOON_SAID {"key":"new_area","text":"A new place to explore. Let's see what's waiting."}
EVT {"seat":1,"t":3,"type":"landed"}
EVT {"seat":2,"t":3,"type":"landed"}
HARNESS_NOTE quitafter fallback fired (harness-level timer, 4.0s)
```
Boots clean, no errors, no warnings. `WORLD_READY {"objectives":0}` and no
`world_completed`/`WORLD_COMPLETED` line anywhere in the output — the
zero-objective guard in `world_base._check_completion()` holds at boot, as
required (nothing ever calls `_on_dreamling_returned` because there is no
`DreamDoor` in this world, so completion bookkeeping never even runs).

## c) Headless boot — `--world=bramble`

Command:
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --world=bramble --quitafter=6
```
Output (verbatim):
```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

HARNESS_FLAGS {"quitafter":"6","skipmenu":true,"world":"bramble"}
CAMERA_RIG_READY
WORLD_READY {"id":"bramble","objectives":10}
MOON_SAID {"key":"new_area","text":"A new place to explore. Let's see what's waiting."}
AudioManager: sfx not found (no-op): res://assets/audio/sfx/snore_geyser.ogg
EVT {"seat":2,"t":3,"type":"landed"}
EVT {"seat":1,"t":6,"type":"landed"}
AudioManager: sfx not found (no-op): res://assets/audio/sfx/snore_geyser.ogg
AudioManager: sfx not found (no-op): res://assets/audio/sfx/snore_geyser.ogg
HARNESS_NOTE quitafter fallback fired (harness-level timer, 6.0s)
```
Boots clean, `WORLD_READY {"id":"bramble","objectives":10}` printed exactly
as required. Both players land on the real meadow floor within a few physics
ticks (no fall-through). The three `AudioManager: sfx not found (no-op)`
lines are `SnoreGeyser` activating on schedule (see below) — expected, no
audio assets exist yet, and `AudioManager.play_sfx` fails soft per its own
contract, not an error.

**Geyser cadence check (extra confidence, not a required item):** with
`cycle_period=5.0`, `active_duration=1.2`, `phase_offset` 1.0 and 3.5 for the
two geysers, the math predicts activations at t≈[0, 0.2), [4, 5.2) for
geyser 1 and t≈[1.5, 2.7), [6.5, 7.7) for geyser 2 — 4 activation edges inside
a 0–8 s window. A separate 8 s run printed exactly 4 `snore_geyser` no-op
lines, matching the prediction and confirming the sine/window cycling logic
in `SnoreGeyser._physics_process` is correct.

## d) Contract property — missing-override warning never fires for either world

Mechanism (`worlds/common/world_base.gd::_is_overridden`): a required method
is "overridden below the contract" if it is declared **more than once**
across the script's inheritance chain — `Script.get_script_method_list()`
returns one entry per declaration found while walking the chain, so the
contract's own stub in `world_contract.gd` always accounts for exactly one
entry; a count of 1 means nothing below it redeclares the method, count > 1
means something does. This is value-independent, which matters here because
`PillowFort.rescue_floor_y()` (`-10.0`) legitimately equals
`WorldContract`'s stub default — a naive "does the return value differ from
the sentinel" check would have false-positived on exactly this world.

Validated the mechanism itself with an isolated 3-level script chain
(`base_a` declares `foo`/`bar`, `mid_b` overrides neither, `leaf_c` overrides
only `foo`) before wiring it into `world_base.gd`:
`get_script_method_list()` on `leaf_c` listed `foo` **twice** (own + base)
and `bar` **once** (base only) — exactly the overridden-vs-not signal the
real check relies on.

Both boot outputs above (`b` and `c`) contain zero `push_warning` output —
confirmed by re-running with the console's warning stream unfiltered; no
`WorldBase: required override missing` line appears for `PillowFort` or
`Bramble`, i.e. every required override (`world_id`, `spawn_points`,
`objective_ids`, `rescue_floor_y`) is genuinely present on both leaf scripts.

## e) Reachability — design-verified only (no player runs performed)

No `--script=` input-playback run was performed in this pass (that's the
harness/director's playtest, per the task brief — "state each dreamling's
intended route... so the director's playtest can check them off"). Every
dreamling's intended route, stated for the record:

### Bramble d01–d10 route table

| id | Location | Height (y) | Intended route | Notes |
|---|---|---|---|---|
| d01 | Meadow, near spawn (-48, 0.55, 3) | 0.55 | Walk straight from spawn. | Trivial, first find. |
| d02 | Meadow, haunch approach (-40, 0.55, -6) | 0.55 | Walk from spawn, slightly off-axis. | Trivial. |
| d03 | +Z paw ramp top (3, 2.7, 16) | 2.7 | Walk onto the paw ramp (`PrismMesh` wedge, 0 -> 2.6 m over 20 m run) and up its slope. | Gentle grade (~7°), no jump required. |
| d04 | −Z paw ramp top (3, 2.7, −16) | 2.7 | Mirror of d03. | Same. |
| d05 | Haunch peak (-30, 10.3, 0) | 10.3 | Climb the haunch mound's slope (sphere r=16, embedded so the lower ~2/3 of its surface is walkable-grade) from the meadow to the top. | First "plateau" per the brief; steepens near the very peak — approach from the shallow (meadow) side, not straight up the tallest face. **Flag for playtest**: exact walkable-slope angle depends on `PlayerBody`'s floor_max_angle, not tuned by this pass. |
| d06 | Rides the breathing chest, local (0, 1.05, 0) relative to `BreathingChest` | 6.9–8.1 (moves) | Reach the chest plateau by walking up from the haunch's forward slope or the shoulder mound's rear slope (both meet the chest's footprint near its rest-height edges), then stand on the chest as it breathes — the dreamling is parented to the chest node, so it rides with it and is always at reach from the plateau's own surface. | "Ride to reach," per brief — no jump timing required, just standing on the plank. |
| d07 | Atop the +Z snore geyser column (54, ~10.39 + 7.7, 4) | ~19.7 | Stand in the geyser's 1.2 m-radius column on the head's front-top surface while it's active (1.2 s window every 5.0 s) and ride the updraft; the dreamling sits low enough inside the column (0.3 m below its 8 m top) to be tagged mid-ride, not only at full extension. | "Ride the snore," per brief. Column base is computed via `_sphere_surface_y` so it sits flush on the head mound, not floating. |
| d08 | Shoulder shelf (24, ~10.7, 6) | ~10.7 | Reach via **either** (a) Otto tossing Pip from the shoulder-mound slope near the shelf (SPEC.md toss apex ~2.2 m, shelf is 3.2 m above the shoulder anchor point — reachable if Otto stands slightly higher on the mound before tossing), **or** (b) a chest-bounce: jump off the rising chest plateau near its shoulder-side edge, inheriting upward platform velocity (`PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY`, already set on `PlayerBody`) for extra height, then a normal jump onto the shelf. | Never toss-only, per the floor rule (solo-completable via the chest-bounce route). **Flag for playtest**: exact toss/bounce geometry not physically simulated in this pass — this is the one placement most likely to need a numeric nudge. |
| d09 | Hidden in the haunch-top fur patch (-27, ~8.9, 6) | ~8.9 | Same haunch-climb route as d05, then step a few meters off-peak into the fur-blade cluster; the dreamling's emissive glow reads through the thin grass blades. | "Visible glow through the grass," per brief — concealment is visual only, blades are non-collidable. |
| d10 | Inside the ear hollow (52, ~12.98, 4.5), 1.5 m from the `DreamDoor` at (50, ~12.98, 6) | ~13.0 | Continue the head-mound climb past d07's geyser to the ear bump at the top; the dreamling sits just beside the return door itself. | Last dreamling on the route; naturally the closest to the point of return. |

Every dreamling sits on ground computed via `_sphere_surface_y()` (exact
sphere-surface height at that XZ, not hand-guessed), so none of them float
or clip below their mound — verified by inspection of the computed values
above, not by a live camera.

### Pillow Fort

Zero objectives in v0.1 (fort growth is Phase 5, per `objective_ids()`
returning `[]`) — nothing to route yet. The `BrambleDoor` (a `WorldDoor`
instance, not a `DreamDoor`) sits just outside the fort's back doorway at
`(0, 0, -8.7)`, reachable by walking from either spawn point straight
through/around the fort shell.

## d01–d10 cadence sanity (D12)

Ten dreamlings across a ~120 m traversal (meadow -> haunch -> chest ->
shoulder -> head -> ear): at a walking pace of ~4 m/s (`move_speed` in
`pip_movement.tres`), the full route is on the order of a minute or two of
wandering with a find roughly every 30–60 s, matching D12's dense-cadence
target. Every one is currently reachable in principle by stick+jump+interact
alone (no verb is toss-only), per the floor rule.

## Integration notes for the director

1. **`BrambleDoor` exit is not yet wired to an actual scene switch.**
   `worlds/common/world_door.gd` emits `exit_requested()` and prints
   `DOOR {"to":"bramble"}` on interact, and `PillowFort` re-emits that up
   through the contract's own `exit_requested` signal. `scenes/main.gd`'s
   `_on_exit_requested()` is currently a documented no-op
   (`pass # hub/world exit routing is a later-phase concern`) — the actual
   `--world=` swap needs to be wired there. That edit is outside
   `worlds/**`, so it's a note, not a change made in this pass.
2. **CameraHint yaw convention assumed, not confirmed against
   `camera_rig.gd`'s exact math.** Both worlds' hints use the convention
   "0° = Godot's default -Z forward (identity rotation)", derived from the
   standard Y-axis Euler rotation formula, giving -90° for +X-facing and
   +90° for -X-facing. `pillow_fort`'s single hint uses 0° (fort faces -Z,
   toward the bear skyline); `bramble`'s three hints use -90°
   (meadow-approach and climb, both facing the bear along +X) and +90°
   (head/ear hint, "view back over the body"). `core/camera/camera_rig.gd`
   does `rotation.y = lerp_angle(..., deg_to_rad(hint.yaw_degrees), ...)`
   directly against the rig's own `rotation.y` — same convention, so this
   should be correct, but was not confirmed with a live camera in this pass
   (no rendering, headless only). Worth a visual check in the next windowed
   playtest.
3. **Found and worked around a live cross-agent bug during this pass, now
   resolved.** `core/camera/camera_hint.gd` originally declared
   `@export var priority: int`, which collides with `Area3D`'s own native
   `priority: int` property — Godot 4.6.2 rejects that as a hard compile
   error ("Member 'priority' redefined") the moment another script
   references `CameraHint` by its global class name for static typing
   (exactly what `pillow_fort.gd`/`bramble.gd` do to build their
   `CameraHint` volumes). Isolated and confirmed via throwaway repro scripts
   in a scratch `worlds/_scratch_test/` directory (deleted before this pass
   finished — nothing left behind in `worlds/**`). The core-feel/camera
   agent fixed it concurrently (removed the redundant `@export`, since the
   inherited native property already satisfies SPEC.md's "priority int"
   contract) — confirmed fixed by re-reading `core/camera/camera_hint.gd`
   and re-running the isolated repro before finishing this pass. No
   workaround remains in `worlds/**`; both files use plain
   `CameraHint.new()` + direct typed property access.
4. **Shoulder shelf (d08) and haunch peak (d05) are the two placements most
   likely to need a numeric nudge** once a real player can walk the route —
   see the route table above. Everything else is either flat ground, a
   shallow ramp, or rides a moving platform, all lower-risk.
5. **Collision layers used, for consistency with the rest of the project:**
   world geometry (ground, mounds, chest, pedestal, ramps, shelf, ear bump,
   fort walls/cushions) — `collision_layer = 1`, matching `PlayerBody`'s
   `collision_mask = 1`. `Dreamling`/`DreamDoor`/`WorldDoor` — Area3D,
   `collision_mask = 2` (the `PlayerBody` layer, per `pip.tscn`/
   `otto.tscn`'s `collision_layer = 2`), `monitorable = false` (nothing
   needs to detect them back). `CameraHint`'s own layer is entirely the
   camera agent's contract (see `HINT_COLLISION_LAYER` in their file) —
   this pass never touches it.

## Deviations from the brief (noted per house convention)

- **Both worlds are built almost entirely procedurally in `_ready()`**
  (primitive meshes + matching collision generated in GDScript), rather than
  hand-authoring dozens of `sub_resource`/`Transform3D` blocks directly in
  `.tscn` text. Only `worlds/common/dreamling.tscn` and
  `worlds/common/dream_door.tscn` are hand-authored scenes (as the brief's
  file list explicitly names both a `.tscn` and a `.gd` for those two);
  `worlds/common/world_door.gd` builds its own doorframe mesh in code (the
  brief lists only a `.gd` for it, no `.tscn`). Justification: this class of
  geometry (spheres embedded as hills, a `PrismMesh`-wedge ramp with a
  `create_trimesh_shape()`-derived collider, sphere-surface-anchored prop
  placement) is much safer to get right in code — see `_sphere_surface_y()`
  — than by hand-computing dozens of world-space transforms for a raw
  `.tscn` file with no engine feedback while authoring.
- **`BreathingChest` and `SnoreGeyser` live in `worlds/bramble/`, not
  `worlds/common/`**, since the brief describes them under the Bramble
  section specifically (not the shared common-module list in item 1) and
  nothing else currently reuses them; both build their own visuals/colliders
  from `@export` parameters, so promoting them to `worlds/common/` later
  (for e.g. Wisp's sky geysers) would be a one-line move, not a rewrite.
- **Fort's single doorway faces away from the spawn side (the clearing's far
  edge), not the near side.** Chosen so a single opening can do double duty
  as both "the fort door" (PITCH.md: "from the fort's doorway you can see
  the whole skyline of sleeping giants") and the literal `BrambleDoor` exit
  trigger — standing at/near the doorway looking further into the clearing
  is the same view as looking toward Bramble's silhouette 80 m beyond it.
- **Moat implemented as a second, larger, lower static slab** (not a ramped
  or sloped transition) — a player walking off the meadow's edge steps down
  ~1.5 m onto the moat (a safe, minor drop, not a rescue trigger) before
  reaching the moat's own outer edge, beyond which there is genuinely no
  ground and `rescue_floor_y = -8.0` catches the fall. Matches "so walking
  off the map ends in rescue, not infinity" without needing a sloped/ramped
  mesh.
- **`Dreamling`'s idle bob was changed from world-space to parent-local
  space mid-build** (`worlds/common/dreamling.gd`): the original draft set
  `global_position` directly from a world-space anchor captured once at
  `_ready()`, which would have fought the `BreathingChest`'s motion every
  physics frame for d06 (the one dreamling parented to a moving node) —
  it would have hovered at a fixed world height instead of riding the
  plank. Fixed to bob in local `position` instead, which is a no-op change
  for the other nine dreamlings (static parents) and makes d06 correctly
  ride the chest before it's ever touched.
- **`WorldBase.remaining()`** is a small convenience getter not in the
  contract (SPEC.md only requires the three signals + four methods) — left
  in for future fort-growth/HUD work since the bookkeeping was already
  there for the completion check.

## Files created

```
worlds/common/dreamling.gd
worlds/common/dreamling.tscn
worlds/common/dream_door.gd
worlds/common/dream_door.tscn
worlds/common/world_base.gd
worlds/common/world_door.gd
worlds/pillow_fort/pillow_fort.gd
worlds/pillow_fort/pillow_fort.tscn
worlds/bramble/bramble.gd
worlds/bramble/bramble.tscn
worlds/bramble/breathing_chest.gd
worlds/bramble/snore_geyser.gd
docs/verify/worlds-VERIFY.md
```

No files outside `worlds/**` and this `docs/verify/` receipt were modified.
No git commit made, per instructions.
