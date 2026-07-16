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
- [ ] Project boots clean: `godot --headless --editor --import --quit --path .`
      exits 0, zero script errors (receipt: command + output)
- [ ] Movement controller per D2/D3: coyote + buffer proven by harness script
      (property: a jump input ≤0.20 s after leaving ground still jumps;
      ≤0.22 s before landing still jumps) — receipt: harness JSON log
- [ ] Apex flutter state reachable; fall gravity > rise gravity (log values)
- [ ] Camera rig per D4: right-stick axes appear NOWHERE in the input map or
      code (property: grep receipt) + hint-volume yaw demonstrated on video
- [ ] Co-op per D5/D7: two simulated pads, leash break → bubble warp shown on
      video; no player-player collision (property: overlap test log)
- [ ] Soft Landing per D6: scripted fall → bubble → return to last safe
      ground, no state loss (harness log + video)
- [ ] Blob shadow + landing ring always-on for both players (video + property:
      nodes present in both player scenes — scene receipt)
- [ ] Solo mode: 1 pad → Otto buddy AI follows, toss works (video)
- [ ] Hub + Bramble grey-box: fort door ↔ bramble round trip, spawn points
      honored (harness log)
- [ ] ≥1 dreamling collect → return → GameState count + save file mutation
      (JSON diff receipt) → fort growth stage 1 visible (still)
- [ ] TheMoon TTS speaks an objective (property: tts_speak called — stdout
      log; audio verified by producer on Gate 2 video or noted UNVERIFIED)
- [ ] Autoplay harness: input-playback script reproduces a full loop
      deterministically under --fixed-fps (two runs, same event log — diff)
- [ ] Movie receipt: ≥60 s gameplay mp4 in `evidence/` (windowed capture,
      D11 recipe) — the Gate 2 packet
- [ ] ⛔ Producer feel check passed

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
      no error shown to player (test receipt)
- [ ] Hot-swap property: pad disconnect mid-play → solo buddy mode without
      crash; reconnect → co-op restored (harness or manual receipt)
- [ ] 60 fps on the golem's Windows partition during normal play
      (perf counter receipt)
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
