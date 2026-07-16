# ALEX MEMORY — running log of things worth your review
*Claude maintains this. Newest entries at top. The NEEDS YOU section is
always current. Skim top-down; nothing below the fold is urgent.*

---

## NEEDS YOU (current)

- **🔑 Meshy key** (needed by Phase 4, not before): the `.env` lives at
  `~/projects/Dead_Attestation/.env` on the Pop!_OS side — not synced to this
  Windows partition. Drop the file onto D:, or paste `MESHY_API_KEY=...` into
  `D:\Projects\soft_landing\.env` (gitignored).
- **🔐 gh auth** (needed at Gate 1 push): GitHub CLI is being installed; it has
  no credentials on this partition. `gh auth login` in any terminal, or paste a
  token. Until then the repo stays local.
- **⛔ GATE 1 pending**: pitch packet lands in chat this session.

---

## LOG

### 2026-07-15 — Session 1 (cont. 2): GATE 1 PASSED, Phase 3 launched
- **Producer greenlight, verbatim: "greenlight! and then some. love it."**
  Meshy key incoming when producer is unloaded. THE BIG NAP is real.
- winget diagnosed unhealthy (30+ min, zero output, both jobs killed).
  Direct-installed to D:\Tools with receipts: **Godot 4.6.2 console**
  (`4.6.2.stable.official.71f334935`), **gh 2.96.0**, **ffmpeg 8.1.2**;
  user PATH extended. gh unauthenticated → still a NEEDS-YOU.
- Phase 3 split: 3A scaffold (Sonnet, running) → then 3B core-feel + 3C
  harness + 3D worlds in parallel (disjoint file ownership) → 3E director
  integration/feel/video. Gate 2 packet will be a gameplay mp4.

### 2026-07-15 — Session 1 (cont.): research landed, pitch written
- **Phase 1 done in ~25 min wall-clock:** four parallel research agents
  (movement / camera+readability / design study / pipeline) delivered
  ~1,200 lines of sourced docs. Synthesis in `docs/RESEARCH.md`; sixteen
  founding decisions in `docs/DECISIONS.md` (D1–D16).
- Load-bearing findings: Kirby FL removed camera control *on purpose* for
  exactly our player; variable jump height punishes preschoolers (dropped);
  Meshy auto-rig only ships walk/run → procedural squash-stretch; Movie
  Maker needs a real window (never --headless) + clean --quit-after.
- **The pitch: THE BIG NAP.** Colossal animals asleep for a once-a-century
  nap; their dreams (dreamlings) drift loose; two kids in onesies — Pip
  (duck, Ezra's seat) and Otto (bear, helper seat) — carry the dreams home,
  narrated by the Moon (diegetic TTS). Falling = a dreamling catches you:
  the Soft Landing. Hub = growing Pillow Fort; World 1 = Bramble the bear
  (breathing-chest trampoline, snore geysers, fur meadows). Full packet:
  PITCH.md, GAME_BRIEF.md, SPEC.md, ART_BIBLE.md, DEFINITION_OF_DONE.md.
- Declined concepts (in PITCH.md): Puddlejump (cloud courier — impersonal
  rescue), Attic of the Bigs (giant toys — Toy Story shadow, toys don't
  breathe).
- winget installs (godot/gh/ffmpeg) still churning in background at pitch
  time; toolchain.md gets post-install verification when they land.

### 2026-07-15 — Session 1: the chair, the audit, the founding
- **Director seated.** Third AI-directed game. Register chosen: *enormous
  tenderness* — a big world that is glad you're small. Repo named
  `soft_landing` — the design floor as a title (no fall damage; every fall
  ends gently; a platformer for someone learning to jump).
- **Toolchain surprise:** this Windows partition has never run Godot — the
  un_party_game / Garden_Train nights ran on the Pop!_OS side of the golem
  (D:\Projects is a Syncthing share; `.stfolder` marker present). godot, gh,
  ffmpeg all absent → installing all three via winget (blanket install
  permission granted by producer mid-session). Python 3.14 + git 2.52 present.
- Godot MCP: not configured in this session (godot-mcp-pro-v1.13.2 sits on
  disk, unwired). Driving godot headless via CLI per goal fallback.
- GOAL.md saved verbatim (both parts) before any other work. AGENTS.md
  written before any code. Tuned to the A (Claude's_corner) before either.
