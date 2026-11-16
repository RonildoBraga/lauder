# Lauder — first playable prototype

**Date:** 16 November 2026\
**Status:** Proposed scope and sequence; implementation has not started.\
**Technical direction:** Swift + RealityKit, current stable iOS 27, iPhone first.\
**Architecture:** [Architecture and platform decision](architecture.md)

**Physical baseline:** iPhone 13 Pro Max on the current stable iOS 27 release. Target 60 fps on this phone; 120 fps is outside the prototype requirement.

## Purpose

Prove that moving through this world, noticing a route, salvaging something useful and returning to make a repair feels understandable and satisfying on a phone.

This is a **Relay House slice** from the middle of [Chapter One](../story/chapter-01.md), not the entire chapter. Aim for roughly **3–5 minutes** for a first playthrough, without padding the route to meet a duration.

## The playable loop

1. At Relay House, Tomas explains the broken transmitter and points Miki toward the depot. Brief text establishes the closed crossing and insufficient water for the longer detour.
2. Walk through a compact ruined service district.
3. Discover that the direct depot entrance is blocked. Observe a visible service passage and go around.
4. Identify and take one compatible regulator from abandoned equipment.
5. Return to Relay House and repair the transmitter.
6. Read a short radio conversation with Lara, Nina and Tomas. Agree to meet at Old Lock.
7. See a clear completion message and retain that progress after relaunch.

The blocked entrance uses ordinary level geometry and collision. It creates a reason to observe the environment without another key, extra fetch task or timed damage system.

## Content budget

| Element | First prototype |
|---|---|
| World | One contiguous scene: relay shelter, short route and depot |
| Player | Miki, using a properly sourced animated stand-in |
| Other physical character | Tomas at the shelter; stationary |
| Remote cast | Lara and Nina represented through text dialogue |
| Salvage | One regulator, one pickup |
| Repair | One transmitter, with visibly broken and working states |
| Controls | Left movement thumbstick; one contextual action button |
| Camera | Fixed elevated perspective with follow; landscape |
| Interface | Objective, carried-part indicator, dialogue, pause, Continue/Restart |
| Persistence | One local checkpoint save |
| Presentation | Graybox first; a small pass of war damage, signs and sound for readability |

Miki is widowed; Nina is her daughter; Tomas is her father; Lara is her trusted friend. The call uses those relationships consistently. The cause of her husband's death and the cause of the collapse remain unexplained.

Water, shelter and travel risk supply the narrative context. Water depletion, hunger meters, health, combat and the security-machine encounter follow a proven base loop. Their absence from this prototype does not revise the full game's survival direction.

## Build sequence after agreement

### 1. Establish the device and asset path

- Verify the test device and its installed stable iOS version before the first device build.
- Use stable Xcode/Reality Composer Pro versions and record them.
- Create one app target and one unit-test target.
- Load a small scene and one rigged character with idle/walk animation.
- Build, sign and run on that phone.

**Exit:** The representative character and scene load correctly on the phone. We understand how an authored asset becomes part of the running game. Resolve import or animation problems here.

### 2. Make movement comfortable

- Add screen-relative touch movement, character collision and camera follow.
- Lay out the shelter, depot, landmarks and service passage.
- Add a nearby stationary Tomas placeholder.
- Verify simultaneous movement and action-button input, safe areas and visibility.

**Exit:** Miki can walk the entire route predictably without getting stuck or disappearing behind geometry. Touch release and interruptions cannot leave her moving.

### 3. Close the loop

- Add the mission phases and the three authored interactions.
- Show the correct contextual labels and objective.
- Gate repair on possessing the regulator.
- Add visible repair feedback, the short family call and completion state.
- Validate required scene IDs at load.

**Exit:** A complete round trip works. The part is collected once; repair and completion happen once; the radio stays working. Repeated input produces coherent results.

### 4. Preserve progress

- Save phase changes through the ordered atomic writer.
- Restore at the declared safe checkpoints.
- Add Continue and Restart.
- Pause and resume world, controls, dialogue and animation with the app lifecycle.
- Handle a load/save failure visibly.

**Exit:** After each completed checkpoint save, terminating and relaunching gives a coherent scene and the expected progress. Ordinary backgrounding resumes the live scene without stuck input or a large simulation jump.

### 5. Verify the playable

- Add only the environmental details needed to communicate a ruined future and the route.
- Let someone unfamiliar with the prototype attempt it without coaching.
- Repeat full runs and restarts on the physical phone.
- Inspect frame pacing, memory and thermal behaviour during roughly 15–20 minutes of repeated play.

**Exit:** The acceptance criteria below pass. Then review what was enjoyable or unclear before expanding the game.

## Acceptance criteria

- A new player understands why Miki needs the transmitter and can finish the loop without developer guidance.
- The intended route and alternative entrance can be understood from the environment.
- Movement follows screen direction, collision is predictable, and the camera keeps Miki readable.
- The nearby action button offers the right action. Interacting through obstacles or beyond reach is prevented.
- Repair before collection gives an explanation and leaves progress unchanged.
- Collecting the regulator twice is impossible, including after loading.
- The repaired radio enables the call. The meeting plan remains available to reread.
- Completed progress remains complete after relaunch; Restart deliberately begins a clean run.
- Checkpoint restoration works before collection, after pickup, after repair and after completion.
- Backgrounding, interrupted touch, lock/unlock and return to the app do not corrupt progress or leave movement active.
- Target smooth **60 fps on the iPhone 13 Pro Max** with representative placeholder animation and scene load. Measure the result; adjust scope or budget if it misses.
- Repeated restarts show no sustained unexpected memory growth, duplicate callbacks or accumulating scene content.

## Focused verification

Automated checks should cover meaningful behaviour:
- Repair without the part fails; duplicate collection and repair requests have no extra effect.
- Pickup → save → load → return → repair → call reaches completion with a consistent world projection.
- A completed save reloads as complete.
- Ordered writes and restart cannot restore older progress over the latest checkpoint.

Use manual device checks for camera, controls, collisions, lifecycle and performance. Keep the first test suite small; it should catch a broken loop or lost progress rather than mirror every method.

## Outside this prototype

The home departure and bridge scenes, moving companions, NPC pathfinding, combat, health or hunger systems, extra salvage errands, equipment, crafting, branching dialogue, voice acting, cinematics, multiple levels, cloud services and App Store submission.

## What completion tells us

We will have evidence for the Swift/RealityKit asset workflow, phone controls, camera, interaction rules and save/lifecycle boundaries. The next design review chooses one survival pressure or threat to explore and decides how much of Chapter One to build next.

No release date is promised before the actual character, content and device workflow is proven.
