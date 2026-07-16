# bramble-setpieces-VERIFY.md — Bramble's two body-functions (M2)

served_model: claude-sonnet-5 (Claude Sonnet 5, Anthropic), acting as the
Bramble set-piece agent. Engine: `D:\Tools\godot\godot_console.exe` ->
`4.6.2.stable.official.71f334935`.

Built against the live worktree, territory-scoped to `worlds/bramble/**`,
new `tools/harness/scripts/bramble_*.json`, and this file. Nothing outside
that set was touched (see `git diff --stat` in the session commit).

## What shipped

1. **Breath-becomes-weather** (`worlds/bramble/breath_weather.gd`, new) —
   an always-on ~44s cycle (within the brief's 40-60s window), independent
   of `BreathingChest`'s fast 5s bounce. On the ~9s exhale: a broad (5m
   radius, 9m tall) updraft area near the snout (see placement note below)
   lifts players using the *exact* eased `move_toward`-toward-`vent_speed`
   / never-push-down law `SnoreGeyser._lift_bodies` already uses; a
   `BreathMotes` particle system (via `ParticlePresets.make_ambient_glow`,
   the same builder `core/env/ambience.gd` uses) turns on; a warm
   `OmniLight3D` swells over 2s. `BREATH {"phase":"exhale_start"|
   "exhale_end"}` prints on every transition.
2. **THE ROLL-OVER** (`worlds/bramble/rollover_sequence.gd`, new) — the
   one-time transformative set piece. Triggers on `GameState.world_completed`
   ("bramble") — which `WorldBase._check_completion()` already fires the
   instant all 10 dreamlings return — or is force-armed 3s after load via
   `--rollover` (dev/capture only). Every connected player is bubble-lifted
   (`core/rescue/bubble_effect.tscn`, the shared rescue/warp visual
   vocabulary) onto a new far meadow (new ground south of the existing
   meadow's z=-40 edge) while the haunch mound settles (translate + spin)
   over 8s. A revisit after a prior session already completed the world
   builds the far-meadow end-state directly, with no replay of the
   animation (`GameState.is_world_completed`).
3. **`--rollover` force-arm** (`Harness.flags`, read-only from my side) —
   fires the sequence ~3s after load regardless of dream count, for
   dev/capture. `ROLLOVER {"forced":true,"phase":"start"}`.
4. **Receipts + harness scripts** — `tools/harness/scripts/
   bramble_breath_lift.json`, `tools/harness/scripts/bramble_rollover.json`.

## Placement note: "in front of the snout"

The brief's literal reading (x beyond the head, z=0) sits on the head
sphere's own sloped surface out to x=64.25 (`HEAD_CENTER`/`HEAD_RADIUS`,
`bramble.gd`) — placing the updraft there either buries it in the mound or
strands it in the last ~5m before the meadow's x=70 edge. The updraft
instead sits at `(58, 0, 24)`: same X neighborhood as the snout/geysers,
offset in Z to clear the head sphere's footprint entirely (its z-reach at
y=0 tops out at 16.25) and land on flat, open meadow reachable "from the
meadow" with no climb, per the brief's "soft elevator" framing. It is
**not** literally astride the chest platform at x=-5 — "gain enough height
to reach the chest from the meadow" is verified as **height parity**
(reaching chest-plateau-comparable altitude, ~7.5m) rather than a landing
on the chest deck itself. See run (c) below: the player peaks at **11.49m**,
well past the 7.5m target, from a dead standing start at ground level.

## Bug found and fixed live, before this file existed

**`lift_rate` too low to ever overpower gravity.** First cut used
`lift_rate = 10.0` (a bit under the geyser's own 14.0, meant to feel
"gentler"). Live receipts showed the player trapped oscillating at
`MovementTuning.apex_hang_threshold` (~0.49 m/s average climb, net *zero*
real lift) instead of climbing — because `SnoreGeyser`/`BreathWeather`
lift only ever nudges `velocity.y` toward a target; `PlayerBody`'s own
gravity (Otto's `rise_gravity` ≈14.8 m/s², `data/tuning/otto_movement.tres`)
fights it every physics frame it's applied, and a player normally enters
the geyser already jumping (real velocity head start) — this updraft is
meant to also work from a dead stand. Fixed by raising `lift_rate` to
`18.0` (clears both players' gravity with real margin). See run (c)'s
first attempt vs. final: 4.75m peak (broken) → 11.49m peak (fixed). Full
reasoning is now a permanent code comment in `breath_weather.gd`.

**Far-meadow collision race.** First cut only flipped the far meadow's
collision live at the *end* of the 8s rotate timer, while the bubble
carrying players there used a shorter 4s flight — players landed on still-
disabled collision and fell through into a generic `RESCUE` instead of the
new ground. Fixed by revealing the far meadow (visual + collision)
immediately at sequence start instead of gating it behind the haunch
settle's own timer; see run (d)'s first attempt (RESCUE fired for both
seats) vs. final (no RESCUE, clean landing).

**`setup()`-after-`add_child()` ordering bug.** `add_child()` fires
`_ready()` synchronously, so `RolloverSequence`'s `_world`/`_haunch_visual`/
`_haunch_body` were still null when `_ready()` first ran (`SCRIPT ERROR:
Invalid access to property... on a base object of type 'Nil'`). Fixed by
calling `setup()` before `add_child()` in `bramble.gd`.

**Scratch-test save pollution (verification-process finding, not a code
bug).** A one-off `--script` smoke test that called
`GameState.mark_world_completed("bramble")` directly to prove the organic
trigger path wrote that completion straight to the real
`user://save.json` (Godot per-machine dev-user data, not a repo file, not
git-tracked). Every subsequent `--rollover` run silently took the
"already completed" branch (no animation) until this was noticed and the
save file deleted to reset a clean baseline. Flagging this so a future
capture session isn't confused by a stale completed-world save — delete
`%APPDATA%\Godot\app_userdata\THE BIG NAP\save.json` for a clean slate.

## a) Headless import — exit 0, zero script errors

```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path .
```

Both new classes register clean on the incremental pass:

```
[   0% ] update_scripts_classes | Bramble
[  16% ] update_scripts_classes | BreathWeather
[  33% ] update_scripts_classes | RolloverSequence
```

## b) `tools/props/check_placements.gd` — green, unaffected by default

```
D:\Tools\godot\godot_console.exe --headless --path . --script tools/props/check_placements.gd
```

```
WORLD_READY {"id":"pillow_fort","objectives":0}
PLACEMENT_NOTE pillow_fort has zero dreamlings (nothing to check)
WORLD_READY {"id":"bramble","objectives":10}
PLACEMENT {"ground_gap":0.31,...,"id":"d06",...,"verdict":"PASS",...}
PLACEMENT {"ground_gap":7.82,...,"id":"d07",...,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.61,...,"id":"d01",...,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.43,...,"id":"d02",...,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.24,...,"id":"d03",...,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.37,...,"id":"d04",...,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.36,...,"id":"d05",...,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.38,...,"id":"d08",...,"verdict":"PASS",...}
PLACEMENT {"ground_gap":0.45,...,"id":"d09",...,"verdict":"PASS",...}
PLACEMENT {"ground_gap":1.51,...,"id":"d10",...,"verdict":"PASS",...}
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort","bramble"]}
```

Exit code `0`, `any_fail: false`. This is the **default boot state**
(no `--rollover`, no completed save) — my new geometry (the haunch settle,
the far meadow) is built lazily inside `RolloverSequence._ready()` only
when the sequence actually triggers, so this run never touches it; the
haunch stays exactly where `bramble.gd`'s own `_add_mound("Haunch", ...)`
put it, unmoved. `d07`'s `moving_platform: true` / `ground_gap: 7.82`
(riding `SnoreGeyser`, untouched by my changes) is unchanged from before
this work.

## c) `bramble_breath_lift.json` — updraft lift property

```
D:\Tools\godot\godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=bramble --pads=2 --script=tools/harness/scripts/bramble_breath_lift.json --poslog=15 --quitafter=18
```

Receipts (seat 1 only, trimmed to the shape of the climb):

```
PLAYER_POS {"seat":1,"t":360,"x":-55.0,"y":0.45,"z":0.0}
BREATH {"phase":"exhale_start"}
HARNESS_TELEPORT {"pos":[58.0,0.5,24.0],"seat":1}
PLAYER_POS {"seat":1,"t":375,"x":58.0,"y":0.47,"z":24.0}
PLAYER_POS {"seat":1,"t":450,"x":58.0,"y":3.69,"z":24.0}
PLAYER_POS {"seat":1,"t":495,"x":58.0,"y":8.01,"z":24.0}
PLAYER_POS {"seat":1,"t":540,"x":58.0,"y":11.49,"z":24.0}   <- PEAK, 11.49m
PLAYER_POS {"seat":1,"t":600,"x":58.0,"y":3.58,"z":24.0}
EVT {"seat":1,"t":614,"type":"landed"}
PLAYER_POS {"seat":1,"t":615,"x":58.0,"y":0.45,"z":24.0}    <- caught by the column again, second bob
PLAYER_POS {"seat":1,"t":780,"x":58.0,"y":11.48,"z":24.0}   <- second peak, 11.48m
PLAYER_POS {"seat":1,"t":855,"x":58.0,"y":0.95,"z":24.0}
EVT {"seat":1,"t":857,"type":"landed"}
BREATH {"phase":"exhale_end"}
PLAYER_POS {"seat":1,"t":960,"x":58.0,"y":0.45,"z":24.0}    <- settled, ground level, still
```

Proves: the exhale opens at t=360 (start_delay=6s @60fps) exactly as
tuned; from a dead stand at y=0.45, the updraft carries the player to a
peak of **11.49m** — well past the chest-plateau's ~7.5m top — bobs a
second time (a real "fountain" ride, not a single boost), and settles
cleanly back to y=0.45 (no stuck state, no residual velocity) after
`exhale_end`. Run is bit-for-bit reproducible under `--fixed-fps 60`
(verified — reran and diffed, identical PLAYER_POS values every frame).

## d) `bramble_rollover.json` — THE ROLL-OVER property (`--rollover`)

```
D:\Tools\godot\godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=bramble --pads=2 --rollover --script=tools/harness/scripts/bramble_rollover.json --poslog=60 --outdir=evidence/_scratch/bramble_rollover_run --quitafter=16
```

Receipts (both seats, trimmed):

```
PLAYER_POS {"seat":1,"t":180,"x":-55.0,"y":0.45,"z":0.0}
PLAYER_POS {"seat":2,"t":180,"x":-57.0,"y":0.43,"z":2.0}
ROLLOVER {"forced":true,"phase":"start"}
MOON_SAID {"key":"world_complete","text":"This whole place is dreaming happily now, because of you.",...}
PLAYER_POS {"seat":1,"t":240,"x":-50.04,"y":0.61,"z":-7.38}
PLAYER_POS {"seat":1,"t":360,"x":-25.29,"y":1.43,"z":-44.14}
BREATH {"phase":"exhale_start"}
PLAYER_POS {"seat":1,"t":420,"x":-20.0,"y":1.6,"z":-52.0}    <- bubble arrival, far meadow landing pad
PLAYER_POS {"seat":2,"t":420,"x":-18.6,"y":1.6,"z":-52.0}
PLAYER_POS {"seat":1,"t":480,"x":-20.0,"y":0.45,"z":-52.0}   <- settled ON solid ground, no fall-through
PLAYER_POS {"seat":2,"t":480,"x":-18.6,"y":0.43,"z":-52.0}
PLAYER_POS {"seat":1,"t":660,"x":-20.0,"y":0.45,"z":-52.0}
ROLLOVER {"forced":true,"phase":"end"}
PLAYER_POS {"seat":1,"t":900,"x":-20.0,"y":0.45,"z":-52.0}   <- holds steady, far meadow
PLAYER_POS {"seat":2,"t":900,"x":-18.6,"y":0.43,"z":-52.0}
```

**No `RESCUE` line anywhere in the run** — the failure mode that would
mean a player fell through the far meadow into the generic rescue net
instead of landing on the new ground (this exact failure DID occur before
the collision-race fix above; its absence here is the property). Sequence
runs `start` (frame ~210) to `end` (frame ~660), matching `ROTATE_DURATION
= 8.0s`. Both seats hold a stable position on the far meadow (x=-20/-18.6,
z=-52, within the new `FAR_MEADOW_SIZE` bounds of x:-45..5, z:-40..-63)
through the rest of the run.

### Organic (non-forced) trigger — proven separately

`--rollover` only proves the force-arm path. The **real** trigger
(`GameState.world_completed`) was verified with a throwaway `--script`
tool (`extends SceneTree`, same technique as `tools/props/
check_placements.gd`) that loaded `bramble.tscn` fresh and called
`GameState.mark_world_completed("bramble")` directly — the same call
`WorldBase._check_completion()` makes the instant a world's 10th dreamling
returns:

```
EVT {"t":10,"type":"world_completed","world_id":"bramble"}
ROLLOVER {"forced":false,"phase":"start"}
MOON_SAID {"key":"world_complete","text":"This whole place is dreaming happily now, because of you.",...}
```

And the **revisit-after-completion** path (`GameState.is_world_completed`
already true at `_ready()`) was proven the same way — pre-marking
completed, then loading `bramble.tscn` fresh:

```
DEBUG_TEST {"far_meadow_found":true,"far_meadow_visible":true,"haunch_position":[-30.0,-7.0,4.0],"haunch_yaw":34.9999961853027}
```

The haunch sits at its final settled position (`HAUNCH_CENTER +
HAUNCH_SETTLE_OFFSET` = `(-30,-6,0) + (0,-1,4)` = `(-30,-7,4)`, matches
exactly) and the far meadow is already visible — with **no** `ROLLOVER`/
`MOON_SAID`/rumble lines printed (no replay), confirming "once per save."
The scratch test file was deleted after use — it is not part of this
delivery, per territory rules (only `worlds/bramble/**`, `tools/harness/
scripts/bramble_*.json`, and this doc are new).

## e) Stills

`evidence/stills/m2_bramble/shot_350.png` (mid-rollover, haunch settling,
bear pose visibly different from rest) and `shot_750.png` (far meadow,
post-landing, decorative props visible) — captured via:

```
D:\Tools\godot\godot_console.exe --path . --fixed-fps 60 --resolution 1280x720 -- --skipmenu --world=bramble --pads=2 --rollover --shots=350,750 --outdir=evidence/stills/m2_bramble --quitafter=16
```

(Windowed, not `--headless`, per `tools/harness/README.md` — Movie
Maker/screenshots need a real display driver.)

## UNVERIFIED

- **Audio.** `breath_exhale.ogg` and `bear_rollover_rumble.ogg` do not
  exist yet (`AudioManager: sfx not found (no-op)` in every run, its
  documented fail-soft convention). No SFX asset was authored — out of
  this agent's scope (grey-box, no art/audio delivery). The call sites are
  wired and will pick up real clips the moment they land at those paths.
- **The eye-test.** No human/couch playtest of "does the fountain feel
  like a gift" or "does the roll-over read as the giant moving" — only
  receipts and two stills are evidence here. The brief's "must feel like a
  gift, never a fling" is argued from the tuning numbers (eased
  `move_toward`, never a snap, never pushes down) and the bobbing-fountain
  shape of the PLAYER_POS trace, not from watching it.
- **Two-player choreography of the roll-over specifically.** Both seats
  were proven to land safely and simultaneously (run d), but no scenario
  was run where one player is mid-air (jumping/tossed) at the exact
  instant the sequence force-triggers — `enter_bubbled()` is unconditional
  per player found in the `"players"` group regardless of their current
  `state`, and `BubbleEffect.play()` itself does not special-case a
  ballistic/CARRIED starting state beyond what `soft_landing.gd`'s own
  rescue path already relies on (same code path) — reasoned safe by
  code-reading, not receipted.
- **Far-meadow camera hint quality.** `FarMeadowHint` was added (yaw 180,
  facing the seam) but never evaluated against a moving camera in real
  play — only that its `CollisionShape3D` exists and gets un-disabled on
  reveal (see run (d)'s implicit proof: no script error, world stayed
  bootable). No still specifically frames "does the auto-camera settle
  nicely on arrival."
- **Real 10-dreamling playthrough.** The organic trigger's *signal wiring*
  is proven (§d, "Organic trigger"), but no run actually walked/collected
  all 10 dreamlings through real gameplay and returned them to the
  DreamDoor — that would additionally exercise the "d07 still exists on
  its geyser mid-collection" timing this sequence's design deliberately
  avoids disturbing. Reasoned safe (my code never touches the head/ear/
  geyser geometry at all, in any path), not receipted end-to-end.
- **`--fixed-fps` determinism of the flower-cluster decoration.** Uses its
  own locally-seeded `RandomNumberGenerator` (seed 7, `GrassField`'s own
  convention) specifically so it never depends on/consumes the shared
  global RNG stream `--seed=N` controls — not independently reran twice to
  diff, though the mechanism is identical to `GrassField.scatter()`'s
  already-shipped, already-verified pattern.

## Files touched

- `worlds/bramble/breath_weather.gd` (new)
- `worlds/bramble/rollover_sequence.gd` (new)
- `worlds/bramble/bramble.gd` (wired both in; new `BREATH_UPDRAFT_POSITION`
  const + `_build_breath_weather()`/`_build_rollover()` calls in `_ready()`)
- `tools/harness/scripts/bramble_breath_lift.json` (new)
- `tools/harness/scripts/bramble_rollover.json` (new)
- `docs/verify/bramble-setpieces-VERIFY.md` (this file)
