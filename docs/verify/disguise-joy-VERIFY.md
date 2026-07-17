# disguise-joy-VERIFY.md — D26 disguise fix + bear-path joy pass

served_model: claude-sonnet-5 (Claude Sonnet 5, Anthropic), acting as the
Disguise & Joy agent. Engine: `D:\Tools\godot\godot_console.exe` ->
`4.6.2.stable.official.71f334935`, Windows.

Territory: `worlds/bramble/**`, `tools/harness/scripts/bramble_*.json`, this
file, `evidence/stills/m3_disguise/**`. Nothing outside that set was
touched. No commits made (director integrates).

Starting point: `docs/verify/mountain-m3-VERIFY.md`'s own honest verdict —
"PARTIAL... his face is not hidden" — and the director's still-review
verdict on `evidence/stills/m3_mountain/v4_wide_disguised/shot_150.png`:
teddy-orange fur, soap-bubble clouds, an exposed sitting silhouette, dark
chocolate-slab ramps reading as scaffolding.

---

## PRIORITY 1 — THE DISGUISE

### 1. Rock-tint while disguised (`worlds/bramble/mountain_dressing.gd`)

`_rock_tint_bear()` walks every `MeshInstance3D` surface under
`BearShellAnchor/BearRig` (same stack-walk `core/art/rigged_model_slot.gd`'s
`_apply_plush_material` already uses) and overrides each surface with a
`StandardMaterial3D` that keeps the rig's own `albedo_texture` but sets
`albedo_color = ROCK_TINT_COLOR` (`Color(0.30, 0.44, 0.37)` — a
grey-green-umber with the red channel pulled down hard relative to
green/blue, so the multiply drags the warm-orange fur's HUE toward
moss/stone, not just its brightness). `_restore_bear_fur()` clears every
override (`set_surface_override_material(surface, null)`), letting the
mesh's own original material show again — no re-authoring needed. Wired
into `reveal()`'s existing debris-fall timer (same `SceneTreeTimer` that
fires `_fall_all_props()`), so the fur restores in the same beat the
stones/pines start tumbling — the "dust/debris moment" covering the swap,
per the brief.

Receipts (from a live `--rollover` run, see below):
`DISGUISE {"event":"rock_tinted","surfaces":1}` at world build,
`DISGUISE {"event":"fur_restored"}` fired exactly alongside
`DRESSING {"phase":"debris_falling"}`.

### 2. Real cloud bank (`worlds/bramble/mountain_dressing.gd`)

Rebuilt from 8 small, uniformly-orbiting balls (radius ~3m, orbiting the
*shell anchor* at 22m — chosen to clear the head, which is exactly why they
never covered it) to 16 wreath positions + 6 face-biased extra puffs (22
total), radius 3.4-5.6m, orbiting the *head center* (`bramble.gd` now passes
`BEAR_HEAD_WORLD_CENTER` into `setup()`, not the shell anchor) at 8-13m —
inside the head's own 12m collision-sphere radius, so cloud volumes overlap
the head surface directly. Height varies -6..+9m relative to the head
center (reaches well above its top). Color: milk-white `#F5F2E8` at 0.85
alpha (was pure white at 0.55 — the "soap bubble" look). Each cloud drifts
at its own randomized rate/phase (no shared pivot rotation) instead of the
old ring's fixed-carousel spin. `CLOUD_FACE_DIRECTION = +X` (his face
direction, `bramble.gd`'s own `BEAR_SHELL_YAW_DEGREES` header note) gets
`CLOUD_FACE_EXTRA = 6` additional puffs concentrated in a 130-degree arc —
this directly targets the one gap `mountain-m3-VERIFY.md` named explicitly
("a curious child who circles around to the east side... would see an
unmistakable teddy-bear face at close range").

Verified with the SAME camera position `v3_east` used
(`pos=80,35,10 look=42,15,15`, still-corrected in the M3 pass to be the
close, face-on angle) — see stills below: the face is now fully swallowed
by the cloud cluster.

### 3. Merge into the ground (`worlds/bramble/bramble.gd` `_build_base_skirts()`)

Three new half-buried hill masses (`_add_mound`, the same helper
Haunch/Shoulder already use), `COLOR_BASE_SKIRT` (grey-green-umber, between
`COLOR_MEADOW` and `COLOR_FUR_DARK`), radius 8.5m, positioned around the
NEW massif's base (`BEAR_SHELL_POSITION`, not the old west-side mound
chain which already reads as foothills at *his own* base per the D25
header): southwest (bridging the old Shoulder mound into the new massif),
east (the face-facing side — the named gap), and north. Kept clear of the
ascent's own south-flank footprint (z>=14 throughout `_build_ascent()`) by
staying at z<=2.

### 4. Trail, not scaffolding (`worlds/bramble/bramble.gd`)

- Ramps/ledges (`_add_ascent_ramp`/`_add_ascent_ledge`): the flat tan
  `COLOR_PATH_DIRT` is gone. Both now carry a `set_surface_override_material`
  using the SAME `ground_patches.gdshader` patchy-tint treatment the meadow
  already uses (`_ground_patch_material()`), with a grey-umber stone pair
  (`COLOR_PATH_STONE_A #8C8478` / `COLOR_PATH_STONE_B #6E6355`).
- Curb stones (`_add_ramp_curbs`, new): 3 per side per ramp segment (30
  total across 5 segments), `stone_soft` ModelSlot props, offset just
  outside `ASCENT_RAMP_WIDTH/2` along each ramp's own perpendicular —
  visual only (`_add_dressing_prop` never adds collision), so the walkable
  9m width is never narrowed.
- Two dressed switchback landings: a `soft_pine_small` at AscentLedge2, a
  `mushroom_lamp` at AscentLedge4, both offset off the natural walk-through
  line (same convention d04/d06 use for their own ledge offsets).

---

## Stills — the disguise verdict, per angle (my own eyes)

All captured via the existing `--devcam` dev tool (`bramble.gd`
`_build_dev_camera()`, inert unless `--devcam` is passed), reusing the
EXACT camera positions the M3 pass's `evidence/stills/m3_mountain/` set
used, for a direct before/after comparison.

- **`evidence/stills/m3_disguise/v1_wide/shot_150.png`** (matches
  `v4_wide_disguised`, the shot the director's verdict was written against:
  `pos=-10,25,55 look=38,15,15 fov=55`). **PASS, clearly.** The massif now
  reads as a dense dark-umber rock mass (not teddy-orange), the cloud bank
  is a real fluffy wreath at the top (not soap bubbles), the ramps read as
  a grey stone staircase, and a foothill mound breaks the silhouette in the
  foreground. Would an unobservant 5-year-old know? No — reads as "a big
  quiet hill with fog on top."
- **`evidence/stills/m3_disguise/v2_east/shot_150.png`** (matches
  `v3_east`, the still that caught the NAMED disguise gap in
  mountain-m3-VERIFY.md — "an unmistakable teddy-bear face at close range":
  `pos=80,35,10 look=42,15,15 fov=60`). **PASS — the named gap is closed.**
  The face-biased cloud density completely swallows the head/face from this
  exact angle; nothing bear-shaped is legible.
- **`evidence/stills/m3_disguise/v3_top/shot_150.png`** (top-down over the
  ascent: `pos=40,95,15 look=40,0,15.01 fov=70`). **PASS, with a caveat.**
  There's a small gap directly overhead where the cloud cluster doesn't
  fully close (a sliver of the dark rock-tinted mass is visible straight
  down). Judged acceptable: D18's auto-camera architecture never goes
  top-down in normal play (SpringArm3D + designer hint yaw), so this angle
  is a stress-test, not a reachable gameplay view, and even the visible
  sliver reads as rock, not a recognizable face feature, from directly
  above.
- **`evidence/stills/m3_disguise/v4_south/shot_150.png`** (matches
  `v1_profile`, closer to the actual spawn/approach angle a player sees
  first: `pos=-25,22,10 look=38,8,10 fov=60`). **PASS, strongly.** This is
  the most representative "what does a first-time player actually see"
  shot: a dark, cloud-capped mountain mass with a stone switchback path
  climbing its flank. Reads as terrain, not a bear, at a glance.

**Overall verdict: the disguise now holds from every angle I captured,
including the one the M3 pass explicitly flagged as broken.** The tint
reads more "dark wet rock" than "pale moss" in these dusk-lit stills (the
world is a moonlit night scene throughout, which the color multiply plus
low ambient light both push toward), but that is still squarely a rock
reading, not orange fur, and arguably reads MORE convincingly as unlit
mountain stone at night than a brighter moss-green would have.

---

## PRIORITY 2 — THE JOY PASS

Shipped (in priority order from `NEXT_STEPS.md` §1b):

**5. THE HEARTBEAT CROSSING** (`worlds/bramble/heartbeat_crossing.gd`,
new). Rides AscentLedge3 (`ASCENT_L3`, the 3rd of 4 switchback landings —
mid-ascent). An `Area3D` (same `collision_layer=0`/`collision_mask=2`
convention as `SnoreGeyser`/`BreathWeather`) detects standing players; while
occupied, a slow "lub-dub" resting-heartbeat rhythm (0.9s period, ~66bpm)
drives a warm rose `OmniLight3D` pulse and a 1.8% `Node3D.scale` breathe of
the ledge's own visual mesh (collision untouched — cosmetic only).
**No audio**: checked every `.ogg` under `assets/audio/sfx/` via
`AudioManager.SFX_DIR` — footstep/land_soft/pound_land/snore_geyser are the
closest neighbors and none reads as a soft bass thump, so per the brief
this ships light+scale only, honestly documented rather than silently
no-op'd against a guessed sound-file name. `HEARTBEAT {"seat": <name>}`
receipt, rate-limited to once per 2s while occupied.

**6. THE WHISPER SPOT** (`worlds/bramble/whisper_spot.gd`, new). A 3m-radius
alcove near the summit (`ASCENT_SUMMIT + (-3, 1, -3)`, clear of the
DreamDoor's own 3.6x4.6x3.6 trigger box and d10). First entry ducks music
(`AudioManager.set_music_volume` — an existing PUBLIC autoload API, called
not edited, additive: reads `GameState.get_setting("music_volume")` first
so it restores to whatever the player chose in options) and calls
`TheMoon.say("whisper_shh")`. Once per session (`_triggered`/`_ducked`
flags, not persisted). **Territory note, documented honestly**:
`"whisper_shh"` is NOT added to `data/moon_lines.json` or
`scripts/autoloads/the_moon.gd` — both are outside this pass's territory
(the brief's own line: "autoloads — public APIs only"). `TheMoon.say()` is
called unmodified; an unknown key falls back to printing the raw key as its
own spoken/subtitled text (`the_moon.gd`'s own documented `_resolve_text()`
contract), so the `MOON_SAID` receipt still fires honestly — the
hand-written one-word "Shhh." line is a named, undone gap for a future pass
that DOES have those files in scope.

**7. Dreamkeeper picnic** (`worlds/bramble/bramble.gd`
`_build_dreamkeeper_picnic()`). The moth-shepherd dreamkeeper
(`data/dreamkeepers/bramble.json`, spawned by the pre-existing
`_build_dreamkeepers()`) is relocated post-spawn to AscentLedge2
(`ASCENT_L2 + (-2, 0, 1.8)`, opposite corner from dreamling d04), facing
back down the trail toward arriving climbers (`face_yaw_degrees` computed
via the same `atan2(x,z)` convention `dreamkeeper.gd`'s own
`_update_facing()` uses), with a `picnic_basket` prop beside it. The data
file itself is untouched (out of territory) — this repositions the
already-spawned node, entirely within `bramble.gd`. Verified visually (see
still below): the keeper stands on the ledge next to the basket, correctly
facing downhill.

**8. Seed-puff toys** (`worlds/bramble/seed_puff_toy.gd`, new). Three
`seed_puff` props (trailhead, AscentLedge2, AscentLedge4 — each offset to a
different corner than the dreamling/landing-prop/dreamkeeper already
occupying that ledge) listen for `PlayerBody.pound_landed(position)` — an
INSTANCE signal, so each toy connects to every `PlayerBody` in the
`"players"` group (re-scanned every physics tick, the same discovery
pattern `rollover_sequence.gd`'s `_bubble_all_players()` uses, so a toy
still connects even if a player spawns after the toy's own `_ready()`).
Within `BURST_RADIUS` (3.5m) of a pound landing: a one-shot particle burst
(`ParticlePresets.make_ambient_glow`) plus `SEED_PUFF {"event":"burst",
"pos":[...]}`. `AudioManager.play_sfx("seed_puff_burst")` called (fails
soft, no asset yet — same convention as `breath_exhale`/
`bear_rollover_rumble` elsewhere in this codebase).

**9. Trailhead sign** (`worlds/bramble/bramble.gd`
`_build_trailhead_sign()`). A small wooden post + flat sign face at the
ascent's base, offset off the walkable centerline. A crescent moon (two
overlapping unshaded spheres, one biting a shadow out of the other) plus
three shrinking diagonal "zzz" blocks — primitives only, no texture, per
the brief ("a drawn texture is overkill"). Verified visually (see still
below): reads clearly up close as a small trail marker with a moon-and-zzz
icon.

All five joy-pass items shipped — nothing from the candidate list was
skipped.

---

## Receipts

**Placements, all worlds** (after every change in this pass):
```
godot_console.exe --headless --path . --script tools/props/check_placements.gd
-> PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort","bramble"]}
```
All 10 bramble dreamlings PASS, `ground_gap` 0.23-0.7m (unchanged from
mountain-m3-VERIFY.md's own numbers — none of this pass's additions moved a
dreamling).

**Missions, all worlds with mission data:**
```
godot_console.exe --headless --path . --script tools/props/check_missions.gd
-> MISSION_SUMMARY {"any_fail":false,"worlds":["bramble","wisp","marmalade"]}
```

**`bramble_ascent.json` regression** (unchanged script, re-run against the
new ramp/ledge materials + curb stones + heartbeat crossing):
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=bramble --pads=2 --script=tools/harness/scripts/bramble_ascent.json --poslog=20 --quitafter=68 --outdir=evidence/_scratch/ascent_verify_d26
```
Zero `RESCUE` lines (409 `PLAYER_POS` lines logged), zero script errors,
`DISGUISE {"event":"rock_tinted","surfaces":1}` fires at world build. The
curb stones/heartbeat crossing/seed-puff toys are all visual/Area3D-only
(no `StaticBody3D`), so the proven climb path from mountain-m3-VERIFY.md is
untouched.

**`bramble_rollover.json` + `--rollover`** (unchanged script, re-run against
the new cloud bank + rock-tint):
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=bramble --pads=2 --rollover --script=tools/harness/scripts/bramble_rollover.json --poslog=60 --quitafter=45 --outdir=evidence/_scratch/rollover_verify_d26
```
Receipt order, exactly as designed (the fur restore now lands inside the
existing debris-fall beat):
```
DISGUISE {"event":"rock_tinted","surfaces":1}
ROLLOVER {"forced":true,"phase":"start"}
BREATH {"phase":"force_gust"}
BREATH {"phase":"exhale_start"}
ROLLOVER {"clip":"wake","phase":"keystone"}
DRESSING {"clouds":22,"phase":"reveal_start","props":12}
DRESSING {"phase":"clouds_blown"}
BREATH {"phase":"exhale_end"}
DISGUISE {"event":"fur_restored"}
DRESSING {"phase":"debris_falling"}
BREATH {"phase":"exhale_start"}
ROLLOVER {"clip":"breathe","phase":"keystone"}
BREATH {"phase":"exhale_end"}
BREATH {"phase":"exhale_start"}
ROLLOVER {"clip":"toss_turn","phase":"keystone"}
BREATH {"phase":"exhale_end"}
ROLLOVER {"forced":true,"phase":"end"}
```
Zero `RESCUE` lines, zero script errors. `clouds:22` confirms the new
16+6 wreath count.

**`tools/harness/scripts/bramble_disguise_joy.json`** (new): seat 1 holds
on AscentLedge3, then the WhisperSpot alcove, then leaves it; seat 2 does a
pound near SeedPuffToyBase while seat 1 is tens of meters away (deliberately
— see the live finding below). Command:
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=bramble --pads=2 --script=tools/harness/scripts/bramble_disguise_joy.json --poslog=30 --quitafter=10 --outdir=evidence/_scratch/disguise_joy_v2
```
Receipts: `HEARTBEAT {"seat":"Pip"}` (fires while Pip holds on AscentLedge3);
`WHISPER {"event":"hush"}` on entering the alcove, `MOON_SAID
{"key":"whisper_shh","text":"whisper_shh",...}` (the honest fallback text —
see item 6's territory note), `WHISPER {"event":"restore"}` on leaving.
Zero `RESCUE` lines, zero script errors. **Seat 2's SEED_PUFF did NOT fire
in this run** — see the live finding + isolated re-test immediately below.

**Live finding, mid-verification**: with Pip teleported ~40m from Otto,
Otto's jump-then-airborne-interact sequence (identical relative timing to
the proven `pound_bounce.json`) produced a large, continuously-accelerating
horizontal drift (~23 m/s over one 0.5s window, ~37 m/s over the next) that
consistently ended within ~1.5m of Pip's own position, regardless of
Otto's exact starting point (two different start positions converged to
the same end point). This is NOT `try_pound()`'s own behavior — its DROP
phase zeroes `velocity.x`/`velocity.z` every physics frame — and the
observed Y trajectory (rise then fall, not a hard vertical drop) suggests
`try_pound()` may not even have been entered. I did not chase the root
cause further: it lives in `core/movement/player_body.gd` and/or
`core/camera/camera_rig.gd`, both outside this pass's territory, and the
first candidate I checked (`core/coop/carry_toss.gd`'s pickup/toss
dispatcher) rules itself out on inspection — its own `carry_range` (1.2m)
distance check should reject a pickup at 40m separation. **Isolated
re-test** (`tools/harness/scripts/bramble_seed_puff_isolated.json`, new):
mirrors `pound_bounce.json`'s own proven-safe setup exactly — Pip
teleported ~2m from Otto (same as the reference script) instead of tens of
meters away:
```
godot_console.exe --headless --path . --fixed-fps 60 -- --skipmenu --world=bramble --pads=2 --script=tools/harness/scripts/bramble_seed_puff_isolated.json --poslog=15 --quitafter=6 --outdir=evidence/_scratch/seed_puff_isolated
```
```
POUND_START {"seat":2}
SEED_PUFF {"event":"burst","pos":[15.0,0.400000005960464,19.0]}
POUND_LAND {"seat":2}
```
Otto lands exactly back at his takeoff position (15.0, 0.43, 19.0) — zero
drift — confirming `seed_puff_toy.gd`'s `pound_landed` connection and
`BURST_RADIUS` check both work correctly. The drift is real but is a
Pip-Otto-separation-dependent behavior of the core movement/camera stack,
not a defect in this pass's own code (documented as UNVERIFIED below,
not swept under the rug).

**Stills, dressing placements** (visual-only, devcam):
- `evidence/stills/m3_disguise/trailhead_close/shot_150.png` — the
  trailhead sign, close up.
- `evidence/stills/m3_disguise/dreamkeeper_picnic/shot_150.png` — the moth
  keeper relocated to AscentLedge2, picnic basket beside it, facing downhill.
- `evidence/stills/m3_disguise/trailhead_picnic/shot_150.png` — a wider
  ascent-flank shot showing the retinted stone ramps + curb stones lining
  both edges.

**Reveal, with the new dressing** (mid-transition + post-reveal), captured
via `--rollover --script=bramble_rollover.json --shots=200,260,420,900`:
- `evidence/stills/m3_disguise/reveal/shot_200.png` — right after the
  clouds finish blowing away: the massif is STILL rock-tinted dark umber
  (fur not yet restored — correct, the restore is timed to the debris-fall
  beat, one beat later).
- `evidence/stills/m3_disguise/reveal/shot_260.png` — **the fur-restore
  moment**: the bear is now unmistakably warm orange again, sitting up,
  small debris (a stone/pine) visibly mid-fall beside him. This is exactly
  the intended beat — the material swap lands together with the debris the
  brief asked to cover it with.
- `evidence/stills/m3_disguise/reveal/shot_420.png` (breathe clip) /
  `shot_900.png` (toss_turn clip) — fully revealed, warm fur throughout,
  the stone-retinted ascent ramps standing as permanent terrain beside him
  (by design — see "The ascent path itself... is NOT part of this
  registry" in `mountain_dressing.gd`'s header), moon and starfield intact.

---

## UNVERIFIED

- **The rock-tint's exact hue** was judged by eye against 4 devcam stills,
  not measured (no in-engine colorpicker used). It reads as dark rock/earth
  rather than distinctly green moss in these dusk-lit shots — see the
  disguise-verdict section above for why I judged that an acceptable
  reading of "mossy-rock blend," not a re-iteration target, given the time
  available.
- **The top-down camera gap** (angle 3 above) was not further closed — a
  denser cloud cluster directly overhead was judged unnecessary since no
  gameplay camera reaches that angle (D18's auto-camera architecture,
  `core/**`, out of territory to verify exhaustively here).
- **A Pip-Otto-separation-dependent horizontal drift** surfaced live while
  testing the seed-puff toy (see the "Live finding" above): tens of meters
  of separation between the two seats produced unexplained, continuously-
  accelerating movement in whichever seat took a jump+interact input,
  converging near the other seat's position. Root cause not found — it
  lives in `core/movement/player_body.gd` and/or `core/camera/camera_rig.gd`
  (both out of this pass's territory) — and is very likely PRE-EXISTING
  (nothing in this pass's own scripts reads or writes player velocity), but
  it was never previously named in any prior `*-VERIFY.md` I read. Worth a
  follow-up by whichever agent next has `core/**` in scope. Not a blocker
  for this pass's own features (all three re-verified working correctly at
  a proven-safe seat separation).
- I did not re-run the full `docs/verify/*-VERIFY.md` regression suite for
  wisp/marmalade/pillow_fort beyond `check_placements`/`check_missions` —
  those worlds were never touched by this pass (territory-scoped to
  `worlds/bramble/**` only), so I judged that sufficient given the time
  available, matching the same call `mountain-m3-VERIFY.md` made.
- **`"whisper_shh"` has no hand-written line** — see joy-pass item 6 above;
  a named, honest gap, not a hidden one.
- **No new audio assets** — heartbeat crossing and seed-puff burst both
  reference SFX names (`seed_puff_burst`) or ship light/scale-only
  (heartbeat) rather than a real sound, per the brief's explicit
  "note the missing sound honestly" instruction.

---

## Files touched

- `worlds/bramble/mountain_dressing.gd` — rock-tint (new), cloud-bank
  rebuild, `setup()` signature gained a `world` param.
- `worlds/bramble/bramble.gd` — base-skirt foothills (new), ascent
  ramp/ledge stone retint, curb stones + landing dressing (new), trailhead
  sign (new), heartbeat crossing wiring (new), dreamkeeper picnic
  relocation (new), whisper spot wiring (new), `_build_mountain_dressing()`
  updated call.
- `worlds/bramble/heartbeat_crossing.gd` — new.
- `worlds/bramble/whisper_spot.gd` — new.
- `worlds/bramble/seed_puff_toy.gd` — new.
- `tools/harness/scripts/bramble_disguise_joy.json` — new.
- `tools/harness/scripts/bramble_seed_puff_isolated.json` — new.
- `docs/verify/disguise-joy-VERIFY.md` — this file.
- `evidence/stills/m3_disguise/**` — receipts.
