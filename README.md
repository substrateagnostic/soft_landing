# THE BIG NAP

*a game about being small and awake in a world that is huge and asleep*

Once every hundred years, the great animals lie down for the Big Nap. When
giants sleep, their dreams leak out — little glowing creatures called
**dreamlings** that drift away on the night wind. Two kids in animal onesies,
**Pip** (duck, small) and **Otto** (bear, big), are awake past bedtime — the
only ones light enough to walk on sleeping giants. The Moon whispers the job:
*bring the dreams home.*

Nothing here can hurt you. If you fall, a dreamling catches you in a bubble
and floats you back — the **Soft Landing**. That's also the repo name,
because the rescue is the design.

## What this is

A 3D collectathon platformer in the Mario 64 lineage, built in Godot 4.6 for
a 4-year-old and their parent — two gamepads on one couch, or one player with
a buddy AI. It is the third AI-directed game in a small portfolio
(*drawdown*: elegiac · *ill-will*: riotous · *the big nap*: **tender-enormous**),
directed end-to-end by Claude (Fable 5) with a human producer.

**The design floor (non-negotiable):** no fail states, no timers, no death,
no fall damage — gentle rescue instead. One stick + jump + interact is always
enough. The camera is fully automatic (the right stick is never read — this
is grepped at every gate). Blob shadow + landing ring always on. Progress
lives in a world that remembers across sessions and is never skill-gated.

## Running it

Godot 4.6.x. From the repo root:

```
godot --path .                      # title screen; press A
godot --path . -- --skipmenu --world=bramble
```

Two pads → co-op (Pip + Otto). One or zero pads → solo with buddy AI
(keyboard fallback: WASD + Space + E drives Otto).

## The autoplay harness

The game drives itself for testing and video receipts — deterministic
input-playback under `--fixed-fps`:

```
godot --path . -- --skipmenu --world=bramble --pads=2 \
  --script=tools/harness/scripts/gate2_meadow.json \
  --outdir=evidence/_scratch/run1 --quitafter=29
```

See `tools/harness/README.md`. Every feature lands with receipts under
`docs/verify/` — commands, captured output, and an honest UNVERIFIED list.
`evidence/gate2_slice.mp4` is 66 s of harness-driven gameplay.

## Repo map

`PITCH.md` (the fiction) · `GAME_BRIEF.md` (one page) · `SPEC.md` (contracts)
· `ART_BIBLE.md` · `DEFINITION_OF_DONE.md` (evidence-linked) ·
`docs/DECISIONS.md` (D1-D16) · `docs/research/` (sourced) ·
`core/` (movement/camera/rescue/co-op — the product) · `worlds/` (module
contract: the hub and Bramble the bear) · `tools/harness/` ·
`alexmemory.md` (ops log) · `NEEDS_YOU.md` (producer gate state).

## License

Apache-2.0. Personal/OSS project. The four-year-old's name is used with
parental blessing; the bear is asleep and prefers not to be credited.
