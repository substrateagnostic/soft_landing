# ROADMAP — THE BIG NAP, from lovely prototype to publication

*Written 2026-07-16 under DIRECTION_V2. Five milestones, each with a
producer gate. Research citations: docs/research/v2/. The plan assumes
autonomous director sessions between gates, per the standing mandate.*

## Where we are

Four worlds boot with 30/30 placements green; movement/camera/rescue/co-op
proven; Meshy pipeline proven; audio skeleton live; Gates 1–2 passed,
Gate 3 provisional. What it is: a beautiful, tuned, *static* prototype for
a 4-year-old. What it must become: a AAA-standard game a 5–9-year-old and
their grown-up would choose over Astro Bot on a Friday night.

## Research verdicts that shape everything (docs/research/v2/)

- **Small and deep beats big and thin.** Banjo-Tooie's own designer says
  scope-creep broke it; Astro Bot's director shipped "a small game" and won
  GOTY. Four worlds is ENOUGH. We make each one dense, alive, transformed.
- **Every dreamling is a story** — six mission archetypes (favor, ride,
  race, puzzle, toss/co-op, secret), never a floor pickup. Something
  rewarding every 20–30 s of traversal.
- **One signature body-function per giant** (Zelda Divine Beast pattern):
  the level IS the creature, and once per world the creature MOVES.
- **Few verbs, deep polish** (Astro Bot): the moveset ladder is hold-vs-tap
  on existing buttons, no timing-chained inputs for small hands.
- **The look is assemblable from proven primitives**: AgX + saturation
  grade, soft glow, CC0 absorption water, wind-swayed MultiMesh grass,
  fresnel rim + fake SSS, fireflies/motes everywhere, **no outlines**.
  No shipped Godot title documents this pastel-toy register — we get to be
  the precedent.
- **Rig once, clips are cheap** (5 cr/rig, 3 cr/clip, 680-clip library),
  BoneMap retarget seam keeps Mixamo open as a deeper well.
- **The Moon narrates structural beats only** (LittleBigPlanet law, anti-
  Book-of-Love), gibberish syllable voice + minimal text, < 5,000 words
  total, TTS as accessibility layer.
- **No variable-ratio reward mechanics anywhere** (the one Astro Bot
  pattern we refuse: the Gatcha Lab).

## M1 — FOUNDATION NIGHT (tonight, 2026-07-16)

*Everything below lands tonight; receipts before sunrise. This milestone is
the goal of record for this session.*

| Lane | Ships |
|---|---|
| Characters | Pip + Otto rigged & animated (idle/walk/run/jump/fall/wave/cheer/pickup/sleep/dance + Pip's skip, Otto's carry) via Meshy rig+animate; AnimationTree locomotion; Callie procedural life (SpringBone tail/ears, LookAt head, breathing) |
| Graphics v1 | Global look pass: painted night sky w/ big moon + drifting clouds, AgX + grade, glow, volumetric haze, fresnel-rim character material, fireflies/dream-motes/footstep particles, wind-swayed grass system, stylized lake water (Wisp), per-world lighting rigs |
| Gameplay v1 | Moveset ladder v1 (flutter double-jump = tap-again, glide = hold jump in air, pound-bounce = tap interact in air, launching partners higher); dreamling micro-mission framework (archetype-tagged, data-driven); touch-react component on props; ambient critters v1 (moths, meadow mice — 2-3 behaviors) |
| UI/Writing v1 | Title screen v2, pause/options w/ camera + audio + accessibility, save-slot vignettes; NARRATION_BIBLE.md (the Moon's voice, every current beat written); gibberish-voice v0 (pitched syllables) behind TheMoon seam |
| Producer orders | Lantern remesh ✅ (30 cr, PBR glow) |

**Gate M1 (async):** tour video + stills in chat; producer veto window on
all of it. No blocking.

## M2 — BRAMBLE, THE PROOF WORLD (week of 7/17)

One world taken all the way to shippable, so every later world has a
template and the vertical slice is honest.

- Bramble's signature body-function: **the breath becomes weather** — on a
  slow cycle his exhale rolls fog and floats seeds/kids upward; once per
  visit (scripted, gentle) he **rolls over**: the hillside rotates, paths
  rearrange, the far meadow opens. The 10/10 reward already promised.
- 10 dreamlings → 10 authored micro-missions across all six archetypes
  (incl. one 60–90 s two-kid choreographed set piece: the snore-geyser
  duet — one kid times the snore, the other rides it).
- NPC dreamkeepers v1: 2–3 wordless characters (a lost lamb, a night-moth
  shepherd) with Meshy models + retargeted clips.
- Art batch 2 (~15 assets): meadow flora, burrow props, dreamkeepers.
- Audio v2: Bramble stem set matched to new set pieces; positional creature
  sounds; silence design. (Viola stems slot in whenever recorded.)
- Performance pass 1: 60 fps receipt on mid-PC settings with all v1
  graphics on.

**Gate M2 (couch):** first Ezra/Caleb-ready build. Feel re-tune from
producer + kids. This is the gate where "fun for a real child" gets its
first honest receipt.

## M3 — THE MOUNTAIN IS THE BEAR + THE OTHER GIANTS (started 7/16, D25)

- **Headline card — D25 (producer direction):** Bramble scales to ~42 m
  and becomes the central massif, half-buried, breathing subtly. An
  on-rails-ish ascent path (authored collision ramps + CameraHint
  framing + quests/dreamkeepers on the way up) leads to the summit —
  his ear, where dreams come home. He is dressed AS terrain (path,
  rocks, pines, snow caps, cloud ring); the 10/10 finale becomes THE
  REVEAL: his breath blows the clouds away, the mountain falls off him
  as he sits up, and a child who never suspected sees the bear. Reveal
  persists across saves.
- **Wisp**: swimming (Meshy swim clips exist), the lake becomes playable
  water; signature function: **the dive** — Wisp settles into the lake and
  the shoreline floods gently into new routes (soft Landing catches
  everyone, always). Giant treatment: whale is non-biped — static sculpt
  + transform/procedural animation (director's call at build time).
- **Marmalade**: the village wakes at night — market stalls, lamplighter
  mice, rooftop routes; signature function: **the stretch** — the cat
  stretches and the rooftops shift like plates. Giant treatment: quadruped
  — static sculpt + procedural stretch keystone.
- Hub population loop: every returned dreamling takes up residence in the
  fort (visible, wave-able, nameable); fort growth stages 4–6.
- Photo mode v1 (family feature; Astro Bot-minimal).
- Art batch 3 (~20 assets). Producer buys credits as needed (~1,500 cr
  estimated for M3–M4 combined).

**Gate M3 (async):** world tour videos, kid-session notes from M2 applied.

## M4 — THE FOURTH GIANT & THE ENDING (week of 7/31)

- **Aunt Tortoise** (garden over her shell) built on the M2 template.
- The finale: **the Waking** — when every dream is home, dawn comes; the
  giants stir, stand, and carry the kids home to bed. Rolling credits over
  the fort at sunrise. (The only "ending" a bedtime game should have.)
- Cutscene/vignette system (in-engine, letterboxed, skippable).
- Complete narration bible recorded through the gibberish voice; TTS
  accessibility pass across every objective.
- Save slots as fort dioramas; menu polish final.

**Gate M4 (couch):** content-complete playtest with the kids.

## M5 — SHIP SHAPE (week of 8/7+)

- Performance/QA sweep: fps receipts on all worlds, memory, load times;
  input remap; colorblind & photosensitivity review; parental volume/
  session options.
- Steam packaging: export presets, capsule art (Meshy renders + palette),
  store copy, trailer cut from harness movie receipts, demo build.
- Localization scaffold (string tables; the game is <5,000 words by law).
- Public repo hygiene: README with screenshots, LICENSE, CONTRIBUTING.

**Gate M5:** producer decides what "release" means (Steam page live? demo
to friends? itch build?). The game is publication-ready either way.

## Budgets & discipline

- **Meshy**: ~2,500 cr in tank at M1 start; M1 spend ≈ 110 cr (lantern 30 +
  rigs/clips ~76). M2 ≈ 450. M3–M4 ≈ 1,500 (producer topped-up). Every
  batch through the manifest forge with receipts; download same-day
  (3-day retention).
- **The floor never moves**: no fail states, no punitive timers, gentle
  rescue everywhere, completable on stick+jump+interact, nothing missable,
  progress never skill-gated.
- **Receipts culture at AAA scale**: every milestone lands with harness
  properties + movie receipts; every agent brief carries the finish-in-one-
  run line; UNVERIFIED stays honest.
