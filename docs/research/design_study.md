# Design Study: "Very Young Player + Accompanying Adult" in Shipped First-Party Platformers

Research compiled July 2026 for **soft_landing** — a no-fail 3D collectathon platformer for a 4-year-old (Ezra) and a parent, gamepad co-op.

Goal: reverse-engineer how shipped, well-reviewed games solve the exact problem soft_landing has — a player who cannot yet lose gracefully, playing beside an adult who wants to help without taking over.

---

## 1. Kirby and the Forgotten Land (Nintendo / HAL, 2022)

This is the single most relevant title: Nintendo's first 3D Kirby, explicitly engineered so that inexperienced players (including young children) can play a 3D platformer without ever fighting the controls.

### Fail-soft / no death spiral
- **Two difficulty modes, both generous.** Spring-Breeze Mode (easy) gives Kirby/Bandana Dee **400 HP vs. 250 HP** in Wild Mode, spawns fewer enemies, and drops boss HP faster when hit. Difficulty is changeable anytime outside a stage — no lock-in, no penalty. ([Game8 difficulty comparison](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/371230), [WiKirby: Difficulty](https://wikirby.com/wiki/Difficulty))
- **Design intent is soothing, not punishing.** Reviewers frame the entire Kirby line as "fun, easy-going adventures meant to soothe more than challenge," and Forgotten Land keeps that even in 3D. ([ScreenRant: Is It Too Easy?](https://screenrant.com/kirby-forgotten-land-difficulty-easy-hard-good/))
- **No hard death.** Losing HP returns you to the last checkpoint; there is no lives-based game-over cascade in normal play. Checkpoints are frequent and stages are short (below).

### Attack/movement forgiveness (primary-source gold)
From Nintendo's official **Ask the Developer Vol. 4** interview, the team's stated goal was to remove the two things that make 3D hard for beginners — camera and aiming:
- **Auto-aim generosity:** *"if it looks like an attack 'should' hit on-screen, we made sure it does connect."*
- **"Fuzzy Landing"** (a developer-coined term): *"the system treats Kirby as if he's already landed if the A Button is pressed at a close distance"* — even misjudged jump timing succeeds. ([Nintendo: Ask the Developer Vol. 4, Part 2](https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-4-kirby-and-the-forgotten-land-part-2/))

These two mechanics are the crux: the game silently rounds the player's imprecise inputs up to success. A 4-year-old's aim and timing are exactly the imprecision this covers.

### Camera (no player camera control)
- **The player never controls the camera.** *"the player doesn't need to control the camera — the camera moves for you."* Level designers hand-author the camera per area; it swings to top-down or side-on to best frame the required action.
- **Camera as a guidance system:** *"camera automatically displays landmarks in the direction you're supposed to travel"* — so players don't get lost or backtrack by accident.
- The devs identified **camera control as the #1 difficulty barrier for inexperienced 3D players and removed it entirely.** ([Nintendo: Ask the Developer](https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-4-kirby-and-the-forgotten-land-part-2/), [Nintendo Life review](https://www.nintendolife.com/reviews/nintendo-switch/kirby-and-the-forgotten-land))
- Structurally it follows the **Super Mario 3D World** model (tightly framed, semi-guided "play areas") rather than Odyssey's free-roam sandbox. ([NintendoEverything tech analysis](https://nintendoeverything.com/kirby-and-the-forgotten-land-tech-analysis-including-frame-rate-and-resolution/))

### Two-player asymmetry (Kirby vs. Bandana Waddle Dee)
This is the reference model for soft_landing's P2. Player 1 = Kirby (full kit: Copy Abilities, Mouthful Modes, all Treasure Road stages). Player 2 = Bandana Waddle Dee (a fixed spear moveset only). ([Game8 co-op guide](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/370930), [WiKirby: Multiplayer](https://wikirby.com/wiki/Multiplayer))

What **P2 can do:** attack with spear, revive downed enemies pressure, help in combat, exist in the world alongside P1.

What **P2 cannot do / asymmetries:**
- **The camera only ever follows Kirby (P1).** Bandana Dee can fall off-screen. ([Game8](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/370930))
- **Warp-to-P1 rescue:** if Bandana Dee goes off-screen, *"they will be carried back into view inside a safe little bubble."* He literally cannot be left behind or lost. ([Co-Optimus co-op review](https://www.co-optimus.com/review/2436/kirby-and-the-forgotten-land-co-op-review.html))
- **Downed-partner auto-revive:** *"A downed partner will automatically respawn after a set time."* Kirby keeps going and Bandana Dee re-enters on his own. ([Co-Optimus](https://www.co-optimus.com/review/2436/kirby-and-the-forgotten-land-co-op-review.html))
- **P2 is not the fail condition:** only if **Kirby (P1) runs out of HP** do both players return to checkpoint. Bandana Dee going down never ends the run. ([Co-Optimus](https://www.co-optimus.com/review/2436/kirby-and-the-forgotten-land-co-op-review.html))
- P2 is excluded from Treasure Road, Tilt-and-Roll, most Mouthful Modes (reduced to throwing spears from Kirby's back), and cannot use "to-go" shop items. ([WiKirby: Multiplayer](https://wikirby.com/wiki/Multiplayer))

**The lesson (and its critique):** This makes P2 the perfect "assist" seat for a younger or weaker player — low stakes, can't lose the game, can't get lost. Critics note it also makes P2 a *lesser* role and wish for two full Kirbys. ([ScreenRant critique](https://screenrant.com/kirby-forgotten-land-coop-two-kirbies-disappointing-multiplayer/), [Co-Optimus](https://www.co-optimus.com/review/2436/kirby-and-the-forgotten-land-co-op-review.html)) — **For soft_landing the "lesser role" tradeoff is a feature, not a bug, IF we assign it correctly** (see Recommendations). Note: in soft_landing the *child* is likely the one who wants the star role, so the naive Kirby-model mapping (child=P2 helper) may be backwards — discussed below.

### Collectible telegraphing (Waddle Dees)
- **Waddle Dees are the core collectible and the progression currency.** Each stage has ~5 "missions"; completing each frees Waddle Dees. Some are obvious (finish the stage), some hidden (secret tasks, defeating bosses). ([Game8 missions](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/371266), [Gamer Rant guide](https://gamerant.com/kirby-and-the-forgotten-land-walkthrough-complete-guide-missions-collectibles-waddle-dees-blueprints/))
- **Hidden objectives are revealed *after* you finish the stage** — the mission list unmasks so you know what you missed, turning "missable" into "come back and get it." No permanent miss anxiety. ([Nintendo Life Waddle Dee locations](https://www.nintendolife.com/guides/kirby-and-the-forgotten-land-waddle-dee-locations-where-to-find-every-hidden-waddle-dee))
- **Collectibles rebuild a visible home:** rescued Waddle Dees repopulate Waddle Dee Town, unlocking new buildings and shops. The count is *visibly* transformed into a growing, revisitable place. ([Game8](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/371266))

### Session structure for short attention spans
- **Stages are ~5 minutes each** (5–10 with full completion), 40 total stages, 5–7 per world. Bite-sized, self-contained, with a clear finish and reward every few minutes. ([Game8 play time](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/371561), [CBR length guide](https://www.cbr.com/kirby-forgotten-land-how-long-beat-complete/))

---

## 2. Super Mario Odyssey (Nintendo, 2017)

### Assist Mode — exactly what it changes
Assist Mode is a toggle that layers generosity on top of the normal game (source: Mario Wiki / SMO Wiki, surfaced via search):
- **More health:** 6 hearts by default (vs. 3), expandable to **9** with a Life-Up Heart.
- **Passive healing:** *"the player will heal by standing idly."* No item required to recover.
- **Bubble return instead of death:** falling into a pit, poison, or other deadly hazard costs **one heart** and **floats you back to safe ground in a bubble** — you are never killed by a fall. (In the Jaxi driving segment, Jaxi respawns at the start on a void-fall.)
- **No drowning:** *"The player will never drown in water."*
- **Guidance arrows:** *"Visual arrows will appear within the world to guide the player to the next objective."*
- Assist is **auto-disabled during opt-in challenge minigames** (Koopa Freerunning, Luigi's Balloon World) so it can't be used to cheat leaderboards.
([Mario Wiki: Assist Mode](https://mario.fandom.com/wiki/Assist_Mode), [SMO Wiki: Assist Mode](https://smo.wiki/Assist_Mode), [GameFAQs Assist Mode guide](https://gamefaqs.gamespot.com/switch/200275-super-mario-odyssey/faqs/75301/assist-mode))

The pattern: **hazards never remove the player from play; they just cost a resource and reset position.** That is the "soft landing" the project is named for.

### Two-player mode (P2 = Cappy) — "helper without stakes"
- P1 controls Mario; **P2 controls Cappy**, floating above Mario's head, free to fly around within a leash, throw at enemies, and grab coins/notes. ([Twinfinite](https://twinfinite.net/guides/super-mario-odyssey-play-co-op-cappy-how/), [Nintendo: Mario and Cappy](https://supermario.nintendo.com/mario-cappy/))
- **Cappy is effectively invincible / stake-free** — "perfect for players who can't stomach dying." P2 cannot lose the game. ([Techtimes](https://www.techtimes.com/articles/210073/20170615/super-mario-odyssey-co-op-mode-is-official-first-player-controls-mario-second-player-gets-cappy.htm), [Twinfinite](https://twinfinite.net/guides/super-mario-odyssey-play-co-op-cappy-how/))
- **Leash constraint:** Cappy must stay near Mario — cannot wander off alone, so P2 can't strand themselves or the camera. ([Samurai Gamers](https://samurai-gamers.com/super-mario-odyssey/co-op-mode/))
- P2's value is *helpful, not required:* clear hazards ahead of Mario, vacuum up quickly-vanishing collectibles (music notes), speed up enemy kills. The game still works if P2 does nothing. ([IBTimes](https://www.ibtimes.com/super-mario-odyssey-co-op-mode-demo-shows-player-two-take-control-cappy-2553108))

This is the **cleanest "helper without stakes" template**: P2 adds capability and joy, holds the fiction of togetherness, and carries zero failure risk. The critique ("2 player Cappy is broken") is that it's *so* stake-free it can feel shallow for the helper — relevant only if the helper is the one seeking challenge. ([GameFAQs board](https://gamefaqs.gamespot.com/boards/200275-super-mario-odyssey/75469140))

---

## 3. Other Prior Art

### Astro Bot (Team Asobi / Sony, 2024) — readability & generosity, GOTY 2024
- Multiple Game-of-the-Year wins (The Game Awards, BAFTA, DICE). Praised for **readability, lavish "devoted to joy" polish, and accessibility to all skill levels** while still offering optional challenge. Levels are short and end before their gimmick gets stale (some only a few minutes). ([Wikipedia](https://en.wikipedia.org/wiki/Astro_Bot), [TechRadar review](https://www.techradar.com/gaming/astro-bot-review))
- Strong accessibility layer: visual cues that mirror haptics, gyro-to-stick remaps, aiming reticles. Nothing gates you behind a hard skill wall. ([Access-Ability review](https://access-ability.uk/2024/09/05/astro-bot-accessibility-review/), [Game Accessibility Nexus low-vision review](https://www.gameaccessibilitynexus.com/blog/2024/09/05/astro-bot-low-vision-review/))
- **Collectible-den model:** rescue **300 Bots** + Puzzle Pieces; both feed a **hub (Crash Site) you rebuild** — Gatcha Lab (spend collected coins on 169 cosmetic prizes), changing room, zoo. Rescued bots become a visible, revisitable crowd in your hub. This is the "count becomes a place you visit" loop done in 3D. ([Game8 Gatcha guide](https://game8.co/games/Astro-Bot/archives/473656), [GamesRadar collectibles](https://www.gamesradar.com/games/platformer/astro-bot-collectibles-bots-puzzle-pieces-warps/), [TheGamer postgame](https://www.thegamer.com/astro-bot-best-postgame-activities/))

### Super Mario 3D World (Nintendo, 2013) — why co-op *competition* hurts here
- 3D World's co-op is celebrated as **"joyous chaos"** — but the chaos is the warning. **Player collision is real:** bumping teammates sends them off ledges to their death; a fast player **drags the shared camera** and leaves slower players behind off-screen; there's an end-of-level **crown competition** that rewards the strongest player. ([Engadget](https://www.engadget.com/2013-10-24-how-super-mario-3d-world-masks-co-op-in-chaos.html), [GameSpot: Chaos Multiplied](https://www.gamespot.com/articles/super-mario-3d-world-chaos-multiplied/1100-6409658/), [Co-Optimus review](https://www.co-optimus.com/review/1319/page/2/super-mario-3d-world-co-op-review.html))
- **Lesson for soft_landing:** every one of these — collision-kills, shared-camera drag, scoreboards/crowns — is *actively harmful* with a 4-year-old. A skilled parent will constantly, accidentally, kill or strand the child, and the crown institutionalizes "dad wins." **soft_landing must design these OUT:** pass-through characters (no collision damage), a camera that never abandons either player, and zero head-to-head scoring.

### Bluey: The Videogame (Outright Games, 2023) — preschool co-op done gently
- Explicitly built for the 4–7 "first real video game" bracket: E-for-Everyone, no purchases, no chat, **UI toggle, simple on-screen text, full voice-over**, up to 4-player local co-op. ([Common Sense Media](https://www.commonsensemedia.org/game-reviews/bluey-the-videogame), [Fatherly review](https://www.fatherly.com/entertainment/bluey-the-videogame-review-kids-and-family), [Screenwise WISE review](https://screenwiseapp.com/media/bluey-the-videogame-game))
- **Key mechanic to steal:** *"if you go off the screen you will get bounced back so little brothers and sisters can join in."* Same anti-strand idea as Kirby's bubble and Cappy's leash — **no player can ever fall behind or be lost.** ([Screenwise](https://screenwiseapp.com/media/bluey-the-videogame-game))
- Co-op leans **cooperative-required** (stand on shoulders to reach high spots, move heavy objects together) rather than competitive — non-competitive by design. ([Screenwise](https://screenwiseapp.com/media/bluey-the-videogame-game))

### Paw Patrol World (3DClouds / Outright Games, 2023) — licensed 3D preschool, the cautionary middle
- First free-roam 3D Paw Patrol; drop-in split-screen co-op, pick-a-pup. Reviewers: *"a smartly made entry-level open-world game… a playground to explore as opposed to a steep challenge,"* lots of collectables. Good at being a safe, low-stakes sandbox. ([ScreenRant review](https://screenrant.com/paw-patrol-world-switch-review/), [Nintendo World Report](http://www.nintendoworldreport.com/reviewmini/65105/paw-patrol-world-switch-review-mini))
- **What licensed preschool games get wrong (the review consensus):** *"repetitive… no variety at all and no slow increase in difficulty,"* most tasks are two-button, mastery arrives immediately and then nothing changes. ([ScreenRant](https://screenrant.com/paw-patrol-world-switch-review/), [OpenCritic aggregate](https://opencritic.com/game/15582/paw-patrol-world/reviews))
- **Lesson:** low-stakes is necessary but not sufficient. Even a 4-year-old needs a **gentle novelty curve** — new gimmicks/toys every stage (Astro Bot's model) — not the same two buttons for 8 hours. The parent needs it too, to stay engaged as co-pilot.

### Nintendo's bubble lineage — New Super Mario Bros. Wii (2009) onward
- The **bubble** debuts as co-op rescue tech: a downed player **reappears in a floating bubble**, and shakes to drift toward teammates; any non-bubbled teammate pops it by touching or hitting it. A player can also **enter a bubble on demand** to opt out of a hard section. ([Mario Wiki: Bubble](https://www.mariowiki.com/Bubble), [Wikipedia: NSMB Wii](https://en.wikipedia.org/wiki/New_Super_Mario_Bros._Wii))
- Design goal, stated by Nintendo, was **beginner-friendliness** (alongside the Super Guide auto-play block): let a weaker player bow out of any moment without ending the group's run. IGN praised the bubble as "a smart design choice." ([Wikipedia](https://en.wikipedia.org/wiki/New_Super_Mario_Bros._Wii))
- Caveat that informs our version: NSMB Wii still had a **fail case — if *everyone* bubbles at once, the level restarts.** For a true no-fail game with a 4-year-old, we want the *rescue* half of the bubble (re-enter safely) **without** the group-wipe condition. This lineage (bubble → Odyssey bubble-return → Kirby off-screen bubble → Bluey bounce-back) is the throughline of "you cannot be lost."

---

## 4. Synthesis — The Rescue Vocabulary (no-fail 3D platformer for a 4-year-old)

A checklist of generosity mechanics, each traced to the shipped game(s) that proved it:

| # | Mechanic | What it does | Proven by |
|---|----------|-------------|-----------|
| 1 | **Bubble-return on hazard/fall** | Falling in a pit/water costs at most a small resource and floats you back to solid ground; never a death. | SMO Assist Mode; NSMB Wii bubble; Kirby off-screen bubble |
| 2 | **No drowning / no environmental death** | Water and hazards can't kill; they inconvenience. | SMO Assist Mode |
| 3 | **Auto-follow camera, zero player camera control** | Camera is authored to frame the goal and show the way; kid never wrestles a second stick. | Kirby (devs called camera the #1 barrier and removed it) |
| 4 | **Camera as compass** | Camera pans to reveal the next landmark/objective so no one gets lost or backtracks. | Kirby; SMO Assist arrows |
| 5 | **Input rounding — "Fuzzy Landing"** | Near-miss jumps snap to landing; imprecise timing succeeds. | Kirby |
| 6 | **Auto-aim generosity** | If an attack *looks* like it should connect, it connects. | Kirby |
| 7 | **Generous / regenerating health** | Big HP pool; heal by standing still; more hearts in assist. | SMO Assist Mode (6→9, idle heal); Kirby (400 HP easy) |
| 8 | **Warp-to-leader / anti-strand** | A player who falls off-screen is carried back to the group; can never be left behind. | Kirby (bubble to Kirby); Bluey (bounce-back); Cappy leash |
| 9 | **Auto-revive of the downed partner** | Knocked-out helper returns on a timer, no input needed. | Kirby |
| 10 | **Failure gated to one anchor player (or none)** | Only the lead running out matters; the child's character can't end the run. Best case: nobody can. | Kirby (only Kirby's HP fails); SMO Cappy (P2 can't die) |
| 11 | **Opt-out button** | A player can voluntarily bubble/rest during a scary bit without stopping the group. | NSMB Wii |
| 12 | **No player-vs-player collision** | Bodies pass through / don't shove each other off ledges. | *Anti-lesson* from Mario 3D World (collision-kills hurt) |
| 13 | **No competitive scoring between players** | No crown, no scoreboard, no "who won." | *Anti-lesson* from Mario 3D World crown |
| 14 | **Objective revealed post-attempt** | Missed collectibles are shown after the stage → "come back," never "lost forever." | Kirby mission unmask |
| 15 | **Short, self-contained stages (~5 min)** | A full arc — start, play, reward — inside one attention span. | Kirby (~5 min stages); Astro Bot (short, gimmick-length levels) |
| 16 | **Novelty curve, gently rising** | New toy/gimmick each stage keeps kid AND parent engaged. | Astro Bot (positive); Paw Patrol (negative: sameness bores) |

---

## 5. Collectible Psychology for Preschoolers

### Immediate feedback loop
- For preschoolers, **immediate feedback drives motivation and a "sense of achievement"**; their attention spans and cognition demand that content be simple, direct, and rewarding *right now*. Delayed or abstract rewards don't land. ([Frontiers in Psychology meta-analysis](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1307881/full), [Springer: preschool educational game design](https://link.springer.com/article/10.1007/s11042-024-19803-7))
- Implication: **every pickup should fire instantly** — sound + sparkle + count-up + the item flying to a visible tally. Multi-sensory confirmation, not a silent inventory increment. (Astro Bot's readability/haptic-cue philosophy applied to collection.)

### Collection screen / den you revisit (the "museum" pattern)
- Animal Crossing's museum is beloved because the collection **becomes a beautiful, living place you revisit and admire** — empty tanks fill with fish, a personal encyclopedia, "a point of pride you can continually revisit," with the reward being *intrinsic* (a happy owl, a full room), not loot. ([Kotaku: I Love the Museum](https://kotaku.com/i-love-animal-crossing-new-horizons-museum-1842798339), [PlayThePast analysis](https://www.playthepast.org/?p=6880))
- **Kirby (Waddle Dee Town) and Astro Bot (Crash Site hub) both do the 3D-platformer version:** the count of things you rescued visibly **rebuilds and repopulates a home** you can walk back through. The collectible isn't a number in a menu — it's a crowd of friends in a place. ([Game8: Waddle Dee reward](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/371266), [Game8: Gatcha Lab](https://game8.co/games/Astro-Bot/archives/473656))
- Implication for soft_landing: build a **hub/den that grows** with what Ezra collects — a place to return, count, and show dad.

### Counting as joy
- 4-year-olds are in the thick of learning to count; **counting is intrinsically pleasurable at this age**, and games that surface number/quantity as reward tap directly into a developing skill and a sense of mastery. ([Springer: preschool game design](https://link.springer.com/article/10.1007/s11042-024-19803-7)) *(See UNVERIFIED for the strength of this specific claim.)*
- Implication: **make the count loud and legible** — big numbers, count-up animations, "you have SEVEN now!", tallies that a pre-reader can read as *more dots = good*. The number going up is itself the reward.

### What to avoid
- **Rare / missable collectibles** — cause anxiety and "lost forever" frustration; Kirby explicitly defuses this by revealing missions after the fact so nothing is permanently missable. ([Nintendo Life](https://www.nintendolife.com/guides/kirby-and-the-forgotten-land-waddle-dee-locations-where-to-find-every-hidden-waddle-dee))
- **Long droughts between rewards** — preschool attention can't bridge a dry stretch; the feedback loop must be dense (Kirby drops Waddle Dees ~every mission; Astro Bot seeds bots throughout every short level).
- **Sameness with no novelty** — Paw Patrol World's core critique: same two buttons, no rising variety = boredom even for the target age. Vary the *kind* of collectible and the toy used to get it. ([ScreenRant: Paw Patrol World](https://screenrant.com/paw-patrol-world-switch-review/))

---

## Recommendations for soft_landing

### The Rescue Vocabulary — implement these (priority order)
1. **Bubble-return, universal.** No pit, water, or hazard ever removes a player. Fall → float back to the last solid ground in a soft bubble. No lives, no game-over screen, ever. *(SMO Assist + NSMB bubble + Bluey bounce-back.)*
2. **Anti-strand camera + warp-to-group.** One authored auto-follow camera; **no player camera control at all** for either player initially. Any player who leaves the frame is gently carried back. Camera actively pans to reveal the next goal. *(Kirby.)*
3. **Input rounding.** Fuzzy-landing on jumps and auto-aim/auto-snap on interactions, so Ezra's imprecise timing/aim reads as success. *(Kirby — the highest-leverage, least-visible generosity.)*
4. **No collision between players, no competitive scoring.** Characters pass through each other; no crown, no score race. *(Anti-lessons from Mario 3D World — the single biggest co-op trap for this age.)*
5. **Generous, forgiving health if health exists at all** — big pool, regen when idle. Strongly consider **no health system at all**, only bubble-return, so there is literally nothing to "lose."
6. **Short stages (~3–6 min)** each ending in a reward and a return to the hub. *(Kirby, Astro Bot.)*
7. **Post-stage reveal of what's left to find** — never a permanent miss. *(Kirby.)*

### P2 asymmetry recommendation
The instinct is to copy Kirby directly (P1 = powerful lead, P2 = stake-free helper) and put the child in the safe P2 seat. **Recommend inverting the surface framing while keeping the mechanics:**

- **Ezra should be the "star" character** (the one the camera follows, the one whose collecting drives progress) — a 4-year-old wants to be the hero, not the sidekick, and being followed by the camera means he can never be stranded.
- **The parent takes the Cappy/Bandana-Dee role: a high-capability but stake-free helper** who can clear hazards ahead, gather fast/tricky collectibles, revive/assist, and *cannot* trigger failure. The adult's superior skill becomes *support*, not competition or accidental sabotage.
- Give the parent **just enough to do to stay engaged** (Astro Bot/Paw-Patrol lesson: a bored helper disengages) — meaningful assist verbs (grab, boost, clear, carry), not a passive floating cursor.
- Concretely: **camera follows the child; the helper is leashed to the child and warps back if they drift** (Cappy leash + Kirby bubble). **Only a shared no-fail state** — neither player can end the run; the worst outcome is a bubble-return.

This gives the emotional truth soft_landing is named for: the adult is the soft landing — always there, always helping, never the reason the game stops, never competing with the child they're playing beside.

---

## UNVERIFIED / Could Not Fully Confirm

- **SMO Assist Mode exact heart counts (6 default → 9 with Life-Up):** sourced from Mario Wiki / SMO Wiki via search snippet; direct page fetches returned 402/403, so numbers are from the search excerpt, not a first-party manual. Treat "6/9, idle-heal, no-drown, bubble-return, arrows" as wiki-consensus, not Nintendo-documented.
- **SMO ledge-grace / longer coyote-time in Assist Mode:** the task asked about "longer ledge grace." **No source found** confirming Assist Mode changes ledge/edge grace timing. Documented Assist changes are hearts, idle-heal, bubble-return, no-drown, and arrows only. Assume ledge-grace is NOT an Assist feature unless verified.
- **Cappy "invincible / cannot die":** sources say P2/Cappy is stake-free and "can't stomach dying" players should use it, and Cappy isn't a damageable body — but I found no first-party statement that Cappy has an explicit invincibility flag. It's stake-free by construction (Cappy has no life bar), which is functionally the same.
- **Kirby downed-partner respawn timer length** ("after a set time") — exact duration not found.
- **"Counting is intrinsically joyful for 4-year-olds"** — supported indirectly by preschool game-design literature on immediate-feedback/achievement and by developmental norms (counting is an actively-developing skill at 4), but I did not find a single study stating "counting as reward" as a named design principle. Directionally well-founded; treat the strong phrasing as design intuition backed by adjacent research, not a cited finding.
- **Astro Bot has no dedicated 2-player co-op** comparable to Kirby/Odyssey; it's cited here for readability, generosity, and the collectible-den/hub-rebuild pattern, not for co-op asymmetry.
- **Kirby "warp-to-P1"**: confirmed as "carried back in a bubble when off-screen," which is functionally warp-to-P1; the game does not appear to offer a manual teleport button for P2. Exact trigger distance not documented.
