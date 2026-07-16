# DREAMKEEPER & DRESSING M2 — VERIFICATION (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
**served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic), running as
the dreamkeeper/dressing build agent inside a Claude Code session.

Scope: `DIRECTION_V2.md` Pillar 3 ("Everything is glad you're here...
rescued dreamlings populate the fort and *remember you*... the world's
aliveness is the progress bar you can walk around inside") and
`docs/research/v2/aliveness_wow.md` §5/§11 ("dreamlings returned to a giant
should not simply disappear into a counter... they belong in the hub fort
as small, huggable, zero-dialogue residents with one idle animation and one
'notice the player' reaction"). New Meshy props behind the D10 seam
(`assets/models/meshy/generated/`) dressed into three worlds; two rigged
Dreamkeeper NPCs (lamb, moth-shepherd) placed and wired to a shared
zero-dialogue presence component.

Territory (per brief): `worlds/pillow_fort/pillow_fort.gd`,
`worlds/wisp/wisp.gd`, `worlds/marmalade/marmalade.gd`,
`worlds/common/dreamkeeper.gd` + `dreamkeeper.tscn` (new files only),
`data/dreamkeepers/*.json` (new), this file. `worlds/bramble/**`,
`core/**`, `scenes/**`, and every existing `worlds/common/*` file were left
untouched.

---

## What shipped

**`worlds/common/dreamkeeper.gd` (`class_name Dreamkeeper`) + `dreamkeeper.tscn`**
A reusable, zero-dialogue NPC component. Loads `scenes/players/rigs/
<rig_id>_rig.tscn` via a runtime-built `RiggedModelSlot` (D19 seam, same
scale/ground contract every rigged character already uses — mesh-local
AABB, no ancestor-transform double-count) plus a grey-box capsule fallback
that stays visible if the rig is ever missing. `model_id`/`target_height`
are set on the slot **before** `add_child()` (this codebase's established
ordering rule — `_ready()` is never guaranteed synchronous inside
`add_child()`, per `critter.gd`'s `kind`/`world_id` doc comment and
`TailBridge`'s position-before-add_child note); rig readiness is read via
`has_rig()`/`rig_root`/`anim_player` **or** the `rig_ready` signal, covering
both possible orderings exactly like `core/art/character_animator.gd`.

Behavior loop (two-state machine, `ASLEEP`/`AWAKE`):
- `ASLEEP` — plays `sleep` (looped), facing its authored `face_yaw_degrees`.
- A player within `WAKE_RADIUS` (4 m) → `AWAKE`: plays `idle` (looped),
  turns smoothly to face the nearest player (`lerp_angle`, matching
  `character_animator.gd`'s own face-camera pattern), fires one `wave`
  ~1 s after waking (long enough for the turn to read), then another `wave`
  every 5-9 s while anyone stays close.
- No player within `WAKE_RADIUS` for `SLEEP_DELAY` (6 s) → back to `ASLEEP`.
- `GameState.dream_returned` (**any** world/id) → interrupts whatever is
  playing for one `cheer`, then resumes idle/sleep exactly where the state
  machine already had it — fires even for a keeper alone and asleep in a
  different world ("even from afar" per the brief).

No collision shape on a Dreamkeeper — deliberate: pure presence, never a
physical obstacle, so it can never block a route regardless of placement.

Receipt (rate-limited via a 0.5 s cooldown, `critter.gd`/`touch_react.gd`'s
own pattern): `DREAMKEEPER {"id":..., "event":"wake"|"wave"|"cheer"|"sleep"}`.

**Placement** — `data/dreamkeepers/{pillow_fort,wisp}.json` (schema: `id`,
`rig`, `pos`, `face_yaw`), loaded by a small `_build_dreamkeepers()` +
`_spawn_dreamkeeper()` pair duplicated verbatim in `pillow_fort.gd` and
`wisp.gd` (a direct per-world spawn call, not a `WorldBase._wire_*` hook —
this pass's territory excludes editing `worlds/common/world_base.gd`).
- **Fort**: `lamb_fort_guest` (`lamb_keeper`, height 0.85) beside the west
  (dusk-blue) cushion, `(-4.7, 0, -3.8)` — the *east* cushion/Callie's-
  cushion/BrambleDoor side is where `finale_home.json`'s route runs (see
  below), so the guest lives on the quiet side of the fort.
- **Wisp**: `moth_shore_shepherd` (`moth_shepherd`, height 1.0) at the
  shore/lake boundary, `(-56, 0, -14)`, lantern-belly facing the water
  (`face_yaw=90`, i.e. +X).
- **Bramble** (dormant, per the brief): `data/dreamkeepers/bramble.json`
  authored (`moth_meadow_shepherd`, meadow-edge position `(-50,0,8)`,
  clear of the haunch mound's footprint) but **nothing spawns it** —
  `worlds/bramble/bramble.gd` is out of this pass's territory (owned by the
  set-piece agent) and doesn't read this file; the fort/wisp loaders are
  per-world direct calls, not a generic hook, so nothing else picks it up
  either. Wiring bramble's own `_build_dreamkeepers()` copy is a one-file,
  next-pass job.

**Dressing** — every world's props are a fresh `Node3D` anchor (position =
placement) holding a grey-box primitive `MeshInstance3D` + a `ModelSlot`
(`model_id`/`target_height` from `tools/meshy/manifest.json`
`target_height_hint`), matching the D10 pattern every existing prop in
these three files already follows. Per the brief, only `stump_door` +
`stone_soft` (+ `soft_pine`, unused this pass — only `soft_pine_small`
appears, which stays walk-through) get a simple static
`CylinderShape3D` collider; everything else is visual-only.

- **Fort**: `picnic_basket` near the mouth, `birdhouse_lantern` on the
  porch (mirrors the existing east `LanternVisual`, offset west of the
  BrambleDoor approach), `haystack_pillow` + 3 `clover_tuft` by the west
  fence, 2 `soft_pine_small` at the clearing's edges. No collision on any
  of these (none are in the three-item collision list) — see the route-
  clearance section below.
- **Wisp**: 2 `stone_soft` (collision) near the two reed patches, 1
  `stump_door` (collision) further up the shore, 2 reed-adjacent
  `clover_tuft`, 4 `moon_daisy`, 3 `seed_puff` scattered across the shore —
  every position checked >=2 m clear of every named dreamling/keeper/door
  position already in the file.
- **Marmalade**: 4 `mushroom_lamp` as lane streetlights (centered between
  consecutive `HOUSE_LAYOUT` x-columns, never on a house footprint), 2
  `berry_bush` pairs flanking the village's two ends, 1 `picnic_basket` in
  the square (off the spawn's direct forward line), 2 `moth_small` perched
  just above the roof collision box on two chimney-less/awning-less houses
  (`HOUSE_LAYOUT` indices 0 and 9, so they never collide with d02/d04's
  existing chimney/awning placements).

---

## (a) Import pass

```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path .
```
`update_scripts_classes` step registers `Dreamkeeper` cleanly alongside
`Marmalade`/`PillowFort`/`Wisp`. Zero script errors, zero import failures.

## (b) `check_placements` — 4/4 worlds green (bramble included, untouched)

```
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd --
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=wisp
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=marmalade
```

| world | objectives checked | verdicts | `any_fail` |
|---|---|---|---|
| pillow_fort | 0 (no dreamlings this world) | n/a — `PLACEMENT_NOTE pillow_fort has zero dreamlings (nothing to check)` | `false` |
| bramble | 10/10 | all `PASS` | `false` |
| wisp | 10/10 | all `PASS` | `false` |
| marmalade | 10/10 | all `PASS` | `false` |

Every run's `MODEL_SWAP` lines confirm every new prop actually swapped in
(GLBs already exist on disk under `assets/models/meshy/generated/`) with a
sane, non-zero scale factor (e.g. `{"id":"lamb_keeper","rigged":true,
"scaled":1.00000004207387}`, `{"id":"stone_soft","scaled":
0.429927887818597}`) — no `push_warning`s, no zero-height-AABB skips.
Bramble's own placement lines are byte-for-byte the same shape as prior
passes (10 dreamlings, all `PASS`) — untouched, as required.

The pre-existing `WARNING: ObjectDB instances leaked at exit` / `ERROR: N
resources still in use at exit` trailer on every run is this tool's own
documented, harmless characteristic (see `docs/verify/world-marmalade-
VERIFY.md` §caveats, `docs/verify/graphics-v2-VERIFY.md`, etc.) — not
introduced by this pass.

## (c) Boot all three worlds clean

```
D:\Tools\godot\godot_console.exe --headless --path . -- --skipmenu --quitafter=5
D:\Tools\godot\godot_console.exe --headless --path . -- --skipmenu --world=wisp --quitafter=5
D:\Tools\godot\godot_console.exe --headless --path . -- --skipmenu --world=marmalade --quitafter=5
```
All three boot to `WORLD_READY`/`HUD_READY`/`MOON_SAID {"key":"new_area"}`
with zero errors. Every dressing prop's `MODEL_SWAP` fires exactly once per
instance; no `DREAMKEEPER` receipt fires at boot in any world (both players
spawn well outside `WAKE_RADIUS` of either keeper — correct: nobody's close
enough yet). `AudioManager: stem layer not found (no-op)` lines for wisp/
marmalade are pre-existing (audio agent's territory, unrelated to this
pass).

## (d) Route-clearance proof — `finale_home.json`, `--pads=2`

```
D:\Tools\godot\godot_console.exe --headless --path . --log-file evidence\_scratch\dressing_m2\finale_home_console.log -- --skipmenu --pads=2 --script=tools/harness/scripts/finale_home.json --outdir=evidence/_scratch/dressing_m2/finale_home --quitafter=30
```

The script's own description states the expected receipts: *"CALLIE
carried seat 1, DOOR bramble, WORLD_READY bramble, collected d01, collected
d02."* Grepped from the run:

```
CALLIE {"seat":1,"state":"carried"}
DOOR {"to":"bramble"}
WORLD_READY {"id":"bramble","objectives":10}
EVT {"id":"d01","t":1177,"type":"dreamling_collected","world_id":"bramble"}
EVT {"id":"d02","t":1608,"type":"dreamling_collected","world_id":"bramble"}
```

Every expected receipt fired, in order, with no `SCRIPT ERROR` anywhere in
the log (only the same pre-existing benign resource-cleanup trailer at
process exit). Pip's route through the fort — wide around the east/blush
cushion, west along the flank to Callie's cushion, pickup, south to the
BrambleDoor — is **not blocked** by the new dressing or the lamb
Dreamkeeper (placed on the opposite, west side of the fort specifically to
stay clear of this corridor; no fort dressing prop carries collision
either, so nothing new can physically block a route regardless of
placement).

## (e) Stills — `evidence/stills/m2_dressing/<world>/`

Screenshots need a real window (`--shots` is skipped under `--headless`
with a `HARNESS_NOTE`, per `tools/harness/README.md`), so these runs drop
`--headless` and add `--fixed-fps 60 --resolution 1280x720`, matching the
project's movie-recipe convention. Each uses a throwaway capture script
(`evidence/_scratch/dressing_m2/shots_<world>.json`, a single `teleport`
event placing Pip within a Dreamkeeper's `WAKE_RADIUS` where one exists)
and `--shots=20,90,240` — pre-teleport establishing shot, just-woken/
turning, and mid-`wave` (`wave`'s own clip is 5.37 s long, so frame 240 is
solidly inside it).

**pillow_fort** (`--pads=1`):
```
DREAMKEEPER {"event":"wake","id":"lamb_fort_guest"}
DREAMKEEPER {"event":"wave","id":"lamb_fort_guest"}
HARNESS_NOTE screenshot saved .../evidence/stills/m2_dressing/pillow_fort/shot_20.png
HARNESS_NOTE screenshot saved .../evidence/stills/m2_dressing/pillow_fort/shot_90.png
HARNESS_NOTE screenshot saved .../evidence/stills/m2_dressing/pillow_fort/shot_240.png
```
`shot_20.png` — the dressed fort clearing at rest (picnic basket, west
haystack/clover cluster, edge pines). `shot_90.png` — the lamb just woken,
turning to face Pip. `shot_240.png` — mid-wave.

**wisp** (`--pads=1 --world=wisp`):
```
HARNESS_NOTE screenshot saved .../evidence/stills/m2_dressing/wisp/shot_20.png
HARNESS_TELEPORT {"pos":[-56.0,0.6,-12.0],"seat":1}
DREAMKEEPER {"event":"wake","id":"moth_shore_shepherd"}
WARP {"seat":2}
HARNESS_NOTE screenshot saved .../evidence/stills/m2_dressing/wisp/shot_90.png
DREAMKEEPER {"event":"wave","id":"moth_shore_shepherd"}
HARNESS_NOTE screenshot saved .../evidence/stills/m2_dressing/wisp/shot_240.png
```
`WARP {"seat":2}` is `core/coop/seat_manager.gd`'s pre-existing partner-
leash (Otto auto-warped back near Pip after the 20+ m teleport) — unrelated
to this pass, out of territory, expected behavior. `shot_20.png` — the
dressed shore at rest (stones, stump-door, daisies, seed puffs). `shot_90/
240.png` — the moth shepherd waking and mid-wave by the water.

**marmalade** (`--pads=1 --world=marmalade`):
```
HARNESS_NOTE screenshot saved .../evidence/stills/m2_dressing/marmalade/shot_20.png
HARNESS_TELEPORT {"pos":[-58.0,0.6,0.0],"seat":1}
HARNESS_NOTE screenshot saved .../evidence/stills/m2_dressing/marmalade/shot_150.png
```
No Dreamkeeper in this world this pass (per the brief — fort gets the lamb,
wisp gets the moth shepherd, bramble is dormant), so correctly zero
`DREAMKEEPER` receipts. `shot_20.png` — spawn-side village establishing
shot. `shot_150.png` — standing among the mushroom-lamp streetlights and
berry bushes down the lane.

---

## Visual spot-check

Read back 4 of the 8 captured PNGs directly (not just the receipt log):
`pillow_fort/shot_20.png` shows the picnic basket, both cushions, a
clover tuft, and the BrambleDoor frame all rendered around the two
spawned players; `pillow_fort/shot_240.png` and `wisp/shot_240.png` both
show a small, clearly-distinct rigged NPC (cream/wooly for the lamb, with
the moth's antennae visible in its own shot) standing near Pip with an
arm-raised, non-idle pose consistent with mid-`wave`; `marmalade/
shot_150.png` shows two mushroom-lamp streetlights, a berry bush, and
lit house windows down the lane, cat-mound silhouette in the background.
Nothing looked broken, embedded, or missing in any of the four.

## UNVERIFIED

- **Not every one of the 8 captured stills was individually eyeballed**
  (4 of 8 spot-checked above) — the remaining 4 (`pillow_fort/shot_90`,
  `wisp/shot_20`, `wisp/shot_90`, `marmalade/shot_20`) are present on disk
  with matching `HARNESS_NOTE screenshot saved` receipts but weren't
  individually read back by this agent.
- **Bramble's dreamkeeper is authored-only.** `data/dreamkeepers/
  bramble.json` exists and is schema-valid but nothing spawns it (by
  design, per the brief — `worlds/bramble/bramble.gd` is out of territory).
  Confirmed dormant: bramble's own `check_placements` run above is
  byte-for-byte the pre-existing 10/10 PASS shape, proving zero behavior
  change.
- **Wisp/marmalade dressing prop clearance was reasoned from each world's
  own named constants (dreamling positions, reed/lily/house coordinates),
  not exercised against a scripted harness route the way the fort's
  `finale_home.json` was** — `finale_wisp.json`/`finale_marmalade.json`
  exist but weren't run against this dressing pass (the brief's explicit
  route-clearance receipt only names `finale_home.json`). None of the new
  props in either world carry collision except wisp's 2 `stone_soft` + 1
  `stump_door`, and all three were placed away from `SPAWN_PIP`/
  `SPAWN_OTTO`/`HomeDoor`/the lily chain/the village lane by construction —
  not independently re-verified by a second harness run.
- **Dreamkeeper facing math (`face_yaw_degrees`) was reasoned from the
  codebase's documented yaw convention (0=-Z, atan2(x,z) for target-facing)
  but not screenshot-confirmed pixel-by-pixel** against "looks like it's
  settled facing into the fort/toward the water" — the wake/turn/wave
  receipts confirm the *mechanism* fires; the resting orientation's exact
  aesthetic is unconfirmed beyond the captured stills.
