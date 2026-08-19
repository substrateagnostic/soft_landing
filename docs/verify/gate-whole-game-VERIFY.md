# gate-whole-game-VERIFY — the B12 whole-game gate bench (D30)

*Opened 2026-08-19 on the dev laptop (see evidence/toolchain.md addendum;
golem is the couch box per D30 — every perf number here is ADVISORY-ONLY).
This is the evidence packet for the first fired bench of the BENCH BOOK
era: the game is end-to-end complete through D29; this gate audits the
WHOLE of it. Status legend follows DEFINITION_OF_DONE.md. Sections marked
PENDING are being filled by running lanes this session — a PENDING here is
honest, not decorative.*

## (a) Machine + HEAD

- Repo: C:\Users\agall\projects\soft_landing (Syncthing share with golem)
- HEAD at packet open: f340fdf (D30 sync)
- Godot 4.6.2.stable.official.71f334935 (winget console binary)
- Canary: `check_placements.gd --world=bramble` →
  `PLACEMENT_SUMMARY {"any_fail":false}` (this machine, this HEAD)

## (b) DoD reconciliation (line by line)

DONE — full table + verbatim property outputs:
`docs/verify/gate-dod-reconciliation.md` (reconciliation lane, Sonnet,
HEAD f340fdf). Counts: Gate 1 5/5 [x] confirmed · Gate 2 14/14 [x]
confirmed · Gate 3: 2 flipped [x] (Meshy seam incl. zero-GLB fallback;
served_model/credits 120/120), 2 [U] (ART_BIBLE comparison never
written; squash-stretch clip owed), sign-off open · Gate 4: 5 [U] with
named closers, full-session video in capture this session, perf
golem-only (D30), accept open · Standing properties: no-fail-state,
never-skill-gated, never-writes-outside-repo all FRESH-GREEN this pass;
input-floor sufficiency [U] (no continuous floor-only run exists).
Placements 5/5 + missions 4/4 green, this machine, this HEAD.

New defects surfaced by the reconciliation (bench-billable):
- **REAL-4 unfixed** (`code-review-opus-2026-07-16.md`): door interact
  fires alongside carry/return on the same press
  (`worlds/common/world_door.gd:149-154`, no dwell/ownership guard) —
  co-op confusion bug, ~40 days old, siblings from the same review all
  fixed.
- Two competing playtest-checklist artifacts (full draft in
  docs/design/ vs the condensed §(e) couch question) — merge owed into
  NEEDS_YOU.md (the Gate-4 line's literal instruction).
- `art-pipeline-VERIFY.md` lacks the served_model self-attestation
  header (doc hygiene only).

## (c) The gate reel — full-session evidence on current HEAD

DONE — `evidence/gate_whole_game_reel.mp4`: **3:37**, 1920×1080
(instrument note: the `--resolution 1280x720` flag is overridden by the
project window settings in windowed mode — all segs consistent, concat
safe), mean −16.7 dB / **max −0.5 dB (near-clipping transient —
flagged for the lullaby lane)**. Frame battery (72 frames @ 1/3s):
`evidence/_scratch/gate_reel/battery/`. Save hygiene held throughout
(real save verified restored, 304 bytes, byte-content re-checked).

Segment record (all fresh, HEAD 4705718-era, windowed, --fixed-fps 60;
receipts in `evidence/_scratch/gate_reel/segN*.stdout.log` + per-seg
events.jsonl):

| seg | content | receipts | exit |
|---|---|---|---|
| 1 title | attract, Moon welcome, "press Ⓐ" | eyes-pass PNG | 0 |
| 2b door+collect | fort → DEV-teleport into BrambleDoor → interact → bramble; walk toward d01 | DOOR bramble · WORLD_READY bramble · **d01 is a RACE — race primed, Moon race line; no collect (see note)** | 139 |
| 2c co-op | live split-screen, both seats walk+jump | force_mode(2) COOP · 4 jumped EVTs | 0 |
| 3b return | DEV-teleport to D25 summit door | **collected d10 + dream_returned d10 + MOON dream_home** (d10 is open-archetype) | 139 |
| 4 rescue | door switch + 2 falls | RESCUE ×2, correct fort placement | 139 |
| 5 fort | seeded save, populated fort | FORT_RESIDENT_SPAWNED ×6 + greets | 0 |
| 6 roll-over | --rollover keystone | full chain: gust→wake→22 clouds→20 tumble pieces | 139 |
| 7 rise | --rise keystone | full chain: reward_ground_solid→petals→risen→settled | 139 |
| 8 waking | --waking finale | all phases; credits photos:8; closing card on screen (eyes-pass) | 139 |

Route-rot finding (paid): the July scripts finale_home.json and
gate2_return.json no longer reproduce on current HEAD (terrain rollout
+ camera-v3 steering moved choreography ground truth; gate2_return
teleports to the pre-D25 ear). Fix: three NEW scripts
(`gate_reel_{door_collect,coop,summit_return}.json`) — the July scripts
stay frozen as their own eras' receipts. seg2b's "collected d01"
expectation was authored wrong (d01 is a race archetype whose mission
suppresses magnetism — the footage of the race PRIMING is honest
gameplay); the collect beat is receipted in seg3b instead.

**THE TEARDOWN SEGFAULT (real, repro'd, bench-billable):** 6 of 11
windowed runs exited 139 (SIGSEGV) at engine teardown, ALWAYS after
content completed and movies finalized (seg4's AVI verified complete
1200/1200 frames). Probes (same rescue script, no Movie Maker):
headless → **exit 0**; windowed → **exit 139**. So: display-driver
teardown crash, not movie-specific — a real player on this machine
quitting after such a session sees a crash-on-exit. Pattern: crashing
runs all loaded a giant world and/or ran bubble/keystone work; fort-only
and title-only runs exit clean. Root cause not chased tonight (quit-time
only, zero gameplay harm) — priced by the bench, owner assignment in the
verdict. Not yet known whether golem reproduces.

**Teardown segfaults (new, real):** seg4 (rescue property) and seg6
(roll-over keystone) both exited 139 (SIGSEGV) AFTER finalizing their
movies (seg4's AVI verified complete: 1200/1200 frames) and after all
property receipts printed green. Working hypothesis: quitting while
bubble/rescue effects are alive crashes engine teardown — both crashed
segs end with active/recent bubble work; segs 1/2/3/5 (no bubbles near
quit) exited 0. If it reproduces without --write-movie it hits real
players quitting mid-rescue. Repro check owed; billed to the bench.

**Instrument gap (new, honest):** the harness synthesizes input via
`Input.action_press()` only — no InputEvent is generated, so
`scenes/title.gd:_unhandled_input` can never see a harness press. The
harness CANNOT drive the title screen; seg1 is attract-only and gameplay
segs boot `--skipmenu`. B10 (first-five-minutes bench) needs a
title-press seam (e.g. `Input.parse_input_event()` path) before its
cold-boot-reel evidence contract is honest. Billed to the bench.

## (d) Settled-register delta (what this gate rules)

1. **D30 stands** (Waking as-is; golem couch box; B12-first) — see
   docs/DECISIONS.md.
2. **The BENCH_BOOK firing order is re-derived for the true state.**
   Printed order assumed "D25 next"; actual state is end-to-end complete.
   Derived order after this gate: pay this gate's S+M bills → **B10+B5**
   (couch-prep: Ezra's first session is the next producer event) →
   **B6+B2** on the dynamic split/merge camera build (REMAINING #1) when
   it lands → B1 after any movement change → B9 on GOLEM only → the rest
   as their systems move.
3. **Laptop receipts are first-class for everything except perf** (D30);
   perf lines stay open until a golem run.

## (e) The couch question (written BEFORE the playtest, per the B12 bar)

For Alex, for Ezra's first session — watch ONE thing:

> **From the title screen with no help: does Ezra get through a fort
> door into a giant's world and collect one dream within his first five
> minutes — and what is the exact FIRST moment he asks for help, looks
> at you, or puts the pad down?**

That moment (timestamp + what was on screen) is the single
highest-value receipt the project can collect. Everything B10/B5 will
bill traces back to it. Secondary watches, only if easy: does he notice
the door beacons; does he understand the split when a second pad joins;
does any Moon line make him look up.

## (f) Verdicts — ROUND 1 (2026-08-19, ~02:30)

**Chair 1 (Game-Feel, Opus): BELOW.** Feel itself EXCEEDS where
measurable — input→jump latency 1 physics frame 5/5 (receipts:
seg2b/seg2c stdout, press-frame vs EVT jumped); jump airtime 0.90s
reconciles with D2's derived spec to ~0.01s (NEW frozen number). Ruled
BELOW on: (a) rescue reads as deletion-then-restoration — camera
follows the body below the world, catch never framed (measured: 38% and
74% of the 3.10s beat below the readability floor, 2× variance);
(b) blob shadow paints vertical faces at full strength
(blob_shadow.gd:22, normal_fade never set); (c) INSTRUMENT: the reel
contains 12.4s input-driven motion of 217s (5.7%), 5 jump presses, zero
platforming, zero natural falls, zero camera input — a feel chair
cannot certify from it. Full verdict: chair transcript (session task
record); bill merged below.

**Chair 2 (Child-Readability, Fable): MEETS.** Wayfinding, bubble
read, tortoise-rise staging, and THE WAKING's wordless arc exceed
comps; held from EXCEEDS by finale text-layer defects, the unwired
rescue Moon line, the unnarrated/occluded roll-over, and night-dark
credits candids.

**MERGED BILL — payment plan (director ruling, round 1):**

PAY NOW (all S, both chairs, deduped):
- P1 blob shadow normal_fade (C1-S1, blob_shadow.gd)
- P2 Moon rescue line wired + rate-limited (C2-S1, soft_landing.gd;
  line exists in moon_lines.json)
- P3 subtitle ribbon renders ABOVE letterbox; HUD fully hidden during
  cinematic seizure (C2-S2 + C1-S5, camera_director/game_ui layers)
- P4 credits caption vs live subtitle collision — ribbon force-cleared
  at credits start (C2-S3 == C1-S4, waking_sequence.gd)
- P5 keystone world_complete praise moved to phase=end; roll-over gains
  its "shh — just rolling over" telegraph line at start (C1-S3 +
  narration half of C2-M3)
- P6 fort arrival says HOME, not "somewhere new" (C2-S5, data + wiring)
- P7 title: spoken press invitation appended to welcome (C2-S4) +
  wordmark float phase-locked so caps never break line (C1-S6)
- P8 fort residents get a dream-glow tint so Otto is unmistakable
  (C2-S6)
- P9 memory album: "bubbled" snap fires at landed, not in the void
  (C1-S2) + luma floor on candid selection + credits ordering biased
  bright (C2-M1 — paid now, contained in one file)
- P10 INSTRUMENT: round-2 reel contract = ONE CONTINUOUS PLAYED segment
  (walk to door under stick → enter → traverse → jump → collect →
  natural fall → caught → return) with --poslog on (C1-M4 + C1-M5),
  wisp coverage + denominator print (C2-S7), 1s battery cadence over
  the waking door-stir (C2-S8)

BANKED (docs/LEDGER.md founded this gate, named owners):
- L1 rescue camera authored recovery (C1-M1) — owner: B6 camera bench,
  AFTER the played reel provides natural-fall evidence (chair's own
  caveat). The teardown segfault rides with this owner (same
  bubble_effect lifetime territory).
- L2 door-arrival + summit-ear framing (C1-M2 == C2-M4) — owner: B6.
- L3 keystone mid-sequence cut-to-kids + static-tail trim (C1-M3) +
  roll-over staging past the tumble stack (C2-M3 camera half) —
  owner: set-piece lane.
- L4 split-screen seat-ownership cue (C2-M2) + solo "which one is me"
  affordance (C1-M6) — RULED AN ENTRY BAR for the B6+B2 dynamic
  split/merge build brief, per Chair 2, with Chair 1's solo extension.
- L5 race-start wordless telegraph (C2-M5) — owner: missions/juice
  lane.

**FIRING ORDER — reconciled (C1 dissent adopted in substance):**
pay S+cheap-M → shoot the PLAYED reel → B6 (camera) in PARALLEL with
B10+B5, all three reading the same new reel → B2 → B9 on golem → B1
parked until movement changes. C2's entry-bar annotation folded into
L4.

**COUCH QUESTION — final form (both chairs' refinements adopted):**
the §(e) watch + C1's first-fall clause ("what do his face and hands do
in the two seconds after the screen goes dark") + C1's "which one is
him" secondary + C2's circle-one stall-card (title Ⓐ / race dash-away /
fort-door interior) pre-registering the bench's predictions.
NEEDS_YOU's COUCH GATE section updated to match at session close.

Round 2: after payment, both chairs re-sit on the played reel +
payment receipts. Court-dress (S only) after that. 3-round cap holds.
