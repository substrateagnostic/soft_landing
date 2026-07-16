# World Card — WISP the whale (world 3)

**One line:** a whale the size of a weather system, dozing in mid-air just
above a moonlit mountain lake, dreaming of the sky.

**Register:** the quietest world — silver-blue, wide, slow. Never dark-scary:
the lake glows faintly from below (moonlight through water), the whale's
belly has a soft aurora sheen.

**Palette:** deep dusk blue `#22304F` (lake), silver `#C9D4E4` (whale hide),
pale cyan `#9FE8E0` (emissives/spouts), blush horizon `#D9A5B3` kept from the
house sky, wet-stone grey `#5E6B7A` (shore rocks). Dreamlings stay `#FFF3C4`.

**The body as playground (movement gifts):**
- **The whole world breathes vertically**: Wisp rises and sinks ~2.5 m on a
  20 s cycle (AnimatableBody root for the whale group, sync_to_physics) —
  crossing from shore to whale means timing a slow, forgiving elevator.
- **Water-spout updrafts**: the blowhole erupts a tall gentle spout on the
  breath cycle (geyser pattern, but 14 m tall, lifting to the head).
- **The slide**: the whale's back from dorsal hump to tail is a low-friction
  slope (a long smooth ramp, physics material friction ~0.05) — ride it down
  into the lily field. Sliding is the joy verb here.
- **Lily-pad hop chain**: 8-10 broad pads (≥1.6 m radius — generous) across
  the lake from shore to flipper; they bob 0.2 m on offset sine phases.
- **Tail seesaw**: the fluke tilts ±8° on a 6 s cycle — a slow moving ramp
  onto the back.

**Layout (along +X like Bramble, shore at −X):** shore spawn → lily chain
across the lake → flipper ledge → belly shelf → dorsal slide crest →
blowhole/head. Whale ~100 m long, back crest ~14 m at rest.

**Dreamlings (10, D12 cadence, ids d01-d10):** d01 shore path, d02 first
lily pad, d03 mid-lily-chain, d04 flipper ledge, d05 belly shelf (open) —
d06 rides a bobbing lily (parented), d07 atop the water spout (ride it),
d08 on the dorsal crest reachable by the slide-crest walk OR Otto-toss from
the belly shelf (never toss-only), d09 hidden among shore reeds (tall thin
boxes, glow visible), d10 beside the blowhole DreamDoor.

**DreamDoor:** the blowhole — dreams dive in; door trigger sized per the
bramble lesson (≥3.6 wide, covers standing above AND beside).

**Camera hints (≥3):** shore approach (frame the whole whale + reflection),
lake crossing (slightly higher pitch for pad-hop depth), spine run (yaw along
body axis toward the head).

**Rescue floor:** the lake is NOT a hazard — falling in shallow water near
shore is walkable (waist-deep, slow move zone OK to skip in v1); the rescue
plane sits below the lake bed (-8). Beyond the shore ring: void → rescue,
same as Bramble's moat (below the rescue line, never a stuck apron).

**Audio hooks:** world stem set `stems/wisp/` (placeholder synth: F major,
slower; layer_1 whale-song swell). SFX reuse: snore_geyser doubles as the
spout until a dedicated sound exists.

**Fort growth:** dreams returned here count toward the same total (D14).
