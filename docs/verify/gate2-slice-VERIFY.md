# GATE 2 — GREY-BOX SLICE VERIFICATION (2026-07-15)

Engine: Godot 4.6.2 console (`D:\Tools\godot\godot_console.exe`), Windows.
All headless property runs use `--fixed-fps 60`. Receipts quoted verbatim
(trimmed). Video: `evidence/gate2_slice.mp4` (66.0 s, 1280x720, four
segments: approach / meadow+rescue / carry+toss / solo buddy). Stills:
`evidence/stills/*.png`.

## The movie recipe (D11)
```
godot_console.exe --path . --write-movie evidence/_scratch/movies/<seg>.avi \
  --fixed-fps 60 --resolution 1280x720 -- --skipmenu --world=<w> --pads=N \
  --script=tools/harness/scripts/<seg>.json --quitafter=S
ffmpeg -i <seg>.avi -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart <seg>.mp4
ffmpeg -f concat -i concat.txt -c copy evidence/gate2_slice.mp4   # 66.038 s
```

## Property receipts

**Collect + magnet generosity** (`gate2_meadow.json`, bramble, pads=2):
```
EVT {"id":"d01","t":441,"type":"dreamling_collected","world_id":"bramble"}
EVT {"id":"d02","t":798,"type":"dreamling_collected","world_id":"bramble"}
```

**Rescue — exactly one, then control restored** (same run):
```
RESCUE {"seat":1}          # walked off the south edge on purpose
WARP {"seat":2}            # Otto leash-warped back into frame (feature demo)
```
Post-rescue PLAYER_POS shows Pip set down ~2 m inland and walking again.

**Carry & toss** (`gate2_toss.json`, pillow_fort, pads=2):
```
CARRY {}
TOSS {}
EVT {"seat":1,"t":194,"type":"landed"}   # Pip lands from the toss, control back
```

**Solo buddy AI** (`gate2_buddy.json`, pads=1): PLAYER_POS receipts show Otto
trailing 2-3 m behind Pip through two direction changes, and mirroring Pip's
jump (both at y=1.9, t=360). Zero P2 inputs exist in the script.

**Coyote time — both directions** (`gate2_coyote.json`):
```
HARNESS_TELEPORT {"pos":[0.0,2.0,0.0],"seat":1}   # airborne, coyote running
EVT {"seat":1,"t":129,"type":"jumped"}             # jump 8f (133ms<200ms) after leaving ground: FIRES
HARNESS_TELEPORT {"pos":[0.0,4.0,0.0],"seat":1}
EVT {"seat":1,"t":436,"type":"landed"}             # jump pressed 30f (500ms) after: NO jumped event
```

**Collect → return → save → fort growth** (`gate2_return.json`, then a fresh
process booting the fort):
```
EVT {"id":"d10","t":125,"type":"dreamling_collected","world_id":"bramble"}
EVT {"id":"d10","t":125,"type":"dream_returned","world_id":"bramble"}
MOON_SAID {"key":"dream_home","text":"Carry the dream home so the giant can keep sleeping softly."}
save.json (next process): fort_stage: 1 | returned: ['d10'] | total: 1
```
Still: `evidence/stills/fort_stage1_nightlights.png` — three night-lights over
the fort door, built by a NEW process from the saved stage. Persistence across
restart proven.

**World-door round trip** (`gate2_doors.json`):
```
DOOR {"to":"bramble"}    → WORLD_READY {"id":"bramble","objectives":10}
DOOR {"to":"pillow_fort"} → WORLD_READY {"id":"pillow_fort","objectives":0}
```

**Determinism** (harness agent, docs/verify/harness-VERIFY.md): two identical
runs → byte-identical events.jsonl (diff exit 0).

**No right stick / no camera input** (corefeel-VERIFY): grep receipts — zero
joypad axis 2/3 references, zero Input.* reads in core/camera/.

**Import clean**: `--headless --editor --import --quit` exit 0 after all
integration edits (run before each recording session).

## Director's feel pass — bugs found via receipts and fixed this session
1. **Movement was world-axis, not camera-relative** — remapped through live
   camera yaw (Mario 64 convention); buddy virtual input stays world-space.
2. **Moat was a stuck-trap**: solid apron at -1.5 m vs 1.5 m jump height and a
   rescue line at -8 that could never fire. Moat sunk below the rescue line —
   every walk-off now ends in the Soft Landing (design floor).
3. **Dreamling trigger was a 17.5 cm bullseye** — now 0.6 m + magnetism
   (drifts to a nearby player, drifts home when alone). Kirby's fuzzy-input
   lesson, made diegetic: dreams want to be found.
4. **d02 was buried inside the haunch mound** (placement inside the hill
   sphere's footprint) — relocated to open meadow.
5. **Rescue returned players to the lip they fell from** (newest ring-buffer
   sample = the corner pixel) → instant re-fall double-rescue. Now returns a
   few samples back — set down "a little way inland."
6. **DreamDoor was edge-triggered and its 2 m trigger was mostly filled by
   the solid ear bump** — collecting d10 beside it could never fire a return.
   Now polled every frame + trigger enlarged to cover both stances.
7. Cosmetics: dreamling release scaled to exactly 0 (det==0 engine errors,
   clamped); `monitoring` toggled inside a signal callback (deferred).

## UNVERIFIED (honest list)
- Jump-buffer property (≤0.22 s press-before-landing fires on landing): only
  the no-late-fire control is proven; the positive case needs a
  frame-measured landing — queued for the next property pass.
- TTS audio quality: MOON_SAID call-path receipts are green; actual audible
  SAPI voice needs producer ears (no audio devices asserted headless).
- CameraHint yaw convention visually confirmed only for the three Bramble
  hints seen on video; fort hint framing looks correct in stills.
- d10 spawns embedded in the solid ear bump (magnetism rescues it — but its
  glow is hidden until a player is near). Placement nudge queued.
- 60 fps sustained: not yet instrumented (perf receipt is a Gate 4 item).
