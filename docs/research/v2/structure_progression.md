# World Structure, Mission Design & Progression — Research for THE BIG NAP

Compiled July 2026. **served_model: claude-sonnet-5** (Claude Sonnet 5, Anthropic).

Lane: world structure, mission (dreamling) design, and progression pacing for THE BIG NAP — a no-fail 3D collectathon for a 4-year-old (P1, Pip the duck) and a parent (P2, Otto the bear), narrated aloud by the Moon. This doc is scoped to *what a level/world/hub is built out of and how it paces reward*, complementing the accessibility-and-co-op findings already in `docs/research/design_study.md`. Vocabulary used throughout: `dreamling` (collectible), `pillow_fort` (hub), `bramble` (first world), `the_moon` (narrator), `soft_landing` (fail-state replacement), `toss` (Otto's carry-throw of Pip).

---

## 1. Super Mario 64 — the collectathon's founding grammar

Super Mario 64 replaced the obstacle-course structure of 2D Mario with a **mission structure inside an explorable sandbox**: each of 15 main courses contains six numbered star missions plus a hidden 100-coin star, for 120 total stars (only 70 required to finish). ([The 3D Collectathon's History, Part One](https://saikogame.design.blog/2018/08/31/the-3d-collectathons-history-analysis-and-future-part-one-super-mario-64/), [Super Mario Wiki](https://www.mariowiki.com/Super_Mario_64))

**Teaching without text — the star name is the tutorial.** Star names are the entire instruction set: "Big Bob-omb on the Summit" tells the player *where* (up) and *what* (a boss) without a quest log. Because the level is one continuous space, a player aiming for one star will stumble into the sightline of another — the "Behind Chain-Chomp's Gate" star is discoverable purely by walking past it on the way to the mountain star. Objectives are simultaneously freestanding (nameable, completable in any order) and spatially entangled (visible from each other), which is what produces the "I meant to get one star and left with three" feeling. ([saikogame.design.blog](https://saikogame.design.blog/2018/08/31/the-3d-collectathons-history-analysis-and-future-part-one-super-mario-64/))

**A confirmed mission taxonomy** recurring across courses: *signature/thematic* (bespoke to the level's core gimmick, e.g. race the giant boulder), *race-vs-rival* (Koopa the Quick), *red-coin* (8 hidden coins scattered per course), *cap-power* (requires Wing/Metal/Vanish cap), and *100-coin* (a survive-and-collect star layered on top of the same geometry as every other star, costing no new content). ([Mario Party Legacy stars guide](https://mariopartylegacy.com/guides/super-mario-64-walkthrough-and-stars))

**Vertical landmarks do double duty.** Eight of fifteen courses are built around a tall, visible landmark (mountain, tower, tree). This solves orientation in a large 3D space (you can always see where "up/away" is) and repurposes the "bottomless pit" tension from 2D platforming into climb-and-retry rather than instant death — falling just means climbing again, no punishment. ([saikogame.design.blog](https://saikogame.design.blog/2018/08/31/the-3d-collectathons-history-analysis-and-future-part-one-super-mario-64/))

**Peach's Castle is the prototype hub-as-progress-display**: it's often cited as the trope codifier for hub worlds. Doors are locked behind star-count thresholds; hitting a threshold physically unlocks a new wing of the *same* building the player already knows, so progression reads as "the house got bigger," not "a menu unlocked." ([CBR: Why Peach's Castle Is a Great Hub](https://www.cbr.com/mario-64-peach-castle-perfect-hub-world-nintendo/), [Trace's Blog: Home Sweet Home](https://tracedressen.wordpress.com/2019/02/21/home-sweet-home/))

---

## 2. Super Mario Odyssey — what changed when moons replaced stars

The headline structural change: **collecting a moon does not eject you from the level.** Odyssey kingdoms range from 1 to 104 moons each, because the design goal shifted from "curated scarcity" to "abundant discoverability" — developers at large described the shift as replacing "search for Power Stars" with **"search for new experiences, new things to capture, and new environments."** ([Game Developer: What Are Devs Saying](https://www.gamedeveloper.com/design/what-are-devs-saying-about-the-design-of-i-super-mario-odyssey-i-), [Super Mario Wiki: Power Moon](https://www.mariowiki.com/Power_Moon))

**Density is the point, not a side effect.** Practitioners praised that "every tiny detail in this world" carries a reward — coin piles reward the skilled/curious player who reaches a high ledge, not just the objective-follower. One developer: exploration should make you "constantly delighted by bite-sized content everywhere." ([Game Developer](https://www.gamedeveloper.com/design/what-are-devs-saying-about-the-design-of-i-super-mario-odyssey-i-))

**Two independent, self-paced hint systems** prevent the late-game "collection slog" that sinks most collectathons as density drops in the back half — hints are both player-paced (opt-in) and economy-paced (cost coins), so a lost player can always self-rescue without being nagged. ([Game Developer](https://www.gamedeveloper.com/design/what-are-devs-saying-about-the-design-of-i-super-mario-odyssey-i-))

**Dual difficulty in one space**: Odyssey's "challenge yourself" design intentionally layers easy-and-hard-at-once — trivial moons sit in plain sight while master moons demand precision — inside the *same* kingdom, with no separate mode. Removal of the lives system was part of the same accessibility push. ([Game Developer](https://www.gamedeveloper.com/design/what-are-devs-saying-about-the-design-of-i-super-mario-odyssey-i-))

---

## 3. Banjo-Kazooie — the jiggy as a story, and Tooie's cautionary bloat

**Hub-and-spoke with thematic gating.** Gruntilda's Lair is the hub; jiggies and musical notes gate access to nine themed worlds (Mumbo's Mountain, Treasure Trove Cove, Clanker's Cavern, Bubblegloop Swamp, Freezeezy Peak, Gobi's Valley, Mad Monster Mansion, Rusty Bucket Bay, Click Clock Wood) — mirroring SM64's star-gate pattern one level deeper (the hub itself is a level with its own secrets). Rare used "weenies" (prominent landmarks), clean zone separation, and legible doorways so players could always self-orient without a map. ([GMTK: The World Design of Banjo-Kazooie](https://gmtk.substack.com/p/the-world-design-of-banjo-kazooie))

**A confirmed jiggy taxonomy** (six recurring archetypes, corroborated across GMTK's analysis and the Jiggy wikis):
1. **NPC favor** — solve a character's stated real-world problem (feed Gobi, help Mr. Vile).
2. **Transformation** — a Mumbo skull temporarily turns Banjo into a walrus/termite/pumpkin/crocodile to reach jiggies otherwise inaccessible; this is the series' signature archetype.
3. **Puzzle/environmental** — switches, movable objects, sequenced interactions.
4. **Race** — Boggy's sled race, Mr. Vile's snap-race; a rival with a fixed pattern, not a punishing time limit.
5. **Exploration/hidden** — sitting in plain sight for a curious/thorough player, no gate at all.
6. **Skill test / mini-challenge** — Conga's drum minigame, target/shooting challenges.
Additionally, a small number of **cross-level jiggies** require an item or ability unlocked in a *later* world, rewarding return visits. ([GMTK](https://gmtk.substack.com/p/the-world-design-of-banjo-kazooie), [Jiggywikki](https://banjokazooiewiki.com/wiki/Jiggy), [GameFAQs Jiggy FAQ](https://gamefaqs.gamespot.com/n64/196694-banjo-kazooie/faqs/24719))

**Design philosophy, stated by the designer himself:** every world in the original *Banjo-Kazooie* "can be finished with the abilities gained by that point" — minimal forced interconnection, so a child (or a first-time player) is never softlocked waiting on a skill from three worlds away. ([GMTK](https://gmtk.substack.com/p/the-world-design-of-banjo-kazooie))

**Tooie is the industry's clearest bloat cautionary tale.** Rare's own designer, Gregg Mayles, later reflected: *"We got the balance right the first time and perhaps made... the mistake of wanting bigger, better, and more for the sequel."* ([GMTK](https://gmtk.substack.com/p/the-world-design-of-banjo-kazooie)) Concretely:
- Mayahem Temple — Tooie's **first and shortest** level — takes over an hour to 100%, versus Kazooie's comparable Mumbo's Mountain at under 30 minutes. ([Derek Ex Machina: Size Over Substance](https://www.derekexmachina.com/blog/2024/11/25/banjo-tooie-larger-levels))
- Grunty Industries, often cited as the worst level in the series, consumed **3.5 hours (20%+ of one reviewer's total playtime)** for no extra collectibles versus other levels — six floors, sprawling interconnection, and a repetitive aesthetic that gets players lost. ([Derek Ex Machina](https://www.derekexmachina.com/blog/2024/11/25/banjo-tooie-larger-levels), [CelJaded retrospective](https://www.celjaded.com/retrospective-banjo-tooie/))
- Constant **backtracking to already-cleared levels** after learning new abilities (worlds physically tunnel-connected instead of separately gated) delayed gratification and confused wayfinding. ([Derek Ex Machina](https://www.derekexmachina.com/blog/2024/11/25/banjo-tooie-larger-levels))
- The essay explicitly invokes designer Jaime Griesemer's **"30 seconds of fun" combat-loop principle** from Halo's 2002 GDC talk: Kazooie kept the collect-loop tight (seconds between rewards); Tooie stretched it to five-plus minutes, turning collection into "busywork." Griesemer's own clarification of the quote matters here too: the point was never "repeat one 30-second loop forever," it was **the same short core loop recontextualized** in new environments/tools each time — variety of dressing, not variety of loop length. ([Derek Ex Machina](https://www.derekexmachina.com/blog/2024/11/25/banjo-tooie-larger-levels), ["30 Seconds of Fun" — Clarity Potion](https://claritypotion.com/2024/04/15/30-second-fun-focusing-principle/), [Engadget: Half-Minute Halo interview](https://www.engadget.com/2011-07-14-half-minute-halo-an-interview-with-jaime-griesemer.html))
- Thematic hub entrances still worked well even at Tooie's scale: Isle O' Hags previews content through its geography (a polluted hub sub-area sits outside the factory-themed world). ([Trace's Blog](https://tracedressen.wordpress.com/2019/02/21/home-sweet-home/))

---

## 4. Astro Bot (2024, GOTY) — joy-density and the "small game" thesis

**Deliberately shrunk scope, in the team's own words.** Director Nicolas Doucet: *"It's okay to make a small game."* The studio mantra is "aim for quality, not quantity." The team cut more-open sandbox levels in favor of **tightly hand-crafted ones**, so every platform, enemy, and bot placement could be tuned for rhythm and tempo — the opposite of Tooie's bigger-is-better trap. Target length was 12 hours (would have shipped at 8 if quality held). ([Game Developer: "It's okay to make a small game"](https://www.gamedeveloper.com/design/-it-s-okay-to-make-a-small-game-astro-bot-director-nicolas-doucet-says-tiny-ideas-contain-huge-potential))

**Mechanical non-repetition as a hard rule.** At GDC 2025, Doucet described cutting a whole level concept (a bird-flight level using the "monkey amplification" boost) because it felt too similar to an already-shipped level's use of the same power-up — even the *same tool* isn't allowed to feel the same way twice. ([IconEra: GDC 2025 notes](https://icon-era.com/threads/gdc-2025-the-making-of-astro-bot-astro-bot-took-3-years-of-development-and-was-pitched-to-sony-back-in-may-of-2021.16650/), [Geek Culture](https://geekculture.co/astro-bot-director-says-smaller-scale-and-aa-nature-was-key-to-games-success/))

**Set-piece cadence — the reviewer-confirmed rule of thumb:** *"Every time the player diverts off the main path in search of a secret or reward, they find one"* — Team Asobi is described as understanding its own level-design grammar well enough to reliably predict where players will get curious, and always paying that curiosity off. ([GameSpot: How to Easily Find All Bots](https://www.gamespot.com/articles/astro-bot-how-to-easily-find-all-bots-puzzle-pieces-and-void-levels/1100-6526249/))

**Collectibles are alive, not inert.** Bots wave, react to being freed, and trigger a **speaker chirp through the DualSense** on pickup — a second, physical sensory channel layered on top of visual/audio feedback. Interactive scenery (destroyable logs that reveal a pull-cord to more reward) demonstrates the "reward curiosity with both a tangible reward and delight" loop directly. ([maxfrequency.net: Astro Bot Notes](https://maxfrequency.net/game-notes/astro-bot/))

**Reward economy, exact numbers:** 430 total collectible locations — 300 bots, 120 puzzle pieces, 10 secret "Lost Galaxy" levels — across roughly a 10–12 hour game. Puzzle pieces unlock hub facilities (Gatcha Lab, speeder garage, outfit collection, Safari Park); collecting all 300 bots + all puzzle pieces unlocks one final bonus level. ([Astro Bot Wikipedia](https://en.wikipedia.org/wiki/Astro_Bot), [PowerPyx 100% Walkthrough](https://www.powerpyx.com/astro-bot-100-walkthrough-all-bots-puzzle-pieces-secret-levels/))

**Caution flag for THE BIG NAP:** the Gatcha Lab spends coins on **randomized** pulls for cosmetic bots — a variable-ratio reward schedule. This is the single Astro Bot mechanic *not* to imitate for a 4-year-old audience (see §7 and Top 12, item 4).

**Minimal narrative load, maximal active time.** Fewer than 5,000 words, no voice acting, only 12.5 minutes of total cutscenes — players are "active" roughly 98.3% of playtime. Guest-character abilities (Kratos, Aloy) were stripped to one-button versions of their source games' more complex kits, prioritizing immediate legibility over faithfulness. ([Game Developer](https://www.gamedeveloper.com/design/-it-s-okay-to-make-a-small-game-astro-bot-director-nicolas-doucet-says-tiny-ideas-contain-huge-potential))

**Crash Site (the hub) as living progress display:** the hub itself has 30 bots and 11 puzzle pieces spread across five subdivisions that unlock progressively as story modules are installed — the hub is not just a menu screen between levels, it is itself a small collectathon that visibly grows as the story does. ([PowerPyx: Crash Site Guide](https://www.powerpyx.com/astro-bot-crash-site-hub-area-bots-puzzle-pieces-locations/), [Game8: Crash Site Guide](https://game8.co/games/Astro-Bot/archives/473459))

---

## 5. Kirby and the Forgotten Land — mission-within-level and hub-as-reward

**Five missions per stage is the level's internal collectible taxonomy.** Every stage carries five missions; missions 1–2 are always "clear the stage" and "save the hidden Waddle Dees" (visible from the start except in boss stages). Crucially, **completing or progressing toward any hidden mission reveals it**, and finishing a stage without 100%-ing it auto-reveals one more hidden mission — the game actively *removes* the anxiety of an invisible checklist rather than demanding the player intuit what they missed. Most missions reward one Waddle Dee; clearing the stage itself rewards three; the "hidden Waddle Dees" mission has 3–5 individually rescuable Dees hidden in the stage geometry. ([Kirby Fandom: Missions](https://kirby.fandom.com/wiki/Missions_(Kirby_and_the_Forgotten_Land)), [WiKirby: Mission](https://wikirby.com/wiki/Mission_(Kirby_and_the_Forgotten_Land)), [Nintendo Life: Waddle Dee Locations](https://www.nintendolife.com/guides/kirby-and-the-forgotten-land-waddle-dee-locations-where-to-find-every-hidden-waddle-dee))

**Difficulty rises through obscurity, not punishment.** Later-game Waddle Dees are hidden behind more oblique triggers (specific copy-ability interactions, secret passages) rather than tighter timing or harder combat — the curve steepens on *cleverness required to find*, not *skill required to survive*. ([Gameranx: World 3 guide](https://gameranx.com/features/id/295326/article/kirby-and-the-forgotten-land-how-to-find-all-waddle-dees-world-3-wondaria-remains/))

**Dual-difficulty-in-one-space, explicitly aimed at a 3-year-old.** The lead designer has stated the design target was a 3D platformer playable by "even a three-year-old" — realized via Spring-Breeze Mode (400 HP vs. 250 HP, fewer enemies, faster boss HP drain, switchable anytime with zero penalty) plus deliberately "quiet areas" for players who want to explore without combat pressure, sitting *inside* the same stages as the higher-challenge content. ([WiKirby: Difficulty](https://wikirby.com/wiki/Difficulty), [Pro Game Guides](https://progameguides.com/kirby-and-the-forgotten-land/kirby-and-the-forgotten-lands-difficulty-modes-explained/), [GamesLearningSociety](https://www.gameslearningsociety.org/wiki/what-is-the-difficulty-setting-in-kirby-forgotten-land/))

**Waddle Dee Town is the reward, made physical.** As Waddle Dees are rescued the town literally rebuilds: Café at 60 saved, Item Shop at 145, Fishing Pond at 155, a minigame booth at 180, with golden statues of Kirby and Elfilin as the 100%-completion capstone. Thresholds are round numbers a child could track without reading a UI — "we rescued more, the town got a new building" is the entire mental model required. ([Gamerant: Waddle Dee Town Upgrades](https://gamerant.com/kirby-forgotten-land-waddle-dee-town-upgrades-list/), [Game8: Waddle Dee Town](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/370824))

**Session length is a designed constant, not an accident.** Stages run roughly 5 minutes for a bare clear, 5–10 for full completion, across 40 stages / 5–7 per world — bite-sized, self-contained units with a guaranteed reward and a guaranteed stopping point every few minutes. ([Game8: Play Time](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/371561))

---

## 6. Pacing, attention span, and parent–child co-play research

**Session length for young children is genuinely short.** General findings across child-focused design research: sustained single-session focus beyond ~30 minutes produces fatigue in young children, and a more realistic evaluation model lets kids play in short bursts across a longer stretch of time rather than one long sitting. Frustration compounds quickly — "a child who feels overwhelmed or confused will check out and get distracted quickly," and higher reported frustration correlates with *smaller* executive-function gains, i.e., frustration doesn't just feel bad, it measurably reduces what the child is getting out of play. ([Digital Games as a Context for Children's Cognitive Development — Social Policy Report](https://srcd.onlinelibrary.wiley.com/doi/full/10.1002/sop2.3); general findings corroborated across [BrainBalance: Normal Attention Span by Age](https://www.brainbalancecenters.com/blog/normal-attention-span-expectations-by-age) and children's-games UX literature surfaced in search)

**Progressive difficulty must have slack, not just a ramp.** The literature is consistent that increasing challenge sustains motivation up to a point, but "a strict difficulty curve that impedes progress may lead to a decline in initial motivation" — for this age band the curve needs escape valves (skip, easy-mode, no-fail) more than most adult-facing design guidance assumes. Feedback mechanisms (points, levels, visible progress) are called out specifically as the tool that keeps motivation up *between* difficulty increases.

**"30 seconds of fun" as a literal pacing budget.** Confirmed origin: Jaime Griesemer, 2002 GDC talk (with programmer Chris Butcher) on Halo's AI/level design — a 3-second loop nested in a 30-second loop nested in a 3-minute mission loop, deliberately re-dressed each time. The oft-misquoted takeaway ("just repeat 30 seconds of fun forever") is *wrong*; the real principle is: identify your shortest satisfying loop, then guarantee it recurs on a short, predictable clock while the surrounding context (environment, tool, partner) keeps changing. ([Clarity Potion](https://claritypotion.com/2024/04/15/30-second-fun-focusing-principle/), [Engadget interview](https://www.engadget.com/2011-07-14-half-minute-halo-an-interview-with-jaime-griesemer.html))

**Reward-schedule ethics matter specifically for this audience.** Variable-ratio (unpredictable) reward schedules are the most compulsion-generating reinforcement pattern in game design — the mechanism behind loot boxes — and the research explicitly flags that "children are easily susceptible to manipulative tactics, especially in-app purchases and variable rewards," and that targeting "adolescent brains with known developmental vulnerabilities" for engagement extraction is a distinct moral category from ordinary reward design. Ethical alternatives named: transparent, non-randomized reward structures; no purchase-driven RNG; clear cause-and-effect between action and reward. ([Gamification Hub: Ethical Gamification Principles](https://www.gamificationhub.org/ethical-gamification-principles/), [Neurolaunch: Variable Reward Psychology](https://neurolaunch.com/variable-reward-psychology/)) This is a direct, explicit warning against copying Astro Bot's Gatcha Lab mechanic (§3) into THE BIG NAP.

**Asymmetric design is the accepted answer to the parent/child skill gap.** Research on intergenerational co-play (age gaps of 10+ years) recommends *asymmetric* mechanics — different rules/verbs for each player rather than making both conform to one shared difficulty — plus **interdependent** mechanics that require real coordination between the pair, because that coordination is what generates conversation and relational value beyond the game itself. This is corroborated by the design philosophy already established in `design_study.md` for Kirby's P1/P2 split and Odyssey's Cappy co-op, but the framing here is explicitly relational: co-op isn't just an accessibility accommodation, the *act of depending on each other* is the product. ([Promoting Family Play through Asymmetric Game Design, ResearchGate](https://www.researchgate.net/publication/380190376_Promoting_Family_Play_through_Asymmetric_Game_Design); title/abstract corroborated, full PDF text not extractable — treat specifics as directional, not verbatim)

---

## 7. Hub design — what makes a hub feel like home

Four recurring elements across the hubs studied (Peach's Castle, Spiral Mountain / Isle O' Hags, Waddle Dee Town, Astro's Crash Site):

1. **Mystery that predates explanation.** A hub should contain something visibly locked or unexplained from the very first visit, so the player forms a goal before being told one. (Peach's Castle's locked upper floors; Crash Site's unlit subdivisions.) ([Trace's Blog](https://tracedressen.wordpress.com/2019/02/21/home-sweet-home/))
2. **Dynamic, visible growth tied to collection count, not menus.** The hub *physically* changes shape as the player collects — new wings unlock (Peach's Castle), buildings appear (Waddle Dee Town), sub-areas light up (Crash Site) — with thresholds simple enough a pre-reader can track them ("we got more, something new appeared") rather than requiring a percentage readout. ([CBR](https://www.cbr.com/mario-64-peach-castle-perfect-hub-world-nintendo/), [Gamerant: Waddle Dee Town](https://gamerant.com/kirby-forgotten-land-waddle-dee-town-upgrades-list/), [PowerPyx: Crash Site](https://www.powerpyx.com/astro-bot-crash-site-hub-area-bots-puzzle-pieces-locations/))
3. **A practice space with no stakes.** Peach's Castle garden lets players rehearse jumps and moves with zero hazard before entering a course proper — the hub doubles as a skill sandbox the child can return to under no pressure. ([saikogame.design.blog](https://saikogame.design.blog/2018/08/31/the-3d-collectathons-history-analysis-and-future-part-one-super-mario-64/))
4. **Thematic anticipation at the threshold.** The portal/door/entrance to each world previews that world's content and mood before the player steps through — Isle O' Hags' polluted approach to the factory world is the clearest example; this lets a narrator (or a parent) say "ooh, what do you think is in *there*?" and have the environment itself answer. ([Trace's Blog](https://tracedressen.wordpress.com/2019/02/21/home-sweet-home/))

Additionally: **the hub can itself be a small collectathon** (Astro's Crash Site has its own 30 bots/11 puzzle pieces) rather than a pure connective-tissue menu screen — this both extends the reward density of "home" and gives players a reason to revisit it beyond fast travel.

---

## TOP 12 ACTIONABLE — recommendations for THE BIG NAP

1. **Adopt a six-archetype dreamling taxonomy**, directly descended from the Banjo-Kazooie jiggy grammar, reskinned to the fiction: (a) **Nudge** — a sleepy creature has a small request (NPC favor); (b) **Snug-fit** — Pip/Otto's onesie shape or Otto's toss unlocks a spot only one of them fits (transformation/ability-gate, softened into "who's shaped right for this," never a hard lock); (c) **Puzzle-nook** — a small environmental interaction (switch, stack, roll); (d) **Gentle chase** — a race with no fail state, rubber-banded so neither kid nor parent "loses," just arrives second and gets the dreamling anyway; (e) **Tucked-away** — pure exploration reward for curiosity, no gate at all; (f) **Flourish** — a mini showcase of one specific move (a big jump, a slide, a toss-catch) as its own tiny challenge. Every dreamling in `bramble` should map to one of these six, named so `the_moon` can hint location/action through the name alone (SM64 pattern) without requiring the child to read anything.

2. **Cap `bramble`'s first-world scope hard.** Target Kirby-stage-length segments (5–10 minutes to fully clear a discrete area) rather than Tooie-scale sprawl. Concretely: no single traversal chunk should take a first-time 4-year-old player longer than ~10 minutes to feel "done," and the *whole first world* should be fully completable well under an hour. This is a direct hedge against the confirmed Banjo-Tooie failure mode (Mayahem Temple 1hr+, Grunty Industries 3.5hrs) — bigger is not better for this audience, and Astro Bot's own "it's okay to make a small game" thesis backs this even for an adult-facing AAA game.

3. **Set a reward-density floor, not just a ceiling.** Astro Bot's confirmed rule — every diversion off the main path pays off — should be a hard design constraint for `bramble`: any time a player leaves the "obvious" path (climbs a ledge, pokes a bush, follows a sound), something rewards them within a few seconds. Pair with the Halo "30 seconds of fun" principle reframed as a *pacing budget*: a sparkle, coin, sound, or dreamling-adjacent event should recur roughly every 20–30 seconds of active traversal, dressed differently each time (new terrain, new interactable) so the loop doesn't feel like repetition even though its rhythm is constant.

4. **Explicitly ban variable-ratio/gacha reward mechanics anywhere near the pillow_fort economy.** Astro Bot's Gatcha Lab (randomized coin-purchase pulls) is the one mechanic from this research set to *not* imitate. Every dreamling-to-fort-decoration conversion should be deterministic and previewable — the child should be able to see or be told exactly what they'll get before spending anything, no RNG loot layer. This is a direct application of the child-development literature on manipulative variable-reward design (§6) and should be treated as non-negotiable alongside the existing "no fail states" design floor in `AGENTS.md`.

5. **Build `pillow_fort` as a living progress display, not a level-select menu.** Follow the Peach's Castle / Waddle Dee Town / Crash Site pattern: new physical objects (a new pillow, a new blanket-tunnel, a new lantern) should appear in the fort itself at simple, round dreamling-count thresholds, visible without opening any UI. Consider giving `pillow_fort` its own small pool of hidden dreamlings/sparkles (Crash-Site pattern) so it's a destination worth lingering in, not just a hallway between worlds.

6. **Theme each world's threshold/portal to preview its content**, per the Isle O' Hags lesson — the door, tunnel-mouth, or path into each new world (bramble, and whatever follows) should visually/aurally hint at what's inside before entry, giving `the_moon` a natural line ("I wonder what's sleeping in there...") and letting the child form anticipation before being told what to expect.

7. **Reveal missed content after a segment closes, never before.** Adopt Kirby's post-clear mission-unmasking: don't show a checklist of hidden dreamlings while exploring (that produces anxiety and reading-dependency for a pre-reader); instead, when a discrete area is "done," have `the_moon` gently note if something's still tucked away, inviting a return look. This keeps the "no fail states / never punish incompleteness" design floor intact while still rewarding thoroughness.

8. **Give every dreamling pickup multi-sensory, non-randomized feedback.** Match Astro Bot's confirmed pattern (visual reaction + audio chirp + controller haptic/rumble) for every single dreamling — the payoff should be identical in *quality* every time (no bigger/smaller random reward), varying only in flavor (different sound per dreamling type) to avoid monotony without introducing gambling-adjacent variability.

9. **Design co-op "flourish" dreamlings that require both players, sparingly.** Use the cross-level/transformation jiggy pattern reframed for the toss mechanic: a small number of dreamlings per world should specifically need Otto to toss Pip somewhere Pip alone can't reach — not as a gate that blocks solo/buddy-AI play, but as an optional bonus category that makes co-op strictly additive (matches pillar 4: "the parent is a helper, never a rival"). This operationalizes the asymmetric/interdependent co-play research finding that shared dependency, not shared skill level, is what generates relational value.

10. **Use vertical/audible landmarks for orientation instead of a minimap.** Per SM64's confirmed pattern (8/15 courses built around one tall visible landmark), give each world one unmistakable silhouette (the sleeping animal itself is the natural fit — `bramble`'s bear) visible from anywhere in the world, so a 4-year-old can always answer "where do I go" by looking up, not by reading a map or HUD.

11. **Session-close checkpoints should land on a dreamling delivery, not mid-traversal.** Because attention span research shows young children need clean stopping points and fatigue compounds frustration, structure `bramble` so that natural pause points (a caregiver saying "one more, then bath time") coincide with "just delivered a dreamling to the fort" — i.e., avoid long uninterruptible stretches between save-safe/satisfying moments; keep the gap between guaranteed-good stopping points at or under ~5–10 minutes throughout, matching Kirby's per-stage cadence.

12. **Keep narrative load minimal and keep players active, not watching.** Follow Astro Bot's ratio discipline (98.3% active playtime, <5,000 words, no forced long cutscenes) — let `the_moon`'s narration ride *over* live gameplay rather than pausing for cutscenes, and keep any given spoken beat short enough that a 4-year-old's attention doesn't lapse before control returns. This also directly serves the existing design-floor requirement that TTS narration cover "anything a 4-year-old must understand," by keeping those narration beats terse enough to actually land.

---

### Sources index (all links used above)

- [The 3D Collectathon's History, Analysis and Future — Part One: Super Mario 64](https://saikogame.design.blog/2018/08/31/the-3d-collectathons-history-analysis-and-future-part-one-super-mario-64/)
- [Super Mario Wiki: Super Mario 64](https://www.mariowiki.com/Super_Mario_64)
- [Mario Party Legacy: SM64 Stars Guide](https://mariopartylegacy.com/guides/super-mario-64-walkthrough-and-stars)
- [CBR: Why Super Mario 64's Peach's Castle Is Such a Great Hub World](https://www.cbr.com/mario-64-peach-castle-perfect-hub-world-nintendo/)
- [Trace's Blog: Home Sweet Home — Exploring the Design of Hub Worlds](https://tracedressen.wordpress.com/2019/02/21/home-sweet-home/)
- [Game Developer: What Are Devs Saying About the Design of Super Mario Odyssey?](https://www.gamedeveloper.com/design/what-are-devs-saying-about-the-design-of-i-super-mario-odyssey-i-)
- [Super Mario Wiki: Power Moon](https://www.mariowiki.com/Power_Moon)
- [GMTK (Mark Brown): The World Design of Banjo-Kazooie](https://gmtk.substack.com/p/the-world-design-of-banjo-kazooie)
- [Jiggywikki: Jiggy](https://banjokazooiewiki.com/wiki/Jiggy)
- [GameFAQs: Banjo-Kazooie Jiggy FAQ](https://gamefaqs.gamespot.com/n64/196694-banjo-kazooie/faqs/24719)
- [Derek Ex Machina: Size Over Substance — How Larger Levels Make Banjo-Tooie an Inferior Sequel](https://www.derekexmachina.com/blog/2024/11/25/banjo-tooie-larger-levels)
- [CelJaded: Banjo-Tooie Retrospective](https://www.celjaded.com/retrospective-banjo-tooie/)
- [Clarity Potion: "30 Seconds of Fun" Is a Brilliant Focusing Principle](https://claritypotion.com/2024/04/15/30-second-fun-focusing-principle/)
- [Engadget: Half-Minute Halo — An Interview with Jaime Griesemer](https://www.engadget.com/2011-07-14-half-minute-halo-an-interview-with-jaime-griesemer.html)
- [Game Developer: "It's okay to make a small game" — Astro Bot's Nicolas Doucet](https://www.gamedeveloper.com/design/-it-s-okay-to-make-a-small-game-astro-bot-director-nicolas-doucet-says-tiny-ideas-contain-huge-potential)
- [IconEra: GDC 2025 — The Making of Astro Bot](https://icon-era.com/threads/gdc-2025-the-making-of-astro-bot-astro-bot-took-3-years-of-development-and-was-pitched-to-sony-back-in-may-of-2021.16650/)
- [Geek Culture: Astro Bot Director on Smaller Scale and AA Nature](https://geekculture.co/astro-bot-director-says-smaller-scale-and-aa-nature-was-key-to-games-success/)
- [GameSpot: Astro Bot — How to Easily Find All Bots and Other Secrets](https://www.gamespot.com/articles/astro-bot-how-to-easily-find-all-bots-puzzle-pieces-and-void-levels/1100-6526249/)
- [maxfrequency.net: Astro Bot Game Notes](https://maxfrequency.net/game-notes/astro-bot/)
- [Astro Bot — Wikipedia](https://en.wikipedia.org/wiki/Astro_Bot)
- [PowerPyx: Astro Bot 100% Walkthrough](https://www.powerpyx.com/astro-bot-100-walkthrough-all-bots-puzzle-pieces-secret-levels/)
- [PowerPyx: Astro Bot Crash Site Guide](https://www.powerpyx.com/astro-bot-crash-site-hub-area-bots-puzzle-pieces-locations/)
- [Game8: Astro Bot Crash Site Guide](https://game8.co/games/Astro-Bot/archives/473459)
- [Kirby Fandom: Missions (Kirby and the Forgotten Land)](https://kirby.fandom.com/wiki/Missions_(Kirby_and_the_Forgotten_Land))
- [WiKirby: Mission (Kirby and the Forgotten Land)](https://wikirby.com/wiki/Mission_(Kirby_and_the_Forgotten_Land))
- [Nintendo Life: Kirby and the Forgotten Land Waddle Dee Locations](https://www.nintendolife.com/guides/kirby-and-the-forgotten-land-waddle-dee-locations-where-to-find-every-hidden-waddle-dee)
- [Gameranx: World 3 Waddle Dee Guide](https://gameranx.com/features/id/295326/article/kirby-and-the-forgotten-land-how-to-find-all-waddle-dees-world-3-wondaria-remains/)
- [WiKirby: Difficulty](https://wikirby.com/wiki/Difficulty)
- [Pro Game Guides: Kirby and the Forgotten Land Difficulty Modes Explained](https://progameguides.com/kirby-and-the-forgotten-land/kirby-and-the-forgotten-lands-difficulty-modes-explained/)
- [Games Learning Society: What Is the Difficulty Setting in Kirby Forgotten Land?](https://www.gameslearningsociety.org/wiki/what-is-the-difficulty-setting-in-kirby-forgotten-land/)
- [Gamerant: Kirby and the Forgotten Land — All Waddle Dee Town Upgrades](https://gamerant.com/kirby-forgotten-land-waddle-dee-town-upgrades-list/)
- [Game8: Waddle Dee Town Facilities and Unlock Conditions](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/370824)
- [Game8: Kirby and the Forgotten Land Play Time](https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/371561)
- [Wiley/SRCD: Digital Games as a Context for Children's Cognitive Development — Social Policy Report](https://srcd.onlinelibrary.wiley.com/doi/full/10.1002/sop2.3)
- [Brain Balance Centers: Normal Attention Span Expectations by Age](https://www.brainbalancecenters.com/blog/normal-attention-span-expectations-by-age)
- [Gamification Hub: 5 Ethical Gamification Principles for Human-Centric Design](https://www.gamificationhub.org/ethical-gamification-principles/)
- [Neurolaunch: Variable Reward Psychology](https://neurolaunch.com/variable-reward-psychology/)
- [ResearchGate: Promoting Family Play through Asymmetric Game Design](https://www.researchgate.net/publication/380190376_Promoting_Family_Play_through_Asymmetric_Game_Design)
