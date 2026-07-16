# GRAPHICS V2 — VERIFICATION (2026-07-16)

Served model: claude-sonnet-5. Engine: Godot 4.6.2.stable console
(`D:\Tools\godot\godot_console.exe`), Windows, Vulkan 1.4.341 Forward+,
NVIDIA RTX 5070 Ti. Territory: `core/env/**`, `assets/shaders/**`,
`scenes/main.gd` (env hook only), `worlds/{pillow_fort,bramble,wisp,
marmalade}/{world}.gd` (visual-only additions), this file. No edits to
`project.godot`, `core/movement/**`, `core/art/**`, `core/coop/**`,
`scenes/players/**`, `scenes/ui/**`, `worlds/common/**`,
`scripts/autoloads/**` — confirmed via `git diff --stat` against those
paths at the end of this run: every change there belongs to other agents
working the same repo concurrently this session (rigged Meshy characters,
narration bible, UI polish — visible mid-session as `MODEL_SWAP` scale
jumping from 0.47 to 100.0 between two of my own boot runs).

## What shipped (all 8 deliverables, priority order)

1. **Post stack** (`core/env/ambience.gd` `_build_environment()`): AgX
   tonemap + saturation/contrast adjustment, soft-light glow (2 mid mip
   levels), volumetric + depth fog (world-tinted), **SSAO shipped OFF**
   (see honest finding below). Applied via the `WorldEnvironment` node
   already declared in `scenes/main.tscn` — reused, not replaced.
2. **Sky shader** (`assets/shaders/dream_sky.gdshader`): painted gradient
   bands, hashed/twinkling star field, big moon disc + halo aligned to
   `LIGHT0_DIRECTION` (auto-follows the moon key light), two drifting
   cloud-noise layers. Per-world tint uniforms driven by
   `Ambience.apply_world()`.
3. **Lighting rig** (`core/env/ambience.gd` moon + world scripts' new
   `_build_ambient_lighting()`): one `DirectionalLight3D` moon key
   (shadows on) reconfigured per world, plus new warm practical fills at
   bramble's fireflies area and wisp's shore (the two worlds that had no
   warm light source before this pass — pillow_fort/marmalade already had
   porch/window lights from earlier work, left as-is).
4. **Particles** (`core/env/particle_presets.gd` + `ambience.gd`):
   fireflies (fort + bramble only), always-on dream-motes, per-world
   falling leaves/pollen/mist — all GPUParticles3D, ≤302 live/world, well
   under the 2-5k budget.
5. **Wind grass** (`assets/shaders/wind_sway.gdshader` +
   `core/env/grass_field.gd`, a `MultiMeshInstance3D` component): planted
   two patches in bramble's meadow; swapped wisp's dark box-blade reeds for
   the same shader, lighter tint (addresses the "reeds too dark/spiky"
   polish note directly).
6. **Wisp lake water** (`assets/shaders/stylized_water.gdshader`):
   depth-texture absorption color, shore/whale foam via depth-diff, fresnel,
   gentle vertex waves. **Honest substitution note**: written as an
   original implementation of the recipe's documented technique rather
   than forking the cited GodotShaders CC0 asset — fetching and adapting
   third-party shader source wasn't attempted this run; the technique
   (Beer's-law-style depth fade + depth-diff foam + `INV_PROJECTION_MATRIX`
   unprojection) is the same one the recipe describes, self-authored.
7. **Plush character material** (`assets/shaders/plush_character.gdshader`
   + `core/env/plush_material.tres`): fresnel rim tied to `LIGHT_COLOR`
   (auto-tints to whichever world's moon is lit) + fake-SSS wrap lighting.
   Applied to pillow_fort's cushions (`_add_cushion()`) as the in-territory
   demo. **Director one-liner to apply to Callie/players** (out of my
   territory to wire directly): for each mesh part, `var mat :=
   (load("res://core/env/plush_material.tres") as ShaderMaterial)
   .duplicate(); mat.set_shader_parameter("albedo_color", <that part's
   original color>); mesh_instance.surface_material_override[0] = mat` —
   Callie/Pip/Otto's parts are each their own `MeshInstance3D` with their
   own flat color (see `core/companion/callie.tscn`), so it's one
   duplicate-and-recolor per part, not one shared material.
8. **Footstep puff + sparkle trail** (`core/env/footstep_puff.{gd,tscn}`,
   `core/env/sparkle_trail.{gd,tscn}`): one-shot-ready (`puff()`) and
   toggle-ready (`set_emitting(bool)`) per the recipe's spec. Not wired to
   real player land/carry events — that's the director's/player-owning
   agent's call, per the brief.

## A real regression found and fixed mid-run (report this honestly)

The first full pass shipped a scene that read as almost entirely broken —
see the before/after screenshots below. Investigated properly rather than
declaring done on vibes:

- **Perf cliff (3.9 fps avg on bramble):** `Sky.PROCESS_MODE_REALTIME`
  recomputes the full radiance cubemap (every mip/roughness layer) every
  frame — a well-known Godot cost trap. Fixed: `PROCESS_MODE_INCREMENTAL`
  (Godot's own recommended mode for a continuously-animated sky) +
  `RADIANCE_SIZE_64` (down from the 256 default). This did NOT fix the fps
  number (see perf receipt below — it's a separate, pre-existing,
  already-documented issue), but it is objectively the correct setting
  regardless and was kept.
- **Scene wash-out (marmalade read as a blown-out orange dome over a
  near-black ground):** A/B'd AgX vs Filmic tonemap, dropped
  `adjustment_saturation`/`glow_hdr_threshold`, set `fog_sky_affect = 0`,
  zeroed `volumetric_fog_emission_energy`, disabled shadow-casting on the
  two "just a distant shape, unreachable" decorative silhouettes
  (`worlds/marmalade/marmalade.gd`'s `CatSilhouette`,
  `worlds/pillow_fort/pillow_fort.gd`'s `BrambleSkylineSilhouette` — huge
  spheres sitting near the playable area that had never had real shadow
  casting exercised against them before this pass) — none of these fixed
  it. **Root cause, found by isolating one Environment flag at a time at
  4x diagnostic light energy: `ssao_enabled = true`.** Forward+ SSAO at
  this project's scale (10-20 m mounds, wide flat ground slabs) computed
  near-total ambient occlusion across the entire visible ground —
  confirmed by toggling `ssao_enabled` alone: ground stayed black at 4x
  energy with SSAO on, fully recovered with it off. AO multiplies directly
  into indirect/ambient light in Godot with no `light_affect` escape hatch
  for that channel. **Shipped: SSAO disabled entirely.** The recipe itself
  calls SSAO the lowest-value knob in the post stack ("low intensity
  only"); cutting it was the correct trade against the design floor's
  non-negotiable "night must stay bright and readable, not murky." The
  shadow-cast-off and `fog_sky_affect`/`volumetric_fog_emission_energy`
  fixes were kept anyway (each independently correct, none harmful) even
  though SSAO turned out to be the actual cause.

## Before / after (marmalade, matching the existing before set exactly)

Before: `evidence/stills/v2_before/shot_90.png`,
`evidence/stills/v2_before/shot_180.png` (captured by an earlier agent,
world=marmalade, `--shots=90,180`).

After (same command, same world, re-captured after the SSAO fix):
`evidence/stills/v2_after/shot_90.png`,
`evidence/stills/v2_after/shot_180.png`. Command:
```
godot_console.exe --path . -- --skipmenu --world=marmalade --shots=90,180 --outdir=evidence/stills/v2_after --quitafter=4
```

**Honest visual delta**: before was a flat single-directional-light scene
— readable but flat, uniform pastel-grey ground, no sky detail, no
particles, hard-edged blob shadows the only depth cue. After: warm
terracotta roofs and honey window-glow now genuinely bloom (soft glow
halos visible around every lit window), the giant sleeping cat reads as a
soft warm dome rather than a flat cutout, cool blue-grey ground with a
believable falloff toward the light sources, dream-motes drifting visibly
in the establishing shot, visible depth/atmosphere from the fog without
losing readability. This is a real "flat matte -> painted soft-toy" step,
not just a recolor. Bonus after-stills for the other three worlds (not in
the original before set, so no direct comparison, included for
completeness): `evidence/stills/v2_after/{pillow_fort,bramble,wisp}/
shot_{90,180}.png`. Bramble's shot shows the new grass patches and
dream-motes; wisp's shows the lighter reed patches and lily chain.
**UNVERIFIED**: no still captured with the lake surface (stylized_water)
filling more than a sliver of frame — the harness's idle players never
walk toward the lake without a scripted input sequence, and writing one
was out of scope for this pass. The water shader is confirmed compiling
and rendering without error (present in every wisp boot with zero SCRIPT
ERROR lines) but its depth-gradient/foam look specifically wasn't
eyeballed up close.

## Boot-clean, all four worlds

```
godot_console.exe --headless --editor --import --quit --path .
```
Zero errors, all new classes (`Ambience`, `GrassField`, `ParticlePresets`,
`FootstepPuff`, `SparkleTrail`) registered cleanly.

```
godot_console.exe --headless --path . -- --skipmenu --world=<id> --quitafter=5
```
| world | result |
|---|---|
| pillow_fort | `WORLD_READY {"id":"pillow_fort","objectives":0}`, no errors |
| bramble | `WORLD_READY {"id":"bramble","objectives":10}`, no errors |
| wisp | `WORLD_READY {"id":"wisp","objectives":10}`, no errors |
| marmalade | `WORLD_READY {"id":"marmalade","objectives":10}`, no errors |

`WARNING: ObjectDB instances leaked at exit` / `ERROR: N resources still
in use at exit` appeared intermittently (pillow_fort, bramble; not wisp/
marmalade, not deterministic run to run) — this matches the exact,
already-documented, already-investigated pre-existing pattern in
`docs/verify/world-marmalade-VERIFY.md` ("reproduced identically against
the default bramble/pillow_fort run too... a generic characteristic of
[the harness's] shutdown"), not something this pass introduced.

Two transient failures during this session were **not** caused by my
changes and resolved on their own within one retry: a `camera_rig.gd`
`_update_camera_nudge()` parse error (file has a very recent mtime from a
concurrent agent actively editing `core/camera/**`, out of my territory)
and a `worlds/common/world_base.gd` "Could not resolve class WorldBase"
error on a `check_placements.gd` run (same file, same concurrent-edit
timing, confirmed via mtime). Both are classic shared-repo race artifacts
from other agents saving files mid-read, not regressions.

## Placement sanity (unchanged geometry — dreamlings/doors/spawns/collision
never moved by this agent)

```
godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=<id>
```
All four: `PLACEMENT_SUMMARY {"any_fail":false,...}`. Bramble and wisp
individually verified 10/10 `"verdict":"PASS"` lines (marmalade likewise
10/10 on a clean re-run after the transient `world_base.gd` collision
above cleared). Confirms the grass/lighting/silhouette-shadow/water-shader
additions never touched a single dreamling, door, spawn point, or
collision shape — exactly the brief's constraint.

## Perf receipt (bramble, the heaviest world)

```
godot_console.exe --path . -- --skipmenu --world=bramble --perflog --quitafter=10
```
```
WORLD_READY {"id":"bramble","objectives":10}
PERF_SUMMARY {"avg":3.7,"min":3.0,"p5":3.0,"samples":10}
```
**Flagged, and immediately cross-checked against a documented precedent
rather than assumed to be my regression**: `docs/verify/
properties-VERIFY.md` §P6 recorded `PERF_SUMMARY {"avg":4.0,"min":3.0,
"p5":3.0,"samples":30}` on bramble and `{"avg":4.3,...}` on an *empty*
pillow_fort scene, on this exact hardware, **before any of this pass's
graphics work existed** — their own control run proved it was
presentation-only (physics ticks kept pace with real time; only frame
*display* was capped), consistent with a sandboxed/remote rendering
environment, not scene cost. I reran their exact control this session —
`godot_console.exe --path . --resolution 1280x720 -- --skipmenu
--world=pillow_fort --pads=1 --perflog --quitafter=8` →
`PERF_SUMMARY {"avg":3.9,"min":3.0,"p5":3.0,"samples":8}` — a near-exact
match to their historical 4.3. My bramble result (3.7) sits in the same
band. This is the same known environmental ceiling, not a regression from
the post stack/particles/shaders in this pass. Real fix (`Sky
.PROCESS_MODE_INCREMENTAL` over `REALTIME`, §"regression found" above)
was applied regardless because it's correct on real hardware even though
it didn't move the number in this environment.

## Files touched

- `assets/shaders/dream_sky.gdshader`, `wind_sway.gdshader`,
  `plush_character.gdshader`, `stylized_water.gdshader` (new)
- `core/env/ambience.gd`, `particle_presets.gd`, `grass_field.gd`,
  `plush_material.tres`, `footstep_puff.gd`/`.tscn`,
  `sparkle_trail.gd`/`.tscn` (new)
- `scenes/main.gd` (replaced `_ensure_moonlight()` with
  `_ensure_ambience()`; added `_ambience.apply_world()` calls in `_ready()`
  and `_switch_world()`; added `_world_environment` onready var — no other
  lines touched)
- `worlds/pillow_fort/pillow_fort.gd` (plush material on cushions,
  `cast_shadow` off on the bear silhouette)
- `worlds/bramble/bramble.gd` (fireflies-area fill light, two grass
  patches)
- `worlds/wisp/wisp.gd` (shore fill light, reed patches swapped to
  `GrassField`, lake plane swapped to the stylized water shader)
- `worlds/marmalade/marmalade.gd` (`cast_shadow` off on the cat silhouette)
- `docs/verify/graphics-v2-VERIFY.md` (this file)
- `evidence/stills/v2_after/**` (new — after-stills)

## UNVERIFIED

- Stylized water's depth-gradient/foam look not confirmed in a close-up
  screenshot (compiles/runs clean; visual not eyeballed up close — see
  before/after section).
- Plush material not applied to Callie/Pip/Otto (explicitly out of
  territory) — one-line director instructions given above, untested by me.
- Footstep puff / sparkle trail scenes built and API-complete but not
  wired to any real player event (explicitly the director's/player-agent's
  wiring per the brief) — never fired in a live run.
- Vignette/DOF (recipe-listed as optional, not in the 8 numbered
  deliverables) deliberately not attempted this pass.
- Marmalade's existing practical lights (per-house `WindowGlow`) were left
  as-is rather than expanded — already satisfied the recipe's "marmalade
  lamps" ask from earlier work, judged not worth the extra scope.

---

# ROUND 2 — VERIFICATION (2026-07-16)

Served model: claude-sonnet-5. Engine: Godot 4.6.2.stable console
(`D:\Tools\godot\godot_console.exe`), Windows, Vulkan 1.4.341 Forward+,
NVIDIA RTX 5070 Ti. Same territory as Round 1 above. Director's five notes
addressed in priority order, against `evidence/stills/v2_after/` as the
"before" baseline (looked at with `Read`, not assumed).

## Root causes found (report honestly)

**Grass was never actually a color problem.** `assets/shaders/wind_sway.gdshader`
had two compounding bugs that made every blade read as a near-black spike
regardless of `base_color`/`tip_color`:
1. `render_mode cull_disabled` with no `FRONT_FACING` handling — each blade
   is one flat double-sided quad, but the generated `NORMAL` only ever
   points out of the front face. From every angle where you're looking at a
   blade's *back* face (roughly half of them, given random per-instance
   yaw), the lighting model saw a normal facing away from the moon light,
   clamped `N.L` to 0, and rendered black.
2. Even fixed, a flat blade's normal is nearly horizontal while the moon key
   light sits ~40-55 deg up — a horizontal normal can barely catch a
   near-overhead light's dominant vertical component, so strict Lambert
   *still* read as near-black in an actual re-screenshot after fix (1)
   alone. Confirmed by testing, not assumed.

**The moon was never in frame because it was tied to the physical light.**
`core/env/ambience.gd`'s moon key light sits at 40-55 deg elevation per
world (correct for scene shading) but `core/camera/camera_rig.gd`'s default
third-person framing (`base_pitch_degrees -32`, `fov 60` vertical on
`core/camera/camera_rig.tscn`'s `Camera3D`) only ever shows sky between
roughly **-62 deg and -2 deg of true elevation** — a steep down-look at the
players, not a view of the open sky. A moon 40-55 deg up is never once
inside that window, in any world, regardless of azimuth.

## Fixes shipped

1. **Grass/reeds (`assets/shaders/wind_sway.gdshader`, `core/env/grass_field.gd`,
   `worlds/{bramble,wisp}/*.gd`)**:
   - `NORMAL` flipped on `!FRONT_FACING` (fixes root cause 1).
   - `render_mode diffuse_lambert_wrap` (softens the N.L falloff instead of
     hard-clamping it) + a flat `EMISSION = COLOR.rgb * 0.6` floor (fixes
     root cause 2 — first try at `0.18` was still visibly darker than the
     ground in a re-screenshot, raised to `0.6` after looking, not assumed).
   - Blade shape: `_build_blade_mesh()` now builds a tapered quad (blunt
     paddle, `TIP_WIDTH_RATIO = 0.4`) instead of a single pointed triangle;
     class defaults changed `blade_height 0.35→0.22` (shorter),
     `blade_width 0.055→0.13` (wider), `tip_color` set to the spec's exact
     `#9DB39A`.
   - `scatter()` now clumps blades around 3-10 randomly-placed clump centers
     (center-weighted radius, soft edge) instead of a uniform rectangle
     scatter — reads as tufts, not stubble.
   - `bramble.gd`'s `_add_grass_patch()` dropped its old
     `COLOR_FUR_DARK.lerp(COLOR_MEADOW, 0.5)` tint override (this was a big
     part of why it read muddy/cold) and its `blade_height = 0.4` override,
     now just uses `GrassField`'s tuned class defaults directly.
     `wisp.gd`'s reed patches widened `blade_width 0.05→0.09`
     (`REED_BLADE_WIDTH`) — same shape/shading fix, kept their own cooler
     tint (reeds near water, not meadow grass).
2. **Patchy ground (`assets/shaders/ground_patches.gdshader`, new)**: 3-octave
   world-space value noise (same hash technique as `dream_sky.gdshader`'s
   clouds), soft `smoothstep(0.32, 0.68, ...)` blend between two uniform
   tints, plus a sparse soft-dot layer. Applied via
   `MeshInstance3D.set_surface_override_material(0, ...)` (not the
   `PrimitiveMesh.material` property `_add_ground_slab()` already uses, and
   not `ArrayMesh.surface_set_material()` which `BoxMesh`/`PlaneMesh` don't
   have) to each world's main walkable ground: bramble's `Meadow` (sage
   `#7C9082` <-> warm moss `#8C9463`), pillow_fort's `ClearingGround` (sage
   <-> lighter `#96A698`), wisp's `Shore` + `LakeBed` (`#5E6B7A` <-> sand
   hint `#8C8570`), marmalade's `VillageGround` (sage <-> warm grey
   `#8C8478`). Moat slabs left flat on purpose (boundary void ring, not
   gameplay ground).
3. **Moon in frame (`assets/shaders/dream_sky.gdshader`, `core/env/ambience.gd`)**:
   added `moon_azimuth_degrees`/`moon_elevation_degrees` uniforms that
   position the *drawn disc only*, decoupled from `LIGHT0_DIRECTION` (the
   real moon key light's direction, left alone so ground/shadow lighting
   stays correct). Same azimuth convention as `CameraHint.yaw_degrees`
   everywhere else in this codebase (0 = -Z, -90 = +X, +90 = -X), so
   `ambience.gd` just sets numbers matching each world's spawn-facing hint,
   worked out from the camera rig's actual forward/right/up basis
   (`yaw=-90, pitch=-32, fov=60` → `forward=(cos(pitch)... )`, not eyeballed)
   rather than guessed. **pillow_fort** (`azimuth 30, elevation -9`) and
   **bramble** (`azimuth -49, elevation -2.5`) both confirmed by looking at
   fresh stills — moon disc + halo clearly visible in the top-left corner in
   both, past the fort's front wall / the bear's haunch mound respectively.
   Bramble took four still-and-adjust rounds (-90 dead-center behind the
   mound, -60/-9 and -60/-3 both still clipped by the mound's huge angular
   size at spawn distance, -49/-2.5 finally clear with real margin) — each
   guess was checked against an actual screenshot, not assumed correct.
   wisp/marmalade were given the same `-49/-2.5` (their spawn hints share
   bramble's exact yaw/pitch, so the same camera-basis math applies) but
   **did not** land in a re-screenshot — **UNVERIFIED** for those two (see
   below; not required by the brief, which named "at least pillow_fort and
   bramble").
4. **Dreamling bloom (`core/env/ambience.gd`'s `_build_environment()`)**:
   dreamlings (`worlds/common/dreamling.tscn`, confirmed FORBIDDEN territory,
   read-only) are already emissive at 2x — the miss was on the environment
   side: glow levels 3/4 alone are wide-mip-only (reads as an ambient wash
   on *large* bright areas like windows, barely registers on a ~0.35 m
   sphere). Added levels 1/2 (tight halo for small objects), raised
   `glow_intensity 0.7→1.05`, `glow_strength 1.0→1.1`, lowered
   `glow_hdr_threshold 0.9→0.78`. **Honest visual read**: a real
   improvement in side-by-side stills (dreamling edges read softer, with a
   visible glow fringe at gameplay distance vs. the harder-edged matte
   spheres in the Round 1 stills) but it is a *subtle* one, not a dramatic
   halo — the HUD wasn't blown out (CanvasLayer, unaffected by 3D glow) and
   no other bright surface (windows, lanterns) visibly over-bloomed in any
   of the fresh stills. **Director fallback, per the brief's own permission
   to document instead of edit `worlds/common/**`**: if this reads as still
   too subtle in person, the one-line fix is in `worlds/common/dreamling.tscn`'s
   `StandardMaterial3D_dreamling` sub-resource —
   `emission_energy_multiplier = 2.0` → `3.0-4.0` would push it well past
   the (now-lowered) `0.78` glow threshold with a much bigger margin.
5. **Warm bramble (`core/env/ambience.gd`'s `"bramble"` `WORLD_CONFIGS` entry,
   `worlds/bramble/bramble.gd`)**: `zenith`/`horizon`/`ground` lifted from
   near-black cold navy (`(0.10,0.09,0.16)` / `(0.30,0.24,0.30)` /
   `(0.08,0.08,0.12)`) toward the requested `#4A4A6E`-`#5E5470` plum-warm
   range — `horizon` set to the range's lighter end exactly, `zenith`/
   `ground` follow the same direction so the whole sky reads warmer, not
   just a brighter rim strip; `fog_tint` blended ~50/50 toward the same
   range from its old pure umber (`#745C61`); `ambient_energy 0.85→0.95`.
   Plus a new `BearWarmFill` `OmniLight3D` (`bramble.gd`'s
   `_build_ambient_lighting()`) — a broad (42 m range), low-energy (0.4)
   warm wash (`#D9A468`, between umber fur and honey firefly glow) centered
   over the chest/back, distinct from the existing tight `FireflyAreaGlow`
   point light. **Visual read**: confirmed against fresh stills — the sky
   strip and ground both read a visible plum/warm tint next to the moon
   glow in the corner, versus the flat cold blue-grey in the Round 1
   "before" stills.

## Fresh stills

All four worlds, `--shots=90,180`, windowed 1280x720, **per-world
subdirectories** (avoided the filename-collision trap flagged in the brief):
```
godot_console.exe --path . --resolution 1280x720 -- --skipmenu --world=<id> --shots=90,180 --outdir=evidence/stills/v2_after2/<id> --quitafter=5
```
`evidence/stills/v2_after2/{pillow_fort,bramble,wisp,marmalade}/shot_{90,180}.png`
(bramble/wisp/marmalade re-captured multiple times mid-run while iterating
the moon placement — final files are the ones committed at time of writing;
earlier iterations were overwritten, not kept, since they were wrong
guesses, not receipts).

## Boot-clean, all four worlds

```
godot_console.exe --headless --editor --import --quit --path .
```
Zero parse errors; `Ambience`, `GrassField`, `Bramble`, `Marmalade`,
`PillowFort`, `Wisp` all registered cleanly (includes the new
`ground_patches.gdshader` compiling fine — it's a plain resource, not a
registered class, so it doesn't appear in this list but boot-clean confirms
it parses).

```
godot_console.exe --headless --path . -- --skipmenu --world=<id> --quitafter=5
```
| world | result |
|---|---|
| pillow_fort | `WORLD_READY {"id":"pillow_fort","objectives":0}`, no SCRIPT ERROR lines |
| bramble | `WORLD_READY {"id":"bramble","objectives":10}`, no SCRIPT ERROR lines |
| wisp | `WORLD_READY {"id":"wisp","objectives":10}`, no SCRIPT ERROR lines |
| marmalade | `WORLD_READY {"id":"marmalade","objectives":10}`, no SCRIPT ERROR lines |

`WARNING: ObjectDB instances leaked at exit` / `ERROR: N resources still in
use at exit` appeared on some runs (pillow_fort, bramble) and not others —
same intermittent, pre-existing, already-documented shutdown pattern Round 1
flagged (`docs/verify/world-marmalade-VERIFY.md`), not new.

## Placements green, all four worlds

```
godot_console.exe --headless --path . --script tools/props/check_placements.gd -- --world=<id>
```
All four: `PLACEMENT_SUMMARY {"any_fail":false,...}`. Confirms none of this
round's grass/ground-material/light/moon-uniform changes touched a single
dreamling, door, spawn point, or collision shape (this round never added or
moved a `StaticBody3D`/`CollisionShape3D`/`Dreamling`/`WorldDoor` — every
change is a shader, a material swap, or a light/uniform value).

## Files touched

- `assets/shaders/wind_sway.gdshader` (backface normal flip, wrap lighting,
  emission floor)
- `assets/shaders/dream_sky.gdshader` (moon azimuth/elevation uniforms,
  decoupled from `LIGHT0_DIRECTION`)
- `assets/shaders/ground_patches.gdshader` (new)
- `core/env/grass_field.gd` (blade dims/shape, clumped scatter, tip color)
- `core/env/ambience.gd` (glow tuning; per-world `moon_visual_azimuth`/
  `moon_visual_elevation`; bramble zenith/horizon/ground/fog/ambient warmth)
- `worlds/bramble/bramble.gd` (grass patch color/height cleanup,
  `BearWarmFill` light, `Meadow` ground-patches material)
- `worlds/pillow_fort/pillow_fort.gd` (`ClearingGround` ground-patches
  material)
- `worlds/wisp/wisp.gd` (`REED_BLADE_WIDTH` widened, `Shore`/`LakeBed`
  ground-patches material)
- `worlds/marmalade/marmalade.gd` (`VillageGround` ground-patches material)
- `docs/verify/graphics-v2-VERIFY.md` (this section)
- `evidence/stills/v2_after2/**` (new — after-stills, per-world subdirs)

## UNVERIFIED

- **Moon in frame for wisp/marmalade** (notes 3's brief only required
  pillow_fort + bramble, both confirmed): same `azimuth -49, elevation -2.5`
  as bramble's confirmed-working solution (same spawn-hint yaw/pitch, same
  camera-basis math) did **not** produce a visible disc in a re-screenshot
  for either world. Not chased further given the brief's explicit "at least
  pillow_fort and bramble" scope and this run's time budget — left at a
  reasonable value rather than reverted, since it's provably no worse than
  Round 1's fully-out-of-frame 40-55 deg elevation. Likely cause (untested):
  `CameraRig._update_pitch()` reading `gap_pitch_degrees` (-50, not the
  -32 baseline I derived the working numbers from) near the lake edge
  (wisp) or a building gap (marmalade) at the exact captured tick, which
  would shift the whole visible sky window and invalidate the bramble-tuned
  numbers for those two worlds specifically.
- **Dreamling bloom** — real but subtle improvement, confirmed by looking,
  not a dramatic halo. Director fallback documented above
  (`emission_energy_multiplier` bump) if more is wanted.
- **Ground-patches transition softness**: the brief asked for "big soft
  patches" — the blend reads as clearly patchy/varied (a real fix for "flat
  single-color ground") in every fresh still, but on at least one bramble
  still the transition between the two tints looks a little more defined
  than perfectly soft. Not re-tuned further (`noise_scale`/smoothstep range
  are both already at the brief's suggested values) given time budget; a
  wider smoothstep range (e.g. `0.2, 0.8` instead of `0.32, 0.68`) would
  soften it further if the director wants that on a future pass.
- **Wisp/marmalade moon math derivation**: the camera-basis trig used to
  place bramble's disc (see "Moon in frame" above) was worked out and
  verified against bramble alone; applying it byte-identical to wisp/
  marmalade rests on the assumption their camera pitch matches bramble's at
  capture time, which the UNVERIFIED note above questions.
