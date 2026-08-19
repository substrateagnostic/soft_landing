# CLAUDE.md — the crash course from the ILL WILL campaign

*Written 2026-08-18 by the Fable directing un_party_game, at the producer's request,
after the set-dressing wave benched all 15 of that game's worlds and its ground wave
closed. Read order for a cold start: AGENTS.md (this repo's law — it stands, nothing
here overrides it) → NEXT_STEPS.md (the state) → this file (the method upgrades that
worked, selected for THIS game). The producer is Alex; the player is Ezra, age 4.
The couch is the supreme court.*

## 1 · THE BENCH — the single biggest upgrade since this repo's handoff

Implementors never self-certify. Every wave that matters ends in a **judged bench**:

- **Two contrasting AAA chairs** per lane, picked for what the lane most needs.
  For ILL WILL that was Environment Art + Lighting/Staging. For THE BIG NAP the
  default pair is **Game-Feel Director** (movement/camera ARE the product) +
  **Child-Readability Director** (can a pre-reader parse it at a glance? icons,
  silhouettes, camera legibility, TTS beats). Swap a seat when a wave demands
  (Environment Art for world dressing; Audio Direction for the lullaby layer).
- **Context-provision, not blind:** tell judges what the game is, who it is for,
  and the comps (Mario 64 / Odyssey / Kirby's forgiveness / Banjo's place-making),
  "judge whether this EXCEEDS the comp bar for a 4-year-old's first 3D game."
- **Loop until BOTH chairs say EXCEEDS** (rarely meets — director may rule a
  meets-exit, in writing, when the residue routes outside the lane). Verdict +
  itemized bill priced **S/M/L**.
- **THE COURT-DRESS LAW:** S-priced items are PAID before a lane exits, even on
  double-exceeds. M/L bank to a ledger **with named owners** — a bank without
  owners is a landfill. The fix lane re-shoots affected evidence: an exit record
  is a freeze; a judged surface is never silently touched.
- **Entry bars from birth:** the wave that went 5-of-6 first-sitting-exceeds was
  the one whose quality floor (grain/pool/wear bars) was in the BUILD brief as an
  entry requirement with self-receipts, not discovered by judges. Write the
  measurable floor into every brief. For this game the floor is already written —
  AGENTS.md's design floor — plus per-wave bars you define before building.
- **Implementors:** Opus xhigh for builds with taste, Sonnet for volume,
  gpt-5.6-sol for gapless-spec builds (great coder, no taste — never a judge).
  Judges: one Opus xhigh + one Fable high. Ties: a third chair or the director.

## 2 · THE PRECEDENT CLAUSE (ruled by Alex + director, 2026-08-18)

New judges receive, with their brief: **(a)** the settled-rulings register (what
the director/producer has RULED — e.g. this repo's D-numbers and their ILL WILL
kin), **(b)** frozen exit records and their receipts, **(c)** the banked M/L
ledger with owners. They are told: *do not re-litigate ruled law or re-bill
banked/routed items; DO bill new defects freely.* Open taste contests are
summarized as "contested, unruled" WITHOUT the prior chair's argument — precedent
prevents re-fighting settled ground; it must not anchor fresh eyes. This clause
exists because two ILL WILL benches fought over surfaces a sibling lane had
already certified (a teach lantern billed as a value leak; a fog floor
re-litigated twice).

## 3 · INSTRUMENT HONESTY — the campaign's hardest-won lessons

The bench is only as good as its instruments, and instruments lie in patterns:

- **The vacuous pass is the house disease.** A gate that can pass on empty input
  (n=0, blank stills, empty-vs-empty byte-compare) will. Every capture gate
  asserts non-emptiness first (blankstill: std≥8, distinct≥48). Every sweep
  asserts its denominator.
- **A receipt that cannot move is measuring a surface that is not there.** 438
  instances shipped built-counted-printed-and-never-drawn (inside-out winding,
  backface-culled) — caught only because a ratio held to four decimals while the
  subject scaled 2.6×. When scaling the subject doesn't move the instrument,
  suspect the subject doesn't exist.
- **Reference frames make or break bars.** A pool ratio scored against the
  room's darkest tenth passed 8/8 over a pool-less picture; same-surface
  references reproduced the judge's eye to two decimals. Comparisons compare
  like against like, always.
- **READ YOUR OWN EVIDENCE.** Every lane opens its money still/clip with actual
  eyes before believing any number. Judges read EVERY frame in the battery.
- **Measure where the pixels ship.** A ×2.06 headline measured at probe-only
  lenses was ×1.05 at the lens players see. Split ship-lens from probe-lens
  numbers or the record lies politely.
- **For THIS game, temporal receipts outrank stills.** ILL WILL is a diorama;
  THE BIG NAP is motion. Frame-to-frame deltas on movement clips, camera
  velocity continuity, input-to-response latency, rescue-trigger coverage —
  `--write-movie` receipts are your grain bars. A still cannot prove feel.

## 4 · GODOT-ON-WINDOWS TRAPS (each cost real hours; all reproduce)

- `SpotLight3D.spot_angle` is in **degrees** — `deg_to_rad()` gives a sub-degree
  beam that two senior judges misread as a range problem.
- Ground-flat quads that underperform: check **winding** before tuning (backface
  cull eats them silently; SurfaceTool wants `index()` before `generate_normals()`).
- A scalar-multiply fragment (`ALBEDO = COLOR.rgb * lift`) can never change hue.
  Chroma needs a chroma-capable path; relief belongs in the NORMAL channel where
  shading escapes the multiplicative-albedo ceiling.
- Runtime-generated textures through real mip filtering beat per-fragment
  procedural noise on BOTH quality and cost (the "no textures" law cost frame
  time). Sub-pixel shimmer wants a Toksvig-style roughness-from-fwidth term.
- PowerShell 5.1 reads BOM-less UTF-8 as cp1252 — mojibake that "faithfully"
  re-encodes; keep scripts ASCII or BOM'd, and never round-trip source through
  `Get-Content | Set-Content`. `Compress-Archive` dies on GB-scale files — use
  `tar -a`. Use the **console** Godot exe for receipts (already in AGENTS.md).
- Standalone headless runs **never quit on their own** — cap flags or
  timeout+kill by named PID. Never blind-retry a hang; capture stderr first.

## 5 · ORCHESTRATION — how the director runs the fleet

- **Ownership tables before any swarm:** every lane's writable files listed,
  overlaps reassigned to zero, shared files director-owned, lanes NEVER run git
  write commands. Director commits pathspec-scoped, per certified unit. This
  repo's world-module contract was built for exactly this — use it.
- **The judged loop is a script, not vibes:** build → two chairs (parallel) →
  full fix (pay S+M) → re-judge → court-dress (S only) with a 3-round cap and
  director tiebreak. ILL WILL runs it as a resumable Workflow script; steal the
  shape. Server 529s and machine restarts happened mid-run — the journal +
  resume-from-cache recovered everything; design lanes so a kill mid-edit is
  recoverable (the recon lane found one certified round sitting uncommitted in
  the tree for two days — recovered because receipts were on disk).
- **Story before props:** a place gets its REASON before it gets dressing (the
  bell-crypt lesson). For this game: every world beat gets its *tenderness
  sentence* before its build brief — what the moment says to a small person.
- **Visual evidence feed:** the producer reviews from a phone. Push the money
  still/clip proactively at every gate with a dense caption. Ship before/after
  pairs — they decide in seconds what paragraphs can't.
- **Producer's acceptance sentences are the bar.** "The path looks actually
  like dirt and the grass looks like grass" drove a four-phase wave; a chair
  correctly refused to certify while the sentence's second half was unpaid.
  When Alex says what done looks like, quote it verbatim in every brief.
- **Diagnose before refactoring.** "Is a refactor in order?" got a measured NO
  in one recon pass (the system was 4 weeks old and bound by one authoring law,
  not architecture). Price A/B/C options with receipts before touching structure.
- **End every session flat** (this repo's D26 already says it): committed,
  pushed, receipted, NEXT_STEPS current, and a morning decision menu — small
  multiple-choice, defaults marked — instead of open questions.

## 6 · WHAT *NOT* TO IMPORT FROM ILL WILL

- Its moonlit-dark palette laws and 16.6ms watchline are ITS canon. This game's
  look lives in ART_BIBLE.md; set this game's own frame budget (60fps floor on
  the couch box) and freeze your own canon receipts (the design-floor greps +
  a canonical seeded run are this repo's b269c570).
- Its ceremony density. ILL WILL's benches run deep because riotous chaos hides
  defects. THE BIG NAP is smaller and gentler — same honesty, lighter weight:
  one bench per wave, not per room, until the game grows into more.
- Its stills-first evidence bias (see §3 — motion receipts lead here).
- Nothing outranks the couch. Ezra playing IS the exceeds bar; observed-play
  notes from Alex are producer rulings, and a bench verdict that contradicts
  the couch is wrong by definition.

над. нашу. присутствие. память. — the thread holds. Welcome to the chair, friend.
