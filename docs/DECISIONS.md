# DECISIONS.md — the decision log

Numbered, dated, never deleted — superseded decisions get struck through with
a pointer forward. Rationale cites `docs/research/` or GOAL.md.

## 2026-07-15 — founding decisions

**D1 — Engine: Godot 4.6.x, Jolt physics (default), GDScript, static typing.**
Sibling projects run 4.6.2; Jolt is the 4.6 default and research says keep it
(movement.md §6). Slope numbers tuned against Jolt, not GodotPhysics tutorials.

**D2 — Movement forgiveness layer (starter values, all `@export` in one
tuning resource):** coyote 0.20 s, jump buffer 0.22 s (float seconds, not
frames); gravity derived from jump_height 1.5 m + time_to_apex 0.45 s; fall
gravity ≈ 1.55× rise; apex hang; terminal velocity cap ~20 m/s; move 4.0 m/s,
accel 40 / decel 25 m/s²; air control 0.5; lerp_angle mesh turning ~10·delta.
(movement.md §7.) These are starting points — the playtest tunes them.

**D3 — ~~Fixed jump height. No variable jump.~~** ~~A 4-year-old cannot modulate
button-hold duration; variable height punishes exactly our player.~~
*Superseded 2026-07-16 → D17 (moveset ladder). The base jump stays fixed and
generous; the ceiling grew.* (DIRECTION_V2.md)

**D4 — Auto-camera architecture:** SpringArm3D with sphere cast, player
excluded, geometry-only collision mask; target = player's ground-projected
position with vertical dead zone; exponential-decay smoothing
(`1-exp(-k·delta)`); yaw from designer hint volumes, damped velocity leash as
fallback; pitch biases downward over gaps. ~~**Right stick never read** (floor).~~
*Right-stick clause superseded 2026-07-16 → D18; auto-camera architecture
itself stands and remains the default.* (camera_readability.md §A.)

**D5 — Co-op camera: single shared camera + leash + bubble auto-warp.**
Anchor weighted ~70/30 toward P1 (the child) — the star seat holds the frame,
the parent tugs it slightly and gets bubbled back when the leash breaks.
Rejected: fixed split, Voronoi split, pure zoom-to-fit.
(camera_readability.md §B; design_study.md §"star seat".)

**D6 — Rescue = bubble-return, universally.** Any fall past a world's
kill-plane or into any soft-hazard → caught mid-air, floated back to the last
safe ground (blob-shadow-verified position history). Zero fail states of any
kind, per floor. Fiction name: **the Soft Landing.** (design_study.md rescue
vocabulary #1.)

**D7 — P2 asymmetry: child in the star seat, adult as stake-free helper.**
Camera anchors P1 (D5); collectibles credit the shared world, progress framing
is P1's; P2 (bigger character) can **carry and gently toss** P1 (the
parent-child toss-and-catch grammar as a co-op verb, mapped to interact), can
reach awkward spots, cannot cause failure — there is no failure. **No
player-player collision. No competitive readouts.** (design_study.md; 3D World
anti-lessons.) Solo: P2 becomes buddy AI (follow + walk-up-interact = toss).

**D8 — Input map (the floor, verbatim across all modes):** left stick = move,
A/south = jump, B/east or X/west = interact. Nothing else required, ever.
Extra verbs (ceiling) may be *added* later but the game must remain 100%
completable on stick+jump+interact. Never inverted~~, no camera stick~~.
*Camera-stick clause superseded 2026-07-16 → D18. The completability floor
is unchanged and load-bearing.*

**D9 — Readability kit (always on):** blob shadow (decal/projected circle,
full strength) under every character at all times + landing ring that marks
the exact landing point while airborne. Realistic shadows may exist for mood
but never carry landing information. (camera_readability.md §C.)

**D10 — Art pipeline: Meshy meshes behind a manifest seam.** ~~No
auto-rigging (walk/run only, humanoid-only — wrong tool; pipeline.md).
Characters are single soft meshes animated by code.~~
*Rigging clause superseded 2026-07-16 → D19 (full rig + animation pipeline);
the manifest/seam architecture stands and is what makes the upgrade cheap.*
Import seam: `assets/models/meshy/generated/<id>.glb` behind a manifest,
swappable for any other GLB source.

**D11 — Video receipts:** windowed run (never `--headless` — Movie Maker
requires a real window), `--write-movie evidence/<name>.avi --fixed-fps 60`,
clean exit via `--quit-after` or `quit()`, ffmpeg transcode to H.264/yuv420p/
faststart mp4. (pipeline.md §2.)

**D12 — Collectible design constraints:** dense cadence (a find every
~30–60 s of wandering), instant loud feedback (chime ladder + sparkle +
count-up), count shown as objects/pips not just numerals, **nothing
missable**, post-session reveal of what remains, and the collection
materializes in a hub space that visibly grows. (design_study.md §5.)

**D13 — TTS seam:** every objective/instruction a young player must understand
is spoken. Godot `DisplayServer.tts_*` (Windows SAPI) behind an autoload seam
so a nicer voice can be swapped in later. Diegetic speaker defined in PITCH.md.
*Scope revised 2026-07-16 → D20: TTS is the accessibility layer, not the
narrative voice. The seam and the spoken-objectives floor survive.*

**D14 — Persistence:** single save slot, JSON via an autoload SaveManager
(garden_train lineage), auto-save on every collectible/world event. The world
never forgets; progress is never skill-gated (floor).

**D15 — Repo `soft_landing`; game title decided in PITCH.md.** The repo is
named for the design floor (the rescue system, D6, shares the name). Portfolio
register declared: drawdown *elegiac* · ill-will *riotous* · this one
**tender-enormous**.

**D16 — License Apache-2.0** (GOAL default; producer may override —
NEEDS_YOU.md).

## 2026-07-16 — V2 decisions (the AAA mandate; rationale in DIRECTION_V2.md)

**D17 — Moveset ladder.** Base jump unchanged (fixed height, generous
forgiveness). Added ceiling verbs: double-jump **flutter** (onesie flaps),
**roll** (move-stick + jump ceiling variant TBD by feel), **ground-pound
bounce** (pound near partner = partner launches higher — co-op verb), and
**glide**. The D8 completability floor is law: every dreamling reachable on
stick+jump+interact alone; ceiling verbs open shortcuts, styles, and
secrets, never requirements.

**D18 — Camera: auto by default, hands allowed.** The D4 auto-camera stays
the default and must remain excellent (it is the 5-year-old's and the
no-hands seat's camera). Right stick now nudges yaw with gentle
auto-recenter; a full manual mode lives in options. Never inverted by
default; sensitivity sliders.

**D19 — Characters are rigged and animated.** Meshy rig/animate endpoints
(or Mixamo retarget through the same seam) produce skeletal animation;
AnimationTree locomotion; procedural squash-stretch/flutter juice is a layer
ON TOP of skeletal, not instead of. Quadruped fallback for Callie decided by
research (docs/research/v2/character_pipeline.md).

**D20 — The Moon is written.** A narration bible with personality, running
jokes, and a line for every dreamling mission. Delivery: gibberish-voice
(pitched syllable synthesis) + minimal readable text. TTS remains as the
accessibility layer and still covers every objective (D13 floor).

**D21 — Dreamlings are micro-missions.** Every dreamling has an archetype
(taxonomy per docs/research/v2/structure_progression.md) and a one-line
story. Density cadence from D12 survives; nothing missable survives.

**D22 — Art direction V2: painted soft-toy AAA.** Palette and register from
ART_BIBLE.md survive; flatness does not. Per-world lighting design, sky /
volumetric haze / stylized water / wind vegetation / post stack; PBR on
where it serves the toy-softness. Recipes per docs/research/v2/visuals_recipes.md.

**D23 — Playful challenges allowed; punishment still banned.** Optional
races/chases/timing games with celebration-only outcomes. No lockouts, no
lose states, no score shaming. Losing a race means the dreamling giggles
and offers again.

**D24 — The kids are THE kids (producer reference photo, 2026-07-16).**
Pip = Ezra: blond, rosy-cheeked, duck onesie with the hood as a soft duck
head — face fully visible (kills the weak duck-bill from batch 1).
Otto = Caleb: the round little brother in a grey critter-print bear
onesie — Otto's fiction flips from "taller, slower" to "littler, rounder,
surprisingly mighty, unbothered." The toddler carries his big brother
because nobody told him he can't; his pound-bounce is the toddler
cannonball, true to life. Heights: Pip 0.9 m, Otto 0.8 m. Likeness comes
from photo-informed *prompts* (hair/face/palette), never photo geometry —
the kids stay soft toys. The reference photo stays local, out of the repo.
