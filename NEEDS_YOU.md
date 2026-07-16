# NEEDS YOU — soft_landing / THE BIG NAP
*Updated at the end of every session. What exists, where the evidence is, one
cold demo command, what's unverified, and what only you can decide.*

## Session 1, overnight shift (2026-07-16, you in Chicago)

### What happened while you slept (all pushed to github.com/substrateagnostic/soft_landing)
- **Gate 2 closed** (your video approval, verbatim, in DoD).
- **Gate 3 provisionally passed** by director-as-producer: Meshy pipeline
  proven end-to-end — **Pip and Otto are real onesie kids now**, lantern/
  jar/cushions live behind the swappable D10 seam. 150 credits total spent
  across 6 assets. Stills: `evidence/stills/art/`. **Your veto stands.**
- **Two new worlds** built parallel against the contract: **Wisp** (drifting
  whale over a moonlit lake) and **Marmalade** (cat asleep on a village).
  All four worlds boot; **30/30 dreamling placements pass** the checker.
- **CALLIE** — yes, that Callie — naps on her cushion by the fort, perches
  on either kid, **mews toward hidden dreams** (receipts show her pointing
  at d01 across the meadow), purrs when you carry dreams, teleports home
  like all good stuffies. Her calico GLB is in. `docs/design/world-cards/callie.md`.
- **The game has sound**: rising chime ladder per carried dream, bubble
  catch/pop, geyser sighs, and the Bramble lullaby stems that add a layer
  at 1/5/10 dreams returned. Placeholder synths await your viola —
  **spec at `docs/design/music-stems-spec.md`** (32 s loops, 60 BPM, D major).
- **HUD** (pips + numeral), pause menu, breathing title screen.
- **Opus code review**: 1 CRITICAL (world-switch rescue soft-lock) found and
  fixed same-night with a regression property; 2 REAL fixed; NITs queued.
- Properties P1-P6 swept; harness gained --poslog/--perflog/pads events.

### ⛔ Decisions pending (all vetoable, none blocking)
1. **Gate 3 art sign-off** — review `evidence/stills/art/` + the finale video.
   Known art notes: duck-bill reads weak on Pip's hood (re-roll candidate,
   or Multi-Image-to-3D from photos — see pipeline.md addendum);
   firefly jar lost its glow-dots (retexture endpoint can fix).
2. **Feel re-tune pass** — every number is @export; tell me in feelings.
3. **License** Apache-2.0 (standing).
4. **Viola stems** whenever — placeholders ship fine.

### Cold demo command (from D:\Projects\soft_landing)
```
D:\Tools\godot\godot_console.exe --path . -- --skipmenu
```
(Boots to the fort: Callie's on her cushion right of the fort; three tinted
doors behind it — umber=Bramble, orange=Marmalade, silver=Wisp. 1-2 pads,
or keyboard WASD+Space+E drives Otto.)

### UNVERIFIED / known-open (honest)
- TTS audible voice quality (call-path receipted; TTS audio is OS-level so
  it is NOT captured in movie receipts — needs live ears).
- Save-corruption recovery: player-facing behavior proven; one engine-level
  JSON parse ERROR line in stdout can't be suppressed (cosmetic, logged).
- Sustained-fps receipt: instrument built; needs your interactive session
  (remote-session numbers are presentation artifacts).
- Polish queue: initial Visual yaw at spawn (kids face camera until they
  move), Wisp reeds too dark/spiky, Wisp establishing framing, door/interact
  same-frame overload (input-claim seam), Otto still capsule-in-scene-file
  fallback only in old stills, review NITs (triple-save, receipt seat
  fields, Jolt pin).
- Ezra playtest checklist: drafted at `docs/design/playtest-checklist.md`,
  moves here at Gate 4.
