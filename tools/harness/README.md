# tools/harness — autoplay harness

`tools/harness/harness.gd` is the `Harness` autoload (registered in
`project.godot`, last in the `[autoload]` list). It parses CLI flags at
boot, can play back a scripted input sequence, logs a greppable JSON-line
event stream, takes screenshots at chosen physics frames, and provides a
scene-agnostic `--quitafter` fallback. See SPEC.md §"Autoplay harness" and
docs/DECISIONS.md D11 for the contract this implements.

Console binary for anything whose stdout is a receipt (`godot.exe` is
GUI-subsystem and eats output):

```
D:\Tools\godot\godot_console.exe
```

## CLI flags (passed after `--` on the command line)

| Flag | Effect |
|---|---|
| `--skipmenu` | boot.gd routes straight to `scenes/main.tscn` instead of the title screen |
| `--seed=N` | seeds the global RNG (`seed(N)`) at the earliest possible moment (`Harness._init()`) — deterministic replay for anything using `randi()`/`randf()` |
| `--world=<id>` | which world `scenes/main.gd` loads (already consumed by `main.gd`; Harness just carries the flag) |
| `--pads=0\|1\|2` | simulated seat count. Calls `InputRouter.force_mode(N)` **if that method exists**; `InputRouter` currently has no override API (by design — the harness agent does not edit `InputRouter`), so today this logs `HARNESS_NOTE pads flag pending integration` instead. Wire `force_mode()` into `InputRouter` to activate it. |
| `--script=<path>` | input-playback JSON, relative to the project root, e.g. `tools/harness/scripts/first_steps.json` |
| `--shots=N,M,…` | physics-frame numbers (offset from Harness's own `_ready()`, i.e. from very early in boot) at which to save a PNG screenshot to `--outdir` |
| `--outdir=<dir>` | relative to the project root; screenshots and `events.jsonl` land here |
| `--quitafter=SECONDS` | `scenes/main.gd` already honors this from its own `_ready()`; Harness *also* starts an independent `SceneTreeTimer` from its own `_ready()` so the process quits after N seconds from **any** scene (title, a future test scene, etc.), not just `main.tscn`. Both timers firing is harmless (redundant `get_tree().quit()`). |

`Harness.flags: Dictionary` and `Harness.flag(name, default)` are the
stable public API other scripts (`boot.gd`, `scenes/main.gd`) already read.

## Input-playback script format

```json
{
  "description": "...",
  "events": [
    {"frame": 120, "seat": 1, "action": "jump", "type": "press"},
    {"frame": 126, "seat": 1, "action": "jump", "type": "release"},
    {"frame": 200, "seat": 1, "action": "move", "vec": [0.0, -1.0]},
    {"frame": 400, "seat": 1, "action": "move", "vec": [0, 0]}
  ]
}
```

- `frame` is a **physics-frame** count (`Engine.get_physics_frames()`)
  offset from when `Harness._ready()` ran — deterministic under
  `--fixed-fps` because fixed-fps steps simulate at a constant delta
  regardless of wall-clock speed (pipeline.md §2.1).
- `press`/`release` actions call `Input.action_press("p<seat>_<action>")` /
  `action_release`.
- `"action": "move"` decomposes `vec` onto the four directional actions:
  negative `y` = up/forward (`-Z`), positive `y` = down/back; negative `x`
  = left, positive `x` = right. The opposite action on each axis is
  released before the new one is pressed; `strength` = `abs(component)`.
- Events execute on-or-after their frame (a tick the engine happened to
  skip still fires the event late rather than dropping it silently).
- Every executed event prints `HARNESS_EVENT {...}` (the raw event dict).

Samples: `scripts/first_steps.json` (baseline walk/jump/walk-back smoke
test), `scripts/jump_props.json` (coyote-time / jump-buffer property demo —
commented expected outcomes in its `description`; needs a world with an
actual ledge/platform to observe the forgiveness-window behavior, so it's a
documented no-op against the scaffold's flat grey-box fallback floor).

## Event log

`Harness` connects (deferred, after the tree is ready) to
`GameState.dreamling_collected` / `dream_returned` / `world_completed`, and
to `jumped` / `landed` on every `PlayerBody` found under the tree — plus
any `PlayerBody` added later (`SceneTree.node_added`), so it survives scene
changes without re-wiring. Each fires one line:

```
EVT {"t":<physics_frame>,"type":"jumped","seat":1}
```

`t` is always `Engine.get_physics_frames()` — never a wall-clock read — so
the whole log is reproducible byte-for-byte across runs under
`--fixed-fps` (see docs/verify/harness-VERIFY.md for the proof).

When `--outdir` is given, every `HARNESS_FLAGS` / `HARNESS_NOTE` /
`HARNESS_EVENT` / `EVT` line Harness itself prints is **also** appended to
`<outdir>/events.jsonl` (directory created on demand, file opened lazily on
first write, flushed after every line so a crash doesn't lose the tail).

### What's NOT in events.jsonl: MOON_SAID / RESCUE / WARP / TOSS

`TheMoon.say()` prints `MOON_SAID {...}` itself; the core-feel agent's
rescue/carry-toss code prints `RESCUE`/`WARP`/`TOSS` lines itself. Both are
plain `print()` calls in files outside `tools/harness/**`. GDScript has no
engine-wide print-interception hook, and the two ways that would get those
lines into `events.jsonl` automatically — editing `the_moon.gd`/the core
rescue script to also write to Harness's file, or turning on Godot's
boot-time `debug/file_logging` project setting — both require edits outside
this harness's file boundary. Those lines still land in the process's
normal stdout exactly as before (nothing is lost); to capture a **complete**
transcript including them, run with Godot's own native `--log-file <path>`
engine flag alongside `--outdir`, e.g.:

```
D:\Tools\godot\godot_console.exe --headless --path . --log-file evidence\_scratch\run\console.log -- --skipmenu --script=tools/harness/scripts/first_steps.json --outdir=evidence/_scratch/run --quitafter=8
```

`--log-file` is a real engine-level flag (confirmed in sibling-project
prior art, `un_party_game/docs/verify/online-greed-VERIFY.md`) that
duplicates *all* stdout — including `MOON_SAID`/`RESCUE`/`WARP`/`TOSS` — to
disk regardless of which script printed it. Point it at a **different**
path than `--outdir`'s `events.jsonl` (two independent writers to the same
file corrupt it — the same gotcha the sibling project already hit with two
processes).

## Screenshots

`--shots=300,600` captures a PNG at those physics frames (same
playback-start-relative counting as script events) to
`<outdir>/shot_<frame>.png`, via `await RenderingServer.frame_post_draw` +
`get_viewport().get_texture().get_image().save_png(...)`. If
`DisplayServer.get_name() == "headless"` this is skipped with a
`HARNESS_NOTE` instead of erroring — screenshots need a real window
(Movie Maker has the same requirement, see below).

## Movie recipe (video receipts, D11)

Movie Maker needs a real display driver — **never `--headless`** with
`--write-movie` (the `headless` display driver's only rasterizer is
`dummy`, which produces no real pixel data). The window does not need
focus or visibility, just needs to exist.

```
D:\Tools\godot\godot_console.exe --path . --write-movie evidence\<name>.avi --fixed-fps 60 --resolution 1280x720 -- --skipmenu --script=tools/harness/scripts/first_steps.json --quitafter=60
```

Transcode to a phone-playable mp4 (`ffmpeg` is on PATH at
`D:\Tools\ffmpeg\ffmpeg-8.1.2-essentials_build\bin`):

```
ffmpeg -y -i evidence\<name>.avi -c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium -movflags +faststart evidence\<name>.mp4
```

Shutdown must be clean — `--quitafter`/`get_tree().quit()`, **never**
Ctrl+C or `taskkill` mid-record, or the AVI is left with no duration header
and won't play.

## Determinism

Run the same command twice with `--fixed-fps 60` added and diff the two
`events.jsonl` files — they should be byte-identical (no wall-clock field
exists anywhere in the log format, by design). See
`docs/verify/harness-VERIFY.md` for the actual verification run.
