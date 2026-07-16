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

**D3 — Fixed jump height. No variable jump.** A 4-year-old cannot modulate
button-hold duration; variable height punishes exactly our player.
(movement.md §3.) The code path stays stubbed for a possible later ceiling.

**D4 — Auto-camera architecture:** SpringArm3D with sphere cast, player
excluded, geometry-only collision mask; target = player's ground-projected
position with vertical dead zone; exponential-decay smoothing
(`1-exp(-k·delta)`); yaw from designer hint volumes, damped velocity leash as
fallback; pitch biases downward over gaps. **Right stick never read** (floor).
(camera_readability.md §A; Kirby FL precedent.)

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
completable on stick+jump+interact. Never inverted, no camera stick.

**D9 — Readability kit (always on):** blob shadow (decal/projected circle,
full strength) under every character at all times + landing ring that marks
the exact landing point while airborne. Realistic shadows may exist for mood
but never carry landing information. (camera_readability.md §C.)

**D10 — Art pipeline: Meshy static meshes + procedural squash-and-stretch.**
No auto-rigging (walk/run only, humanoid-only — wrong tool; pipeline.md).
Characters are single soft meshes animated by code (bounce, tilt, squash,
flutter). Import seam: `assets/models/meshy/generated/<id>.glb` behind a
manifest, swappable for any other GLB source.

**D11 — Video receipts:** windowed run (never `--headless` — Movie Maker
requires a real window), `--write-movie evidence/<name>.avi --fixed-fps 60`,
clean exit via `--quit-after` or `quit()`, ffmpeg transcode to H.264/yuv420p/
faststart mp4. (pipeline.md §2.)

**D12 — Collectible design constraints:** dense cadence (a find every
~30–60 s of wandering), instant loud feedback (chime ladder + sparkle +
count-up), count shown as objects/pips not just numerals, **nothing
missable**, post-session reveal of what remains, and the collection
materializes in a hub space that visibly grows. (design_study.md §5.)

**D13 — TTS seam:** every objective/instruction a 4-year-old must understand
is spoken. Godot `DisplayServer.tts_*` (Windows SAPI) behind an autoload seam
so a nicer voice can be swapped in later. Diegetic speaker defined in PITCH.md.

**D14 — Persistence:** single save slot, JSON via an autoload SaveManager
(garden_train lineage), auto-save on every collectible/world event. The world
never forgets; progress is never skill-gated (floor).

**D15 — Repo `soft_landing`; game title decided in PITCH.md.** The repo is
named for the design floor (the rescue system, D6, shares the name). Portfolio
register declared: drawdown *elegiac* · ill-will *riotous* · this one
**tender-enormous**.

**D16 — License Apache-2.0** (GOAL default; producer may override —
NEEDS_YOU.md).
