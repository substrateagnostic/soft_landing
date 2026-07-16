# THE BIG NAP
*a game about being small and awake in a world that is huge and asleep*

**Repo:** `soft_landing` · **Register:** tender-enormous · **Audience:** Ezra
(4) + Alex, one couch, two gamepads · **Lineage:** third AI-directed game —
drawdown was *elegiac*, ill-will was *riotous*, this one is **hushed and
huge**: the feeling of being carried to bed by someone much bigger than you.

---

## The elevator

Once every hundred years, the great animals lie down for the Big Nap. A bear
the size of a hill. A whale that dozes in mid-air. A cat asleep across a whole
village. And when giants sleep, their dreams leak out — little glowing
creatures called **dreamlings** that drift away on the night wind.

Two small kids in animal onesies — **Pip** (duck onesie, small, P1) and
**Otto** (bear onesie, big, P2) — are awake past bedtime. They are the only
ones light enough to walk on sleeping giants without waking them. Their job,
whispered to them by **the Moon**: *bring the dreams home.*

You bounce across the breathing chest of a bear like a slow warm trampoline.
You ride snore-geysers up through the fur. You catch dreamlings and carry them
back to the giant's ear, and when a dream goes home the giant *dreams it out
loud* — the meadow blooms with moths and starlight for a moment, one more
viola line joins the lullaby, and somewhere in your pillow fort a new
night-light flickers on.

Nothing here can hurt you. If you fall, a dreamling catches you in a soft
bubble and floats you back up — the **Soft Landing**. The giants never wake.
The Moon never scolds. The world is enormous, and all of it is glad you came.

## Why this concept (and the two it beat)

**Movement as joy, literalized.** The genre brief asks for movement as the
product. A sleeping colossus is a playground made of movement gifts: a chest
that rises and falls is a *slow trampoline you can time or ignore*; a snore is
an *updraft on a rhythm*; fur is *tall grass that hides treasure*; a paw is a
*valley that becomes a staircase when the giant stirs*. The level design IS
the character design.

**The rescue is a relationship, not a system.** Every design-floor mandate
becomes fiction here: no fall damage because *something gentle always catches
you*; auto camera because *the Moon is watching over you*; TTS because *the
Moon talks to you*; persistence because *the giants remember your kindness in
their sleep*. The floor stops being constraints and becomes the theme:
**you are small, and the world is careful with you.** (The relation is the
only sovereign unit — this time as a bedtime story.)

**It's Ezra-shaped.** He free-roams (worlds are open bodies, never gated); he
loves ducks (he *wears* the duck); he counts (dreamlings chime up a pentatonic
ladder as the count grows); he jumps on furniture and his dad (chest
trampolines; Otto can pick Pip up and toss him — toss-and-catch is the oldest
parent-child game there is, now a co-op verb). And it's Kilgore-adjacent:
befriending the enormous thing instead of fearing it.

**Concept B — PUDDLEJUMP (declined):** cloud-kid weather courier; bounce on
clouds, deliver raindrops to thirsty gardens below. Great verticality, but the
rescue (an updraft) is impersonal, the collectible doesn't build toward a
place, and the fiction has no second character in it — co-op would be bolted
on. Kept in the drawer as a possible *world* (the whale's sky) rather than a
game.

**Concept C — THE ATTIC OF THE BIGS (declined):** shrunk kids in a giant
attic of enormous toys. Strong platforming furniture, but toys don't breathe —
the living-landscape movement tricks are the whole joy engine — and it lives
in Toy Story / Astro Bot's shadow. Declined for prior-art gravity and a
colder heart.

## Cast

| Who | What | Notes |
|---|---|---|
| **Pip** | small kid, duck onesie (P1 — Ezra's seat) | The star. Camera anchors him. His onesie's feathers puff and flap automatically at the top of every jump (the apex hang, made diegetic). |
| **Otto** | big kid, bear onesie (P2 — the helper seat) | Taller, slower, unbothered. Can carry & gently toss Pip, reach high shelves, and never, ever causes a problem. Solo mode: Otto follows as buddy AI. |
| **The Moon** | narrator (TTS) | Awake while everyone sleeps. Speaks every objective out loud, softly proud: "There's a dreamling hiding in the bear's left ear, little duck." |
| **The giants** | the worlds | Never wake. Respond in their sleep: rumbles, hums, happy sighs, a paw that curls open a new path when enough dreams come home. |
| **Dreamlings** | the collectible | Glowing drifting creatures, each a dream some giant is missing. Caught by touch; carried visibly overhead; chime on a rising pentatonic ladder. |

## The hub: the Pillow Fort

A blanket-and-cushion fort at the foot of the first giant, under a porch
light. This is the persistent, growing place (the museum pattern): every
returned dreamling adds something — a night-light, a jar of fireflies, a
drawing pinned to the blanket wall, a mobile that plays the collected dreams
back as tiny glowing dioramas. From the fort's doorway you can see the whole
skyline of sleeping giants — that's the world map. Walk toward a giant to
visit it. No doors are ever locked.

## The first world: BRAMBLE the bear

A bear the size of a hill, asleep in a dusk meadow. Chest = slow breathing
trampoline. Snout = warm wind that ruffles your onesie. Snores = scheduled
updraft geysers. Fur = tall-grass fields hiding dreamlings. Paws = valley
walk-up. Ten dreamlings in v0.1: some sitting in the open (dense cadence),
some needing a breath-timed bounce, one needing Otto's toss, one hiding in
the ear (the Moon tells you). Returning dreams to Bramble's ear makes him
dream aloud — and at 10/10, he rolls over in his sleep, gently, hugely,
revealing the meadow on his other side (the sequel hook, and the proof the
world remembers).

Roadmap giants (post-v0.1, one per world module): **Wisp** the whale (dozing
just above a lake — sky-and-water world), **Marmalade** the cat (asleep across
a village — rooftop world), **Aunt Tortoise** (a garden grown over her shell).

## The feel commitments (what Gate 2's video must prove)

- Jump feels like being tossed by someone who will catch you: fast rise,
  floaty flappy apex, soft fall, generous coyote/buffer (D2/D3).
- Camera never asks anything of anyone: no right stick, no surprises, reads
  like a patient adult kneeling to the child's eye line (D4/D5).
- Falling is a tiny gift, not a punishment: the Soft Landing bubble is
  *pleasant* — you get a dreamling's giggle and a soft pop (D6).
- Blob shadow + landing ring always-on; landing is never a guess (D9).
- Bramble breathes at a rhythm a 4-year-old can ride *without* timing it:
  the chest is bouncy at every point of its cycle; timing it is bonus, not
  requirement.

## Co-op camera choice (director's call, per GOAL)

Single shared camera, leash + bubble auto-warp, anchor weighted ~70/30 toward
Pip (D5). The child holds the frame; the parent tugs it; nobody is ever lost.

## Audio

Each giant sleeps to its own lullaby. The producer's viola records the melody
stems; dream-returns add layers (pizzicato fireflies, harmonics for the moon).
AudioManager exposes a stem seam from day one (placeholder synth stems until
the viola arrives). SFX: breath, felt-soft footsteps, dreamling chime ladder,
the bubble's pop. No percussion. Silence is allowed to happen.

## v0.1 scope (what Gate 4 accepts)

Pillow Fort hub + Bramble, movement/camera/co-op/rescue complete and tuned,
10 dreamlings, 3-stage fort growth, Moon TTS for every objective, viola stem
seam with placeholder stems, save/persistence, autoplay harness + movie
receipts throughout. Grey-box first; Meshy art behind the D10 seam.

## Title

**THE BIG NAP.** A four-year-old can say it, a film-noir dad can smirk at it,
and it is exactly what the game is. Working subtitle for the store page,
someday: *a very quiet adventure.*
