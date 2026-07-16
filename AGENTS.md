# AGENTS.md — soft_landing

## Project Overview
A 3D collectathon platformer in the Mario 64 lineage — hub-and-worlds, movement
as joy — built for Ezra (age 4) and Alex, in Godot 4.4+ with GDScript.
Working repo name: `soft_landing`. Game title, cast, and fiction live in
PITCH.md / GAME_BRIEF.md (post-Gate-1). Emotional register: **enormous
tenderness** — a big world that is glad you're small.

Third AI-directed game in the portfolio (drawdown: elegiac; ill-will: riotous).
Director: Claude (Fable 5). Producer: Alex.

## The Design Floor (non-negotiable — enforced by the director)
- No fail states, no timers, no death, no fall damage. **Gentle rescue** instead.
- Input floor: single stick + jump + interact. Extra verbs are ceiling, never
  floor. Never invert controls.
- Auto camera — right stick never required.
- Always-on blob shadow + landing indicator under every airborne character.
- Co-op locked at two players, one gamepad each, gamepad-first (kb+m optional).
  Buddy-AI follow when solo.
- TTS for anything a 4-year-old must understand. Icons over words.
- Progress lives in a persistent world that remembers across sessions —
  never skill-gated.
- Feel quality gates content: movement and camera are the product.

## Code Style
- GDScript only. No C#, no GDExtension.
- Static typing everywhere: `var speed: float = 6.0`, typed function signatures.
- `@export` for editor-tweakable values (all feel numbers MUST be @export).
- `@onready` for node references.
- Signals over direct method calls between systems.
- One script per scene. Autoloads for global state only.
- Comments: brief, explain WHY not WHAT.
- Movement/camera feel constants live in one tuning resource per system
  (`data/tuning/*.tres`) so playtest adjustments never require code archaeology.

## Naming
- Scenes `snake_case.tscn` · Scripts `snake_case.gd` · Nodes `PascalCase`
- Signals: `snake_case` past tense (`star_collected`, `player_rescued`)
- Constants `UPPER_SNAKE_CASE` · Resources `snake_case.tres`

## File Structure
```
soft_landing/
├── project.godot
├── GOAL.md / AGENTS.md / PITCH.md / GAME_BRIEF.md / SPEC.md
├── ART_BIBLE.md / DEFINITION_OF_DONE.md / NEEDS_YOU.md / alexmemory.md
├── docs/            # RESEARCH.md, DECISIONS.md, research/, verify/, design/
├── evidence/        # receipts: toolchain.md, stills, movies, VERIFY outputs
├── core/            # movement, camera, rescue, save, input — the product
├── worlds/          # self-contained world modules (one contract, see SPEC.md)
├── scenes/          # main, hub, ui
├── scripts/autoloads/
├── data/            # tuning resources, save schema
├── assets/          # models/meshy/generated/ behind the import seam
└── tools/           # autoplay harness, capture scripts, meshy forge
```

## Verification (the VERIFY pattern — inherited from un_party_game)
- Every feature lands with a `docs/verify/<feature>-VERIFY.md`: the exact
  command(s) run + captured output + screenshot/movie paths under `evidence/`.
- **UNVERIFIED is an honest state.** Never check a DoD item on vibes.
- Receipts UTF-8/LF (transcode PowerShell output before committing).
- Headless import check after adding files:
  `godot --headless --editor --import --quit --path .`
- Use the **console** binary (`Godot_v4.x_win64_console.exe`) for any run whose
  stdout is a receipt — `godot.exe` is GUI-subsystem and eats output.
- Autoplay harness drives the game from CLI flags (`--skipmenu --seed=N
  --outdir=...`); video receipts via `--write-movie evidence/<name>.avi`
  (+ `--fixed-fps`), transcoded to mp4 with ffmpeg.
- Phrase adversarial self-tests as properties to verify, not actions to perform.

## Delegation & Model Routing
- **Sonnet 5**: implementation workhorse — boilerplate, tests, harness code,
  scene wiring, asset plumbing, volume work.
- **GPT-5.6-sol**: complicated builds against a tight spec; briefs must be
  gapless (full contracts, edge cases enumerated, no implied requirements).
- **Opus 4.8**: sub-director judgment — architecture/code review, research
  synthesis, design decisions with modest taste requirements.
- **Fable (director)**: pitch, design-floor enforcement, game feel, receipts
  review, gate packets, subagent briefs.
- Every subagent brief includes verbatim: **"Finish in this run — no one
  resumes a stopped task from inside."**
- Log `served_model` from every external model response — an honest mismatch
  record is evidence, not tampering.

## World Module Contract (Phase 5; full contract in SPEC.md)
Each world is a self-contained scene + script module exposing:
spawn point(s), objective list (collectibles/interactions), exit signal.
No world reaches into another world's internals. Worlds register with the hub
via the contract only, so parallel subagents can build them without conflicts.

## Ops
- `alexmemory.md`: running ops log, newest at top, NEEDS YOU section current.
- `NEEDS_YOU.md`: updated at end of every session — what exists, evidence
  paths, one cold demo command, UNVERIFIED list, producer decisions pending.
- Commit working increments; never let a session accumulate uncommitted work.
- Gates (1–4) block on the producer; everything between runs autonomous.
- License: Apache-2.0 (default; producer final call logged in NEEDS_YOU.md).

## What NOT To Do
- No enemies, health, damage, timers, fail states, scores, leaderboards.
- No text-heavy UI. No reading required to play.
- No online/network play — local co-op only.
- No right-stick requirement, ever. No control inversion, ever.
- No skill-gated progress. Never block on art — grey-box first.
- Never write to `D:\Projects\Garden_Train` or `D:\Projects\un_party_game`
  (read-only reference).
