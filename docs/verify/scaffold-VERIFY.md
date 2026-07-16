# scaffold-VERIFY.md — shared skeleton (Phase 3 grey-box, pre-parallel-build)

Engine: `D:\Tools\godot\godot_console.exe` → `4.6.2.stable.official.71f334935`.
All three checks re-run after a bugfix (see deviation note below); output
below is the final clean pass.

## a) Headless import

Command:
```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path D:\Projects\soft_landing
```

Output (trimmed to meaningful lines):
```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

[ DONE ] first_scan_filesystem
[   0% ] update_scripts_classes | Started Registering global classes... (13 steps)
[   0% ] update_scripts_classes | CameraHint
[   7% ] update_scripts_classes | MovementTuning
[  14% ] update_scripts_classes | PlayerBody
[  21% ] update_scripts_classes | WorldContract
[ DONE ] update_scripts_classes
[ DONE ] reimport
[ DONE ] loading_editor_layout
```
Exit code: `0`. Zero script errors. All four global classes
(`CameraHint`, `MovementTuning`, `PlayerBody`, `WorldContract`) registered.

## b) Headless run — boot to main via harness flags

Command:
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --quitafter=3
```

Output (verbatim):
```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

HARNESS_FLAGS {"quitafter":"3","skipmenu":true}
Main: world scene not found (res://worlds/pillow_fort/pillow_fort.tscn), spawning grey-box fallback
MOON_SAID {"key":"new_area","text":"A new place to explore. Let's see what's waiting."}
```
Exit code: `0`. Boots straight to `main.tscn` (skipmenu honored), grey-box
fallback (40x40 grey floor + soft moonlight) spawns because `worlds/` doesn't
exist yet (Phase 5, other agents), `Harness.flags.get("quitafter")` schedules
a `SceneTreeTimer` that calls `get_tree().quit()` — process exits cleanly at
~3s with no `--quitafter` CLI flag needed in the harness itself yet (stub
only parses/exposes flags; `main.gd` does the scheduling per the brief's
fallback wiring instruction).

**Bug found + fixed during this verification pass:** the first run of (b)
threw `Condition "!is_inside_tree()" is true` from `_setup_camera()` —
`Camera3D.new()` had `global_position` set *before* `add_child()`, and
`global_position`/`look_at()` require the node to already be inside the
scene tree. Fixed by reordering to `add_child()` first, then
`global_position`/`look_at()` (`scenes/main.gd`). Re-ran (a) and (b) after
the fix; both clean, output above is post-fix.

## c) Grep receipt — no right-stick anywhere

Command:
```
rg "\"axis\": ?[23]" D:\Projects\soft_landing\project.godot
```
Output: `No matches found` (only axis 0 and axis 1 — left stick — appear in
the entire `[input]` section).

Second pass, broader (all scripts, not just project.godot):
```
rg "axis.*[23]|RIGHT_X|RIGHT_Y|right_stick|right stick" D:\Projects\soft_landing --glob "*.gd"
```
Output: `No files found`. No right-stick axis, no `JOY_AXIS_RIGHT_*`
reference, anywhere in the codebase.

## Deviations from the brief (noted per instructions)

- **`worlds/` "two manifest-less placeholder":** the brief's scope line
  ("nothing in worlds/ beyond the two manifest-less placeholder noted
  below") never actually specifies what those two placeholders are anywhere
  in the numbered build steps — treated as a drafting artifact and created
  **nothing** under `worlds/`. `main.gd`'s grey-box fallback (spec-supported:
  "if the scene is missing... spawn a fallback so the game always boots")
  already covers this cleanly, verified by (b) above.
- **Moonlight is unconditional, not fallback-only:** item 9 describes "soft
  directional moonlight" as part of the always-present `WorldEnvironment`
  mood setup, and separately says the missing-world fallback should include
  "a soft directional light." Rather than create two competing lights, one
  `DirectionalLight3D` ("Moonlight") is created unconditionally in
  `main.gd._ready()` — it satisfies both the environment-mood requirement
  and the fallback-light requirement without duplication, and avoids
  double-lighting once a world scene brings its own sun in a later phase.
- **Apex-hang state left unimplemented in `player_body.gd`:** `tuning`
  exposes `apex_hang_threshold`/`apex_gravity_mult` (item 5, required), but
  item 6's "implement" list for `player_body.gd` only calls out rise/fall
  gravity via `fall_gravity_mult`, not the apex-hang state — the brief
  frames this file as "the core-feel agent will extend, not rewrite," and
  apex-hang/carried/tossed/bubbled states are that agent's territory per
  SPEC.md's state list. Left the two tuning fields wired but unused by this
  script.
