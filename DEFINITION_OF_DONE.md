# DEFINITION_OF_DONE.md — THE BIG NAP v0.1

Every item is checked ONLY with a linked receipt (file path, test name, or
command + captured output under `evidence/` or `docs/verify/`). Nothing
checks on vibes. **UNVERIFIED is an honest state.** Status legend:
`[ ]` open · `[U]` built but UNVERIFIED · `[x]` verified (receipt linked).

## Gate 1 — pitch (producer)
- [x] GOAL.md saved verbatim before other work — `GOAL.md` (git b566980)
- [x] AGENTS.md before any code — `AGENTS.md` (git b566980)
- [x] Phase 0 audit — `evidence/toolchain.md`
- [x] Phase 1 research, 4 sourced docs + synthesis + decisions —
      `docs/research/*`, `docs/RESEARCH.md`, `docs/DECISIONS.md` (git 0a5e8f6)
- [x] ⛔ Producer greenlight of PITCH.md — "greenlight! and then some. love
      it." (chat, 2026-07-15; logged in alexmemory.md)

## Gate 2 — grey-box slice + harness (producer feel check from video)
- [x] Project boots clean: import exit 0, zero script errors —
      `docs/verify/scaffold-VERIFY.md`, re-run post-integration
      (`docs/verify/gate2-slice-VERIFY.md` §Import)
- [x] Coyote proven both directions (133 ms fires / 500 ms refuses) —
      gate2-slice-VERIFY §Coyote. Buffer positive case now verified —
      `docs/verify/properties-VERIFY.md` §P1 (measured landing frame, then
      a 166.7 ms press fires 1 frame after landing; a 300 ms control
      correctly does not fire).
- [x] Apex flutter state + rise/fall gravity asymmetry —
      `docs/verify/corefeel-VERIFY.md` (state machine + derived gravities)
- [x] Camera per D4: zero right-stick/axis-2/3 refs (grep receipts,
      corefeel-VERIFY §d) + hint yaw visible on video
- [x] Co-op leash → bubble warp: `WARP {"seat":2}` receipts + on video;
      player-player non-collision via layer config (corefeel-VERIFY)
- [x] Soft Landing: `RESCUE {"seat":1}` + set down inland + control restored
      (gate2-slice-VERIFY §Rescue + video @ ~0:40)
- [x] Blob shadow + landing ring wired in both player scenes (scene receipt)
      + visible throughout video
- [x] Solo buddy: zero-P2-input script, Otto trails + mirrors jumps
      (gate2-slice-VERIFY §Buddy + video final segment)
- [x] Fort door ↔ bramble round trip: DOOR/WORLD_READY receipt chain
      (gate2-slice-VERIFY §Doors)
- [x] Collect → return → save mutation → fort growth stage 1 in a FRESH
      process: save.json diff + `stills/fort_stage1_nightlights.png`
- [x] TheMoon speaks: MOON_SAID receipts (welcome/new_area/dream_home).
      **Audible voice quality [U]** — needs producer ears.
- [x] Determinism: byte-identical events.jsonl across two runs
      (docs/verify/harness-VERIFY.md)
- [x] Movie receipt: `evidence/gate2_slice.mp4` — 66.0 s, 4 segments
      (approach / meadow+rescue / toss / buddy)
- [x] ⛔ Producer feel check passed — "gate 2 from video is approved for now
      -- hard to tell without character models, my inputs etc so may need
      slight tuning but good to go for now." (chat, 2026-07-16). A feel
      re-tune pass is expected post-art, post-couch — logged in NEEDS_YOU.

## Gate 3 — art pipeline proof (producer sign-off)
- [ ] Meshy→GLB→Godot seam per D10: manifest-driven, source-swappable
      (receipt: forge report JSON + import log)
- [ ] 1 character (Pip) + 3 props in-engine per ART_BIBLE (stills in
      `evidence/`, palette + silhouette review against bible)
- [ ] Procedural squash-stretch on the Meshy Pip (video clip)
- [ ] served_model / credits logged per external call (forge report)
- [ ] ⛔ Producer art sign-off

## Gate 4 — v0.1 accept
- [ ] Bramble: 10 dreamlings per D12 cadence, all reachable on the input
      floor alone (property: harness completes world using only
      stick+jump+interact — event log)
- [ ] Fort growth 3 stages, persistent across restart (save round-trip receipt)
- [ ] Lullaby stem seam: layers audibly add per dreams returned (video +
      AudioManager log); placeholder stems in `assets/audio/stems/bramble/`
- [ ] Full session video: boot → co-op → collect → rescue → return → fort
      growth → quit, ≥3 min mp4 in `evidence/`
- [ ] Save corruption property: corrupt save → .bak rename + clean start,
      no error shown to player (test receipt). PARTIAL —
      `docs/verify/properties-VERIFY.md` §P4: .bak rename, exit 0, and a
      genuinely fresh valid save after a real collect are all proven, and
      no app code raises an error (quarantine message is a plain print(),
      no crash/dialog); left unchecked because stdout does carry one
      engine-level `ERROR: Parse JSON failed` line from Godot's own
      `JSON.parse_string()`, which `SaveManager` cannot suppress and which
      is outside this pass's territory to touch.
- [x] Hot-swap property: pad disconnect mid-play → solo buddy mode without
      crash; reconnect → co-op restored (harness or manual receipt) —
      `docs/verify/properties-VERIFY.md` §P5 (mode flips both directions
      via the new `InputRouter.force_mode` script seam, no crash; buddy AI
      closes to follow distance within 3 s of engaging and sits frozen for
      5 s of a widening gap after disengaging).
- [ ] 60 fps on the golem's Windows partition during normal play
      (perf counter receipt). Instrument built and run —
      `docs/verify/properties-VERIFY.md` §P6 (`--perflog`, windowed,
      real Vulkan device) — but the reading (min 3 fps) is an artifact of
      this automated/remote session's window presentation, confirmed via a
      trivial-scene control run showing the same number; left unchecked
      pending a re-run on the golem's actual interactive Windows session.
- [ ] Playtest-observation checklist for Ezra's first session written into
      NEEDS_YOU.md
- [ ] ⛔ Producer v0.1 accept

## Standing properties (re-verified at every gate)
- [ ] No fail state exists: grep + design review — no health, damage, timer,
      score, game-over symbols anywhere (receipt: grep output)
- [ ] Input floor sufficiency: every objective completable with
      stick+jump+interact only (harness property run)
- [ ] Worlds never skill-gated: all world doors open from a fresh save
      (harness receipt)
- [ ] Never writes to Garden_Train / un_party_game (property: no paths
      outside repo in code — grep receipt)
