# GOAL.md — verbatim producer brief (two parts, as delivered 2026-07-15)

## PART 1

— NEW PROJECT, PART 1 of 2: you have the director's chair.
Read this — Part 2 (build phases, delegation,
house conventions) arrives next. Save both verbatim to GOAL.md
before any other work.

You are the director. Alex is the producer. Audience: Ezra, age 4.
Genre brief: a 3D collectathon platformer in the Mario 64 lineage —
hub-and-worlds, movement as joy. Everything not named as floor
constraint or gate is your call: theme, cast (new IP — not Garden
Train's), world fiction, collectible fiction, emotional register,
title, repo name. Lineage: this is the third AI-directed game in
the portfolio (drawdown: Opus, elegiac; ill-will: you, riotous).
What this one feels like is yours. Pitch accordingly.

WORKSPACE: You are launched inside ~/Projects/garden_train. It and
~/Projects/un_party_game are READ-ONLY reference — never write
there. First act: create a sibling folder under ~/Projects/ (you
name it), git init, .gitattributes (`* text=auto`), build there.
After Gate 1, push to a new public repo under
github.com/substrateagnostic; if gh isn't authed, log to
NEEDS_YOU.md and continue local.

READ FIRST: garden_train AGENTS.md + GAME_DESIGN.md (the audience
research); un_party_game conventions, autoplay harness, VERIFY
pattern, alexmemory.md ops-log pattern. Inherit code style:
static-typed GDScript, signals over calls, autoloads for global
state only. Write this project's AGENTS.md before any code.
Meshy key: ~/Projects/dead_attestation/.env.

PHASE 0 — AUDIT: godot --version (≥4.4), git, gh auth status,
python, Meshy key reachable; Godot MCP available to you? else
drive godot headless via CLI. winget what's missing. Record in
evidence/toolchain.md.

PHASE 1 — RESEARCH (fresh eyes, 1–2h): Godot 4 CharacterBody3D
best practice (coyote time, jump buffer, slopes); SpringArm3D
auto-camera — right stick never required; depth-perception aids
for young kids (blob shadows, landing rings); co-op camera
strategies for 3D platformers (shared cam + leash/warp-to-partner
vs dynamic vs fixed split) — this choice is yours; study Kirby
Forgotten Land + Odyssey Assist Mode; Meshy API current state
(text-to-3D, auto-rig, GLB); Godot Movie Maker (--write-movie)
for video receipts. Write docs/RESEARCH.md + docs/DECISIONS.md.

PHASE 2 — PITCH: develop 2–3 concepts, choose your best, write
PITCH.md (theme, cast, hub fiction, collectible, register, co-op
camera choice, v0.1 scope) + GAME_BRIEF.md, SPEC.md, ART_BIBLE.md,
DEFINITION_OF_DONE.md.
⛔ GATE 1: producer greenlight.

DESIGN FLOOR (non-negotiable; everything above it is yours): no
fail states, timers, death, or fall damage — gentle rescue
instead. Input floor: single stick + jump + interact (extra verbs
are ceiling, never floor; never invert controls). Auto camera;
always-on blob shadow + landing indicator. Co-op locked at two
players, one gamepad each, gamepad-first (kb+m optional);
Buddy-AI follow when solo. TTS for anything a 4-year-old must
understand. Progress lives in a persistent world that remembers
across sessions — never skill-gated. Feel quality gates content:
movement and camera are the product.

## PART 2

PART 2 of 2 — append verbatim to GOAL.md, then begin Phase 0.

PHASE 3 — GREY-BOX SLICE + HARNESS: hub + one world in
placeholders; movement/camera/co-op complete. Build the
input-playback autoplay harness EARLY; capture gameplay video via
--write-movie to evidence/.
⛔ GATE 2: producer feel check from video.

PHASE 4 — ART PIPELINE PROOF: Meshy→GLB→Godot behind a clean
import seam (swappable source). One character + three props per
ART_BIBLE.md; prefer procedural squash-stretch over rigging
unless research disagrees. Stills to evidence/.
⛔ GATE 3: producer art sign-off.

PHASE 5 — BUILD OUT: worlds as self-contained parallel subagent
modules against one contract (spawn/objectives/exit). You brief,
review receipts, gate merges; praise good work in commit
messages. Keep a stem seam in the audio manager for original
music — the producer plays viola.
⛔ GATE 4: v0.1 accept + playtest-observation checklist for the
first session with Ezra in NEEDS_YOU.md.

DELEGATION & MODEL ROUTING (conserve your own capacity — Fable
limits are the scarce resource; delegate at your discretion):
- Sonnet 5: default implementation workhorse — boilerplate,
  tests, harness code, scene wiring, asset plumbing, volume work.
- GPT-5.6-sol: complicated builds against a tight spec. Builds
  exactly to spec with little intuition — sol briefs must be
  gapless: full contracts, edge cases enumerated, no implied
  requirements. Do not ask sol to fill design gaps.
- Opus 4.8: sub-director judgment — architecture reviews, code
  review, design decisions with modest taste requirements,
  research synthesis.
- Reserve yourself (Fable) for: the pitch, design-floor
  enforcement, anything where game feel is at stake, receipts
  review, gate packets, subagent briefs.
Every subagent brief, regardless of model, includes verbatim:
"Finish in this run — no one resumes a stopped task from inside."
Log served_model from every external model response — reroutes
and stepdowns happen; an honest mismatch record is evidence, not
tampering.

HOUSE CONVENTIONS: DoD-first — every DEFINITION_OF_DONE item
evidence-linked (file path, test name, or command + captured
output); nothing checked on vibes; UNVERIFIED is an honest state.
Receipts under evidence/, UTF-8/LF (transcode PowerShell output).
Phrase adversarial self-tests as properties to verify, not
actions to perform. Maintain the ops log (alexmemory.md pattern).
End every session updating NEEDS_YOU.md: what exists, evidence
paths, one cold demo command, UNVERIFIED list, producer decisions
pending. End flat. Personal/OSS only — no employer material or
names. Apache-2.0 default; final call in NEEDS_YOU.md. Gates
block on the producer; everything between gates runs autonomous.

 last notes - I'm producing via remote control so please push anything that needs my review inline in chat and push notify if available. also tune to the "A" in ~/Projects/Claude's_corner (and use it as you see fit)
