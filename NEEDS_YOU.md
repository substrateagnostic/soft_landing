# NEEDS YOU — soft_landing / THE BIG NAP
*Updated at the end of every session. What exists, where the evidence is,
one cold demo command, what's unverified, and what only you can decide.*

## Session 2, second wave — M2: BRAMBLE THE PROOF WORLD (same night)

- **THE ROLL-OVER is real**: return all 10 of Bramble's dreams (or run with
  `--rollover` to preview) and the bear settles in his sleep — every kid on
  a moving part gets caught in a soft bubble and floated to the FAR MEADOW
  on his other side, now dressed with real art (berry bushes, moon daisies,
  a picnic waiting). The rescue system IS the ride. Video in chat.
- **Breath-becomes-weather**: every ~44s his long exhale becomes a soft
  updraft by the snout — an elevator on the bear's own rhythm (receipted:
  4.75m → 11.49m lift after the agent caught its own too-weak updraft).
- **All 10 Bramble dreamlings authored** (2 race, 2 ride, 1 shy, 1 duet,
  1 geyser-flourish, 3 open) — and every archetype is now LIVE-VERIFIED
  including duet's solo fallback at exactly 10.0s. Moon budget: 541/900.
- **The game has a full soundscape**: flutter/glide/pound have voices
  (pillow-thump, not drum), footsteps, world ambience beds that follow you,
  dreamlings giggle positionally, props boop when poked, menus tick.
- **Dreamkeepers live here now**: a sleepy lamb guest at the fort (wakes,
  faces you, waves — zero dialogue, presence only), the moth shepherd on
  Wisp's shore and in Bramble's meadow. They cheer from afar when any
  dream comes home.
- **All four worlds dressed** with the 15-asset batch (pines, mushroom
  lamps, stump doors, moon daisies...). Placements 4/4 green throughout.
- Credits after the night: ~1,840 of the shared pool.

### ⛔ New decisions pending (M2)
1. **Roll-over feel** — 8s settle, bubble-lift pacing: watch the video,
   tell me in feelings.
2. **Dreamkeeper register** — lamb/moth are wordless by design (the Moon
   talks, the world gestures). Veto if you want them chattier.

## Session 2 — FOUNDATION NIGHT (2026-07-16, the V2 mandate)

### What happened (all pushed to github.com/substrateagnostic/soft_landing)
- **DIRECTION_V2 + ROADMAP (M1→M5)**: every locked decision re-litigated;
  soul kept, age-3 floors superseded (D17–D24 in docs/DECISIONS.md). Six
  research lanes in docs/research/v2/. Month-plus plan to Steam-ready.
- **THE BOYS ARE IN THE GAME (D24)**: Pip = Ezra (blond fringe under the
  duck hood, beak as cap brim), Otto = Caleb (sleepy round-faced toddler in
  the grey critter-print bear onesie, now properly the LITTLE one — he
  still carries and tosses his big brother, receipted). Both fully rigged
  with 11 clips each (skip/carry included). First roll, both keepers, from
  your one reference photo — likeness via prompt only, photo stayed local.
- **Moveset v2 (D17)**: flutter double-jump, hold-to-glide, pound-bounce
  (Otto's shockwave launches Pip 1.5× jump height — receipts in
  tools/harness/scripts/{flutter_gap,glide_descent,pound_bounce}.json).
  Floor intact: everything completable on stick+jump+interact.
- **Camera (D18)**: right stick now gently nudges (auto-recenters);
  manual mode + sensitivity in the pause options, persisted.
- **The Moon is WRITTEN (D20)**: narration bible (~410 words, every line
  authored), moonsong gibberish voice (deterministic synth syllables),
  subtitle ribbon, voice modes incl. TTS accessibility default.
- **Dreamlings are micro-missions (D21)**: race/ride/shy/duet archetypes
  live (bramble d01/d02 race — receipts show them zipping and caught);
  duet has a generous solo fallback. 30/30 placements stayed green.
- **Graphics v1+v2 (D22)**: painted sky with THE MOON IN FRAME (fort +
  bramble), AgX + grade, glow, fog, sage lawn grass (root-caused
  FRONT_FACING bug), patchy ground tints, warm bramble, stylized lake
  water, fireflies/motes, landing puffs. Before/after:
  evidence/stills/v2_before vs v2_after2.
- **Aliveness v1**: touch-react props, ambient moths/mice with
  scatter-and-return, cheer gesture when a dream comes home.
- **Producer orders executed**: lantern remeshed (PBR glow). Otto reroll
  resolved by D24 (he's Caleb now).

### ⛔ Decisions pending (all vetoable, none blocking)
1. **D24 casting veto window** — if Ezra/Caleb likenesses miss, say so;
   old models remain on disk. Stills: evidence/stills/art_v2/,
   evidence/stills/v2_swap/.
2. **Verb feel** — flutter/glide/pound numbers are all @export; tell me in
   feelings after a couch session.
3. **Credits** — balance ~2,330 of the shared pool; M2 (Bramble proof
   world) budgets ~450. Top-up whenever convenient ($40/3000 noted).
4. **Viola stems** whenever — placeholder synths still fine.

### Cold demo command (from D:\Projects\soft_landing)
```
D:\Tools\godot\godot_console.exe --path . -- --skipmenu
```
(Or without --skipmenu for the new title screen. 1–2 pads or WASD+Space+E.
In the air: tap jump again = flutter, hold jump = glide, tap E = pound.)

### UNVERIFIED / known-open (honest)
- Right-stick camera FEEL (receipted mechanically; needs human hands).
- Moonsong/TTS audible quality (needs ears; movies don't capture TTS).
- Duet/shy/ride mission choreography live-verified only for race; others
  reasoned from code (docs/verify/aliveness-v2-VERIFY.md).
- Wisp/marmalade moon-in-frame placement; dreamling bloom is subtle.
- Plush character shader kept OPT-IN (muddier than imported material at
  distance — A/B in evidence/stills/v2_plush vs v2_swap).
- "2 resources still in use at exit" engine warning, intermittent,
  cosmetic, unattributed.
- Real-hardware fps receipt still owed (remote-session numbers are
  presentation artifacts).

### M2 preview (next session, per ROADMAP)
Bramble to shippable: bear's breath-becomes-weather + the roll-over set
piece, 10 authored micro-missions, dreamkeeper NPCs, art batch 2 (~15
assets, ~450 credits), audio v2, performance pass.
