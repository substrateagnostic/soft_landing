# RESEARCH.md — Phase 1 synthesis (2026-07-15)

Four sourced research docs live in `docs/research/`. This file is the
executive synthesis; decisions extracted from it live in `docs/DECISIONS.md`.

| Doc | Scope |
|---|---|
| [research/movement.md](research/movement.md) | CharacterBody3D feel: coyote, buffer, slopes, jump arcs, Jolt |
| [research/camera_readability.md](research/camera_readability.md) | SpringArm3D auto-camera, co-op camera strategies, depth aids for young kids |
| [research/design_study.md](research/design_study.md) | Kirby Forgotten Land, Odyssey Assist Mode, preschool prior art, rescue vocabulary |
| [research/pipeline.md](research/pipeline.md) | Meshy API (July 2026), Godot Movie Maker receipts |

## What the research says, in one page

**Movement.** Forgiveness is a timing layer, not a difficulty setting: coyote
time + jump buffer gated as `(buffer > 0) and (on_floor or coyote > 0)`,
tracked as float seconds. Shipped casual values run 110–180 ms; for a
4-year-old we go wider (0.20 s / 0.22 s). Gravity is derived from
jump_height + time_to_apex, falls faster than it rises, and hangs at the apex
— the single biggest "joy" lever. Variable jump height is *dropped*: it
requires modulated button-holds a preschooler can't perform. Godot 4.6 ships
Jolt as the default 3D physics — keep it, and re-tune slope numbers rather
than trusting GodotPhysics-era tutorials (floor_snap_length 0.4–0.5, constant
speed on slopes, zero snap on the jump frame or jumps get swallowed).

**Camera.** HAL removed player camera control from Kirby and the Forgotten
Land *specifically* to protect novices from two-stick load — the shipped proof
of our design floor. The architecture that reproduces it in Godot: SpringArm3D
(sphere cast, player excluded, geometry-only mask) tracking the player's
ground-projected position inside a vertical dead zone, exponential-decay
smoothing (never `lerp(a, b, speed*delta)`), yaw directed by designer-placed
hint volumes with a damped velocity leash as fallback, pitch biased top-down
over gaps. Right stick: never read.

**Co-op camera.** Single shared camera + generous leash + bubble auto-warp
(Kirby FL model). Fixed split halves the resolution and doubles the confusion;
Voronoi seams disorient young kids; zoom-to-fit shrinks the child's avatar.
The bubble warp structurally erases "I got left behind."

**The rescue vocabulary** (each item traced to a shipped game in
design_study.md): bubble-return on any fall; auto camera; input rounding
("fuzzy landing"); anti-strand warp; no player-player collision; no
competitive scoring; short stages with post-stage reveal; nothing permanently
missable. The P2 pattern: the child sits in the star seat (progress is theirs),
the adult is the high-capability stake-free helper — skill becomes support,
never competition.

**Collectibles.** Dense cadence, loud instant feedback, numbers legible to a
pre-reader (counting IS the joy at 4), and the count must become a *place you
revisit* that visibly grows (Animal Crossing museum → Waddle Dee Town →
Crash Site lineage).

**Pipeline.** Meshy text-to-3D (meshy-6, preview→refine, ~30 credits/prop,
GLB) is proven by the sibling project this month; auto-rig ships only walk/run
and is humanoid-only — useless for platformer verbs, so characters are static
meshes + procedural squash-and-stretch in-engine. Movie Maker requires a real
window (`--headless` breaks it), a clean `--quit-after` exit, and
`--fixed-fps`; transcode MJPEG AVI → H.264 mp4 with ffmpeg for phone review.

## UNVERIFIED rollup (carried from the four docs)
- 3D physics interpolation default state in 4.6 (movement.md) — verify in-project.
- Blob-shadow quantitative studies (thesis PDF + GameAIPro ch.47 didn't
  text-extract); qualitative conclusion multiply corroborated (camera_readability.md).
- Odyssey Assist Mode ledge-grace changes; SMO heart counts are wiki-consensus
  (design_study.md).
- Meshy rate-limit tier names returned inconsistently same-day (pipeline.md);
  5-in-flight batching is safe under every version seen.
