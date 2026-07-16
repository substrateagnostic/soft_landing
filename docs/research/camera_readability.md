# Camera & Readability Research — soft_landing

Research date: July 2026. Target engine: Godot 4.6.x.
Design floor (hard constraints this document must serve):

- **Fully automatic camera.** The right stick must NEVER be *required*. Camera can exist as an optional assist, never a dependency.
- **Always-on blob shadows** under every character.
- **Always-on landing indicators** (ground-projected target where the player will land).
- Audience: a 4-year-old and a parent, two gamepads co-op *or* solo-with-buddy-AI, one couch, one screen.

Sections: **A** auto-camera in Godot 4, **B** co-op camera, **C** depth-perception aids. Recommendations and an UNVERIFIED list are at the end.

---

## A. Auto-camera in Godot 4

### A.1 SpringArm3D — the collision backbone

Godot ships a purpose-built node for third-person collision: `SpringArm3D`. It casts a ray (or a shape) along its local −Z axis and moves all its direct children (the `Camera3D`) to the first collision point, with an adjustable `margin`. This is exactly the "pull the camera in when a wall is behind the player" behavior.

- Node reference and API (including `add_excluded_object`, `clear_excluded_objects`, `margin`, `shape`, `spring_length`, `collision_mask`): <https://docs.godotengine.org/en/stable/classes/class_springarm3d.html>
- Official tutorial "Third-person camera with spring arm": <https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html> (4.4 mirror: <https://docs.godotengine.org/en/4.4/tutorials/3d/spring_arm.html>)
- Practical setup guide (the layer/mask pitfall below): <https://supermatrix.studio/blog/camera-controller-and-spring-arm-3d-in-godot>

**Excluding the player (critical).** By default SpringArm3D checks collision on Layer 1. If the player is also on Layer 1, the arm instantly detects the player's own body as an obstacle and collapses to length 0, trapping the camera inside the character. Two fixes, use both:

1. Put the SpringArm's `collision_mask` on a dedicated "camera blockers" layer (level geometry only), not the player layer.
2. Call `spring_arm.add_excluded_object(player.get_rid())` at ready, so the player's `PhysicsBody3D` is explicitly skipped.

**Shape vs ray.** A bare ray can slip the camera through thin geometry or clip its near plane against a wall it passes beside. Assigning a `SphereShape3D` (or a small box) to `SpringArm3D.shape` sweeps a volume so the camera keeps a physical standoff from walls and never near-plane-clips. Cost: shape casts are heavier and can feel "sticky," snapping in hard when the sweep touches anything. There is an open Godot proposal to make the shape cast only engage once the ray already collides (best of both): <https://github.com/godotengine/godot-proposals/discussions/12091> and <https://github.com/godotengine/godot-proposals/issues/12098>.

**Recommendation for a kid game:** SphereShape3D of radius ~0.3–0.5 m with a `margin` of ~0.2 m. A "sticky" pull-in is *safer* for a 4-year-old than a clipped view — never show the inside of a wall. To hide the hard snap, smooth only the *spring length* on the way back out (fast pull-in, slow ease-out), which is what most shipped third-person cams do.

### A.2 Follow smoothing — lerp vs exponential/critically-damped

The most common beginner bug is frame-rate-dependent smoothing:

```gdscript
# WRONG: frame-rate dependent, overshoots at low FPS, jitters
pos = pos.lerp(target, follow_speed * delta)
```

`lerp(a, b, speed*delta)` does not compose correctly across variable frame times; at high delta the weight can exceed 1 and overshoot. This is a documented footgun (Godot issue #93115): <https://github.com/godotengine/godot/issues/93115>.

The correct frame-rate-independent form is **exponential decay** (a.k.a. exponential smoothing / a one-pole low-pass filter):

```gdscript
# RIGHT: frame-rate independent exponential smoothing.
# 'decay' is a rate constant; larger = snappier. ~6..12 feels good for a follow cam.
pos = pos.lerp(target, 1.0 - exp(-decay * delta))
```

Equivalently `1.0 - pow(smoothing, delta)` where `smoothing = exp(-decay)` (the form surfaced in Godot camera tutorials). Sources: Godot interpolation docs <https://docs.godotengine.org/en/stable/tutorials/math/interpolation.html>; kidscancode interpolated-camera recipe <https://kidscancode.org/godot_recipes/4.x/3d/interpolated_camera/index.html>.

For the *best* feel (no overshoot, tunable settle time, no wobble), use a **critically-damped spring** ("SmoothDamp"). It reaches the target quickly without oscillating and handles a moving target gracefully. Little Polygon's third-person breakdown recommends "a low-pass filter or critically-damped spring" on the tracking position: <https://blog.littlepolygon.com/posts/cameras/>. Critically damped means damping ratio = 1: no bounce, which matters for motion-sickness with a small child watching.

**Physics interpolation caveat (Godot 4.3+).** With `physics/common/physics_interpolation = true`, nodes are interpolated between physics ticks at render time. If the camera runs its follow in `_process()` while the player moves in `_physics_process()`, you can get jitter or *lose* your own smoothing. Fixes: run the follow logic where the target does, read the interpolated transform, and/or call `reset_physics_interpolation()` on hard camera cuts. See: <https://bugnet.io/blog/fix-godot-physics-interpolation-jitter-on-camera-follow> and forum thread <https://forum.godotengine.org/t/godot-4-3-no-camera-smoothing-when-new-physics-interpolation-is-on/78544>.

**Track the ground, not the jump.** Solar Ash's camera (via Little Polygon) projects the player's position onto the ground plane before using it as the tracking point, and smooths vertical motion heavily. Result: the camera does not lurch up and down every time a small player bounces. Strongly recommended here — a 4-year-old jumps constantly.

### A.3 Auto-yaw with no right stick

This is the crux of the hard constraint. Options, roughly in order of increasing "auto":

1. **Velocity-led yaw ("leash").** Slowly rotate the camera to sit behind the player's *horizontal velocity*. Little Polygon's concrete trick: take the vertical component of the cross-product of view-direction and player-velocity, scale it, and add it into yaw — this "simulates a leash." Heavily damped so it never whips. Source: <https://blog.littlepolygon.com/posts/cameras/>. Good default for open movement; the camera drifts behind you as you run, but never snaps.
2. **Look-ahead offset.** Push the tracking point ahead of the player along velocity so the child sees where they're going, not where they've been. Standard 2D-camera idea that ports to 3D; damp it so a stop doesn't yank the view. (Camera-logic reference: <https://www.gamedeveloper.com/design/camera-logic-in-a-2d-platformer>.)
3. **Designer camera hint volumes (the shipped-platformer answer).** Level designers place invisible trigger volumes/regions that *dictate* camera yaw/pitch/framing per area, with interpolated transitions between them. Donkey Kong Country pioneered per-region camera rules; Super Mario Odyssey uses invisible "hints" to pick a recommended angle so the player "worries more about platforming than controlling the camera." Sources: <https://gamedesignskills.com/game-design/platformer/>, <https://www.gamedeveloper.com/design/camera-logic-in-a-2d-platformer>. This is the single most reliable way to guarantee "the important thing is always framed" without a right stick.
4. **Full on-rails / spline camera.** The camera position and aim ride a designer-authored path; the player literally cannot desync it. Kirby and the Forgotten Land does this (Section A.5).

For a 4-year-old, **hint volumes + a gentle velocity leash** beats a purely velocity-driven free camera, because velocity-only cameras spin when a young child mashes the stick back and forth.

### A.4 Pitch when jumping / falling, and dead zones

- **Pitch bias with height/fall.** "Pretty normal platformer logic is to come in close when looking up and pull far out when looking down" (FOV/pitch note surfaced via <https://en.wikipedia.org/wiki/Field_of_view_in_video_games> discussion; and general platformer camera lore). Concretely: when the player is falling or over a gap, tilt the camera slightly *more top-down* and/or pull back so the landing surface and its blob shadow enter frame. Do not chase vertical position 1:1 — decouple pitch from the bounce.
- **Vertical dead zone.** Give the tracking point a vertical dead zone (a band the player can move within before the camera reacts) so routine jumps don't move the camera at all; only sustained height change (climbing, long falls) shifts pitch/height. This is the 2D "camera window" idea applied to the vertical axis.
- **Dead zones generally** keep a jittery small player from constantly nudging the camera. Combine a small screen-space dead zone on the tracking point with the exponential/critically-damped smoothing above.

### A.5 What shipped kid-friendly 3D platformers actually do

- **Kirby and the Forgotten Land (HAL/Nintendo)** — *automatic, level-designer-directed camera; no player camera control at all.* From Nintendo's "Ask the Developer": "the camera moves automatically. It always shifts to the optimal view for the actions you need to take, whether you're looking down at Kirby from above or seeing him from a specific side angle." Rationale, explicitly: "The player doesn't need to control the camera — the camera moves for you," so beginners aren't forced to manage camera and character on two sticks at once. Designers track the camera along a rail and fudge it to center enemies and the intended path rather than pinning Kirby dead-center. Sources: <https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-4-kirby-and-the-forgotten-land-part-2/>, developer-analysis piece <https://www.gamedeveloper.com/marketing/kirby-at-30>, review noting the largely fixed camera <https://www.nintendolife.com/reviews/nintendo-switch/kirby-and-the-forgotten-land>.
- **Astro Bot (Team Asobi)** — automatic, dynamic third-person camera that adjusts as you move; the accessibility layer lets you play with a *single* analog stick, moving camera control onto a button instead of the right stick. That is the exact "right stick never required" posture. Sources: accessibility review <https://access-ability.uk/2024/09/05/astro-bot-accessibility-review/>, <https://www.videogameschronicle.com/review/astro-bot/>, <https://en.wikipedia.org/wiki/Astro_Bot>.
- **Super Mario 3D World (Nintendo)** — largely fixed / constrained camera; levels are "more semi-3D than the totally open spaces" of other 3D Marios, so the camera rarely needs orbiting. Source: <https://www.thegamer.com/coop-platformers-similar-super-mario-3d-world/>.

**When a constrained/rail camera beats a free-orbit auto camera for young kids:** essentially always for the 3–5 age band. A rail/hint camera (a) guarantees the objective and the landing spot are framed, (b) removes the failure mode where the child hides the goal behind a wall or stares at the sky, (c) eliminates the two-stick cognitive load that HAL explicitly cited as the barrier for beginners, and (d) reduces motion sickness because camera motion is authored and smooth rather than reactive to a flailing stick. A free-orbit auto camera only wins when exploration/backtracking in open 3D space is core — which is not this game's floor.

---

## B. Co-op camera for two players (one screen)

Four shipped patterns, evaluated for a 4-year-old + parent specifically.

### B.1 Single shared camera + leash + warp-to-partner (Kirby FL style)

Both players share one camera; the camera anchors on the "lead" player and pans generously. If the second player falls behind and goes off-screen, they are **automatically scooped back into view inside a safe floating bubble** — no death, no penalty. In Kirby FL the camera focuses on Kirby (P1) and Bandana Waddle Dee (P2) is carried back on-screen in a bubble when left behind. Sources: <https://wikirby.com/wiki/Multiplayer>, <https://game8.co/games/Kirby-and-the-Forgotten-Land/archives/370930>, <https://gamerant.com/kirby-and-the-forgotten-land-bandana-waddle-dee-co-op-tips/>.

- **Pros for our pair:** zero split, zero "which half is mine" confusion, lowest motion-sickness, trivial to implement, and the bubble-warp *structurally solves* "where am I / I got left behind" — the single hardest co-op problem for a small child. The parent naturally becomes the anchor; the child can wander and is always rescued.
- **Cons:** the non-anchor player can be dragged; if the *child* is the anchor and mashes movement, the parent gets yanked. Mitigate by anchoring the camera on a *midpoint biased toward the parent*, or letting the anchor be dynamic (whoever is making forward progress).

### B.2 Dynamic zoom-to-fit midpoint camera (Super Mario 3D World style)

One camera frames the midpoint of both players and zooms out to keep both in frame, panning back "pretty generously." Players are leashed to one screen. Sources: <https://www.thegamer.com/coop-platformers-similar-super-mario-3d-world/>, <https://www.co-optimus.com/game/3009/nintendo-wii-u/super-mario-3d-world.html>.

- **Pros:** both players always visible, both feel equally present (no second-class P2), still single-screen so no split.
- **Cons:** when players separate, the zoom-out shrinks characters and can make a 4-year-old's own avatar tiny and hard to track; the constant zoom in/out is a mild motion-sickness and "my guy got small" readability cost. 3D World controls this by keeping levels *constrained* so players can't separate far — which pairs naturally with a hint-volume camera.

### B.3 Fixed split screen

Each player gets a permanent half (or quadrant). No leash, full independence.

- **Pros:** neither player can drag the other; each has a private, stable view.
- **Cons:** worst option for this pair. Halves the resolution and doubles the render cost; a 4-year-old struggles to know which half is theirs; loses the shared-space, "we're doing this together on one screen" feeling that is the entire point of parent+child couch play. Off-screen partner and "where am I" are *worse*, not better, because the child must map two viewports.

### B.4 Voronoi / dynamic split

Screen splits only when players separate, with the divider placed on the Voronoi line between them, and **merges back into one image** when they come close. Popularized by the LEGO games; first seen in Renegade Ops. Sources: technical tour <https://mattwoelk.github.io/voronoi_split_screen_notes/>, research paper "Voron_eye" <https://www.researchgate.net/publication/370285558>, and a ready-made Godot 4 implementation to crib from: <https://github.com/BenjaminNavarro/godot_dynamic_split_screen>. (There is also a raytraced single-image variant: <https://ph3at.github.io/posts/Ray-Coop-Camera/>.)

- **Pros:** independence when apart, togetherness when close; no one is dragged; no forced warp.
- **Cons:** the split *appearing and rotating* is exactly the kind of sudden view change that disorients young kids and can trigger motion sickness; the moving seam is cognitively heavy for a 4-year-old ("why did the screen break in half?"). Best when both players are competent; overkill and confusing for our pair.

### B.5 Off-screen rescue patterns (shipped)

- **Bubble/float auto-warp:** off-screen player is enclosed and floated back to the group with no death (Kirby FL bubble; New Super Mario Bros. bubble). Best-in-class for a child who wanders — cited above.
- **Screen-edge indicators:** an arrow/portrait at the screen edge points to an off-frame player. Useful as a *warning* before a warp triggers, but on its own it still demands the child navigate back, which they often can't.
- **Generous pan / leash-then-warp:** pan back as far as reasonable, then warp — the combination 3D World and Kirby use.

---

## C. Depth-perception aids for young kids in 3D

### C.1 Blob shadows beat realistic shadows for landing — and why

The consensus across platformer developers and academic work: for *judging where you will land*, a **blob shadow anchored directly under the character wins**, and realistic/shadow-mapped shadows actively hurt.

- A thesis specifically on shadows in 3D platformers concludes the "unrealistic but essential landing shadow" is important for gameplay: accurately judging depth/distance is critical, and the blob directly beneath the character lets players read their ground-relative position while airborne. Source (PDF): <https://www.diva-portal.org/smash/get/diva2:1441836/FULLTEXT01.pdf>.
- The failure mode of realistic shadows: when the sun is at an angle, the shadow lands *far* from the character (e.g. 10 m away while 10 m up), so aiming for a small platform, you overshoot. The blob is always the vertical drop line — the true landing point. (Same thesis; and CMU graphics lesson on shadows for gameplay <https://15466.courses.cs.cmu.edu/lesson/shadows>.)
- **Cheap and robust:** a blob is one downward raycast + a projected decal/quad; no shadow-map data structures. Techarthub's platformer drop-shadow guide walks the raycast-down-and-project approach: <https://techarthub.com/drop-shadow/>.
- **Hybrid trick shipped games use:** fade the blob *in* while airborne and fade the realistic shadow *out*, so you never show both at once and the landing cue is unambiguous during the jump. (Thesis; also the general practice discussed in the CMU lesson.)

**Implication for us:** always-on blob is correct. Make it a downcast decal that (a) tracks the exact ground point below the character, (b) *scales/darkens as the character nears the ground* (contact cue), and (c) is drawn on top of terrain so it's never lost in a dark area.

### C.2 Landing rings / target reticles projected on the ground

Extend the blob into an explicit **landing predictor**: project a ring/reticle at the point the character's ballistic arc will actually intersect the ground (or a platform), not just straight down. This tells a 4-year-old *"you will land here"* before they commit. This is the same family of aid as Kirby's "Fuzzy Landing" assist described below and as aim-assist landing markers in many action games. (Design rationale: same landing-judgment need identified in the shadows thesis, extended to predicted position.)

Spec suggestions: draw both the straight-down blob (where I am now) and a distinct predicted-landing ring (where I'm going); color/pulse the ring green when it's over safe ground and neutral/absent over a gap, so safety is legible pre-jump without text.

### C.3 Generosity mechanics: coyote time and "fuzzy" landings

Young children mistime jumps constantly; the fix shipped platformers use is to *lie in the player's favor*:

- **Coyote time:** allow the jump for a few frames *after* walking off a ledge. Celeste uses 5 frames. Sources: <https://www.thealmightyguru.com/Wiki/index.php?title=Coyote_time>, Godot recipe <https://kidscancode.org/godot_recipes/4.x/2d/coyote_time/index.html>. Use a *generous* window here (larger than Celeste's — this is a 4-year-old, not a speedrunner).
- **Kirby's "Fuzzy Landing":** HAL explicitly added tech that "allows players to jump again even if they misjudge landing distance," plus attack aiming tuned so "if it looks like an attack should hit on-screen, we made sure it does connect," and fluorescent-tape map decorations to make height differences legible. Source: <https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-4-kirby-and-the-forgotten-land-part-2/>. This is the gold standard for "generous to the point of forgiving" and should be copied directly.
- Pair with **jump buffering** (register a jump pressed slightly before landing) for the same forgiveness on the takeoff side.

### C.4 Camera pitch, contrast, and FOV for readable depth

- **Pitch toward top-down-ish for landing legibility.** A higher, more downward camera angle makes the ground plane and the gap between platforms directly readable, versus a low chase-cam where platforms occlude each other and depth collapses. Shipped kid platformers lean high/angled (Kirby drops to near top-down over platforming sections; 3D World uses an elevated angled view). This is engineering consensus rather than a single citation; the Kirby developer note about "looking down at Kirby from above ... for the actions you need to take" supports it: <https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-4-kirby-and-the-forgotten-land-part-2/>.
- **Contrast rims / silhouette.** Keep characters high-contrast against the ground (rim light or a bright outline) so a young child never loses their avatar — this is why the zoom-out cost in B.2 matters, and why the always-on blob doubles as a "find my guy" anchor.
- **FOV.** Console third-person games typically sit ~50–70° vertical-ish; wider FOV increases apparent speed and edge distortion (motion-sickness risk), narrower FOV flattens depth. Source on ranges: <https://en.wikipedia.org/wiki/Field_of_view_in_video_games>. A moderate FOV keeps depth readable without the "rushing" feeling that unsettles small kids.

### C.5 Research on children, depth perception, and 3D games

Direct, controlled studies on *preschoolers* judging depth in 3D platformers are scarce (see UNVERIFIED). What exists:

- Playing genuinely stereoscopic (not flat) 3D games measurably improves *stereoacuity* (precision of depth perception), though not accuracy or contrast sensitivity. Sources: <https://www.nature.com/articles/s41598-024-82194-0>, Berkeley summary <https://vision.berkeley.edu/posts/playing-3d-video-games-boosts-stereo-vision>, PubMed <https://pubmed.ncbi.nlm.nih.gov/38834021/>. Most cohorts are older children/young adults, not preschoolers — so this supports "3D is developmentally fine and even beneficial," not a specific difficulty tuning.
- Preschool visual-spatial skill is trainable and matters for later reasoning; short bouts of spatial *language during play* boost mental-rotation skill. Practical relevance: narrate space ("jump over here," "the shadow shows where you'll land"). Source: <https://hes-extraordinary.com/spatial-awareness>.

The load-bearing point: the literature says nothing contradicts a 3D game for a 4-year-old, but nothing gives us a numeric difficulty curve either — so the readability aids (blob, ring, generosity, framed camera) are how we *manufacture* the accessibility that studies don't hand us.

---

## Recommendations for soft_landing

### Recommended auto-camera architecture

A **hint-volume-directed camera on a SpringArm3D, with a damped velocity leash as the fallback framing**, and **zero required right-stick input** (an optional recenter/nudge button at most — never a stick dependency). Concretely:

1. **Rig:** `Player → CameraPivot (yaw) → CameraArm (SpringArm3D, pitch) → Camera3D`. SpringArm uses a `SphereShape3D` (r≈0.4 m, margin≈0.2 m), `collision_mask` on a level-geometry-only layer, and `add_excluded_object(player.get_rid())`.
2. **Tracking point:** the player's position *projected onto the ground plane* (Solar Ash trick), inside a vertical dead-zone band, so bounces don't move the camera.
3. **Smoothing:** critically-damped spring (or `pos.lerp(target, 1 - exp(-decay*delta))`, decay≈8) on position; pull the spring arm *in* fast, ease it *out* slow. Run follow where the player moves and call `reset_physics_interpolation()` on hard cuts.
4. **Yaw:** default is set by the *nearest camera hint volume* (designer-authored per area), interpolated between volumes; where no volume is active, fall back to a heavily damped velocity leash (Little Polygon cross-product method). Never yaw fast enough to whip.
5. **Pitch:** hint-volume-driven, biased more top-down over platforming/gaps; auto-pull-back + tilt-down when the player is falling so the landing surface and its blob enter frame.
6. This mirrors what Kirby FL and Astro Bot ship, and satisfies the hard constraint by construction: the stick is never read for camera.

### Recommended co-op camera strategy (pick one)

**Single shared camera + generous leash + bubble auto-warp (B.1, the Kirby FL model), with the anchor biased toward the parent.** Justification for a 4-year-old + parent on one couch:

- It is the *only* option that structurally erases "where am I / I got left behind": the child physically cannot get lost — they're floated back in a safe bubble. No screen split to parse, no viewport mapping, lowest motion-sickness.
- Biasing the anchor toward the parent (or making it dynamic toward whoever is progressing) stops the child from yanking the parent's view while still letting the child roam.
- It keeps the "we're playing together in one shared world" feeling that is the whole reason a parent plays with a preschooler.
- Reject fixed split (halves resolution, doubles confusion), Voronoi (the appearing/rotating seam disorients young kids), and pure zoom-to-fit (shrinks the child's own avatar when they separate — though keep 3D World's generous pan-back as a component *before* the bubble triggers).

### Readability kit (always on)

- **Blob shadow:** downcast-raycast decal pinned to the exact ground point under each character; drawn over terrain (never lost in shadow); **darkens and tightens as the character nears the ground** as a contact cue; fade in on takeoff.
- **Landing ring:** a second, distinct ground reticle at the *predicted* ballistic landing point (not straight-down). Green/solid when over safe ground, absent/neutral over a gap — safety readable pre-jump, no text.
- **Generosity:** generous coyote time (larger than Celeste's 5 frames), jump buffering, and a "fuzzy landing" re-jump grace when a landing is just barely missed (copy Kirby directly).
- **Framing:** elevated, angled-toward-top-down pitch over platforming; moderate FOV (~55–65°) to keep depth readable without a motion-sickness "rush"; high-contrast character rim so the avatar is never lost.

---

## UNVERIFIED

Claims below are plausible and partly supported but I could not verify them from a primary source in this run; treat as design hypotheses to validate.

- **Exact numeric tunings** (SpringArm radius 0.4 m / margin 0.2 m, smoothing decay ≈ 8, FOV 55–65°, "coyote larger than 5 frames") are my engineering judgment, not values pulled from a cited study. Playtest and tune.
- **The diva-portal shadows thesis' specific results** are summarized from search snippets and secondary discussion; the source PDF did not text-extract in this run, so any implied quantitative player-test result (e.g. "X% better landing accuracy with blob shadows") is UNVERIFIED — the *qualitative* conclusion (blob beats realistic for landing) is well-corroborated across multiple sources.
- **GameAIPro "Tips and Tricks for a Robust Third-Person Camera System" (Chapter 47)** was located (<https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter47_Tips_and_Tricks_for_a_Robust_Third-Person_Camera_System.pdf>) but its PDF did not text-extract here; its specific damping/spring recommendations are not directly quoted.
- **"45–60° is the optimal camera pitch for preschool depth reading"** — no controlled study found; higher/top-down framing is inferred from shipped-game practice and the Kirby developer note, not measured on children.
- **Preschooler-specific 3D-platformer difficulty research** appears not to exist as a controlled literature; the cited depth-perception studies use older cohorts. The recommendation to lean on readability aids rather than a research-derived difficulty curve follows from that gap.
- **The Little Polygon "leash = vertical component of cross(view-dir, velocity)" formula** is reported from the article summary; verify the exact vector construction against the source before implementing.
- **Astro Bot's "single-stick, camera-on-a-button" mode** is confirmed as an accessibility option by multiple reviews, but whether it fully removes camera-stick dependence in *all* levels (vs most) is not confirmed.

### Source index (primary/most load-bearing)

- Godot SpringArm3D class: <https://docs.godotengine.org/en/stable/classes/class_springarm3d.html>
- Godot spring-arm tutorial: <https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html>
- Godot interpolation docs: <https://docs.godotengine.org/en/stable/tutorials/math/interpolation.html>
- Godot lerp-with-delta footgun (#93115): <https://github.com/godotengine/godot/issues/93115>
- Physics-interpolation camera jitter fix: <https://bugnet.io/blog/fix-godot-physics-interpolation-jitter-on-camera-follow>
- Little Polygon, third-person cameras: <https://blog.littlepolygon.com/posts/cameras/>
- Kirby FL — Nintendo Ask the Developer (camera + Fuzzy Landing): <https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-4-kirby-and-the-forgotten-land-part-2/>
- Kirby at 30 (camera-on-rails analysis): <https://www.gamedeveloper.com/marketing/kirby-at-30>
- Astro Bot accessibility (single-stick): <https://access-ability.uk/2024/09/05/astro-bot-accessibility-review/>
- Super Mario 3D World co-op camera: <https://www.thegamer.com/coop-platformers-similar-super-mario-3d-world/>
- Kirby FL co-op bubble rescue: <https://wikirby.com/wiki/Multiplayer>
- Voronoi split — technical tour: <https://mattwoelk.github.io/voronoi_split_screen_notes/>
- Godot dynamic split-screen implementation: <https://github.com/BenjaminNavarro/godot_dynamic_split_screen>
- Shadows in 3D platformer games (thesis PDF): <https://www.diva-portal.org/smash/get/diva2:1441836/FULLTEXT01.pdf>
- Platformer drop-shadow (raycast/decal how-to): <https://techarthub.com/drop-shadow/>
- Coyote time reference: <https://www.thealmightyguru.com/Wiki/index.php?title=Coyote_time>
- Stereoscopic 3D games & depth perception: <https://www.nature.com/articles/s41598-024-82194-0>
- Field of view in video games: <https://en.wikipedia.org/wiki/Field_of_view_in_video_games>
