# World Card — AUNT TORTOISE (world 4)

**One line:** the oldest giant, asleep so long a whole garden grew over her
shell — a terraced hillside of moss and blooms climbing a tortoise instead
of a hill.

**Register:** the hushed-est world in the game — slower than Bramble, softer
than Wisp, quieter than Marmalade. Nothing here hurries. Her breathing sway
is the slowest of any giant (`SHELL_BREATH_PERIOD=14.0s`, nearly 3x
Bramble's own chest-breathing period, `worlds/bramble/breathing_chest.gd`'s
`period=5.0` — D25's mountain precedent: static terrain collision, subtle
VISUAL breathing only, at the smallest amplitude of any world, ±1% scale).
Never dark-scary: honey lantern-glow at dusk, moonlight on dew.

**Palette:** moss shell `#8C9463`, deep moss accents `#6E8F6A`, honey bloom
glow `#F2C879`, blush blooms `#E8B4C8`, cream `#F5F2E8`, dusk-sage meadow
`#7C9082` (lighter tint pair `#96A698` for the ground-patches shader), warm
soil/stone terrace edging `#8A6552`. Dreamlings stay `#FFF3C4`.

**The body as playground (movement gifts):**
- **Terraces as scute plates**: her big rounded shell plates read as garden
  terraces — collision ring-ledges hugging the dome at four heights
  (meadow skirt, Tier1, Tier2, Tier3, Crown), each a generous garden bed
  you could nap on, connected by long, gentle ramps (9-14° grades — the
  gentlest slopes of any world; "gentle ramps/steps" per the brief).
- **The whole dome breathes, barely**: an always-on, near-imperceptible
  breathing sway on the shell's own visual scale (never the collision —
  static under subtle visual breathing, matching D25's mountain precedent)
  — you could stand here a long time before you noticed.
- **A perch that breathes with her**: one small bloom (`BreathingBloom`)
  bobs gently on her breath cycle partway up the climb — a dream naps
  right on it (the flourish dreamling, d07 — the tortoise's answer to
  Bramble's snore-geyser / Wisp's water-spout / Marmalade's purr-thermal
  "rides a living breath" tradition).

**Layout (radial, not linear — a spiral up and around the shell, spawn at
the meadow's west edge):** meadow skirt → Tier1 (low terrace, ~2 m) →
Tier2 (~5.6 m) → Tier3 (~9 m) → Crown (~12 m, the shell's highest bloom,
DreamDoor). Shell footprint ~40 m across (target ~35-45 m per the brief).

**Dreamlings (10, D12 cadence, ids d01-d10) — the mix (1 race, 1 ride, 1
shy, 1 duet, 1 flourish, 5 open):**
d01 race (meadow, near spawn), d02 open (meadow, dense-cadence second
find), d03 open (Tier1 ledge), d04 ride (Tier2 ledge, a small drifting
loop), d05 duet (Tier2 ledge, a garden clearing big enough for two), d06
open (Tier3 ledge), d07 open+flourish (rides the BreathingBloom perch
between Tier2 and Tier3 — speaks once on catch, "naps right on her slow
breath"), d08 shy (hidden among Tier3 clover tufts), d09 open (Crown
ledge), d10 open (beside the DreamDoor, the highest bloom).

**DreamDoor:** nested beside the Crown's "highest bloom" bump — dreams
return at the top of the climb, the highest point she has ever grown.

**Camera hints (4):** meadow approach (frame the whole terraced dome),
lower terraces (Tier1/Tier2), upper terrace (Tier3), crown (the summit
bloom + DreamDoor).

**Rescue floor:** meadow at y=0; void beyond the meadow ring → rescue
plane at y=-8 (bramble-moat pattern — below the rescue line, never a stuck
apron).

**Audio hooks:** world stem set `stems/tortoise/` (placeholder synth: the
slowest tempo of any world). SFX reuse: `giant_rumble`/`giant_yawn_sigh`
double for THE SLOW RISE until dedicated sounds exist (audio pass note,
honestly UNVERIFIED — see VERIFY doc).

**Fort growth:** dreams returned here count toward the same total (D14).

---

## THE SLOW RISE (keystone, `worlds/tortoise/rise_sequence.gd`, on
`core/cinematic/cine_sequence.gd`)

At 10/10 dreams (or `--rise`), Aunt Tortoise — slower than anything in the
game — stands over ~12 s: the whole garden (terraces + shell, one group)
lifts skyward a few meters into a hanging-terrace vista, petals drift,
nothing falls hard (the world's gentlest earthquake). A long hold under the
moon, then she settles back down with a sigh. Players are bubble-lifted to
the meadow skirt FIRST (floor law — nobody is ever near moving ground).
Persistent reward: a small "highest bloom" garden nook near the crown,
built hidden at boot and revealed (visibility + collision, ground solid
first — the established lesson) during the sequence — permanently
reachable afterward, exactly the way Wisp's flood route and Marmalade's
attic nook persist.
