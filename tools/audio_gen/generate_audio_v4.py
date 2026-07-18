"""generate_audio_v4.py — audio pass 4: the three worlds without music.

Fills the two gaps NEEDS_YOU.md has carried since the tortoise shipped:
  assets/audio/ambience/tortoise.ogg          — the missing fifth bed
  assets/audio/stems/{tortoise,wisp,marmalade}/layer_[1-4].ogg
                                              — lullabies for every giant

Same contracts as generate_audio.py's bramble stems (32 s @ 60 bpm, four
layers: drone / melody / pizz-dots / shimmer, per-layer peak targets, a
summed-mix ceiling check per world) and generate_audio_v2.py's ambience
beds (36 s quiet loops, bitexact ogg). Deterministic throughout: fixed
seeds, -fflags +bitexact encodes, sha256 printed per file.

World identities (docs/design/music-stems-spec.md; tortoise is new —
logged here as its spec):
  WISP      — F major, slower still (8 s breath), melody as long slow
              glissandi (portamento phase-integration, not note plucks) —
              "breathing underwater".
  MARMALADE — G major, a hint of playfulness: dotted lullaby cell,
              pizzicato-forward third layer (denser, with grace-note
              double plucks).
  TORTOISE  — C major, the slowest lullaby in the game: ~10.7 s drone
              breath (the world's own shell breathes at 14 s — same
              register of patience), a four-whole-note melody, pizz on
              sparse DOWNbeats (grounded, not floating), rare shimmer.

Run:  python tools/audio_gen/generate_audio_v4.py
Then: godot --headless --import; flip loop=true in each new .ogg.import
      (tools/audio_gen never edits .import files itself — see the wave
      notes); re-import; boot-verify.
"""
from __future__ import annotations

import hashlib
import os
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import generate_audio as ga  # noqa: E402
import generate_audio_v2 as v2  # noqa: E402

SR = ga.SR
STEMS_DIR = ga.STEMS_DIR
AMBIENCE_DIR = v2.AMBIENCE_DIR
LOOP_SECONDS = ga.LOOP_SECONDS
XFADE_MS = ga.XFADE_MS
AMBIENCE_LOOP_SECONDS = v2.AMBIENCE_LOOP_SECONDS
AMBIENCE_XFADE_MS = v2.AMBIENCE_XFADE_MS

# Same per-layer peak targets as bramble's (generate_audio.py) — the four
# lullabies must sit at the same couch volume as the first one.
LAYER_TARGETS_DB = {1: -9.0, 2: -7.0, 3: -10.0, 4: -18.0}
MIX_CEILING_DB = -1.0


def hz(midi: int) -> float:
    """Equal-temperament frequency for a MIDI note number (A4=69=440)."""
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


# MIDI note names used below (C4=60 convention).
F2, C3, F3, G3, A3, C4_, F4, G4, A4_, C5, D5 = 41, 48, 53, 55, 57, 60, 65, 67, 69, 72, 74
G2, D3, E4, D4, B4, G5, A5, B5, D6, E5 = 43, 50, 64, 62, 71, 79, 81, 83, 86, 76
C2, E5_, G5_, C6, E6, G6 = 36, 76, 79, 84, 88, 91


def _glide_melody_gen(anchor_midis: list[tuple[float, int]], phrase_len: float,
                      lowpass_hz: float, seed_name: str):
    """A melody that SLIDES between anchor pitches instead of plucking
    them: piecewise-linear frequency curve integrated to phase (cumsum),
    so the line is one continuous portamento voice. anchor_midis is
    [(beat, midi)] within one phrase; the phrase tiles the loop."""
    def gen(t: np.ndarray) -> np.ndarray:
        tp = np.mod(t, phrase_len)
        beats = np.array([b for b, _ in anchor_midis] + [phrase_len])
        freqs = np.array([hz(m) for _, m in anchor_midis] + [hz(anchor_midis[0][1])])
        f_of_t = np.interp(tp, beats, freqs)
        phase = 2.0 * np.pi * np.cumsum(f_of_t) / SR
        voice = np.sin(phase)
        # Breath-shaped amplitude so the line swells and releases rather
        # than droning: one arch per half-phrase.
        amp = 0.55 + 0.45 * np.sin(np.pi * np.mod(t, phrase_len / 2.0) / (phrase_len / 2.0))
        return ga.lowpass_fft(voice * amp, SR, cutoff_hz=lowpass_hz, shoulder_hz=lowpass_hz * 0.45)
    return gen


def _pluck_melody_gen(notes: list[tuple[float, float, int]], phrase_len: float,
                      lowpass_hz: float, core=ga.sawtooth):
    """generate_audio.py's _layer2_gen idiom, parameterized: [(start_beat,
    dur_beats, midi)] tiled across the loop, core-wave plucks, low-passed
    into placeholder-viola warmth."""
    def gen(t: np.ndarray) -> np.ndarray:
        x = np.zeros_like(t)
        n_repeats = int(np.ceil((t[-1] + 0.001) / phrase_len)) + 1
        for rep in range(n_repeats):
            offset = rep * phrase_len
            for start_beat, dur_beat, midi in notes:
                t0 = offset + start_beat
                attack = 0.02
                tau = max(dur_beat - attack, 0.05)
                x += 0.9 * core(hz(midi), t - t0) * ga.env_pluck(t, t0, attack, tau)
        return ga.lowpass_fft(x, SR, cutoff_hz=lowpass_hz, shoulder_hz=500.0)
    return gen


def _pizz_gen(pitch_midis: list[int], density: float, seed_name: str,
              on_downbeats: bool = False, grace_chance: float = 0.0):
    """generate_audio.py's _layer3_gen idiom, parameterized. density =
    fraction of candidate slots used; on_downbeats grounds the dots ON
    the beat (tortoise) instead of floating off it; grace_chance adds a
    quick double-pluck before some notes (marmalade's playful paw)."""
    def gen(t: np.ndarray) -> np.ndarray:
        rng = ga.seeded_rng(seed_name)
        x = np.zeros_like(t)
        total_beats = int(np.ceil(t[-1])) + 1
        slots = np.arange(0, total_beats) + (0.0 if on_downbeats else 0.5)
        n_pick = max(1, int(len(slots) * density))
        chosen = np.sort(rng.choice(slots, size=n_pick, replace=False))
        pitch_idx = rng.integers(0, len(pitch_midis), size=len(chosen))
        grace = rng.uniform(0.0, 1.0, size=len(chosen)) < grace_chance
        for t0, pi, g in zip(chosen, pitch_idx, grace):
            freq = hz(pitch_midis[pi])
            if g:
                x += 0.5 * ga.triangle(freq, t - (t0 - 0.11)) * ga.env_pluck(t, t0 - 0.11, 0.008, 0.10)
            x += 0.8 * ga.triangle(freq, t - t0) * ga.env_pluck(t, t0, attack=0.010, tau=0.22)
        return x
    return gen


def _shimmer_gen(pitch_midis: list[int], avg_gap_s: float, seed_name: str):
    """generate_audio.py's _layer4_gen idiom, parameterized: sparse bell
    tones at free onsets, near-subliminal after the -18 dB target."""
    def gen(t: np.ndarray) -> np.ndarray:
        rng = ga.seeded_rng(seed_name)
        x = np.zeros_like(t)
        n_events = max(4, int(t[-1] / avg_gap_s))
        onsets = np.sort(rng.uniform(0.0, t[-1], size=n_events))
        pitch_idx = rng.integers(0, len(pitch_midis), size=len(onsets))
        for t0, pi in zip(onsets, pitch_idx):
            x += ga.additive_tone(hz(pitch_midis[pi]), t, t0, attack=0.018,
                                  tau=0.75, partials=ga.BELL_PARTIALS, amp=0.6)
        return x
    return gen


def _drone(root_midi: int, fifth_midi: int, breath_period: float,
           swell_lo: float = 0.7, swell_hi: float = 1.0):
    """generate_audio.py's _drone_gen with a parameterized breath period
    (bramble fixed it at LOOP/6; wisp breathes slower, tortoise slowest)."""
    def gen(t: np.ndarray) -> np.ndarray:
        swell = swell_lo + (swell_hi - swell_lo) * 0.5 * (1.0 - np.cos(2.0 * np.pi * t / breath_period))
        root_tone = 0.85 * ga.sine(hz(root_midi), t) + 0.15 * ga.triangle(hz(root_midi), t)
        fifth_tone = 0.85 * ga.sine(hz(fifth_midi), t) + 0.15 * ga.triangle(hz(fifth_midi), t)
        return (0.6 * root_tone + 0.4 * fifth_tone) * swell
    return gen


# =========================================================================
# The three worlds
# =========================================================================

WORLD_STEMS = {
    # WISP — F major, slower still, glissandi like breathing underwater.
    "wisp": {
        1: _drone(F2, C3, breath_period=LOOP_SECONDS / 4.0),  # 8 s breath
        2: _glide_melody_gen(
            [(0.0, F3), (4.0, A3), (8.0, G3), (12.0, F3)],
            phrase_len=16.0, lowpass_hz=800.0, seed_name="wisp_gliss"),
        3: _pizz_gen([F4, G4, A4_, C5, D5], density=0.25, seed_name="wisp_layer3_drops"),
        4: _shimmer_gen([F4 + 24, G4 + 24, A4_ + 12, C5 + 12], avg_gap_s=3.5, seed_name="wisp_layer4_shimmer"),
    },
    # MARMALADE — G major, playful: dotted cell, pizzicato-forward.
    "marmalade": {
        1: _drone(G2, D3, breath_period=LOOP_SECONDS / 6.0),
        2: _pluck_melody_gen(
            [(0.0, 1.5, G4), (1.5, 1.0, B4), (2.5, 1.5, A4_), (4.0, 1.5, G4),
             (5.5, 1.0, E4), (6.5, 1.5, D4), (8.0, 1.5, G4), (9.5, 1.0, A4_),
             (10.5, 1.5, B4), (12.0, 1.0, A4_), (13.0, 3.0, G4)],
            phrase_len=16.0, lowpass_hz=1200.0),
        3: _pizz_gen([G5, B5, D6, A5, E5 + 12], density=0.5,
                     seed_name="marmalade_layer3_pizz", grace_chance=0.3),
        4: _shimmer_gen([G6, A5 + 12, B5 + 12, D6], avg_gap_s=3.0, seed_name="marmalade_layer4_shimmer"),
    },
    # TORTOISE — C major, the slowest lullaby in the game.
    "tortoise": {
        1: _drone(C2, G2, breath_period=LOOP_SECONDS / 3.0),  # ~10.7 s breath
        2: _pluck_melody_gen(
            [(0.0, 4.0, C4_), (4.0, 4.0, E4), (8.0, 4.0, D4), (12.0, 4.0, C4_)],
            phrase_len=16.0, lowpass_hz=900.0, core=ga.triangle),
        3: _pizz_gen([C5, E5_, G5_, D5], density=0.18,
                     seed_name="tortoise_layer3_steps", on_downbeats=True),
        4: _shimmer_gen([C6, D6, E6, G6], avg_gap_s=4.5, seed_name="tortoise_layer4_shimmer"),
    },
}


# TORTOISE ambience — the missing fifth bed: night-garden hush. Soil-warm
# pink-noise floor, leaf-rustle swells tied to the SAME ~10.7 s breath the
# lullaby drone uses, and sparse synthesized "garden tick" sparkles (the
# pillow_fort bed's dreamlike-not-literal cricket rule).
def _ambience_tortoise_gen(t: np.ndarray) -> np.ndarray:
    n = len(t)
    breath_period = LOOP_SECONDS / 3.0
    soil = ga.lowpass_fft(ga.pink_noise(n, ga.seeded_rng("ambience_tortoise_soil")), SR, 300.0) * 0.5

    swell = 0.45 + 0.55 * 0.5 * (1.0 - np.cos(2.0 * np.pi * t / breath_period))
    leaves = ga.swept_noise(n, ga.seeded_rng("ambience_tortoise_leaves"), 700.0, 2400.0,
                            sweep_env=0.3 + 0.15 * np.sin(2.0 * np.pi * t / 13.0)) * swell * 0.6

    rng_tick = ga.seeded_rng("ambience_tortoise_ticks")
    tick_onsets = np.sort(rng_tick.uniform(0.0, t[-1], size=10))
    ticks = np.zeros(n)
    for t0 in tick_onsets:
        ticks += ga.additive_tone(hz(C6 + rng_tick.integers(0, 5)), t, t0,
                                  attack=0.012, tau=0.28, partials=ga.BELL_PARTIALS, amp=0.16)
    return soil + leaves + ticks


def _sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _write_ogg(x: np.ndarray, ogg_path: str) -> None:
    os.makedirs(os.path.dirname(ogg_path), exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav_path = os.path.join(td, "tmp.wav")
        ga.write_wav(wav_path, x)
        v2.to_ogg_bitexact(wav_path, ogg_path)
    print(f"  {os.path.relpath(ogg_path, ga.REPO)}  peak={ga.peak_db(x):+.1f} dB  sha256={_sha256(ogg_path)[:16]}")


def main() -> int:
    for world, gens in WORLD_STEMS.items():
        print(f"--- STEMS: {world} (32 s loop, layers 1-4) ---")
        raw = {k: ga.render_seamless_loop(gen, LOOP_SECONDS, xfade_ms=XFADE_MS) for k, gen in gens.items()}
        normalized = {k: ga.normalize_to_peak(v, LAYER_TARGETS_DB[k]) for k, v in raw.items()}
        mix_peak = ga.peak_db(sum(normalized.values()))
        if mix_peak > MIX_CEILING_DB:
            scale = ga.db_to_amp(MIX_CEILING_DB) / ga.db_to_amp(mix_peak)
            normalized = {k: v * scale for k, v in normalized.items()}
            mix_peak = ga.peak_db(sum(normalized.values()))
        print(f"  summed mix peak: {mix_peak:+.1f} dBFS (ceiling {MIX_CEILING_DB:+.1f})")
        for layer, x in normalized.items():
            _write_ogg(x, os.path.join(STEMS_DIR, world, f"layer_{layer}.ogg"))

    print(f"--- AMBIENCE: tortoise ({AMBIENCE_LOOP_SECONDS:.0f} s bed) ---")
    bed = ga.render_seamless_loop(_ambience_tortoise_gen, AMBIENCE_LOOP_SECONDS, xfade_ms=AMBIENCE_XFADE_MS)
    bed = ga.normalize_to_peak(bed, -23.0)  # v2's bed register: -22..-24
    _write_ogg(bed, os.path.join(AMBIENCE_DIR, "tortoise.ogg"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
