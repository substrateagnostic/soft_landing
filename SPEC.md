# SPEC.md — THE BIG NAP technical contracts

Engine: Godot 4.6.x · GDScript, static typing everywhere · Jolt (default).
Conventions in AGENTS.md. Decisions cited as D-numbers (docs/DECISIONS.md).

## Autoloads (global state only — everything else is scenes + signals)

| Autoload | Owns |
|---|---|
| `GameState` | current world id, dreamling counts (per-world + total), fort growth stage, session flags. Emits `dreamling_collected(world_id, id)`, `dream_returned(world_id, id)`, `world_completed(world_id)`. |
| `InputRouter` | pad enumeration, seat assignment (P1/P2), co-op vs solo mode, hot-swap on connect/disconnect. Emits `mode_changed(mode)`, `seat_assigned(seat, device)`. |
| `AudioManager` | lullaby stem player (per-world stem sets, layer count driven by dreams returned — the viola seam), SFX pool. `play_stem_layer(world_id, layer)`, `play_sfx(name)`. Stems live in `assets/audio/stems/<world_id>/layer_<n>.ogg`; placeholder synth stems ship first (D-PITCH audio). |
| `SaveManager` | single-slot JSON at `user://save.json`, auto-save on every `dream_returned` / fort change (D14). `save_game()`, `load_game()`, schema below. |
| `TheMoon` | TTS seam (D13): `say(text_key)` → line lookup (`data/moon_lines.json`) → `DisplayServer.tts_speak` (Windows SAPI now, swappable voice later). Queues, never overlaps, interruptible by newer objective lines. Also logs every spoken line to stdout for harness receipts. |

## Input map (the floor — D8)

Actions (both seats, per-device): `move_left/right/up/down` (stick),
`jump` (south button), `interact` (east/west both mapped). Optional kb+m:
WASD + Space + E for P2 only. NEVER: camera actions, inverted axes.
Extra verbs are additive ceiling and must never be required to finish anything.

## core/ — the product

### `core/movement/player_body.gd` (both kids share it; per-kid tuning res)
CharacterBody3D. All feel numbers in `data/tuning/pip_movement.tres` /
`otto_movement.tres` (`MovementTuning` Resource, D2 starter values: move 4.0,
accel 40, decel 25, jump_height 1.5, time_to_apex 0.45, fall_gravity_mult
1.55, apex_hang_window, coyote 0.20, buffer 0.22, floor_snap 0.45, air_control
0.5, terminal 20). Fixed jump height (D3). Gravity derived, never hand-set.
State: grounded / rising / apex (onesie flutter plays here) / falling /
carried / tossed / bubbled. `is_on_floor()` read after `move_and_slide()`;
`floor_snap_length = 0` on the jump frame; `floor_constant_speed = true`;
`platform_on_leave = ADD_UPWARD_VELOCITY` (breathing-chest launches must
inherit lift).

### `core/camera/camera_rig.gd` (D4/D5)
SpringArm3D rig, sphere cast (margin ~0.25), excludes both players,
geometry-only mask. Target: ground-projected anchor = 0.7·Pip + 0.3·Otto
(solo: 1.0·Pip), vertical dead zone; exp-decay smoothing `1-exp(-k·delta)`.
Yaw: `CameraHint` Area3D volumes (designer-placed, priority int, blend time)
→ fallback damped velocity leash. Pitch: base ~-35°, biases downward when no
ground within landing-probe range. Right stick never read.

### `core/rescue/soft_landing.gd` (D6)
Tracks per-player safe-ground history (position ring buffer, only while
`is_on_floor()` on `safe` physics layer). Trigger: kill-plane Area3D per world
OR `y < world.rescue_floor_y`. Sequence: freeze input → bubble mesh + giggle
SFX → float to last safe position (2.5 s ease) → pop + brief sparkle →
release. Emits `player_rescued(seat)`. Never a fail state; no counter shown.

### `core/readability/` (D9)
`blob_shadow.tscn`: Decal, always-on, full-strength, both players.
`landing_ring.tscn`: raycast down from player while airborne, projected ring
at hit point, scales with height. Attached by player scene, no per-world work.

### `core/coop/`
`seat_manager.gd` consumes InputRouter: 2 pads = co-op; 1/0 pads = solo (Otto
→ `buddy_ai.gd`: follow at 2.5 m, auto-jump when Pip jumps a gap, teleport-
join Pip's bubble warp, walk-up + `interact` = toss). `carry_toss.gd`: Otto
`interact` near Pip = pick up; `interact` again or `jump` = gentle toss
(fixed arc, apex ~2.2 m — reaches "high shelf" markers). Pip `interact` near
Otto while carried = hop down. No player-player collision (D7): players on
distinct layers, neither collides with the other.
Leash: if Otto (or Pip) exits camera frustum + 2 m for >1.5 s → bubble
auto-warp to partner (same visual as rescue — one vocabulary).

## World module contract (Phase 5 parallel builds happen against THIS)

Each world = `worlds/<id>/` containing `<id>.tscn` (root: Node3D with script
extending `core/world_contract.gd`) + `world.json` manifest. The contract:

```gdscript
class_name WorldContract extends Node3D
# REQUIRED overrides:
func world_id() -> String
func spawn_points() -> Dictionary      # {"pip": Transform3D, "otto": Transform3D}
func objective_ids() -> Array[String]  # dreamling ids, stable, order-free
func rescue_floor_y() -> float
# REQUIRED signals (emitted by the world):
signal objective_collected(id: String)  # dreamling caught
signal objective_returned(id: String)   # dream carried home
signal exit_requested()                 # player chose to leave (fort door)
```

Rules: a world never touches another world, the hub, or autoload internals
beyond the documented API; all dreamlings placed per D12 cadence; every world
provides ≥1 `CameraHint` per distinct traversal space; hub instantiates worlds
via manifest only. The hub (`worlds/pillow_fort/`) implements the same
contract (its "objectives" are fort-growth stages).

## Save schema (`user://save.json`, D14)

```json
{ "version": 1,
  "total_dreams": 0,
  "worlds": { "bramble": { "collected": [], "returned": [], "completed": false } },
  "fort_stage": 0,
  "settings": { "tts_enabled": true, "music_volume": 1.0, "sfx_volume": 1.0 } }
```
Unknown keys preserved on load (forward-compat). Corrupt file → rename to
`save.bak.json`, start fresh, Moon says nothing scary.

## Autoplay harness (Phase 3, built EARLY — GOAL)

CLI contract (parsed in `tools/harness/harness.gd`, boot scene checks
`OS.get_cmdline_user_args()`):
`--skipmenu` · `--seed=N` · `--world=<id>` · `--pads=0|1|2` (simulated seats)
· `--script=tools/harness/scripts/<name>.json` (input-playback: timestamped
action events per seat, deterministic under `--fixed-fps`) · `--shots=N,M,...`
(screenshot frames → `--outdir`) · `--outdir=evidence/_scratch/<run>` ·
`--quitafter=SECONDS`. Movie receipts (D11): windowed, `--write-movie
evidence/<name>.avi --fixed-fps 60`, ffmpeg → mp4 (H.264, yuv420p, faststart).
Harness logs one JSON line per event (collected/returned/rescued/warped/said)
→ receipts are greppable. Console binary for anything whose stdout matters.

## Evidence & verify (house)
Every feature lands with `docs/verify/<feature>-VERIFY.md` (commands + output
+ evidence paths). UNVERIFIED is an honest state. UTF-8/LF receipts.
