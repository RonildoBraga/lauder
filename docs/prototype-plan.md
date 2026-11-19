# Lauder — first playable prototype

**Updated:** 20 November 2026\
**Status:** The game opens on a greybox Brooklyn Bridge ([ADR 0004](decisions/0004-brooklyn-bridge-opening.md)), and the whole opening is built, its formations included. What follows needs its own assignment.\
**Technical direction:** Swift + RealityKit, iOS 27, iPhone first.\
**Architecture:** [Architecture and platform decision](architecture.md)

The [story bible](story/story-bible.md) supplies the ensemble direction; the [gameplay walkthrough](gameplay-script.md) describes the opening as built and planned. Their dialogue, exact relationships and enhancement histories remain proposals.

## Purpose and scope

The first playable is the Brooklyn Bridge opening. Miki crosses alone and meets Tom and Laura as strangers, through a first fight, an ambush and a rescue; then the three travel on together. It should show that the party's movement and switching, a light fight and short scripted scenes work together on the phone, and whether the opening is worth building on.

Use the greybox bridge and simple coloured stand-ins. No art or animation production is required. Identify characters and interactions with text as well as colour. Duration should come from playtesting.

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
| Contextual action / advance text | Cross / A | Look, showing the action where there is one | E |
| Cycle leader, once there are two | R1 / RB | Next: name | Q |
| Change formation, once there are two companions | Triangle / Y | Formation | R |
| Fire | R2 / RT | Fire, during a fight or once the carbine is drawn | F |
| Pause / Resume | Options / Menu | Pause / Resume | Escape |

Xbox RB and RT use the same input path as PS5, but hardware delivery remains unverified. [Touch controls](touch-controls.md) are automatic without an extended controller; a connected controller is preferred unless **Use touch controls** is chosen, and **Use controller** returns to it. This in-memory selection changes the input source, not gameplay rules.

- Switching and changing formation are available only while exploring. Pause and dialogue ignore their presses rather than queueing them.
- A switch changes leadership and eases the camera target to the new leader over a short transition, preserving every character's world position and all party progress. It does not teleport the party.
- Held movement may continue on the new leader, including a stick touch held alongside **Next: name**. Switching alone does not close the neutral-input gate. Source changes cancel old captures and require neutral input. After Pause, interruption or reconnection, all keys, buttons and fingers must release; a centred-stick finger still counts as held input.
- Consume a switch or formation edge before an action edge from the same input sample, discarding that action. A held action must be released and pressed again before it acts.
- Prompts describe what the leader can do from an accessible approach. On press, revalidate the leader, the approach and the current progress; a stale prompt cannot act through a wall.

| Interaction | Who | Result |
|---|---|---|
| Search | Whoever leads, at the downed stranger | Takes his rounds and medical kit once, and begins the ambush |
| Help | Whoever leads, beside Laura | Uses the medical kit; she can stand and joins |

## Verification and performance

Use [Simulator and the standard checks](../CONTRIBUTING.md#validation) for everyday iteration. Each change adds focused Swift Testing cases with its implementation, and scripted playtests run through the real controls: `bridge-walk`, `first-fight`, `fight-retry`, `ambush`, `laura`, `opening` for the whole sequence, and `formations`. Pure rule tests alone cannot establish spatial behaviour or feel.

Milestones that change controls, feel or performance get a phone checkpoint on the baseline **iPhone 13 Pro Max**: controls with touch and a controller, combat feel, Pause/Resume and recovery, and measured frame pacing. The target is **60 fps** on that phone, measured during representative play. Record the build, conditions and results; adjust scope or budget if missed. Simulator timing is not phone evidence, and Xbox controllers remain untested on hardware.

## Later hardening, after the loop is worth keeping

Revise the [saving design](architecture.md#saving-and-interruption) before implementation. Preserve stable member identities, the story's progress and a safe group placement when reconstructing a run; do not serialise entity graphs. Use versioned snapshots, ordered atomic writes, restart invalidation and explicit failure handling. Test save round-trips, relaunch, completed progress and interrupted or restarted writes.

Then repeat full runs and restarts on the physical phone over roughly **15–20 minutes**. Inspect frame pacing, memory, thermals and accumulation of scene content, subscriptions or unfinished loads. Persistence and sustained thermal validation remain outside the first-playable exit gate.

## Outside the first playable

Free jumping and climbing, squad orders and combat positioning ([ADR 0003](decisions/0003-squad-movement.md)'s phases S3 and S4), separate character inventories, skill trees, multiplayer, health and hunger systems, crafting, branching dialogue, voice acting, cinematics, levels beyond the bridge, finished character art, checkpoint saves, persistent Continue, cloud services and App Store submission. Combat is limited to what ADR 0004 brings into the opening: assisted aim, a placeholder hit rule and one ammunition count. Expand only in response to a concrete playtest need.

## Combat design review gate

Combat stays occasional; exploration and salvage lead. The longer-term goal is a companion movement system in which the characters **behave like a coordinated squad of soldiers rather than just following the player**: squad formations cycled by one button, directional commands to position squad members, companions that keep formation, avoid obstacles and react to their surroundings, and coordinated use of weapons and abilities in encounters. Mobile controls should stay simple while offering meaningful tactical depth.

The characters' [combat identities](story/story-bible.md#combat-identities), the [future squad behaviour](gameplay-script.md#future-squad-and-combat-design) and [The Quiet Yard](encounters/the-quiet-yard.md) record the working design. [ADR 0003](decisions/0003-squad-movement.md) sets out the navigation, formations, orders and phases S1 to S4, of which S1 is built, and [ADR 0004](decisions/0004-brooklyn-bridge-opening.md) settles the opening's fights.

Before any formation or combat implementation beyond the opening, settle the open design choices with the maintainer and obtain an explicit assignment for a bounded greybox experiment. A reviewer recommendation or a clean review alone is not an implementation assignment.
