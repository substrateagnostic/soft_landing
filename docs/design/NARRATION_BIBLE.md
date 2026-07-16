# NARRATION_BIBLE.md — The Moon

*Written for THE BIG NAP's UI/writing pass (D20, DIRECTION_V2.md). Read
alongside `docs/research/v2/ui_writing.md` §4 (the Fry/Hakim contrast this
whole document is built around) and §5 (the gibberish-voice technique
`scripts/autoloads/the_moon.gd` implements).*

## Who the Moon is

The Moon is awake while everyone else sleeps — the giants, the fort, the
whole hushed world of the game. That's the entire character: **she has
nothing to do but watch over you, so she does it warmly.**

- She speaks *to* the kids as "little duck" — never their character names,
  never "player one." It's a term of address a parent uses, not a game UI
  label.
- She is a little wry with the grown-up on the second pad, without ever
  being unkind or knowing to the kids. The dry wit lives in *word choice*
  (see `well_done`'s "can you hear it purring?"), never in a joke that
  requires reading between the lines — a 5-year-old should never feel
  talked over.
- She is **softly proud**, not congratulatory. She never says "great job!"
  or "you win!" — no scoring language exists in her vocabulary. She
  notices what happened and reflects it back gently.
- She **never scolds, never explains controls mid-play, never narrates an
  action while it's happening.** That last rule is the load-bearing one —
  see "The Law" below.

## The Law: structural beats only

Research (`ui_writing.md` §4) names the exact failure mode to avoid: *It
Takes Two*'s Dr. Hakim, a narrator so constant and self-congratulatory
that reviewers call him "one of the game's more annoying characters" —
not because his intent was wrong, but because *frequency broke the
character*. Stephen Fry's LittleBigPlanet narration is the counter-example:
present at structural moments only, and beloved for it.

The Moon speaks at, and only at:

1. **Arrivals** — a new area loads (`new_area`), the title screen appears
   (`welcome`).
2. **First-catch** — the first dream returned in a given world
   (`dream_home`) and a world's *last* dream returned (`well_done`).
3. **Returns at 1 / 5 / 10** — the fort-growth thresholds. The very first
   return already speaks through `dream_home`; the 5th and 10th
   *cumulative* returns across all worlds speak through `fort_grows_5` /
   `fort_grows_10`, which `the_moon.gd` fires **on its own** by watching
   `GameState.dream_returned` and counting `GameState.total_returned()` —
   no other file needs a call site for this beat.
4. **Bloom moments** — a dreamling mission resolving (`mission_race`,
   `mission_ride`, `mission_shy`, `mission_duet` — see "Keys prepared for
   other systems" below).
5. **First-use celebrations** — the very first flutter / glide / ground-
   pound-bounce a session sees (`move_flutter_first`, `move_glide_first`,
   `move_pound_first`).
6. **Callie moments** — rare, world-specific (`callie_dreams`).
7. **Rescue** — the soft-landing catch (`rescue` — see below).
8. **Title welcome** and **goodnight on quit** (`welcome`, `goodnight`).
9. **Pause** (`paused`, `keep_playing`) — the one *utility* exception:
   these exist to confirm the game heard the pause/resume, not to
   editorialize about it, so they stay short and function-first.

She never speaks mid-jump, mid-carry, mid-toss, or to describe a UI
element. If a future call site is tempted to add "nice flutter!" on every
single flutter (not just the first), that is the Hakim failure mode —
don't.

## Mechanical enforcement

`the_moon.gd` backs the content discipline above with a **one-line-at-a-
time job queue**: `say()` always prints its `MOON_SAID` receipt
immediately, but the actual spoken/captioned playback is serialized
through `_busy`/`_queue`, so two beats fired close together can never talk
over each other — the queue enforces "one at a time," writers/call-sites
enforce "rare."

## Delivery: moonsong + minimal text (D20)

Every line now has **1-5 hand-written variants**, picked at random per
call (high-frequency keys get more variants so they don't wear into
wallpaper). `settings.voice_mode` picks the channel:

| Mode | What plays |
|---|---|
| `moonsong+text` | Gibberish "moonsong" syllables + a subtitle. No TTS. |
| `moonsong+tts` (**default**) | Moonsong, then real TTS speaks the same line — the D13 floor ("every objective a young player must understand is spoken") stays satisfied even with a gibberish voice as the primary personality layer. |
| `tts_only` | TTS alone — an accessibility mode for a player who'd find moonsong noisy to parse. |
| `text_only` | Subtitle alone, no audio. |

Moonsong itself: `~/assets/audio/voice/moon_syl_00..09.ogg`, ten soft
breathy syllable samples (`tools/audio_gen/generate_voice.py`, D-major-
pentatonic pitch centers matching the rest of the game's sound world).
For a given line's *text*, a `RandomNumberGenerator` seeded from
`hash(text)` deterministically picks which samples play, in what order,
and at what per-syllable `pitch_scale` (±8% jitter around a mood-biased
center — lines tagged "excited" in `the_moon.gd`'s `EXCITED_KEYS` run a
little higher, "gentle" ones in `GENTLE_KEYS` run a little lower, Animal-
Crossing-style). Same text in, same syllable stream out, every time.

The subtitle ribbon (`scenes/ui/subtitle_ribbon.gd`) shows the same chosen
line text in every mode except a line has no audio to sync to
(`text_only`), where it just holds for an estimated reading time.

## Word budget

Total line text across every key below (all variants, summed): **~410
words** — under the 900-word ceiling, and a fraction of Astro Bot's
~4,300-word *entire-game* script, appropriate for a narrator who speaks
rarely by design.

## Every line, by key

### Wired today (an existing call site already speaks this key)

**`welcome`** — title screen load (`scenes/title.gd`).
> "Hello, little duck. The giants are sleeping. Let's find their dreams."
> "Shh. Everyone's asleep but us. Ready to go dream-hunting?"
> "Welcome back, little duck. The night is soft and waiting."

**`find_dreamling`** — reserved (written, not yet called from anywhere;
kept for whichever system adds a "point at the next glow" hint).
> "A dream is glowing nearby. Can you go touch it?"

**`dream_home`** — the first dream returned in a world
(`worlds/common/world_base.gd`). Rewritten this pass from an instruction
("carry the dream home...") to a reflection of what just happened —
matches the Moon's "notices, doesn't narrate the doing" register.
> "Home again. The giant sighs, warm and glad."
> "Look at that — safe and snug. One more dream tucked in."
> "There. The fort glows a little brighter now."
> "Well carried, little duck. That dream is home."

**`well_done`** — every objective in a world returned
(`worlds/common/world_base.gd`, alongside `GameState.mark_world_completed`).
This key already *is* the "world complete" beat — see the `world_complete`
note below for why a second, separate key exists rather than reusing this
one for a bigger milestone.
> "You found them all. The giant smiles in their sleep."
> "Every dream is home. Listen — can you hear it purring?"
> "All tucked in. This whole place is glad you came."

**`new_area`** — every world load/switch (`scenes/main.gd`).
> "A new place to explore. Let's see what's waiting."
> "Ooh. Somewhere new. Stay close, and let's look around."
> "Here we are. Quiet now — someone big is sleeping here."

**`paused`** — pause menu opens (`scenes/ui/pause_menu.gd`).
> "Taking a little rest. I'll wait right here."
> "Pause whenever you like. I'm not going anywhere."

**`keep_playing`** — resume from pause (`scenes/ui/pause_menu.gd`).
> "Let's keep exploring together."
> "Back we go, little duck."

**`goodnight`** — Sleep (quit-to-title) from the pause menu
(`scenes/ui/pause_menu.gd`). This key already covers "quit-goodnight" —
there is no separate key for that concept.
> "Goodnight, little duck. Sweet dreams until next time."
> "Off to bed. I'll keep watch till you're back."
> "Sleep well. The giants will still be dreaming tomorrow."

**`callie_dreams`** — a Callie moment in Marmalade (`core/companion/callie.gd`).
> "Callie dreams of being big someday."
> "Even Callie curls up small and dreams enormous dreams."

### Self-wired this pass (`the_moon.gd` listens to `GameState` directly)

**`fort_grows_5`** — cumulative `total_returned()` crosses 5 (fort_stage 2).
> "Five dreams home now. Listen — the fort is humming."
> "The fort's getting fuller. Can you feel it glowing?"

**`fort_grows_10`** — cumulative `total_returned()` crosses 10 (fort_stage 3).
> "Ten dreams home. The whole fort is warm with them."
> "Look how big it's grown. All because you kept going."

### Keys prepared for other systems (written + registered; call sites owned elsewhere)

These are written and live in `the_moon.gd`'s line table today —
`TheMoon.say("mission_race")` etc. works the instant another system calls
it. No call site exists yet because the owning system (dreamling
micro-missions, D21; the movement moveset ladder, D17) is outside this
UI/writing pass's territory (`worlds/**`, `core/**`).

**`mission_race`** — a gentle-chase dreamling archetype resolving.
> "Someone's feeling quick today. Think you can keep up?"
> "A little race, just for fun. Nobody loses this one."

**`mission_ride`** — a carry/ride-together dreamling archetype resolving.
> "Climb on. Some dreams are easier to carry together."
> "Hold tight, little duck. This one likes to travel."

**`mission_shy`** — a shy-creature dreamling archetype resolving (needs a
gentle approach, never a chase).
> "This one's shy. Go slow, and let it come to you."
> "Careful now — soft steps. Shy dreams startle easy."

**`mission_duet`** — a two-player-only dreamling archetype resolving.
> "This dream needs two. Lucky you brought a friend."
> "Together now — one of you won't be enough for this."

**`move_flutter_first`** — the first double-jump flutter a session sees.
> "Ooh! Your onesie catches the air. Try that again."
> "Look at you flutter. Little duck, you can float."

**`move_glide_first`** — the first glide a session sees.
> "Now you're gliding. Slow and soft, like a falling leaf."
> "Arms out — there you go. That's flying, almost."

**`move_pound_first`** — the first ground-pound bounce a session sees.
> "What a thump! Did you feel that bounce?"
> "Down you go — and up someone else pops. Nicely done."

**`world_complete`** — reserved for a *bigger* milestone than a single
world's `well_done` (e.g. every world complete, a whole-game "the night
is settled" beat) — deliberately **not** auto-wired to `GameState.
world_completed` in this pass, because `worlds/common/world_base.gd`
already speaks `well_done` on that exact signal; wiring both would mean
two Moon lines back-to-back for one event, which is the over-narration
failure mode this whole document exists to avoid. Whoever adds the
bigger milestone (an all-worlds-done state doesn't exist yet — there are
two worlds in the v0.1 slice) should call this key directly, once, for
that distinct moment.
> "This whole place is dreaming happily now, because of you."
> "Everything here is settled and sound. You did that."

**`rescue`** — the soft-landing catch (`core/rescue/soft_landing.gd`,
`player_rescued` signal). Written to the exact register the design floor
demands: falling is a gift, never a failure, so the Moon never sounds
surprised or concerned — she treats it as unremarkable. Not wired in this
pass (`core/**` is out of this build's territory); ready the instant the
owning system calls `TheMoon.say("rescue")`.
> "Whoops — up you float. Falling's just another way to land."
> "Gotcha. Soft as a pillow, safe as anything."
> "No trouble at all, little duck. Up and onward."

## Coordination note for parallel agents

If your system needs a Moon line for a beat not listed above: **add the
key + 1-3 variants to `data/moon_lines.json`** (it's a flat
`key -> String | Array[String]` map — either shape works, `the_moon.gd`
normalizes both) and call `TheMoon.say("your_key")` from your own
call site. Please keep new lines to the same register (warm, spare,
"little duck," never scolding, never narrating an action in progress) and
run the word-budget math again before it grows unbounded.
