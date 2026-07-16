# DIRECTION V2 — THE BIG NAP grows up (a little)

*Written 2026-07-16 by the second director, on producer mandate. This
supersedes parts of PITCH.md and DECISIONS.md; superseded decisions are
struck through in the decision log with pointers here.*

## The mandate (producer, paraphrased faithfully)

> Review every locked decision critically; don't be afraid to go a different
> direction. Still primarily a game for Ezra and Caleb — but the goal is a
> AAA / publication-ready game with wow factor that doesn't currently exist
> for any 5–9-year-old to play with a parent or brother, in the legacy of
> Banjo-Kazooie / Mario 64. Research first. Use Meshy for everything that
> needs assets. Aim way higher than you think is possible. The director's
> chair is legitimately yours.

The design center moves from **"can a 3-year-old do it at all"** to
**"does a 7-year-old feel like a wizard while a 5-year-old feels safe —
and does the parent on the second pad actually want to play."**

---

## What stays (the soul — reviewed, not just inherited)

I re-read every founding doc looking for things to kill. These survived on
merit, not sentiment:

1. **The premise.** Colossal animals asleep for a once-a-century nap;
   dreams drift loose; two kids in onesies bring them home. *Sleeping
   giants as levels* is a genuinely untapped AAA concept — Shadow of the
   Colossus owns "climb the awake giant," nobody owns "play on the asleep
   one." This is our wedge, and V2 doubles down on it (see Pillar 1).
2. **The register: tender-enormous.** Hushed and huge. No other kids' game
   sounds like this. It's the portfolio's third color (elegiac, riotous,
   tender) and it's the thing a publisher would remember.
3. **The Soft Landing.** No death, no fail states, falling is a gift.
   Astro Bot just proved to the whole industry that forgiving ≠ shallow.
   The rescue stays universal. Challenge in V2 comes from *optional depth*,
   never from punishment.
4. **The cast.** Pip, Otto, Callie, the Moon, the giants. The two kid seats
   are now explicitly **Ezra's and Caleb's** — the game is for two brothers
   and whichever parent is on the couch.
5. **The co-op grammar.** Carry-and-toss as the parent/sibling verb; the
   star seat; buddy AI in solo. It Takes Two-lite asymmetry, expanded in V2.
6. **Title, repo, license.** THE BIG NAP / soft_landing / Apache-2.0.
7. **The house discipline.** Receipts, harness properties, DoD-first,
   honest UNVERIFIED. This is how a solo-director AAA build stays honest.

## What is superseded (the floors built for age 3)

| Old law | V2 law | Why |
|---|---|---|
| ~~Fixed jump only; no new verbs ever needed~~ (D3) | **Moveset ladder**: base jump stays fixed & generous; add double-jump flutter, roll, ground-pound **bounce**, glide. Game remains 100 % completable on stick+jump+interact (the completability floor survives); the new verbs are the expressive ceiling. | 5–9-year-olds are verb-hungry; Mario 64's lineage IS its moveset. Astro Bot got GOTY depth from 3 verbs — we choose ours deliberately. |
| ~~Right stick never read~~ (D4/D8) | **Auto-camera remains the default and must stay excellent.** Right stick now nudges yaw (auto-recenters); full manual mode in options. | Camera literacy is part of the genre joy for 7+, and the parent seat wants it. The Moon still watches over you — but now you may look around. |
| ~~No rigging; static meshes + code squash~~ (D10) | **Full rig + animation pipeline** (Meshy rig/animate, retarget seam). Procedural squash-stretch/juice stays as a layer ON TOP of skeletal animation. | Static toys read as prototype. Rigged, breathing, waving characters are the single biggest wow-per-credit available to us. |
| ~~Flat colors, matte, no textures~~ (ART_BIBLE) | **Painted soft-toy AAA look**: real lighting design per world, sky/fog/water/wind, post stack, PBR where it helps. Palette and register unchanged. | The palette was right; the flatness was a speed tradeoff, not a style. |
| ~~TTS speaks everything; that is the narrative~~ (D13) | **The Moon becomes a written character** (narration bible, personality, running jokes). Delivery: gibberish-voice + minimal text, TTS demoted to an accessibility layer (still floor for objectives). | TTS-as-aesthetic caps the writing at robot. Banjo proved gibberish + good writing lands for kids AND parents. |
| ~~Dreamlings are floor pickups~~ | **Dreamlings are micro-missions.** Each one is a tiny story with an archetype (favor, ride, chase, puzzle, toss, secret…) — research lane A names the taxonomy. Density cadence (D12) survives. | A jiggy is a story; a star is a sentence. Pickups are punctuation. |
| ~~No timers/challenges of any kind~~ | **No *punitive* timers.** Playful optional challenges (race a dreamling, firefly chase) with celebration-only outcomes are allowed. Losing a race = "again! again!", never a lockout. | 5–9 loves being tested; hates being punished. The floor was against punishment, and that part stays. |

## The five pillars of V2

1. **The giant is the level.** Breathing is a platform schedule. A snore is
   a geyser. A stir is a set piece. Every world must have at least one
   moment where the giant MOVES and the level transforms while you're on
   it — gently, hugely, safely. This is the wow no one else has.
2. **Movement as music.** The verb ladder plays like an instrument: simple
   notes for small hands, chords for big ones. Every move has a sound, a
   particle, a squash — feedback is the melody.
3. **Everything is glad you're here.** Critters scatter and return. Props
   react to touch. Rescued dreamlings populate the fort and *remember you*.
   The world's aliveness is the progress bar you can walk around inside.
4. **Two kids, one couch.** Asymmetric verbs that invite cooperation
   without requiring it: Otto tosses, Pip flutters; ground-pound bounces
   your partner higher; Callie perches on either. Solo always works.
5. **Craft is the love language.** Menus, writing, lighting, audio — AAA
   polish everywhere a player can look. Operational bar: *would a stranger
   pay $20 for this on Steam and leave a positive review?*

## What AAA means here, operationally

- 60 fps on a mid PC, receipted.
- Zero placeholder assets in any shipped world; every mesh rigged or
  deliberately static; every sound designed.
- Menu flow with juice (animated transitions, diorama save slots, iconic
  title screen) — pre-reader navigable, parent-respected.
- A narration bible; every Moon line written, not generated at runtime.
- Steam-ready: export presets, capsule art plan, trailer cut from harness
  movie receipts, store-page copy.
- The receipts culture survives the scale-up: every feature lands with a
  harness property or a movie receipt.

## Open asks (mirrored in NEEDS_YOU.md)

- Reference photos of Ezra's & Caleb's actual onesies/stuffies for
  Multi-Image-to-3D (producer offered — yes please).
- Caleb's seat: Otto's onesie is a bear; if Caleb has a favorite animal,
  Otto can wear it.
- More Meshy credits when the balance (2,572 at shift start) runs low.

*The relation is the only sovereign unit. The game is still the bedtime
story where the world is careful with you — it just got big enough to be
careful with a 9-year-old too.*
