# Visuals Recipes — Godot 4.6 AAA stylized look (V2 research, lane C)

*Assembled 2026-07-16 by the director from two research sub-agents
(served_model: claude-sonnet-5 lineage; director-condensed). Target:
Forward+, mid-range PC, 60 fps, pastel night register. Honest headline:
no shipped Godot title publicly documents an Astro Bot/Kirby-grade
pastel-toy look — we assemble it from proven primitives and become the
precedent.*

## Post stack (WorldEnvironment / Environment)

- **Tonemap: AgX** (4.3+ default) — preserves hue in bright warm tones
  (honey #F2C879 / cream #FFF3C4 sit exactly in the overexposure-prone
  range where Filmic/ACES collapse to yellow). AgX mutes midtone
  saturation, so pair with **Adjustments enabled: saturation ≈ 1.15–1.3,
  slight contrast boost**. A/B against Filmic on our palette.
  ([AgX discussion](https://github.com/godotengine/godot-proposals/discussions/7545))
- **Glow**: `glow_enabled`, blend **Soft Light or low-intensity Additive**
  ("dream-like" per docs), `glow_hdr_threshold` 0.5–0.9 so honey/cream
  tones bloom; cap glow levels 4–5 for perf.
- **Adjustments/LUT**: `adjustment_color_correction` takes Texture3D
  (33×33×33) for a graded look; start with brightness/contrast/saturation
  only, LUT later.
- **SSAO**: low intensity only (contact shadows at feet/props); nonzero
  Light Affect for stylized depth. **SSIL: skip** (cost > benefit on flat
  materials).
- **Vignette**: no built-in — full-rect ColorRect + canvas_item shader
  ([Camera Vignette Shader](https://godotshaders.com/shader/camera-vignette-shader/)).
- **DOF/diorama**: CameraAttributesPractical far-blur is cheap; a real
  tilt-shift needs a depth-based full-screen shader
  ([Depth-based Tilt-Shift](https://godotshaders.com/shader/depth-based-tilt-shift/)).
  Optional; try far-blur first.
- **Volumetric fog**: enable per-world, low density, tinted toward each
  world's palette for dreamy haze; combine with depth/height distance fog.

## Sky

Custom sky shader (painted gradient bands dusk-blue→deep blue, big
stylized moon disc with soft halo, star field, 2-layer drifting cloud
noise) on a PanoramaSky-style ShaderMaterial — procedural, no textures
required. Moon should be BIG (toy-scale honesty) and sit where the
CameraHints frame it.

## Character rendering (soft plush, NO outlines)

- **Outlines: skip.** Kirby/Astro are outline-free; softness comes from
  rounded geometry, soft shadows, rim light. Outlines would harden the
  register.
- **Fresnel rim** tied to the moonlight in the light pass:
  `rim = pow(1.0 - dot(NORMAL, VIEW), rim_width);
  SPECULAR_LIGHT += rim * rim_color.rgb * LIGHT_COLOR / PI;`
- **Fake SSS / wrap lighting** for plush edges (MIT:
  [Performant SSS](https://godotshaders.com/shader/performant-sss-sub-surface-scattering-approximation/)):
  `DIFFUSE_LIGHT += max(abs(dot(-NORMAL, LIGHT)), 0.0) * LIGHT_COLOR / PI * ALBEDO * sss_factor;`

## Water (Wisp's lake)

Fork **[Absorption Based Stylized Water](https://godotshaders.com/shader/absorption-based-stylized-water/)
(CC0, Godot 4.x Forward+)** — Beer's-law depth color, edge foam,
vertex waves, ripples, refraction, fresnel. Retint dusk-blue/sage, lower
wave amplitude to calm. Depth reconstruction: `hint_depth_texture`,
un-project via `INV_PROJECTION_MATRIX` (Vulkan 0–1 depth). Screen-reading
materials render in the transparent pass. Alternatives (MIT):
[Stylized Water 4.x](https://godotshaders.com/shader/stylized-water-for-godot-4-x/),
[Toon Water](https://godotshaders.com/shader/toon-water-shader/).

## Wind & vegetation

- Vertex sway, roots pinned, per-instance phase from world position:
  ```glsl
  float tip = 1.0 - UV.y;
  VERTEX.x += sin(NODE_POSITION_WORLD.x + TIME * 1.25 + UV.y) * tip * 0.10;
  VERTEX.z += cos(NODE_POSITION_WORLD.z + TIME * 0.45 + UV.y) * tip * 0.15;
  ```
  ([Stylized Cartoon Grass, MIT](https://godotshaders.com/shader/stylized-cartoon-grass/);
  [Victor Karp foliage wind](https://victorkarp.com/godot-foliage-wind/) —
  vertex-color masks: R = trunk→canopy, G = branch tips.)
- **MultiMeshInstance3D** for grass fields (one draw call; chunk several
  MultiMeshes for frustum culling). **Full-geometry blades (3–7 tris,
  solid color, no alpha)** near camera — best match for the toy softness;
  billboard impostors far. Shell grass: skip (reads realistic-fur).
  ([MultiMesh docs](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html),
  [hexaquo grass series](https://hexaquo.at/pages/grass-rendering-series-part-2-full-geometry-grass-in-godot/))

## Particles (GPUParticles3D; budget ≤ ~2–5k live total, verify in profiler)

Key knobs: `turbulence_enabled` (+ noise_scale ~9, strength ~1) is THE
organic-drift control; `scale_curve` CurveTexture for firefly breathing;
`color_ramp` for fade in/out; `particle_flag_align_y` for trails.
- **Fireflies**: sphere emission, gravity ~0, velocity 0.1–0.3, turbulence
  on, pulsing scale, honey color, lifetime 4–8 s, 20–50 count.
- **Dream-motes/pollen**: large box around play space, gravity (0,-0.05,0),
  tiny, slow, cream, 100–300.
- **Sparkle trail** (carried dreamlings/moves): point emission on player,
  lifetime 0.5–1 s, shrink-to-zero, additive.
- **Footstep puffs**: `one_shot`, `explosiveness 1.0`, 8–16 burst.
- Glow material: radial-gradient billboard, ALPHA + ADD blend,
  PARTICLE_BILLBOARD, UNSHADED (+ env glow blooms the cores).
- GPU cost scales with `amount` even when invisible
  ([#92764](https://github.com/godotengine/godot/issues/92764)) — size to
  need. GPUParticles3D over CPUParticles3D throughout.

## Lighting for readable night

Night scenes stay bright the way Mario/Astro night levels do: a cool
bright key (moon) + warm practical fills (lanterns, fireflies, windows) +
higher ambient than realism wants. SDFGI: unnecessary for our scale;
prefer baked-feel via fill lights + AO. Blob shadow stays the landing
truth (D9); realistic shadows are mood only.

## Ceiling proof / references

- GodotCon Boston 2025 "Making Stylized 3D Games in Godot"
  ([talk](https://talks.godotengine.org/godotcon-us-2025/talk/QXD8TR/)) —
  pipeline methodology transfers.
- [Ex Zodiac](https://godotengine.org/showcase/ex-zodiac/) — polished
  stylized 3D ships in Godot.
- [Godot 2025 showreel](https://www.youtube.com/watch?v=7ZwEmxihlw4).
