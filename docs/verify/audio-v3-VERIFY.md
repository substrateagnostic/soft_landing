# AUDIO V3 — VERIFICATION (2026-07-17)

served_model: claude-fable-5 (Fable 5), acting as the audio pass 3 build
agent directly (no external model calls this pass).

Engine: `D:\Tools\godot\Godot_v4.6.2-stable_win64_console.exe` →
`4.6.2.stable.official.71f334935`, Windows. Generator: `C:\Python314\python.exe`
3.14.0 + numpy 2.5.1. Converter: `ffmpeg 8.1.2-essentials` at
`D:\Tools\ffmpeg\ffmpeg-8.1.2-essentials_build\bin\ffmpeg.exe` (+bitexact).
All commands run from `D:\Projects\soft_landing`. Territory (per brief):
`tools/audio_gen/generate_audio_v3.py` (new), `assets/audio/**` (new files),
`scripts/autoloads/audio_manager.gd` (additive only), one-line play-call
wiring in `worlds/bramble/{rollover_sequence,heartbeat_crossing,
breath_weather}.gd`, `worlds/wisp/dive_sequence.gd`,
`worlds/marmalade/stretch_sequence.gd`, and this doc. No git commits made.

**Concurrent-session note:** while this pass ran, another agent generalized
the cine-camera/letterbox machinery out of the three sequence files into
`core/cinematic/cine_sequence.gd` (the M4 card). All of this pass's wiring
lines were re-verified intact after that refactor landed (grep receipts +
full re-runs of all three sequences below, §6), and placements + world
boots were re-checked green afterwards (§5).

## 1. Generator — `tools/audio_gen/generate_audio_v3.py` (new file)

Imports `generate_audio.py` (V1 DSP toolkit) and `generate_audio_v2.py`
(for `to_ogg_bitexact()` — the `-fflags +bitexact` container-determinism
technique) as modules; zero edits to either. Register floor held by
construction: no percussion — every thump is a low sine glide with a
raised-cosine attack ≥ 10 ms; every texture is filtered/swept pink noise;
every one-shot is DC-removed and declicked to true zero at both ends.

```
C:/Python314/python.exe tools/audio_gen/generate_audio_v3.py
```

Exit 0. **Ran twice; every sha256 byte-identical run-to-run**
(determinism proven on container bytes, not just PCM):

```
file                                     dur(s)   peak(dBFS)  sha256[:16]
assets/audio/sfx/giant_rumble.ogg          4.00        -9.00  b887ffd750bd076f
assets/audio/sfx/giant_yawn_sigh.ogg       3.00        -9.00  50d0843a32cb95fa
assets/audio/sfx/debris_soft_tumble.ogg    2.50       -10.00  bcbc68b94d7fe222
assets/audio/sfx/water_rise_shimmer.ogg    4.00        -9.00  88329f93b381967b
assets/audio/sfx/roof_slide_soft.ogg       2.00       -10.00  f397e07b0bb198d8
assets/audio/sfx/heartbeat_thump.ogg       1.20       -10.00  4e6b9455c838089a
assets/audio/sfx/gust_breath.ogg           2.50        -9.00  82292009060f1500
```

Per-file peaks all -10 to -9 dBFS, inside the brief's -12 to -8 window —
well under the lullaby stems' mix ceiling (`BRAMBLE_TARGETS_DB` tops out at
-7 for layer_2; these one-shots sit 2-3 dB below that).

Sound designs (all synthesized, deterministic per-name seeds):
- **giant_rumble** (4.0s): 40-70 Hz sine, pitch drifting on one slow LFO
  cycle spanning the duration + lowpassed (140 Hz) noise breath; 0.7s
  attack / 1.8s release swell.
- **giant_yawn_sigh** (3.0s): noise sweep closing 2400→350 Hz + faint
  vocal-ish formant (150→90 Hz sine glide with a 1.5x partial).
- **debris_soft_tumble** (2.5s): 5 staggered soft thuds (85→50 Hz glides,
  14 ms attacks, each successive one quieter) + lowpassed-noise "give" —
  felt, not stone.
- **water_rise_shimmer** (4.0s): noise sweeping up 400→2000 Hz + 5 sparse
  pentatonic droplet bells (A5/C6/D6/E6).
- **roof_slide_soft** (2.0s): felt-on-felt — one slow up-down noise sweep
  500→1300→700 Hz.
- **heartbeat_thump** (1.2s): lub (t=0, 70→48 Hz glide) + dub (t=0.42s,
  0.6 amplitude — the exact secondary-beat weight
  `heartbeat_crossing.gd`'s own light pulse already uses) + 180 Hz-lowpassed
  noise give. One play spans one full 0.9s pulse cycle; declicked to true
  zero both ends so back-to-back retriggers are seam-safe.
- **gust_breath** (2.5s): broad wind swell, noise opening 300→1600 Hz on a
  raised-cosine sweep shape.

## 2. ffprobe + import

All 7 files: `48000,1,<dur>` (48 kHz mono), durations matching the
generator's report exactly. Headless import pass
(`--headless --editor --import --quit`) exit 0, all 7 reimported, zero
`ERROR:` lines. All 7 `.import` sidecars present; `loop=false` (importer
default) on all — correct: every one of these is a one-shot (heartbeat_
thump is retriggered by the crossing's own pulse logic, not looped).

## 3. AudioManager — additive changes only

- Header doc-comment listing the 7 new registered names and their call
  sites (the flat `assets/audio/sfx/` pool needs no registry — `play_sfx()`
  reads any name from disk — so "registration" is the documented contract).
- **`play_sfx_overlay(sfx_name)`** (new, additive): identical
  lookup/fail-soft to `play_sfx()`, but plays on an ephemeral
  `AudioStreamPlayer` (SFX bus, freed on `finished`) instead of the shared
  `_sfx_player`. Reason found while wiring: `bubble_effect.gd`'s
  `bubble_catch` and this pass's own second beats fire in the **same
  synchronous frame** as `giant_rumble` in all three sequences — on the
  shared player, last-call-wins silently swallowed the rumble. Mirrors
  `core/audio/player_audio.gd`'s established own-player convention (audio
  v2), lifted to a one-line call. No existing API touched.

## 4. Wiring (play-call lines only; nothing else changed in these files)

| File | Call | Beat |
|---|---|---|
| bramble/rollover_sequence.gd | `play_sfx_overlay("giant_rumble")` | sequence start (replaces unbacked `bear_rollover_rumble`) |
| bramble/rollover_sequence.gd | `play_sfx("giant_yawn_sigh")` | "wake" keystone clip |
| bramble/rollover_sequence.gd | `play_sfx_overlay("debris_soft_tumble")` | `_trigger_dressing_reveal()` — the single choke point both keystone + fallback paths call (mountain_dressing.gd untouched, per territory) |
| bramble/heartbeat_crossing.gd | `play_sfx("heartbeat_thump")` | at pulse trigger, rate-limited by its own existing `RECEIPT_COOLDOWN` (2s) logic |
| bramble/breath_weather.gd | `play_sfx("gust_breath")` | `force_gust()` |
| wisp/dive_sequence.gd | `play_sfx_overlay("giant_rumble")` | sequence start (replaces unbacked `whale_dive_sigh`) |
| wisp/dive_sequence.gd | `play_sfx("giant_yawn_sigh")` | whale settled beat |
| wisp/dive_sequence.gd | `play_sfx_overlay("water_rise_shimmer")` | flood-route reveal / rise tween |
| marmalade/stretch_sequence.gd | `play_sfx_overlay("giant_rumble")` | sequence start (replaces `bear_rollover_rumble` placeholder reuse) |
| marmalade/stretch_sequence.gd | `play_sfx("roof_slide_soft")` | `_tween_plates()` |
| marmalade/stretch_sequence.gd | `play_sfx("giant_yawn_sigh")` | arch (stretch apex) |

## 5. Boot + placements — 4/4 green after all edits

`--skipmenu --world=<id> --pads=2 --quitafter=4` for all four worlds: zero
errors, zero `not found` lines except the two pre-existing
wisp/marmalade `stem layer not found` gaps (music-stems-spec.md's own
"write nothing yet"). `check_placements.gd`:
`PLACEMENT_SUMMARY {"any_fail":false}` for bramble, pillow_fort, wisp, and
marmalade — re-run AFTER the concurrent cine_sequence refactor landed.
`--pads=0/1/2` regression boots: zero new ERROR/SCRIPT ERROR lines.

## 6. Sequence dry-runs — headless, post-refactor, post-overlay-swap

All three forced sequences run clean end-to-end with the new wiring, zero
`not found` for any of the 7 new names, zero script errors:

- `--world=bramble --rollover --quitafter=45`: full phase chain
  start → force_gust → wake/breathe/toss_turn keystones → end. The only
  `not found` lines are 3x pre-existing `breath_exhale.ogg` (breathing
  chest, outside territory, pre-existing gap audio-v2-VERIFY.md already
  documented).
- `--world=marmalade --stretch --quitafter=40`: start → nook_revealed →
  plates_shifting → arch → plates_shifted → resettle → route_open → end.
- `--world=wisp --dive --quitafter=25`: start → settled → routes_open → end.
- **heartbeat_thump live trigger**: re-ran the existing
  `bramble_disguise_joy.json` harness script (Pip teleports onto
  AscentLedge3 and holds) — `HEARTBEAT {"seat":"Pip"}` fired with zero
  `heartbeat_thump not found`, i.e. the play call at the pulse trigger
  loaded and played the real asset.

## 7. Windowed movie receipts + volumedetect

Both windowed (never headless), `--write-movie` + `--fixed-fps 60`,
transcoded to mp4 per the house recipe:

```
godot_console.exe --path . --write-movie evidence/audio_v3_rollover.avi --fixed-fps 60 --resolution 1280x720 -- --skipmenu --world=bramble --pads=2 --rollover --quitafter=45
godot_console.exe --path . --write-movie evidence/audio_v3_stretch.avi  --fixed-fps 60 -- --skipmenu --world=marmalade --pads=2 --stretch --quitafter=40
```

(2701 frames / 45.0s and 2401 frames / 40.0s respectively, both exit
clean; the stretch capture recorded at 1920x1080 — the `--resolution`
flag was dropped by the detached launcher's quoting; cosmetic only,
audio receipts unaffected.)

`ffmpeg -af volumedetect` (audio confirmed `pcm_s16le, 48000 Hz, stereo`):

| Clip / window | mean_volume | max_volume |
|---|---|---|
| **audio_v3_rollover.avi, full 45s** | **-13.6 dB** | **-0.1 dB** |
| rollover: pre-trigger baseline (0-2.9s) | -12.5 dB | -0.1 dB |
| rollover: rumble/gust onset (3.0-7.5s) | -12.7 dB | -0.1 dB |
| rollover: keystone window (8-32s, yawn+debris) | -13.5 dB | -0.1 dB |
| **audio_v3_stretch.avi, full 40s** | **-21.6 dB** | **-4.4 dB** |
| stretch: pre-trigger baseline (0-2.9s) | -17.1 dB | -4.4 dB |
| stretch: start rumble+slide (3.0-5.0s) | -17.5 dB | -4.4 dB |
| stretch: arch yawn_sigh (5.0-8.0s) | -18.4 dB | -4.4 dB |
| stretch: post-sequence ambient (32-39s) | -21.5 dB | -4.4 dB |
| prior showcase `three_keystones.mp4` (known prior mean) | -16.8 dB | — |
| prior `k_bear.mp4` (27s trimmed keystone cut) | -13.4 dB | -0.5 dB |
| prior `k_cat.mp4` (27s trimmed keystone cut) | -20.3 dB | -2.5 dB |

Reading these honestly:
- **Rollover** full-clip mean **-13.6 dB vs the known prior showcase mean
  ≈ -16.8 dB — 3.2 dB richer**, as the brief predicted. Bramble's own
  loud bed (layer_1 stem + ambience + giggle/geyser traffic, baseline mean
  -12.5) compresses the *within-clip* window deltas, so the per-name fire
  proof for rollover is the §6 receipt (the three former
  `bear_rollover_rumble` no-op prints are GONE and no new name prints
  `not found` while the phases fire), not the window table alone.
- **Stretch** sequence windows are **3-4 dB hotter than the same clip's
  own post-sequence ambient tail** (-17.5/-18.4 vs -21.5 mean) — the
  set-piece beats are audible over marmalade's quiet bed. The early
  windows include the Moon's `world_complete` TTS line (fires in the same
  beat, by design — it did before this pass too). Stretch's full-clip
  mean (-21.6) is NOT above the prior -15to-17 showcase band because that
  band was measured on a bramble-heavy trimmed showcase; marmalade has no
  stems yet (pre-existing gap) and a -23 dBFS ambience bed, so its
  absolute level is inherently lower. Its own prior cut (`k_cat.mp4`,
  -20.3 mean) was captured **while the sequence played a missing-file
  no-op**, i.e. with zero set-piece audio; the new capture's sequence
  windows sit ~2-3 dB above that clip's mean despite the new capture
  including 16s of quiet tail the trim excluded.
- The constant -4.4 dB max across every stretch window is the dreamling
  giggle/critter traffic (fires continuously through the whole capture,
  see the render log) — not a set-piece sound clipping.

## UNVERIFIED

- **Windowed captures predate the `play_sfx_overlay` swap.** Both movies
  were recorded with the initial `play_sfx` wiring, where same-frame
  `bubble_catch` cut `giant_rumble` short (the exact defect the overlay
  fix then removed). The overlay wiring is receipted headless (§6: clean
  phase chains, assets load, zero errors) but no *re-recorded* movie
  proves its audible mix; the sounds themselves are identical assets.
  First re-capture of any keystone will double as the overlay's audible
  receipt.
- **Subjective listening pass** (does the rumble read as "tender-enormous"
  on real speakers) — same caveat V1/V2's VERIFY docs carry; peaks,
  attacks ≥ 10 ms, no-percussion-by-construction, and fire receipts are
  what's proven above.
- **Wisp dive windowed capture** — the brief asked for movie+volumedetect
  of rollover and stretch only; the dive's water_rise_shimmer/yawn beats
  are receipted headless (§6), not by ear.
- **heartbeat_crossing.gd's header comment is now stale** (it documents
  "the call site is deliberately absent" from the pre-asset era). The
  brief's "change NOTHING else in those files" kept me from touching the
  header; the director should trim that paragraph at next pass.

## Files touched

- New: `tools/audio_gen/generate_audio_v3.py`, `docs/verify/audio-v3-VERIFY.md`
- New: `assets/audio/sfx/{giant_rumble,giant_yawn_sigh,debris_soft_tumble,water_rise_shimmer,roof_slide_soft,heartbeat_thump,gust_breath}.ogg` (+`.import`)
- Modified (additive): `scripts/autoloads/audio_manager.gd` (header doc + `play_sfx_overlay()`)
- Wiring (play-call lines only): `worlds/bramble/{rollover_sequence,heartbeat_crossing,breath_weather}.gd`, `worlds/wisp/dive_sequence.gd`, `worlds/marmalade/stretch_sequence.gd`
- Evidence: `evidence/audio_v3_rollover.{avi,mp4}`, `evidence/audio_v3_stretch.{avi,mp4}`
