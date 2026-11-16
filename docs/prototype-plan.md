# Lauder — first playable prototype

**Date:** 16 November 2026\
**Status:** Party prototype proposal for Claude's documentation review and maintainer agreement before implementation. The approved direction is one human player controlling three characters together, switching the leader while two companions follow. The proposed cast, roles, controls and milestones below remain review choices. The current build has one controlled character, stationary Tomas and observations; party movement, specialist actions and the repair loop are not implemented.\
**Technical direction:** Swift + RealityKit, iOS 27, iPhone first.\
**Architecture:** [Architecture and platform decision](architecture.md)

The [story bible](story/story-bible.md) supplies the ensemble direction; the [gameplay walkthrough](gameplay-script.md) describes the proposed experience. Their new dialogue, exact relationships and enhancement histories remain proposals. This plan replaces the earlier solo Stage 3 target. It does not rewrite the completed [Stage 1](stage-1.md) and [Stage 2](stage-2.md) evidence or authorise gameplay work.

## Purpose and scope

First prove that controlling a party is comfortable on the existing route. Then test whether reading the depot, using a companion's ability, recovering a useful part and repairing a shared transmitter makes the journey satisfying.

Use one contiguous Relay House–depot scene, simple coloured stand-ins and the current geometry. No new art or animation production is required. Identify characters and interactions with text as well as colour. Duration should come from playtesting; the previous solo estimate of 3–5 minutes is not a party requirement.

| Element | Proposed first playable |
|---|---|
| Party | Miki, Lara and Tomas, all present and controllable; names and role assignments remain proposals |
| Leadership | One active character, two computer-controlled followers, one elevated follow camera |
| Access | One barrier: Lara reaches its latch, or Tomas shifts its loose panel; either opens the same passage |
| Salvage and repair | Miki inspects and takes one regulator, then repairs one transmitter |
| Other dialogue | Keeper briefing through text, without a fourth physical character rig |
| Contact | Coastal operator/water crew; all three party members remain local |
| Progress | Party-wide opened-passage, carried-regulator and mission progress |
| Interface | Active-character label, contextual prompt, objective, carried-part indicator, dialogue, Pause/Resume and Restart |
| Run | In-memory progress; a fresh launch or Restart begins a new run |

The two access methods are alternatives, not consecutive tasks. There is no separate strength obstacle or trio of mandatory skill locks. The wider game retains distinct skills, discreet enhancements, exploration, survival context and light combat. This slice needs no combat, health, hunger, countdown, equipment or enhancement-resource system.

Nina-specific dialogue is excluded from this prototype while kinship remains undecided. Lara participates beside the others, rather than as the remote contact. The full chapter's departure, crossing, further encounters and detailed revelations are outside this slice.

## Review before implementation

Request Claude's review of the walkthrough, this sequence and the party architecture on GitHub before assigning implementation. Resolve the remaining maintainer choices, then use focused implementation PRs with review before merge.

The architecture pass must settle a single authority for leader identity, shared progress and interaction modes; how input reaches it; how the world owns three bodies and the camera; and how following, restart and teardown work. Existing solo ownership and save assumptions are not automatically accepted for the party. Carry forward the [reachability, command-routing and restart discussion](https://github.com/RonildoBraga/lauder/issues/13).

Choose the simplest follow method that passes the route tests. A bounded authored route is acceptable for this scene; no particular engine API, navigation framework or package is prescribed. Prove it before expanding the level.

## Proposed input and interaction contract

| Intent | PS5 / Xbox | Simulator |
|---|---|---|
| Move active character | Left stick | WASD |
| Contextual action / advance text | Cross / A | E |
| Cycle leader Miki → Lara → Tomas | R1 / RB | Tab |
| Pause / Resume | Options / Menu | Escape |

These switching mappings are proposals, not implemented controls. There are no touch controls or clickable screen actions.

- Switching is available only while exploring. Pause and dialogue ignore switch presses rather than queueing them.
- A switch changes leadership and the camera target, preserving every character's world position and all party progress. It does not teleport the party or transfer an item between inventories.
- Held movement may continue on the new leader. Switching alone does not close the neutral-input gate. Existing release requirements after interruption, reconnection and Pause/Resume remain.
- Consume a switch edge before an action edge from the same input sample, discarding that action. A held action must be released and pressed again before it acts for the new leader.
- Prompts describe what the active character can do from an accessible approach. On press, revalidate the active character, role, range, accessibility and current progress; a stale prompt cannot act through a wall or call a remote companion.
- An unsuitable character receives a short explanation or a suggestion to switch. Do not automatically make the specialist perform the action elsewhere.

| Interaction | Eligible active character | Result |
|---|---|---|
| Keeper briefing | Any leader | Establish the fault and shared objective |
| Reach latch | Lara | Open the shared ground-level service passage once |
| Shift loose panel | Tomas | Open that same passage once, as an alternative to the latch |
| Inspect and take regulator | Miki | Confirm compatibility and collect the single party-owned part |
| Repair | Miki, with the part | Consume the part once and restore the transmitter |
| Call / Read plan | Any leader | Contact the water crew / reread the secured meeting details |

## Completed foundations — preserve their evidence

### 1. Establish the device and asset path

Stage 1 established the representative rig, idle/walk clips, direct USDZ loading and Swift-composed scene on the baseline iPhone. Keep the [asset provenance and reproduction workflow](../sources/content/character/README.md), [session log](stage-1.md) and [engine decision](decisions/0001-engine.md).

The agreed [three-session stop criterion](decisions/0001-engine.md#stage-1-stop-criterion) remains unchanged in the engine decision record. This party plan does not restart that completed proof or require three animated character assets before testing following.

### 2. Make movement comfortable

Stage 2 supplies the existing route, character collision, camera framing, controller/keyboard input, pause and interruption handling. Its stationary Tomas and single moving character are historical implementation facts, not the party target. Preserve the actual [Simulator and phone observations](stage-2.md); passing the earlier solo checks does not establish party behaviour.

## Party A — prove switching and following

Use three clearly named, differently coloured primitive stand-ins on the existing route. Animation is not an exit requirement for this milestone. Retain its open service passage while testing shelter → depot → shelter movement; add no mission or skill gate yet.

- Direct each character in turn. The other two follow through the actual route, including turns and the service opening, without clipping walls, automatic teleports or player rescue.
- Switch at rest and while moving, including beside obstacles and with followers on different parts of the route. Preserve positions and transfer camera follow without losing the active character.
- Avoid followers repeatedly blocking the leader or each other. Reversing direction and switching to a trailing member must remain usable.
- Freeze the whole party on Pause, inactivity or loss of available input. Resume without stale movement, accumulated frame time or duplicate update callbacks.
- Check the proposed input priority and release behaviour before adding interactions.

**Exit:** The whole party completes the round trip under every leader, with predictable collision and readable camera behaviour. Record stuck, separated or obscured cases and fix the bounded route before adding content.

## Party B — prove alternative specialist actions

Add one closed barrier to the existing service passage. Lara can **Reach latch** from the ground, or Tomas can **Shift loose panel** from a stable grip. Each is a contextual action conveyed by brief text or a simple pose. No free jump, climbing mode, vertical control, simulated heavy-object physics or inaccessible follower ledge is needed.

- Author one accessible approach and prompt for each method. Miki's feedback explains the Lara/Tomas alternatives; an unsuitable leader cannot use the other character remotely.
- Either action sets the same party-owned open flag. The player never needs both. Test each solution independently from a fresh run.
- Once opened, all three traverse the normal ground passage in either direction. Repeating either action, including the other method, has no additional effect.
- Switching preserves the opened state. The front entrance stays blocked; the closed barrier cannot be bypassed by changing leaders.
- Recheck approach accessibility and role on press, including when a prompt became stale after moving or switching.

**Exit:** A new player understands why to switch and can choose either method to admit everyone. Following still passes with the barrier closed and open. Add no separate strength task or additional item requirement.

## Party C — close and evaluate the shared loop

Add only the briefing, one regulator, transmitter repair, short crew call, completion, **Read plan** and in-memory Restart.

The trio leaves Relay House together. Miki checks disconnected equipment and takes its compatible regulator without disabling the maintained water supply. The party returns; Miki repairs the transmitter. Any leader can start the call with the coastal operator and water crew and secure the Old Lock meeting plan. All three remain present locally.

- Keep the opened passage, carried part and mission progress with the party. Switching cannot duplicate, drop or hide progress. The architecture review should determine which indicators are derived from the phase rather than stored twice.
- Repair without the part explains what is missing and changes nothing. Repeated pickup, repair or call requests cannot award or consume progress twice.
- Completion states what changed. **Read plan** repeats the meeting details without restarting the mission.
- Keep dialogue and Pause controls distinct from world actions. Paused/dialogue input cannot move the party, switch leaders or trigger a nearby object.
- A controller/keyboard-operated Restart resets the party, passage, regulator and transmitter together, without duplicate entities, loads or callbacks. Settle the minimal menu and reset-versus-rebuild choice in the architecture review.

**Exit:** An unfamiliar player with a supported controller can understand the goal and complete the party loop on the phone without developer coaching. Review what was enjoyable or unclear before adding another mechanic.

## Verification and performance

Use [Simulator and the standard checks](../CONTRIBUTING.md#validation) for everyday iteration. Add focused Swift Testing cases with the relevant implementation:

- Leader cycling, mode restrictions, simultaneous switch/action priority and no held-action replay.
- Role validation, accessible approaches and revalidation after moving or switching.
- Both barrier solutions independently, shared opening state and harmless requests after opening.
- Shared part/progress surviving switches; repair without the part; duplicate requests; full pickup → repair → call progression.
- Restart restoring the beginning; **Read plan** leaving secured progress unchanged.

Rendered route tests must check three-body following, collision, narrow passages, reversals, separation and camera visibility. Pure rule tests alone cannot establish these behaviours.

At playable-feature milestones, before merging, validate affected inputs, party movement, lifecycle and frame pacing on the **iPhone 13 Pro Max** with supported controllers. The [phone-check tracker #18](https://github.com/RonildoBraga/lauder/issues/18) preserves the accepted earlier deferral; it is not a passed check or a waiver for future milestones. This documentation task requests no phone session.

The target remains **60 fps** on that phone, measured during representative party play before declaring the first playable proven. Record the build, conditions and results; adjust scope or budget if missed. Simulator timing and previous solo phone checks are not party performance evidence. Keep the foreground game awake, including Pause, and restore normal idle locking when inactive.

## Later hardening, after the loop is worth keeping

Revise the [saving design](architecture.md#saving-and-interruption) for party checkpoints before implementation. Preserve stable member identities, shared mission progress and a safe group placement when reconstructing a run; do not serialise entity graphs or assume the old solo spawn model is sufficient. Use versioned snapshots, ordered atomic writes, restart invalidation and explicit failure handling. Test save round-trips, relaunch, completed progress and interrupted/restarted writes.

Then repeat full runs and restarts on the physical phone over roughly **15–20 minutes**. Inspect frame pacing, memory, thermals and accumulation of scene content, subscriptions or unfinished loads. Persistence and sustained thermal validation remain later hardening, outside the first-playable exit gate.

## Outside the first playable

Mandatory strength obstacles, free jumping/climbing, formation orders, separate character inventories, skill trees, multiplayer, combat, health/hunger systems, extra salvage errands, crafting, branching dialogue, voice acting, cinematics, additional levels, finished character art, checkpoint saves, persistent Continue, cloud services and App Store submission.

The party loop can establish whether switching, following and purposeful salvage work together. It will not establish full-chapter pacing, persistent-save reliability or sustained device performance. Expand only in response to a concrete playtest need.
