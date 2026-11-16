# Lauder — first playable prototype

**Date:** 16 November 2026\
**Status:** Preparation approved; implementation has not started.\
**Technical direction:** Swift + RealityKit, current stable iOS 27, iPhone first.\
**Architecture:** [Architecture and platform decision](architecture.md)

**Physical baseline:** iPhone 13 Pro Max on the current stable iOS 27 release. Target 60 fps on this phone; 120 fps is outside the prototype requirement.

## Purpose and milestones

Prove that moving through this world, noticing a route, salvaging something useful and returning to make a repair feels understandable and satisfying on a phone.

This is a **Relay House slice** from the middle of [Chapter One](../story/chapter-01.md). Aim for roughly **3–5 minutes** for a first playthrough, without padding the route.

The maintainer approved [issue #4's scope split](https://github.com/RonildoBraga/lauder/issues/4#issuecomment-6905581377):
- **First playable:** Stages 1–3 and the prototype exit checks below.
- **Later hardening:** Stage 4 persistence and Stage 5 sustained memory/thermal validation, after the maintainer decides the loop is worth keeping.

The [saving design](architecture.md#saving-and-interruption) remains the target for hardening. It is not a prerequisite for evaluating the first loop.

This preparation PR requests Claude's review before Stage 1. It does not start Stage 1 or authorise implementation.

## The playable loop

1. At Relay House, Tomas explains the broken transmitter and points Miki toward the depot. Brief text establishes the closed crossing and insufficient water for the longer detour.
2. Walk through a compact ruined service district.
3. Discover that the direct depot entrance is blocked. Observe a visible service passage and go around.
4. Identify and take one compatible regulator from abandoned equipment.
5. Return to Relay House and repair the transmitter.
6. Read a short radio conversation with Lara, Nina and Tomas. Agree to meet at Old Lock.
7. See a clear completion message and reread the meeting plan in the current run.

The blocked entrance uses ordinary level geometry and collision. It creates a reason to observe the environment without another key, extra fetch task or timed damage system.

## Content budget

| Element | First playable |
|---|---|
| World | One contiguous scene: relay shelter, short route and depot |
| Player | Miki, using a properly sourced animated stand-in |
| Other physical character | Tomas at the shelter; stationary |
| Remote cast | Lara and Nina represented through text dialogue |
| Salvage | One regulator, one pickup |
| Repair | One transmitter, with visibly broken and working states |
| Controls | Left movement thumbstick; one contextual action button |
| Camera | Fixed elevated perspective with follow; landscape |
| Interface | Objective, carried-part indicator, dialogue, Pause/Resume and Restart |
| Progress | In-memory run state; a fresh launch starts a new run |
| Presentation | Graybox first; limited war damage, signs and sound for readability |

Miki is widowed; Nina is her daughter; Tomas is her father; Lara is her trusted friend. The call uses those relationships consistently. The cause of her husband's death and the cause of the collapse remain unexplained.

Water, shelter and travel risk supply the narrative context. Water depletion, hunger meters, health, combat and the security-machine encounter follow a proven base loop. This prototype's smaller scope does not revise the full game's survival direction.

## First playable: Stages 1–3

### 1. Establish the device and asset path

- Verify the test device and its installed stable iOS version.
- Use stable Xcode/Reality Composer Pro versions and record them.
- Create one app target and one Swift Testing unit-test target with the [Swift conventions](architecture.md#swift-conventions).
- Follow the [asset contribution policy](../CONTRIBUTING.md#assets-and-attribution) before adding any model or scene.
- Load a small scene and one rigged character with idle/walk animation.
- Build, sign and run on the baseline phone.

**Exit:** The representative character and scene load correctly on the phone. We understand the authored-asset-to-app workflow.

**Stop criterion:** If that rigged character, scene and idle/walk animation are not running on the baseline phone after **three focused work sessions**, stop and document the blocker. Reassess with the maintainer before expanding the work. Use the [engine decision record](decisions/0001-engine.md#stage-1-stop-criterion) for the agreed criterion and how to record the sessions.

### 2. Make movement comfortable

- Add screen-relative touch movement, character collision and camera follow.
- Lay out the shelter, depot, landmarks and service passage.
- Add a nearby stationary Tomas placeholder.
- Verify simultaneous movement and action-button input, safe areas and visibility.
- On inactivity, clear held input, pause the live world and reset frame timing on resume.

**Exit:** Miki can walk the route predictably without getting stuck or disappearing behind geometry. Touch release and interruptions cannot leave her moving.

### 3. Close and evaluate the loop

- Add mission phases, authored interactions and the correct objective/action labels.
- Gate repair on possessing the regulator.
- Add repair feedback, the family call, completion and **Read plan**.
- Validate required scene IDs at load.
- Add an in-memory Restart that tears down the old scene and cancels old loads/callbacks.
- Add only the environmental details needed to communicate a ruined future and the route.
- Let someone unfamiliar with the prototype try the complete loop without coaching.
- Measure frame pacing during representative play on the baseline phone.

**Exit:** The first-playable criteria pass. Review what was enjoyable or unclear before deciding to harden or expand the loop.

## First-playable exit checks

- A new player understands the goal and finishes the loop without developer guidance.
- The intended route and alternative entrance read from the environment.
- Movement follows screen direction, collision is predictable, and the camera keeps Miki readable.
- The contextual button offers the correct action. Current distance/accessibility are rechecked on press.
- Repair before collection explains itself and changes nothing; the regulator cannot be collected twice in a run.
- The repaired radio enables the call. Rereading the meeting plan leaves progress unchanged.
- Restart begins a clean in-memory run with no duplicated scene content or callbacks.
- Backgrounding, lock/unlock and interrupted touch clear held input and pause/resume the live scene coherently.
- Smooth **60 fps is measured on the iPhone 13 Pro Max** with representative placeholder animation and scene load. If missed, record the measurement and adjust scope or budget before declaring the loop proven.

## Focused first-playable verification

Use Swift Testing for rules that can fail:
- Repair without the part is rejected; duplicate collection and repair requests have no additional effect.
- Briefing → pickup → repair → call completes, with consistent item, radio and objective state.
- Restart resets the phase; **Read plan** after completion does not restart the mission.

Use manual device checks for controls, camera, collision, interruptions and a complete unfamiliar-player run. There is no app or runnable test command yet; add one documented build-and-test command when the project exists.

## Later hardening, after the loop is worth keeping

### 4. Preserve progress

Implement the existing [saving and interruption design](architecture.md#saving-and-interruption):
- Versioned checkpoint snapshots and an ordered atomic writer.
- Continue across relaunch and restoration at the declared safe spawns.
- Restart invalidation of older pending writes.
- Visible save/load failure handling; corrupt saves are not silently erased.
- Coherent recovery after termination before collection, after pickup, after repair and after completion.

Add save round-trip, completed-save reload and write-order/restart checks here. Ordinary in-memory pause/resume already belongs in Stage 2; hardening adds persistence.

### 5. Validate sustained behaviour

Repeat full runs and restarts on the physical phone over roughly 15–20 minutes. Inspect frame pacing, memory and thermal behaviour. Check that scene content, subscriptions and unfinished loads do not accumulate.

**Hardening exit:** Checkpoint persistence works, interrupted/restarted runs remain coherent, and repeated play shows no sustained unexpected memory growth or unacceptable thermal/frame-time degradation on the baseline phone.

These checks are not the first-playable exit gate.

## Outside the first playable

The home departure and bridge scenes, moving companions, NPC pathfinding, combat, health or hunger systems, extra salvage errands, equipment, crafting, branching dialogue, voice acting, cinematics, multiple levels, checkpoint saves, persistent Continue, sustained memory/thermal profiling, cloud services and App Store submission.

## What completion tells us

The first playable provides evidence for the Swift/RealityKit asset workflow, phone controls, camera, in-memory interaction rules and the salvage-and-repair loop. It does not establish persistent-save reliability or sustained performance.

No release date is promised before the actual character, content and device workflow is proven.
