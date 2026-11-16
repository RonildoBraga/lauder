# Lauder — first playable prototype

**Date:** 16 November 2026\
**Status:** Party A is assigned by the maintainer's instruction to continue implementation regardless of Claude's response. Initial following/recovery, controls, the three-session stop budget and A/C phone checkpoints remain accepted. Track actual progress in the [Party A record](party-a.md). Biographies, dialogue and B/C interactions remain proposals; no skill barrier or repair loop is included in A.\
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

This is a materially larger first playable than the earlier solo scope. Two followers through the existing narrow passage add navigation, switching and camera risk before the salvage loop has been played. Party A is a bounded experiment to expose that cost, not a small extension already known to work. Do not continue adding content if it fails its stop criterion.

Nina-specific dialogue is excluded from this prototype while kinship remains undecided. Lara participates beside the others, rather than as the remote contact. The full chapter's departure, crossing, further encounters and detailed revelations are outside this slice.

## Review before implementation

Claude [reviewed the proposal at fe9af2d](https://github.com/RonildoBraga/lauder/pull/21#issuecomment-6916286122); the follow-up architecture was consolidated through [PR #22](https://github.com/RonildoBraga/lauder/pull/22). The maintainer subsequently [assigned Party A regardless of Claude's response](https://github.com/RonildoBraga/lauder/issues/13#issuecomment-6917260783), superseding the earlier wait-for-confirmation gate. Continue using the review guidance, focused PRs and required validation without asking for duplicate permission to begin.

The [architecture](architecture.md) and [following ADR](decisions/0002-party-following.md) record the accepted single authority for mode/leader/progress, input edge rules, three bodies, recovery and camera easing. Implement and validate the accepted A decisions; refine the recorded interaction data before B and exact in-place restart/teardown steps before C. Existing solo ownership/save assumptions are superseded. Carry forward the [B1–B3 discussion](https://github.com/RonildoBraga/lauder/issues/13#issuecomment-6916287544).

Initial B1 planning decisions: use bounded, recorded movement trails, with pure Swift path bookkeeping and world collision checks for every body. Exclude party members from physical collision with each other, retain scenery collision, and use spacing for readable separation. Keep equal circular footprints in the initial graybox so different visual silhouettes do not silently introduce new clearance requirements. Switching/reversals must preserve reachable routes rather than connect directly through walls. No navigation mesh or new package is the starting requirement; the architecture and ADR define the accepted trail connections and bounds to validate during Party A.

Initial recovery is **hold and diagnose**, not an automatic warp: stop the blocked follower safely, record the failing route and correct the trail or simplify the authored layout. At the stop review, a constrained out-of-view regroup may be proposed separately. It would require explicit maintainer agreement, safe placement on the same currently reachable/open route, and both origin and destination outside the current camera view including a switch transition. It could never move the active leader or bypass a closed barrier. None of that fallback is approved or required for initial Party A.

## Proposed input and interaction contract

| Intent | PS5 / Xbox | Simulator |
|---|---|---|
| Move active character | Left stick | WASD |
| Contextual action / advance text | Cross / A | E |
| Cycle leader Miki → Lara → Tomas | R1 / RB | Q |
| Pause / Resume | Options / Menu | Escape |

These switching mappings are accepted initial defaults, not implemented controls. Q replaces the Tab proposal to avoid focus navigation; verify actual delivery in Simulator during Party A. There are no touch controls or clickable screen actions.

- Switching is available only while exploring. Pause and dialogue ignore switch presses rather than queueing them.
- A switch changes leadership and eases the camera target to the new leader over a short transition, preserving every character's world position and all party progress. It does not teleport the party or transfer an item between inventories.
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

### Party A stop criterion

Allow **three focused work sessions** to establish a reliable round trip under every leader, including switches and reversals at the service opening. Record each session's attempt and actual result. If that is still unreliable at the end of the third session, stop party implementation before adding B or C, document the blocker and reassess with the maintainer. Do not extend the budget automatically. Named alternatives are a simpler route/layout or a separately agreed constrained regroup policy. The maintainer accepted this budget when proceeding with the recommendations; it applies when Party A is assigned and does not alter the completed Stage 1 criterion.

## Party B — prove alternative specialist actions

Add one closed barrier to the existing service passage. Lara can **Reach latch** from the ground, or Tomas can **Shift loose panel** from a stable grip. Each is a contextual action conveyed by brief text or a simple pose. No free jump, climbing mode, vertical control, simulated heavy-object physics or inaccessible follower ledge is needed.

- Author one accessible approach and prompt for each method. Miki's feedback explains the Lara/Tomas alternatives; an unsuitable leader cannot use the other character remotely.
- Either action sets the same party-owned open flag. The player never needs both. Test each solution independently from a fresh run.
- Once opened, all three traverse the normal ground passage in either direction. Repeating either action, including the other method, has no additional effect.
- Switching preserves the opened state. The front entrance stays blocked; the closed barrier cannot be bypassed by changing leaders.
- Recheck approach accessibility and role on press, including when a prompt became stale after moving or switching.

**Exit:** A new player understands why to switch and can choose either method to admit everyone. Record which method they chose and whether they noticed the other. Following still passes with the barrier closed and open. This establishes role-gated prompts and alternative access, not distinct skill feel: both methods are contextual single-press actions. Add no separate strength task or additional item requirement.

## Party C — close and evaluate the shared loop

Add only the briefing, one regulator, transmitter repair, short crew call, completion, **Read plan** and in-memory Restart.

The trio leaves Relay House together. Miki checks disconnected equipment and takes its compatible regulator without disabling the maintained water supply. The party returns; Miki repairs the transmitter. Any leader can start the call with the coastal operator and water crew and secure the Old Lock meeting plan. All three remain present locally.

Tomas needs the coastal supply team to arrange future inland deliveries, so meeting its crew at Old Lock serves his onward journey as well as the immediate repair. A brief proposed meal coda in the walkthrough tests inclusion among the adults. Finalise the underlying relationships and ending dialogue before Party C; the provisional crew call does not establish that the full chapter's emotional ending lands.

- Keep the opened passage, carried part and mission progress with the party. Switching cannot duplicate, drop or hide progress. The architecture review should determine which indicators are derived from the phase rather than stored twice.
- Repair without the part explains what is missing and changes nothing. Repeated pickup, repair or call requests cannot award or consume progress twice.
- Completion states what changed. **Read plan** repeats the meeting details without restarting the mission.
- Keep dialogue and Pause controls distinct from world actions. Paused/dialogue input cannot move the party, switch leaders or trigger a nearby object.
- A controller/keyboard-operated Restart resets the existing world in place: party, passage, regulator and transmitter return to their initial state without duplicate entities, loads or callbacks. This is the proposed reset strategy; record its exact steps and the minimal menu in the architecture review before C.

**Exit:** An unfamiliar player with a supported controller can understand the goal and complete the party loop on the phone without developer coaching. Review what was enjoyable or unclear before adding another mechanic.

## Verification and performance

Use [Simulator and the standard checks](../CONTRIBUTING.md#validation) for everyday iteration. Add focused Swift Testing cases with the relevant implementation:

- Leader cycling, mode restrictions, simultaneous switch/action priority and no held-action replay.
- Role validation, accessible approaches and revalidation after moving or switching.
- Both barrier solutions independently, shared opening state and harmless requests after opening.
- Shared part/progress surviving switches; repair without the part; duplicate requests; full pickup → repair → call progression.
- Restart restoring the beginning; **Read plan** leaving secured progress unchanged.

Use a **manual Simulator playtest checklist**, not an implied automated rendering suite:

1. Complete shelter → depot → shelter with each leader; inspect both followers at turns and the opening.
2. Reverse and switch beside obstacles and inside the passage; check world collision, trail rebasing, spacing and camera easing. Record any hold/stuck case rather than hiding it.
3. Check Q delivery, switch while moving, simultaneous switch/action and release recovery after Pause or input interruption.
4. From fresh runs, open the barrier with Lara and with Tomas. Recheck stale/wrong-role approaches, repeated requests and group traversal with the barrier closed/open.
5. Carry the part through leader changes, repair, call, reread and restart. Verify that dialogue/Pause controls do not act on nearby objects or duplicate world updates.

Run the relevant subset at A, B and C; items for later stages do not block the earlier movement experiment. Pure rule tests alone cannot establish these spatial behaviours.

Use **two milestone phone sessions**, on the **iPhone 13 Pro Max**: one at the end of Party A for switching/following/controller feel, interruptions and measured frame pacing; one at the end of Party C for the complete loop and the [deferred #18 checks](https://github.com/RonildoBraga/lauder/issues/18). Party B uses everyday Simulator checks and is covered on the phone with C. Review intermediate PRs independently; keep their phone-dependent exit unclaimed until the relevant session. The maintainer accepted this schedule when proceeding with the recommendations; this consolidation task requests no phone session. The earlier deferral and separate Xbox-hardware gap remain recorded, not passed or silently waived.

The target remains **60 fps** on that phone, measured during representative party play before declaring the first playable proven. Record the build, conditions and results; adjust scope or budget if missed. Simulator timing and previous solo phone checks are not party performance evidence. Keep the foreground game awake, including Pause, and restore normal idle locking when inactive.

## Later hardening, after the loop is worth keeping

Revise the [saving design](architecture.md#saving-and-interruption) for party checkpoints before implementation. Preserve stable member identities, shared mission progress and a safe group placement when reconstructing a run; do not serialise entity graphs or assume the old solo spawn model is sufficient. Use versioned snapshots, ordered atomic writes, restart invalidation and explicit failure handling. Test save round-trips, relaunch, completed progress and interrupted/restarted writes.

Then repeat full runs and restarts on the physical phone over roughly **15–20 minutes**. Inspect frame pacing, memory, thermals and accumulation of scene content, subscriptions or unfinished loads. Persistence and sustained thermal validation remain later hardening, outside the first-playable exit gate.

## Outside the first playable

Mandatory strength obstacles, free jumping/climbing, formation orders, separate character inventories, skill trees, multiplayer, combat, health/hunger systems, extra salvage errands, crafting, branching dialogue, voice acting, cinematics, additional levels, finished character art, checkpoint saves, persistent Continue, cloud services and App Store submission.

The party loop can establish whether switching, following and purposeful salvage work together. It will not establish full-chapter pacing, persistent-save reliability or sustained device performance. Expand only in response to a concrete playtest need.
