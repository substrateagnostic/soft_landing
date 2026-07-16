#!/usr/bin/env python3
"""tools/audio_gen/generate_audio_v2.py — THE BIG NAP procedural audio, V2
pass: player verb sounds, footsteps, world ambience beds, positional
creature/prop one-shots, and menu sounds.

Imports tools/audio_gen/generate_audio.py as a module (same pattern
generate_voice.py already established) and reuses every DSP helper from it
verbatim — see that file's own docstring for the synthesis toolkit. Nothing
in generate_audio.py is modified; this is a pure additive sibling.

REGISTER (binding, unchanged from V1 — see AGENTS.md / docs/design/
music-stems-spec.md): hushed, tender-enormous, D-major/pentatonic
sound-world, NO percussion (every "thump" is a low sine glide with a
raised-cosine attack >= 10 ms, never a hard transient), silence allowed.
Peaks target <= -8 dBFS for verb one-shots (a hair louder than V1's -6/-7
dBFS floor is NOT intended here — see the per-manifest target_db column,
most V2 one-shots actually sit at or below -8), <= -12 dBFS for anything
that repeats often (footsteps, critter chirps), and <= -22 dBFS for
ambience beds (the "very quiet, ducked under the stems" mix-discipline
ask — approximated via peak target since this pipeline has no true LUFS
meter; see module docstring in generate_audio.py for why numpy-only DSP is
the deliberate choice, not an oversight).

DETERMINISM: uses to_ogg_bitexact() (borrowed technique from
generate_voice.py's own module docstring finding: plain `ffmpeg -c:a
libvorbis` does NOT produce byte-identical containers run-to-run — the
muxer picks a random stream serial number unless `-fflags +bitexact` pins
it) for every output in this file, so "generators deterministic (hash
twice)" is provably true, not just PCM-identical.

OUTPUTS:
  assets/audio/sfx/*.ogg          — new verb/critter/UI-adjacent one-shots
                                     (same flat dir play_sfx() already reads,
                                     so PositionalAudio's play_at() — which
                                     loads through AudioManager.load_sfx_stream
                                     — can spatialize any of them for free)
  assets/audio/ambience/*.ogg     — bramble/pillow_fort/wisp/marmalade beds
  assets/audio/ui/*.ogg           — focus_tick/confirm_bloom/pause_open/close

Usage:
    C:/Python314/python.exe tools/audio_gen/generate_audio_v2.py
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

SFX_DIR = ga.SFX_DIR
AMBIENCE_DIR = os.path.join(REPO, "assets", "audio", "ambience")
UI_DIR = os.path.join(REPO, "assets", "audio", "ui")
SCRATCH_DIR = os.path.join(tempfile.gettempdir(), "soft_landing_audio_gen_v2")

SR = ga.SR
NOTE_HZ = ga.NOTE_HZ
BELL_PARTIALS = ga.BELL_PARTIALS
HARP_PARTIALS = ga.HARP_PARTIALS

AMBIENCE_LOOP_SECONDS = 36.0  # within the brief's 30-45 s range
AMBIENCE_XFADE_MS = 150.0     # longer than the music stems' 60 ms -- these are pure texture, a longer blend hides the seam even better


def to_ogg_bitexact(wav_path: str, ogg_path: str, qscale: str = "4") -> None:
    """Same technique as generate_voice.py's to_ogg_bitexact — see that
    file's module docstring for why plain ffmpeg is not byte-reproducible
    without this flag."""
    os.makedirs(os.path.dirname(ogg_path), exist_ok=True)
    cmd = [
        ga.FFMPEG, "-y", "-loglevel", "error", "-fflags", "+bitexact",
        "-i", wav_path, "-c:a", "libvorbis", "-qscale:a", qscale,
        "-fflags", "+bitexact", "-flags:a", "+bitexact", ogg_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg failed converting {wav_path} -> {ogg_path}:\n{result.stderr}")


# =========================================================================
# Player verb one-shots (core/audio/player_audio.gd is the runtime caller)
# =========================================================================

def make_flutter() -> np.ndarray:
    """flutter — a tiny airy wing-flap chirp: a short swept-noise burst
    (300->1800 Hz, quick attack/decay, standing in for the flap itself)
    plus a single pentatonic grace note (E5, bell partials) landing right
    at the burst's peak — reads as a little upward lift, not a percussive
    hit. ~0.35 s."""
    dur = 0.35
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("flutter")
    burst_env = ga.env_pluck(t, 0.0, 0.015, 0.09)
    burst = ga.swept_noise(n, rng, 300.0, 1800.0, sweep_env=np.clip(t / 0.08, 0.0, 1.0)) * burst_env
    grace = ga.additive_tone(NOTE_HZ["E5"], t, 0.03, attack=0.012, tau=0.16, partials=BELL_PARTIALS, amp=0.55)
    x = 0.8 * burst + grace
    return ga.finalize_oneshot(x, fade_out_ms=90.0)


def _glide_loop_gen(t: np.ndarray) -> np.ndarray:
    """glide_loop generator — two detuned swept-noise bands drifting in and
    out of phase via slow independent LFOs (3.0 s / 2.3 s periods), so the
    short loop never feels static even though it repeats every 3 s while
    a hold is sustained."""
    n = len(t)
    rng_a = ga.seeded_rng("glide_loop_a")
    rng_b = ga.seeded_rng("glide_loop_b")
    lfo_a = 0.5 + 0.5 * np.sin(2.0 * np.pi * t / 3.0)
    lfo_b = 0.5 + 0.5 * np.sin(2.0 * np.pi * t / 2.3 + 1.7)
    band_a = ga.swept_noise(n, rng_a, 700.0, 2600.0, sweep_env=lfo_a)
    band_b = ga.swept_noise(n, rng_b, 900.0, 3200.0, sweep_env=lfo_b)
    return 0.6 * band_a + 0.4 * band_b


def make_glide_loop() -> np.ndarray:
    """glide_loop — gentle sustained air shimmer. Baked as a plain
    seamless loop with NO fade-io of its own (fading would break the loop
    seam); PlayerAudio.gd owns the fade-in/out around GLIDE state entry
    and exit at runtime instead. 3 s loop, quiet even before PlayerAudio's
    own -14 dBFS-ish playback ceiling."""
    return render_seamless_loop_quiet(_glide_loop_gen, 3.0, xfade_ms=80.0)


def render_seamless_loop_quiet(gen_fn, loop_seconds: float, xfade_ms: float) -> np.ndarray:
    """Thin pass-through to generate_audio.render_seamless_loop — named
    locally so every loop call in this file reads the same way regardless
    of which module actually owns the helper."""
    return ga.render_seamless_loop(gen_fn, loop_seconds, xfade_ms=xfade_ms)


def make_pound_start() -> np.ndarray:
    """pound_start — a quick inhale whoosh: swept noise CLOSING (bright
    2000->600 Hz, sweep_env going 1->0, the reverse of every other
    "opening" whoosh in this pack) under a fast attack / short hold — a
    sharp little intake of breath, not a boom. ~0.22 s."""
    dur = 0.22
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("pound_start")
    sweep_env = 1.0 - (t / t[-1])
    whoosh = ga.swept_noise(n, rng, 600.0, 2000.0, sweep_env=sweep_env)
    env = ga.env_swell(t, dur=dur, attack=0.02, release=0.12)
    x = whoosh * env
    return ga.finalize_oneshot(x, fade_out_ms=60.0)


def make_pound_land() -> np.ndarray:
    """pound_land — a soft DEEP PILLOW thump, not a drum hit: a low sine
    glide (90->55 Hz, deeper and longer than land_soft's 100->65 Hz) with
    a gentle 25 ms raised-cosine attack (well clear of a true percussive
    transient), a little low-passed noise "give" under it, plus a tiny
    two-note pentatonic sparkle arriving just after the thump settles —
    the free launch is a gift, so the landing gets a little glimmer.
    ~0.5 s."""
    dur = 0.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    thump_dur = 0.11
    tt = np.linspace(0.0, thump_dur, int(thump_dur * SR), endpoint=False)
    thump_freq = 90.0 * (55.0 / 90.0) ** (tt / thump_dur)
    thump = np.sin(2.0 * np.pi * np.cumsum(thump_freq) / SR) * ga.env_pluck(tt, 0.0, 0.025, 0.11)
    x = np.zeros(n)
    x[:len(thump)] += thump

    rng = ga.seeded_rng("pound_land")
    noise = ga.lowpass_fft(ga.pink_noise(n, rng), SR, 260.0)
    x += 0.4 * noise * ga.env_pluck(t, 0.0, 0.02, 0.09)

    for freq, t0 in zip([NOTE_HZ["A5"], NOTE_HZ["D6"]], [0.14, 0.20]):
        x += 0.16 * ga.additive_tone(freq, t, t0, attack=0.012, tau=0.14, partials=BELL_PARTIALS)
    return ga.finalize_oneshot(x, fade_out_ms=140.0)


def make_footstep() -> np.ndarray:
    """footstep — a soft felt PAT, deliberately smaller than land_soft (no
    low-sine core at all — just a brief low-passed noise tap) so a running
    cadence of these never competes with land_soft/pound_land for low-end
    space or gets fatiguing at repeat-every-few-hundred-ms rates. ~0.1 s,
    quiet (-16 dBFS target — see SFX_V2_MANIFEST)."""
    dur = 0.1
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("footstep")
    noise = ga.lowpass_fft(ga.pink_noise(n, rng), SR, 500.0, shoulder_hz=250.0)
    x = noise * ga.env_pluck(t, 0.0, 0.006, 0.035)
    return ga.finalize_oneshot(x, fade_out_ms=40.0)


# =========================================================================
# Positional creature / prop one-shots (worlds/common/positional_audio.gd
# spatializes any of these by name — they live in the flat SFX pool, not a
# separate directory, so AudioManager stays the single source of truth for
# "what sounds exist").
# =========================================================================

def make_moth_flutter() -> np.ndarray:
    """moth_flutter — a critter's own wing-whir (distinct texture from the
    player's `flutter` verb: no grace note, pure wingbeat): a fast-AM'd
    high noise band. ~0.5 s, whisper-quiet — the critter's motion already
    reads as startled; the sound should confirm, not announce."""
    dur = 0.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("moth_flutter")
    band = ga.swept_noise(n, rng, 1200.0, 3200.0, sweep_env=np.full(n, 0.6))
    flutter_am = 0.5 + 0.5 * np.clip(np.sin(2.0 * np.pi * 22.0 * t), 0.0, None)
    env = ga.env_swell(t, dur=dur, attack=0.05, release=0.25)
    x = band * flutter_am * env
    return ga.finalize_oneshot(x, fade_out_ms=100.0)


def make_mouse_squeak() -> np.ndarray:
    """mouse_squeak — a tiny startled "squeak-yawn": a short pitch-bent
    tone (900->1300->650 Hz: a quick startled rise then an easing "yawn"
    fall, echoing mew_soft's bent-tone technique) with a breathy noise
    tail. Soft despite the high pitch — the peak target keeps it quiet.
    ~0.4 s."""
    dur = 0.4
    n = int(dur * SR)
    t = np.arange(n) / SR
    seg_a = n // 3
    seg_b = n // 3
    seg_c = n - seg_a - seg_b
    freq = np.concatenate([
        np.linspace(900.0, 1300.0, seg_a, endpoint=False),
        np.linspace(1300.0, 950.0, seg_b, endpoint=False),
        np.linspace(950.0, 650.0, seg_c),
    ])
    tone = np.sin(2.0 * np.pi * np.cumsum(freq) / SR)
    rng = ga.seeded_rng("mouse_squeak")
    breath = ga.swept_noise(n, rng, 800.0, 2600.0, sweep_env=np.linspace(0.2, 0.8, n))
    env = ga.env_swell(t, dur=dur, attack=0.02, release=0.22)
    x = (0.7 * tone + 0.3 * breath) * env
    return ga.finalize_oneshot(x, fade_out_ms=100.0)


def make_door_chime() -> np.ndarray:
    """door_chime — a soft rising two-note open/close chime (D5 -> F#5, a
    warm second, borrowing dream_home's HARP_PARTIALS so it doesn't
    compete with the dreamling_chime's bell timbre) that stays a plain
    rising interval rather than a resolving phrase — reads as "door", not
    "reward". Registered for later adoption by whichever world/door script
    wires it (worlds/common/world_door.gd, dream_door.gd are outside this
    pass's territory — this pass only generates + registers the asset).
    ~0.65 s."""
    t = np.arange(int(0.65 * SR)) / SR
    x = ga.additive_tone(NOTE_HZ["D5"], t, 0.0, attack=0.014, tau=0.22, partials=HARP_PARTIALS, amp=0.8)
    x += ga.additive_tone(NOTE_HZ["F#5"], t, 0.10, attack=0.014, tau=0.28, partials=HARP_PARTIALS, amp=0.7)
    return ga.finalize_oneshot(x, fade_out_ms=160.0)


_GIGGLE_BASE_NOTES = [NOTE_HZ["A5"], NOTE_HZ["C6"], NOTE_HZ["E5"]]
_GIGGLE_FORMANT_RATIOS = [1.6, 1.9, 1.75]


def make_dreamling_giggle(variant: int) -> np.ndarray:
    """dreamling_giggle[_N] — three short breathy giggle variants: three
    quick pitch-bent "ha" syllables (sine + detuned-triangle formant blend,
    the same technique generate_voice.py uses for moonsong syllables) with
    close onsets (~85 ms apart) and a gently falling pitch per syllable, so
    it reads as one giggle rather than three separate blips. Played
    periodically while a Dreamling is IDLE (worlds/common/dreamling.gd),
    positionally, so a dream can be *heard* before it's found (aliveness_
    wow.md §2/§6 item 9). ~0.55 s each."""
    rng = ga.seeded_rng("dreamling_giggle_%d" % variant)
    base = _GIGGLE_BASE_NOTES[(variant - 1) % len(_GIGGLE_BASE_NOTES)]
    formant_ratio = _GIGGLE_FORMANT_RATIOS[(variant - 1) % len(_GIGGLE_FORMANT_RATIOS)]
    n_syl = 3
    gap = 0.085
    syl_tau = 0.055
    dur = n_syl * gap + 0.22
    n = int(dur * SR)
    t = np.arange(n) / SR

    x = np.zeros(n)
    for i in range(n_syl):
        t0 = i * gap
        freq = base * (1.0 - 0.025 * i)  # each "ha" eases down a hair
        env = ga.env_pluck(t, t0, 0.010, syl_tau)
        tone = 0.75 * ga.sine(freq, t - t0) + 0.25 * ga.triangle(freq * formant_ratio, t - t0)
        x += tone * env

    breath = ga.swept_noise(n, rng, base * 1.2, base * 2.5, sweep_env=np.linspace(0.3, 0.7, n))
    breath_env = ga.env_swell(t, dur=t[-1], attack=0.02, release=dur * 0.4)
    x = 0.85 * x + 0.15 * breath * breath_env
    x = ga.lowpass_fft(x, SR, cutoff_hz=3200.0, shoulder_hz=800.0)
    return ga.finalize_oneshot(x, fade_in_ms=6.0, fade_out_ms=90.0)


def make_poke_boop() -> np.ndarray:
    """poke_boop — worlds/common/touch_react.gd has shipped a
    `sfx_name = "poke_boop"` default since it landed, with no matching
    asset (documented no-op in worlds/common/dream_door.gd's own comment)
    — this closes that gap. A tiny warm boop: a short downward sine glide
    (620->320 Hz, same shape family as bubble_pop's "boop" component) plus
    one soft pentatonic sparkle landing on the glide's tail. Smaller/
    lighter than bubble_pop on purpose — that sound owns the rescue
    moment; this one plays on every poke, potentially dozens of times per
    session, and touch_react.gd now varies playback pitch_scale across 3
    values rather than baking three separate files (one clean source,
    cheap variety, see touch_react.gd). ~0.28 s."""
    dur = 0.28
    n = int(dur * SR)
    t = np.arange(n) / SR
    pop_dur = 0.07
    pop_t = np.linspace(0.0, pop_dur, int(pop_dur * SR), endpoint=False)
    pop_freq = 620.0 * (320.0 / 620.0) ** (pop_t / pop_dur)
    pop = np.sin(2.0 * np.pi * np.cumsum(pop_freq) / SR) * ga.env_pluck(pop_t, 0.0, 0.010, 0.035)
    x = np.zeros(n)
    x[:len(pop)] += pop
    x += 0.3 * ga.additive_tone(NOTE_HZ["C6"], t, 0.05, attack=0.010, tau=0.09, partials=BELL_PARTIALS)
    return ga.finalize_oneshot(x, fade_out_ms=90.0)


SFX_V2_MANIFEST: list[tuple[str, object, float]] = [
    ("flutter",           make_flutter, -8.0),
    ("glide_loop",        make_glide_loop, -14.0),  # loop, not a one-shot: could sustain for seconds under a held glide
    ("pound_start",       make_pound_start, -9.0),
    ("pound_land",        make_pound_land, -8.0),
    ("footstep",          make_footstep, -16.0),   # rate-limited but frequent -- quietest verb sound on purpose
    ("moth_flutter",      make_moth_flutter, -14.0),
    ("mouse_squeak",      make_mouse_squeak, -12.0),
    ("door_chime",        make_door_chime, -8.0),
    ("dreamling_giggle",   lambda: make_dreamling_giggle(1), -10.0),
    ("dreamling_giggle_2", lambda: make_dreamling_giggle(2), -10.0),
    ("dreamling_giggle_3", lambda: make_dreamling_giggle(3), -10.0),
    ("poke_boop",          make_poke_boop, -9.0),
]


# =========================================================================
# World ambience beds — assets/audio/ambience/<world>.ogg, 36 s seamless
# loops, very quiet (mix discipline: ducked well under the lullaby stems).
# =========================================================================

def _ambience_bramble_gen(t: np.ndarray) -> np.ndarray:
    """bramble — warm night meadow: filtered wind-through-grass noise,
    amplitude-tied to the SAME ~5.3 s breath cycle the layer_1 lullaby
    drone uses (docs/design/music-stems-spec.md: "the chest onscreen
    breathes at 5 s") — the ambience bed and the drone breathe together
    without sharing any runtime state, just the same period."""
    n = len(t)
    rng = ga.seeded_rng("ambience_bramble")
    breath_period = 5.3
    swell = 0.55 + 0.45 * 0.5 * (1.0 - np.cos(2.0 * np.pi * t / breath_period))
    wind = ga.swept_noise(n, rng, 300.0, 1400.0, sweep_env=0.4 + 0.2 * np.sin(2.0 * np.pi * t / 11.0))
    return wind * swell


def make_ambience_bramble() -> np.ndarray:
    return ga.render_seamless_loop(_ambience_bramble_gen, AMBIENCE_LOOP_SECONDS, xfade_ms=AMBIENCE_XFADE_MS)


def _ambience_pillow_fort_gen(t: np.ndarray) -> np.ndarray:
    """pillow_fort — intimate hush: a very quiet low-passed room-tone bed,
    a few sparse soft "fabric shift" noise swells, and sparse high
    pentatonic-bell "cricket-adjacent" sparkles (explicitly synthesized,
    not sampled crickets, per the brief — dreamlike rather than literal)."""
    n = len(t)
    room = ga.lowpass_fft(ga.pink_noise(n, ga.seeded_rng("ambience_pillow_fort_room")), SR, 350.0) * 0.55

    shift_noise = ga.lowpass_fft(
        ga.pink_noise(n, ga.seeded_rng("ambience_pillow_fort_shift_noise")), SR, 900.0, shoulder_hz=400.0)
    rng_shift = ga.seeded_rng("ambience_pillow_fort_shifts")
    shift_onsets = np.sort(rng_shift.uniform(2.0, t[-1] - 2.0, size=4))
    shifts = np.zeros(n)
    for t0 in shift_onsets:
        shifts += ga.env_pluck(t, t0, 0.15, 0.35)
    shift_layer = shift_noise * shifts * 0.35

    sparkle_pitches = [NOTE_HZ["A5"], NOTE_HZ["C6"], NOTE_HZ["D6"], NOTE_HZ["E6"]]
    rng_sparkle = ga.seeded_rng("ambience_pillow_fort_sparkles")
    n_sparkles = 8
    sparkle_onsets = np.sort(rng_sparkle.uniform(0.0, t[-1], size=n_sparkles))
    pitch_idx = rng_sparkle.integers(0, len(sparkle_pitches), size=n_sparkles)
    sparkles = np.zeros(n)
    for t0, pi in zip(sparkle_onsets, pitch_idx):
        sparkles += ga.additive_tone(sparkle_pitches[pi], t, t0, attack=0.02, tau=0.5, partials=BELL_PARTIALS, amp=0.22)

    return room + shift_layer + sparkles


def make_ambience_pillow_fort() -> np.ndarray:
    return ga.render_seamless_loop(_ambience_pillow_fort_gen, AMBIENCE_LOOP_SECONDS, xfade_ms=AMBIENCE_XFADE_MS)


def _ambience_wisp_gen(t: np.ndarray) -> np.ndarray:
    """wisp — watery air + gentle lapping: a slowly sweeping airy noise bed
    plus sparse soft low-passed noise "laps" (irregular onsets, ~0.5 s
    decay each) standing in for water lapping against the whale-drift
    world's edges."""
    n = len(t)
    air = ga.swept_noise(n, ga.seeded_rng("ambience_wisp_air"), 500.0, 2200.0,
                          sweep_env=0.4 + 0.15 * np.sin(2.0 * np.pi * t / 9.0)) * 0.4

    lap_noise = ga.lowpass_fft(ga.pink_noise(n, ga.seeded_rng("ambience_wisp_lap_noise")), SR, 700.0, shoulder_hz=300.0)
    rng_lap = ga.seeded_rng("ambience_wisp_laps")
    lap_onsets = np.sort(rng_lap.uniform(1.0, t[-1] - 1.0, size=10))
    laps = np.zeros(n)
    for t0 in lap_onsets:
        laps += ga.env_pluck(t, t0, 0.08, 0.5)
    lap_layer = lap_noise * laps * 0.4

    return air + lap_layer


def make_ambience_wisp() -> np.ndarray:
    return ga.render_seamless_loop(_ambience_wisp_gen, AMBIENCE_LOOP_SECONDS, xfade_ms=AMBIENCE_XFADE_MS)


def _ambience_marmalade_gen(t: np.ndarray) -> np.ndarray:
    """marmalade — distant sleepy village: a soft continuous chimney-wind
    texture plus ONE faint distant bell (G4, marmalade's G-major register
    per music-stems-spec.md's "later giants" guidance) placed partway
    through the loop — "once" per loop iteration reads as "occasional,
    far away" once this bed is looping continuously during play."""
    n = len(t)
    wind = ga.swept_noise(n, ga.seeded_rng("ambience_marmalade_wind"), 250.0, 1000.0,
                           sweep_env=0.35 + 0.12 * np.sin(2.0 * np.pi * t / 13.0)) * 0.5
    bell_t0 = t[-1] * 0.62
    bell = ga.additive_tone(NOTE_HZ["G4"], t, bell_t0, attack=0.02, tau=1.8, partials=BELL_PARTIALS, amp=0.18)
    return wind + bell


def make_ambience_marmalade() -> np.ndarray:
    return ga.render_seamless_loop(_ambience_marmalade_gen, AMBIENCE_LOOP_SECONDS, xfade_ms=AMBIENCE_XFADE_MS)


AMBIENCE_MANIFEST: list[tuple[str, object, float]] = [
    ("bramble",     make_ambience_bramble, -22.0),
    ("pillow_fort", make_ambience_pillow_fort, -24.0),
    ("wisp",        make_ambience_wisp, -22.0),
    ("marmalade",   make_ambience_marmalade, -23.0),
]


# =========================================================================
# Menu sounds — assets/audio/ui/*.ogg (AudioManager.play_ui() API)
# =========================================================================

def make_focus_tick() -> np.ndarray:
    """ui/focus_tick — a single tiny tick: brief low-passed noise (still
    >=10 ms raised-cosine attack, per the register floor — no true click
    transient) plus a barely-there high sine blip. Softer/shorter than
    ui_select so it can fire on every focus-move without wearing out.
    ~0.09 s."""
    dur = 0.09
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("focus_tick")
    noise = ga.lowpass_fft(ga.pink_noise(n, rng), SR, 2200.0, shoulder_hz=800.0)
    tick = noise * ga.env_pluck(t, 0.0, 0.010, 0.03)
    blip = 0.3 * ga.sine(NOTE_HZ["A5"], t) * ga.env_pluck(t, 0.0, 0.010, 0.025)
    x = 0.7 * tick + blip
    return ga.finalize_oneshot(x, fade_out_ms=30.0)


def make_confirm_bloom() -> np.ndarray:
    """ui/confirm_bloom — a gentle two-note bloom (C5 + E5, 30 ms apart) in
    the chime's own bell timbre — softer/shorter than dream_home so it
    never competes with that "all done" moment; this is a small "yes",
    not a reward. ~0.55 s."""
    t = np.arange(int(0.55 * SR)) / SR
    x = ga.additive_tone(NOTE_HZ["C5"], t, 0.0, attack=0.015, tau=0.24, partials=BELL_PARTIALS, amp=0.85)
    x += ga.additive_tone(NOTE_HZ["E5"], t, 0.03, attack=0.015, tau=0.26, partials=BELL_PARTIALS, amp=0.7)
    return ga.finalize_oneshot(x, fade_out_ms=140.0)


def make_pause_open() -> np.ndarray:
    """ui/pause_open — a soft hush swelling IN: low-passed noise opening
    (900->1600 Hz) under a gentle swell, like a held breath as the world
    quiets for the pause menu. ~0.4 s."""
    dur = 0.4
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("pause_open")
    hush = ga.swept_noise(n, rng, 900.0, 1600.0, sweep_env=t / t[-1])
    env = ga.env_swell(t, dur=dur, attack=0.12, release=0.2)
    x = hush * env * 0.8
    return ga.finalize_oneshot(x, fade_out_ms=100.0)


def make_pause_close() -> np.ndarray:
    """ui/pause_close — the same hush releasing OUT (sweep direction and
    envelope reversed relative to pause_open, same texture family so the
    pair reads as one gesture bookending the pause). ~0.4 s."""
    dur = 0.4
    n = int(dur * SR)
    t = np.arange(n) / SR
    rng = ga.seeded_rng("pause_close")
    hush = ga.swept_noise(n, rng, 1600.0, 700.0, sweep_env=1.0 - t / t[-1])
    env = ga.env_swell(t, dur=dur, attack=0.05, release=0.28)
    x = hush * env * 0.75
    return ga.finalize_oneshot(x, fade_out_ms=120.0)


UI_MANIFEST: list[tuple[str, object, float]] = [
    ("focus_tick",    make_focus_tick, -14.0),
    ("confirm_bloom", make_confirm_bloom, -9.0),
    ("pause_open",    make_pause_open, -12.0),
    ("pause_close",   make_pause_close, -12.0),
]


# =========================================================================
# Main
# =========================================================================

def main() -> int:
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(AMBIENCE_DIR, exist_ok=True)
    os.makedirs(UI_DIR, exist_ok=True)
    os.makedirs(SCRATCH_DIR, exist_ok=True)

    print("=== THE BIG NAP -- audio v2 generator (verbs / ambience / positional / ui) ===")
    print(f"sample rate: {SR} Hz mono | ffmpeg: {ga.FFMPEG} (+bitexact)")
    print(f"wav scratch: {SCRATCH_DIR}")
    print()

    report_rows: list[tuple[str, float, float]] = []
    hashes: dict[str, str] = {}

    def _emit(name: str, x: np.ndarray, out_dir: str) -> None:
        wav_path = os.path.join(SCRATCH_DIR, f"{name.replace('/', '_')}.wav")
        ogg_path = os.path.join(out_dir, f"{name}.ogg")
        ga.write_wav(wav_path, x)
        to_ogg_bitexact(wav_path, ogg_path)
        dur, pdb = len(x) / SR, ga.peak_db(x)
        with open(ogg_path, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
        rel = os.path.relpath(ogg_path, REPO).replace(os.sep, "/")
        report_rows.append((rel, dur, pdb))
        hashes[rel] = digest
        print(f"  {rel:<42s} {dur:6.2f}s  peak {pdb:7.2f} dBFS  sha256 {digest[:16]}")

    print("--- SFX v2 (assets/audio/sfx/) ---")
    for name, gen_fn, target_db in SFX_V2_MANIFEST:
        x = ga.normalize_to_peak(gen_fn(), target_db)
        _emit(name, x, SFX_DIR)

    print()
    print(f"--- Ambience beds (assets/audio/ambience/, {AMBIENCE_LOOP_SECONDS:.0f} s loops) ---")
    for name, gen_fn, target_db in AMBIENCE_MANIFEST:
        x = ga.normalize_to_peak(gen_fn(), target_db)
        _emit(name, x, AMBIENCE_DIR)

    print()
    print("--- UI (assets/audio/ui/) ---")
    for name, gen_fn, target_db in UI_MANIFEST:
        x = ga.normalize_to_peak(gen_fn(), target_db)
        _emit(name, x, UI_DIR)

    print()
    print("=== Peak-level / hash summary table ===")
    print(f"{'file':<42s} {'dur(s)':>8s} {'peak(dBFS)':>12s}  sha256[:16]")
    for name, dur, pdb in report_rows:
        print(f"{name:<42s} {dur:8.2f} {pdb:12.2f}  {hashes[name][:16]}")

    print()
    print("Done. Re-run and diff the sha256 column above to confirm determinism.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
