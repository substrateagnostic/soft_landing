# GAME_BRIEF.md — THE BIG NAP (one page, for every subagent)

**What it is:** 3D collectathon platformer, Mario 64 lineage, Godot 4.6.x,
for a 4-year-old (P1) and their parent (P2), two gamepads, one couch.

**Fiction in three sentences:** The great animals are taking their
once-a-century nap, and their dreams (glowing **dreamlings**) have drifted
loose. Two kids in animal onesies — **Pip** (duck, small, P1) and **Otto**
(bear, big, P2) — climb the sleeping giants to carry the dreams home, guided
by **the Moon**, who narrates everything out loud. Nothing can hurt anyone;
if you fall, a dreamling catches you in a bubble — the **Soft Landing**.

**Register:** tender-enormous. Hushed and huge. Dusk pastels, lantern glow,
lullaby viola. The world is big and glad you're small. Never spooky, never
loud, never urgent.

**Pillars (in priority order):**
1. Movement and camera ARE the product. Feel gates content.
2. The rescue is a relationship: every failure-shaped moment resolves as care.
3. Counting is joy: dense collectibles, loud warm feedback, a fort that grows.
4. The parent is a helper, never a rival: no collision, no scores, toss-and-catch.

**The design floor (non-negotiable, from GOAL.md):** no fail states / timers /
death / fall damage — gentle rescue instead; single stick + jump + interact
only (extra verbs are ceiling); auto camera, right stick never read; always-on
blob shadow + landing ring; two players max, one gamepad each, buddy-AI when
solo; TTS for anything a 4-year-old must understand; persistent world, never
skill-gated.

**Key vocabulary (use these names in code comments, scenes, and docs):**
`dreamling` (collectible) · `soft_landing` (rescue system) · `pillow_fort`
(hub) · `bramble` (first world, the bear) · `the_moon` (TTS narrator seam) ·
`star_seat` (P1 camera anchor policy) · `toss` (Otto's carry-throw of Pip).

**Where the law lives:** design floor + conventions → `AGENTS.md`; decisions
D1–D16 → `docs/DECISIONS.md`; full fiction → `PITCH.md`; contracts →
`SPEC.md`; art rules → `ART_BIBLE.md`; acceptance → `DEFINITION_OF_DONE.md`.
