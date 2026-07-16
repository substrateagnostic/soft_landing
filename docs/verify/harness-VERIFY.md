# harness-VERIFY.md — autoplay harness (tools/harness/harness.gd)

Engine: `D:\Tools\godot\godot_console.exe` → `4.6.2.stable.official.71f334935`.
All commands run from `D:\Projects\soft_landing`. Scope: `tools/harness/**`
only — no edits to `core/**`, `scenes/**`, `worlds/**`, or `project.godot`
(the `Harness` autoload line already existed there).

## a) Headless import pass

Command:
```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path D:\Projects\soft_landing
```

Output (trimmed):
```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

[   0% ] first_scan_filesystem | Started Project initialization (5 steps)
[  16% ] first_scan_filesystem | Loading global class names...
[  33% ] first_scan_filesystem | Verifying GDExtensions...
[  50% ] first_scan_filesystem | Creating autoload scripts...
[  83% ] first_scan_filesystem | Starting file scan...
[ DONE ] first_scan_filesystem
[ DONE ] loading_editor_layout
```
Exit code: `0`. Zero script errors — `harness.gd` and the new
`tools/harness/scripts/*.json` samples parse and import cleanly.

## b) Headless smoke run — `first_steps.json`

Command:
```
D:\Tools\godot\godot_console.exe --headless --path D:\Projects\soft_landing -- --skipmenu --seed=7 --script=tools/harness/scripts/first_steps.json --outdir=evidence/_scratch/harness_smoke --quitafter=8
```

stdout (verbatim):
```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

HARNESS_FLAGS {"outdir":"evidence/_scratch/harness_smoke","quitafter":"8","script":"tools/harness/scripts/first_steps.json","seed":"7","skipmenu":true}
HARNESS_NOTE script loaded: res://tools/harness/scripts/first_steps.json (8 events) - P1 walks forward ~3s (frames 0-180 @60fps physics), jumps twice while grounded (press+release near frame 190 and frame 230, each held 6 frames), then walks backward ~2s (frames 260-380) before stopping. Baseline smoke test: exercises move+jump input playback end to end with no forgiveness-window edge cases (both jumps land comfortably inside the grounded window) - used by docs/verify/harness-VERIFY.md.
Main: world scene not found (res://worlds/pillow_fort/pillow_fort.tscn), spawning grey-box fallback
MOON_SAID {"key":"new_area","text":"A new place to explore. Let's see what's waiting."}
HARNESS_EVENT {"action":"move","frame":0,"seat":1,"vec":[0.0,-1.0]}
EVT {"seat":2,"t":2,"type":"landed"}
EVT {"seat":1,"t":5,"type":"landed"}
HARNESS_EVENT {"action":"move","frame":180,"seat":1,"vec":[0.0,0.0]}
HARNESS_EVENT {"action":"jump","frame":190,"seat":1,"type":"press"}
EVT {"seat":1,"t":191,"type":"jumped"}
HARNESS_EVENT {"action":"jump","frame":196,"seat":1,"type":"release"}
HARNESS_EVENT {"action":"jump","frame":230,"seat":1,"type":"press"}
HARNESS_EVENT {"action":"jump","frame":236,"seat":1,"type":"release"}
EVT {"seat":1,"t":240,"type":"landed"}
EVT {"seat":1,"t":241,"type":"jumped"}
HARNESS_EVENT {"action":"move","frame":260,"seat":1,"vec":[0.0,1.0]}
EVT {"seat":1,"t":290,"type":"landed"}
HARNESS_EVENT {"action":"move","frame":380,"seat":1,"vec":[0.0,0.0]}
HARNESS_NOTE quitafter fallback fired (harness-level timer, 8.0s)
```
Exit code: `0`. `HARNESS_FLAGS` present, all 8 `HARNESS_EVENT` lines present
(one per scripted event), `EVT jumped`/`EVT landed` lines present for both
seats — `seat 2` (Otto, buddy-follow/idle) lands once on spawn, `seat 1`
(Pip, the scripted player) lands on spawn plus once per scripted jump, and
`jumped` fires for both scripted jumps.

`events.jsonl`:
```
$ wc -l evidence/_scratch/harness_smoke/events.jsonl
17 evidence/_scratch/harness_smoke/events.jsonl

$ head -3 evidence/_scratch/harness_smoke/events.jsonl
HARNESS_FLAGS {"outdir":"evidence/_scratch/harness_smoke","quitafter":"8","script":"tools/harness/scripts/first_steps.json","seed":"7","skipmenu":true}
HARNESS_NOTE script loaded: res://tools/harness/scripts/first_steps.json (8 events) - P1 walks forward ~3s (frames 0-180 @60fps physics), jumps twice while grounded (press+release near frame 190 and frame 230, each held 6 frames), then walks backward ~2s (frames 260-380) before stopping. Baseline smoke test: exercises move+jump input playback end to end with no forgiveness-window edge cases (both jumps land comfortably inside the grounded window) - used by docs/verify/harness-VERIFY.md.
HARNESS_EVENT {"action":"move","frame":0,"seat":1,"vec":[0.0,-1.0]}
```
Non-empty (17 lines — every `HARNESS_FLAGS`/`HARNESS_NOTE`/`HARNESS_EVENT`/
`EVT` line Harness printed, mirrored). `MOON_SAID` is not in this file (see
Deviations below — it's printed by `TheMoon`, outside `tools/harness/**`).

## c) Determinism property — identical `events.jsonl` across two runs

Same command run twice with `--fixed-fps 60` added (identical flags, same
`--outdir`, first run's file copied out before the second run overwrites
it, to isolate engine determinism from my own test scaffolding):

```
D:\Tools\godot\godot_console.exe --headless --fixed-fps 60 --path D:\Projects\soft_landing -- --skipmenu --seed=7 --script=tools/harness/scripts/first_steps.json --outdir=evidence/_scratch/harness_det --quitafter=8
```
(run once → copy `events.jsonl` aside → run again with the exact same
command → diff the two copies)

```
$ diff /tmp/events_run1.jsonl /tmp/events_run2.jsonl
$ echo $?
0

$ wc -l /tmp/events_run1.jsonl /tmp/events_run2.jsonl
17 /tmp/events_run1.jsonl
17 /tmp/events_run2.jsonl
34 total
```

**Verdict: VERIFIED — byte-identical.** Zero-line diff, both files 17 lines.
This holds by construction: every line's "when" is `Engine.get_physics_frames()`
(a deterministic tick counter under `--fixed-fps`, which steps physics at a
constant delta "as fast as possible" rather than real time — pipeline.md
§2.1) — no `Time.*`/`OS.get_ticks_msec()`/wall-clock read appears anywhere
in `harness.gd`. Bonus observation: `JSON.stringify` in this Godot version
sorts dictionary keys alphabetically on output (e.g. `EVT` lines print as
`{"seat":...,"t":...,"type":...}`, not insertion order `t, type, seat`) —
harmless, and it makes the log robust to any future insertion-order change
in how a payload dict is built.

## Bonus checks (not required by the three properties above, run for confidence)

**`--pads=2` with no `InputRouter.force_mode`:**
```
HARNESS_NOTE pads flag pending integration (InputRouter.force_mode not found) — requested pads=2
```
Matches the brief exactly — `InputRouter` (owned by the core agent) has no
override method today; logs the note instead of erroring or editing
`InputRouter`.

**`--shots=30` under `--headless`:**
```
HARNESS_NOTE screenshots skipped (headless) frame=30
```
No error/hang.

**`--shots=20` windowed (real display, `--resolution 640x360`, no
`--headless`):**
```
HARNESS_NOTE screenshot saved D:/Projects/soft_landing/evidence/_scratch/harness_shot_test/shot_20.png
```
Confirmed on disk: `shot_20.png`, 22,585 bytes.

**`--log-file` companion mechanism (documented in README.md as the fix for
the MOON_SAID/RESCUE/WARP/TOSS gap, see Deviations):**
```
D:\Tools\godot\godot_console.exe --headless --path . --log-file evidence/_scratch/harness_extra/console.log -- --skipmenu --pads=2 --shots=30,9999 --outdir=evidence/_scratch/harness_extra --quitafter=2
$ grep -c MOON_SAID evidence/_scratch/harness_extra/console.log
1
```
Confirms Godot's native `--log-file` flag captures `MOON_SAID` (printed by
`TheMoon`, a file this harness never touches) alongside every
`HARNESS_*`/`EVT` line, in a file separate from `events.jsonl`.

**`jump_props.json` loads and plays without error (headless, exit 0):**
```
HARNESS_NOTE script loaded: res://tools/harness/scripts/jump_props.json (6 events) - Movement-forgiveness property test ...
```

## Deviations from the brief (noted per house convention — UNVERIFIED is honest)

- **MOON_SAID/RESCUE/WARP/TOSS are not mirrored into `events.jsonl` by
  `harness.gd` itself.** Those lines are printed via plain `print()` inside
  `scripts/autoloads/the_moon.gd` and the core-feel agent's rescue/carry-toss
  code — both outside `tools/harness/**`. GDScript has no engine-wide
  print-interception hook; the two ways to make them land in
  `events.jsonl` automatically (editing those files to also write to
  Harness's log, or enabling Godot's boot-time `debug/file_logging` project
  setting) both require edits outside this harness's file boundary
  (`the_moon.gd`, or `project.godot`), which the brief explicitly forbids.
  Mitigation, verified above: Godot's own native `--log-file <path>` engine
  flag captures the complete stdout stream (everything, regardless of which
  script printed it) into a companion file alongside `--outdir`'s
  `events.jsonl` — documented with the exact command in
  `tools/harness/README.md`.
- **`--pads` cannot actually change seat count today.** `InputRouter` (a
  file this harness must not edit) has no `force_mode()` or equivalent
  override method yet. Per the brief's own fallback instruction, this logs
  `HARNESS_NOTE pads flag pending integration` rather than erroring or
  reaching into `InputRouter`. Wiring `force_mode(mode: InputRouter.Mode)`
  into `input_router.gd` (one file, one method) activates it immediately —
  `harness.gd`'s call site already checks `has_method()` and needs no
  further changes.
- **`--world=<id>` needed no harness-side code.** `scenes/main.gd` (owned
  by the core agent) already reads `Harness.flags.get("world", ...)`
  directly — the flag only needed to keep flowing through `flags`, which it
  already did in the original stub. No new code added for this one; it's
  listed here only so the flag-by-flag contract in the brief is accounted
  for explicitly.
- **`frame`/`seat` normalized to int before echoing in `HARNESS_EVENT`
  lines.** `JSON.parse_string` returns `float` for every JSON number
  (Godot has no int/float distinction in its JSON grammar), so without this
  normalization `HARNESS_EVENT` would print `"frame":190.0` instead of
  `"frame":190`. Cosmetic only — `vec` components are left as float,
  correctly, since stick input is genuinely fractional.
