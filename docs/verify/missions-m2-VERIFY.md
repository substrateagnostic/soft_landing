# MISSIONS M2 — bramble authored, Moon wired, live choreography — VERIFICATION (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows,
headless for every run below (no rendering needed — receipts only).
**served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic), running as
the mission-author agent inside a Claude Code session.

Scope: finish authoring bramble's 10 dreamlings (D21/D23 archetypes), write
Moon lines for every named mission across all four worlds, wire mission
bloom/start moments to `TheMoon.say()`, and live-verify the three
archetypes the previous shift left as honest UNVERIFIED-choreography
(ride/shy/duet) — per `AGENTS.md`, `DIRECTION_V2.md`,
`docs/research/v2/structure_progression.md` TOP 12 #1,
`docs/design/NARRATION_BIBLE.md`, and `docs/verify/aliveness-v2-VERIFY.md`
(the prior shift's own honest gaps, quoted below where relevant).

---

## 1. Bramble archetype mix — 10/10 authored

`data/missions/bramble.json` now has all ten `d01`–`d10` entries (archetype
+ one-line `story` + `moon_line_key`, all authored this pass). Placements
read live from `worlds/bramble/bramble.gd` (`_build_dreamlings()`), not
guessed — every race/ride waypoint set is a small closed loop with
non-negative local Y offsets only (never dips below its own placement, so
`waypoints_ok` is trivially satisfied against `rescue_floor_y()=-8.0`, and
nothing clips into nearby ramp/mound geometry since the loop only ever
moves up/sideways from a placement that's already validated by
`check_placements.gd`).

| id | archetype | why | moon_line_key |
|---|---|---|---|
| d01 | race | meadow approach near spawn (unchanged from prior shift) | `bramble_d01_race` |
| d02 | race | meadow approach, south side (unchanged) | `bramble_d02_race` |
| d03 | **ride (new)** | +Z paw ramp — small loop, Y offset always ≥0 relative to its ramp placement | `bramble_d03_ride` |
| d04 | **open (new)** | −Z paw ramp, left plain deliberately (mirror of d03, keeps the paw-ramp pair asymmetric on purpose so one side is calm) | `bramble_d04_open` (data only, not wired — see §UNVERIFIED) |
| d05 | ride | haunch peak (unchanged) | `bramble_d05_ride` |
| d06 | **open (kept)** | rides the breathing chest already — a second motion system stacked on an already-moving platform was the prior shift's own reasoning for leaving it open, still holds | `bramble_d06_open` (data only, not wired) |
| d07 | **open + geyser-timing flourish (new)** | rides the snore geyser already; mechanically `open` (the geyser IS the timing challenge, no driver needed) but gets a **special one-off spoken flourish on catch** via a new `params.speak_on_collect: true` seam — the brief's explicit ask | `bramble_d07_geyser` (wired, see §3) |
| d08 | duet | shoulder shelf (unchanged) | `bramble_d08_duet` |
| d09 | shy | fur patch on the haunch (unchanged) | `bramble_d09_shy` |
| d10 | **open (kept)** | ear/DreamDoor spot — deliberately left untouched: `gate2_return.json` (existing, unmodified) teleports Pip alone next to it for ~5s, proven in `docs/verify/gate2-slice-VERIFY.md`; any gated archetype here risks breaking that property (same reasoning the prior shift used to keep it off duet) | `bramble_d10_open` (data only, not wired) |

**Target mix hit exactly**: 2 race, 2 ride, 1 shy, 1 duet, 1 geyser-timing,
3 plain open = 10. Confirmed by `check_missions.gd`'s new
`MISSION_ARCHETYPE_COUNTS` receipt (§4):
```
MISSION_ARCHETYPE_COUNTS {"counts":{"duet":1,"open":4,"race":2,"ride":2,"shy":1},"total":10,"world":"bramble"}
```
(`"open":4` = the 3 plain-open + d07's geyser-timing open.)

---

## 2. Moon lines — every named mission, all four worlds

Added to `data/moon_lines.json` (bible voice, ≤12 words each, one line per
key — no multi-variant array, since each is a genuinely one-off flourish
rather than a high-frequency line that needs variety):

- `bramble_d01_race`, `bramble_d02_race`, `bramble_d03_ride`,
  `bramble_d04_open`, `bramble_d05_ride`, `bramble_d06_open`,
  `bramble_d07_geyser`, `bramble_d08_duet`, `bramble_d09_shy`,
  `bramble_d10_open` (bramble's 10)
- `wisp_d01_race`, `wisp_d09_shy` (wisp's two already-tagged missions —
  the JSON entries already referenced these keys before this pass; the
  text simply didn't exist yet in `moon_lines.json`, so `TheMoon.say()`
  was silently falling back to printing the raw key)
- `marmalade_d01_race`, `marmalade_d09_shy` (same situation)

No retagging done in wisp/marmalade — their existing race/shy assignments
(d01/d09) were kept as-is; only the missing line text was authored.

Also tagged the new per-dreamling race/shy/duet keys into
`scripts/autoloads/the_moon.gd`'s `GENTLE_KEYS`/`EXCITED_KEYS` mood-pitch
arrays (shy + the geyser "careful" line run gentle; race + duet run
excited), matching the existing generic `mission_race`/`mission_shy`/
`mission_duet` template keys' own mood classification. Ride keys were left
neutral (pitch 1.0), matching the precedent that the generic `mission_ride`
template key was ALSO left out of both arrays by the writing pass that
authored `NARRATION_BIBLE.md`.

**Word budget**: counted programmatically (PowerShell `ConvertFrom-Json`,
sum of `.Split()` word counts across every key, every variant) —
**541 words total**, up from the bible's documented ~410 baseline (+131
words for the 14 new lines), still well under the 900-word ceiling.

```
Total words: 541
```

**Not updated (out of territory):** `docs/design/NARRATION_BIBLE.md` still
says "~410 words" — that file isn't in this pass's edit territory
(`docs/design/**` wasn't listed), so its own word-count line is now stale.
Flagging honestly for whoever owns that file next rather than touching it.

---

## 3. Wiring — mission bloom/start → `TheMoon.say()`

The seam existed (`Mission.moon_line_key`) but was unconnected — confirmed
by reading `mission.gd`'s own prior comment ("this file and
mission_driver.gd deliberately never call TheMoon themselves") and by the
fact that every `moon_line_key` value already present in `data/missions/
*.json` referenced keys that didn't exist yet in `moon_lines.json` (§2).

**`worlds/common/mission_driver.gd`** — added a shared `_speak_bloom_line()`
helper (guards on a non-empty key, then `TheMoon.say(_mission.moon_line_key)`),
called from each archetype's own bloom/start moment, exactly once
(state-guarded, matching "once per mission per session, never repeating
chatter"):
- **race** — at the WAITING→RUNNING transition (existing `EVT
  mission_race_started` trigger; unchanged motion contract).
- **ride** — **new**: ride never had a "start" moment (its loop has been
  drifting since `_ready()`, magnetism always on, by design). Added a
  purely-observational `RIDE_DEFAULT_TRIGGER_RADIUS` (3.0m, mirrors race's
  default) proximity check inside the existing `_process_ride()` loop —
  it only ever ADDS a one-shot `EVT mission_bloomed` + Moon line the first
  time a player gets close; it never gates or touches the offset/motion
  itself, so the archetype's own "always catchable, never suppressed"
  contract is untouched.
- **shy** — at `_reveal_shy()` (existing bloom moment).
- **duet** — at `_bloom_duet()` (existing bloom moment, both triggers:
  `dual_proximity` and `fallback_timer`).

**`worlds/common/world_base.gd`** — added `_wire_open_moon_line()`, called
from `_attach_mission()` for `open`-archetype ids only. Deliberately
**opt-in** via `params.speak_on_collect == true` (not "any open id with a
moon_line_key speaks") — bramble's d04/d06/d10 all carry a `moon_line_key`
for data completeness (§1) but stay silent, because auto-speaking on every
plain pickup would be exactly the "nice job on every catch" over-narration
failure `NARRATION_BIBLE.md` names by example (the Hakim problem). Only
d07 opts in, per the brief's explicit "geyser-timing" ask. `open` ids still
get **no MissionDriver at all** — D21's zero-behavior-change floor for the
classic dreamling is unchanged; this is a signal connection on the
`Dreamling.collected` signal, nothing more.

Both `mission.gd`'s doc comment and `mission_driver.gd`'s header comment
were updated to describe the new contract (they previously said "never
call TheMoon" — now false, so the comments would have been actively
misleading if left alone).

---

## 4. Mission sanity — `check_missions.gd` (updated schema + run on all four worlds)

Added two things (see the file's own updated header comment for the
rationale): a `moon_line_key_ok` check (every non-open archetype must have
a non-empty `moon_line_key`, now that `mission_driver.gd` actually speaks
it — a blank key would be a silent, permanent gap since `TheMoon.say()`
fails soft on it) and a `MISSION_ARCHETYPE_COUNTS` summary line per world
(informational, never fails the run).

```
=== pillow_fort ===
MISSION_NOTE pillow_fort has no mission data (all-open, nothing to check)
MISSION_SUMMARY {"any_fail":false,"worlds":["pillow_fort"]}

=== bramble ===
MISSION_CHECK {"archetype":"race","duet_ok":true,"id":"d01","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"bramble"}
MISSION_CHECK {"archetype":"race","duet_ok":true,"id":"d02","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"bramble"}
MISSION_CHECK {"archetype":"ride","duet_ok":true,"id":"d03","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"bramble"}
MISSION_CHECK {"archetype":"open","duet_ok":true,"id":"d04","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"bramble"}
MISSION_CHECK {"archetype":"ride","duet_ok":true,"id":"d05","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"bramble"}
MISSION_CHECK {"archetype":"open","duet_ok":true,"id":"d06","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"bramble"}
MISSION_CHECK {"archetype":"open","duet_ok":true,"id":"d07","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"bramble"}
MISSION_CHECK {"archetype":"duet","duet_ok":true,"id":"d08","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"bramble"}
MISSION_CHECK {"archetype":"shy","duet_ok":true,"id":"d09","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"bramble"}
MISSION_CHECK {"archetype":"open","duet_ok":true,"id":"d10","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"bramble"}
MISSION_ARCHETYPE_COUNTS {"counts":{"duet":1,"open":4,"race":2,"ride":2,"shy":1},"total":10,"world":"bramble"}
MISSION_SUMMARY {"any_fail":false,"worlds":["bramble"]}

=== wisp ===
MISSION_CHECK {"archetype":"race","duet_ok":true,"id":"d01","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"wisp"}
MISSION_CHECK {"archetype":"shy","duet_ok":true,"id":"d09","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"wisp"}
MISSION_ARCHETYPE_COUNTS {"counts":{"race":1,"shy":1},"total":2,"world":"wisp"}
MISSION_SUMMARY {"any_fail":false,"worlds":["wisp"]}

=== marmalade ===
MISSION_CHECK {"archetype":"race","duet_ok":true,"id":"d01","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"marmalade"}
MISSION_CHECK {"archetype":"shy","duet_ok":true,"id":"d09","id_found":true,"moon_line_key_ok":true,"reasons":[],"verdict":"PASS","waypoints_ok":true,"world":"marmalade"}
MISSION_ARCHETYPE_COUNTS {"counts":{"race":1,"shy":1},"total":2,"world":"marmalade"}
MISSION_SUMMARY {"any_fail":false,"worlds":["marmalade"]}
```
Command (repeated per world):
```
godot_console.exe --headless --path . --script tools/props/check_missions.gd -- --world=<id>
```
All PASS, every non-open mission now has a real `moon_line_key_ok`.

---

## 5. Placement receipt — LAW: 30/30 green (re-run after this pass's data changes)

```
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort"]}   # 0 dreamlings
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["bramble"]}       # 10/10 PASS
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["wisp"]}          # 10/10 PASS
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["marmalade"]}     # 10/10 PASS
```
30/30 dreamlings PASS. Command (repeated per world):
```
godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=<id>
```
Unaffected by this pass by construction: mission archetype assignment
happens post-placement (`world_base.gd._wire_dreamlings()` attaches a
driver AFTER the dreamling already exists at its scene-authored position);
`check_placements.gd` only ever samples the placement itself, never
anything a driver could move. (The pre-existing `ERROR: 2 resources still
in use at exit` on bramble/wisp/marmalade runs is the same documented,
unrelated finding from the prior shift's own VERIFY doc.)

---

## 6. Live choreography — ride / shy / duet (the honest gap from the last shift, now closed)

All four runs headless (`--headless --path . -- --skipmenu --world=bramble
--script=... --outdir=... --quitafter=N`), full stdout captured to
`evidence/_scratch/missions_m2/*_console.log` (also mirrored into each
run's own `events.jsonl` under `--outdir`, minus the plain-`print()`
`MOON_SAID` lines per the harness's own documented limitation — see
`tools/harness/README.md` §"What's NOT in events.jsonl").

### 6a. Ride — `tools/harness/scripts/mission_ride.json` (bramble d05, haunch peak)

Proves ride is catchable **mid-path**: ride has no settle/pause state
(unlike race), so any successful catch is by construction mid-loop. DEV
TELEPORT drops Pip within the new `RIDE_DEFAULT_TRIGGER_RADIUS` while the
loop is already mid-drift (it's been looping since `_ready()`).

```
HARNESS_TELEPORT {"pos":[-30.0,10.6,0.5],"seat":1}
EVT {"archetype":"ride","id":"d05","t":30,"trigger":"proximity","type":"mission_bloomed","world":"bramble"}
MOON_SAID {"key":"bramble_d05_ride","text":"Climb on, little duck — this dream loves to drift.","voice_mode":"moonsong+tts"}
EVT {"id":"d05","t":32,"type":"dreamling_collected","world_id":"bramble"}
EVT {"archetype":"ride","id":"d05","t":32,"type":"mission_caught","world":"bramble"}
```
Bloomed 2 frames after teleport, caught 2 frames after bloom — the ride
loop never paused, so this is a live mid-motion catch. **PASS.**

Command:
```
godot_console.exe --headless --path . -- --skipmenu --world=bramble --script=tools/harness/scripts/mission_ride.json --outdir=evidence/_scratch/missions_m2/ride --quitafter=10
```

### 6b. Shy — `tools/harness/scripts/mission_shy.json` (bramble d09, fur patch)

DEV TELEPORT parks Pip inside `SHY_DEFAULT_REVEAL_RADIUS` (4.0m) once, no
further movement — `_process_shy` accumulates continuously while a player
stays within radius (no separate velocity check), so a single un-repeated
teleport IS the "stillness."

```
HARNESS_TELEPORT {"pos":[-27.0,9.0,7.0],"seat":1}
EVT {"archetype":"shy","id":"d09","t":120,"trigger":"stillness","type":"mission_bloomed","world":"bramble"}
MOON_SAID {"key":"bramble_d09_shy","text":"Shh — go slow. This one startles easily.","voice_mode":"moonsong+tts"}
EVT {"id":"d09","t":121,"type":"dreamling_collected","world_id":"bramble"}
EVT {"archetype":"shy","id":"d09","t":121,"type":"mission_caught","world":"bramble"}
```
Teleport landed ~frame 28 (absolute); bloom at t=120 is ~90 physics frames
later — **exactly `SHY_DEFAULT_REVEAL_TIME` (1.5s)**. Caught 1 frame after
reveal (magnetism had been pulling the hidden dreamling toward Pip the
whole time — only `monitoring`/the Area3D catch was gated, not the pull).
**PASS.**

An incidental bonus in the same run: buddy AI (default SOLO mode, no
`--pads` passed) wandered near d01 en route and triggered its race bloom
too — a live re-confirmation that the race archetype's *new* Moon-wiring
(added this pass) didn't regress the pre-existing, previously-verified
race behavior:
```
EVT {"archetype":"race","id":"d01","t":59,"type":"mission_race_started","world":"bramble"}
MOON_SAID {"key":"bramble_d01_race","text":"Ready, little duck? This one loves a good chase.","voice_mode":"moonsong+tts"}
```

Command:
```
godot_console.exe --headless --path . -- --skipmenu --world=bramble --script=tools/harness/scripts/mission_shy.json --outdir=evidence/_scratch/missions_m2/shy --quitafter=8
```

### 6c. Duet, dual-proximity — `tools/harness/scripts/mission_duet.json` (bramble d08, shelf), `--pads=2`

True co-op (no buddy AI) — both seats teleported to d08 simultaneously.

```
HARNESS_NOTE pads override applied via InputRouter.force_mode(2)
HARNESS_TELEPORT {"pos":[24.0,11.2,6.3],"seat":1}
HARNESS_TELEPORT {"pos":[24.0,11.2,5.7],"seat":2}
EVT {"archetype":"duet","id":"d08","t":20,"trigger":"dual_proximity","type":"mission_bloomed","world":"bramble"}
MOON_SAID {"key":"bramble_d08_duet","text":"This dream needs two, little duck. Bring your friend.","voice_mode":"moonsong+tts"}
EVT {"id":"d08","t":22,"type":"dreamling_collected","world_id":"bramble"}
EVT {"archetype":"duet","id":"d08","t":22,"type":"mission_caught","world":"bramble"}
```
Bloomed the SAME frame both teleports landed (no accumulation needed for
dual-proximity, per `_process_duet`'s own `within >= 2` check). **PASS.**

Command:
```
godot_console.exe --headless --path . -- --skipmenu --world=bramble --pads=2 --script=tools/harness/scripts/mission_duet.json --outdir=evidence/_scratch/missions_m2/duet --quitafter=6
```

### 6d. Duet, solo fallback timer — `tools/harness/scripts/mission_duet_solo.json` (bramble d08), `--pads=1`

The harder half: proving the timer itself fires at 10.0s, isolated from
the *also-true* fact (documented, not proven, by the prior shift) that
buddy AI's tight `follow_distance` (2.5m, tighter than `duet_radius`=3.0m)
would likely satisfy dual-proximity for free within a couple seconds in
real solo play. Isolation technique: Otto is repeatedly re-teleported
(every 30 frames, the whole run) to a fixed holding anchor — `(28.3, 0.5,
12.5)`, flat meadow ground clear of the shoulder mound's own 14m footprint,
~13m true-3D from d08, and within buddy AI's own horizontal-only
`lag_warp_distance` (12m) of Pip so the dramatic bubble-warp never fires —
while Pip teleports to d08 once (frame 30) and never moves again. This is
the documented `teleport` dev-instrument used at higher frequency, not a
new mechanic; it isolates the property under test rather than claiming
dual-proximity never happens in real solo play (it likely still does,
often — see §7).

```
HARNESS_NOTE pads override applied via InputRouter.force_mode(1)
HARNESS_TELEPORT {"pos":[24.0,11.2,6.0],"seat":1}
HARNESS_TELEPORT {"pos":[28.3,0.5,12.5],"seat":2}   # repeats every 30 frames throughout — 30 total
...
EVT {"archetype":"duet","id":"d08","t":629,"trigger":"fallback_timer","type":"mission_bloomed","world":"bramble"}
MOON_SAID {"key":"bramble_d08_duet","text":"This dream needs two, little duck. Bring your friend.","voice_mode":"moonsong+tts"}
EVT {"id":"d08","t":630,"type":"dreamling_collected","world_id":"bramble"}
EVT {"archetype":"duet","id":"d08","t":630,"type":"mission_caught","world":"bramble"}
```
Pip's teleport landed at t≈29 (absolute physics frame); bloom fired at
t=629 — **exactly 600 physics frames (10.0000s at 60 ticks/s) later**,
matching `DUET_DEFAULT_FALLBACK_SECONDS` precisely. Critically, **no**
`mission_bloomed` fired at any point before t=629 despite Otto being alive
in the world the whole run (confirmed via the full log — only ambient
`dreamling_giggle` idle-fidget events from unrelated dreamlings appear in
that window), proving Otto's pinning never leaked into `duet_radius`.
Caught 1 frame after bloom. **PASS.**

Command:
```
godot_console.exe --headless --path . -- --skipmenu --world=bramble --pads=1 --script=tools/harness/scripts/mission_duet_solo.json --outdir=evidence/_scratch/missions_m2/duet_solo --quitafter=16
```

### 6e. Bonus (not required by the brief, but new code, so verified anyway) — `mission_geyser_flourish.json`: d07's open+speak_on_collect flourish

```
HARNESS_TELEPORT {"pos":[54.0,18.2,4.0],"seat":1}
EVT {"id":"d07","t":32,"type":"dreamling_collected","world_id":"bramble"}
MOON_SAID {"key":"bramble_d07_geyser","text":"Careful — this dream rides the bear's own snore.","voice_mode":"moonsong+tts"}
```
`world_base.gd._wire_open_moon_line()`'s new one-shot signal hookup fires
correctly on catch, with no `MissionDriver` involved (d07 has none — it's
`open`). **PASS.**

---

## 7. UNVERIFIED (honest)

- **d03 (bramble, ride, paw ramp)** — verified via `check_missions.gd`
  (params sane, waypoints above rescue floor) and by-construction (same
  `_process_ride`/bloom code path proven live for d05 in §6a), but not
  independently choreographed live — one ride live-verify was judged
  sufficient to prove the *mechanism*; d03's specific geometry (a sloped
  paw-ramp surface rather than a flat peak) was not separately observed.
- **wisp/marmalade's `race`/`shy` Moon-line wiring (d01/d09 in both
  worlds)** — the line TEXT is authored and `check_missions.gd` confirms
  `moon_line_key_ok` for both, and the wiring code is the exact same
  shared `mission_driver.gd` already proven live in bramble (§6a/6b) — but
  no choreography script was run against the wisp or marmalade scenes
  themselves this pass. High by-construction confidence (identical driver
  code, different data only), not a live receipt.
- **bramble d04/d06/d10's plain-open `moon_line_key`s** — authored as data
  (satisfies "every bramble dreamling gets... a moon_line_key") but
  deliberately NOT wired to speak (no `speak_on_collect` flag) to preserve
  the "rare, structural beats only" narration law — see §3's reasoning.
  This is a scope decision, not a bug, but flagging plainly in case a
  future pass expects all ten to be audibly spoken.
- **`docs/design/NARRATION_BIBLE.md`** — not updated (out of this pass's
  territory); its documented "~410 words" total and its "Keys prepared for
  other systems" section (which still describes `mission_race`/`mission_
  ride`/`mission_shy`/`mission_duet` as unwired) are now stale relative to
  this pass's actual wiring. Whoever owns `docs/design/**` next should
  reconcile it.
- **Windowed/movie receipt** — every run this pass was `--headless` (no
  rendering needed for these EVT/MOON_SAID-only properties); no video
  receipt was captured for the new archetypes. The prior shift's
  windowed race choreography (`docs/verify/aliveness-v2-VERIFY.md` §"Windowed
  race choreography") remains the only rendered/movie evidence for any
  mission archetype.

---

## Files touched

- `core/quests/mission.gd` (doc-comment update only — the TheMoon contract
  it describes changed; no code change)
- `worlds/common/mission_driver.gd` (`_speak_bloom_line()` + ride
  proximity-bloom + 4 call sites + header comment)
- `worlds/common/world_base.gd` (`_wire_open_moon_line()` + `_attach_mission`
  restructure)
- `scripts/autoloads/the_moon.gd` (additive: `GENTLE_KEYS`/`EXCITED_KEYS`
  entries only)
- `data/missions/bramble.json` (5 new/changed entries: d03/d04/d06/d07/d10;
  d01/d02/d05/d08/d09 kept, `story` field added to all 10)
- `data/moon_lines.json` (14 new keys)
- `tools/props/check_missions.gd` (`moon_line_key_ok` check +
  `MISSION_ARCHETYPE_COUNTS` summary)
- `tools/harness/scripts/mission_ride.json` (new)
- `tools/harness/scripts/mission_shy.json` (new)
- `tools/harness/scripts/mission_duet.json` (new)
- `tools/harness/scripts/mission_duet_solo.json` (new)
- `tools/harness/scripts/mission_geyser_flourish.json` (new, bonus)
- `docs/verify/missions-m2-VERIFY.md` (this file)

Not touched: `worlds/bramble/**` beyond reading `bramble.gd` for
placements (no edits — geometry/placement logic is another agent's
territory tonight per the brief), `worlds/wisp/**`, `worlds/marmalade/**`,
`worlds/pillow_fort/**`, `core/**` outside `core/quests/**`, `scenes/**`,
`project.godot`. No git commit made (per brief).
