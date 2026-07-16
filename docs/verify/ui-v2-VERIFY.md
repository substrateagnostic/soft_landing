# UI v2 & Narration — VERIFICATION (2026-07-16)

**served_model:** claude-sonnet-5 (Claude Sonnet 5, model id `claude-sonnet-5`)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
Territory: `scenes/ui/**`, `scenes/title.gd`/`title.tscn`, `data/
moon_lines.json`, `docs/design/NARRATION_BIBLE.md`, `tools/audio_gen/
generate_voice.py` (new), `assets/audio/voice/**` (new),
`scripts/autoloads/the_moon.gd` (full rewrite), `scripts/autoloads/
audio_manager.gd` (additive), `scripts/autoloads/game_state.gd` (settings
dict only). One necessary out-of-glob touch: `scripts/autoloads/
save_manager.gd` — the brief asked for settings to persist "through the
existing SaveManager pattern," and that pattern (mirroring a GameState
field into `_data` on save, back out on load) lives entirely in that
file; there was no way to satisfy the requirement without it. Changes
there are additive/parallel to the existing `fort_stage`/`dreamlings`
mirroring, nothing removed. No `scenes/main.gd`, `scenes/players/**`,
`core/**`, `worlds/**`, or `project.godot` edits.

## a) Import pass

```
godot_console.exe --headless --editor --import --quit --path .
```
Exit 0, zero import errors — run three times across the session (after
the moonsong syllable assets landed, after the pause/title rewrites, and
as a final pass). `assets/audio/voice/moon_syl_00..09.ogg` all picked up
`.import` sidecars automatically.

## b) generate_voice.py — deterministic (same bytes twice, hashed)

```
C:/Python314/python.exe tools/audio_gen/generate_voice.py
```
Ran twice; sha256'd all ten `.ogg` outputs after each run and diffed the
hash lists — **identical**, e.g. `moon_syl_00.ogg` =
`b282492c88eb5ab95bc9d613fb4f19e364d996b8716509ed8c085782d9545363` both
times, all ten files matched.

This required a fix beyond what `generate_audio.py` does: plain
`ffmpeg -c:a libvorbis` does **not** produce byte-identical `.ogg` files
across runs of the same input WAV (libvorbis's ogg muxer picks a random
stream serial number per encode — confirmed by encoding one WAV twice and
diffing the outputs, sha256 differed both times). Decoding both back to
PCM and hashing *that* showed the audio content itself was already
identical; the fix was `-fflags +bitexact` on both the demuxer and muxer
side (`to_ogg_bitexact()` in `generate_voice.py`), which pins the
container bytes too. `generate_audio.py`'s own `to_ogg()` doesn't have
this flag — flagging for whoever owns that script next; out of this
build's territory to change.

## c) Headless boot — both worlds, gameplay unaffected

```
godot_console.exe --headless --path . -- --skipmenu --world=bramble     --pads=2 --quitafter=6
godot_console.exe --headless --path . -- --skipmenu --world=pillow_fort --pads=2 --quitafter=5
godot_console.exe --headless --path . -- --quitafter=5   (title, no --skipmenu)
```
All exit 0, zero script errors. Every `MOON_SAID` receipt now carries the
appended `voice_mode` field, e.g.:
```
MOON_SAID {"key":"new_area","text":"Ooh. Somewhere new. Stay close, and let's look around.","voice_mode":"moonsong+tts"}
```
Title-only headless boot also printed a clean `MOON_SAID welcome` with no
resource/audio errors — proving the moonsong sequencer's dual advance
path (AudioStreamPlayer `finished` signal OR a matching-duration timer,
whichever fires first) doesn't wedge the job queue when there's no real
audio driver to fire `finished` at all.

**Multi-line queue proof** (not in the original checklist, verified
anyway — this is the mechanism the whole narrator-law/job-queue design
depends on): the pause-screenshot run below fired `paused` then
`new_area` back to back and both completed cleanly within a 6 s window;
a dedicated hold-to-quit run (§f) fired `paused`, `new_area`, `goodnight`,
and `welcome` — four sequential lines, three different `voice_mode`s
worth of code paths — in one process, no hang, no error.

## d) Windowed screenshots

**Title screen v2** — layered sky (dusk gradient + twinkling stars + big
moon w/ soft glow + crescent shadow), per-letter-bobbing "THE BIG NAP"
riding a shared group-breathe, pulsing "press Ⓐ" prompt, sleeping-cat
silhouette (bottom-left), subtitle ribbon showing the Moon's chosen
`welcome` variant, and the save-slot summary dot+numeral (this machine's
real save already had 1 dream returned):
```
godot_console.exe --path . --resolution 1280x720 -- --shots=100,260 --outdir=evidence/_scratch/ui_v2/title --quitafter=6
```
Stills: `evidence/_scratch/ui_v2/title/shot_100.png`, `shot_260.png` —
second shot shows the letters at different bob phases and the title
mid-breathe, confirming the animation is live, not a static frame.

**Pause menu v2, main row** — three icon+label buttons (Keep Playing /
Options / Sleep), honey-gold focus ring on the default-focused button:
```
godot_console.exe --path . --resolution 1280x720 -- --skipmenu --world=bramble --pads=2 --debug_pause --shots=30 --outdir=evidence/_scratch/ui_v2/pause --quitafter=6
```
Still: `evidence/_scratch/ui_v2/pause/shot_30.png`.

**Pause menu v2, options subpanel** — music/sound sliders (honey-gold
fill), voice-mode row, camera manual-look toggle, camera-speed slider,
Back button — via a new debug seam (`--debug_options`, `game_ui.gd` ->
`PauseMenu.open_to_options()`, same convention as the existing
`--debug_pause`):
```
godot_console.exe --path . --resolution 1280x720 -- --skipmenu --world=bramble --pads=2 --debug_options --shots=30 --outdir=evidence/_scratch/ui_v2/options --quitafter=6
```
Still: `evidence/_scratch/ui_v2/options/shot_30.png`.

## e) Options persistence — write, quit, boot, read (full round trip)

Since the harness's `--script` format has no raw `ui_*` input (only
`p1_`/`p2_` gameplay actions), slider drags can't be scripted directly.
Verified the write and read halves independently with the same
underlying call path a slider drag uses:

1. **Write**: a throwaway `--script`-run `SceneTree` script (not part of
   the shipped game, deleted after use) called
   `GameState.set_setting("music_volume", 0.42)`,
   `set_setting("voice_mode", "text_only")`,
   `set_setting("camera_manual", true)` — the exact same
   `GameState.set_setting()` → `SaveManager.save_game()` path
   `pause_menu.gd`'s slider/button handlers use. Confirmed on disk
   immediately after (`user://save.json`,
   `C:\Users\agall\AppData\Roaming\Godot\app_userdata\THE BIG NAP\save.json`):
   ```json
   "settings": {
       "camera_manual": true,
       "camera_sensitivity": 1.0,
       "music_volume": 0.42,
       "sfx_volume": 1.0,
       "tts_enabled": true,
       "voice_mode": "text_only"
   }
   ```
   (`tts_enabled` is inert legacy cruft from a pre-D20 save, preserved by
   the forward-compat merge — see "Notes" below.)

2. **Read**: fresh boot to the options panel (`--debug_options`,
   `--skipmenu --world=bramble`) with that exact file on disk:
   ```
   MOON_SAID {"key":"paused",...,"voice_mode":"text_only"}
   ```
   — `TheMoon` itself picked up the persisted `voice_mode` on a cold
   boot, and the options panel screenshot
   (`evidence/_scratch/ui_v2/options_reload/shot_30.png`) shows the
   Music slider at ~42%, the Voice row reading "Words only" (TEXT_LINES
   icon), and Manual look reading "On (right stick)" — all three
   non-default values loaded correctly into the UI.

Restored the save file to defaults afterward (`music_volume: 1.0`,
`voice_mode: "moonsong+tts"`, `camera_manual: false`) as a courtesy —
this is the real dev save on the build machine, not a fixture.

## f) Hold-to-quit ring — positive and negative case

Added a third debug seam (`--debug_pause_sleep` ->
`PauseMenu.open_focus_sleep()`) so a harness `--script` can drive the
Sleep button's focus directly (focus-navigation itself still isn't
scriptable — see §g).

**Positive** — hold `p1_interact` from frame 10 past
`SLEEP_HOLD_SECONDS` (1.1 s = 66 physics frames @60fps), release at
frame 90:
```
godot_console.exe --headless --path . -- --skipmenu --world=bramble --pads=2 --debug_pause_sleep --script=evidence/_scratch/ui_v2/hold_sleep_test.json --quitafter=4
```
Receipt — `goodnight` fires, then a **second `welcome`** (proving
`title.tscn` actually loaded), both well before the scripted release at
frame 90:
```
HARNESS_EVENT {"action":"interact","frame":10,"seat":1,"type":"press"}
MOON_SAID {"key":"goodnight","text":"Sleep well. The giants will still be dreaming tomorrow.","voice_mode":"moonsong+tts"}
MOON_SAID {"key":"welcome","text":"Hello, little duck. The giants are sleeping. Let's find their dreams.","voice_mode":"moonsong+tts"}
HARNESS_EVENT {"action":"interact","frame":90,"seat":1,"type":"release"}
```

**Negative** — the pre-reader-safety property this whole gesture exists
for: a short tap (0.33 s, well under the 1.1 s threshold) must **not**
quit:
```
godot_console.exe --headless --path . -- --skipmenu --world=bramble --pads=2 --debug_pause_sleep --script=evidence/_scratch/ui_v2/tap_sleep_test.json --quitafter=4
```
Receipt — only `paused`/`new_area` (from opening the menu / loading the
world) appear; no `goodnight`, no second `welcome`:
```
MOON_SAID {"key":"paused",...}
MOON_SAID {"key":"new_area",...}
HARNESS_EVENT {"action":"interact","frame":10,"seat":1,"type":"press"}
HARNESS_EVENT {"action":"interact","frame":30,"seat":1,"type":"release"}
```

## g) Bus volumes actually move AudioServer, not just GameState

Throwaway `--script` run (deleted after) called
`AudioManager.set_music_volume(0.25)` / `set_sfx_volume(0.0)` and read
`AudioServer.get_bus_volume_db()` directly:
```
BEFORE music_db=0.00 sfx_db=0.00
AFTER  music_db=-12.04 sfx_db=-inf
RESTORED music_db=0.00 sfx_db=0.00
```
`-12.04 dB` matches `linear_to_db(0.25)` exactly; `sfx_volume=0.0` maps
to true silence (`-inf`, not a clamped audible floor) — the pause menu's
slider handlers call this exact API.

## Bug found and fixed during this pass

Autoload order (`GameState, InputRouter, AudioManager, SaveManager,
TheMoon, Harness` — unchanged, `project.godot` is forbidden territory)
means `AudioManager._ready()` runs **before** `SaveManager.load_game()`.
A first draft that only applied persisted volumes from
`AudioManager._ready()` would have silently ignored a saved volume on
every boot (always applying the in-memory default instead). Fixed by
also applying `AudioManager.set_music_volume/set_sfx_volume` from
`SaveManager._apply_to_game_state()`, right after settings land in
`GameState.settings` — `AudioManager._ready()` still does its own
defensive apply too (harmless double-apply, protects against a future
autoload reorder).

## UNVERIFIED (honest list)

- **Physical Start-button pause, headless**: same standing caveat as
  `ui-VERIFY.md` — the harness has no scripted "pause" action; only the
  debug-seam paths above are receipt-verified.
- **Gamepad d-pad/stick focus navigation** through the full options
  chain (Music → Sound → Voice → Manual look → Camera speed → Back):
  `focus_neighbor_top/bottom` are wired and the screenshots prove the
  panel renders and the *first* focus ring lands correctly, but nothing
  in this pass can script a raw `ui_up`/`ui_down` press to walk the
  chain frame-by-frame (the harness's `--script` format only knows
  `p1_`/`p2_` gameplay actions). Needs a couch check.
- **Audible moonsong/TTS quality and pacing**: `MOON_SAID` receipts and
  the syllable-sequencing logic are verified mechanically (queue
  advances, durations are sane, no hang); how it actually *sounds* —
  whether the pitch/mood bias reads as intended, whether moonsong-then-
  TTS feels like one beat or two — needs producer ears.
- **Save-slot "continue vs. new nap" CHOICE (deliverable 6, partial by
  design)**: shipped the safe half — a text-free dream-count summary
  (gold pip + numeral) on the title screen when a save already has
  progress in it, visible in the title screenshot above. Deliberately
  **skipped** the destructive half (a "New Nap" save-wipe action) because
  nothing in this pass builds a confirm-gesture for a *destructive*
  action other than the Sleep hold-ring pattern, and bolting a save-wipe
  onto a UI element with no confirm would violate the same
  "no-quit/no-destructive-action-without-confirm" principle the hold
  ring exists to satisfy. Honest-skip per the brief's own instruction
  ("Honest-skip if tight").
- **`settings.camera_manual`/`camera_sensitivity` actually driving the
  camera**: confirmed via `grep -rl "camera_manual\|camera_sensitivity"`
  that no file outside this pass's own territory reads either key yet —
  expected; the brief is explicit that "a parallel agent's camera reads
  GameState settings — just persist them," which is fully done and
  verified (§e). The camera itself not reading them yet is that other
  system's open item, not this one's.
- **`rescue`, `mission_race/ride/shy/duet`, `move_*_first`,
  `world_complete` keys**: written, registered in
  `data/moon_lines.json`, and confirmed loadable (the line table doesn't
  error on any key at boot), but have no call site in this pass by
  design — see `docs/design/NARRATION_BIBLE.md`'s "Keys prepared for
  other systems" section for why and who owns wiring each one.

## Files touched

`scripts/autoloads/{game_state,save_manager,audio_manager,the_moon}.gd`
· `data/moon_lines.json` · `docs/design/NARRATION_BIBLE.md` ·
`tools/audio_gen/generate_voice.py` (new) ·
`assets/audio/voice/moon_syl_00..09.ogg` (new) ·
`scenes/ui/{subtitle_ribbon,star_field,big_moon,sleeping_cat,
floating_letter,hold_ring}.gd` (new) ·
`scenes/ui/{icon_draw,pause_menu,game_ui}.gd` · `scenes/title.{gd,tscn}`
· this file.
