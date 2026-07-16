#!/usr/bin/env python3
"""tools/audio_gen/generate_audio.py — THE BIG NAP procedural audio generator.

Deterministic (fixed per-sound seeds), dependency-light (numpy + the system
ffmpeg binary, no scipy) synthesizer for every placeholder sound the game
currently calls by name. Re-run any time; every output path is overwritten.

REGISTER (binding, see AGENTS.md / the audio brief): everything soft. No
percussion hits, no brass, no buzz. Sine/triangle cores, gentle attacks
(>= 10 ms), long soft releases, generous silence. Every one-shot is DC-
removed and fade-in/out declicked (same technique as
un_party_game/tools/declick_sfx.py, adapted to synthesis instead of
post-processing a recording). Peaks are normalized conservatively: <= -6
dBFS everywhere except the dreamling-chime ladder, which is allowed to
reach -4 dBFS (still quiet, just the loudest "count!" moment in the game).

SYNTHESIS TOOLKIT (all pure numpy, no scipy):
  - sine / triangle / sawtooth: closed-form oscillators, phase referenced
    to each note's own onset so retriggering never clicks.
  - additive_tone: struck/plucked bell or harp timbre — a few partials,
    each with its own decay time (higher partials die faster: true bell
    behaviour), raised-cosine attack.
  - lowpass_fft: a zero-phase low-pass built by masking the rfft spectrum
    with a raised-cosine shoulder (no ringing, no scipy.signal needed).
  - pink_noise / swept_noise: 1/f noise, and a "sweep" approximated by
    crossfading a duller (more low-passed) noise bed into a brighter one
    across a time-varying envelope — a simple, robust stand-in for a true
    time-varying filter.
  - render_seamless_loop: generates loop_length + a small crossfade tail
    from a *continuous* function of absolute time, then blends the tail's
    natural continuation into the loop's head (equal-power crossfade) so
    the file boundary is seam-free without needing the underlying content
    to be exactly periodic at the loop length.

OUTPUTS:
  assets/audio/sfx/*.ogg                    — one-shots (see SFX_MANIFEST)
  assets/audio/stems/bramble/layer_[1-4].ogg — D major, 60 bpm, 32 s loop
  assets/audio/stems/pillow_fort/layer_1.ogg — quieter home-drone variant

Usage:
    C:/Python314/python.exe tools/audio_gen/generate_audio.py
"""

from __future__ import annotations

import math
import os
import subprocess
import tempfile
import wave
import zlib

import numpy as np

# --- Paths -------------------------------------------------------------

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(THIS_DIR, "..", ".."))
SFX_DIR = os.path.join(REPO, "assets", "audio", "sfx")
STEMS_DIR = os.path.join(REPO, "assets", "audio", "stems")
SCRATCH_DIR = os.path.join(tempfile.gettempdir(), "soft_landing_audio_gen")

FFMPEG = r"D:\Tools\ffmpeg\ffmpeg-8.1.2-essentials_build\bin\ffmpeg.exe"

SR = 48000  # 48 kHz mono throughout, per spec.


# --- Low-level DSP helpers ----------------------------------------------

def seeded_rng(name: str) -> np.random.Generator:
    """A Generator seeded from a stable hash of `name` — deterministic and
    independent per sound, so regenerating one sound never perturbs another
    (no shared global RNG stream to accidentally desync)."""
    return np.random.default_rng(zlib.crc32(name.encode("utf-8")))


def db_to_amp(db: float) -> float:
    return 10.0 ** (db / 20.0)


def amp_to_db(amp: float) -> float:
    return 20.0 * math.log10(max(amp, 1e-9))


def peak_db(x: np.ndarray) -> float:
    return amp_to_db(float(np.max(np.abs(x))) if x.size else 0.0)


def normalize_to_peak(x: np.ndarray, target_db: float) -> np.ndarray:
    """Scale so the signal's peak sits exactly at target_db. Sounds that
    should read as quieter than the pack simply get a lower target_db in
    the manifest, rather than relying on incidental amplitude."""
    p = float(np.max(np.abs(x)))
    if p < 1e-9:
        return x
    return x * (db_to_amp(target_db) / p)


def fade_io(x: np.ndarray, sr: int, fade_in_ms: float = 10.0,
            fade_out_ms: float = 40.0) -> np.ndarray:
    """Raised-cosine in/out ramps so the waveform starts and ends at exactly
    zero — the declick technique from un_party_game/tools/declick_sfx.py,
    generalized to any fade length."""
    n = len(x)
    fi = min(int(sr * fade_in_ms / 1000.0), n // 2)
    fo = min(int(sr * fade_out_ms / 1000.0), n // 2)
    if fi > 0:
        ramp = 0.5 * (1.0 - np.cos(np.linspace(0.0, np.pi, fi)))
        x[:fi] = x[:fi] * ramp
    if fo > 0:
        ramp = 0.5 * (1.0 - np.cos(np.linspace(0.0, np.pi, fo)))
        x[-fo:] = x[-fo:] * ramp[::-1]
    return x


def finalize_oneshot(x: np.ndarray, fade_in_ms: float = 10.0,
                      fade_out_ms: float = 150.0) -> np.ndarray:
    """DC-remove then declick every one-shot SFX before normalization."""
    x = x - np.mean(x)
    return fade_io(x, SR, fade_in_ms=fade_in_ms, fade_out_ms=fade_out_ms)


def write_wav(path: str, x: np.ndarray, sr: int = SR) -> None:
    x = np.clip(x, -1.0, 1.0)
    ints = np.round(x * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(ints.tobytes())


def to_ogg(wav_path: str, ogg_path: str, qscale: str = "5") -> None:
    os.makedirs(os.path.dirname(ogg_path), exist_ok=True)
    cmd = [FFMPEG, "-y", "-loglevel", "error", "-i", wav_path,
           "-c:a", "libvorbis", "-qscale:a", qscale, ogg_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"ffmpeg failed converting {wav_path} -> {ogg_path}:\n{result.stderr}")


# --- Oscillators (phase referenced to caller-supplied time array) -------

def sine(freq: float, t: np.ndarray) -> np.ndarray:
    return np.sin(2.0 * np.pi * freq * t)


def triangle(freq: float, t: np.ndarray) -> np.ndarray:
    return (2.0 / np.pi) * np.arcsin(np.sin(2.0 * np.pi * freq * t))


def sawtooth(freq: float, t: np.ndarray) -> np.ndarray:
    phase = np.mod(freq * t, 1.0)
    return 2.0 * phase - 1.0


# --- Filters / noise (pure numpy, no scipy) ------------------------------

def lowpass_fft(x: np.ndarray, sr: int, cutoff_hz: float,
                 shoulder_hz: float | None = None) -> np.ndarray:
    """Zero-phase low-pass: mask the rfft spectrum with a raised-cosine
    shoulder from cutoff_hz to cutoff_hz+shoulder_hz. The smooth taper
    avoids the ringing a brick-wall cut would introduce."""
    n = len(x)
    if shoulder_hz is None:
        shoulder_hz = max(cutoff_hz * 0.35, 30.0)
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, d=1.0 / sr)
    gain = np.ones_like(freqs)
    hi = cutoff_hz + shoulder_hz
    ramp = (freqs >= cutoff_hz) & (freqs <= hi)
    gain[ramp] = 0.5 * (1.0 + np.cos(np.pi * (freqs[ramp] - cutoff_hz) / shoulder_hz))
    gain[freqs > hi] = 0.0
    return np.fft.irfft(X * gain, n=n)


def pink_noise(n: int, rng: np.random.Generator, sr: int = SR) -> np.ndarray:
    """1/f noise via spectral shaping of white noise — breathier and less
    hissy than white noise, the right texture for breath/whoosh sounds."""
    white = rng.normal(0.0, 1.0, size=n)
    X = np.fft.rfft(white)
    freqs = np.fft.rfftfreq(n, d=1.0 / sr).copy()
    freqs[0] = freqs[1] if len(freqs) > 1 else 1.0
    X = X / np.sqrt(freqs)
    pink = np.fft.irfft(X, n=n)
    peak = float(np.max(np.abs(pink)))
    return pink / peak if peak > 1e-9 else pink


def swept_noise(n: int, rng: np.random.Generator, lo_cut: float, hi_cut: float,
                 sweep_env: np.ndarray, sr: int = SR) -> np.ndarray:
    """Approximate a time-varying filter sweep by crossfading a duller
    (lo_cut) and a brighter (hi_cut) static low-pass of the SAME noise bed,
    using sweep_env (0=dull..1=bright) as the per-sample blend weight.
    Dependency-free stand-in for a true time-varying filter — convincing at
    these durations and in this hushed register."""
    noise = pink_noise(n, rng, sr=sr)
    dull = lowpass_fft(noise, sr, lo_cut)
    bright = lowpass_fft(noise, sr, hi_cut)
    return dull * (1.0 - sweep_env) + bright * sweep_env


# --- Envelopes ------------------------------------------------------------

def env_pluck(t: np.ndarray, t0: float, attack: float, tau: float) -> np.ndarray:
    """Raised-cosine attack (>= 10 ms per the soft-register floor) then
    exponential decay with time-constant tau. Used for anything struck or
    plucked: bells, harp notes, pizzicato dots, thumps."""
    tt = t - t0
    env = np.zeros_like(t)
    a_mask = (tt >= 0.0) & (tt < attack)
    d_mask = tt >= attack
    if attack > 0.0:
        env[a_mask] = 0.5 * (1.0 - np.cos(np.pi * tt[a_mask] / attack))
    env[d_mask] = np.exp(-(tt[d_mask] - attack) / max(tau, 1e-6))
    return env


def env_swell(t_local: np.ndarray, dur: float, attack: float,
              release: float) -> np.ndarray:
    """Attack -> hold -> release window over a LOCAL time axis starting at
    0. Used for breath/whoosh sounds that swell rather than pluck."""
    env = np.zeros_like(t_local)
    hold_end = max(attack, dur - release)
    a_mask = (t_local >= 0.0) & (t_local < attack)
    h_mask = (t_local >= attack) & (t_local < hold_end)
    r_mask = (t_local >= hold_end) & (t_local < dur)
    if attack > 0.0:
        env[a_mask] = 0.5 * (1.0 - np.cos(np.pi * t_local[a_mask] / attack))
    env[h_mask] = 1.0
    if release > 0.0:
        rt = t_local[r_mask] - hold_end
        env[r_mask] = 0.5 * (1.0 + np.cos(np.pi * rt / release))
    return env


# --- Additive tone (bell / music-box / harp family) ----------------------

# (partial ratio, relative weight, decay-time multiplier). Higher partials
# are quieter AND decay faster — that asymmetric decay is what reads as
# "struck metal" rather than a flat, synthetic organ tone.
BELL_PARTIALS = [
    (1.00, 1.00, 1.00),
    (2.01, 0.45, 0.55),
    (3.03, 0.22, 0.38),
    (4.20, 0.12, 0.24),
    (5.40, 0.06, 0.16),
]

# Harmonic (not inharmonic) partials, slower relative decay -> rounder,
# less bell-like, more "plucked string" for dream_home's harp phrase.
HARP_PARTIALS = [
    (1.0, 1.00, 1.00),
    (2.0, 0.50, 0.70),
    (3.0, 0.28, 0.50),
    (4.0, 0.15, 0.35),
    (5.0, 0.08, 0.22),
]


def additive_tone(freq: float, t: np.ndarray, t0: float, attack: float,
                   tau: float, partials: list[tuple[float, float, float]],
                   amp: float = 1.0) -> np.ndarray:
    out = np.zeros_like(t)
    total_w = sum(w for _, w, _ in partials)
    for ratio, w, decay_mul in partials:
        env = env_pluck(t, t0, attack, tau * decay_mul)
        out += w * sine(freq * ratio, t - t0) * env
    return amp * out / total_w


# --- Note table (D major stems + the C-major-pentatonic chime ladder) ---

NOTE_HZ: dict[str, float] = {
    "D2": 73.4162, "A2": 110.0000,
    "D3": 146.8324, "A3": 220.0000, "B3": 246.9417,
    "C4": 261.6256, "C#4": 277.1826, "D4": 293.6648, "E4": 329.6276,
    "F#4": 369.9944, "G4": 391.9954, "A4": 440.0000, "B4": 493.8833,
    "C5": 523.2511, "D5": 587.3295, "E5": 659.2551, "F#5": 739.9888,
    "G5": 783.9909, "A5": 880.0000,
    "C6": 1046.5023, "D6": 1174.6591, "E6": 1318.5102, "F#6": 1479.9777,
    "A6": 1760.0000, "B6": 1975.5332,
}

# Steps 1..8 climbing C-major-pentatonic (C D E G A | C D E) — the ladder
# the brief asks for: counting sounds like climbing.
PENTATONIC_LADDER_HZ = [NOTE_HZ[n] for n in
                         ("C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6")]


# --- Loop helper: continuous-generator -> seamless fixed-length loop ----

def render_seamless_loop(gen_fn, loop_seconds: float, sr: int = SR,
                          xfade_ms: float = 60.0) -> np.ndarray:
    """Evaluate gen_fn over [0, loop_seconds + xfade) as ONE continuous
    signal, then equal-power-crossfade the natural overhang (what comes
    right after the nominal loop end) into the loop's head. Result: a
    loop_seconds-long buffer whose wrap point is seam-free, without
    requiring the underlying content to be exactly periodic at
    loop_seconds (melodies, sparse random events, and LFO'd drones all
    loop cleanly with the same helper)."""
    loop_n = int(round(loop_seconds * sr))
    xfade_n = int(round(xfade_ms / 1000.0 * sr))
    total_n = loop_n + xfade_n
    t = np.arange(total_n, dtype=np.float64) / sr
    x = gen_fn(t)
    out = x[:loop_n].copy()
    if xfade_n > 0:
        w = np.linspace(0.0, 1.0, xfade_n, endpoint=False)
        fade_head = np.sin(w * np.pi / 2.0) ** 2       # 0 -> 1: weight for true head
        fade_overhang = np.cos(w * np.pi / 2.0) ** 2   # 1 -> 0: weight for the natural continuation
        out[:xfade_n] = x[:xfade_n] * fade_head + x[loop_n:loop_n + xfade_n] * fade_overhang
    return out


# =========================================================================
# SFX
# =========================================================================

def make_chime(step: int) -> np.ndarray:
    """dreamling_chime[_N] — THE signature pickup sound: a warm music-box
    pentatonic note built from additive bell partials (ratios ~1 / 2.01 /
    3.03 / 4.2 / 5.4 so it rings like struck metal, not a pure sine).
    Steps 1..8 climb the C-major-pentatonic ladder (C D E G A C D E) so
    counting *sounds* like climbing; loudness is IDENTICAL across all 8 so
    pitch alone carries the excitement and step 8 never startles. ~0.7 s:
    12 ms raised-cosine attack, ~0.42 s decay (faster on the higher
    partials — true bell behaviour), long soft tail to true zero."""
    freq = PENTATONIC_LADDER_HZ[step - 1]
    t = np.arange(int(0.85 * SR)) / SR
    x = additive_tone(freq, t, t0=0.0, attack=0.012, tau=0.42, partials=BELL_PARTIALS)
    return finalize_oneshot(x, fade_out_ms=220.0)


def make_dream_home() -> np.ndarray:
    """dream_home — the fort's "all done" welcome: a resolving falling-
    third phrase (E5 -> C5, landing on the same C5 the chime ladder calls
    home) in a harp-ish harmonic-partial timbre (rounder/longer than the
    chime's inharmonic bell). Second note enters at 0.55 s, slightly
    overlapping the first for a legato "aaah". ~1.2 s total."""
    t = np.arange(int(1.3 * SR)) / SR
    x = additive_tone(NOTE_HZ["E5"], t, 0.00, attack=0.015, tau=0.55, partials=HARP_PARTIALS)
    x += 0.9 * additive_tone(NOTE_HZ["C5"], t, 0.55, attack=0.015, tau=0.65, partials=HARP_PARTIALS)
    return finalize_oneshot(x, fade_out_ms=300.0)


def make_bubble_catch() -> np.ndarray:
    """bubble_catch — "you're safe": a sine glide 300 -> 900 Hz (exponential
    curve, so it reads as a rising whoop, not a siren) under airy pink
    noise that opens up 500 -> 3500 Hz across the same window — the "air"
    of the bubble forming. One swell envelope wraps both layers so nothing
    snaps on or off. ~0.6 s."""
    dur = 0.6
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0, f1 = 300.0, 900.0
    freq = f0 * (f1 / f0) ** (t / t[-1])
    tone = np.sin(2.0 * np.pi * np.cumsum(freq) / SR)
    rng = seeded_rng("bubble_catch")
    air = swept_noise(n, rng, 500.0, 3500.0, sweep_env=t / t[-1])
    env = env_swell(t, dur=dur, attack=0.03, release=0.28)
    x = (0.72 * tone + 0.30 * air) * env
    return finalize_oneshot(x, fade_out_ms=120.0)


def make_bubble_pop() -> np.ndarray:
    """bubble_pop — a tiny warm "boop" (60 ms downward sine glide,
    500 -> 150 Hz, fast exponential decay) plus a 3-note pentatonic
    sparkle tail (bell partials, staggered onsets, quiet) — never
    startling. ~0.4 s."""
    dur = 0.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    pop_dur = 0.09
    pop_t = np.linspace(0.0, pop_dur, int(pop_dur * SR), endpoint=False)
    pop_freq = 500.0 * (150.0 / 500.0) ** (pop_t / pop_dur)
    pop = np.sin(2.0 * np.pi * np.cumsum(pop_freq) / SR) * env_pluck(pop_t, 0.0, 0.012, 0.045)
    x = np.zeros(n)
    x[:len(pop)] += pop

    rng = seeded_rng("bubble_pop_sparkle")
    sparkle_pitches = [NOTE_HZ["A5"], NOTE_HZ["C6"], NOTE_HZ["E6"]]
    onsets = np.sort(rng.uniform(0.06, 0.32, size=3))
    for freq, t0 in zip(sparkle_pitches, onsets):
        x += 0.22 * additive_tone(freq, t, t0, attack=0.012, tau=0.12, partials=BELL_PARTIALS)
    return finalize_oneshot(x, fade_out_ms=150.0)


def make_snore_geyser() -> np.ndarray:
    """snore_geyser — a sleeping bear's sigh, not a jet: filtered pink
    noise with a slow raised-cosine swell (0.45 s attack, 0.7 s release)
    and a gentle filter-closing sweep (bright 1300 Hz -> dull 450 Hz)
    across the tail, so the breath audibly "settles". ~1.5 s."""
    dur = 1.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = seeded_rng("snore_geyser")
    sweep_env = np.cos(0.5 * np.pi * t / dur) ** 2  # 1 (bright) at t=0 -> 0 (dull) at t=dur
    breath = swept_noise(n, rng, 450.0, 1300.0, sweep_env)
    amp_env = env_swell(t, dur=dur, attack=0.45, release=0.7)
    x = breath * amp_env
    return finalize_oneshot(x, fade_out_ms=200.0)


def make_toss() -> np.ndarray:
    """toss — a soft whoosh-up: filtered pink noise opening 600 -> 2800 Hz
    across a quick-attack, short-decay swell. ~0.5 s."""
    dur = 0.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = seeded_rng("toss")
    whoosh = swept_noise(n, rng, 600.0, 2800.0, sweep_env=t / t[-1])
    amp_env = env_swell(t, dur=dur, attack=0.03, release=0.35)
    x = whoosh * amp_env
    return finalize_oneshot(x, fade_out_ms=100.0)


def make_land_soft() -> np.ndarray:
    """land_soft — a felt-cushion thump, not a stomp: a low sine
    (100 -> 65 Hz over 50 ms) plus a brief low-passed noise "thud" texture,
    both very quiet. ~0.2 s. Generated now for later wiring — no
    play_sfx('land_soft') call exists yet in the codebase."""
    dur = 0.22
    n = int(dur * SR)
    t = np.arange(n) / SR
    thump_dur = 0.05
    tt = np.linspace(0.0, thump_dur, int(thump_dur * SR), endpoint=False)
    thump_freq = 100.0 * (65.0 / 100.0) ** (tt / thump_dur)
    thump = np.sin(2.0 * np.pi * np.cumsum(thump_freq) / SR) * env_pluck(tt, 0.0, 0.010, 0.05)
    x = np.zeros(n)
    x[:len(thump)] += thump

    rng = seeded_rng("land_soft")
    noise = lowpass_fft(pink_noise(n, rng), SR, 320.0)
    x += 0.35 * noise * env_pluck(t, 0.0, 0.010, 0.045)
    return finalize_oneshot(x, fade_out_ms=60.0)


def make_mew_soft() -> np.ndarray:
    """mew_soft — Callie's tiny breathy meow (docs/design/world-cards/
    callie.md: "tiny, breathy, never insistent"). A pitch-bent tone (rises
    520 -> 720 Hz over the first third, eases back to 480 Hz by the end --
    the classic small-cat "mew" contour) with a little triangle-core warmth
    mixed under the sine (same trick as the drone layers, keeps it from
    reading as a pure test tone), plus airy swept noise for breathiness.
    One shared swell envelope (40 ms soft attack, 300 ms release) over both
    layers so nothing snaps on or off. ~0.5 s, peak <= -12 dBFS (register
    floor: soft attack, quiet, never insistent)."""
    dur = 0.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    rise_n = n // 3
    fall_n = n - rise_n
    freq = np.concatenate([
        520.0 + (720.0 - 520.0) * (np.arange(rise_n) / max(rise_n - 1, 1)),
        720.0 + (480.0 - 720.0) * (np.arange(fall_n) / max(fall_n - 1, 1)),
    ])
    tone = np.sin(2.0 * np.pi * np.cumsum(freq) / SR)
    tone = 0.8 * tone + 0.2 * triangle(600.0, t)
    rng = seeded_rng("mew_soft")
    breath = swept_noise(n, rng, 700.0, 2200.0, sweep_env=np.sin(np.pi * t / dur))
    env = env_swell(t, dur=dur, attack=0.04, release=0.30)
    x = (0.75 * tone + 0.35 * breath) * env
    return finalize_oneshot(x, fade_out_ms=120.0)


def _purr_gen(t: np.ndarray) -> np.ndarray:
    """purr_loop generator — a low rumble (55 Hz sine core, cat-purr
    register) amplitude-modulated by a ~25 Hz pulse train. The pulse itself
    is a half-rectified sine raised to a power (not a square edge), so each
    pulse has its own soft attack/decay rather than a buzzy click -- that
    double modulation (tone x pulse) is what reads as a purr instead of a
    plain droning hum. The modulation floor (0.35) keeps it from ever
    hitting true silence between pulses, same as a real purr never fully
    stopping mid-cycle."""
    carrier = sine(55.0, t)
    pulse = np.clip(np.sin(2.0 * np.pi * 25.0 * t), 0.0, None) ** 1.5
    am = 0.35 + 0.65 * pulse
    return carrier * am


def make_purr_loop() -> np.ndarray:
    """purr_loop — Callie's warm loop while her carrier holds dreamlings
    (docs/design/world-cards/callie.md: "low, warm, loopable ~4 s"). Built
    with the same render_seamless_loop crossfade helper the music stems use
    (loop-clean ends by construction, no fade_io -- a fade would break the
    loop), then low-passed at 180 Hz to keep it low/warm with no buzz from
    the pulse train's own harmonics. ~4.0 s, peak <= -16 dBFS (quiet enough
    to sit under everything else while carried)."""
    x = render_seamless_loop(_purr_gen, 4.0, xfade_ms=XFADE_MS)
    return lowpass_fft(x, SR, cutoff_hz=180.0)


def make_ui_select() -> np.ndarray:
    """ui_select — a single tiny music-box blip, same bell-partial family
    as the dreamling chime (pitch A5) so the UI feels made of the same
    material as the world. ~0.25 s."""
    t = np.arange(int(0.28 * SR)) / SR
    x = additive_tone(NOTE_HZ["A5"], t, 0.0, attack=0.010, tau=0.11, partials=BELL_PARTIALS)
    return finalize_oneshot(x, fade_out_ms=90.0)


SFX_MANIFEST: list[tuple[str, object, float]] = [
    ("dreamling_chime",   lambda: make_chime(1), -4.0),
    ("dreamling_chime_2", lambda: make_chime(2), -4.0),
    ("dreamling_chime_3", lambda: make_chime(3), -4.0),
    ("dreamling_chime_4", lambda: make_chime(4), -4.0),
    ("dreamling_chime_5", lambda: make_chime(5), -4.0),
    ("dreamling_chime_6", lambda: make_chime(6), -4.0),
    ("dreamling_chime_7", lambda: make_chime(7), -4.0),
    ("dreamling_chime_8", lambda: make_chime(8), -4.0),
    ("dream_home",   make_dream_home, -6.0),
    ("bubble_catch", make_bubble_catch, -6.0),
    ("bubble_pop",   make_bubble_pop, -6.0),
    ("snore_geyser", make_snore_geyser, -7.0),
    ("toss",         make_toss, -7.0),
    ("land_soft",    make_land_soft, -12.0),
    ("ui_select",    make_ui_select, -8.0),
    # Callie (docs/design/world-cards/callie.md): a one-shot mew and a
    # seamless purr loop. purr_loop lands in assets/audio/sfx/ (not
    # stems/) like every other loop-flagged one-off sound in this pack --
    # only the four-layer Bramble/pillow_fort drones live under stems/.
    ("mew_soft",     make_mew_soft, -12.0),
    ("purr_loop",    make_purr_loop, -16.0),
]


# =========================================================================
# STEMS — bramble (D major, 60 bpm so 1 beat == 1 second, 32 s loop) and
# pillow_fort (a quieter home-drone variant of layer_1 only).
# =========================================================================

LOOP_SECONDS = 32.0
XFADE_MS = 60.0
# The pad's breath-swell period: 32 s / 6 = ~5.33 s, close to the "~5 s"
# breath cycle GAME_BRIEF ties to Bramble, AND an exact divisor of the loop
# length (so the LFO itself is already period-matched; render_seamless_loop
# handles the oscillator phase, which does NOT divide evenly, on top of
# that).
BREATH_PERIOD = LOOP_SECONDS / 6.0


def _drone_gen(root_hz: float, fifth_hz: float, swell_lo: float, swell_hi: float):
    """layer_1 family — a warm pad drone (root + fifth, sine core with a
    touch of triangle for warmth), amplitude tied to a slow breath-swell so
    it never goes fully silent ("breathing slowly")."""
    def gen(t: np.ndarray) -> np.ndarray:
        swell = swell_lo + (swell_hi - swell_lo) * 0.5 * (1.0 - np.cos(2.0 * np.pi * t / BREATH_PERIOD))
        root_tone = 0.85 * sine(root_hz, t) + 0.15 * triangle(root_hz, t)
        fifth_tone = 0.85 * sine(fifth_hz, t) + 0.15 * triangle(fifth_hz, t)
        return (0.6 * root_tone + 0.4 * fifth_tone) * swell
    return gen


# layer_2 — a simple 4-bar (16-beat == 16 s at 60 bpm) diatonic D-major
# lullaby phrase, repeated twice to fill the 32 s loop: a gentle arch down
# to the tonic, then a wider arch up through the sixth and home again.
MELODY_NOTES: list[tuple[float, float, str]] = [
    (0.0, 2.0, "D4"), (2.0, 1.0, "F#4"), (3.0, 1.0, "E4"),
    (4.0, 1.0, "D4"), (5.0, 1.0, "C#4"), (6.0, 2.0, "D4"),
    (8.0, 2.0, "A4"), (10.0, 1.0, "G4"), (11.0, 1.0, "F#4"),
    (12.0, 1.0, "E4"), (13.0, 1.0, "F#4"), (14.0, 2.0, "D4"),
]
PHRASE_LEN_S = 16.0


def _layer2_gen(t: np.ndarray) -> np.ndarray:
    """layer_2 — a slow melodic cell in a sawtooth core, heavily low-passed
    (cutoff ~1.1 kHz) so the buzzy harmonics wash into a warm, indistinct
    "a viola will live here" placeholder rather than a bright lead synth."""
    x = np.zeros_like(t)
    n_repeats = int(np.ceil((t[-1] + 0.001) / PHRASE_LEN_S)) + 1
    for rep in range(n_repeats):
        offset = rep * PHRASE_LEN_S
        for start_beat, dur_beat, note in MELODY_NOTES:
            t0 = offset + start_beat
            freq = NOTE_HZ[note]
            attack = 0.02
            tau = max(dur_beat - attack, 0.05)
            x += 0.9 * sawtooth(freq, t - t0) * env_pluck(t, t0, attack, tau)
    return lowpass_fft(x, SR, cutoff_hz=1100.0, shoulder_hz=500.0)


PIZZ_PITCHES = ["D5", "F#5", "A5", "E5", "B4"]


def _layer3_gen(t: np.ndarray) -> np.ndarray:
    """layer_3 — sparse plucked/pizzicato dots on the offbeats (triangle
    core, fast pluck decay), ~35% of available offbeat slots chosen with a
    fixed seed so the pattern breathes without being metronomic."""
    rng = seeded_rng("bramble_layer3_pizz")
    x = np.zeros_like(t)
    total_beats = int(np.ceil(t[-1])) + 1
    offbeats = np.arange(0, total_beats) + 0.5
    n_pick = max(1, int(len(offbeats) * 0.35))
    chosen = np.sort(rng.choice(offbeats, size=n_pick, replace=False))
    pitch_idx = rng.integers(0, len(PIZZ_PITCHES), size=len(chosen))
    for t0, pi in zip(chosen, pitch_idx):
        freq = NOTE_HZ[PIZZ_PITCHES[pi]]
        x += 0.8 * triangle(freq, t - t0) * env_pluck(t, t0, attack=0.010, tau=0.22)
    return x


SHIMMER_PITCHES = ["D6", "E6", "F#6", "A6", "B6"]


def _layer4_gen(t: np.ndarray) -> np.ndarray:
    """layer_4 — high glass-harmonic / starlight shimmer: sparse bell tones
    (roughly one every ~3 s on average) at free (non-metrical) onsets, very
    quiet even before the layer's own -18 dBFS normalization target."""
    rng = seeded_rng("bramble_layer4_shimmer")
    x = np.zeros_like(t)
    n_events = max(4, int(t[-1] / 3.0))
    onsets = np.sort(rng.uniform(0.0, t[-1], size=n_events))
    pitch_idx = rng.integers(0, len(SHIMMER_PITCHES), size=len(onsets))
    for t0, pi in zip(onsets, pitch_idx):
        freq = NOTE_HZ[SHIMMER_PITCHES[pi]]
        x += additive_tone(freq, t, t0, attack=0.018, tau=0.75, partials=BELL_PARTIALS, amp=0.6)
    return x


# Per-layer peak targets before the mix-clip safety check. layer_2 (the
# melodic voice) sits a little hotter than the drone; layer_4 (shimmer) is
# deliberately near-subliminal.
BRAMBLE_TARGETS_DB = {1: -9.0, 2: -7.0, 3: -10.0, 4: -18.0}
MIX_CEILING_DB = -1.0  # headroom kept below true 0 dBFS when layers sum


def build_bramble_stems() -> tuple[dict[int, np.ndarray], float, bool]:
    raw = {
        1: render_seamless_loop(_drone_gen(NOTE_HZ["D2"], NOTE_HZ["A2"], 0.7, 1.0), LOOP_SECONDS, xfade_ms=XFADE_MS),
        2: render_seamless_loop(_layer2_gen, LOOP_SECONDS, xfade_ms=XFADE_MS),
        3: render_seamless_loop(_layer3_gen, LOOP_SECONDS, xfade_ms=XFADE_MS),
        4: render_seamless_loop(_layer4_gen, LOOP_SECONDS, xfade_ms=XFADE_MS),
    }
    normalized = {k: normalize_to_peak(v, BRAMBLE_TARGETS_DB[k]) for k, v in raw.items()}
    mix_peak = peak_db(sum(normalized.values()))
    adjusted = mix_peak > MIX_CEILING_DB
    if adjusted:
        # All four layers play simultaneously in AudioManager, so verify
        # (not assume) the summed mix stays under 0 dBFS, and back every
        # layer off equally (preserving relative balance) if it doesn't.
        scale = db_to_amp(MIX_CEILING_DB) / db_to_amp(mix_peak)
        normalized = {k: v * scale for k, v in normalized.items()}
        mix_peak = peak_db(sum(normalized.values()))
    return normalized, mix_peak, adjusted


def build_pillow_fort_stems() -> dict[int, np.ndarray]:
    """pillow_fort/layer_1 — the hub's "even quieter" home-drone: same
    drone construction one octave up (D3+A3, closer/homier than Bramble's
    low D2+A2) and normalized well under Bramble's layer_1."""
    gen = _drone_gen(NOTE_HZ["D3"], NOTE_HZ["A3"], 0.75, 1.0)
    raw = render_seamless_loop(gen, LOOP_SECONDS, xfade_ms=XFADE_MS)
    return {1: normalize_to_peak(raw, -14.0)}


# =========================================================================
# Main
# =========================================================================

def main() -> int:
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(os.path.join(STEMS_DIR, "bramble"), exist_ok=True)
    os.makedirs(os.path.join(STEMS_DIR, "pillow_fort"), exist_ok=True)
    os.makedirs(SCRATCH_DIR, exist_ok=True)

    report_rows: list[tuple[str, float, float]] = []

    print("=== THE BIG NAP -- procedural audio generator ===")
    print(f"sample rate: {SR} Hz mono | ffmpeg: {FFMPEG}")
    print(f"wav scratch: {SCRATCH_DIR}")
    print()

    print("--- SFX (assets/audio/sfx/) ---")
    for name, gen_fn, target_db in SFX_MANIFEST:
        x = normalize_to_peak(gen_fn(), target_db)
        wav_path = os.path.join(SCRATCH_DIR, f"{name}.wav")
        ogg_path = os.path.join(SFX_DIR, f"{name}.ogg")
        write_wav(wav_path, x)
        to_ogg(wav_path, ogg_path)
        dur, pdb = len(x) / SR, peak_db(x)
        report_rows.append((f"sfx/{name}.ogg", dur, pdb))
        print(f"  {name:<22s} {dur:5.2f}s  peak {pdb:6.2f} dBFS")

    print()
    print("--- STEMS: bramble (D major, 60 bpm, 32 s loop) ---")
    bramble_layers, bramble_mix_peak, bramble_adjusted = build_bramble_stems()
    for idx in sorted(bramble_layers):
        x = bramble_layers[idx]
        wav_path = os.path.join(SCRATCH_DIR, f"bramble_layer_{idx}.wav")
        ogg_path = os.path.join(STEMS_DIR, "bramble", f"layer_{idx}.ogg")
        write_wav(wav_path, x)
        to_ogg(wav_path, ogg_path)
        dur, pdb = len(x) / SR, peak_db(x)
        report_rows.append((f"stems/bramble/layer_{idx}.ogg", dur, pdb))
        print(f"  layer_{idx}  {dur:6.2f}s  peak {pdb:6.2f} dBFS")
    note = "auto-attenuated to avoid clipping" if bramble_adjusted else "no adjustment needed"
    print(f"  MIX CHECK (layers 1-4 summed): peak {bramble_mix_peak:6.2f} dBFS ({note})")

    print()
    print("--- STEMS: pillow_fort (quieter home-drone variant) ---")
    pf_layers = build_pillow_fort_stems()
    for idx in sorted(pf_layers):
        x = pf_layers[idx]
        wav_path = os.path.join(SCRATCH_DIR, f"pillow_fort_layer_{idx}.wav")
        ogg_path = os.path.join(STEMS_DIR, "pillow_fort", f"layer_{idx}.ogg")
        write_wav(wav_path, x)
        to_ogg(wav_path, ogg_path)
        dur, pdb = len(x) / SR, peak_db(x)
        report_rows.append((f"stems/pillow_fort/layer_{idx}.ogg", dur, pdb))
        print(f"  layer_{idx}  {dur:6.2f}s  peak {pdb:6.2f} dBFS")

    print()
    print("=== Peak-level summary table ===")
    print(f"{'file':<38s} {'dur(s)':>8s} {'peak(dBFS)':>12s}")
    for name, dur, pdb in report_rows:
        print(f"{name:<38s} {dur:8.2f} {pdb:12.2f}")

    print()
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
