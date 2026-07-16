#!/usr/bin/env python3
"""tools/audio_gen/generate_voice.py — THE BIG NAP "moonsong" syllable
generator (UI/writing pass, D20: gibberish-voice v0).

Synthesizes a small bank of soft, breathy "Moon syllable" one-shots that
scripts/autoloads/the_moon.gd sequences at runtime (per-word/per-syllable,
Banjo-Kazooie style — docs/research/v2/ui_writing.md §5) into a spoken-
sounding stream for any line, without real voice acting. Reuses every DSP
helper from generate_audio.py (numpy, no scipy; deterministic per-sound
seeds; same declick/normalize conventions) by importing it as a module —
see that file's own docstring for the synthesis toolkit this borrows.

REGISTER: hushed, breathy, lunar — not a "grunt" (Banjo) or a crisp letter
sample (Animalese). Each syllable is a soft formant-ish blend (a sine
fundamental + a detuned triangle partial standing in for a second vowel
formant) under a little swept-noise breath, low-passed for a hushed
timbre, pitch-centered on THE BIG NAP's own D-major-pentatonic palette
(the same NOTE_HZ table bramble's stems and the dreamling chime use) so
the Moon sounds made of the same material as the rest of the game.

DETERMINISM NOTE (found during this build): plain `ffmpeg -c:a libvorbis`
does NOT produce byte-identical .ogg files across runs of the identical
input WAV — libvorbis's ogg muxer picks a random stream serial number per
encode. `-fflags +bitexact` pins that (and any timestamp/encoder-string
metadata) so the container bytes match run-to-run, not just the decoded
PCM. `to_ogg_bitexact()` below applies it; generate_audio.py's existing
`to_ogg()` does not (out of this build's territory to change, flagged in
the VERIFY doc for whoever owns that script next).

OUTPUT: assets/audio/voice/moon_syl_00.ogg .. moon_syl_09.ogg (10 samples,
~120-200ms each).

Usage:
    C:/Python314/python.exe tools/audio_gen/generate_voice.py
"""

from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import tempfile

import numpy as np

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(THIS_DIR, "..", ".."))
sys.path.insert(0, THIS_DIR)
import generate_audio as ga  # noqa: E402  (path must be set up first)

VOICE_DIR = os.path.join(REPO, "assets", "audio", "voice")
SCRATCH_DIR = os.path.join(tempfile.gettempdir(), "soft_landing_voice_gen")

SR = ga.SR


def to_ogg_bitexact(wav_path: str, ogg_path: str, qscale: str = "4") -> None:
    """Same as generate_audio.to_ogg but with -fflags +bitexact on both the
    demuxer and muxer side, so the .ogg file itself (not just its decoded
    PCM) is byte-identical across repeated runs — see module docstring."""
    os.makedirs(os.path.dirname(ogg_path), exist_ok=True)
    cmd = [
        ga.FFMPEG, "-y", "-loglevel", "error", "-fflags", "+bitexact",
        "-i", wav_path, "-c:a", "libvorbis", "-qscale:a", qscale,
        "-fflags", "+bitexact", "-flags:a", "+bitexact", ogg_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg failed converting {wav_path} -> {ogg_path}:\n{result.stderr}")


# --- Moon syllable palette ------------------------------------------------

# Ten pitch centers drawn from THE BIG NAP's own D-major pentatonic
# vocabulary (bramble stems / dreamling chime NOTE_HZ table) — a mid-high,
# "lunar" register, not the chime's brighter upper octave.
SYLLABLE_PITCHES = [
    "D4", "E4", "F#4", "A4", "B4",
    "D5", "E4", "A4", "F#4", "B4",
]

# Per-syllable "vowel" formant ratio (second partial relative to the
# fundamental) — varying this across the bank is what keeps ten syllables
# from all sounding like the same "ooh". Non-harmonic ratios read as vowel
# color rather than a musical interval.
FORMANT_RATIOS = [1.55, 1.85, 2.15, 1.65, 2.35, 1.45, 2.05, 1.75, 2.45, 1.95]


def make_moonsong_syllable(idx: int) -> np.ndarray:
    """moon_syl_NN — one soft breathy syllable: sine fundamental + a
    detuned triangle formant partial (quiet, ~22% weight) under airy
    swept noise, one shared swell envelope, then low-passed to a hushed
    ~2.2 kHz ceiling. Duration and exact pitch/formant detune vary
    per-sample (seeded) so the ten-sample bank doesn't read as a single
    looped blip when the_moon.gd sequences several per line."""
    rng = ga.seeded_rng(f"moon_syl_{idx}")
    dur = float(rng.uniform(0.12, 0.20))
    n = int(dur * SR)
    t = np.arange(n) / SR

    base_freq = ga.NOTE_HZ[SYLLABLE_PITCHES[idx % len(SYLLABLE_PITCHES)]]
    base_freq *= float(rng.uniform(0.99, 1.01))  # a hair of per-sample detune
    formant_ratio = FORMANT_RATIOS[idx % len(FORMANT_RATIOS)]

    tone = 0.78 * ga.sine(base_freq, t) + 0.22 * ga.triangle(base_freq * formant_ratio, t)

    breath = ga.swept_noise(
        n, rng, lo_cut=base_freq * 1.5, hi_cut=base_freq * 4.0,
        sweep_env=np.sin(np.pi * t / max(t[-1], 1e-6)),
    )

    attack = float(rng.uniform(0.015, 0.025))
    release = float(rng.uniform(0.04, 0.06))
    env = ga.env_swell(t, dur=dur, attack=attack, release=min(release, dur * 0.5))

    x = (0.82 * tone + 0.22 * breath) * env
    x = ga.lowpass_fft(x, SR, cutoff_hz=2200.0, shoulder_hz=500.0)
    return ga.finalize_oneshot(x, fade_in_ms=8.0, fade_out_ms=30.0)


def main() -> int:
    os.makedirs(VOICE_DIR, exist_ok=True)
    os.makedirs(SCRATCH_DIR, exist_ok=True)

    print("=== THE BIG NAP -- moonsong syllable generator ===")
    print(f"sample rate: {SR} Hz mono | ffmpeg: {ga.FFMPEG}")
    print()

    hashes: dict[str, str] = {}
    for idx in range(10):
        name = f"moon_syl_{idx:02d}"
        x = ga.normalize_to_peak(make_moonsong_syllable(idx), -11.0)
        wav_path = os.path.join(SCRATCH_DIR, f"{name}.wav")
        ogg_path = os.path.join(VOICE_DIR, f"{name}.ogg")
        ga.write_wav(wav_path, x)
        to_ogg_bitexact(wav_path, ogg_path)
        dur, pdb = len(x) / SR, ga.peak_db(x)
        with open(ogg_path, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        hashes[name] = digest
        print(f"  {name:<14s} {dur:5.3f}s  peak {pdb:6.2f} dBFS  sha256 {digest[:16]}")

    print()
    print("Done. Re-run and diff the sha256 column above to confirm determinism.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
