# Lauder — first playable prototype

**Updated:** 21 November 2026\
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
| Fire, the way the leader faces or at the assisted target once she faces it, or straight ahead, within the weapon's spread: press to draw, hold to keep firing; free outside a fight ([ADR 0007](decisions/0007-aiming-and-shot-feedback.md), [ADR 0008](decisions/0008-weapon-feel-and-combat-plan.md)) | R2 / RT | Fire, while Miki leads | F |
| Aim Miki's carbine apart from movement, which also draws it ([ADR 0007](decisions/0007-aiming-and-shot-feedback.md)) | Right stick | None: assisted aim | I, K, J, L |
| The leader's signature: Miki's Disrupt, in the combat yard ([ADR 0005](decisions/0005-squad-combat-experiment.md)) | Square / X | Signature, during a yard fight while Miki leads | X |
| Pause / Resume | Options / Menu | Pause / Resume | Escape |
| Choose Resume, Restart, while the experiments last the next level in a cycle, or Vibration, in the pause menu: Combat test on the bridge, Salvage test in the combat yard, Bridge in the salvage yard | Left stick or D-pad, up or down | Resume, Look reading Restart, a button beside Resume naming the next level, and a Vibration button below | W / S or the up and down arrow keys |
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

Milestones that change controls, feel or performance get a phone checkpoint on the baseline **iPhone 13 Pro Max**: controls with touch and a controller, combat feel, Pause/Resume and recovery, and measured frame pacing. The target is **60 fps** on that phone, measured during representative play. Record the build, conditions and results; adjust scope or budget if missed. Simulator timing is not phone evidence, and Xbox controllers remain untested on hardware.

## Later hardening, after the loop is worth keeping

Revise the [saving design](architecture.md#saving-and-interruption) before implementation. Preserve stable member identities, the story's progress and a safe group placement when reconstructing a run; do not serialise entity graphs. Use versioned snapshots, ordered atomic writes, restart invalidation and explicit failure handling. Test save round-trips, relaunch, completed progress and interrupted or restarted writes.

Then repeat full runs and restarts on the physical phone over roughly **15–20 minutes**. Inspect frame pacing, memory, thermals and accumulation of scene content, subscriptions or unfinished loads. Persistence and sustained thermal validation remain outside the first-playable exit gate.

## Outside the first playable

Free jumping and climbing, combat positioning outside the combat yard ([ADR 0003](decisions/0003-squad-movement.md)'s phase S4), separate character inventories, skill trees, multiplayer, health and hunger systems, crafting, branching dialogue, voice acting, cinematics, levels beyond the bridge, finished character art, checkpoint saves, persistent Continue, cloud services and App Store submission. Combat is limited to what ADR 0004 brings into the opening, assisted aim, a placeholder hit rule and one ammunition count, with [ADR 0007](decisions/0007-aiming-and-shot-feedback.md)'s right-stick aim, shots that strike the scenery and their effects, and the first phase of [ADR 0008](decisions/0008-weapon-feel-and-combat-plan.md): a pose in place of the aim line, spread, enemies' reactions, sound and vibration. Expand only in response to a concrete playtest need.

## Combat design review gate

Combat stays occasional; exploration and salvage lead. The longer-term goal is a companion movement system in which the characters **behave like a coordinated squad of soldiers rather than just following the player**: squad formations cycled by one button, directional commands to position squad members, companions that keep formation, avoid obstacles and react to their surroundings, and coordinated use of weapons and abilities in encounters. Mobile controls should stay simple while offering meaningful tactical depth.

The characters' [combat identities](story/story-bible.md#combat-identities), the [future squad behaviour](gameplay-script.md#future-squad-and-combat-design) and [The Quiet Yard](encounters/the-quiet-yard.md) record the working design. [ADR 0003](decisions/0003-squad-movement.md) sets out the navigation, formations, orders and phases S1 to S4, of which S1 to S3 are built and S4 is built in the combat yard, and [ADR 0004](decisions/0004-brooklyn-bridge-opening.md) settles the opening's fights.

Before any formation or combat implementation beyond the opening, settle the open design choices with the maintainer and obtain an explicit assignment for a bounded greybox experiment. A reviewer recommendation or a clean review alone is not an implementation assignment.

On 21 November 2026 the maintainer settled the choices for a first experiment, which [ADR 0005](decisions/0005-squad-combat-experiment.md) records:
- a test yard outside the story;
- companions firing by themselves from their slots and order points;
- a third hit on anyone falling the party back while enemies keep their damage;
- Miki's Disrupt as the only signature.

The maintainer assigned it on 21 November 2026: “Yes, build it”. It is built in a greybox combat yard that the pause menu's **Combat test** opens, and its playtests decide what comes next. After the first session the maintainer reported “Everything worked as expected” and chose cover next, “Yes, try cover next”, so the yard's companions now take cover near their places, as ADR 0005 records [after the first session](decisions/0005-squad-combat-experiment.md#after-the-first-session). On build 0.1.0 (13) that “Worked well”, and the maintainer chose to finish S4 in the yard, “Yes, finish S4”, as ADR 0005 records [after the second session](decisions/0005-squad-combat-experiment.md#after-the-second-session). On build 0.1.0 (15) that “Worked well”, the last of the experiment's three sessions.

After ADR 0007's shooting, the maintainer asked on 21 November 2026 to take combat further, with The Division 2 as the reference, and to see research, a comparison and a phased plan first. [ADR 0008](decisions/0008-weapon-feel-and-combat-plan.md) records the plan's five phases: the shot, cover for the leader, the squad's weapons, companion combat and enemies that fight back. On 22 November 2026 the maintainer chose to begin, “Start Phase 1”. Its first phase is built: no aim line, a pose that shows the aim, spread, enemies that flinch and fall, sound and vibration. Each later phase gets its own record when it begins.

## Salvage and exploration review

The maintainer's goals put exploration and salvage first. The story bible gives each member a part in them: Miki's inspection and careful salvage, Laura's reading of a route, and Tom's handling of a load. Its [Relay House scene](story/story-bible.md#later-scene--relay-house) is a worked salvage trip.

On 21 November 2026, after the combat experiment's three sessions, the maintainer chose salvage and exploration as the next track and settled the choices for a first experiment, which [ADR 0006](decisions/0006-salvage-and-exploration-experiment.md) records:
- a test yard outside the story;
- a part for a repair as the salvage's purpose;
- alternative approaches, so that no step needs one particular member and each member makes some step better;
- the shared bag only, with no weight.

The maintainer assigned it the same day, with its defaults: “Yes, build it”. It is built in a greybox salvage yard, which the pause menu's third choice reaches from the combat yard. After its first session, on build 0.1.0 (16), the maintainer reported: “Yes it went well”, and chose to shuffle the cabinets next, “Shuffle the cabinets (Recommended)”, so each run now deals their contents afresh for the second session. After Claude played build 0.1.0 (17) in the Simulator at the maintainer's request, the maintainer chose to fix what it found unclear from the camera, “Yes, do both”, as [ADR 0006](decisions/0006-salvage-and-exploration-experiment.md#after-claudes-simulator-playtest) records. On build 0.1.0 (18) the maintainer found that it “reads well”, the experiment's second session, and chose to give the last session to its other questions, “The other questions”.
