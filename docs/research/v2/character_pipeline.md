# Character animation pipeline — Meshy → rigged/animated in Godot 4.6

**Written:** 2026-07-16
**served_model:** `claude-sonnet-5` (Claude Sonnet 5, Anthropic) — this document was produced by this
model via web search/fetch only; it did not call the Meshy API and has no API key.
**Scope:** THE BIG NAP — Godot 4.6 co-op 3D platformer. Cast: Pip and Otto (toddler-proportioned
kids in animal onesies, bipedal/humanoid) and Callie (calico cat sidekick, quadruped). All three
currently exist as **static, unrigged GLB meshes** from Meshy (meshy-6, ~8000 polys, `enable_pbr:
false`, flat-color house style — see `docs/research/pipeline.md` for the proven text-to-3d
parameters already in use on this project). Mandate: get them rigged and animated to an
AAA-reading standard inside Godot 4.6.
**Method:** web search + fetch only (`docs.meshy.ai`, `docs.godotengine.org`, community
sources). No Meshy API calls were made. No files outside this one were modified.

---

## 1. Meshy rigging + animation API

### 1.1 Endpoints (confirmed against [docs.meshy.ai/api/rigging](https://docs.meshy.ai/api/rigging.md), [docs.meshy.ai/api/animation](https://docs.meshy.ai/api/animation.md), [docs.meshy.ai/api/animation-library](https://docs.meshy.ai/api/animation-library.md))

```
POST   /openapi/v1/rigging            -- create rigging task (one humanoid mesh -> skeleton)
GET    /openapi/v1/rigging/:id        -- poll status
GET    /openapi/v1/rigging/:id/stream -- SSE progress
DELETE /openapi/v1/rigging/:id

POST   /openapi/v1/animations            -- apply ONE library animation to an existing rig
GET    /openapi/v1/animations/:id        -- poll status
GET    /openapi/v1/animations/:id/stream
DELETE /openapi/v1/animations/:id
```

**Rigging request:** one of `input_task_id` (prior text-to-3d task) or `model_url` (public URL /
data URI to `.glb`), plus optional `height_meters` (default 1.7) and `texture_image_url`.
Requirements confirmed from the live doc text: **textured mesh only** (untextured fails), **≤
300,000 faces** (use the separate Remesh endpoint, 1 credit, if over), and the model must **face
+Z** (glTF forward) or rigging fails/misaligns. No explicit T-pose/A-pose requirement is stated in
the API doc itself, but the consumer-facing tutorial (see §2) recommends T-pose for best results.

**Rigging output:** `rigged_character_fbx_url`, `rigged_character_glb_url`, plus a
`basic_animations` object bundling **only two free motions — walking and running** (each as
skinned GLB, skinned FBX, and armature-only GLB). Cost: **5 credits**, refunded on failure.

**Animation request:** `rig_task_id` (required, from a completed rigging task) + `action_id`
(integer, one clip per call — see the library below). Optional `post_process` (`change_fps`,
`fbx2usdz`, `extract_armature`) and `fps` (24/25/30/60). **One call = one clip on that rig** — to
get idle + jump + land + wave + pickup on Pip, that's 5 separate `POST /openapi/v1/animations`
calls, 5 separate result GLBs, all sharing the same skeleton topology because they share
`rig_task_id`. Cost: **3 credits per clip**, refunded on failure.

### 1.2 Animation library

Catalog fetched live from `https://api.meshy.ai/web/public/animations/resources` (JSON,
`action_id` + `name` + `category` + preview URL per entry): **680 total animations**, grouped into
`WalkAndRun`, `DailyActions` (idle, interacting, picking up, sleeping, pushing, working out),
`Fighting`, `BodyMovements`, `Dancing`. Representative `action_id`s useful for a platformer: Idle
= `0`, Walking = `-2`, Running = `-1`, Jump Run = `13`, Big Wave Hello = `28`, Male Bend Over Pick
Up = `276`, Collect Object = `284`. **Query the live JSON at task time** — do not hard-code
`action_id`s into this doc; the library is a moving target and ids should be resolved
programmatically when the forge script runs.

### 1.3 Costs, one rig fully animated

5 (rig, includes walk+run) + 3 × N additional clips. A reasonable platformer set for Pip/Otto —
idle, jump, land/impact, wave, pickup, maybe a sit — is **5 + 3×5 = 20 credits per character**,
on top of whatever text-to-3d/refine credits were already spent making the static mesh (30
credits per the proven pipeline in `docs/research/pipeline.md`). **This supersedes that doc's
earlier "static mesh + procedural squash-and-stretch, skip rigging" verdict** — see §9 for why.

---

## 2. The quadruped problem: can Meshy rig Callie?

**No — not through the public REST API, as of this research.** The canonical API reference
([docs.meshy.ai/api/rigging](https://docs.meshy.ai/api/rigging.md)) is explicit and
unambiguous: rigging "currently only works well with standard **humanoid (bipedal)** assets," and
lists "**Non-humanoid assets**" under things the endpoint explicitly does not support.

This directly contradicts Meshy's **marketing pages**, which advertise a distinct web-app tool
called "Animate": [meshy.ai/features/ai-animation-generator](https://www.meshy.ai/features/ai-animation-generator)
states "Auto-rigging works on humanoids, bipeds, **quadrupeds**, and stylized figures," and the
FAQ specifically says the Animate feature "works on humanoid and quadrupedal characters, including
mythological and fictional creatures (dragons, griffins, wolves, centaurs, etc.)." The tutorial
[meshy.ai/tutorials/character-auto-rigging-workflow](https://www.meshy.ai/tutorials/character-auto-rigging-workflow)
confirms a web-UI "Select the character type" step offering **Quadruped — four-legged animals
(dogs, horses, creatures)** as a preset, requiring a T-pose or A-pose, and separately warns
"quadruped characters can be rigged too, but currently have **fewer animation options** than
humanoids." Neither marketing page states whether this quadruped path is reachable via the
`openapi/v1/rigging` REST endpoint or is web-app-UI-only; a targeted search for a `rig_type` /
`character_type` request parameter in the OpenAPI spec turned up nothing.

**Reconciliation / practical read:** treat quadruped rigging as **web-app-only and unconfirmed for
the scripted API pipeline**. Two options for Callie, in order of recommendation:

1. **Procedural cat rig, handmade in Godot** (recommended — see §6/§7, especially the new
   **SplineIK3D** node for the tail). Fully scriptable, fits this project's existing
   manifest-driven Meshy forge pattern for everything else, zero dependency on an unconfirmed API
   surface, and avoids "fewer animation options than humanoids" ever mattering.
2. **One-off manual pass through the Meshy web app's Animate tool** for just this one character
   (drag-and-drop, pick "Quadruped," export GLB/FBX) if the procedural rig reads as too stiff.
   Since Callie is a single hero asset (not a batch), a manual step is tolerable here in a way it
   wouldn't be for e.g. 20 background props — but confirm actual output quality (walk cycle
   believability on a cat proportion, not a generic "creature") before committing to it, since the
   feature is generically trained across dragons/wolves/centaurs/horses, not cat-specific.

---

## 3. Godot 4.6 GLB import: skeleton + animation, AnimationLibrary extraction

Confirmed against [Import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html)
and community workflow write-ups (MoCap Online's Godot guides, the `godot-anim-lib-export` and
`Godot4-MixamoLibraries` projects).

- A `.glb`/`.gltf`/`.fbx` file can be imported **"As: Scene"** (mesh + skeleton + animations
  together) or **"As: Animation"** (animation-only, no mesh) — set per-file in the Import dock.
  This matters because Meshy's per-`action_id` animation GLBs are typically skinned (mesh +
  skeleton + one clip) — import the *first* one ("As: Scene") to get the mesh+skeleton, then
  import the rest **"As: Animation"** against that same skeleton so you aren't duplicating meshes.
- Each imported animation clip can be individually configured under the **Animation** import
  section with a **"Save to File"** toggle — this extracts the clip to its own `.res`
  `Animation` resource on disk instead of leaving it locked inside the scene's baked
  `AnimationPlayer`.
- **AnimationLibrary** is the Godot 4 container that lets you pool multiple `Animation` resources
  (regardless of which source file they were imported from) under one named library, attachable to
  a single `AnimationPlayer` or `AnimationTree` on the actual character scene. This is exactly how
  the community solves "N separate Meshy animation-task GLBs → one usable character": import each,
  extract each clip via "Save to File," then load them all into one `AnimationLibrary` on the
  Pip/Otto/Callie scene's `AnimationPlayer`.
- Community tooling exists that automates this for the Mixamo case specifically and generalizes
  cleanly to "any per-clip animation-only GLB retargeted onto a shared rig" (which is structurally
  identical to what Meshy's animation endpoint produces): [Godot4-MixamoLibraries](https://github.com/jwelchgames/Godot4-MixamoLibraries),
  [godot-anim-lib-export](https://github.com/geowarin/godot-anim-lib-export/) (drives Blender
  headless to merge FBX actions into NLA tracks, then a headless Godot pass turns them into a
  library), [Godot-Mixamo-Animation-Retargeter](https://github.com/RaidTheory/Godot-Mixamo-Animation-Retargeter)
  (adds a right-click "Retarget Mixamo Animation" batch action in the editor).

---

## 4. Retargeting: BoneMap / SkeletonProfile, and can Mixamo animations drive a Meshy rig?

Confirmed against the official [Retargeting 3D Skeletons](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/retargeting_3d_skeletons.html)
doc and [BoneMap](https://docs.godotengine.org/en/stable/classes/class_bonemap.html) class ref.

**Yes — this is exactly what Godot's retargeting system is built for, and it does not care what
tool produced either skeleton.** Retargeting maps *semantic bone roles* (hip, spine, head,
upper-arm-L, etc.), not literal bone name strings, so a Mixamo FBX (`mixamorig:Hips`,
`mixamorig:Spine`, ...) and a Meshy-rigged GLB (bone names unconfirmed/unspecified by Meshy's
docs) can both be mapped onto the same intermediate `SkeletonProfileHumanoid` and animation will
transfer between them.

**Exact workflow (official, in the Import dock, per-file, "Advanced" scene import settings):**
1. Select the imported **Skeleton3D** node in the scene tree shown in the import dialog.
2. In the **Retarget** section on the right panel, create a **BoneMap** resource and set its
   **Profile** to **SkeletonProfileHumanoid**.
3. Godot **auto-maps** bones by name/hierarchy heuristics as soon as the profile is set; any bone
   it couldn't confidently map is flagged (magenta/red in the mapping UI) for **manual
   correction** — click the profile-side bone, then click the matching skeleton-side bone.
4. Save the BoneMap (e.g. `res://retarget/meshy_humanoid_bonemap.tres`) — **reuse it across every
   Meshy-rigged asset with the same rig topology** (Pip and Otto, if built from the same Meshy
   rigging call shape, likely share one BoneMap).
5. **Rest Fixer** section (critical, quoted from the doc as "the most important option for
   sharing animations in Godot 4"): enable **"Overwrite Axis"**; **"Fix Silhouette"** corrects
   pose differences between source and target skeletons (e.g. Mixamo's A-pose vs. a T-pose Meshy
   rig — relevant since Meshy's own tutorial says T-pose is the preferred rig input, while Mixamo
   ships in A-pose); **"Normalize Position Tracks"** rescales stride/root motion length for
   differing character heights (Pip/Otto are toddler-proportioned, so this will matter a lot if
   pulling adult-proportioned Mixamo walk cycles).
6. **Remove Tracks** options (enable when building a shared `AnimationLibrary`): "Except Bone
   Transform," "Unimportant Positions," "Unmapped Bones" — strips anything not needed for a clean
   shared-skeleton clip.
7. **Bone Renamer**: renames the target skeleton's bones to the profile's canonical names (and can
   mark the Skeleton3D "unique" so retargeted names don't collide across imports).

**Practical implication:** Mixamo's much deeper animation library (see §5) can legitimately
backstop or replace Meshy's 680-clip catalog for Pip/Otto, using the same BoneMap once built.

---

## 5. Mixamo as an animation source

- **Auto-rigger + library:** free (Adobe account), produces `mixamorig:`-prefixed bone names,
  large curated library across locomotion/combat/social/dance categories, generally recognized as
  higher hand-animated quality than a generic 680-clip catalog for common actions.
- **Commercial licensing:** confirmed via [Adobe's Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)
  and community summary ([LicenseOrg guide](https://www.licenseorg.com/guide/3d-assets/mixamo)):
  royalty-free for personal, commercial, and non-profit projects, **explicitly includes video
  games**, no credit/attribution required, no fee. The only real restriction: **cannot redistribute
  the raw characters/animations as a standalone downloadable asset pack** — fine for "baked into a
  shipped game," which is this project's use case.
- **FBX → GLB / Blender headless conversion:** multiple community pipelines confirm this is a
  solved, scriptable problem — [godot-anim-lib-export](https://github.com/geowarin/godot-anim-lib-export/)
  drives Blender **headless** via Python to import a base character, layer each Mixamo FBX in as
  an NLA (Non-Linear Animation) track, and export one combined GLB, then runs Godot **headless**
  a second time to bake that into an `AnimationLibrary`. A simpler no-Blender web tool,
  [mixamo2gltf.com](https://mixamo2gltf.com/), merges multiple Mixamo FBX exports directly into
  one GLB with all clips intact, for cases where the NLA/Blender step is overkill.
- **Known Godot-retarget issues** (from the [Godot Forum retarget thread](https://forum.godotengine.org/t/mixamo-animation-retarget/137067)
  and the [dredyson.com guide](https://dredyson.com/the-hidden-truth-about-swapping-skeleton-3d-models-in-godot-4-6-3-a-complete-beginners-step-by-step-fix-guide-for-multiplayer-fps-character-skin-swapping-using-mixamo-rig-and-animationlibraries-wit/)):
  bone-name collisions when multiple skeletons share a scene (fix: "make Skeleton unique" during
  Bone Renamer), and forgetting to set the **Bone Renamer → Skeleton Name** field to match the
  target skeleton's actual node name (silently breaks playback with no error). A one-click
  alternative that automates the whole BoneMap/profile dance exists: **MixaBridge**
  ([mixabridge.uzair.ct.ws](https://mixabridge.uzair.ct.ws/)) — "analyzes the skeleton, auto-maps
  all Mixamo bones to Godot's humanoid profile, configures import settings, and reimports... in
  three clicks."

---

## 6. AnimationTree architecture for a platformer character

Confirmed against the official [Using AnimationTree](https://docs.godotengine.org/en/latest/tutorials/animation/animation_tree.html)
doc plus current community guides (Godot MCP Pro's AnimationTree guide, kidscancode's Godot
Recipes state-machine walkthrough).

**Recommended shape, one `AnimationTree` per character:**
- **Top level: `AnimationNodeStateMachine`** — high-level discrete states: `Idle`, `Locomotion`,
  `Jump`, `Fall`, `Land`, plus any social one-shots. `travel()` for scripted transitions (e.g.
  cutscene-driven), boolean/float **conditions** wired from character-controller state
  (`is_on_floor()`, vertical velocity sign, input magnitude) for gameplay-driven transitions —
  community guidance is to prefer conditions over `travel()` for anything driven every physics
  frame by `CharacterBody3D` state, reserving `travel()` for one-off scripted triggers.
- **Inside `Locomotion`: `AnimationNodeBlendSpace1D`** — one axis (`speed` or planar velocity
  magnitude), blending Idle → Walk → Run continuously instead of hard-cutting between discrete
  clips. (BlendSpace2D exists for full 8-directional strafing; a 1D speed axis is sufficient for
  Pip/Otto's forward-facing platformer locomotion, per this project's design doc conventions —
  reserve 2D for if/when strafing or directional locomotion is added.)
- **`Jump`/`Fall`/`Land` as their own states**, driven by physics conditions rather than blended
  continuously with locomotion (a jump doesn't "blend" from idle — it triggers, plays, and
  transitions out on animation-finished or a landing condition).
- **One-shot overlays via `AnimationNodeOneShot`**: wave, pickup, small "oops" bounce — layered on
  top of whatever locomotion state is currently active without disrupting it. Fire via
  `oneshot_request = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE` from script.
  **`AnimationNodeAdd2`** is the additive-layer node for cases where an upper-body gesture should
  play *while still walking* (e.g., waving while moving) — separate from `OneShot`, which by
  default fully overrides.
- **Root motion vs. in-place — use in-place for this game.** Root motion (engine reads the root
  bone's translation/rotation per frame and feeds it into `CharacterBody3D.velocity`) is the right
  call when an animation's *inherent* trajectory must exactly match world movement — dodge rolls,
  climbs, precisely-timed attack lunges. For **ordinary platformer locomotion** (walk/run/jump)
  where `CharacterBody3D` physics code already owns velocity, acceleration, gravity, and collision
  response, **in-place** animation (root motion off, `CharacterBody3D` fully code-driven) is the
  established pattern — confirmed via [RootMotionView](https://docs.godotengine.org/en/stable/classes/class_rootmotionview.html)
  docs and forum consensus ([How to use root motion to make a 3D character move](https://forum.godotengine.org/t/how-to-use-root-motion-to-make-a-3d-character-move-in-godot-4/1489)).
  Reserve root motion, if ever needed, for a specific special-move animation (e.g. a big
  telegraphed pounce for Callie) layered as an exception, not the default for every clip.

---

## 7. Procedural juice on top of a rigged mesh

- **Squash-and-stretch:** with a real skeleton now in play (vs. the earlier static-mesh plan),
  the clean approach is **scaling the root/hip bone (or a dedicated root `Skeleton3D` node)**
  non-uniformly on jump-anticipation/land frames via a `Tween`, exactly the pattern in the
  [Godot Quick Tip: Platformer Squash and Stretch](https://www.youtube.com/watch?v=iJx6uKqufJo)
  video and the [forum's squash-and-stretch thread](https://forum.godotengine.org/t/squash-and-stretch/25627).
  A **`Skeleton3D` bone's `inherit_scale`** property (confirmed shipped via [PR #83903](https://github.com/godotengine/godot/pull/83903))
  lets a single bone scale independently of its children — useful if only the torso should squish
  while limbs keep their proportions. Practically: scale a wrapper `Node3D` (or the mesh's visual
  root) rather than fighting bone-space math, unless a specific bone needs to squash
  independently of its skinned children.
- **Spring/jiggle bones — `SpringBoneSimulator3D` exists and shipped in Godot 4.4, confirmed still
  present in 4.6.** Add as a child of `Skeleton3D`, configure a Root Bone → End Bone chain, tune
  gravity/drag/radius/stiffness; multiple simulators can coexist on one skeleton. ([docs.godotengine.org class ref](https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html),
  [GameFromScratch coverage](https://gamefromscratch.com/godot-4-4-gets-jiggle-physics/)). Direct
  fit for **Callie's tail and ears**, and for secondary motion on Pip/Otto's onesie ears/floppy
  bits.
- **Look-at / head tracking — `LookAtModifier3D` (a `SkeletonModifier3D`) exists, confirmed
  current in 4.6.** Rotates a bone toward a target node with a configurable forward axis, tween-
  based interpolation/easing, and an angle-limit option that prevents unnatural neck rotation.
  ([class ref](https://docs.godotengine.org/en/4.6/classes/class_lookatmodifier3d.html), [PR #98446](https://github.com/godotengine/godot/pull/98446)).
  Good, cheap "alive" signal for Pip/Otto glancing at each other or at a nearby puzzle element.
- **Foot IK — worth it here, and 4.6 makes it easy.** Godot 4.6 shipped a genuinely new modular
  IK framework replacing the long-deprecated `SkeletonIK3D`: an `IKModifier3D` base with **seven**
  concrete solvers — `TwoBoneIK3D` (arms/legs — analytic, single-pass, described as "rock-solid"),
  `FABRIK3D` (long chains), `CCDIK3D` (tentacles/simple robotic chains), `SplineIK3D` (tails —
  shape-driven, direct fit for **Callie's tail** as an alternative/complement to spring bones),
  plus `ChainIK3D`, `IterateIK3D`, `JacobianIK3D`. ([Godot 4.6 release notes](https://godotengine.org/releases/4.6/),
  [GameFromScratch: IK Return to Godot](https://gamefromscratch.com/inverse-kinematics-ik-return-to-godot/),
  [StraySpark's 4.6 IK guide](https://www.strayspark.studio/blog/godot-46-inverse-kinematics-procedural-animation)).
  Recommended platformer foot-IK recipe (from the StraySpark walkthrough): keep the baked walk
  animation as the base pose, add a `TwoBoneIK3D` per leg (upper-leg → foot bone) with a target
  node and a pole target positioned in front of the knee, then in `_physics_process()` raycast
  downward from each animated foot position, pin the IK target to the ground hit (with an ankle
  offset) and align the foot's basis to the surface normal for slope matching. For toddler-
  proportioned stylized characters walking mostly on flat garden/train-car geometry, foot IK is a
  **nice-to-have polish pass, not a must-ship-day-one feature** — the stack order (solve legs →
  solve look-at → solve secondary/spring motion) is straightforward to add later without
  restructuring the rig, so it's safe to defer.

---

## 8. Facial life on a low-poly toy mesh

- **Meshy does not generate blend shapes / morph targets.** Confirmed via search: Meshy's own
  rigging output is skeletal (bones + skin weights) only; true facial blendshape rigs (e.g. the
  ARKit 52-shape standard) require manual sculpting in Blender/Maya with tools like the
  [ARKitBlendshapeHelper](https://github.com/elijah-atkins/ARKitBlendshapeHelper) Blender addon —
  out of scope for this pipeline's automation goals and overkill for toddler-toy-proportioned
  characters at this asset budget.
- **Simplest AAA-*reading* solution for this style (confirmed community pattern):** skip
  blendshapes entirely. Two viable low-effort approaches surfaced:
  1. **UV-offset animation on a dedicated eye/face texture region** — paint a small sprite-sheet
     of eye states (open, blink, happy-squint) into the character's existing flat-color texture,
     then animate the UV offset via an `AnimationPlayer` track on the mesh's material (or a tiny
     shader `uv` uniform). Matches the "Skillshare: Animating Textures on 3D Game Characters"
     pattern and the forum's "move UV mapping around" cartoon-eye technique.
  2. **A thin secondary "eyelid" mesh/decal parented to a head bone**, driven purely by bone
     animation (scale/rotate down to closed) — zero shader work, reuses the same `AnimationPlayer`
     already being built for body clips, and was the pattern explicitly recommended on the
     [Godot Forum's cartoon eye-animation thread](https://forum.godotengine.org/t/cartoon-character-eye-animation/101347)
     ("model opened eyes and closed eyes in separate objects... combine the eye_open/eye_closed
     visibility behavior into one parameter" via a driver).
  Recommendation: **option 1 (UV-offset blink) for Pip/Otto's faces** if their existing texture has
  spare UV space reserved for a face region (check the actual Meshy-generated texture atlas before
  committing); fall back to **option 2 (separate eyelid decal)** if the face is baked into a
  texture region too cramped to add blink frames without a re-roll. Either is one small
  `AnimationLibrary` clip, blended additively so it never fights body locomotion.
- Meshy's only native tie-in here is **USDZ export being ARKit-flagged** for Apple ecosystem AR
  use ([meshy.ai/features/ai-animation-generator](https://www.meshy.ai/features/ai-animation-generator))
  — irrelevant to this project's Godot-only target platform; not a path to facial rigging.

---

## TOP 12 ACTIONABLE

**A. Pip & Otto (humanoid) — Meshy rig+animate → Godot AnimationTree**

1. **Rig each character once**: `POST /openapi/v1/rigging` with `input_task_id` = the existing
   text-to-3d refine-stage task id (or `model_url` to the already-committed static GLB), explicit
   `height_meters` set to the toddler-proportioned actual scene scale (not the 1.7 m default).
   Confirm the source mesh is already textured and ≤300k faces (it is — 8000-poly house style) and
   that the model's forward axis is +Z before submitting, or rigging silently misaligns. Cost: 5
   credits each; free bonus: bundled walk + run clips.
2. **Pull the live animation catalog** (`GET https://api.meshy.ai/web/public/animations/resources`)
   at forge-run time and resolve `action_id`s for: Idle, Jump (anticipation+air), Land, Wave, Pick
   Up — do not hard-code ids from this doc, the library is a moving target.
3. **Submit one `POST /openapi/v1/animations` per clip** (`rig_task_id` + `action_id`), 3 credits
   each; poll each to `SUCCEEDED` and download the skinned GLB immediately (Meshy URLs are
   presigned/expiring — same lesson already baked into `meshy_forge.ps1` for text-to-3d).
4. **In Godot's Import dock**, import the walk/run/base-rig GLB **"As: Scene"** (mesh + skeleton),
   then import every subsequent per-clip GLB **"As: Animation"** against that same `Skeleton3D`.
5. **Build one `BoneMap` per rig topology**, Profile = `SkeletonProfileHumanoid`, let Godot
   auto-map, hand-fix any magenta-flagged bones, save as
   `res://retarget/pip_otto_bonemap.tres` and reuse across both characters if they share rig
   shape. Enable **Rest Fixer → Overwrite Axis + Fix Silhouette + Normalize Position Tracks** (the
   last one specifically matters given toddler proportions vs. any Mixamo adult-proportioned
   clips pulled in later).
6. **Extract every clip via "Save to File"** into a shared `AnimationLibrary`
   (`res://characters/pip/anim_lib.tres`), attach to one `AnimationPlayer` on the character scene.
7. **Wire an `AnimationTree`**: top-level `AnimationNodeStateMachine` with `Idle` /
   `Locomotion` / `Jump` / `Fall` / `Land` states; `Locomotion` is an `AnimationNodeBlendSpace1D`
   on planar speed (Idle→Walk→Run); Wave/Pickup as `AnimationNodeOneShot` fired from gameplay
   script (`oneshot_request = ONE_SHOT_REQUEST_FIRE`); **root motion off / in-place** — physics
   stays fully owned by `CharacterBody3D` code.
8. **If Meshy's 680-clip catalog reads thin** for a needed action, pull the equivalent from
   Mixamo instead (free, commercially licensed, confirmed game-safe) and retarget it onto the
   *same* `pip_otto_bonemap.tres` skeleton — Godot's retargeting is bone-role-based, not
   tool-of-origin-based, so this is a drop-in extension of step 5-6, not a parallel pipeline.

**B. Callie (quadruped) — procedural, no Meshy rigging API dependency**

9. **Do not route Callie through `POST /openapi/v1/rigging`** — the canonical API doc states
   humanoid/bipedal only; the quadruped support Meshy advertises is web-app-only ("Animate" tool)
   and unconfirmed for the scripted `openapi/v1/` surface. If a manual pass through the web UI is
   later tried as a one-off (acceptable for a single hero asset), verify cat-specific believability
   before committing — the feature is trained broadly across dragons/wolves/horses, not cats
   specifically.
10. **Hand-build a simple quadruped `Skeleton3D`** on the static Callie GLB in Blender (spine
    chain, 4 leg chains, neck/head, tail chain) — a small, fixed bone count is fine for a stylized
    toy-proportioned cat; hand-keyframe a walk/idle/sit cycle directly in Godot's animation editor
    or Blender, since there is no external library to retarget from for quadrupeds.
11. **Add `SplineIK3D` (Godot 4.6's new IK framework) on the tail chain** for shape-driven procedural
    tail motion layered over the base clips, and/or a **`SpringBoneSimulator3D`** on tail + ears for
    passive jiggle secondary motion — both are lightweight, config-only additions to the
    `Skeleton3D`, no baked animation data required for the jiggle layer.
12. **Layer `LookAtModifier3D` on Callie's head bone** for cheap "alive" head-tracking (toward
    Pip/Otto or a nearby puzzle element), stacked after the base locomotion state machine in the
    modifier order (solve legs/spine pose first → look-at → spring/secondary motion last), matching
    the general modifier-stacking guidance confirmed for the 4.6 IK framework.
