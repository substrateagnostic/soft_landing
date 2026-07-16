# ART_BIBLE.md — THE BIG NAP

**One sentence:** everything looks like a plush toy at dusk, lit like a
nursery at bedtime.

## Register
Tender-enormous. Hushed and huge. Soft, rounded, matte, warm. Nothing sharp,
nothing glossy, nothing that buzzes. If an object could plausibly hurt a
toddler who hugged it, its silhouette is wrong.

## Palette — "dusk pastel + lantern"
| Role | Color | Hex |
|---|---|---|
| Sky (zenith) | deep dusk blue | `#2E3B5E` |
| Sky (horizon) | rose quartz | `#D9A5B3` |
| Ground/meadow | sage in moonlight | `#7C9082` |
| Giant fur (Bramble) | warm umber | `#8A6552` |
| Lantern/porch light | honey glow | `#F2C879` |
| Dreamlings | pale gold-white | `#FFF3C4` (emissive) |
| Pip's duck onesie | soft yolk yellow | `#F0D264` + `#F5EDE0` belly |
| Otto's bear onesie | cocoa brown | `#9C7A5B` + `#E8D9C3` belly |
| The Moon / UI accents | milk white | `#F5F2E8` |
| Rescue bubble | blush translucent | `#E8B4C8` @ ~40% alpha |

Saturation stays low-mid everywhere EXCEPT dreamlings and the lantern glow —
emissive warmth is reserved for "things that love you." UI/readability
elements (blob shadow, landing ring) are exempt from mood rules: full
contrast, always legible (D9).

## Light
Single warm directional "moonlight" (soft shadows, low intensity, slightly
blue) + local honey-warm points (lanterns, fireflies, dreamlings). AGX
tonemap (house look proven in ill-will). Fog: gentle height fog in dusk rose,
never obscuring gameplay ground. Night, but a *safe* night — floor of visual
comfort: the player must never wonder what's in the dark, because nothing is.

## Shape language
Spheres and beans. Characters are single soft masses (onesie = one continuous
form, hood with animal face, mitten hands). Giants read as hills first,
animals second — horizon-scale curves, no visible claws/teeth (Bramble's
mouth is a sleepy line). Props: chunky, oversized in the hand, toy-store
proportions.

## Meshy house prompt (D10; adapted from ill-will's proven suffix)
Append to every prop/character prompt, verbatim:
`soft plush low poly, rounded chunky toddler-toy proportions, flat colors,
matte, no textures needed, game asset, clean silhouette, single object,
gentle and friendly, Kenney/KayKit style`
Params (proven July 2026, pipeline.md): meshy-6, preview→refine, lowpoly,
triangle, target_polycount 8000, should_remesh true, enable_pbr false, GLB.

## What Meshy makes vs what the engine makes
- **Meshy:** Pip, Otto, dreamlings (one base + tint variants), fort props
  (lantern, jar, mobile, cushions), meadow props (tufts, stones, flowers).
- **Engine (never Meshy):** the giants — they are terrain: sculpted soft
  meshes/CSG-derived forms with a fur pass (shader shells or mesh-scatter
  tufts), authored to collision-first shapes; the sky; fog; all VFX
  (dreamling trails, bubble, fireflies) as GPUParticles3D; blob shadow +
  landing ring.

## Animation (D10 — procedural, no rigs)
Squash-stretch on jump/land (scale, volume-preserving), lean into
acceleration, `lerp_angle` turning, idle breathing bob (everything alive
breathes — the whole game is breathing), onesie apex-flutter for Pip
(feather quads puff via shader/particles), Otto's carry = Pip parented to a
socket with both squashing slightly. Giants: one very slow sine breath
driving chest AnimatableBody3D + audio.

## Scale rules (meters)
Pip 0.9 · Otto 1.3 · dreamling 0.35 · fort door 1.6 · lantern 0.5 ·
Bramble ~120 nose-to-tail, chest plateau ~8 wide. Camera default distance
6–8 m; everything authored to read at that range on a couch TV.

## Type & UI
Almost none. Counts shown as dreamling pips + a big friendly numeral.
Any unavoidable text is also spoken by the Moon (D13). Rounded everything.
