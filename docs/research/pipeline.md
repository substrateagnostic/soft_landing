# Pipeline research — Meshy text-to-3D + Godot video receipts

Written 2026-07-15 for soft_landing (Godot 4.6 3D platformer). Covers two
independent pipeline seams: art generation (Meshy) and automated video
verification receipts (Godot Movie Maker).

---

## 1. Meshy API — current state (July 2026)

### 1.1 What the sibling project already proved

Prior art: `D:\Projects\un_party_game\docs\design\15-meshy-pipeline.md` and
`D:\Projects\un_party_game\tools\meshy_forge.ps1` — a working, batch-driven
PowerShell text-to-3D pipeline used to generate 32 props this month (following
three earlier batches, 18/18 KEEP-verdict assets total).

**Proven flow:** `POST /openapi/v2/text-to-3d` twice per asset —
`mode: "preview"` (untextured mesh) then `mode: "refine"` (`preview_task_id`
→ textured mesh) — polling `GET /openapi/v2/text-to-3d/:id` every 5s until a
terminal status.

**Proven preview parameters** (reproduced exactly across 4 batches, 18/18 keep
rate):
```json
{
  "mode": "preview",
  "prompt": "<description> + house style suffix",
  "ai_model": "meshy-6",
  "model_type": "lowpoly",
  "topology": "triangle",
  "target_polycount": 8000,
  "should_remesh": true,
  "moderation": false,
  "target_formats": ["glb"],
  "origin_at": "bottom"
}
```

**Proven refine parameters** (flat-color house style, PBR intentionally off):
```json
{
  "mode": "refine",
  "preview_task_id": "<id>",
  "ai_model": "meshy-6",
  "enable_pbr": false,
  "moderation": false,
  "target_formats": ["glb"],
  "origin_at": "bottom"
}
```

**House-style suffix** (verbatim, reused across every batch to avoid a style
seam between props): `low poly, chunky toy-like proportions, flat colors, no
textures needed, game asset, clean silhouette, single object, Kenney/KayKit
style`.

**Costs confirmed empirically:** preview = 20 credits (meshy-6/lowpoly),
refine = 10 credits → **30 credits per finished static prop**, matching
`docs.meshy.ai/en/api/pricing` at the time.

**Quirks / operational lessons baked into `meshy_forge.ps1`:**
- `model_urls.glb` is a **presigned, expiring URL** — download immediately on
  `SUCCEEDED`, never cache the URL.
- Batch submissions at 5-in-flight (well under the queued-task cap) — preview
  phase fully drains before refine phase starts, so at most one kind of task
  is queued at a time.
- On `FAILED`/`CANCELED` preview: **one automatic retry** with the prompt
  suffixed `, simple clean geometry, single distinct object` before giving up
  per-id.
- `429`/`5xx` → exponential backoff (5s/10s/20s), 3 retries, then hard-fail
  that id.
- Per-task poll timeout: 15 minutes (typical actual time ~1-3 min).
- API key lives in a gitignored `.env`, read into a process variable only —
  never logged, never written to disk in any script output (report JSON omits
  it).
- PowerShell footguns documented inline in the script and worth carrying
  forward to any soft_landing tooling: `ConvertFrom-Json` piped straight into
  `@(...)` can silently collapse a multi-item JSON array into a 1-item outer
  array (fix: assign first, `@()` the variable after); a bare
  `Where-Object` match of exactly one item returns a scalar with no `.Count`
  (fix: wrap every `Where-Object` result in `@()`).

### 1.2 Current API docs (docs.meshy.ai, verified July 2026)

**Text-to-3D** — [docs.meshy.ai/en/api/text-to-3d](https://docs.meshy.ai/en/api/text-to-3d):
- `POST /openapi/v2/text-to-3d`, `GET /openapi/v2/text-to-3d/:id`, and (new
  since the sibling project's doc) `GET /openapi/v2/text-to-3d/:id/stream`
  for SSE progress instead of polling.
- `ai_model`: `"meshy-5"`, `"meshy-6"`, or `"latest"` — meshy-6 confirmed
  current/default.
- `model_type`: `"standard"` | `"lowpoly"`.
- `topology`: `"quad"` | `"triangle"`.
- `target_polycount`: 100–300,000 (default 30,000 if unset — the sibling
  project's explicit `8000` is well below default, intentionally).
- `should_remesh`: boolean, **defaults to `false` on meshy-6** (the sibling
  project sets it explicitly `true` — do not rely on the old meshy-5 default).
- `pose_mode`: `"a-pose"`, `"t-pose"`, or `""` — relevant for characters
  destined for rigging (see below); **not used** in the sibling project's
  static-prop pipeline.
- `target_formats`: array from `["glb", "obj", "fbx", "stl", "usdz", "3mf"]`.
- Refine adds `hd_texture` (4K textures, meshy-6+ only) and
  `texture_prompt`/`texture_image_url` for guided texturing — neither used by
  the sibling pipeline (flat-color house style, no textures).

**Rigging** — [docs.meshy.ai/en/api/rigging](https://docs.meshy.ai/en/api/rigging)
(this is the piece the sibling project's static-prop pipeline never needed —
new research for soft_landing, which has a moving player character):
```
POST   /openapi/v1/rigging          -- create rigging task
GET    /openapi/v1/rigging/:id      -- poll status
GET    /openapi/v1/rigging/:id/stream
DELETE /openapi/v1/rigging/:id
```
Required (one of): `input_task_id` (a prior text-to-3d task id) or
`model_url` (public URL / data URI to a `.glb`). Optional: `height_meters`
(default 1.7), `texture_image_url`.

Output: `rigged_character_fbx_url` and `rigged_character_glb_url`, plus a
`basic_animations` object containing **only two motions — walking and
running** — each offered as skinned GLB, skinned FBX, and armature-only GLB.
No idle, jump, land, or attack animation is generated. Cost: **5 credits**
per rig (confirmed).

**Hard limitations for a game character:**
- Humanoid bipeds only — "non-humanoid assets are not supported."
- Input mesh must already be **textured** (untextured meshes fail) and
  ≤300,000 faces (use the separate Remesh endpoint, 1 credit, to get under
  that first).
- Model must face **+Z** (glTF forward) or rigging fails/misaligns.
- Auto-rig runtime is fast (~30s per the Meshy tutorial pages) but the
  animation set is minimal — walk/run only. Any platformer verb beyond
  walking/running (jump, land, squash-stretch, idle-breathe, wall-slide,
  death/respawn — all things a kid's platformer needs) has **no Meshy
  endpoint**; it would have to be hand-authored or come from a separate
  animation-retargeting step (Mixamo-style) onto the rigged skeleton, which
  is out of scope for "just call the API."

**Pricing** — [docs.meshy.ai/en/api/pricing](https://docs.meshy.ai/en/api/pricing):
preview (meshy-6/lowpoly) 20 credits, preview (other models) 5 credits,
refine/texture 10 credits, auto-rig 5 credits, remesh 1 credit, animation
(separate library-animation endpoint, distinct from the walk/run bundled with
rigging) 3 credits.

**Rate limits** — [docs.meshy.ai/en/api/rate-limits](https://docs.meshy.ai/en/api/rate-limits):
20 req/s across paid tiers (Enterprise 100 req/s), queued-task caps vary by
tier (this page currently lists Pro/Premium/Ultra/Studio/Enterprise — the
tier *names* differ from what the sibling project's doc recorded nine days
earlier as Pro/Max/Max Unlimited on the same date, 2026-07-15; treat exact
tier-to-cap mapping as unverified/in flux, see bottom). Regardless of tier
naming, the sibling project's defensive pattern — 5 tasks in flight,
sequential preview-then-refine phases — stays safely under every tier's cap
and should be reused as-is.

### 1.3 Verdict: auto-rig+animate vs. static mesh + procedural squash-and-stretch

**For soft_landing's player/NPC characters: static mesh + procedural
squash-and-stretch in-engine is the safer path** — same conclusion the
sibling project reached independently for its own (non-platformer) use case,
and the evidence here is stronger for a kid's platformer specifically:

1. **Animation coverage gap.** Meshy's bundled rig output is walk+run only.
   A platformer needs idle, jump-up, apex/fall, land-squash, and probably a
   celebration/hurt-free "oops" bounce (no fail states per this project's
   design doc elsewhere in the repo — but *some* landing feedback is still
   expected). None of that exists in the API. You'd be hand-animating in
   Blender on top of a Meshy-generated skeleton anyway, which erases most of
   the "just call the API" time savings.
2. **Style constraint.** The sibling project's proven house style is flat
   color, chunky low-poly, toy-like — exactly the "clean silhouette" style
   that is *easiest* to squash-and-stretch procedurally in code (scale the
   mesh/skeleton root non-uniformly on jump/land) without fighting bone
   weights or a rig imported from an external tool.
2b. Squash-and-stretch as a **procedural node transform** (scale curves on
   land/jump, no baked animation channels) sidesteps GLB/FBX animation-import
   fidelity questions entirely — nothing to verify on import beyond "the mesh
   imported."
3. **Pipeline seam simplicity.** A static-mesh contract (Meshy → GLB → Godot
   import dir, no rig/skeleton data to validate) is a much smaller surface to
   keep correct than a rigged-character contract (bone naming, retarget
   compatibility, animation clip naming conventions inside Godot's
   AnimationPlayer/AnimationTree). Fewer moving parts = fewer places a nightly
   batch run can silently produce a broken asset.
4. **Cost.** Rig+animate adds 5 credits on top of the 30/prop the static
   pipeline already costs, for two animations that don't cover the actual
   gameplay verb set — poor value next to writing one procedural
   squash-and-stretch function once and reusing it for every character.

If a future need arises for actual bone-driven animation (a boss character
with a big telegraphed wind-up, say), the rigging endpoint is proven-capable
enough to use *selectively* — it's not a dead end, just not the default path
for the roster.

---

## 2. Godot 4.6 Movie Maker — video receipts

Source: [docs.godotengine.org — Creating movies](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html),
[MovieWriter class](https://docs.godotengine.org/en/stable/classes/class_moviewriter.html),
and cross-checked against community/source discussion for the headless
question specifically (see 2.3).

### 2.1 Command line

```
godot --path <project_dir> --write-movie output.avi --fixed-fps 60 --resolution 1280x720 --quit-after <frame_count>
```
- `--write-movie <path>`: enables Movie Maker mode; path relative to the
  **project folder**, not cwd. Extension picks the writer (`.avi` → AVI/MJPEG,
  `.ogv` → Theora/Vorbis, `.png` → PNG sequence + separate `.wav`).
- `--fixed-fps <n>`: **not real-time** — engine steps simulate as fast as
  possible with a constant delta, so frame pacing in the output is perfect by
  construction (no dropped/stuttered frames), independent of how slow the
  actual render takes on the host machine. This is the determinism guarantee:
  fixed timestep + fixed-fps writer means the same scene replay produces
  frame-identical output run to run (modulo any non-deterministic gameplay
  logic — RNG seeding is on the game, not the engine).
- `--resolution <w>x<h>`: sets output resolution directly.
- `--quit-after <n>`: auto-quits after N frames — needed for unattended CI/
  batch runs since Movie Maker has no "record N seconds" flag of its own.

### 2.2 Output formats

| Writer | Container | Notes |
|---|---|---|
| AVI | MJPEG video + uncompressed PCM audio | 4 GB file-size ceiling, fast encode, no transparency |
| OGV (new-ish) | Theora video + Vorbis audio | inter-frame compression (smaller than AVI), directly playable in Godot's own `VideoStreamPlayer`, no transparency |
| PNG sequence | one `.png` per frame + one `.wav` | lossless, largest on disk, only format supporting alpha (`transparent_bg` project setting) |

For a "video receipt" use case (proof a scene/interaction ran and rendered
correctly, watched on a phone) **AVI is the pragmatic default** — one file,
audio embedded, fast to produce, no per-frame-PNG cleanup step.

### 2.3 Headless compatibility — verified, and it's a hard no

**Movie Maker requires a real display driver; `--headless` does not work with
it.** `--headless` forces the `headless` display driver, whose only rasterizer
option is `dummy` — it explicitly disables rendering output. Movie Maker (and
anything depending on actual rendered frame content, e.g. screenshots) needs
a window to be spawned so there is real pixel data to write. This is called
out directly in Godot's own docs/proposals around off-screen rendering
support for render farms (godotengine/godot-proposals#5790): headless mode
"disables all rendering code," so Movie Maker "requires a window [to] be
spawned by Godot," which is explicitly *not* desired for render-farm/CI use
but is currently unavoidable.

**Practical implication for soft_landing's receipt workflow:** run the
windowed binary (no `--headless`), on Windows this just means a normal
`godot.exe --write-movie ...` invocation — the window can be left in the
background/unfocused, it does not need focus or visibility to record
correctly, but it does need to exist. If this ever needs to run on a
headless Linux CI box, the fallback is a virtual framebuffer (Xvfb) providing
a real (if invisible) display for Godot's normal (non-headless) display
driver to attach to — `--headless` itself is not an option. Not needed for
this Windows-only project today; noting for completeness since the task
brief asked to verify this exactly.

### 2.4 Project settings (`movie_writer/*` family, under Editor/Rendering in
Project Settings, also settable via `--fixed-fps`/`--write-movie` at the CLI
without touching the .godot project file at all):

- Movie file path, FPS, video quality (0.01–1.0, always lossy even at max),
  mix rate, speaker mode (stereo/5.1/7.1), disable-vsync-for-encoding-speed,
  and OGV-specific audio quality / encoding speed / keyframe interval knobs.
- Output resolution is controlled the normal way — `Display > Window > Size >
  Viewport Width/Height` (or `--resolution` at the CLI, which is simplest for
  a scripted receipt run since it needs no project-file edits).

### 2.5 Shutdown correctness

Must exit cleanly (`get_tree().quit()` from a script, e.g. after
`--quit-after` triggers it, or the window's close button) — killing the
process with Ctrl+C/F8 leaves an AVI with no duration header (unplayable/
broken in some players). For an automated receipt script this means: drive
the quit from in-game logic or `--quit-after`, never `taskkill`/Ctrl+C the
process to end a recording.

### 2.6 ffmpeg transcode to MP4 for phone review

The docs' own example (`ffmpeg -i input.avi -crf 15 output.mp4`) is
under-specified for phone playback — it doesn't pin the pixel format or
enable fast start, both of which matter for iOS/Android video players and
for scrubbing before the whole file downloads. The correct command for this
use case:

```
ffmpeg -i output.avi -c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium -c:a aac -b:a 192k -movflags +faststart soft_landing_receipt.mp4
```

- `-pix_fmt yuv420p`: forces 4:2:0 chroma subsampling — without this, ffmpeg
  may pick 4:4:4 or another format from the MJPEG source that many phone/
  hardware decoders (notably iOS Safari/Photos) refuse to play.
- `-movflags +faststart`: moves the MP4 `moov` atom to the front of the file
  so playback/scrubbing can start before the download finishes — the
  standard fix for "video won't play/scrub on a phone browser."
- `-crf 18`: visually near-lossless, reasonable file size for a short
  gameplay clip (18 is tighter than the docs' example `-crf 15` default scale
  reference — for x264 lower CRF = higher quality; 18 is a well-established
  "visually lossless" x264 convention, 15 also fine if size isn't a concern).
- `-c:a aac`: AVI's audio track is uncompressed PCM; re-encode to AAC for a
  playable/compact MP4 audio track (raw PCM in MP4 has poor player support).

---

## Recommendations for soft_landing

### Art pipeline seam: Meshy → GLB → import dir contract

Reuse `meshy_forge.ps1`'s proven shape almost verbatim, adapted to this
project's directory layout:

1. **Manifest-driven, not ad hoc.** `tools/meshy_manifest.json` (or
   soft_landing's equivalent): `{id, prompt, category, target_height_hint}`
   per asset. One prompt suffix constant (a soft_landing house-style string,
   analogous to the sibling project's Kenney/KayKit line) appended to every
   prompt so the whole roster stays visually coherent.
2. **Static props and static character meshes only** through the
   preview→refine text-to-3d flow, with the exact proven parameters above
   (`meshy-6`, `lowpoly`, `triangle`, explicit `target_polycount`,
   `should_remesh: true`, `enable_pbr` decided once per house style,
   `target_formats: ["glb"]`, `origin_at: "bottom"`). Do not route
   characters through the Rigging endpoint by default — see verdict in 1.3.
3. **Output contract:** `assets/models/meshy/<id>.glb`, flat, one file per
   manifest id — this *is* the import directory Godot's asset pipeline reads
   from directly (Godot auto-imports `.glb` on scan, no manual conversion
   step). Keep a `generated/` subfolder pattern for any experimental/re-roll
   batch so a bad batch never collides with or reshuffles a shipped set,
   matching the sibling project's convention.
4. **Report file** (`tools/meshy_forge_report.json`): id → task ids,
   consumed_credits, status, glb_path — gives a cheap per-batch audit trail
   and resumability (`-Resume` skip-if-exists) without needing to re-query
   the API.
5. **Never commit the API key.** `.env`-sourced, read into a process
   variable only, exactly as the sibling script does.
6. If/when a character genuinely needs bone-driven animation beyond
   procedural squash-and-stretch, treat Rigging as an opt-in per-asset step
   (5 credits, walk+run only) layered on top of an already-approved static
   GLB — not a default stage in the batch pipeline.

### Video-receipt recipe (exact)

```
godot.exe --path D:\Projects\soft_landing --write-movie receipts\run_001.avi --fixed-fps 60 --resolution 1280x720 --quit-after 600
```
(600 frames at fixed-fps 60 = a fixed, deterministic 10-second clip; adjust
`--quit-after` per scenario, or drive `get_tree().quit()` from a scripted
in-game trigger for variable-length receipts instead of a hard frame count.)

Do **not** add `--headless` — it silently breaks Movie Maker (dummy
rasterizer, no real frame data). Run the normal windowed binary; the window
does not need focus, just needs to exist.

Transcode for phone review:
```
ffmpeg -i receipts\run_001.avi -c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium -c:a aac -b:a 192k -movflags +faststart receipts\run_001.mp4
```

Shutdown must be clean (`quit()`/`--quit-after`, never Ctrl+C/taskkill) or
the AVI header is left broken.

---

## UNVERIFIED

- **Meshy rate-limit tier names/caps are in flux or inconsistently
  documented.** The sibling project's doc (fetched 2026-07-15, same day as
  this research) recorded tiers as Pro (10 queued)/Max/Max Unlimited (20
  queued). This session's fetch of the same rate-limits page, also
  2026-07-15, returned tier names Pro/Premium/Ultra/Studio/Enterprise with
  different queue caps (10/30/100/20/50). Both can't be the current page
  simultaneously — likely explanation is a doc restructure/rename between
  the two fetches, or one fetch hit a cached/stale render. **Do not hard-code
  a specific queue-cap number from either source**; the 5-in-flight batching
  pattern is safely under every observed number and should be used
  regardless of which tier list is current.
- **Whether `--quit-after` is the exact current flag name** — surfaced via
  general web search summarization rather than a direct fetch of the CLI
  reference page; worth a `godot.exe --help` sanity check before wiring into
  a script.
- **OGV format's actual maturity in 4.6** — search results surfaced a PR
  ("Add Ogg Theora support to MovieWriter") that reads as a relatively recent
  addition; did not confirm which exact 4.x version shipped it or whether
  4.6 specifically has it stable vs. still-new. Recommendation above uses AVI
  regardless, so this doesn't block anything, but don't assume OGV is
  battle-tested if it's chosen later.
- **Xvfb/virtual-display workaround for headless Linux CI** — stated from
  general Godot community knowledge about the `dummy` vs `x11`/`wayland`
  display-driver split, not from a doc page that specifically blesses Xvfb
  for Movie Maker. Not load-bearing for this Windows-only project; re-verify
  before relying on it if CI ever moves to Linux.
- **Exact current wording of the meshy-6 `should_remesh` default** — the
  text-to-3d doc fetch reported "default false for meshy-6" via model
  summarization of the page rather than a verbatim quote; worth re-checking
  against the raw OpenAPI spec if `should_remesh` is ever omitted from a
  request in the soft_landing pipeline (the recommendation above sets it
  explicitly, which sidesteps the ambiguity either way).

---

## Addendum (2026-07-16, from docs.meshy.ai/llms.txt — producer pointer)

Deltas vs the research above, for future instances:

- **Asset retention: 3 days max** (non-Enterprise). Meshy-hosted model URLs
  and task records go stale fast — the committed GLBs in this repo are the
  ONLY durable record. Never re-derive from task IDs in forge_report.json.
- **Image-to-3D and Multi-Image-to-3D exist.** Big lever for likeness work:
  Callie could be regenerated from PHOTOS of the actual stuffy (multiple
  angles) instead of a text prompt, if the text version misses her.
- **Retexture endpoint**: fix a texture read (e.g. the firefly jar's missing
  glow-dots) without regenerating geometry — cheaper than a re-roll.
- **SSE streaming** (`/<endpoint>/:id/stream`) and **webhooks** exist as
  alternatives to polling; polling remains fine for batch forge runs.
- **Models**: `meshy-6` (default) / `meshy-5` / `latest`. Formats via
  `model_urls.<format>`: GLB, FBX, OBJ, USDZ.
- **Rate limits** (matches sibling doc): Pro 20 req/s + 10 queued, Studio
  20/s + 20, Enterprise 100/s + 50+.
- **A Meshy MCP server exists** (`claude mcp add meshy`) — future sessions
  could drive Meshy via MCP tools instead of tools/meshy/meshy_forge.ps1.
  The forge stays canonical here (deterministic receipts, house-style
  suffix enforcement, credit caps), but MCP is handy for one-off explorations.
