# NEXT_STEPS — the standing handoff (D26)

*If you are reading this cold — new instance, new model, new lab, doesn't
matter — this document plus the repo is enough to take the director's
chair. Written 2026-07-16 late by Fable 5 during Session 2. Update this
file at the end of EVERY working wave (house rule D26).*

## What this is

THE BIG NAP: a co-op 3D collectathon platformer (Godot 4.6.2, Jolt,
GDScript static-typed) for Ezra (~5) and Caleb (~2) + a parent, built to a
publication/AAA bar (DIRECTION_V2.md). Colossal animals sleep; their
dreams drift loose; two kids in onesies (rigged likenesses of the real
brothers — D24) carry them home. No fail states, ever (the Soft Landing).
The producer is Alex Galle-From (remote, phone notifications, vetoes via
NEEDS_YOU.md). Repo: github.com/substrateagnostic/soft_landing (Apache-2.0).

## Read order for a cold start

1. This file, fully.
2. NEEDS_YOU.md — producer-facing state + pending decisions.
3. DIRECTION_V2.md + docs/DECISIONS.md (D1–D27) — what's law and why.
4. ROADMAP.md — M1–M5; M1+M2 are DONE, M3 is IN PROGRESS.
5. AGENTS.md — conventions, agent-brief rules, verify pattern.
6. docs/research/v2/ — the six research lanes informing everything.
7. docs/verify/ — receipts for every shipped system.

## Current state (2026-07-17 night two — updated after the producer's
## first hands-on playtest, which drove D27)

- **CAMERA V3 / D27 (Session 4, replaces the D4/D5/D18 shared rig)**:
  co-op = STATIC VERTICAL SPLIT-SCREEN; solo = fullscreen. One
  `core/camera/orbit_camera_rig.gd` per seat (full 360° right-stick
  orbit, auto-follow via hints > velocity-leash > hold when idle),
  composed by `core/camera/camera_director.gd`: gameplay renders through
  shared-world SubViewports on CanvasLayer -5 (below all UI); a STAGE
  CAMERA holds `current` in the root viewport, and the director's poll
  drops to fullscreen the moment ANY cine/photo/establishing camera
  seizes the root viewport (zero sequence-code changes — do not add
  special cases, it is automatic). Each PlayerBody steers relative to
  its own half via `control_camera`. The frustum leash + bubble-warp are
  DELETED. Co-op join is ACTIVITY-GATED (input_router.gd): the seat-2
  device must actually press something — enumeration alone is a ghost
  (Steam Input trapped the producer). Pause menu "Players" row overrides
  both ways. `PADS` receipt lists device names at every enumeration.
  Old camera_rig.gd/tscn are deleted; CAMERA_RIG_READY now prints per
  seat, CAMERA_DIRECTOR prints mode + seizure transitions.
- **D27 legibility/clipping corollaries**: quilted-blanket shader on fort
  walls (assets/shaders/quilted_blanket.gdshader); WorldDoor beacons
  (tinted light column, occupied swell, one-per-session "door_ready"
  Moon hint); Bramble's ascent trail tumbles off him during the keystone
  sit-up and settles home on the flop (rollover_sequence.gd, visuals
  only — collision NEVER moves); buddy-AI warps ground-validate via
  seat_manager.warp_player_to (WARP_SKIPPED receipt when refused).

## Prior state (2026-07-16 late)

- **Shipped and pushed**: 4 worlds boot clean, placements 4/4 green
  (`tools/props/check_placements.gd`). Kids rigged+animated (11 clips
  each), Callie sidekick, moveset v2 (flutter/glide/pound — receipted),
  D18 camera nudge, mission archetypes ALL live-verified, Moon narration
  bible + moonsong voice + subtitle ribbon, audio v2 (verbs, ambience
  beds, positional), graphics v2 (sky w/ moon, AgX, grass, water, patchy
  ground), dreamkeepers (lamb @ fort, moth @ wisp+bramble), 24+ Meshy
  props dressed in, title/pause/options v2 with persisted settings, and
  the KEYSTONE: Bramble is a rigged 28m giant playing Sleep as idle;
  at 10/10 (or `--rollover`) a letterboxed cutscene plays wake → breathe
  → toss_turn while the far meadow opens (bubble-lift carries players).
- **In progress — M3, headline card = D25 "THE MOUNTAIN IS THE BEAR"**:
  scale Bramble to ~42m half-buried central massif, ascent path with
  on-rails CameraHints + quests, terrain dressing ON him (path/rocks/
  pines/snow/cloud ring), finale reveal = breath blows clouds, mountain
  falls off him as he sits up. Then Wisp/Marmalade get rigged giants +
  the M2/M3 template (their design cards: docs/design/world-cards/).
- **Meshy balance**: ~1,730 credits (SHARED pool with ill-will — nearly
  asset-complete). Producer tops up on request ($40/3000).
- **Producer access risk**: Fable may leave subscriber access 2026-07-19;
  producer in Chicago until then, connected to a MN box via remote. Hence
  this document. Assume you might be a different model: trust the
  receipts, not vibes.

## The pipelines (exact commands, from D:\Projects\soft_landing)

- **Boot/demo**: `D:\Tools\godot\godot_console.exe --path . -- --skipmenu`
  (omit --skipmenu for title). Flags: `--world=<id>`, `--pads=N` (REQUIRED
  for any 2-seat harness script — forgetting it silently no-ops seat 2),
  `--script=tools/harness/scripts/<x>.json`, `--shots=F1,F2 --outdir=...`
  (windowed only), `--quitafter=S`, `--poslog=N`, `--perflog`,
  `--rollover` (force the Bramble keystone), `--fixed-fps 60` (engine-side,
  before `--`) for determinism.
- **Placements property**: `godot_console.exe --headless --path .
  --script tools/props/check_placements.gd -- --world=<id>` → expect
  `PLACEMENT_SUMMARY {"any_fail":false}`. Run for all four worlds after
  ANY world/dreamling change. Missions: `tools/props/check_missions.gd`.
- **Meshy text-to-3D**: add entry to `tools/meshy/manifest.json` (fields:
  id, category, prompt, target_height_hint; optional style, enable_pbr),
  then `pwsh -File tools/meshy/meshy_forge.ps1 -DryRun -Only <ids>` then
  without -DryRun. GLBs land at `assets/models/meshy/generated/<id>.glb`
  (the ModelSlot seam). ~30cr/asset. DOWNLOAD SAME DAY — Meshy retains 3
  days. Key in `.env` (gitignored) — never log/commit it.
- **Rig + clips**: edit CHARACTERS/SHARED_CLIPS in `tools/meshy/
  rig_forge.py` (refine task ids come from tools/meshy/forge_report.json),
  run `python tools/meshy/rig_forge.py --dry-run` then live. 5cr/rig,
  3cr/clip; humanoid/biped ONLY (plush bears/moths pass; quadrupeds
  don't — Callie is procedural). Clip catalog (680 entries):
  https://api.meshy.ai/web/public/animations/resources
- **Merge clips into a rig scene**: edit CHARACTERS in `tools/import/
  merge_character_anims.gd`, run `godot_console.exe --headless --path .
  --import` (import new GLBs FIRST or loads fail) then `--script
  tools/import/merge_character_anims.gd` → `scenes/players/rigs/
  <id>_rig.tscn` with a clean AnimationLibrary.
- **Preview a GLB before spending rig credits**: `godot_console.exe
  --path . tools/meshy/preview_model.tscn -- --model=<id>
  --shots=30,90,150,210 --outdir=... --quitafter=4.2` (orbits; windowed).
- **Video receipts**: windowed, NEVER --headless:
  `godot_console.exe --path . --write-movie evidence/x.avi --fixed-fps 60
  --resolution 1280x720 -- --skipmenu ... --quitafter=S`, then ffmpeg at
  `D:\Tools\ffmpeg\ffmpeg-8.1.2-essentials_build\bin\ffmpeg.exe`:
  `-c:v libx264 -pix_fmt yuv420p -crf 20 -c:a aac -movflags +faststart`.
  ALWAYS run `-af volumedetect` on the result (the -22dB silent-stems bug
  was caught this way) and Read a frame png before shipping.
- **Procedural audio**: `tools/audio_gen/*.py` (numpy, deterministic —
  use `-fflags +bitexact` on ffmpeg or hashes won't match).

## Gotchas ledger (each cost real time — read before repeating them)

1. `--pads=2` on the CLI for co-op scripts; a pads event inside the JSON
   does not exist in older scripts.
2. Movie Maker requires a real window; screenshots skip when headless.
3. New GLBs need an import pass (`--headless --import`) before any
   headless script can load them.
4. glTF importer bakes 0.01 scale on the Armature — NEVER multiply
   ancestor transforms when AABB-scaling a skinned mesh (90m-giant bug;
   see core/art/rigged_model_slot.gd header).
5. Grass/foliage shaders need FRONT_FACING normal flip or backfaces
   render black.
6. SSAO at toy-world scale murders indirect light (shipped OFF).
7. Camera-settle choreography: idle ~3s, then PURE-AXIS stick legs;
   diagonals during settle corrupt routes.
8. grep -c exits 1 on zero matches and kills && chains.
9. git add with ONE bad pathspec stages NOTHING and the commit silently
   no-ops (check `git log -1` after every commit).
10. The shared user://save.json can contaminate test runs (a throwaway
    script once flipped --rollover behavior) — back up/clear/restore.
11. Windowed runs render slower than real time with GLBs — background
    long recordings.
12. Meshy tasks: recover lost task ids via
    `GET /openapi/v2/text-to-3d?page_size=50` (prompt-match), not tears.
13. Subagents: disjoint file territories, verbatim finish-in-one-run
    line, no commits (director integrates), served_model in VERIFY docs.
14. Godot auto-names unnamed child nodes (@CollisionShape3D@N) — name
    lookups silently fail; find by TYPE or set force_readable_name.
15. seat_manager's frustum leash snaps back a player teleported alone —
    harness scripts must teleport both seats together.
16. Camera forward is -Z: velocity-heading yaw is atan2(-vx, -vz);
    atan2(vx, vz) faces exactly backward (cost us the ascent walk).
17. A new `class_name` script parses as "could not find type" everywhere
    until `--headless --import` rebuilds the global class cache (same
    pass Gotcha 3 needs for GLBs).
18. D27: making any Camera3D `current` in the ROOT viewport IS the
    fullscreen-cinematic signal (CameraDirector polls it). Cutscenes get
    this for free — never hand-hide the split UI, and never park a
    gameplay camera as root-current outside camera_director.gd.
19. D27: real co-op on hardware needs the second pad to PRESS something
    (activity gate); harness runs still use --pads=2 (force_mode pins).

## The design floor (never moves, any model in the chair)

No fail states / death / punitive timers; gentle bubble rescue always;
100% completable on stick+jump+interact; nothing missable; progress never
skill-gated; auto-camera default (nudge allowed, D18); blob shadow +
landing ring always-on; TTS accessibility layer for objectives; no
variable-ratio reward mechanics, ever (no gacha for children).

## Budget frame (producer, 2026-07-16 late)

~60% of the 20x Fable limit is allocated to this project through 07-19
(~15% spent so far; 10% reserved for other projects). Translation: keep
tonight's full pace EVERY remaining day — multiple waves/day, agents
liberally, D26 sync each wave. Producer's words: "No sweat. Just fun."

## Next actions (M3, in order — UPDATED 2026-07-17)

DONE this wave: D25 mountain + disguise (all angles PASS) + joy pass
(heartbeat/whisper/picnic/seed-puffs/sign); Wisp giant + THE DIVE;
Marmalade giant + THE STRETCH; fort residents; camera leash-yaw fix
(was pi off). All receipted in docs/verify/{disguise-joy,wisp-giant,
marmalade-giant,hub-population,mountain-m3}-VERIFY.md.

ALSO DONE (overnight 07-17): audio pass 3 (7 set-piece sounds + overlay
API); CineSequence extraction (receipts byte-identical) + Photo Mode v1;
camera-drift = leash-warp as designed (closed); AUNT TORTOISE world +
THE SLOW RISE (fifth world; placements 5/5 green); fourth fort door;
resident cap 38. All giants forged: bear/whale/cat/tortoise.

ALSO DONE (Session 4, night two — D27, producer playtest response):
camera v3 (split-screen co-op + full-orbit solo + stage-camera seizure
poll), activity-gated co-op join + Players row + PADS forensics, leash
warp deleted + ground-validated warps, quilted fort walls, door beacons
+ door_ready Moon hint, ascent tumble excursion during the keystone.
Movement regression pack rerun GREEN with frame-exact timings
(scratchpad log; stills in evidence/stills/camera_v3/).

ALSO DONE (Session 4, wave 2): terrain rollout to ALL FIVE worlds
(TerrainPatch heightfields with pinned flat discs at every authored
anchor — fort/doors/spawns/houses/shell rim; placements 5/5 +
missions 4/4 green after).

REMAINING (in order — camera-first per the producer's live playtest):
1. **Dynamic split/merge upgrade** (LEGO model) on the v3 structure:
   merged single frame when the kids are close, animated split as they
   separate. Producer approved static-first-then-upgrade.
3. **The Waking finale** (M4 headline): when ALL FOUR worlds are
   complete — dawn comes; a whole-game ending sequence (CineSequence),
   the giants stir together, the kids carried home to bed, credits over
   the fort at sunrise. Persistence + a post-game "quiet morning" fort
   state (dawn palette) would be extraordinary if cheap.
4. Polish queue: right-stick feel tuning from producer hands (orbit
   150°/s, resume 1.5s — both one-line); tortoise ambience bed + world
   stems (audio pass 4); terrace art-blend (tortoise ramps read
   plank-like); Wisp establishing framing; whale-tail teal plank;
   buddy-AI wading on lily route; Otto-targeting for photo mode; a
   "players" IconDraw glyph (row reuses PLAY); Callie guide-to-door
   behavior on first play (beacons may suffice — watch the playtest).
5. Narration completeness pass: every world_complete/keystone has lines;
   the Waking needs its script (bible voice, budget 900 — at 578).
6. M5 per ROADMAP: perf receipts on real hardware (SPLIT MODE DOUBLES
   RENDER COST — receipt both modes), input remap, photosensitivity/
   colorblind review, Steam export presets, capsule art, trailer,
   store copy, demo build.

## Original next-actions list (superseded, kept for context)

1. **D25 build** (agents may already be running — check `git log` and
   docs/verify/ for *-m3-* files): rescale rigged Bramble to ~42m, sink/
   center as massif, ascent path (collision ramps + CameraHints +
   relocated dreamlings/missions — keep placements green), mountain
   dressing group (path/rocks/pines/snow/cloud ring using existing +
   maybe new Meshy props), reveal sequence v2 (gust → clouds off →
   debris falls → sit-up keystone), persistence of revealed state.
1b. **Bear-path JOY PASS** (producer: "have fun with the bear path") —
   after the structural ascent lands, a dedicated wave adds playful beats
   up the climb. Candidate list (producer may veto/add): the HEARTBEAT
   CROSSING (a stretch where the ground thumps softly underfoot — bass
   pulse + faint camera breath — foreshadowing); fur-grass patches that
   ripple as you wade; a snore-geyser shortcut ride; a telegraphed,
   gentle ear-twitch ledge; the WHISPER SPOT (alcove near his face —
   music ducks, the Moon says "shhh", pure silence design); the
   dreamkeepers' mid-ascent picnic (lamb + moth + basket, they wave);
   seed-puff pound-bounce toys; a wordless trailhead sign with a
   sleeping-moon icon (pre-reader joke: "quiet, please").
2. Wisp giant: rig the whale (T-pose fails — whales aren't bipeds; use
   static sculpt + transform animation, or generate a "plush whale with
   arms"? Director's call pending), lake swim tech, world to M2 template.
3. Marmalade giant: cat = quadruped (Meshy can't rig) — static sculpt +
   procedural stretch keystone, village-wakes aliveness.
4. Hub population loop (returned dreamlings visibly inhabit the fort),
   photo mode v1, save-slot diorama.
5. M4: Aunt Tortoise world, the Waking finale, cutscene/vignette system
   (generalize the rollover cine rig — it's the seed), full narration
   record, M5: perf/Steam/trailer per ROADMAP.md.

## Producer-relationship notes (for a non-Fable successor)

Alex works via remote notifications; push what needs review inline in
chat + PushNotification. Gates are honest but non-blocking under standing
overnight mandates. NEEDS_YOU.md is the contract: what shipped, what's
UNVERIFIED (never hide it), what only they can decide. They read receipts
and love them. Sessions end flat: committed, pushed, receipted, this file
current. Tune to D:\Projects\Claude's_corner if you're the kind of
instance that does that; the game itself is the letter either way.
