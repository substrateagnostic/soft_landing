#!/usr/bin/env python3
"""tools/audio_gen/generate_audio_v3.py — THE BIG NAP procedural audio, V3
pass: keystone set-piece sounds (the three giants' rollover/dive/stretch
sequences currently call `AudioManager.play_sfx("bear_rollover_rumble")`,
which has no asset and fails soft) plus the Heartbeat Crossing thump and the
Breath Weather gust.

Imports tools/audio_gen/generate_audio.py (`ga`) and tools/audio_gen/
generate_audio_v2.py (`gav2`) as modules — same pattern V2 established for
V1 (generate_audio_v2.py imports generate_audio.py verbatim). Nothing in
either prior file is modified; this is a pure additive sibling. Reuses
`gav2.to_ogg_bitexact()` (the `-fflags +bitexact` technique, needed for
byte-reproducible `.ogg` containers) for every output here, same as V2.

REGISTER (binding, unchanged — see AGENTS.md / docs/design/
music-stems-spec.md / this file's own brief): soft pillow-world physics,
NO percussion anywhere (every "thump"/"tumble"/"slide" is a low sine glide
or lowpassed noise with a raised-cosine attack >= 10 ms, never a hard
transient). Peaks target -12 to -8 dBFS — well under the 32 s lullaby
stems' own mix ceiling (docs/design/music-stems-spec.md), documented per
sound below and in the printed summary table.

OUTPUTS (flat res://assets/audio/sfx/ pool — AudioManager.play_sfx() /
load_sfx_stream() already read any name from there, so no new directory or
AudioManager API is needed; see audio_manager.gd's own additive doc-comment
for the registered-name list):
  assets/audio/sfx/giant_rumble.ogg          (~4.0s)
  assets/audio/sfx/giant_yawn_sigh.ogg       (~3.0s)
  assets/audio/sfx/debris_soft_tumble.ogg    (~2.5s)
  assets/audio/sfx/water_rise_shimmer.ogg    (~4.0s)
  assets/audio/sfx/roof_slide_soft.ogg       (~2.0s)
  assets/audio/sfx/heartbeat_thump.ogg       (~1.2s, a lub-dub pair)
  assets/audio/sfx/gust_breath.ogg           (~2.5s)

Usage:
    C:/Python314/python.exe tools/audio_gen/generate_audio_v3.py
"""

from __future__ import annotations

import hashlib
import os
import sys
import tempfile

import numpy as np

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(THIS_DIR, "..", ".."))
sys.path.insert(0, THIS_DIR)
import generate_audio as ga  # noqa: E402  (path must be set up first)
import generate_audio_v2 as gav2  # noqa: E402  (reuses to_ogg_bitexact)

SFX_DIR = ga.SFX_DIR
SCRATCH_DIR = os.path.join(tempfile.gettempdir(), "soft_landing_audio_gen_v3")

SR = ga.SR
NOTE_HZ = ga.NOTE_HZ
BELL_PARTIALS = ga.BELL_PARTIALS


# =========================================================================
# 1. giant_rumble — the ground remembering it's alive. Used by all three
# keystone sequences (rollover/dive/stretch) at their start, replacing the
# unbacked "bear_rollover_rumble" name every sequence currently calls.
# =========================================================================

def make_giant_rumble() -> np.ndarray:
    """A deep gentle sub-swell: a 40-70 Hz sine core whose own pitch drifts
    on one slow LFO cycle spanning the whole duration (so it breathes
    rather than drones at a fixed pitch), under a very quiet lowpassed-
    noise "breath" bed for texture. One swell envelope (0.7 s attack, 1.8 s
    release) so nothing snaps in or out. ~4.0 s."""
    dur = 4.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    lfo = np.sin(2.0 * np.pi * t / dur)  # exactly one slow cycle over the whole sound
    freq = 55.0 + 15.0 * lfo
    tone = np.sin(2.0 * np.pi * np.cumsum(freq) / SR)
    rng = ga.seeded_rng("giant_rumble_breath")
    breath = ga.lowpass_fft(ga.pink_noise(n, rng), SR, 140.0, shoulder_hz=60.0)
    env = ga.env_swell(t, dur=dur, attack=0.7, release=1.8)
    x = (0.85 * tone + 0.22 * breath) * env
    return ga.finalize_oneshot(x, fade_in_ms=15.0, fade_out_ms=250.0)


# =========================================================================
# 2. giant_yawn_sigh — a huge soft exhale. Bear wake beat (rollover), whale
# settle (dive), cat stretch apex (stretch).
# =========================================================================

def make_giant_yawn_sigh() -> np.ndarray:
    """A filtered-noise sweep CLOSING (bright 2400 -> 350 Hz across the
    whole duration, the "sigh releasing" direction — same convention as
    generate_audio_v2.py's ui/pause_close) under a faint low vocal-ish
    formant: a slow downward sine glide (150 -> 90 Hz) with a quiet second
    partial at 1.5x, standing in for an exhale's own resonance without
    reading as a literal voice. One shared swell envelope (0.35 s attack,
    2.0 s release). ~3.0 s."""
    dur = 3.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("giant_yawn_sigh")
    sweep_env = 1.0 - (t / t[-1])  # 1 (bright) at t=0 -> 0 (dull) at t=dur
    breath = ga.swept_noise(n, rng, 350.0, 2400.0, sweep_env=sweep_env)
    formant_freq = 150.0 + (90.0 - 150.0) * (t / t[-1])
    formant = np.sin(2.0 * np.pi * np.cumsum(formant_freq) / SR)
    formant += 0.35 * np.sin(2.0 * np.pi * np.cumsum(formant_freq * 1.5) / SR)
    env = ga.env_swell(t, dur=dur, attack=0.35, release=2.0)
    x = (0.7 * breath + 0.30 * formant) * env
    return ga.finalize_oneshot(x, fade_in_ms=15.0, fade_out_ms=250.0)


# =========================================================================
# 3. debris_soft_tumble — mountain_dressing reveal (wired from
# rollover_sequence.gd's own _trigger_dressing_reveal(), the single choke
# point both its keystone-clip and rigid-roll-fallback paths already call
# through — mountain_dressing.gd itself is out of this pass's territory).
# =========================================================================

def make_debris_soft_tumble() -> np.ndarray:
    """Muffled soft thumps cascading — a few staggered lowpassed thuds
    (felt, not stone): each event is a short low sine glide (like
    generate_audio.py's land_soft/generate_audio_v2.py's pound_land thump
    technique) plus a burst of heavily lowpassed noise "give", raised-
    cosine attack >= 10 ms on every event. 5 onsets, staggered with a fixed
    seed so the cascade breathes rather than ticks metronomically. ~2.5 s."""
    dur = 2.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("debris_soft_tumble")
    onsets = np.sort(rng.uniform(0.0, dur - 0.5, size=5))
    x = np.zeros(n)
    for i, t0 in enumerate(onsets):
        thump_dur = 0.09
        tt = np.linspace(0.0, thump_dur, int(thump_dur * SR), endpoint=False)
        thump_freq = 85.0 * (50.0 / 85.0) ** (tt / thump_dur)
        thump = np.sin(2.0 * np.pi * np.cumsum(thump_freq) / SR) * ga.env_pluck(tt, 0.0, 0.014, 0.08)
        i0 = int(t0 * SR)
        i1 = min(i0 + len(thump), n)
        x[i0:i1] += thump[: i1 - i0] * (0.85 - 0.08 * i)  # each successive tumble a hair quieter

        noise = ga.lowpass_fft(ga.pink_noise(n, ga.seeded_rng("debris_soft_tumble_noise_%d" % i)), SR, 220.0)
        x += 0.22 * noise * ga.env_pluck(t, t0, 0.015, 0.10)
    return ga.finalize_oneshot(x, fade_in_ms=10.0, fade_out_ms=180.0)


# =========================================================================
# 4. water_rise_shimmer — the dive sequence's flood beat (the moment the
# flood route's collision goes solid and the water-rise tween begins).
# =========================================================================

def make_water_rise_shimmer() -> np.ndarray:
    """A gentle rising water texture: filtered noise sweeping UP (400 ->
    2000 Hz across the whole duration, sweep_env = t/dur, the "opening"
    direction) plus sparse pentatonic droplet bell tones (5 onsets, quiet,
    high register) landing over the swell — echoes the flood cushions'
    own blush/cream/sage palette in sound rather than sight. One swell
    envelope (0.5 s attack, 1.6 s release). ~4.0 s."""
    dur = 4.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("water_rise_shimmer")
    rise = ga.swept_noise(n, rng, 400.0, 2000.0, sweep_env=t / t[-1])
    env = ga.env_swell(t, dur=dur, attack=0.5, release=1.6)
    x = 0.65 * rise * env

    droplet_pitches = [NOTE_HZ["C6"], NOTE_HZ["D6"], NOTE_HZ["E6"], NOTE_HZ["A5"], NOTE_HZ["D6"]]
    rng_drop = ga.seeded_rng("water_rise_shimmer_droplets")
    onsets = np.sort(rng_drop.uniform(0.6, dur - 0.4, size=len(droplet_pitches)))
    for freq, t0 in zip(droplet_pitches, onsets):
        x += 0.20 * ga.additive_tone(freq, t, t0, attack=0.015, tau=0.35, partials=BELL_PARTIALS)
    return ga.finalize_oneshot(x, fade_in_ms=15.0, fade_out_ms=220.0)


# =========================================================================
# 5. roof_slide_soft — the stretch sequence's plate-shift beat (RoofB0-3
# sliding into their new chain positions).
# =========================================================================

def make_roof_slide_soft() -> np.ndarray:
    """A felt-on-felt sliding whoosh: swept noise opening then gently
    closing (500 -> 1300 -> 700 Hz, a single slow up-down sweep across the
    whole duration, standing in for a plate sliding past and settling)
    under a soft swell envelope (0.2 s attack, 1.1 s release). ~2.0 s."""
    dur = 2.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("roof_slide_soft")
    half = dur / 2.0
    sweep_env = np.where(t < half, t / half, 1.0 - (t - half) / half)
    slide = ga.swept_noise(n, rng, 500.0, 1300.0, sweep_env=np.clip(sweep_env, 0.0, 1.0))
    env = ga.env_swell(t, dur=dur, attack=0.2, release=1.1)
    x = slide * env * 0.75
    return ga.finalize_oneshot(x, fade_in_ms=12.0, fade_out_ms=160.0)


# =========================================================================
# 6. heartbeat_thump — the Heartbeat Crossing's lub-dub, synced to its own
# existing pulse timing (worlds/bramble/heartbeat_crossing.gd: PULSE_PERIOD
# = 0.9 s, a sharp primary "lub" beat early in the cycle then a softer
# "dub" partway through — this asset mirrors that exact two-beat shape so
# one play lines up with one full pulse cycle).
# =========================================================================

def make_heartbeat_thump() -> np.ndarray:
    """Two soft sub thumps (lub-dub, ~55 Hz core, pillow-muffled): the
    "lub" at t=0 (slightly louder/longer, matching HeartbeatCrossing's own
    primary-beat weighting) and the "dub" at t=0.42s (softer, ~60% amplitude
    — same 0.6 relative weight heartbeat_crossing.gd's own pulse() already
    uses for its second beat), each a low sine glide with a >= 10 ms raised-
    cosine attack plus a little lowpassed noise "give". Finalized as a
    clean one-shot (DC-removed, fades to true zero both ends) so it is
    loop-safe to retrigger back-to-back without a click, matching the
    "loopable pair" ask without requiring a true seamless-loop crossfade
    for a rate-limited, rarely-back-to-back trigger. ~1.2 s."""
    dur = 1.2
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)

    def _thump(t0: float, weight: float, thump_dur: float) -> None:
        tt = np.linspace(0.0, thump_dur, int(thump_dur * SR), endpoint=False)
        thump_freq = 70.0 * (48.0 / 70.0) ** (tt / thump_dur)
        thump = np.sin(2.0 * np.pi * np.cumsum(thump_freq) / SR) * ga.env_pluck(tt, 0.0, 0.014, thump_dur * 0.75)
        i0 = int(t0 * SR)
        i1 = min(i0 + len(thump), n)
        nonlocal x
        x[i0:i1] += weight * thump[: i1 - i0]

    _thump(0.0, 1.0, 0.16)   # lub
    _thump(0.42, 0.6, 0.13)  # dub -- softer, matches heartbeat_crossing.gd's own 0.6 secondary-beat weight

    rng = ga.seeded_rng("heartbeat_thump_give")
    noise = ga.lowpass_fft(ga.pink_noise(n, rng), SR, 180.0)
    give_env = ga.env_pluck(t, 0.0, 0.015, 0.12) + 0.6 * ga.env_pluck(t, 0.42, 0.015, 0.10)
    x += 0.18 * noise * give_env
    return ga.finalize_oneshot(x, fade_in_ms=10.0, fade_out_ms=260.0)


# =========================================================================
# 7. gust_breath — Breath Weather's force_gust() exhale (D25 finale reveal,
# worlds/bramble/breath_weather.gd).
# =========================================================================

def make_gust_breath() -> np.ndarray:
    """A broad soft wind swell: filtered noise opening (300 -> 1600 Hz
    across the attack/hold, sweep_env eased with a raised-cosine rather
    than linear so the "gust" arrives gradually) under a swell envelope
    (0.4 s attack, 1.3 s release) — matches breath_weather.gd's own
    exhale_duration register (a single deliberate gust, not a hiss).
    ~2.5 s."""
    dur = 2.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("gust_breath")
    sweep_shape = 0.5 * (1.0 - np.cos(np.pi * np.clip(t / (dur * 0.6), 0.0, 1.0)))
    gust = ga.swept_noise(n, rng, 300.0, 1600.0, sweep_env=sweep_shape)
    env = ga.env_swell(t, dur=dur, attack=0.4, release=1.3)
    x = gust * env * 0.8
    return ga.finalize_oneshot(x, fade_in_ms=15.0, fade_out_ms=220.0)


SFX_V3_MANIFEST: list[tuple[str, object, float]] = [
    ("giant_rumble",        make_giant_rumble, -9.0),
    ("giant_yawn_sigh",     make_giant_yawn_sigh, -9.0),
    ("debris_soft_tumble",  make_debris_soft_tumble, -10.0),
    ("water_rise_shimmer",  make_water_rise_shimmer, -9.0),
    ("roof_slide_soft",     make_roof_slide_soft, -10.0),
    ("heartbeat_thump",     make_heartbeat_thump, -10.0),
    ("gust_breath",         make_gust_breath, -9.0),
]


# =========================================================================
# Main
# =========================================================================

def main() -> int:
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(SCRATCH_DIR, exist_ok=True)

    print("=== THE BIG NAP -- audio v3 generator (keystone set-piece sounds) ===")
    print(f"sample rate: {SR} Hz mono | ffmpeg: {ga.FFMPEG} (+bitexact)")
    print(f"wav scratch: {SCRATCH_DIR}")
    print()

    report_rows: list[tuple[str, float, float]] = []
    hashes: dict[str, str] = {}

    def _emit(name: str, x: np.ndarray) -> None:
        wav_path = os.path.join(SCRATCH_DIR, f"{name}.wav")
        ogg_path = os.path.join(SFX_DIR, f"{name}.ogg")
        ga.write_wav(wav_path, x)
        gav2.to_ogg_bitexact(wav_path, ogg_path)
        dur, pdb = len(x) / SR, ga.peak_db(x)
        with open(ogg_path, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        rel = os.path.relpath(ogg_path, REPO).replace(os.sep, "/")
        report_rows.append((rel, dur, pdb))
        hashes[rel] = digest
        print(f"  {rel:<38s} {dur:6.2f}s  peak {pdb:7.2f} dBFS  sha256 {digest[:16]}")

    print("--- SFX v3 (assets/audio/sfx/) ---")
    for name, gen_fn, target_db in SFX_V3_MANIFEST:
        x = ga.normalize_to_peak(gen_fn(), target_db)
        _emit(name, x)

    print()
    print("=== Peak-level / hash summary table ===")
    print(f"{'file':<38s} {'dur(s)':>8s} {'peak(dBFS)':>12s}  sha256[:16]")
    for name, dur, pdb in report_rows:
        print(f"{name:<38s} {dur:8.2f} {pdb:12.2f}  {hashes[name][:16]}")

    print()
    print("Done. Re-run and diff the sha256 column above to confirm determinism.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
