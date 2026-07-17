# TORTOISE WORLD — VERIFICATION (M4, 2026-07-17)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
**served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic), running as
the Tortoise-world / M4 build agent inside a Claude Code session.

Scope: M4's headline — build the fourth world, AUNT TORTOISE, from scratch
on the proven giant+keystone template (Bramble → Wisp → Marmalade
precedent), plus the fourth hub door. Territory: `worlds/tortoise/**` (new),
the ONE `worlds/pillow_fort/pillow_fort.gd` door addition, `data/missions/
tortoise.json`, `data/critters/tortoise.json`, `data/dreamkeepers/
tortoise.json`, `data/moon_lines.json` (additive), `data/fort_residents/
spots.json` (additive, 8 tortoise-tagged spots), `scripts/autoloads/
the_moon.gd` (additive GENTLE_KEYS/EXCITED_KEYS entries), `tools/props/
check_placements.gd` + `check_missions.gd` (DEFAULT_WORLDS additions),
`tools/harness/scripts/tortoise_*.json`, this file, `docs/design/
world-cards/tortoise.md`, `evidence/stills/m4_tortoise/**`. No other files
touched. No commits made (director integrates).

---

## What shipped

**The world (`worlds/tortoise/tortoise.gd`, `class_name Tortoise extends
WorldBase`).** A radial layout (not linear like the other three worlds'
along-+X anatomy paths): a meadow skirt at ground level surrounds one big
buried terrain dome (`SHELL_CENTER`/`SHELL_RADIUS`, apex at y=12 — matching
Wisp's/Marmalade's own summit heights), and a spiral of four terraced
garden tiers (Tier1 ~2m → Tier2 ~5.6m → Tier3 ~9m → Crown ~12m) climbs up
and around it via long, gentle box ramps. The giant herself — a real
Meshy-generated plush tortoise (`assets/models/meshy/generated/
tortoise_giant.glb`, already on disk, `tortoise_giant` manifest entry) —
sits via a plain `ModelSlot` (quadruped, Meshy can't rig; the established
"static sculpt" precedent Marmalade's cat / Wisp's whale-body mounds
already set). GLB scale was measured, not guessed: a throwaway
`--script` probe (mirroring `ModelSlot._compute_local_aabb`) read the raw
local AABB (`size: x=1.389, y=0.908, z=1.906`), from which
`SHELL_TARGET_HEIGHT=19.0` was derived to land the model's long (Z) axis
at ~39.9m — dead center of the brief's "35-45m across" spec.

**Ten dreamlings (d01-d10), the exact mix asked for**: 1 race (d01, meadow),
1 ride (d04, Tier2), 1 duet (d05, Tier2), 1 shy (d08, Tier3), 1 flourish
(d07 — `open` archetype + `speak_on_collect`, riding a new `BreathingBloom`
perch — Tortoise's answer to Bramble's snore-geyser / Wisp's water-spout /
Marmalade's purr-thermal "rides a living breath" tradition), and 5 plain
`open` finds (d02, d03, d06, d09, d10) spread across meadow/terraces/
crown. `data/missions/tortoise.json` carries the 5 authored entries;
`check_missions.gd`'s own archetype tally confirms
`{"duet":1,"open":1,"race":1,"ride":1,"shy":1}` (the remaining 5 "open"
ids correctly have NO json entry at all — the established
zero-behavior-change convention, D21).

**The DreamDoor** sits beside a small "highest bloom" bump at the Crown —
"dreams return at the highest bloom," per the world card.

**Dressing, critters, a dreamkeeper.** ~14 dressing props (soft_pine_small,
berry_bush, moon_daisy, stone_soft, seed_puff on the fixed meadow;
mushroom_lamp, birdhouse_lantern, and a 3-piece clover_tuft hiding patch
around d08 on the rising terraces — all already-generated Meshy assets, no
new generation needed). `data/critters/tortoise.json`: 6 moths + 6 mice =
12 (at the brief's own cap). `data/dreamkeepers/tortoise.json`: one lamb
(`lamb_keeper`, already-rigged) visiting the meadow.

**THE SLOW RISE (`worlds/tortoise/rise_sequence.gd`, new, `class_name
RiseSequence`).** Built directly on `core/cinematic/cine_sequence.gd` (the
letterbox + cine-camera machinery Wisp's/Marmalade's own file headers
flagged as "an M4 card, not tonight's" — it is tonight's, here), NOT a
third hand-duplicated copy. Trigger: `GameState.world_completed
("tortoise")`, once per save, the same existing WorldBase signal every
other keystone reuses. `--rise` force-arms it 3s after load, dev/capture
only. Choreography: reward ground goes solid FIRST (the established
"never gate new ground behind the full animation length" lesson) → every
connected player bubble-lifts to the meadow BEFORE anything moves → a 12s
rise (the whole garden — shell terrain, all four terrace ledges + their
ramps, the crown bloom bump, the DreamDoor, every terrace dressing prop —
lifts +4m together) → petals drift (`GPUParticles3D`, blush quads) → a 3s
hold under the moon → an 8s settle back down (slower than every other
keystone's own settle — "slower than anything in the game," per the
brief) → letterbox out. Persistence: `_apply_already_risen_state()` snaps
the garden back to rest and the reward permanently visible/solid on a
revisit, matching the "world remembers the transformation, not the
animation" pattern Wisp's dive / Marmalade's stretch already established.

**Architecture note on "the whole garden lifts together"**: rather than
reparenting every dreamling/prop under one shared moving group (which
would have accidentally exempted ALL ten dreamlings from
`check_placements.gd`'s ground-gap check, not just the one — d07 — that's
genuinely supposed to be exempt), `tortoise.gd` keeps every dreamling a
direct child of the world root exactly like every other world, and
instead collects an explicit `Array[Node3D]` of top-level rising pieces
(`garden_nodes()`) as they're built. `RiseSequence` tweens `position:y` on
every entry in that array by the same delta, in parallel — visually
identical to a single shared parent, zero risk to the established
per-dreamling placement-checking convention.

**The reward — "a permanently raised step... left behind"**: a small
blush "Highest Bloom" nook near the crown (`REWARD_ANCHOR`, its own XZ
anchor, clear of both the crown ledge and the bloom bump by hand-checked
margins), built hidden + collision-disabled at boot, revealed (visibility
+ collision flip, matching Wisp's flood-route / Marmalade's attic-nook
"build once, reveal by flip" convention) the moment the rise starts, its
own small Y-arrival tween timed to land during the settle. Dressed with
`birdhouse_lantern` + `moon_daisy` + `moth_small` (Marmalade's own nook
dressing recipe, reused).

**The fourth fort door.** `worlds/pillow_fort/pillow_fort.gd`'s
`_build_bramble_door()` gained one more `_add_world_door()` call —
`TortoiseDoor`, moss-green (`#8C9463`), at `(0.0, 0.0, 9.2)` yaw `0.0` (the
clearing's one remaining clear side — north, on the Z axis like
BrambleDoor's own south placement, tangent-oriented the same way). Checked
by hand against the fort layout before placing: clear of both spawn
points (>6m), both walkable cushions and Callie's cushion (>10m), every
existing `fort_residents/spots.json` entry (all at z≤2.5; this door sits
at z=9.2), and the nearest fence post (2.3m clear). 8 new tortoise-tagged
spots were added to `data/fort_residents/spots.json`, clustered north of
the new door, clear of its own trigger box and the fence ring.
`FORT_RESIDENT_CAP` (30) was deliberately left untouched — out of the "ONE
door" territory for this pass — so a fully-completed fourth world will not
get a visible resident for every dream; documented honestly in the
spots.json comment, not silently left as a surprise.

**Moon narration.** 5 new lines (`tortoise_d01_race`, `tortoise_d04_ride`,
`tortoise_d05_duet`, `tortoise_d07_bloom`, `tortoise_d08_shy`), each
9-10 words (≤12 floor). Registered additively in `scripts/autoloads/
the_moon.gd`: `tortoise_d08_shy`/`tortoise_d07_bloom` → `GENTLE_KEYS`;
`tortoise_d01_race`/`tortoise_d05_duet` → `EXCITED_KEYS` (matching the
exact per-archetype pattern every other world's own race/shy/duet keys
already follow — `tortoise_d04_ride` deliberately left unlisted, matching
the codebase's own convention that no `_ride` key appears in either list
today). **Word budget**: a full recount of `data/moon_lines.json` after
the edit — 575 words total across every key (well under the ≤900 law),
47 of those newly added by this pass.

---

## Bugs found + fixed during this pass (the terrain-curvature lesson)

`tools/props/check_placements.gd --world=tortoise` caught three real bugs
on the first run (`d03`/`d05`/`d08`, all `"inside_solid":true"`). Root
cause, in two parts:

1. **The shell terrain is a SOLID ball** (`SphereShape3D` has no hollow
   interior). At the outer tiers (Tier1 especially — its anchor sits at
   `d~20.25` out of `SHELL_RADIUS=26`, close to the ball's own "equator"
   relative to its radius), the ball's local surface climbs steeply with
   lateral XZ distance from a ledge's own anchor point — over a meter of
   rise across less than 2m of offset. A flat ledge computed from ONE
   anchor sample plus a small clearance can sit entirely below the ball's
   surface just a meter or two off that anchor. Fixed by widening
   `TERRACE_HEIGHT_ABOVE_ANCHOR` (0.4 → 1.5, in two escalating steps as
   each new run re-surfaced the same class of bug) and pulling dreamling/
   dressing offsets in closer to each ledge's own anchor (`TIER_OFFSET`).
2. **Every ramp's own box collision is centered exactly on the ledge's
   anchor point at both ends it touches** (Tier2 in particular — where
   Ramp1 arrives and Ramp2 departs from the SAME point). A dreamling
   offset placed within roughly half the ramp's own width of that shared
   point can land inside the ramp itself, independent of the terrain-ball
   issue above (`d08`'s original position, and `d10`'s once-flaky
   failure, were traced to this, not curvature). Fixed by narrowing
   `ASCENT_RAMP_WIDTH` (5.0 → 2.0, across three escalating passes) and,
   for Tier2 specifically (both ramps meeting at once), moving `d04`/`d05`
   to a Z-leaning offset well clear of the ramps' own X-leaning shared
   connection point.

`d05` additionally **flickered PASS/FAIL run-to-run** at one intermediate
fix (`ground_gap` swinging from 0.0 to 0.19 across identical positions) —
traced to `dreamling.gd`'s own `_bob_phase = randf() * TAU` (a true random
seed, not a deterministic RNG — present in every world, not introduced by
this pass, and out of this pass's territory to change) combining with an
already-thin baseline clearance. Fixed by widening the baseline margin
enough to absorb the bob's own ±0.15m swing, then re-verified: **13
consecutive clean `check_placements.gd --world=tortoise` runs**, zero
flakes, before moving on. Final geometry constants and their own inline
comments in `tortoise.gd` document this reasoning in place, for whichever
agent next has to add a fifth tier to this world or a similar dome-terrain
world elsewhere.

---

## Receipts

**Import pass:**
```
godot_console.exe --headless --editor --import --quit --path .
```
Exit code `0`. `Tortoise`, `RiseSequence`, `BreathingBloom` all register
cleanly as global classes. Zero script errors.

**Headless boot:**
```
godot_console.exe --headless --path . -- --skipmenu --world=tortoise --quitafter=5
```
```
WORLD_READY {"id":"tortoise","objectives":10}
HUD_READY {"pips":10,"world":"tortoise"}
MOON_SAID {"key":"new_area", ...}
EVT {"seat":1,"t":8,"type":"landed"}
EVT {"seat":2,"t":10,"type":"landed"}
```
No script errors. `AudioManager: stem layer not found (no-op): .../stems/
tortoise/layer_1.ogg` and `ambience not found (no-op): .../ambience/
tortoise.ogg` are honest, expected no-ops (see UNVERIFIED — no dedicated
audio pass yet, matching the task brief's own acknowledgment).

**Placements, ALL FIVE worlds:**
```
check_placements.gd (DEFAULT_WORLDS)     → PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort","bramble","tortoise"]}
check_placements.gd -- --world=wisp      → PLACEMENT_SUMMARY {"any_fail":false,"worlds":["wisp"]}
check_placements.gd -- --world=marmalade → PLACEMENT_SUMMARY {"any_fail":false,"worlds":["marmalade"]}
```
Tortoise's own 10/10: `d01`/`d02` (meadow) ground_gap 0.4-0.7m; `d03`/
`d04`/`d05`/`d06`/`d08`/`d09`/`d10` (terraces/crown) ground_gap 0.1-0.4m;
`d07` (BreathingBloom, moving-platform exemption) PASS. **13 consecutive
runs, zero flakes** (see the bugs section above for why that number
matters here specifically). `tortoise` added to `check_placements.gd`'s
own `DEFAULT_WORLDS` (was `["pillow_fort","bramble"]`, now includes
`"tortoise"` — `wisp`/`marmalade` were already absent from that array
before this pass; out of this territory to add, flagged honestly below).

**Missions, ALL worlds with mission data:**
```
check_missions.gd → MISSION_SUMMARY {"any_fail":false,"worlds":["bramble","wisp","marmalade","tortoise"]}
```
`tortoise` added to `check_missions.gd`'s own `DEFAULT_WORLDS`.
`MISSION_ARCHETYPE_COUNTS {"world":"tortoise","counts":{"duet":1,"open":1,
"race":1,"ride":1,"shy":1},"total":5}` — matches the brief's mix exactly.

**`finale_home.json` (existing script, unmoved) — proves the new
TortoiseDoor didn't break the established route:**
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=pillow_fort --pads=2 --script=tools/harness/scripts/finale_home.json --quitafter=27
```
`CALLIE_COUNT`, `CALLIE {"state":"carried"}`, `DOOR {"to":"bramble"}`,
`WORLD_READY {"id":"bramble", ...}`, both `d01`/`d02` collected — identical
to the pre-existing receipt, unaffected.

**TortoiseDoor itself** — a throwaway probe (`evidence/_scratch/
door_probe.json`, deleted after use, territory-legal per the established
`evidence/_scratch/` exception): teleport to `(0,0.1,9.2)`, interact →
`DOOR {"to":"tortoise"}` → `WORLD_READY {"id":"tortoise", ...}`. Confirmed
working, then the throwaway script was removed.

**`tools/harness/scripts/tortoise_tour.json` (new)** — spawn → real
walking legs (never teleport) → 2 dreamlings, camera-settle discipline
(idle 3s, then pure-axis moves — gotcha #7). Movement here is
camera-relative (`core/movement/player_body.gd _camera_relative_dir`);
the exact mapping (spawn's `MeadowApproachHint` yaw=-90 makes camera-
forward world +X) was **measured via a throwaway probe script**, not
assumed — an early draft used raw world-axis vectors and walked the
player roughly 90° off course, caught live via `PLAYER_POS` trail
inspection.
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=tortoise --pads=1 --script=tools/harness/scripts/tortoise_tour.json --poslog=60 --quitafter=26
```
```
EVT {"type":"mission_race_started","id":"d01", ...}
EVT {"type":"dreamling_collected","id":"d01", ...}
EVT {"type":"mission_caught","id":"d01", ...}
EVT {"type":"dreamling_collected","id":"d02", ...}
```
Zero `RESCUE` lines (flat meadow route). Both catches confirmed via a
second corrective pass after the first draft undershot d02's position by
~2.3m (outside `ATTRACT_RADIUS`) — caught live via the final
`PLAYER_POS`, retimed, re-verified.

**`tools/harness/scripts/tortoise_rise.json` (new)** — Phase 1 (`--rise`,
no scripted input needed): full phase order, exactly as designed:
```
RISE {"forced":true,"phase":"start"}
RISE {"phase":"reward_ground_solid"}
RISE {"phase":"petals"}
RISE {"phase":"risen"}
RISE {"phase":"settling"}
RISE {"phase":"settled"}
RISE {"forced":true,"phase":"end"}
```
Both seats bubble-lift to the meadow (`(-18/-16.6, 0.45, -12.0)`) and hold
rock-solid through the whole ~26s choreography — zero real `RESCUE`
receipts (the one grep match was the harness script's own description
text, not an event — double-checked). PHASE 2 (teleport-assisted, ~30s
in, well after `phase=end`, same allowance `marmalade_stretch.json`'s own
Phase 2 used): both seats teleport onto the Highest Bloom reward platform
at `(29.0, 12.3, 4.0)`/`(29.0, 12.3, 4.6)`, settle to `(29.0, 12.36, *)`,
and hold there UNCHANGED for the remaining ~6.5s of the run — proves the
crown reward is solid, reachable ground at its permanent post-rise
position.
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=tortoise --pads=2 --rise --script=tools/harness/scripts/tortoise_rise.json --poslog=30 --quitafter=37
```

**Pre-existing shutdown warning (not this pass's bug)**: every run above
prints `WARNING: ObjectDB instances leaked at exit` / `ERROR: N resources
still in use at exit` on quit. Confirmed pre-existing and unrelated to
this pass — the identical warning fires on a plain
`--world=marmalade --stretch --quitafter=8` run too.

---

## Stills — the "would a child know?" verdict (own eyes)

- `evidence/stills/m4_tortoise/establishing/shot_120.png` (devcam wide,
  pre-rise) and `.../terraces/shot_90.png` (overhead spiral angle): **the
  tortoise reads clearly** — a moss-green domed shell with visible
  individual scute-plate bumps, a warm sandy tucked head poking out at the
  front. A child would read "sleeping tortoise" immediately from either
  angle. **Garden-reads verdict: PARTIAL.** The terrace ramps (flat brown
  planks crossing the dome at angles) read more like plank-bridges laid
  across her shell than blended garden terraces — there's no grass/bloom
  texture ON the ramps/ledges themselves yet, only the standalone dressing
  props scattered near them. This matches the SAME grey-box-geometry
  register every sibling world's own ledges/shelves/roofs use (flat
  StandardMaterial3D boxes) — not a regression, but the "garden" read is
  currently carried entirely by the separate dressing props (clover/
  daisies/lanterns), not by the terrace geometry itself. Flagging
  honestly rather than claiming more than the still shows.
- `evidence/stills/m4_tortoise/establishing/shot_90.png` (real spawn
  camera, no devcam): Pip + Otto in the meadow among soft-pine/berry-
  bush/moon-daisy dressing; the shell itself is only a thin sliver at the
  very top of frame. This is the SAME pre-existing "tight spawn crop"
  limitation Marmalade's own VERIFY doc already documented (the camera
  rig's fixed downward pitch, `core/**`, out of this pass's territory) —
  not new, not fixed here, flagged for completeness.
- `evidence/stills/m4_tortoise/rise/shot_540.png` (mid-rise, ~6s into the
  12s lift) and `shot_990.png` (during the hold, fully risen): **the
  rise-read verdict is clean.** Between the two shots her pose visibly
  changes — four leg-like bumps become clearly visible under the shell in
  `shot_990` that read as barely-there in the pre-rise establishing shots
  — a genuine "she's stirring/standing" read, letterbox bars confirming
  the cinematic camera is active, the Moon's `world_complete` subtitle
  still lingering in `shot_540`.
- `evidence/stills/m4_tortoise/crown/shot_1770.png` (devcam, captured
  right after `phase=end`, ~29.5s into a forced `--rise` run): **the
  clearest "reward" read of the whole set.** The revealed Highest Bloom
  platform is unmistakably a distinct blush/lavender square against the
  moss-green terrace ledges around it, its lantern/daisy/moth dressing
  visible on top, connected into the same ramp network as the rest of the
  climb, the shell's own dome visible below. A child would read this as
  "a new pretty spot appeared" immediately. (Two earlier attempts at this
  shot, `shot_660.png`/`shot_700.png`, only captured the mid-sequence
  CINE camera's own view — `RiseSequence`'s letterboxed camera takes over
  the viewport for the whole ~26s choreography and only hands control back
  to whatever was `current` before `begin()` — devcam included — once
  `_cine.end()` fires; both are kept as honest mid-rise records of the cine
  camera's own default framing, not reward shots.)

---

## UNVERIFIED (honest list)

- **The terrace/ramp geometry reads as "plank-bridges across a dome," not
  fully "garden terraces blended into a hillside"** — see the stills
  section above. A follow-up art pass (softer ramp materials blended with
  grass, or terraces re-cut to better hug the dome's own curvature) would
  strengthen this; not attempted here given the placement-correctness
  work this pass already required (see the bugs section).
- **The spawn establishing shot is tightly cropped** — same pre-existing
  camera-rig limitation Marmalade's own VERIFY doc flagged; not
  `core/**`-fixable from this territory.
- **`wisp`/`marmalade` are still absent from `check_placements.gd`'s own
  `DEFAULT_WORLDS`** (only `pillow_fort`/`bramble`/now `tortoise` are
  listed there) — a pre-existing gap from before this pass, verified
  working correctly via their own explicit `--world=` runs above but
  outside this pass's "add tortoise to the world lists" instruction to
  fix more broadly.
- **`FORT_RESIDENT_CAP` (30) was not raised** — a fully-completed fourth
  world (40 total possible returned dreams across all four worlds) will
  not get a visible fort resident for every one of them once the other
  three worlds are also fully done; the 8 new tortoise spots make the
  fourth door's own neighborhood populated, but the cap itself is
  untouched by design (the "ONE door" territory boundary) — documented in
  `spots.json`'s own comment, not a silent gap.
- **THE SLOW RISE's shell-terrain does NOT itself gain a permanently
  different resting pose after completion** (unlike the reward nook,
  which does persist) — she settles back to her exact pre-rise sleep
  transform every time, matching Dive's/Stretch's own "the world
  remembers the transformation, not the animation" pattern exactly. Flagged
  only so a reader doesn't expect otherwise.
- **Audio**: no dedicated `stems/tortoise/` set or `ambience/tortoise.ogg`
  exists yet — `AudioManager` no-ops both, per its own documented
  fail-soft convention (confirmed live in the headless boot receipt
  above). `RISE` reuses `giant_rumble`/`giant_yawn_sigh` as placeholders,
  same as every other keystone's own placeholder-audio note.
- **60fps sustained perf**: not instrumented for this pass (same
  pre-existing gap flagged in every prior world's own VERIFY doc).
- **Co-op / solo controller feel for THE SLOW RISE itself was not tested
  with real jump/movement input** — verified via the forced `--rise` flag
  (no player input needed during the sequence itself) plus the
  teleport-assisted reward-landing proof, matching every other keystone's
  own precedent for this exact kind of claim, not a scripted live
  jump-arc traversal.
- I did not re-run the full regression suite for `pillow_fort`/`bramble`/
  `wisp`/`marmalade` beyond `check_placements`/`check_missions`/
  `finale_home.json` (all outside this pass's territory to edit further).

---

## Files touched (≤12 lines)

- `worlds/tortoise/tortoise.gd`, `rise_sequence.gd`, `breathing_bloom.gd`,
  `tortoise.tscn` — new (the world + keystone).
- `worlds/pillow_fort/pillow_fort.gd` — the ONE `TortoiseDoor` addition.
- `data/missions/tortoise.json`, `data/critters/tortoise.json`,
  `data/dreamkeepers/tortoise.json` — new.
- `data/moon_lines.json`, `scripts/autoloads/the_moon.gd` — additive.
- `data/fort_residents/spots.json` — additive (8 tortoise spots + comment).
- `tools/props/check_placements.gd`, `check_missions.gd` — `tortoise`
  added to `DEFAULT_WORLDS`.
- `tools/harness/scripts/tortoise_tour.json`, `tortoise_rise.json` — new.
- `docs/design/world-cards/tortoise.md`, this file — new.
- `evidence/stills/m4_tortoise/**` — new (receipts).
