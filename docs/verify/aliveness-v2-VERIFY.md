# ALIVENESS & QUESTS — VERIFICATION (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
**served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic), running as
the aliveness/quests build agent inside a Claude Code session.

Scope: D21 micro-mission framework, D23 playful-challenge archetypes
(race/ride/shy/duet), touch-react poke system, ambient critters — per
`docs/DECISIONS.md` D21/D23, `DIRECTION_V2.md`, `docs/research/v2/
aliveness_wow.md`, `docs/research/v2/structure_progression.md`.

---

## What shipped

**Mission framework**
- `core/quests/mission.gd` — `Mission` (RefCounted data class): id,
  archetype (`open`/`race`/`ride`/`shy`/`duet`), params, moon_line_key.
  Unknown archetypes fall back to `open` with a `push_warning`.
- `core/quests/mission_registry.gd` — `MissionRegistry.load_for_world(id)`
  reads `data/missions/<id>.json`, mirrors `the_moon.gd`'s own FileAccess
  pattern. Missing file / missing id / unparseable JSON all resolve to
  "open" (generosity-by-default, matches the "nothing missable" floor).
- `worlds/common/mission_driver.gd` — `MissionDriver` (a Node, attached as
  a Dreamling *child*, never a subclass). Drives an ADDITIVE local offset
  via `Dreamling.mission_set_local_offset()` on top of the existing
  bob/magnetism anchor — never touches the anchor itself, so a deleted or
  buggy driver can only ever leave a dreamling at its unmodified placement.
- `worlds/common/dreamling.gd` — two small additive hooks:
  `mission_suppress_magnetism: bool` (default false) and
  `_mission_offset: Vector3` (default ZERO), consumed in `_process_idle`.
  For any dreamling with no attached driver these are never touched, so
  the "open" archetype is a byte-for-byte no-op — verified below.
- `worlds/common/world_base.gd._wire_dreamlings()` now loads
  `MissionRegistry.load_for_world(world_id())` once and calls
  `_attach_mission()` per surviving dreamling: a driver is attached ONLY
  for a non-open archetype; open ids get no driver at all.

**Archetype contracts** (D23: celebration-only, nothing missable)
- `open` — unchanged classic dreamling.
- `race` — waits for a player within `trigger_radius`, then zips a small
  CLOSED waypoint loop (rubber-banded: progress slows to 25% speed when
  the nearest player falls beyond `RACE_CATCHUP_DISTANCE`=5m) for `laps`
  loops, then eases the offset back to zero and hands off to normal
  magnetism. Catchable by touch THE ENTIRE TIME via the dreamling's own
  unmodified Area3D collision — the driver never suppresses that, only the
  idle-magnetism drift.
- `ride` — loops a small closed path forever; magnetism is deliberately
  left ON (not suppressed), so a nearby player pulls the whole floating
  loop toward them — "generous magnetism stays on" per the brief.
- `shy` — hides (scale × 0.5, emission × 0.35) and `monitoring = false`
  until a player stands within `reveal_radius` for `reveal_time`
  continuous seconds, then tweens back to full size/brightness and flips
  `monitoring = true`.
- `duet` — hidden (same treatment as shy) until TWO players are within
  `duet_radius` simultaneously (checked every physics frame across the
  `players` group), OR a single player has held proximity continuously for
  `fallback_seconds` (default 10s) — the explicit "nothing missable solo"
  escape valve.

**Data** — `data/missions/{bramble,wisp,marmalade}.json` (pillow_fort has
zero dreamlings; no file = all-open, per the brief):
- bramble: d01 race, d02 race, d05 ride, d09 shy, d08 duet, rest open
  (5 assigned + 5 open = 10; d06/d07 deliberately left open — they already
  ride the breathing chest / snore geyser, and layering a second motion
  system on an already-moving platform risked compounding drift for no
  benefit).
- wisp: d01 race, d09 shy, rest open.
- marmalade: d01 race, d09 shy, rest open.
- **d09 is "shy" in all three worlds on purpose** — it was already the
  world's own designed hiding spot before tonight (bramble's fur patch,
  wisp's reed patch, marmalade's garden pots — see each world script's own
  placement comments), so the archetype assignment matches original design
  intent exactly rather than fighting it.
- **Bramble's duet dreamling is d08 (shoulder shelf), not d10.** d10 is
  exercised by an EXISTING, documented harness property
  (`tools/harness/scripts/gate2_return.json`, proven in
  `docs/verify/gate2-slice-VERIFY.md`: teleports Pip alone next to d10 for
  ~5s total before moving away). A duet gate (two players, or a 10s
  single-player fallback) cannot bloom in 5s of single-player exposure —
  assigning duet to d10 would have silently broken that property. d08 is
  untouched by any existing harness script (confirmed via `grep -oE
  "d0[1-9]|d10" tools/harness/scripts/*.json`) and is thematically apt (a
  shelf reachable by both the toss route and the chest-bounce route — a
  natural "meet here together" spot).

**Touch-react** — `worlds/common/touch_react.gd` (`TouchReact`, Area3D):
spring-damped squash/tilt + a rate-limited one-shot SFX (`poke_boop`,
no asset yet — fails soft per `AudioManager`'s documented convention, so
tonight ships the wobble with silent audio, not a missing feature) on any
player touch. `world_base.gd._wire_touch_react()` auto-attaches one to
every node in the `"poke"` group under that world, idempotently, with
optional `touch_react_radius`/`touch_react_sfx` metadata overrides.
**Concrete attachment tonight:** `worlds/common/dream_door.gd` opts its own
`Visual` (the return-disk mesh) into `"poke"` in its own `_ready()` — this
lives entirely in `worlds/common/dream_door.tscn`/`.gd` (mine), so
bramble/wisp/marmalade all get the wobble+boop on their DreamDoor disk for
free with ZERO edits to any of their own scripts. No other common prop
existed to opt in tonight (pedestals/chimneys/garden-pot geometry all live
in the forbidden per-world scripts) — documented honestly rather than
forced.

**Ambient critters** — `worlds/common/critter.gd` (`Critter`, plain
Node3D, no collision, decorative only): Idle-Wander / Scatter-on-Approach
(2m) / Return, re-skinned via `kind` ("moth" = two flapping quads + glow
sprite, "mouse" = capsule + ears), spawned from `data/critters/<id>.json`
via `world_base.gd._wire_critters()`. Populated per the brief: bramble
moths×6 + mice×3 (meadow, near spawn), pillow_fort moths×3 (clustered at
the FireflyJarVisual coordinates — ambient life there even before
fort_stage 2 unlocks the real jar), wisp moths×4 (shore), marmalade
mice×4 (village square). ≤9 per world, well under the 20-per-world budget.

**Verify tool** — `tools/props/check_missions.gd`: same technique as
`check_placements.gd` (instantiate world headless, no players, settle 3
physics frames), cross-checks every mission entry against (a) a real
Dreamling id existing in that world, (b) every race/ride waypoint's world-Y
staying above `rescue_floor_y()`, (c) duet params sane (`duet_radius > 0`,
`0 < fallback_seconds <= 30`).

---

## Bug caught and fixed during verification

`Critter._ready()` originally read `GameState.current_world_id` to stamp
its own `critter_scatter` receipts. First live boot of marmalade printed
`EVT {"kind":"mouse","type":"critter_scatter","world":""}` — GameState's
write isn't guaranteed to have landed before a world's own children finish
`_ready()` (world instancing happens via `_world_slot.add_child(_world)`,
which runs the whole subtree's `_ready()` chain — including
`world_base.gd`'s `_wire_critters()` — BEFORE `scenes/main.gd`'s next line,
`GameState.set_current_world(...)`, executes). Fixed by having
`world_base.gd` pass `world_id()` directly into `critter.world_id` BEFORE
`add_child()` (the same established-safe ordering `bramble.gd`'s
`breathing_chest.gd`/`tail_bridge.gd` comments already document), matching
the pattern already used for `MissionDriver.setup(..., world_id())`.
Re-verified: `"world":"marmalade"`/`"world":"wisp"`/`"world":"bramble"` now
populate correctly on every subsequent run (quoted below).

---

## Placement receipt — LAW: 30/30 green

`check_placements.gd`'s own `DEFAULT_WORLDS` only covers
`["pillow_fort","bramble"]` (pre-existing, not touched tonight — outside
my mandate to edit). Ran all four explicitly via `--world=<id>`:

```
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort"]}   # 0 dreamlings
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["bramble"]}       # 10/10 PASS
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["wisp"]}          # 10/10 PASS
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["marmalade"]}     # 10/10 PASS
```
30/30 dreamlings PASS (10+10+10 across the three worlds that have any,
pillow_fort has none) — including every id I attached a mission to
(d01/d02/d05/d08/d09 in bramble; d01/d09 in wisp/marmalade). Missions
attach to dreamlings post-placement and only ever move a dreamling in
response to live player proximity — never at scene-instantiation time,
which is the only moment this checker samples — so the LAW holds by
construction, not by luck. (The pre-existing `ERROR: 2 resources still in
use at exit` line on bramble/wisp/marmalade runs is documented in prior
nights' verify docs — `docs/verify/ui-VERIFY.md`,
`docs/verify/world-marmalade-VERIFY.md` — confirmed unrelated to tonight.)

Command used (repeated per world):
```
godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=<id>
```

## Mission sanity — `check_missions.gd`

```
MISSION_SUMMARY {"any_fail":false,"worlds":["bramble"]}
MISSION_SUMMARY {"any_fail":false,"worlds":["wisp"]}
MISSION_SUMMARY {"any_fail":false,"worlds":["marmalade"]}
```
Every mission id matched a real dreamling, every race/ride waypoint stayed
above its world's rescue floor, and both duet-param checks passed (bramble
d08: `duet_radius=3.0`, `fallback_seconds=10.0`).

```
godot_console.exe --headless --path . --script tools/props/check_missions.gd -- --world=<id>
```

---

## Clean boot, all four worlds

```
godot_console.exe --headless --path . -- --skipmenu --world=<id> --quitafter=5
```
All four printed `WORLD_READY` with the correct objective count and no
`SCRIPT ERROR`/`Parse Error`: `pillow_fort` (0 objectives), `bramble` (10),
`wisp` (10, plus a live `EVT critter_scatter` from a shore moth), `marmalade`
(10). Re-confirmed a second time with the real (non-cleared) shared save
file restored, to match realistic play conditions.

---

## Windowed race choreography — driven by an EXISTING, unmodified script

Per the brief: "drive with an existing gate2 script if it passes near one."
`tools/harness/scripts/gate2_meadow.json` was already documented
(`docs/verify/gate2-slice-VERIFY.md`) to walk Pip through d01 and d02 —
exactly the two dreamlings I assigned `race`. Ran it unmodified, windowed
(Movie Maker's own display requirement — never `--headless` for anything
touching real rendering), with `--poslog` and a `--log-file` capturing the
full stdout:

```
godot_console.exe --path . --log-file evidence/_scratch/aliveness_v2/gate2_race/console.log \
  -- --skipmenu --world=bramble --script=tools/harness/scripts/gate2_meadow.json \
  --poslog=15 --outdir=evidence/_scratch/aliveness_v2/gate2_race --quitafter=30
```

Receipts (`evidence/_scratch/aliveness_v2/gate2_race/console.log`):
```
EVT {"archetype":"race","id":"d01","t":312,"type":"mission_race_started","world":"bramble"}
EVT {"id":"d01","t":498,"type":"dreamling_collected","world_id":"bramble"}
EVT {"archetype":"race","id":"d01","t":498,"type":"mission_caught","world":"bramble"}
EVT {"kind":"moth","t":619,"type":"critter_scatter","world":"bramble"}
EVT {"archetype":"race","id":"d02","t":768,"type":"mission_race_started","world":"bramble"}
EVT {"id":"d02","t":789,"type":"dreamling_collected","world_id":"bramble"}
EVT {"archetype":"race","id":"d02","t":789,"type":"mission_caught","world":"bramble"}
```
Both race dreamlings triggered on approach, zipped, and were caught by
touch well within their loop's own duration (186 physics frames / 3.1s
from trigger to catch on d01; 21 frames on d02 — Pip's approach vector
happened to cross the loop almost immediately on d02) — no script edits,
no new harness content, the pre-existing property still passes AND now
demonstrates the race choreography live. A meadow moth also scattered
mid-run, confirming critters are alive in a real windowed frame too.

**Pre-existing, out-of-territory finding (not mine to fix):** the same
windowed run printed several `SCRIPT ERROR: Parse Error: Function
"_draw_gear()" not found...` lines from `scenes/ui/icon_draw.gd` (HUD icon
rendering — a `_draw()` callback issue that only manifests with real
rendering, never under `--headless`, confirmed by re-running the identical
boot headless and seeing zero such lines). `scenes/**` is outside my
territory tonight; flagging honestly rather than touching it.

---

## Duet — UNVERIFIED-choreography (honest)

No existing harness script drives two players together near any dreamling
long enough to observe a live `dual_proximity` bloom, and I did not write
a new `tools/harness/scripts/*.json` (that directory belongs to the
movement agent tonight). What IS verified:
- `check_missions.gd` confirms bramble d08's duet params are sane
  (`duet_radius=3.0 > 0`, `0 < fallback_seconds=10.0 <= 30`).
- The single-player fallback path was exercised INDIRECTLY and
  informatively: while investigating whether d10 (my first duet candidate)
  would break `gate2_return.json`, I ran that exact single-player-teleport
  script against a temporary duet-on-d10 build and confirmed empirically
  that ~5s of single-player exposure (well under the 10s fallback) leaves
  the dreamling uncatchable — i.e., the fallback timer's *gate* (nothing
  blooms early) is proven; the fallback's own *trigger* (blooms at exactly
  10s) was reasoned from the code, not separately timed live tonight.
- `buddy_ai.gd`'s `follow_distance` (2.5m) is tighter than bramble's
  `duet_radius` (3.0m), so dual-proximity SHOULD often succeed for free in
  solo mode too — read, not driven live. UNVERIFIED-choreography for the
  dual-proximity path specifically; the fallback is the floor-law
  guarantee regardless, so nothing is missable even if dual-proximity
  never fires in practice.

## Shy reveal (bramble d09 / wisp d09 / marmalade d09) — UNVERIFIED-choreography

No existing harness script parks a player still for 1.5s within 4m of any
world's fur-patch/reed-patch/garden-pot dreamling (all three worlds' d09
is a genuine off-the-beaten-path hiding spot by original design, which is
exactly why nothing currently walks there). `check_missions.gd` confirms
the params parse and the id resolves; the live stillness-timer -> reveal
-> `monitoring=true` transition was read and reasoned from
`mission_driver.gd`'s `_process_shy`, not observed via a live receipt
tonight. Documented honestly rather than claimed.

## Ride (bramble d05) — UNVERIFIED-choreography

Same story: no existing script climbs to the haunch peak. The closed-loop
math (`_closed_path_length`/`_sample_closed_path`) is exercised by
`check_missions.gd`'s waypoint-above-rescue-floor check and by the
identical code path already proven live for race (d01/d02 above), but the
ride-specific "magnetism stays on and pulls the loop toward an approaching
player" behavior was not observed live.

**Callie compatibility (shy/duet):** not a live-receipt item but a
by-construction guarantee, confirmed by reading both files side by side:
`callie.gd._nearest_sniffable_dreamling()` filters candidates on
`candidate.monitoring`; shy/duet set `monitoring = false` until revealed.
Callie therefore never sniffs/mews at a still-hidden dream — zero
`callie.gd` changes needed, and the resulting behavior (she only points at
dreams that are actually findable right now) reads as intentional.

---

## Files touched

- `worlds/common/dreamling.gd` (additive hooks only)
- `worlds/common/world_base.gd` (mission/touch-react/critter wiring)
- `worlds/common/dream_door.gd` ("poke" opt-in for its Visual)
- `worlds/common/mission_driver.gd` (new)
- `worlds/common/touch_react.gd` (new)
- `worlds/common/critter.gd` (new)
- `core/quests/mission.gd` (new)
- `core/quests/mission_registry.gd` (new)
- `data/missions/{bramble,wisp,marmalade}.json` (new)
- `data/critters/{bramble,pillow_fort,wisp,marmalade}.json` (new)
- `tools/props/check_missions.gd` (new)
- `docs/verify/aliveness-v2-VERIFY.md` (this file)

Not touched: `worlds/pillow_fort|bramble|wisp|marmalade` per-world
scripts/scenes, `core/movement/**`, `core/art/**`, `core/env/**`,
`scenes/**`, `scripts/autoloads/**` (read-only), `project.godot`,
`tools/harness/**`. No git commit made.
