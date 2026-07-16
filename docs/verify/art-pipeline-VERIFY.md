# art-pipeline-VERIFY.md — Meshy forge + ModelSlot import seam

Engine: `D:\Tools\godot\godot_console.exe` -> `4.6.2.stable.official.71f334935`.
Built against the live worktree while other agents worked in parallel on
`tools/harness/**`, `worlds/bramble|wisp|marmalade/**`, `scenes/ui/**`,
`assets/audio/**`, `scripts/autoloads/**` — nothing outside this task's
territory (`tools/meshy/**`, `assets/models/**`, `core/art/**`,
`scenes/players/pip.tscn`, the licensed `pillow_fort.gd` builder functions,
`docs/verify/art-pipeline-VERIFY.md`, `evidence/stills/art/**`) was touched.
`git status --porcelain` at the end of this pass:

```
 M scenes/players/pip.tscn
 M worlds/pillow_fort/pillow_fort.gd
?? assets/models/
?? core/art/
?? docs/verify/art-pipeline-VERIFY.md
?? evidence/stills/art/
?? tools/meshy/
```

(`worlds/wisp/` also shows untracked in a full status — that's a parallel
agent's work, not touched by this pass.)

## 1. Manifest — `tools/meshy/manifest.json`

Exactly the 4 assets specified, ART_BIBLE.md's Meshy house prompt appended
verbatim by the forge script at submission time (not baked into the
manifest file itself, so the suffix stays a single source of truth — same
pattern as the proven sibling `un_party_game/tools/meshy_forge.ps1`):

| id | category | target_height_hint (m) |
|---|---|---|
| pip | character | 0.9 |
| lantern | prop | 0.5 |
| firefly_jar | prop | 0.35 |
| cushion | prop | 0.4 |

House suffix (verbatim, ART_BIBLE.md): `soft plush low poly, rounded chunky
toddler-toy proportions, flat colors, matte, no textures needed, game
asset, clean silhouette, single object, gentle and friendly, Kenney/KayKit
style`.

## 2. Forge script — `tools/meshy/meshy_forge.ps1`

Ported from `D:\Projects\un_party_game\tools\meshy_forge.ps1` (read-only
reference, never written to): same preview→refine request shapes, same
`Get-Batches`/`Save-Report` PowerShell-footgun-safe helpers (documented
inline), same retry/backoff/timeout handling. Adapted: paths default to
this project (`-EnvPath D:\Projects\soft_landing\.env`), report field names
match this brief's ask (`preview_task`, `refine_task`, `credits`,
`served_model`), and a `-DryRun` switch was added (parses the manifest,
builds full prompts, prints the batch plan — zero HTTP calls, zero credits)
so the script could be validated before spending the real budget.

### 2a. Dry run (zero credits spent) — validated first

```
pwsh -NoProfile -Command "& 'tools/meshy/meshy_forge.ps1' -DryRun"
```
Output (trimmed): parsed all 4 manifest entries, printed each `full_prompt`
with the house suffix correctly appended, reported the batch plan (1 batch
of ≤5), output dir, and report path — no errors, exit before any network
call. Confirms manifest parsing / prompt construction / path resolution
before the real spend.

### 2b. Real run — `pwsh -NoProfile -Command "& 'tools/meshy/meshy_forge.ps1'"`

Output (trimmed, key never printed at any point):
```
Meshy Forge - reading API key (never printed)...
Meshy Forge - API key loaded into memory only.
Manifest: 4 assets from D:\Projects\soft_landing\tools\meshy\manifest.json
Processing 4 assets (0 resumed-skipped).

PREVIEW batch 1/1: pip, lantern, firefly_jar, cushion
  submitted preview pip -> 019f69bf-1f50-72f3-8a8b-8d1ff8107bc7
  submitted preview lantern -> 019f69bf-291c-79b0-a18a-3e9320a1cca4
  submitted preview firefly_jar -> 019f69bf-316e-7e36-b5e6-a22ac1b6fe58
  submitted preview cushion -> 019f69bf-3aad-79b2-b9e5-028826ccbff7
  preview SUCCEEDED lantern credits=20 served_model=meshy-6 (not_reported_by_api_echoing_requested)
  preview SUCCEEDED firefly_jar credits=20 served_model=meshy-6 (not_reported_by_api_echoing_requested)
  preview SUCCEEDED pip credits=20 served_model=meshy-6 (not_reported_by_api_echoing_requested)
  preview SUCCEEDED cushion credits=20 served_model=meshy-6 (not_reported_by_api_echoing_requested)

REFINE batch 1/1: pip, lantern, firefly_jar, cushion
  submitted refine pip -> 019f69c2-d1a4-772f-8358-6cf526baaa81
  submitted refine lantern -> 019f69c2-d3ed-7a5f-a603-74ee32361946
  submitted refine firefly_jar -> 019f69c2-d63f-7a60-9dc4-f5720ae6abbd
  submitted refine cushion -> 019f69c2-d88f-7ee3-996e-c189b8d0a677
  refine SUCCEEDED + downloaded lantern credits=10 total=30
  refine SUCCEEDED + downloaded pip credits=10 total=30
  refine SUCCEEDED + downloaded cushion credits=10 total=30
  refine SUCCEEDED + downloaded firefly_jar credits=10 total=30

TOTAL: 4  ok=4  preview_only=0  failed=0  resumed_skip=0
TOTAL CREDITS CONSUMED: 120
```

All 4 assets succeeded on the **first** attempt — the one-retry-per-failed-asset
path in the script was never exercised (nothing failed to exercise it on).
Every GLB was downloaded immediately on `SUCCEEDED` (the presigned URL is
never cached, per the proven pattern).

### 2c. `served_model` — honest finding

The live API's `GET /openapi/v2/text-to-3d/:id` response (checked across all
8 tasks: 4 preview + 4 refine) does **not** echo back a distinct model
identifier field under any of `ai_model` / `model` / `model_version` /
`served_model` — matching `docs/research/pipeline.md`'s note that the
documented sample response shape doesn't show one either. `Get-ServedModel`
in the forge script correctly falls through to its honest fallback for
every task: `served_model: "meshy-6"`, `served_model_source:
"not_reported_by_api_echoing_requested"` — i.e. this is the *requested*
model, not independently confirmed by the API. Recorded as-is, not
papered over.

### 2d. Report — `tools/meshy/forge_report.json` summary table

| id | category | credits | served_model | served_model_source | status |
|---|---|---|---|---|---|
| pip | character | 30 | meshy-6 | not_reported_by_api_echoing_requested | ok |
| lantern | prop | 30 | meshy-6 | not_reported_by_api_echoing_requested | ok |
| firefly_jar | prop | 30 | meshy-6 | not_reported_by_api_echoing_requested | ok |
| cushion | prop | 30 | meshy-6 | not_reported_by_api_echoing_requested | ok |

**TOTAL: 120 / 120 budgeted credits.** 0 retries used (0 of the 1 allowed
retry consumed). GLBs land at `assets/models/meshy/generated/<id>.glb`
(1.4–2.0 MB each, textures auto-extracted by Godot's glTF importer to
sibling `<id>_0.jpg` files on import).

## 3. Import receipt — headless import, exit 0

```
D:\Tools\godot\godot_console.exe --headless --editor --import --quit --path D:/Projects/soft_landing
```
Trimmed output (final clean pass):
```
[   0% ] update_scripts_classes | ModelSlot
[  33% ] update_scripts_classes | PillowFort
[ DONE ] update_scripts_classes

[   0% ] _update_scan_actions | Started Scanning actions... (4 steps)
[   0% ] _update_scan_actions | cushion.glb
[  20% ] _update_scan_actions | firefly_jar.glb
[  40% ] _update_scan_actions | lantern.glb
[  60% ] _update_scan_actions | pip.glb
[ DONE ] _update_scan_actions

[   0% ] reimport | cushion.glb ... [ DONE ] import
[  20% ] reimport | firefly_jar.glb ... [ DONE ] import
[  40% ] reimport | lantern.glb ... [ DONE ] import
[  60% ] reimport | pip.glb ... [ DONE ] import
[  80% ] reimport | Finalizing Asset Import...
[ DONE ] reimport
```
Exit code `0`. `ModelSlot` registers as a global class alongside
`PillowFort` with zero script errors. All 4 GLBs import cleanly.

## 4. MODEL_SWAP receipts — headless boot, default save state

```
D:\Tools\godot\godot_console.exe --headless --path D:/Projects/soft_landing -- --skipmenu --world=pillow_fort --quitafter=4
```
Output (verbatim):
```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

HARNESS_FLAGS {"quitafter":"4","skipmenu":true,"world":"pillow_fort"}
MODEL_SWAP {"id":"pip","scaled":0.472176738856881}
CAMERA_RIG_READY
MODEL_SWAP {"id":"lantern","scaled":0.262320410476045}
MODEL_SWAP {"id":"cushion","scaled":0.638011298671118}
MODEL_SWAP {"id":"cushion","scaled":0.549398618300129}
WORLD_READY {"id":"pillow_fort","objectives":0}
HUD_READY {"pips":0,"world":"pillow_fort"}
MOON_SAID {"key":"new_area","text":"A new place to explore. Let's see what's waiting."}
EVT {"seat":1,"t":4,"type":"landed"}
EVT {"seat":2,"t":4,"type":"landed"}
HARNESS_NOTE quitafter fallback fired (harness-level timer, 4.0s)
```
Boots clean, zero errors/warnings. One `MODEL_SWAP` for `pip` (Pip's
`ModelSlot` under `Visual`, `pip.tscn`), one for `lantern` (the porch
lantern), and **two distinct** `MODEL_SWAP` lines for `cushion` with
**different** scale factors (0.638 vs 0.549 — ratio 1.162, matching the
1.08/0.93 explicit jitter values in `_build_cushions()`, ratio 1.161) —
confirms the "varied uniform scale ±15%, instanced per cushion" requirement
lands correctly and deterministically (no `randf()` involved). No
`firefly_jar` swap in this run — expected: this machine's shared
`user://save.json` (D14 single save slot) currently has `fort_stage: 1`
from other agents' concurrent sessions, and `_build_fort_growth()` only
builds the jar at `stage >= 2`. Not touched (see §7).

Otto (the other player, `otto.tscn`) never gets a `MODEL_SWAP` line in any
run in this pass — correct, `otto` isn't in this batch's 4-asset manifest,
so `otto.tscn` was never touched and Otto stays grey-box by design.

## 5. Grey-box-fallback receipt — GLB genuinely absent, zero errors

Per D10 ("swappable for any other GLB source"), the game must work with
**zero GLBs on disk**. Tested by temporarily removing one asset's files and
re-booting:

```
mv assets/models/meshy/generated/lantern.glb assets/models/meshy/generated/lantern.glb.bak
```
First rename-only boot **still showed** `MODEL_SWAP {"id":"lantern",...}` —
an important honest finding: Godot's import cache (the `.glb.import`
sidecar + its `.godot/imported/` cache entry) satisfies
`ResourceLoader.exists()` on its own, independent of whether the original
source `.glb` is still on disk. This is normal Godot behavior (the cached
converted resource is what actually loads), not a bug in `ModelSlot` — but
it means a true "GLB missing" test has to remove the `.import` sidecar too:

```
mv assets/models/meshy/generated/lantern.glb.import assets/models/meshy/generated/lantern.glb.import.bak
```
Re-boot output (verbatim, `lantern` `MODEL_SWAP` line now absent, no
errors, no warnings):
```
HARNESS_FLAGS {"quitafter":"4","skipmenu":true,"world":"pillow_fort"}
MODEL_SWAP {"id":"pip","scaled":0.472176738856881}
CAMERA_RIG_READY
MODEL_SWAP {"id":"cushion","scaled":0.638011298671118}
MODEL_SWAP {"id":"cushion","scaled":0.549398618300129}
WORLD_READY {"id":"pillow_fort","objectives":0}
...
HARNESS_NOTE quitafter fallback fired (harness-level timer, 4.0s)
```
The grey-box `LanternPost` `MeshInstance3D` remains visible (never hidden —
`ModelSlot._swap_in()` only hides siblings after confirming the GLB loaded,
per `core/art/model_slot.gd`), pip/cushion swaps are unaffected, zero
errors. Renamed back immediately:
```
mv assets/models/meshy/generated/lantern.glb.bak assets/models/meshy/generated/lantern.glb
mv assets/models/meshy/generated/lantern.glb.import.bak assets/models/meshy/generated/lantern.glb.import
```
Confirmed restored with one more boot — `MODEL_SWAP {"id":"lantern",...}`
back, identical scale factor `0.262320410476045` as before the rename
round-trip (proves nothing was corrupted by the test).

## 6. Windowed stills — `evidence/stills/art/`

Movie Maker / screenshots need a real window (`--headless` uses the
`dummy` rasterizer, no real pixel data — pipeline.md §2.3 /
tools/harness/README.md), so these runs use the plain windowed console
binary. A small walk-input-playback script,
`tools/meshy/scripts/fort_props_walk.json` (my own territory, not
`tools/harness/**` — it only supplies data consumed by the existing
`--script=` flag), moves Pip east of the fort's footprint from spawn out
past the back doorway, so a single frame could catch the lantern and both
cushions together (they sit on opposite/near/far sides of the fort's solid
walls — verified empirically with `--poslog=20` headless dry runs first, no
credits involved, to pick frames before spending render time).

```
D:\Tools\godot\godot_console.exe --path D:/Projects/soft_landing -- --skipmenu --world=pillow_fort --script=tools/meshy/scripts/fort_props_walk.json --shots=90,110,130,170 --outdir=evidence/_scratch/art_walk2 --quitafter=6
```

- **`pip_meshy.png`** (from `shot_90.png`) — Pip's real Meshy GLB (duck
  onesie, hood with bill, cream belly) close-up mid-walk, fort + nightlight
  orbs + right cushion in frame behind.
- **`fort_props.png`** (from `shot_110.png`) — lantern (small honey-glow
  paper lantern on its post, right beside Pip past the fort's back corner)
  **and both cushions** (left + right, distinct scale) **in the same
  frame**, plus the fort wall and nightlight orbs. Otto (buddy AI,
  grey-box brown capsule — no GLB for `otto`, correct) also visible,
  trailing behind.

Both `MODEL_SWAP` lines for `pip`/`lantern`/`cushion`×2 print before the
first screenshot, confirming every visible prop in both stills is the real
generated asset, not the grey-box primitive.

### 6a. Bonus — `firefly_jar_meshy.png`, via a temporary test scene

The brief's jar caveat: *"jar needs fort_stage>=2 — if the current save's
stage < 2, note it and screenshot the jar via a temporary spawn in your own
test scene or skip with honest note."* This machine's `user://save.json`
(single shared save slot, D14) currently has `fort_stage: 1` from other
agents' concurrent test sessions running in parallel on this repo.
Mutating that shared file to force `stage >= 2` — even temporarily — risked
corrupting a concurrent agent's live run, so instead of touching shared
state this pass used the explicitly-licensed "temporary spawn in your own
test scene" path: `tools/meshy/test_jar_scene.gd` + `.tscn` (my own
territory), which builds the **exact same** anchor + grey-box mesh +
`ModelSlot("firefly_jar")` construction as `_build_fort_growth()`'s
`stage >= 2` branch, standalone, with its own camera/light — same code
path, zero shared state touched, zero fort/save mutation.

```
D:\Tools\godot\godot_console.exe --path D:/Projects/soft_landing tools/meshy/test_jar_scene.tscn -- --shots=5 --outdir=evidence/_scratch/art_jar3 --quitafter=3
```
`MODEL_SWAP {"id":"firefly_jar","scaled":0.183624287333232}` printed, clean
screenshot saved, copied to `evidence/stills/art/firefly_jar_meshy.png`.
Quality note (honest, not a pipeline failure): the generated jar reads as a
plain frosted-white glass jar with a cork lid — it matches the "round glass
mason jar with cork lid" half of the prompt clearly, but the "filled with
tiny glowing golden fireflies" detail didn't come through as a visible
separate element in the mesh/texture (a known limitation of flat-color
low-poly text-to-3D at this budget — Meshy modeled the container, not
discrete internal light sources). The swap mechanism itself (ModelSlot
load/scale/ground/hide-primitive) worked correctly; this is purely an art
content note for a future regen if the fireflies need to read more clearly.

`tools/meshy/test_jar_scene.gd`/`.tscn` were left in place (not deleted) —
they're inert (not referenced by `project.godot`'s `run/main_scene` or any
autoload, never auto-loaded), harmless to leave in `tools/meshy/**` as
reusable evidence-capture tooling for future jar-related regens.

## 7. UNVERIFIED

- **`served_model` is not independently confirmed by the API** — see §2c.
  Recorded honestly as `not_reported_by_api_echoing_requested` rather than
  assumed; if Meshy adds this field to the response later, the script's
  `Get-ServedModel` will pick it up automatically (checks `ai_model` /
  `model` / `model_version` / `served_model` in that order).
- **`fort_props.png` shows the lantern + both cushions, but not the
  firefly jar** — the jar needs `fort_stage >= 2` (see §6a); the bonus
  `firefly_jar_meshy.png` covers it via an isolated test scene instead of a
  combined in-hub shot, since forcing `fort_stage >= 2` on the shared save
  slot for one screenshot risked interfering with a concurrent agent's
  session.
- **No video/movie receipt taken for this pass** — the brief asked for
  stills only (`--shots`), not `--write-movie`; not attempted.
- **Otto's own Meshy asset (bear onesie) was never generated** — outside
  this batch's 4-asset budget, by design (manifest is exactly the 4 the
  brief specified). Otto remains grey-box everywhere, correctly.
- **Firefly-jar "glowing fireflies" visual detail is weak** — see §6a
  quality note. Not re-rolled (would exceed the 1-retry-for-1-failed-asset
  budget rule, and the asset didn't fail — it succeeded, just with a softer
  art result than the prompt aimed for).

## Files created / modified

```
tools/meshy/manifest.json                 (new)
tools/meshy/meshy_forge.ps1                (new)
tools/meshy/forge_report.json              (new, generated by the real run)
tools/meshy/scripts/fort_props_walk.json   (new, evidence-capture input script)
tools/meshy/test_jar_scene.gd              (new, evidence-capture test scene)
tools/meshy/test_jar_scene.tscn            (new, evidence-capture test scene)
core/art/model_slot.gd                     (new — the D10 import seam)
assets/models/meshy/generated/pip.glb          (new, +.import, +_0.jpg/.import)
assets/models/meshy/generated/lantern.glb      (new, +.import, +_0.jpg/.import)
assets/models/meshy/generated/firefly_jar.glb  (new, +.import, +_0.jpg/.import)
assets/models/meshy/generated/cushion.glb      (new, +.import, +_0.jpg/.import)
scenes/players/pip.tscn                    (modified — ModelSlot added under Visual)
worlds/pillow_fort/pillow_fort.gd          (modified — lantern/cushion/jar builders wrap
                                             their grey-box primitive in a ground-anchored
                                             container + ModelSlot; doors/spawn/camera
                                             code untouched)
docs/verify/art-pipeline-VERIFY.md         (this file)
evidence/stills/art/pip_meshy.png          (new)
evidence/stills/art/fort_props.png         (new)
evidence/stills/art/firefly_jar_meshy.png  (new, bonus)
```

No files outside this task's licensed territory were modified. No git
commit made, per instructions.
