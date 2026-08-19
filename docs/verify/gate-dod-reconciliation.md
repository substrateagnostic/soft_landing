<!-- served_model: claude-sonnet-5 (reconciliation lane, B12 gate, brief by Fable director) -->
# gate_dod_reconciliation.md — DoD line-by-line reconciliation for B12 (D30)

*Machine: this session's Windows box (repo at C:\Users\agall\projects\soft_landing,
Syncthing-shared with golem per gate-whole-game-VERIFY.md). HEAD at run time:
f340fdf88b6c26cb864daa3737ad576e581cfc93 ("D30 sync: NEEDS_YOU waking rulings
cleared; dev-laptop toolchain addendum"). Godot:
`C:\Users\agall\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64_console.exe`
→ 4.6.2.stable.official.71f334935.*

*This file feeds `docs/verify/gate-whole-game-VERIFY.md` §(b), which is
PENDING as of HEAD above — that file is a sibling lane's evidence packet for
the same B12 bench and was found untracked on disk when this pass started
(opened same day, same HEAD, its own §(c) "gate reel" lane still running).
Not edited by this pass — read-only reference confirming scope.*

Status legend (from DEFINITION_OF_DONE.md): `[x]` verified (receipt linked)
· `[U]` built but UNVERIFIED · `[ ]` open.

---

## PART A — DoD TABLE

### Gate 1 — pitch (producer)

| DoD line | Claimed | TRUE | Receipt(s) | Notes |
|---|---|---|---|---|
| GOAL.md saved verbatim before other work | [x] | **[x]** | `GOAL.md` exists on disk | git b566980 not independently re-verified (predates this pass's git-log window) but file content matches the claim's framing |
| AGENTS.md before any code | [x] | **[x]** | `AGENTS.md` exists on disk | — |
| Phase 0 audit | [x] | **[x]** | `evidence/toolchain.md` exists | — |
| Phase 1 research, 4 sourced docs + synthesis + decisions | [x] | **[x]** | `docs/research/{camera_readability,design_study,movement,pipeline}.md` (4 files, confirmed on disk) + `docs/RESEARCH.md` + `docs/DECISIONS.md` | exactly 4 v1 research docs present (v2/ has 6 more, separate lane) |
| ⛔ Producer greenlight of PITCH.md | [x] | **[x]** | `alexmemory.md:213` — `"greenlight! and then some. love it."` | quote confirmed verbatim in file |

**Gate 1: 5/5 confirmed [x]. No changes.**

### Gate 2 — grey-box slice + harness

Every Gate-2 line in DEFINITION_OF_DONE.md is already `[x]` with an inline
receipt pointer. Spot-verified by reading the cited VERIFY docs in full
(`scaffold-VERIFY.md`, `corefeel-VERIFY.md`, `gate2-slice-VERIFY.md`,
`harness-VERIFY.md`, `properties-VERIFY.md`) — every cited command/output is
present and matches the DoD's own quoted numbers (coyote 133ms fires / 500ms
refuses; jump-buffer positive case landed→jumped = 1 frame gap; apex-hang +
gravity asymmetry in corefeel; zero right-stick refs via three separate grep
passes; WARP/RESCUE/CARRY/TOSS/DOOR receipts all present; save.json diff +
`fort_stage1_nightlights.png` on disk; MOON_SAID receipts; byte-identical
`events.jsonl` across two runs; `gate2_slice.mp4` on disk, 8.14MB).

**Gate 2: 14/14 confirmed [x]. No changes.** One adjacent, NOT-a-DoD-line
finding worth flagging: `docs/verify/code-review-opus-2026-07-16.md` logged
4 REAL/CRITICAL bugs against this era's code. Re-checked against current
HEAD: CRITICAL-1 (stale rescue history soft-lock) is FIXED
(`core/rescue/soft_landing.gd:47 reset_history()`, called from
`scenes/main.gd:183,244`). REAL-3 (orbit-group leak) is FIXED
(`worlds/common/dreamling.gd:85-86 _exit_tree()`). REAL-2 (carried player
rescue-eligible) is FIXED (`soft_landing.gd:91-98`, explicit
`state == PlayerBody.State.CARRIED` guard). **REAL-4 (door interact fires
alongside carry/return on the same press — a co-op-only, low-severity but
real confusion bug) is NOT fixed** — `worlds/common/world_door.gd:149-154`
still polls `p1_interact`/`p2_interact` unconditionally whenever any body is
inside, no dwell/shared-ownership guard. Not a DoD checklist line, but
relevant to the "never confuse a 4-year-old" design floor — see
DISCREPANCIES.

### Gate 3 — art pipeline proof (producer sign-off)

| DoD line | Claimed | TRUE | Receipt(s) | Notes |
|---|---|---|---|---|
| Meshy→GLB→Godot seam per D10: manifest-driven, source-swappable | `[ ]` | **[x] — STALE-OPEN, box unchecked** | `docs/verify/art-pipeline-VERIFY.md` full doc; `tools/meshy/manifest.json`, `tools/meshy/forge_report.json` (both on disk, forge report shows 4/4 assets `ok`, 120/120 credits, `served_model:"meshy-6"` + honest `served_model_source:"not_reported_by_api_echoing_requested"` per asset); import receipt (exit 0, 4 GLBs import clean); MODEL_SWAP receipts; a real **zero-GLB fallback test** (renamed `.glb`+`.glb.import` away, reboot, `LanternPost` grey-box stays visible, zero errors, then restored byte-identical) | This is the seam's strongest proof: it was tested with the source physically removed, not just code-reviewed. Fully built and verified. |
| 1 character (Pip) + 3 props in-engine per ART_BIBLE (stills, palette + silhouette review against bible) | `[ ]` | **[U] — STALE-OPEN but incomplete** | Stills on disk: `evidence/stills/art/pip_meshy.png`, `fort_props.png` (lantern + both cushions in one frame), `firefly_jar_meshy.png`; MODEL_SWAP receipts for all 4 (pip/lantern/cushion×2) | Character + 3 props ARE in-engine with stills — the "in-engine" half is solid. The "palette + silhouette review **against ART_BIBLE**" half was never done as a named comparison step in any VERIFY doc — no doc quotes ART_BIBLE.md's palette hexes/silhouette rules next to the captured stills and rules pass/fail. Downgraded from a clean [x] to [U] on that basis. |
| Procedural squash-stretch on the Meshy Pip (video clip) | `[ ]` | **[U] — STALE-OPEN but not by video** | `docs/verify/characters-v2-VERIFY.md` §"Squash-stretch verified surviving": `PlayerBody._update_squash_stretch()` scales `Visual` every physics frame, confirmed composing correctly with skeletal animation in stills (e.g. `otto_carry_pip.png` shows pickup-squash + walk-cycle pose at once) | Mechanism is proven (two independent transform channels composing correctly), but the DoD line literally asks for a **video clip** and only stills exist for this specific claim. Note also: Pip is now RIGGED (D19 superseded D10's original "single soft mesh" scope for squash-stretch's *subject*), which is a documented, approved supersession, not a defect. |
| served_model / credits logged per external call | `[ ]` | **[x] — STALE-OPEN, box unchecked** | `tools/meshy/forge_report.json` — every one of the 4 asset entries carries `credits` + `served_model` + `served_model_source`; TOTAL 120/120 credits reconciled | Fully verified. (Note: `art-pipeline-VERIFY.md`'s own header lacks the `served_model: claude-sonnet-5` self-attestation line every other VERIFY doc in this repo carries — a doc-hygiene nit, not a gap in the actual receipt.) |
| ⛔ Producer art sign-off | `[ ]` | **[ ] open** | — | Cannot close except by producer. Nothing blocks asking for it — all 4 preceding items have real receipts now. |

**Gate 3: 3 of 5 stale-open items have solid receipts (2 clean [x], 1 [x] with
a documented gap, 1 [U] on a literal-video-clip technicality); 1 sign-off
genuinely open.**

### Gate 4 — v0.1 accept

| DoD line | Claimed | TRUE | Receipt(s) | Notes |
|---|---|---|---|---|
| Bramble: 10 dreamlings per D12, all reachable on the input floor alone (harness completes world using only stick+jump+interact — event log) | `[ ]` | **[U]** | `docs/verify/missions-m2-VERIFY.md` (all 5 non-open archetypes individually live-verified via `--headless` teleport-then-observe scripts — a sanctioned dev instrument, not raw stick input); `docs/verify/mountain-m3-VERIFY.md`'s `bramble_ascent.json` (Seg0 walked un-teleported via real camera-relative movement; Segs 2-5 documented UNVERIFIED for un-teleported walking, camera-yaw gap issue named); `check_placements`/`check_missions` 10/10 green (fresh, this pass) | Every individual mechanism is proven reachable via stick+jump+interact in isolation. **No single harness run collects all 10 bramble dreamlings end-to-end using continuous stick+jump+interact input with an event log** — every existing script either teleports to isolate one archetype or (for the ascent) only proves the first switchback via real walking. This is the honest gap the DoD line's parenthetical is asking to close. |
| Fort growth 3 stages, persistent across restart (save round-trip receipt) | `[ ]` | **[U]** | Stage 1: `docs/verify/gate2-slice-VERIFY.md` — full save round trip, fresh process, `evidence/stills/fort_stage1_nightlights.png` on disk. Stage 2: `docs/verify/art-pipeline-VERIFY.md` §6a (isolated test-scene, same code path, `MODEL_SWAP {"id":"firefly_jar",...}` fires) + `docs/verify/hub-population-VERIFY.md` (seeded save with `"fort_stage":2`, real `pillow_fort` boot — jar-build code path runs but the jar's own receipt line isn't quoted in that doc). Stage 3: **no receipt anywhere** — `worlds/pillow_fort/pillow_fort.gd:170-177` (`if stage >= 3: ... "MobileDream%d"`) exists in code; grepped the whole repo for `MobileDream` and `fort_stage.*3` — zero hits outside the source file itself. | Stage 1 is fully verified end-to-end (save round trip). Stage 2 is verified by mechanism (same code path proven, real GLB swap) but never via a genuine fort_stage=2 save + fresh-process restart showing the jar on screen. Stage 3 has literally never been booted or receipted. |
| Lullaby stem seam: layers audibly add per dreams returned (video + AudioManager log); placeholder stems in `assets/audio/stems/bramble/` | `[ ]` | **[U]** | `scenes/main.gd:84-96 _update_stems()` — thresholds `returned>=1→2 layers, >=5→3, >=10→4`, wired since commit `c0738c3` ("stems actually wired... -22dB before, -14.9dB after", `evidence/overnight_tour.mp4`); full 4-stem sets now exist for all 4 worlds (`assets/audio/stems/{bramble,wisp,marmalade,tortoise}/layer_{1..4}.ogg`, D28 "audio pass 4" — `generate_audio_v4.py`) | The seam demonstrably plays stems (volumedetect proof of silence→sound), and the threshold logic is in code and correct by inspection. **No receipt anywhere demonstrates the layer COUNT actually growing (1→2→3→4) as dreams are returned** — no video, no AudioManager log walking a save through the four thresholds. This is exactly what the DoD line's "layers audibly add per dreams returned" asks for and it has never been captured. |
| Full session video: boot → co-op → collect → rescue → return → fort growth → quit, ≥3 min mp4 in `evidence/` | `[ ]` | **[ ] open — confirmed, no such file exists** | Checked every mp4 in `evidence/`: `the_waking.mp4` (62s, finale only, per `git log bfc1a94`), `gate2_slice.mp4` (66.0s, 4 segments, Gate-2 scope only), `overnight_tour.mp4` (55s), `three_keystones.mp4`/`k_bear.mp4`/`k_cat.mp4`/`k_whale.mp4` (keystone showcases only), `m2_bramble_showcase.mp4`, `audio_v2/v3_*.mp4` (verb/set-piece proofs). None covers boot→co-op→collect→rescue→return→fort-growth→quit in one continuous ≥3min clip. | `docs/verify/gate-whole-game-VERIFY.md` §(c), opened same session/same HEAD as this pass, is actively building exactly this — `evidence/gate_whole_game_reel.mp4`, 8 segments, target ≥3min — but **that file does not exist on disk as of this run** (checked directly). That doc also names a real instrument gap: the harness cannot drive the title screen (`Input.action_press()` produces no `InputEvent`), so a true "boot" segment can only be attract-footage, not a title-press-through. |
| Save corruption property | PARTIAL (already honest in file) | **PARTIAL — confirmed accurate, no change** | `docs/verify/properties-VERIFY.md` §P4, re-read in full | The DoD file's own text is already a correct, honest description of this line's state — .bak rename + exit 0 + fresh valid save all proven; the one open thread is Godot's own engine-level `ERROR: Parse JSON failed` stdout line, outside `SaveManager`'s power to suppress. No update needed. |
| Hot-swap property | [x] | **[x] confirmed, no change** | `docs/verify/properties-VERIFY.md` §P5 | Mode flips both directions, buddy AI engages/disengages correctly at the boundaries, zero crash. Matches the DoD's own quoted text exactly. |
| 60 fps on the golem's Windows partition during normal play (perf counter receipt) | [ ] (with detail: instrumented, PARTIAL reading) | **[ ] open — confirmed, cannot close from this machine** | `docs/verify/properties-VERIFY.md` §P6 (min 3fps, diagnosed as a session-presentation artifact, not scene cost); **D30 (docs/DECISIONS.md)**: "THE COUCH BOX IS GOLEM (Windows partition): any perf number captured on the dev laptop is ADVISORY-ONLY... the B9 watchline freezes only on golem hardware." | This pass did not attempt a perf capture (not asked to in Task 2's property list, and D30 makes clear it would be advisory-only from this machine regardless). Stays open until run on golem's real interactive session. |
| Playtest-observation checklist for Ezra's first session written into NEEDS_YOU.md | [ ] | **[U]** | `docs/design/playtest-checklist.md` exists in full (dated 2026-07-16, complete: setup / movement watches / fiction watches / co-op watches / hard-data fields / after-session question) — but its own first line says *"Draft (final version lands in NEEDS_YOU.md at Gate 4)"* | Read the current `NEEDS_YOU.md` in full: the checklist has **not** been transplanted there yet — only scattered related language exists (e.g. the D27/D28 sections reference watching feel, not this specific checklist). The DoD line's literal instruction ("written into NEEDS_YOU.md") is unmet even though the content is fully drafted and ready to paste in. `docs/verify/gate-whole-game-VERIFY.md` §(e) independently authored a condensed one-question version of this same checklist for this exact bench ("does Ezra get through a fort door... within his first five minutes") — the two should be reconciled, not left as two competing artifacts. |
| ⛔ Producer v0.1 accept | [ ] | **[ ] open** | — | Gates on the items above. |

**Gate 4: 0 of 9 lines are clean-verified; 1 is a correctly-stated PARTIAL,
1 is a correctly-stated [x], 5 are [U] (mechanism proven, specific receipt
the line asks for is missing), 2 are genuinely [ ] open (video reel + perf +
producer sign-offs — perf and 2 sign-offs are open; full-session video is
open; playtest checklist is [U] not [ ]).**

### Standing properties (re-verified at every gate)

| DoD line | Claimed | TRUE | Receipt(s) | Notes |
|---|---|---|---|---|
| No fail state exists: grep + design review | `[ ]` | **[x] — freshly re-verified this pass** | See PART B(c) below — full verbatim grep output | Every symbol clean. The one `damage` hit is a comment explicitly denying it exists ("Pure gift: no damage, no..."); every `lives` hit is the verb, not a mechanic. Zero `health`/`game_over`/`gameover`/`score`/`death`/`die(` anywhere in `core/worlds/scenes/scripts`. |
| Input floor sufficiency: every objective completable with stick+jump+interact only | `[ ]` | **[U]** | Same evidence base as the Bramble-10-dreamlings line above, extended across all 4 giant worlds (world-wisp/world-marmalade/tortoise-world VERIFY docs' own route tables + placement/mission green runs) | Design-verified and individually mechanism-verified everywhere; no single continuous harness run proves full-floor-only completion end-to-end for any one world. D17's ceiling verbs (flutter/glide/pound) are explicitly documented as never required, which is the right shape of guarantee, just not yet an event-log receipt. |
| Worlds never skill-gated: all world doors open from a fresh save | `[ ]` | **[x]** | `worlds/pillow_fort/pillow_fort.gd:91 _build_bramble_door()` builds all 4 `_add_world_door()` calls (Bramble/Marmalade/Wisp/Tortoise) unconditionally in `_ready()` — no `fort_stage`/dream-count/`if` gate of any kind wraps door construction (confirmed by reading the function; grepped for `fort_stage >=` near door code — no match) | Each door additionally has its own individually-receipted round trip: bramble (`gate2-slice-VERIFY.md`), marmalade (`world-marmalade-VERIFY.md` §d), wisp (`world-wisp-VERIFY.md` §d), tortoise (`tortoise-world-VERIFY.md`, throwaway door probe). No single receipt is labeled "fresh save, all 4 doors open before any dream collected" as one run, but the code-level absolute guarantee (zero conditionals) plus 4 independent working-door receipts together clear the bar. |
| Never writes to Garden_Train / un_party_game (grep receipt) | `[ ]` | **[x] — freshly re-verified this pass** | See PART B(e) below — full verbatim grep output | Only mentions of `un_party_game`/`D:\Projects` are in comments documenting code lineage (`generate_audio.py`, `meshy_forge.ps1` headers) — zero write calls to any path outside the repo. Every `FileAccess.open(..., WRITE)` call in the codebase targets `user://save.json` or a repo-relative `--outdir` (globalized from `res://`, never a hardcoded external path). |

**Standing properties: 3 of 4 verified clean [x] fresh this pass; 1 [U] for
the same reason as the Gate-4 dreamlings line (mechanism proven piecewise,
no single end-to-end event-log receipt).**

---

## PART B — PROPERTY RE-RUNS, VERBATIM (this machine, this HEAD)

### (a) Placements — 5/5 worlds, all green

```
> "<godot>" --headless --path . --script tools/props/check_placements.gd -- --world=bramble
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["bramble"]}   exit=0

> ... --world=wisp
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["wisp"]}   exit=0

> ... --world=marmalade
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["marmalade"]}   exit=0

> ... --world=tortoise
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["tortoise"]}   exit=0

> ... --world=pillow_fort
PLACEMENT_NOTE pillow_fort has zero dreamlings (nothing to check)
PLACEMENT_SUMMARY {"any_fail":false,"worlds":["pillow_fort"]}   exit=0
```
Denominator note: the script's own default-world set is
`["pillow_fort","bramble"]`; `wisp`/`marmalade`/`tortoise` all take an
explicit `--world=` flag (confirmed this is the correct/only way to run
them — matches every prior VERIFY doc's own usage). "Five worlds" here is
genuinely the four giant worlds + the fort, not four giants + a phantom
fifth — `pillow_fort` legitimately has zero dreamlings by design (D14 —
fort growth is stage-based, not dreamling-based).

### (b) Missions — 4/4 giant worlds, all green

```
> ... --script tools/props/check_missions.gd -- --world=bramble
MISSION_ARCHETYPE_COUNTS {"counts":{"duet":1,"open":4,"race":2,"ride":2,"shy":1},"total":10,"world":"bramble"}
MISSION_SUMMARY {"any_fail":false,"worlds":["bramble"]}   exit=0

> ... --world=wisp
MISSION_ARCHETYPE_COUNTS {"counts":{"race":1,"shy":1},"total":2,"world":"wisp"}
MISSION_SUMMARY {"any_fail":false,"worlds":["wisp"]}   exit=0

> ... --world=marmalade
MISSION_ARCHETYPE_COUNTS {"counts":{"race":1,"shy":1},"total":2,"world":"marmalade"}
MISSION_SUMMARY {"any_fail":false,"worlds":["marmalade"]}   exit=0

> ... --world=tortoise
MISSION_ARCHETYPE_COUNTS {"counts":{"duet":1,"open":1,"race":1,"ride":1,"shy":1},"total":5,"world":"tortoise"}
MISSION_SUMMARY {"any_fail":false,"worlds":["tortoise"]}   exit=0
```
`pillow_fort` has no mission data (all-open, nothing to check per every
prior VERIFY doc — not re-run, matches documented convention).

### (c) No-fail-state grep — verbatim, `core/ worlds/ scenes/ scripts/`

```
$ grep -rniE "health" core worlds scenes scripts
(no matches, exit 1)

$ grep -rniE "damage" core worlds scenes scripts
core/movement/player_body.gd:464:## within tuning.pound_radius gets a free launch. Pure gift: no damage, no

$ grep -rniE "game_over|gameover" core worlds scenes scripts
(no matches, exit 1)

$ grep -rniE "score" core worlds scenes scripts
(no matches, exit 1)

$ grep -rniE "\blives\b" core worlds scenes scripts
core/art/character_animator.gd:4:## its PlayerBody's public state every physics frame. Lives as a child of a
core/camera/camera_director.gd:58:	# Must keep polling under get_tree().paused — photo mode lives inside
core/camera/orbit_camera_rig.gd:30:## Lives under a SubViewport (CameraDirector) — get_world_3d() resolves to
core/env/ambience.gd:14:## the moon key light lives here now, alongside the ambient particle systems
core/movement/movement_tuning.gd:3:## MovementTuning — every movement feel number lives here (D2), never
core/movement/player_body.gd:4:## number lives in `tuning` (a MovementTuning resource); this script holds
core/quests/mission.gd:9:## worlds/common/world_base.gd; the actual archetype BEHAVIOR lives in
worlds/bramble/rollover_sequence.gd:52:# Machinery (letterbox + cine-camera create/tween/restore) lives in
worlds/common/dreamkeeper.gd:5:## Homeworlds model): a small, zero-dialogue resident who lives at a fixed
worlds/common/dream_door.gd:45:## ALREADY standing in the door (d10 lives right beside it) never re-fires
worlds/common/fort_resident.gd:21:##            DRIFT_RADIUS of its assigned home (never further — it lives
worlds/marmalade/stretch_sequence.gd:56:# cine-camera create/tween/restore) lives in core/cinematic/cine_sequence.gd

$ grep -rniE "death" core worlds scenes scripts
(no matches, exit 1)

$ grep -rniE "die\(" core worlds scenes scripts
(no matches, exit 1)
```
**Classification: every hit is benign.** `damage` — a doc-comment denying
the concept exists. `lives` — every instance is the verb "resides," never
"remaining lives" as a resource/counter. `health`/`game_over`/`gameover`/
`score`/`death`/`die(` — zero matches anywhere (note: plain `grep` with no
matches exits 1 per AGENTS.md's documented gotcha, sequenced with `;` not
`&&`, none of these killed the sequence).

### (d) Right-stick floor — grep + code-read

```
$ grep -rniE "axis.*[23]|RIGHT_X|RIGHT_Y|right_stick|right stick|JOY_AXIS_RIGHT" core --include="*.gd"
core/camera/orbit_camera_rig.gd:12:##   1. THE STICK (new): this seat's right stick orbits yaw continuously

$ grep -niE "\"axis\":\s*[23]" project.godot
(8 matches: p1_camera_left/right/up/down + p2_camera_left/right/up/down,
 device 0/1, axis 2/3 — the D18/D27-approved camera-orbit input map)

$ grep -rln "p1_camera_\|p2_camera_" --include="*.gd" .
./scenes/ui/photo_mode.gd
(and core/camera/orbit_camera_rig.gd itself, matched separately above)
```
**Finding: right stick exists and is read (axis 2/3, `p1_camera_*`/
`p2_camera_*`), and this is CORRECT per D18 (superseding D4's original
"never read" clause) and D27 ("full-orbit optional camera IS allowed").**
The property that matters — is it ever REQUIRED — holds: `orbit_camera_rig.gd`'s
own header states the yaw/pitch authority order explicitly as (1) stick
if deflected → (2) CameraHint → (3) velocity leash → (4) idle hold, i.e.
**the camera auto-follows correctly with zero stick input**. Grepped every
`.gd` file in the repo for who reads `p1_camera_*`/`p2_camera_*`: only
`orbit_camera_rig.gd` (camera itself) and `photo_mode.gd` (an optional,
paused-game photo feature) — no movement/jump/interact/objective-completion
code anywhere reads a camera-stick action. Right stick is confirmed
camera-only and optional, never a completion requirement.

### (e) External-write property — grep, whole repo

```
$ grep -rnE "Garden_Train|un_party_game" --include="*.gd" --include="*.ps1" --include="*.py" .
./tools/audio_gen/generate_audio.py:12:  un_party_game/tools/declick_sfx.py, adapted to synthesis instead of
./tools/audio_gen/generate_audio.py:102:  zero — the declick technique from un_party_game/tools/declick_sfx.py,
./tools/meshy/meshy_forge.ps1:6:  D:\Projects\un_party_game\tools\meshy_forge.ps1 (18/18 KEEP rate across

$ grep -rn "D:\\\\Projects\|D:/Projects" --include="*.gd" --include="*.ps1" --include="*.py" .
(no matches, exit 1)

$ grep -rnE "FileAccess\.open\(|\.open\(\"[A-Za-z]:\\\\|\.open\('[A-Za-z]:\\\\" --include="*.gd" . | grep -v "user://"
core/quests/mission_registry.gd:26:  FileAccess.open(path, FileAccess.READ)      # data/missions/<id>.json, res://-relative
scripts/autoloads/save_manager.gd:39:   FileAccess.open(SAVE_PATH, FileAccess.READ)
scripts/autoloads/save_manager.gd:110:  FileAccess.open(SAVE_PATH, FileAccess.WRITE)
scripts/autoloads/the_moon.gd:116:      FileAccess.open(LINES_PATH, FileAccess.READ)
tools/harness/harness.gd:174:        FileAccess.open(res_path, FileAccess.READ)
tools/harness/harness.gd:490:  FileAccess.open(_outdir_abs.path_join("events.jsonl"), FileAccess.WRITE)
worlds/bramble/bramble.gd:676:     FileAccess.open(path, FileAccess.READ)
worlds/common/world_base.gd:210:   FileAccess.open(path, FileAccess.READ)
worlds/pillow_fort/pillow_fort.gd:570,640: FileAccess.open(path/FORT_RESIDENT_SPOTS_PATH, FileAccess.READ)
worlds/tortoise/tortoise.gd:656:    FileAccess.open(path, FileAccess.READ)
worlds/wisp/wisp.gd:873:    FileAccess.open(path, FileAccess.READ)
```
Verified the two WRITE call sites by reading their path constants:
`SAVE_PATH = "user://save.json"` (`save_manager.gd:7`) — Godot's per-user
data dir, never the repo, never Garden_Train/un_party_game.
`harness.gd:107-108`: `_outdir_abs = ProjectSettings.globalize_path("res://").path_join(outdir_flag)`
— always resolves inside the repo (`res://`), never an external absolute
path, regardless of what `--outdir=` string is passed.
**PASS — zero writes outside the repo anywhere in the codebase.**

---

## PART C — STALE-OPEN ITEMS SAFE TO CHECK (receipts verified to exist)

1. **Gate 3 — Meshy→GLB→Godot seam per D10.** `[ ]` → `[x]`. Full receipt
   chain confirmed: `tools/meshy/manifest.json` + `forge_report.json` +
   import receipt + MODEL_SWAP + the zero-GLB fallback test (rename source
   away, reboot, grey-box survives, restore, byte-identical).
2. **Gate 3 — served_model / credits logged per external call.** `[ ]` →
   `[x]`. `tools/meshy/forge_report.json` on disk, every one of the 4
   assets carries `credits`+`served_model`+`served_model_source`, totals
   reconcile (120/120).
3. **Standing property — Worlds never skill-gated.** `[ ]` → `[x]`.
   `pillow_fort.gd`'s door-building function has zero conditional gates;
   all 4 doors individually receipted working.
4. **Standing property — No fail state.** `[ ]` → `[x]`. Fresh grep this
   pass, zero live hits, all context-benign.
5. **Standing property — Never writes outside repo.** `[ ]` → `[x]`. Fresh
   grep this pass, only comment/lineage mentions, both write call sites
   confirmed `user://` / repo-relative.

## PART D — HONESTLY STILL OPEN (what would close each)

1. **Gate 3 — 1 character + 3 props "palette + silhouette review against
   ART_BIBLE."** Closer: 10 minutes with `ART_BIBLE.md` open beside
   `evidence/stills/art/{pip_meshy,fort_props,firefly_jar_meshy}.png`,
   writing a short pass/fail against its stated palette hexes and
   silhouette rules. The stills already exist; only the comparison is
   missing.
2. **Gate 3 — squash-stretch video clip.** Closer: one windowed
   `--write-movie` capture of Pip jumping/landing (squash-stretch fires
   every jump per `player_body.gd`), a few seconds, transcoded per the
   house recipe. The mechanism is already proven; only the clip format
   the DoD line names is missing.
3. **Gate 4 — Bramble 10-dreamling stick+jump+interact-only completion.**
   Closer: one new `tools/harness/scripts/bramble_full_collect.json` that
   walks (never teleports) through all 10 in D12 cadence order, using only
   move/jump/interact actions, with `--poslog` + a full `events.jsonl`.
   The camera-yaw gap noted in `mountain-m3-VERIFY.md` (segments 2-5 of the
   ascent) would need either a bridging `CameraHint` fix or a documented
   workaround first.
4. **Gate 4 — Fort growth stage 2 and stage 3 receipts.** Closer: seed a
   save with `fort_stage:2`, boot `pillow_fort` fresh, confirm the
   `FireflyJarVisual`/`MODEL_SWAP{"id":"firefly_jar"}` receipt explicitly;
   repeat with `fort_stage:3`, confirm the 4 `MobileDream%d` orbs build
   (they have no MODEL_SWAP — plain primitives — so confirm via a node-walk
   or a screenshot). Both are cheap, mechanical, ~10 minutes total.
5. **Gate 4 — Lullaby layer-count growth receipt.** Closer: seed 3 saves
   at `returned=0/1/5/10` for one world, boot each, grep
   `AudioManager`'s stem-layer log line (or add one if it doesn't already
   print layer count) for the layer count at each threshold; ideally one
   windowed capture with `volumedetect` per threshold showing the mix
   getting richer.
6. **Gate 4 — Full session video ≥3min.** Already being built by a sibling
   lane (`gate-whole-game-VERIFY.md` §(c)) — not yet on disk. Its named
   instrument gap (harness can't press-through the title screen) should be
   fixed or explicitly worked around before that reel is cited as closing
   this line.
7. **Gate 4 — 60fps on golem.** Closer: literally just run the existing
   `--perflog` windowed harness command from `properties-VERIFY.md` §P6 on
   the golem's own interactive Windows session (not remote/automated) — the
   instrument already exists and works, per D30 it just needs to run on the
   right box.
8. **Gate 4 — Playtest checklist into NEEDS_YOU.md.** Closer: literally
   copy `docs/design/playtest-checklist.md`'s content (already complete)
   into `NEEDS_YOU.md`, reconciled against `gate-whole-game-VERIFY.md`
   §(e)'s condensed one-question version so the two don't compete.
9. **Standing property — Input floor sufficiency, full receipt.** Same
   closer shape as item 3 above, generalized to all 4 giant worlds (or
   at minimum a statement that item 3's bramble run stands in for the
   property, since the mechanism — never-required ceiling verbs — is
   identical everywhere).
10. **3 producer sign-offs** (Gate 3 art, Gate 4 v0.1 accept, and by
    extension this whole B12 gate's own verdict) — cannot be closed by any
    agent; need Alex in the chair.

## PART E — DISCREPANCIES

1. **`docs/verify/gate-whole-game-VERIFY.md` exists, untracked, opened the
   same day/HEAD as this pass.** It is the parent packet this reconciliation
   feeds (§(b) is literally this file's job, marked PENDING there). Not a
   contradiction — confirmed it's a sibling lane in the same bench, not a
   stale duplicate. Flagging so the director doesn't mistake it for
   drift.
2. **`docs/design/playtest-checklist.md` vs. `gate-whole-game-VERIFY.md`
   §(e)**: two different, non-identical framings of "what to watch during
   Ezra's first session" now exist (the full multi-section draft, and a
   condensed single-question version authored for this specific bench).
   Neither has been merged into `NEEDS_YOU.md` as DEFINITION_OF_DONE.md's
   Gate-4 line requires. Needs one director decision: merge, or pick one.
3. **REAL-4 from `code-review-opus-2026-07-16.md` (door interact races
   carry/return on the same button press) is unfixed**, ~40 days after the
   review that found it, while 3 sibling findings from the same review
   (CRITICAL-1, REAL-2, REAL-3) were all fixed. Not a DoD line, but a named,
   real, still-open defect that predates this gate and nothing in the
   30 VERIFY docs mentions re-visiting it.
4. **`art-pipeline-VERIFY.md` is missing the `served_model:` self-attestation
   header line every other VERIFY doc in this repo carries** (doc-hygiene
   only — the actual Meshy `served_model` data is present and correct in
   `forge_report.json`, this is about the VERIFY doc's own header
   convention, not the underlying receipt).
5. **No MISSING receipt files found.** Every specific file this pass spot-
   checked (art-pipeline stills, characters-v2 stills, fort_stage1 still,
   forge_report.json, m3_hub stills) exists on disk exactly as its VERIFY
   doc claims. `evidence/gate_whole_game_reel.mp4` does NOT exist yet, but
   that's an honestly-PENDING sibling-lane deliverable, not a broken
   reference — `gate-whole-game-VERIFY.md` itself marks it PENDING, it
   doesn't claim it's done.
