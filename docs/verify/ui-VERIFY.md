# UI — HUD, PAUSE MENU, TITLE POLISH — VERIFICATION (2026-07-16)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
Territory: `scenes/ui/**` (new), `scenes/title.tscn`/`title.gd` (polish),
a narrow licensed edit to `scenes/main.tscn`/`main.gd` (mount `GameUI`,
call `setup_hud`), `data/moon_lines.json` (three new keys), and one
`project.godot` edit (the `pause` input action). No other files touched.

## a) Import pass

```
godot_console.exe --headless --editor --import --quit --path .
```
Exit 0, zero import errors (`evidence/_scratch/ui/import_check2.log`,
re-run after a concurrent harness.gd edit from another in-flight agent
settled — see "Notes" below).

## b) Headless boot, both worlds — HUD hidden vs visible

```
godot_console.exe --headless --path . -- --skipmenu --world=pillow_fort --pads=2 --quitafter=3
godot_console.exe --headless --path . -- --skipmenu --world=bramble     --pads=2 --quitafter=3
```
Receipts (`evidence/_scratch/ui/boot_fort.log`, `boot_bramble.log`):
```
WORLD_READY {"id":"pillow_fort","objectives":0}
HUD_READY {"pips":0,"world":"pillow_fort"}
...
WORLD_READY {"id":"bramble","objectives":10}
HUD_READY {"pips":10,"world":"bramble"}
```
`hud.gd` sets `visible = false` whenever `objective_ids` is empty, so the
fort's `pips:0` line also proves the HUD hid itself. Zero script errors in
either run (only a pre-existing, unrelated shutdown warning — see Notes).

## c) Scripted collect run — live HUD_PIP receipts

Reused `tools/harness/scripts/gate2_meadow.json` read-only, per the brief
(never edited the harness or its scripts):
```
godot_console.exe --headless --path . -- --skipmenu --world=bramble --pads=2 \
  --script=tools/harness/scripts/gate2_meadow.json \
  --outdir=evidence/_scratch/ui/hud_pips --quitafter=30
```
Receipts (`evidence/_scratch/ui/hud_pip_run.log`):
```
HUD_READY {"pips":10,"world":"bramble"}
EVT {"id":"d01","t":443,"type":"dreamling_collected","world_id":"bramble"}
HUD_PIP {"id":"d01","state":"carried"}
EVT {"id":"d02","t":798,"type":"dreamling_collected","world_id":"bramble"}
HUD_PIP {"id":"d02","state":"carried"}
```
Each `dreamling_collected` GameState signal is followed immediately by a
`HUD_PIP` line — the pip flips to "carried" (hollow ring) the instant it
happens, live, with no polling.

## d) Pause — MANUALLY UNVERIFIED headless (honest)

The harness has no scripted "pause" action (Start-button presses aren't in
its input-playback vocabulary, by design — extending it was out of
territory here). A real Start-button pause therefore stays **MANUALLY
UNVERIFIED headless**: the producer confirms it on the couch.

What *is* verified: a debug seam reads `Harness.flag("debug_pause", false)`
in `scenes/ui/game_ui.gd` (same convention as
`core/rescue/soft_landing.gd`'s `--testfall`) and opens the pause menu on
boot, so a windowed `--shots` run could capture it without a real
Start-button press:
```
godot_console.exe --path . --resolution 1280x720 -- --skipmenu --world=bramble \
  --pads=2 --debug_pause --shots=30 --outdir=evidence/_scratch/ui/pause --quitafter=6
```
Receipt (`evidence/_scratch/ui/pause/run.log`):
```
MOON_SAID {"key":"paused","text":"Taking a little rest. I'll wait right here."}
HARNESS_NOTE screenshot saved D:/Projects/soft_landing/evidence/_scratch/ui/pause/shot_30.png
```
Still: `evidence/_scratch/ui/pause/shot_30.png` — dusk-blue dim overlay,
two rounded icon-only buttons (play-triangle "Keep Playing" with a visible
honey-gold focus ring since it's the default focus target, moon-crescent
"Sleep"), HUD visible-but-frozen underneath. This proves the pause UI
itself, its Moon line, and the focus ring render correctly; it does NOT
prove the physical Start-button binding reaches it — that's the part left
UNVERIFIED headless.

## e) Windowed screenshots

**HUD over bramble, mid-collect** (reused `gate2_meadow.json` again,
shot after both d01/d02 collect events at t=443/798):
```
godot_console.exe --path . --resolution 1280x720 -- --skipmenu --world=bramble --pads=2 \
  --script=tools/harness/scripts/gate2_meadow.json --shots=850 \
  --outdir=evidence/_scratch/ui/hud_bramble --quitafter=16
```
Still: `evidence/_scratch/ui/hud_bramble/shot_850.png`. Shows d01/d02 as
hollow gold rings ("carried"), the rest dim dusk-blue ("untouched") —
**except d10, filled solid gold ("returned")**: this machine's persistent
`user://save.json` already had d10 returned from an earlier gate2 session,
and the HUD correctly read that back through `GameState.returned_ids()` at
`setup()` time (numeral reads "1", matching). Stronger evidence than a
fresh save would have given — both the live-update path and the
persisted-load path are visible in one frame.

**Title screen, polished**:
```
godot_console.exe --path . --resolution 1280x720 -- --shots=90 --outdir=evidence/_scratch/ui/title --quitafter=5
```
Still: `evidence/_scratch/ui/title/shot_90.png`. Dusk-to-rose gradient sky,
"THE BIG NAP" in the heavy-embolden default font with a soft drop shadow,
three drifting gold orbs, pulsing "press Ⓐ" prompt.

**Bonus — HUD idle-fade property** (not in the checklist, verified anyway
since it's an explicit design requirement): two shots of an untouched HUD,
one at 0.5 s and one at 5.3 s in:
```
godot_console.exe --path . --resolution 1280x720 -- --skipmenu --world=bramble --pads=2 \
  --shots=30,320 --outdir=evidence/_scratch/ui/hud_fade --quitafter=8
```
`shot_30.png` (0.5 s, well under the 4 s idle threshold): panel reads
solid. `shot_320.png` (5.3 s, past the threshold): panel is visibly more
translucent — the world behind it reads through more strongly. Confirms
`_reset_fade()` / `_process()`'s 4 s-idle -> 1 s ease to 40% alpha, and
that it eases (no flash/cut) per the design floor.

## Import clean (re-confirmed post-integration)

Re-ran `--headless --editor --import --quit` after wiring `GameUI` into
`main.tscn`/`main.gd` — exit 0, zero errors
(`evidence/_scratch/ui/import_check2.log`).

## Bug found and fixed during this pass

`scenes/ui/game_ui.gd`'s debug seam originally read
`bool(Harness.flag("debug_pause", false))`. Harness stores a bare flag
(`--debug_pause`, no `=value`) as a native `bool`, but a flag passed as
`--debug_pause=true` comes back as the **String** `"true"` — and
GDScript's `bool()` constructor has no String overload, so that line threw
`SCRIPT ERROR: Invalid call. Nonexistent 'bool' constructor.` on my first
attempt (receipt: `evidence/_scratch/ui/pause_shot_run.log`). Fixed by
dropping the `bool()` wrapper and using the flag directly in the `if`
(Variant truthiness), matching the exact convention already established by
`core/rescue/soft_landing.gd`'s `--testfall`. Re-verified clean in §d.

## Notes — pre-existing, out of territory

- A concurrent in-flight edit to `tools/harness/harness.gd` by another
  agent (adding perf sampling) briefly broke `_maybe_sample_perf()` mid-run
  during this session (a genuine multi-agent race, receipt:
  `evidence/_scratch/ui/pause_shot_run2.log`) — resolved itself once that
  agent's edit landed; re-verified clean afterward. Not a UI-territory bug.
- Every bramble boot-and-quit (with or without the UI changes) prints
  `ERROR: 2 resources still in use at exit` for
  `assets/audio/sfx/snore_geyser.ogg` (an `AudioStreamOggVorbis` /
  `OggPacketSequence` leak, confirmed via `--verbose`). This is
  `worlds/bramble/snore_geyser.gd` audio-cleanup, not `scenes/ui/**` —
  out of this build's territory, flagging for whoever owns that file.

## UNVERIFIED (honest list)

- **Physical Start-button pause, headless**: the harness has no scripted
  "pause" action; only the debug-seam path (§d) is receipt-verified. The
  producer needs to confirm a real pad's Start button opens the menu.
- **Gamepad dpad/stick focus navigation between the two pause buttons**:
  `focus_neighbor_left/right` are wired and Godot's default spatial focus
  should cover it, but neither the harness nor a screenshot can prove
  *navigation* (only that the initial focus ring renders) — needs a couch
  check.
- **Audible TTS quality** for the three new Moon lines (`paused`,
  `keep_playing`, `goodnight`): `MOON_SAID` call-path receipts are green
  (§d); actual SAPI voice needs producer ears, same standing caveat as
  `gate2-slice-VERIFY.md`.
