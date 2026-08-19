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

## (f) Verdicts

PENDING — two chairs (Opus xhigh + Fable) sit after (b) and (c) land.
Loop: build → two chairs → full fix (S+M) → re-judge → court-dress
(S only), 3-round cap, director tiebreak, producer live for rulings.
