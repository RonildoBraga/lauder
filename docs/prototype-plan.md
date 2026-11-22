# Lauder — first playable prototype

**Updated:** 22 November 2026\
**Status:** The first playable is complete. The game opens on a greybox Brooklyn Bridge ([ADR 0004](decisions/0004-brooklyn-bridge-opening.md)), and the whole opening is built, its formations included, with squad orders ([ADR 0003](decisions/0003-squad-movement.md)'s phase S3) on it. On the baseline iPhone it held 60 fps through the whole walk and passed its phone checkpoint on build 0.1.0 (11); Xbox hardware and walk cadence remain unchecked. On 21 November 2026 the maintainer judged the opening worth building on: “Yes, build on it”. The combat design review settled a [first squad combat experiment](decisions/0005-squad-combat-experiment.md), which the maintainer assigned the same day, “Yes, build it”, and it is built in a greybox combat yard. After its first session, “Everything worked as expected”, the maintainer chose cover next, “Yes, try cover next”, and the yard's companions now take cover near their places. Asked how that played on build 0.1.0 (13), the maintainer answered “Worked well”, and then chose to finish S4 there, “Yes, finish S4”: the yard now has all of ADR 0003's combat positioning. Asked how that played on build 0.1.0 (15), the maintainer answered “Worked well”: the experiment has had its three sessions. Next, the maintainer chose salvage and exploration, and the [salvage and exploration review](#salvage-and-exploration-review) settled a first experiment, which the maintainer assigned, “Yes, build it”; it is built in a greybox salvage yard, and on build 0.1.0 (16), asked how it played, the maintainer answered “Yes it went well”. For the second session each run deals the cabinets' contents afresh. Asked to play build 0.1.0 (17) in the Simulator instead, Claude found the rules sound but the yard unclear from the camera, and the maintainer chose to fix that, “Yes, do both”: the yard now shows its gate, latch, panel and transmitter, and what the party knows of each cabinet. On build 0.1.0 (18), asked how it played, the maintainer answered “It reads well”. The maintainer then asked for a better shooting system, which [ADR 0007](decisions/0007-aiming-and-shot-feedback.md) records and builds: right-stick aim on a controller, shots that strike the scenery, shot effects, and a closer lens in a fight. The [later hardening](#later-hardening-after-the-loop-is-worth-keeping) needs its own assignment.\
**Technical direction:** Swift + RealityKit, iOS 27, iPhone first.\
**Architecture:** [Architecture and platform decision](architecture.md)

The [story bible](story/story-bible.md) supplies the ensemble direction; the [gameplay walkthrough](gameplay-script.md) describes the opening as built and planned. Their dialogue, exact relationships and enhancement histories remain proposals.

## Purpose and scope

The first playable is the Brooklyn Bridge opening. Miki crosses alone and meets Tom and Laura as strangers, through a first fight, an ambush and a rescue; then the three travel on together. It should show that the party's movement and switching, a light fight and short scripted scenes work together on the phone, and whether the opening is worth building on.

The bridge starts as a greybox with simple coloured stand-ins. It moves in small steps to the frozen low-poly [visual direction](visual-direction.md), which the maintainer chose on 20 November 2026, reusing what exists where it serves. No animation production is required. Identify characters and interactions with text as well as colour. Duration should come from playtesting.

| Element | First playable |
|---|---|
| Party | Miki alone at first; Tom joins after the ambush and Laura at mid-span. One active character, computer-controlled companions, one elevated follow camera |
| Fights | Assisted aim, line of sight and cover, a placeholder hit rule (three hits, then a retry) and one ammunition count |
| Scenes | Short scripted beats that play the same way every time |
| Inventory | One small shared inventory: rounds and medical kits |
| Interface | Active-character label, objective, contextual action, the fight's HUD, dialogue, Pause/Resume and Restart |
| Run | In-memory progress; a fresh launch or Restart begins a new run |

Nina-specific dialogue is excluded while kinship remains undecided. The full chapter's later scenes, further encounters and detailed revelations are outside this slice.

## The opening

[ADR 0004](decisions/0004-brooklyn-bridge-opening.md) builds the opening in five milestones, each its own assignment, checked with `./scripts/check`, Simulator playtests and a maintainer playtest:

| Milestone | Adds | State |
|---|---|---|
| **M1** The bridge, Miki alone | Levels as values, the bridge greybox, a party of one, trigger areas, Restart | Built |
| **M2** The first fight | Fire, assisted aim, line of sight, hits, the stranger, the retry | Built |
| **M3** Search, ambush, Tom | Searching and loot, the ambush, Tom's shot, recruitment, following with one companion | Built |
| **M4** Laura and onwards | Helping, the medical kit, the third member, the end of the opening | Built |
| **M5** Formations | [ADR 0003](decisions/0003-squad-movement.md)'s phase S2 on the open deck | Built |

Levels and models come from Blender ([ADR 0002](decisions/0002-blender-source-of-truth.md)), as [Editing a level in Blender](../CONTRIBUTING.md#editing-a-level-in-blender) describes.

## Input and interaction contract

| Intent | PS5 / Xbox | Touch | Keyboard |
|---|---|---|---|
| Move active character | Left stick | Bottom-left analog stick | WASD |
| Contextual action, advance text or confirm the pause menu's choice | Cross / A | Look, showing the action where there is one, Continue in a conversation and Restart while paused | E |
| Cycle leader, once there are two | R1 / RB | Next: name | Q |
| Lead as the previous member, wherever Next is | L1 / LB | None: Next cycles | Z |
| Change formation, once there are two companions; after an order, call everyone back; in a fight in the combat yard, regroup ([ADR 0005](decisions/0005-squad-combat-experiment.md#after-the-second-session)) | Triangle / Y | Formation, Follow after an order, or Regroup in a yard fight | R |
| Order companions, once there are two: both go, the one on that side goes, or both hold | D-pad up, left or right, down | Press and hold on the ground, then Both, a name or Hold | Arrow keys |
| Fire the current leader's weapon along their facing or at the assisted target once they face it: press to draw, hold to keep firing at its pace; free outside a fight, automatic reload ([ADR 0007](decisions/0007-aiming-and-shot-feedback.md), [ADR 0010](decisions/0010-squad-weapons.md)) | R2 / RT | Fire, with any leader | F |
| Aim the current leader's weapon apart from movement, which also draws it ([ADR 0007](decisions/0007-aiming-and-shot-feedback.md), [ADR 0010](decisions/0010-squad-weapons.md)) | Right stick | None: assisted aim | I, K, J, L |
| The leader's signature: Miki's Disrupt, in the combat yard ([ADR 0005](decisions/0005-squad-combat-experiment.md)) | Square / X | Signature, during a yard fight while Miki leads | X |
| Pause / Resume | Options / Menu | Pause / Resume | Escape |
| Choose Resume, Restart, the next venue (Combat test → Salvage test → Relay mission → Bridge), or Vibration in the pause menu | Left stick or D-pad, up or down | Resume, Look reading Restart, a button beside Resume naming the next level, and a Vibration button beside it | W / S or the up and down arrow keys |
| Hide or show the status panel | Circle / B | None: the panel always shows with touch controls | H |

Xbox RB, LB, RT and X use the same input path as PS5, but hardware delivery remains unverified. [Touch controls](touch-controls.md) are automatic without an extended controller; a connected controller is preferred unless **Use touch controls** is chosen, and **Use controller** returns to it. This in-memory selection changes the input source, not gameplay rules.

- Switching, changing formation, orders and the signature are available only while exploring. Pause and dialogue ignore their presses rather than queueing them.
- A switch changes leadership and eases the camera target to the new leader over a short transition, preserving every character's world position and all party progress. It does not teleport the party.
- Held movement may continue on the new leader, including a stick touch held alongside **Next: name**. Switching alone does not close the neutral-input gate. Source changes cancel old captures and require neutral input. After Pause, interruption or reconnection, all keys, buttons and fingers must release; a centred-stick finger still counts as held input.
- Consume a switch, formation or order edge before a signature or action edge from the same input sample, discarding them, and a signature edge before an action edge. Next wins over Previous pressed with it. A held action or signature must be released and pressed again before it acts.
- Prompts describe what the leader can do from an accessible approach. On press, revalidate the leader, the approach and the current progress; a stale prompt cannot act through a wall.

| Interaction | Who | Result |
|---|---|---|
| Search | Whoever leads, at the downed stranger | Takes his rounds and medical kit once, and begins the ambush |
| Help | Whoever leads, beside Laura | Uses the medical kit; she can stand and joins |

## Verification and performance

Use [Simulator and the standard checks](../CONTRIBUTING.md#validation) for everyday iteration. Each change adds focused Swift Testing cases with its implementation, and [scripted playtests](../CONTRIBUTING.md#scripted-simulator-playtests) run through the real controls. Pure rule tests alone cannot establish spatial behaviour or feel.

After first deferring deployment for Simulator iteration on 22 November 2026, the maintainer requested and received TestFlight build **0.1.0 (20)** using API-key authentication, then confirmed that it worked. The later continuous assignment in [ADR 0011](decisions/0011-companion-combat.md) authorised finishing combat phases 4 and 5, testing in Simulator, integrating reviewed work and delivering through TestFlight without repeated milestone prompts. All five combat phases are now implemented, reviewed and merged. They first reached TestFlight together in **0.1.0 (21)**, source `cec1a33`, including the squad weapons and phases 4 and 5.

That source passed `./scripts/check`: Blender tests, generated sounds, strict Swift formatting, the app build and Swift Testing, including all **13 headless scenarios**. Six rendered Simulator routes passed: `combat-yard` (102/102 steps), `leader-cover` (74/74), `tactical-enemies` (44/44), `squad-weapons` (60/60), `salvage-yard` (95/95) and `first-fight` (23/23). Automatic Codex review completed on the identical source tree with no findings. A fresh signed Release archive was verified for Lauder's bundle, version/build, signing team and matching dSYM. API-authenticated upload completed, and Apple's read-only verification confirmed upload **COMPLETE**, processing **VALID**, internal state **IN_BETA_TESTING** and availability to the existing internal TestFlight group, with tester membership unchanged. The archive, symbols and full delivery evidence remain private.

The remaining level-switch implementation is merged in [PR #107](https://github.com/RonildoBraga/lauder/pull/107) and delivered as **0.1.0 (22)**, source `89f61c8`, the latest verified TestFlight build. It passed the full standard check, all thirteen headless scenarios, eight new cache/isolation tests, rendered `combat-yard` (102/102) and `salvage-yard` (95/95), and automatic/independent source review. Its fresh signed Release archive passed bundle, team, signature and matching-dSYM verification. API-authenticated upload completed; Apple confirmed **COMPLETE**, **VALID**, **IN_BETA_TESTING**, internal-only availability to the existing testers and unchanged membership.

Bounded immutable navigation reuse and a pristine scene template reduced return-to-bridge construction from a paired Debug Simulator baseline of **314.3 ms** (251.2 navigation, 59.2 scene) to **10.2 ms** in the combat route and **3.9 ms** in salvage. Repeat navigation measured 0.0 ms and scene cloning 0.2/0.0 ms. Full-route maxima were still **116.7/150.7 ms**, with means of 16.8/16.9 ms. These are repeat-construction improvements: first preparation and renderer costs remain, and the timings exclude some setup as described below. Physical-phone performance remains unverified.

Weapon-feel and cover phone checkpoints, the new weapons' touch and hardware feedback checks, and the salvage experiment's final maintainer judgement remain unverified in the [deferred checklist](#deferred-phone-and-playtest-checks), without pausing this assigned Simulator-based implementation and delivery sequence. Debug playtests record each world's construction stages to investigate the level-switch hitch; those timings cover the initializer body and exclude later renderer setup.

Physical checkpoints on the baseline **iPhone 13 Pro Max** establish touch and controller behaviour, combat feel, Pause/Resume and recovery, and measured frame pacing. The target remains **60 fps** on that phone during representative play. Record the build, conditions and actual results; adjust scope or budget if missed. For the current continuous combat assignment, these checks remain separate from the authorised Simulator-based integration and TestFlight deliveries. Simulator timing is not phone evidence, and Xbox controllers remain untested on hardware.

### Deferred phone and playtest checks

After build 21's delivery, the maintainer instructed: **“I will test later, please continue with the remaining items and close all git issues once you finish the implementation”.** Implementation issues close when their code and checks are complete, and review-only issues close as deferred with this checklist as their continuation point. Closure does not mark an unperformed check as passed, waive the phone evidence below or supply a maintainer judgement. All items below remain **unverified**. The level-switch implementation and Simulator results are recorded above; its physical validation remains here.

- [ ] **Weapon feel and hardware (#89/#93):** run the delivered build on the baseline phone with touch and PS5 controls; check all three leaders' Fire, reloads, sound and touch combinations, phone vibration, controller vibration and DualSense trigger resistance, recording any unsupported or non-working feedback. Answer [ADR 0008's judgement questions](decisions/0008-weapon-feel-and-combat-plan.md#how-it-is-judged), including aim readability, fair spread, enemy reactions and feedback feel, and whether the carbine needs clearer presentation. Xbox hardware remains an optional, unverified check.
- [ ] **Cover and lifecycle (#92):** record a maintainer cover session, checking low-cover exposure, tall-edge peeks, directional shields, affected controls, Pause/Resume and recovery with fresh neutral input on the phone.
- [ ] **Squad and encounters (#94/#95):** record the maintainer's answers to **“Do they fight like a squad?”** and **“Is each fight a readable puzzle?”** after playing the combat yard.
- [ ] **Salvage (#90):** play the salvage yard and answer **“Does switching leader follow the player's reading of the place, rather than a checklist?”**, **“Do Miki's inspection and the wrong model make the search satisfying rather than a chore?”** and **“Does the trip feel purposeful without any meters?”** Record those answers in [ADR 0006](decisions/0006-salvage-and-exploration-experiment.md), then decide what salvage work follows; the third session has not happened.
- [ ] **Phone performance (#89/#92/#95/#96):** measure representative combat-yard frame pacing against **60 fps**, and time a level switch in a Release build with Instruments. If a switch still holds a frame for more than about **100 ms**, adjust the work or transition and measure again. Salvage-yard frame pacing is an optional additional measurement.

For each result, record the actual build, phone, input source, conditions, measurement or observation and the exact question answered. Preserve failed or unsupported results as such; TestFlight availability and Simulator success do not answer this checklist.

Relay Run's route choice, meaningful switching, purposeful return and optional threat also need a later maintainer playtest. Its phone controls and performance remain unverified until that session; the implementation assignment continues with Simulator testing.

## Relay Run — a complete salvage journey

The maintainer answered **“Proceed with your recommendation”** to the continuous exploration-and-salvage mission. [ADR 0013](decisions/0013-relay-run.md) records the scope and implementation sequence; the [walkthrough](relay-run-walkthrough.md) describes what the player does. These are prepared and the implementation is under verification. This remains a standalone greybox, with provisional dialogue and story placement.

The party leaves a shelter to recover a regulator from a depot, then returns to repair its transmitter. A protected west detour avoids combat; a shorter marked route has one stationary guard. Existing gate alternatives, cabinet inspection, shuffled contents, the live supply and the shared bag remain. Optional guarded encounters detect any visible party member inside, wait for all members to leave before breaking contact, and retain salvage, ammunition and guard damage. Withdrawal cancels bursts while preserving magazines and reload timing. The completed repair gathers the trio and begins a short provisional exchange once.

The pause menu cycles **Combat test → Salvage test → Relay mission → Bridge**. The navigation cache now retains four geometry entries for these four venues, preserving warm returns to the bridge. No new patrol framework, signatures, art, crafting or persistence is included.

Verification covers both safe gate approaches with no firing or damage, knowledge-based return guidance, companion-triggered contact, whole-party retreat/re-entry, weapon readiness, completion, Pause and Restart. New `relay-run-safe` and `relay-run-retreat` scenarios join the standard headless checks and rendered Simulator routes. Reviewed integration and a verified TestFlight delivery follow; physical results are recorded separately in the deferred checklist.

## Later hardening, after the loop is worth keeping

Revise the [saving design](architecture.md#saving-and-interruption) before implementation. Preserve stable member identities, the story's progress and a safe group placement when reconstructing a run; do not serialise entity graphs. Use versioned snapshots, ordered atomic writes, restart invalidation and explicit failure handling. Test save round-trips, relaunch, completed progress and interrupted or restarted writes.

Then repeat full runs and restarts on the physical phone over roughly **15–20 minutes**. Inspect frame pacing, memory, thermals and accumulation of scene content, subscriptions or unfinished loads. Persistence and sustained thermal validation remain outside the first-playable exit gate.

## Outside the first playable

Free jumping and climbing, combat positioning outside the combat yard ([ADR 0003](decisions/0003-squad-movement.md)'s phase S4), separate character inventories, skill trees, multiplayer, health and hunger systems, crafting, branching dialogue, voice acting, cinematics, levels beyond the bridge, finished character art, checkpoint saves, persistent Continue, cloud services and App Store submission. The opening retains its placeholder hit rule and one ammunition count. The assigned later prototypes add [ADR 0007](decisions/0007-aiming-and-shot-feedback.md)'s aiming and effects, [ADR 0008](decisions/0008-weapon-feel-and-combat-plan.md)'s first phase of weapon feel, [ADR 0009](decisions/0009-leader-cover.md)'s combat-yard cover, and [ADR 0010](decisions/0010-squad-weapons.md)'s three weapons. Their per-character magazines are readiness gates within the shared ammunition total, not separate inventories. Phases 4 and 5 are assigned combat-yard experiments in [ADR 0011](decisions/0011-companion-combat.md) and [ADR 0012](decisions/0012-tactical-enemies.md), not an expansion of the opening or onward story. Further scope changes need a concrete gameplay need and assignment.

## Combat design review gate

Combat stays occasional; exploration and salvage lead. The longer-term goal is a companion movement system in which the characters **behave like a coordinated squad of soldiers rather than just following the player**: squad formations cycled by one button, directional commands to position squad members, companions that keep formation, avoid obstacles and react to their surroundings, and coordinated use of weapons and abilities in encounters. Mobile controls should stay simple while offering meaningful tactical depth.

The characters' [combat identities](story/story-bible.md#combat-identities), the [future squad behaviour](gameplay-script.md#future-squad-and-combat-design) and [The Quiet Yard](encounters/the-quiet-yard.md) record the working design. [ADR 0003](decisions/0003-squad-movement.md) sets out the navigation, formations, orders and phases S1 to S4, of which S1 to S3 are built and S4 is built in the combat yard, and [ADR 0004](decisions/0004-brooklyn-bridge-opening.md) settles the opening's fights.

Formation or combat implementation beyond the opening needs an explicit assignment for a bounded greybox experiment. The current remaining combat assignment is recorded in [ADR 0011](decisions/0011-companion-combat.md), with phase 5's scope in [ADR 0012](decisions/0012-tactical-enemies.md); it authorises this sequence without another approval at each milestone. Its tunable prototype defaults are implementer choices under that instruction. A reviewer recommendation or a clean review alone does not assign additional work outside it.

On 21 November 2026 the maintainer settled the choices for a first experiment, which [ADR 0005](decisions/0005-squad-combat-experiment.md) records:
- a test yard outside the story;
- companions firing by themselves from their slots and order points;
- a third hit on anyone falling the party back while enemies keep their damage;
- Miki's Disrupt as the only signature.

The maintainer assigned it on 21 November 2026: “Yes, build it”. It is built in a greybox combat yard that the pause menu's **Combat test** opens, and its playtests decide what comes next. After the first session the maintainer reported “Everything worked as expected” and chose cover next, “Yes, try cover next”, so the yard's companions now take cover near their places, as ADR 0005 records [after the first session](decisions/0005-squad-combat-experiment.md#after-the-first-session). On build 0.1.0 (13) that “Worked well”, and the maintainer chose to finish S4 in the yard, “Yes, finish S4”, as ADR 0005 records [after the second session](decisions/0005-squad-combat-experiment.md#after-the-second-session). On build 0.1.0 (15) that “Worked well”, the last of the experiment's three sessions.

After ADR 0007's shooting, the maintainer asked on 21 November 2026 to take combat further, with The Division 2 as the reference, and to see research, a comparison and a phased plan first. [ADR 0008](decisions/0008-weapon-feel-and-combat-plan.md) records the plan's five phases: the shot, cover for the leader, the squad's weapons, companion combat and enemies that fight back. On 22 November 2026 the maintainer chose to begin, “Start Phase 1”. Its first phase is built: no aim line, a pose that shows the aim, spread, enemies that flinch and fall, sound and vibration. Each later phase gets its own record when it begins.

The maintainer then assigned phase 2 after the automatic-cover recommendation: “Proceed and let me know if you need anything from me”. [ADR 0009](decisions/0009-leader-cover.md) records automatic proximity cover, initially a shield only for the active character, and 0.3 seconds of exposure after firing. This combat-yard prototype is built and passes the standard check and the rendered `leader-cover` and combat-yard routes. Focused tests cover the rules, lifecycle and shield direction/clearance. Moving near a block takes cover without another button; a low block allows firing above it, and a tall wall allows a clear peek near its edge. The bridge and salvage retain their earlier cover rules; phase 4 extends the yard's rule to companions. Physical cover and performance checks remain unverified.

After build 20's delivery, the maintainer's instruction to continue with Simulator testing assigned phase 3, [ADR 0010](decisions/0010-squad-weapons.md). It is built: Miki fires the precision carbine, Laura a three-shot burst weapon, and Tom a close scatter shot dealing two hits. Every recruited character can fire as leader using the existing controls. Each owns magazine, reload, cooldown and spread state across leader and companion roles; switching cancels queued burst shots without refilling or resetting timing. Automatic reloads need no button, freeze on Pause and consume no ammunition. Only actual leader shots during encounters reduce the one shared total; companion fire and practice remain free. Companions now use seeded spread and can miss. Weapon props, poses, sound and player haptic/trigger settings follow the weapon kind.

Phase 3 passed the standard check, its 12 headless scenarios and the rendered `squad-weapons`, `combat-yard`, `leader-cover` and `ambush` routes; an unsigned Release Simulator build also passed. The starting capacities, reload times and handling values in ADR 0010 are Codex's tunable implementation defaults, not additional quoted maintainer decisions. Hardware feedback, new touch combinations and baseline-phone performance remain unverified for that phase.

The subsequent continuous assignment covers phase 4's shared party cover, directional shields, focus fire and replanning when a flank makes cover unsafe ([ADR 0011](decisions/0011-companion-combat.md)), followed by phase 5's cover-seeking shooter, bounded flanker and warned grenade thrower ([ADR 0012](decisions/0012-tactical-enemies.md)). Companions leave an active grenade's marked ground without losing their orders. These behaviours add no control button, health system or story encounter. **The combined implementation is complete and delivered in TestFlight 0.1.0 (21).** The [verification record](#verification-and-performance) distinguishes completed checks and Apple availability from unverified physical results and the later maintainer judgement of combat feel.

## Salvage and exploration review

The maintainer's goals put exploration and salvage first. The story bible gives each member a part in them: Miki's inspection and careful salvage, Laura's reading of a route, and Tom's handling of a load. Its [Relay House scene](story/story-bible.md#later-scene--relay-house) is a worked salvage trip.

On 21 November 2026, after the combat experiment's three sessions, the maintainer chose salvage and exploration as the next track and settled the choices for a first experiment, which [ADR 0006](decisions/0006-salvage-and-exploration-experiment.md) records:
- a test yard outside the story;
- a part for a repair as the salvage's purpose;
- alternative approaches, so that no step needs one particular member and each member makes some step better;
- the shared bag only, with no weight.

The maintainer assigned it the same day, with its defaults: “Yes, build it”. It is built in a greybox salvage yard, which the pause menu's third choice reaches from the combat yard. After its first session, on build 0.1.0 (16), the maintainer reported: “Yes it went well”, and chose to shuffle the cabinets next, “Shuffle the cabinets (Recommended)”, so each run now deals their contents afresh for the second session. After Claude played build 0.1.0 (17) in the Simulator at the maintainer's request, the maintainer chose to fix what it found unclear from the camera, “Yes, do both”, as [ADR 0006](decisions/0006-salvage-and-exploration-experiment.md#after-claudes-simulator-playtest) records. On build 0.1.0 (18) the maintainer found that it “reads well”, the experiment's second session, and chose to give the last session to its other questions, “The other questions”.
