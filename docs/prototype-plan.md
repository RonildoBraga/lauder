# Lauder — first playable prototype

**Updated:** 19 November 2026\
**Status:** The game opens on a greybox Brooklyn Bridge, as the maintainer accepted in [ADR 0004](decisions/0004-brooklyn-bridge-opening.md). Milestones M1 to M4 are merged, completing the opening; what follows needs its own assignment. The maintainer assigned M4, **“Yes, start M4”**, and [authorised its merge](https://github.com/RonildoBraga/lauder/pull/47#issuecomment-6996988166), **“merge #47”**, after its phone checkpoint, where a five-minute run averaged 59.97 fps with four long frames, and the maintainer reported **“I did not noticed any stutters and everything worked as expected”**. The [opening record](opening.md) lists what each milestone built and how it was checked. The earlier Relay House slice, Stages 1 and 2, Parties A to C and squad movement S1, is summarised in the [project history](history.md); the maintainer removed its level on 18 November 2026. TestFlight build 0.1.0 (3), from M4's branch at `c6af7c1`, is available to internal testers.\
**Technical direction:** Swift + RealityKit, iOS 27, iPhone first.\
**Architecture:** [Architecture and platform decision](architecture.md)

The [story bible](story/story-bible.md) supplies the ensemble direction; the [gameplay walkthrough](gameplay-script.md) describes the opening as built and planned. Their new dialogue, exact relationships and enhancement histories remain proposals.

## Purpose and scope

The first playable is the Brooklyn Bridge opening. Miki crosses alone and meets Tom and Laura as strangers, through a first fight, an ambush and a rescue; then the three travel on together. It should show that the party's movement and switching, a light fight and short scripted scenes work together on the phone, and whether the opening is worth building on.

Use the greybox bridge and simple coloured stand-ins. No new art or animation production is required. Identify characters and interactions with text as well as colour. Duration should come from playtesting.

| Element | First playable |
|---|---|
| Party | Miki alone at first; Tom joins in M3 and Laura in M4. One active character, computer-controlled companions, one elevated follow camera |
| Fights | Assisted aim, line of sight and cover, a placeholder hit rule (three hits, then a retry) and one ammunition count |
| Scenes | Short scripted beats that play the same way every time |
| Inventory | One small shared inventory: rounds and medical kits |
| Interface | Active-character label, objective, contextual action, the fight's HUD, dialogue, Pause/Resume and Restart |
| Run | In-memory progress; a fresh launch or Restart begins a new run |

Nina-specific dialogue is excluded while kinship remains undecided. The full chapter's later scenes, further encounters and detailed revelations are outside this slice.

## Opening — the Brooklyn Bridge

ADR 0004's five milestones are each assigned separately, with `./scripts/check`, Simulator playtests and a maintainer playtest:

| Milestone | Adds | State |
|---|---|---|
| **M1** The bridge, Miki alone | Levels as values, the bridge greybox, a party of one, trigger areas, Restart, the renames to Tom and Laura | Merged: assigned by the maintainer (“Yes, start M1”), who [authorised the merge](https://github.com/RonildoBraga/lauder/pull/41#issuecomment-6971880003) (“Yes, merge both”) without an independent review |
| **M2** The first fight | Fire, assisted aim, line of sight, hits, the stranger, the retry | Merged: assigned by the maintainer (“Yes, start M2”). After playing it on the baseline iPhone, the maintainer reported “It read well” and [authorised the merge](https://github.com/RonildoBraga/lauder/pull/42#issuecomment-6973249055) (“Yes, merge it”) without an independent review |
| **M3** Search, ambush, Tom | Searching and loot, the ambush, Tom's shot, recruitment, following with one companion | Merged: assigned by the maintainer (“Yes, start M3”). After playing it on the baseline iPhone, the maintainer reported “It played well” and [authorised the merge](https://github.com/RonildoBraga/lauder/pull/44#issuecomment-6975896955) (“Yes, merge both”). Codex's automatic review found nothing; no independent review was requested |
| **M4** Laura and onwards | Helping, the medical kit, the third member, the end of the slice; a phone checkpoint | Merged: assigned by the maintainer (“Yes, start M4”). At the phone checkpoint, a five-minute run averaged 59.97 fps with four long frames, and the maintainer reported “I did not noticed any stutters and everything worked as expected”, then [authorised the merge](https://github.com/RonildoBraga/lauder/pull/47#issuecomment-6996988166) (“merge #47”) |
| **M5** Formations | ADR 0003 phase S2 on the open deck | Not assigned |

**The bridge at real tower spacing:** [merged](https://github.com/RonildoBraga/lauder/pull/55#issuecomment-7005537305) under the standing permission, after the maintainer played it on the baseline iPhone (“I finished play and everything seems ok”). The maintainer asked to simplify the bridge to the road and the towers at correct dimensions, and chose the real tower spacing (“Real tower spacing”), as [ADR 0004's amendment](decisions/0004-brooklyn-bridge-opening.md#amendment--the-bridge-at-its-real-tower-spacing) records. The deck is now 644 m long.

**M1 exit:** Miki walks the whole deck without snagging and the camera reads well; each trigger fires once. Whether the camera reads well was not recorded.

**M2 exit:** a new player answers the stranger without help, with touch and with a controller; cover works for both sides. Stop rule from the ADR: if the first fight is not readable on the phone after three focused work sessions on M2, stop and reassess with the maintainer. After the first session the maintainer reported “It read well”; who played, and with which inputs, was not recorded.

**M3 exit:** the beat plays the same way every time; Tom follows along the deck without snagging.

**M4 exit:** the whole opening plays through, with a phone checkpoint for controls, combat feel and frame pacing.

## Blender pipeline

[ADR 0006](decisions/0006-blender-source-of-truth.md), which the maintainer accepted on 19 November 2026 (“Yes, record it”), makes Blender files the source of levels and models. Each step is its own pull request and needs its own go-ahead:

| Step | Adds | State |
|---|---|---|
| **1** The decision | ADR 0006 and the documents it changes | Merged: accepted by the maintainer (“Yes, record it”) and [merged](https://github.com/RonildoBraga/lauder/pull/51#issuecomment-6999540584) under the standing permission. Codex's automatic review found nothing, and Copilot's two findings were fixed |
| **2** The path into the game | The game loads the bridge's look from a USDZ that Blender exports, instead of drawing boxes; a phone check | Merged: assigned by the maintainer (“go ahead”). On the baseline iPhone it held 59.92 fps over 103 s, with four long frames, and the maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/52#issuecomment-7000152015) (“Yes, merge it”). Codex's and Copilot's findings were fixed |
| **3** Blender as the source | The committed level file, Export and the freshness check; Load, safe Save, the working file and the palette retire | Merged: assigned by the maintainer (“Yes, start step 3”), and [merged](https://github.com/RonildoBraga/lauder/pull/53#issuecomment-7000891999) under the standing permission. Codex's and Copilot's findings were fixed |
| **4** Models and provided files | Linked models, the intake check and provenance notes | Merged: assigned by the maintainer (“Start step 4”), and [merged](https://github.com/RonildoBraga/lauder/pull/54#issuecomment-7003938273) under the standing permission. Codex's and Copilot's findings were fixed. USDZ files for things the code spawns wait for the first such model |
| **5** Art and richer light | Point and spot lights, full texture maps, models the code spawns, and baked lighting | Assigned by the maintainer (“proceed with the next step”), who chose all four parts and raised the light budget to four (“Up to 4, 1 shadowed”). Each part is a pull request of its own: point and spot lights [merged](https://github.com/RonildoBraga/lauder/pull/56#issuecomment-7006540355) under the standing permission; full texture maps [merged](https://github.com/RonildoBraga/lauder/pull/57#issuecomment-7007123450); models the code spawns in review |

## Input and interaction contract

| Intent | PS5 / Xbox | Touch | Keyboard |
|---|---|---|---|
| Move active character | Left stick | Bottom-left analog stick | WASD |
| Contextual action / advance text | Cross / A | Look, showing the action where there is one | E |
| Cycle leader, once there are two | R1 / RB | Next: name | Q |
| Fire | R2 / RT | Fire, during a fight or once the carbine is drawn | F |
| Pause / Resume | Options / Menu | Pause / Resume | Escape |

Xbox RB and RT use the same input path as PS5, but hardware delivery remains unverified. The maintainer's [touch request](touch-controls.md#authorisation) superseded the earlier no-touch decision. Touch is automatic without an extended controller; a connected controller is preferred unless **Use touch controls** is chosen, and **Use controller** returns to it. This in-memory selection changes the input source, not gameplay rules.

- Switching is available only while exploring. Pause and dialogue ignore switch presses rather than queueing them.
- A switch changes leadership and eases the camera target to the new leader over a short transition, preserving every character's world position and all party progress. It does not teleport the party.
- Held movement may continue on the new leader, including a stick touch held alongside **Next: name**. Switching alone does not close the neutral-input gate. Source changes cancel old captures and require neutral input. After Pause, interruption or reconnection, all keys, buttons and fingers must release; a centred-stick finger still counts as held input.
- Consume a switch edge before an action edge from the same input sample, discarding that action. A held action must be released and pressed again before it acts for the new leader.
- Prompts describe what the leader can do from an accessible approach. On press, revalidate the leader, the approach and the current progress; a stale prompt cannot act through a wall.

| Interaction | Who | Result |
|---|---|---|
| Search | Whoever leads, at the downed stranger | Takes his rounds and medical kit once, and begins the ambush |
| Help | Whoever leads, beside Laura (M4) | Uses the medical kit; she can stand and joins |

## Verification and performance

Use [Simulator and the standard checks](../CONTRIBUTING.md#validation) for everyday iteration. Each milestone adds focused Swift Testing cases with its implementation, and a scripted playtest scenario through the real controls: `bridge-walk`, `first-fight`, `fight-retry`, `ambush`, `laura`, and `opening` for the whole sequence. Pure rule tests alone cannot establish spatial behaviour or feel.

The opening's planned phone checkpoint comes with M4, on the baseline **iPhone 13 Pro Max**: controls with touch and a controller, combat feel, Pause/Resume and recovery, and measured frame pacing. The target remains **60 fps** on that phone, measured during representative play. Record the build, conditions and results; adjust scope or budget if missed. Simulator timing is not phone evidence. Earlier deferrals, the [#18](https://github.com/RonildoBraga/lauder/issues/18) lists, PR #11's refreshed phone check and Xbox hardware, stay open as the [project history](history.md#stage-2--movement-and-controls) records, not passed or silently waived.

## Later hardening, after the loop is worth keeping

Revise the [saving design](architecture.md#saving-and-interruption) before implementation. Preserve stable member identities, the story's progress and a safe group placement when reconstructing a run; do not serialise entity graphs. Use versioned snapshots, ordered atomic writes, restart invalidation and explicit failure handling. Test save round-trips, relaunch, completed progress and interrupted or restarted writes.

Then repeat full runs and restarts on the physical phone over roughly **15–20 minutes**. Inspect frame pacing, memory, thermals and accumulation of scene content, subscriptions or unfinished loads. Persistence and sustained thermal validation remain outside the first-playable exit gate.

## Outside the first playable

Free jumping and climbing, formation orders before M5, separate character inventories, skill trees, multiplayer, health and hunger systems, crafting, branching dialogue, voice acting, cinematics, levels beyond the bridge, finished character art, checkpoint saves, persistent Continue, cloud services and App Store submission. Combat is limited to what ADR 0004 brings into the opening: assisted aim, a placeholder hit rule and one ammunition count. Expand only in response to a concrete playtest need.

## Combat design review gate

On 17 November 2026 the maintainer confirmed **“Occasional combat; exploration and salvage lead”**, and set the longer-term goal: **“I’d like to introduce a more sophisticated AI-driven companion movement system where the characters behave like a coordinated squad of soldiers rather than just following the player.”** It names squad formations cycled by one button, directional commands to position squad members, companions that keep formation, avoid obstacles and react to their surroundings, and coordinated use of weapons and abilities in encounters. It also set the order: **“before implementing any of these mechanics, I think we should focus on defining the characters and their combat identities”**, then **“Once we’re happy with those definitions, we can design the movement, formation, and combat systems around them.”** Mobile controls should stay simple while offering meaningful tactical depth.

The maintainer [agreed the combat definitions](https://github.com/RonildoBraga/lauder/pull/29#issuecomment-6943836774) after Claude's review: **“Agreed, start design”**. The [combat identities](story/story-bible.md#combat-identities), [future squad behaviour](gameplay-script.md#future-squad-and-combat-design) and [The Quiet Yard](encounters/the-quiet-yard.md) record that working design. [ADR 0003](decisions/0003-squad-movement.md) sets out the navigation, formations, orders and phases S1 to S4; the maintainer accepted it (**“Accept, S1 first”**), and S1 is built. ADR 0004 settles the design choices for the opening's first fight.

Before any formation or combat implementation beyond the opening's milestones, settle the open design choices with the maintainer and obtain an explicit assignment for a bounded greybox experiment. A reviewer recommendation or a clean review alone is not an implementation assignment.
