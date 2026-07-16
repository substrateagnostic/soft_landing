# PROPERTIES VERIFY — post-Gate-2 property pass (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
Headless property runs use `--fixed-fps 60` (except P6, which is windowed
and deliberately omits it — see P6). Receipts quoted verbatim (trimmed).
Full run logs under `evidence/_scratch/props/*.log`.

Scope: clears the UNVERIFIED jump-buffer positive case and the d10
placement bug from `docs/verify/gate2-slice-VERIFY.md` §UNVERIFIED, adds a
placement-sanity property (P2), and pulls three Gate 4 DoD items
(save-corruption recovery, hot-swap, perf) forward for an early property
pass. Territory: `tools/harness/**`, `tools/props/**`, one line + comment
in `worlds/bramble/bramble.gd` (the d10 constant), this file,
`evidence/_scratch/props/**`.

## Verdict table

| # | Property | Verdict | Receipt |
|---|---|---|---|
| P1 | Jump buffer positive case | **PASS** | §P1 |
| P2 | Placement sanity (tool) | **PASS** (tool works; flags one pre-existing, out-of-territory finding — d07) | §P2 |
| P3 | d10 fix | **PASS** | §P3 |
| P4 | Save corruption recovery | **PARTIAL** (all player-facing criteria pass; one engine-level stdout ERROR line exists — see nuance) | §P4 |
| P5 | Hot-swap mode | **PASS** | §P5 |
| P6 | Perf receipt | **INSTRUMENTED & RUN** (min 3.0 fps — investigated, found to be a sandboxed-session presentation artifact, not scene cost; reported per brief, not "fixed") | §P6 |

---

## P1 — Jump buffer positive case

`core/movement/movement_tuning.gd`: `jump_buffer = 0.22s` (13.2 physics
frames @60fps). Property: a jump pressed 0.1s–0.22s before landing fires
within a few frames AFTER landing; a jump pressed 0.3s before landing does
NOT fire (buffer expired at touchdown).

**Step 1 — measure the real landing frame** (no jump presses, so the run is
pure ballistics): teleport Pip to `(0,4,0)` on `pillow_fort`'s flat
`ClearingGround` (top at y=0.0) at frame 60.

```
godot_console.exe --headless --fixed-fps 60 --path . -- --skipmenu \
  --world=pillow_fort --pads=1 --script=tools/harness/scripts/jump_buffer_measure.json \
  --poslog=2 --outdir=evidence/_scratch/props/p1_measure --quitafter=5
```
```
HARNESS_TELEPORT {"pos":[0.0,4.0,0.0],"seat":1}
PLAYER_POS {"seat":1,"t":60,"x":0.0,"y":4.0,"z":0.0}
...
EVT {"seat":1,"t":96,"type":"landed"}
PLAYER_POS {"seat":1,"t":98,"x":0.0,"y":0.45,"z":0.0}
```
Landing measured at **t=96** (36 frames after the f60 teleport; resting
y=0.45 on this ground).

**Step 2 — lock the property script to the measured frame**
(`tools/harness/scripts/jump_buffer.json`): EPISODE A (positive case) —
same teleport at f60, jump pressed at **f86** (96−86=10 frames=166.7ms,
inside the 6–13.2 frame / 0.1–0.22s window). EPISODE B (control) — a second
identical teleport at f250 (lands at f286 by the same 36-frame fall), jump
pressed at **f268** (286−268=18 frames=300ms, outside the window).

```
godot_console.exe --headless --fixed-fps 60 --path . -- --skipmenu \
  --world=pillow_fort --pads=1 --script=tools/harness/scripts/jump_buffer.json \
  --poslog=1 --outdir=evidence/_scratch/props/p1_test --quitafter=6
```
```
HARNESS_EVENT {"action":"teleport","frame":60,"pos":[0.0,4.0,0.0],"seat":1}
HARNESS_EVENT {"action":"jump","frame":86,"seat":1,"type":"press"}
EVT {"seat":1,"t":96,"type":"landed"}
EVT {"seat":1,"t":97,"type":"jumped"}
EVT {"seat":2,"t":97,"type":"jumped"}          # Otto's buddy-AI jump mirror (solo, pads=1) — expected, not the property under test
...
HARNESS_EVENT {"action":"teleport","frame":250,"pos":[0.0,4.0,0.0],"seat":1}
HARNESS_EVENT {"action":"jump","frame":268,"seat1":1,"type":"press"}
EVT {"seat":1,"t":286,"type":"landed"}          # no "jumped" EVT anywhere near this landing
```
Full-log grep for every `"type":"jumped"` line in the run returns exactly
the two at t=97 (Pip + Otto's mirror) — **none** near the f286 control
landing. PLAYER_POS confirms the buffered jump was a real physical launch,
not just the signal: y settles to 0.45 at t=96/97 then climbs again
(0.56, 0.67, 0.77… from t=98) — the jump actually fired.

**Landed→jumped gap: 97−96 = 1 frame** (≤3 frame requirement met).
**PASS**: positive case fires within 1 frame of landing; control (0.3s
early) correctly does not fire.

---

## P2 — Placement sanity property

Tool: `tools/props/check_placements.gd`, a standalone `SceneTree` script
(run via `--script`, no `scenes/main.tscn` involved — no players, no
camera, just world geometry + Dreamlings). For each world it instantiates
`<id>.tscn` under the live root, waits a few physics frames for
`PhysicsServer3D` to register colliders, then per Dreamling: (a) a
`PhysicsDirectSpaceState3D.intersect_point` at its exact position against
world-geometry layer 1 (any hit = embedded), (b) a downward
`intersect_ray` on the same layer (the vertical gap to the first hit must
be 0–2.0m, unless the dreamling's parent isn't the world root — the
moving-platform case, d06 on Bramble's breathing chest).

**Two bugs hit building this tool, both documented in the script's own
header comments:**
1. A static `is Dreamling` type check pulled `dreamling.gd` in as a
   compile dependency of the tool script itself; `dreamling.gd` references
   the `AudioManager` autoload, which is not yet a resolvable GDScript
   global identifier at the point a bare `--script` main loop's target
   file is first parsed (confirmed: this only happens under `--script`,
   never under the normal `boot.tscn -> main.tscn` path). The failure gets
   cached, permanently breaking every later `DreamlingScene.instantiate()`
   call for the rest of the process — every Bramble dreamling silently
   failed to spawn (`_add_dreamling` errored `Invalid assignment... base
   object of type Nil` ten times, `bramble has zero dreamlings`). Fixed by
   switching to a duck-typed check (`node.get_script().resource_path ==
   "res://worlds/common/dreamling.gd"`) so the tool never statically
   references the `Dreamling` class at all.
2. A real save.json with `bramble.returned: ["d10"]` would make
   `WorldBase._wire_dreamlings()` `queue_free()` d10 before the tool could
   ever inspect it — exactly the dreamling this property exists to check.
   Fixed in-tool (no file I/O): before instancing a world, the tool erases
   that world's key from the live `GameState.dreamlings` dict (an
   in-memory autoload mutation, scoped to this one-shot process — the save
   *file* is never opened by this tool).

**Caveat, documented not worked around**: `intersect_point` does not
support concave/trimesh shapes per Godot docs — Bramble's paw ramps use
`ConcavePolygonShape3D`. No current dreamling sits inside a paw ramp
(d03/d04 sit ON one), so this is a latent blind spot, not a live miss.

```
godot_console.exe --headless --path . --script tools/props/check_placements.gd
```

**Before the d10 fix** (`evidence/_scratch/props/p2_before.log`):
```
PLACEMENT_NOTE pillow_fort has zero dreamlings (nothing to check)
PLACEMENT {"ground_gap":7.66,...,"id":"d07","inside_solid":false,"moving_platform":false,"pos":[54.0,18.06,4.0],"verdict":"FAIL","world":"bramble"}
PLACEMENT {"ground_gap":1.75,"has_ground":true,"id":"d10","inside_solid":true,"moving_platform":false,"pos":[50.0,13.03,4.5],"verdict":"FAIL","world":"bramble"}
PLACEMENT_SUMMARY {"any_fail":true,"worlds":["pillow_fort","bramble"]}
```
d10: `inside_solid: true` — confirmed embedded, matching the known bug in
`gate2-slice-VERIFY.md` §UNVERIFIED. All other dreamlings (d01–d06, d08,
d09) PASS.

**d07 (out of territory, flagged not fixed)**: `inside_solid: false` — it
is NOT buried. It sits atop a `SnoreGeyser` blast column
(`worlds/bramble/snore_geyser.gd`, an `Area3D` updraft, `collision_layer =
0`, invisible to this property's layer-1 queries) and is reachable only by
riding the updraft — a legitimate third placement category ("launch
volume") that P2's two-category model (standable ground OR moving
platform) doesn't recognize. This is a real, honest FAIL under the
property as specified, not a tool bug and not a buried-dreamling bug; my
brief authorizes editing only the d10 line in `bramble.gd`, so it is
reported here rather than silently fixed or the property loosened to hide
it.

---

## P3 — d10 fix

`worlds/bramble/bramble.gd`, `_build_dreamlings()`: only the d10 position
constant + its comment changed.

**Before**: `Vector3(EAR_ANCHOR_X, 0.0, EAR_ANCHOR_Z - 1.5)` — 1.50m from
the ear-bump sphere's center (`EAR_BUMP_RADIUS = 1.8`), i.e. embedded
1.8−1.50=0.30m deep.

**After**: `Vector3(EAR_ANCHOR_X, 0.0, EAR_ANCHOR_Z - 2.3)` — 2.30m from
the same center, clearing the required 1.8 + 0.35 (dreamling clearance) =
2.15m by 0.15m, while the Y assignment (unchanged, still anchored via
`_sphere_surface_y(HEAD_CENTER, HEAD_RADIUS, EAR_ANCHOR_X, EAR_ANCHOR_Z) +
EAR_BUMP_HEIGHT`) keeps it sitting visibly on the bump's surface height,
1.51m above the head mound directly below it (well inside the door
collect route — DreamDoor's trigger box is `Vector3(3.6,4.6,3.6)`
centered on the same point).

**After the fix** (`evidence/_scratch/props/p2_after.log`):
```
PLACEMENT {"ground_gap":1.52,"has_ground":true,"id":"d10","inside_solid":false,"moving_platform":false,"pos":[50.0,12.99,3.7],"verdict":"PASS","world":"bramble"}
PLACEMENT_SUMMARY {"any_fail":true,"worlds":["pillow_fort","bramble"]}   # any_fail still true — d07 only (§P2)
```
d10: `inside_solid: false`, `ground_gap: 1.52` (within 0–2.0m). **PASS**
for d10 specifically, before(FAIL)/after(PASS) shown above. (Small
run-to-run jitter in other dreamlings' `ground_gap`, e.g. d01/d02/d09, is
the idle bob animation's random phase — `Dreamling._bob_phase = randf() *
TAU` — sampled at a slightly different point each run; amplitude ±0.15m,
never crosses a verdict threshold.)

---

## P4 — Save corruption recovery

Real save at `%APPDATA%\Godot\app_userdata\THE BIG NAP\save.json` held the
producer's Gate 2 receipt state (`fort_stage:1`, `bramble.returned:
["d10"]`) — backed up first, restored last, byte-diffed to confirm.

```
cp "$SAVE" evidence/_scratch/props/save_backup_original.json
```
```json
{"fort_stage":1,"total_dreams":1,"version":1,"worlds":{"bramble":{"collected":["d10"],"completed":false,"returned":["d10"]}},...}
```

**Corrupt the save**, then boot with a script that teleports Pip directly
onto bramble's d01 to prove a real post-recovery save write, not just a
boot-time default:
```
printf '{ this is not valid json at all !!! %%%% corrupt data ]]]' > "$SAVE"
godot_console.exe --headless --fixed-fps 60 --path . -- --skipmenu \
  --world=bramble --pads=1 --script=tools/harness/scripts/save_corruption_collect.json \
  --outdir=evidence/_scratch/props/p4_save --quitafter=3
```
```
ERROR: Parse JSON failed. Error at line 0: Expected key
   at: parse_string (core/io/json.cpp:624)
   GDScript backtrace (most recent call first):
       [0] load_game (res://scripts/autoloads/save_manager.gd:51)
       [1] _ready (res://scripts/autoloads/save_manager.gd:14)
SaveManager: save.json unreadable, quarantining as save.bak.json
...
EVT {"id":"d01","t":62,"type":"dreamling_collected","world_id":"bramble"}
HUD_PIP {"id":"d01","state":"carried"}
HARNESS_NOTE quitafter fallback fired (harness-level timer, 3.0s)
```
Process **exits 0**.

Filesystem after boot: `save.bak.json` exists and holds the exact garbage
bytes (quarantine confirmed). `save.json` is a fresh, valid file reflecting
the one collect:
```json
{"fort_stage":0,"total_dreams":0,"version":1,"worlds":{"bramble":{"collected":["d01"],"completed":false,"returned":[]}},...}
```

**Restore**: `save.json` overwritten with the backed-up original bytes,
`save.bak.json` deleted (test artifact, not something to leave in the
player's profile); `diff` against the backup confirms **IDENTICAL**.

**Verdict nuance — PARTIAL, not a clean PASS**: every player-facing
criterion holds — exit 0, `.bak` quarantine, a genuinely fresh valid save
after normal play resumes, and `SaveManager`'s own code never raises an
error (its quarantine message is a plain `print()`, not `push_error`; no
in-game dialog, no crash — a player watching the screen sees nothing
alarming). But the literal instruction "stdout has no ERROR lines about
the save" is not met: Godot's own `JSON.parse_string()` unconditionally
logs an `ERROR:` line to stdout when the parse fails, from inside the
engine, before `SaveManager.load_game()` ever gets control back — this is
not something `SaveManager`'s GDScript can suppress (no silent-parse mode
exists on `JSON`), and `save_manager.gd` is outside this brief's territory
to edit regardless. Reporting honestly rather than calling it a clean
PASS: the recovery mechanism itself is fully correct; the console
transcript is not error-line-free.

---

## P5 — Hot-swap mode property

`InputRouter.force_mode(pad_count)` is the sanctioned no-physical-pad seam
(already existed). Added to `tools/harness/harness.gd`: a `{"action":
"pads","count":N}` script event (calls the same `force_mode` path as
`--pads`) and a deferred connection to `InputRouter.mode_changed` that
prints `EVT mode_changed` — the harness had no prior window into COOP/SOLO
transitions.

Script `tools/harness/scripts/hotswap.json` (bramble, boots `--pads=2`):
Pip and Otto sit at spawn until f300, then `pads:1` (SOLO) fires at the
same frame Pip starts walking. At f600, `pads:2` (COOP) restores, and Pip
immediately reverses direction — a movement Otto (real, unpressed p2
input) has no reason to mirror unless buddy AI is genuinely off.

```
godot_console.exe --headless --fixed-fps 60 --path . -- --skipmenu \
  --world=bramble --pads=2 --script=tools/harness/scripts/hotswap.json \
  --poslog=5 --outdir=evidence/_scratch/props/p5_hotswap --quitafter=17
```
```
EVT {"mode":0,"mode_name":"COOP","t":1,"type":"mode_changed"}      # --pads=2 applied at boot
EVT {"mode":1,"mode_name":"SOLO","t":300,"type":"mode_changed"}    # pads:1 script event
EVT {"mode":0,"mode_name":"COOP","t":600,"type":"mode_changed"}    # pads:2 script event
```

**Engage (SOLO, f300→f480, 3s window)** — BuddyAI prints nothing today, so
read via PLAYER_POS: Pip and Otto start ~2.83m apart at f300; Otto closes
the gap to ~2.51m by f480 (essentially `follow_distance = 2.5m`, the
buddy's own hold distance) — clear, steady tracking the whole window:
```
PLAYER_POS {"seat":1,"t":300,"x":-55.0,"z":0.0}   PLAYER_POS {"seat":2,"t":300,"x":-57.0,"z":2.0}
PLAYER_POS {"seat":1,"t":390,"x":-49.3,"z":-0.03}  PLAYER_POS {"seat":2,"t":390,"x":-52.35,"z":0.32}
PLAYER_POS {"seat":1,"t":480,"x":-45.02,"z":-0.04} PLAYER_POS {"seat":2,"t":480,"x":-47.53,"z":0.04}
```
(Pip stalls against the haunch mound's slope around f460 — expected
geometry, not a bug in this script; doesn't affect the engage evidence.)

**Disengage (COOP restored, f600→f900)** — Otto freezes at
`(-47.52, 0.65, 0.04)` from t=590 through t=900 (300 frames / 5s),
**never moving a centimeter**, while Pip walks steadily from
`(-45.02,...)` back to `(-64.72,...)` — a 19.7m retreat, growing the gap
from ~2.5m to ~17.5m with zero response from Otto:
```
PLAYER_POS {"seat":2,"t":600,"x":-47.52,"z":0.04}
PLAYER_POS {"seat":1,"t":700,"x":-51.39,...}  PLAYER_POS {"seat":2,"t":700,"x":-47.52,"z":0.04}
PLAYER_POS {"seat":1,"t":900,"x":-64.72,...}  PLAYER_POS {"seat":2,"t":900,"x":-47.52,"z":0.04}
```
**PASS**: mode flips correctly both directions with no crash; buddy AI
demonstrably engages (closes to follow distance within 3s) and disengages
(zero drift for 5s despite a widening gap) exactly at the mode boundaries.

---

## P6 — Perf receipt

Added `--perflog` to `tools/harness/harness.gd`: samples
`Engine.get_frames_per_second()` every 60 physics frames; at quit (from
the harness's own `--quitafter` timer, before `get_tree().quit()`) prints
one `PERF_SUMMARY {"avg":…,"min":…,"p5":…,"samples":n}` line.

Run **windowed** (real rendering, default vsync — `--fixed-fps` and
`--headless` both deliberately omitted, per the brief) over
`gate2_meadow.json` on bramble:
```
godot_console.exe --path . --resolution 1280x720 -- --skipmenu \
  --world=bramble --pads=2 --script=tools/harness/scripts/gate2_meadow.json \
  --perflog --outdir=evidence/_scratch/props/p6_perf --quitafter=30
```
```
Vulkan 1.4.341 - Forward+ - Using Device #0: NVIDIA - NVIDIA GeForce RTX 5070 Ti
...(full 19-event script completes: d01, d02 collected, jump/land, WARP, RESCUE, all as in gate2-slice-VERIFY)...
PERF_SUMMARY {"avg":4.0,"min":3.0,"p5":3.0,"samples":30}
```

**min=3.0 is far below the 55fps bar — investigated per the brief (report,
don't optimize).** Control run on the simplest possible scene
(`pillow_fort`, no script, 8s):
```
godot_console.exe --path . --resolution 1280x720 -- --skipmenu \
  --world=pillow_fort --pads=1 --perflog --quitafter=8
```
```
Vulkan 1.4.341 - Forward+ - Using Device #0: NVIDIA - NVIDIA GeForce RTX 5070 Ti
PERF_SUMMARY {"avg":4.3,"min":3.0,"p5":3.0,"samples":8}
```
Identical ~3–4fps on a scene with essentially no geometry, on a real
Vulkan device (RTX 5070 Ti, confirmed via `Get-CimInstance
Win32_VideoController` — driver status OK, 3440x1440 desktop). This rules
out scene rendering cost as the cause. Meanwhile the gate2_meadow run's
~1640-physics-frame script fully completed inside the 30s wall-clock
budget (physics ticks kept pace with real time via Godot's normal
catch-up stepping), so the simulation itself was not starved — only frame
*presentation* was. This is consistent with running inside this
automated/remote agent session, where the game window is not composited
by a normal interactive desktop session the way it would be on the
golem's own console at the couch. **Honest read, per the brief: this
windowed harness run is the standing instrument, but this specific 3–4fps
number is an artifact of the session it ran in, not a measurement of the
game's real rendering cost — it should be re-run on the golem's actual
interactive Windows session before any Gate 4 perf sign-off.** No
optimization was attempted, per instructions.

---

## .gitignore

Removed a duplicated `evidence/_scratch/` line (the pattern was listed
twice, back to back).

## Deviations (one-line justifications)

- P2's tool checks `inside_solid` via a single point query at the
  dreamling's origin, not a full-shape overlap of its 0.6m collision
  sphere — matches the brief's own wording ("spawn position is... NOT
  inside") and keeps the tool's failure mode symmetric with the
  raycast-from-the-same-point ground check; a full-shape check would need
  a shape-cast API this brief didn't ask for.
- d07's FAIL is reported, not fixed or silenced — outside the d10-only
  edit authorization in `bramble.gd`.
- P4 is graded PARTIAL rather than PASS on the strict "no ERROR lines"
  wording, for the engine-level `JSON.parse_string` diagnostic explained
  above — everything player-facing and mechanically required (rename,
  fresh save, no crash, no in-game message) is fully verified.
- P6's low numbers are reported, investigated with one cheap control run,
  and explicitly NOT treated as a real perf regression to fix — per "don't
  optimize — report."
