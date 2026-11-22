# Relay Run — gameplay walkthrough

**Status:** Standalone prototype prepared; Simulator and release verification pending\
**Date:** 22 November 2026

The maintainer approved this next mission with **“Proceed with your recommendation”**. [ADR 0013](decisions/0013-relay-run.md) owns its scope, technical defaults, implementation sequence and acceptance criteria.

This is a short, continuous salvage journey with the whole trio. Story placement and the sample lines below remain provisional; the mission does not settle where [Relay House](story/story-bible.md#later-scene--relay-house) belongs or reveal anyone's hidden past. Duration comes from playtesting.

From the bridge, use **Pause → Combat test**, then **Pause → Salvage test**, then **Pause → Relay mission**. The relay mission's next-level choice returns to the bridge.

## 1. A reason to leave the shelter

Miki, Tom and Laura stand together beside a broken transmitter. Its aerials make it recognisable from the elevated camera. The objective is **Find a compatible regulator in the depot**. The opening line explains the part's purpose and the return journey.

> **Miki:** The transmitter needs a regulator. The depot is ahead; we come back together.

Any of the three can lead, with the other two following. The shelter remains the visible place to return to, not a stationary role assigned to one of the trio. The objective and compass guide the outward trip to the depot. The controls are the current stick/WASD movement, leader switch, contextual action, formations and orders.

## 2. Read the route

A short frozen district opens ahead. A service wall and simple landmarks divide two ways to the same depot:

- **The safe detour** takes the group around the defended frontage. It is wide enough for the companions and stays clear of the guard's view and defended area.
- **The guarded shortcut** is shorter and visibly occupied. From a covered approach the player can see the guard and the marked boundary before stepping into it.

> **Laura:** The covered west lane goes around. The shorter cut is guarded.

The player can take the detour immediately. There is no reward or required part that secretly makes the guard compulsory. Companions follow the route choice rather than beginning a fight because they can see a hostile nearby.

## 3. Open access for everyone

Both routes reach the depot's service barrier. Its latch and loose panel are readable interaction points, using the current amber markings and prompts.

If Laura leads, **Reach the latch** opens the gate. If Tom leads, **Shift the panel** opens it instead. Miki's prompt can say who could help. Either action opens the same passage for the whole party. The player does not perform both in sequence or leave a character outside to hold a switch.

The gate stays open for the return. Ordinary movement, rather than a travel button, carries the group into the depot.

## 4. Take what is useful, leave what still serves

Three cabinets hold the compatible regulator, a wrong model and equipment still feeding another shelter. Each run deals them afresh.

Miki can **Inspect**, identify the compatible disconnected part and take it. Another leader can **Search** without identifying the model first. A mistaken part can be carried back, but a failed fit explains the error and directs the player towards Miki's expertise. Knowledge is shared; once inspected, the usable part is anyone's to collect.

The live cabinet stays connected for everyone:

> **Miki:** This one is still feeding the next shelter. Leave it connected.

This is a practical observation about people still using the district. It is not a moral-choice screen or an explanation of the war. The compatible regulator comes from separate equipment and goes into the current shared bag.

## Optional branch — contact at the shortcut

Entering the marked frontage in clear sight can alert the stationary guard, whether it sees the leader or a companion. Its warning precedes its normal rifle wind-up. No hit is required to learn that the route is defended.

The player may use ordinary weapons and cover, with companions defending once the encounter begins. The guard holds its post and targets party members within the marked frontage under the current sight and range rules. Miki's existing Disrupt can interrupt a wind-up. Laura and Tom remain viable leaders with their current weapons; no new ability or required three-character combo is introduced.

**Turn back:** walk behind the service wall and use Regroup if companions need recalling. They stop trying to finish the guard and come back. Everyone must get safely clear before contact ends. A companion left exposed is still a participant, and switching leaders does not dismiss the encounter.

The party keeps the part, gate access, cabinet knowledge and damage dealt to the guard. The player can continue by the safe route, or return later in the same run to a guard with the same remaining damage. A third-hit fallback remains a separate recovery outcome.

The repair remains achievable even if the player never engages or defeats this guard.

## 5. Return with a purpose

With a regulator that might fit in the bag, the objective and compass point back to the shelter, including after a blind search. Guidance does not reveal a part's hidden model. The bag and contextual **Fit regulator** prompt make the next action clear. Fitting the compatible part consumes it and restores the transmitter; a wrong model does neither, and recognising that mistake returns guidance to the depot.

Everyone must be out of the guarded encounter and gathered beside the leader at the transmitter before a fit attempt. If a companion is still away, the action asks the player to bring everyone back; Regroup or Follow can recall them.

The transmitter changes from faded teal to amber, and the objective reads **Signal restored. The trio can travel on together.** A brief provisional exchange gives the journey a human finish:

> **Miki:** The transmitter answers.
>
> **Laura:** Someone will hear it.
>
> **Tom:** Then we leave it working.

No relationship reveal, global explanation or promise of a new destination is established by these lines. The three have simply made something useful work again. The player can walk around the completed place, restart for another run or use the existing pause-menu level choice.

## What play should answer

- Can the player understand the goal, both approaches, the guarded boundary and the way home from the camera?
- Does switching follow a useful reading of the place rather than a checklist?
- Do inspection, the wrong model and the live supply make salvage feel purposeful?
- Does the optional threat create a choice while avoidance and a whole-party retreat remain credible?
- Does returning and repairing give the outward journey a satisfying end?

Scripted Simulator routes verify the flow and state rules first. Actual phone performance, physical controls and the maintainer's answers remain unverified until tested and recorded; implementation or TestFlight delivery alone supplies none of those answers.
