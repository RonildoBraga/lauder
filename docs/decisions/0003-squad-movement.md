# ADR 0003 — squad movement

**Status:** Proposed for the maintainer's review. Not accepted and not assigned for implementation. Once accepted and its first phase lands, it replaces the following method of [ADR 0002](0002-party-following.md).\
**Date:** 17 November 2026\
**Deciders:** Maintainer, pending review\
**Author:** Claude, continuing after the [handover in #30](https://github.com/RonildoBraga/lauder/issues/30)

## Context

The maintainer asked for companions that behave **“like a coordinated squad of soldiers rather than just following the player”**: a button that cycles formations, directional-pad commands to position squad members, and companions that keep formation, avoid obstacles and react to their surroundings instead of following the player's exact path. They asked for the characters' combat identities first; those were [agreed on 17 November 2026](https://github.com/RonildoBraga/lauder/pull/29#issuecomment-6943836774), with the instruction to start this design. The [combat design review gate](../prototype-plan.md#combat-design-review-gate) quotes the full request. Controls should stay simple on a phone while offering real tactical choices.

Today the two companions walk the leader's recorded trail ([ADR 0002](0002-party-following.md)). That was chosen to prove switching and following on one short route, and the options table there already named general navigation as the candidate for "varied destinations and larger levels".

This design keeps most of what exists:

- **Kept:** the plain-Swift collision resolver against the authored rectangles ([#27](https://github.com/RonildoBraga/lauder/pull/27)), the fixed 1/120 s simulation step ([#31](https://github.com/RonildoBraga/lauder/pull/31)), `GameSession` as the owner of commands, the shared `InputRules`, the camera and the touch surface.
- **Retired once phase S1 lands:** `PartyTrail` and its tests (about 970 lines together), the trail limits and the party-wide movement hold.

"AI" here means ordinary game techniques (pathfinding, steering and simple scoring), all in plain Swift on the device. No machine learning, network service or new package is involved.

## What the player experiences

- Companions walk beside and behind the leader in the chosen formation. They do not trace the leader's footsteps, and they take their own sensible route around obstacles.
- In a doorway or narrow passage they fall into single file and spread out again afterwards, without any button press.
- When the leader stops, they settle and stay still. When the leader turns round, the group turns with them rather than snapping.
- One button cycles **Close**, **Spread** and **Column**. The same button calls everyone back after an order.
- The D-pad sends both companions, or one of them, to a spot ahead of the leader, or tells them to hold where they are. On touch, pressing and holding on the ground does the same.
- A companion who cannot reach their spot keeps as close as they can and says so. Nobody teleports, and one stuck companion never freezes the rest of the party.

## Decision

### Ownership

- `GameSession` owns the squad state as it owns leadership: the current formation and each companion's order. It accepts or rejects commands by mode, so Pause and dialogue keep blocking them.
- `InputRules` turns the formation button, D-pad directions, the previous-leader button and the touch long-press into fresh, edge-triggered intents, with the existing priority and release rules.
- `GameWorld` executes: it moves the leader as now, then works out where each companion should be and moves them. All movement still goes through `PartyMotion`, so the collision guarantees from #25 carry over.

### Formations

Slots are positions relative to the leader, turned to match the leader's heading. Starting values for playtests:

| Formation | Companion slots | Use |
|---|---|---|
| **Close** (default) | 0.9 m to each side, 0.9 m behind | Ordinary travel; mutual support |
| **Spread** | 2.2 m to each side, 0.5 m behind | Open ground and fights: a wider front that is harder to hit together |
| **Column** | 1.0 m and 2.0 m behind, on the leader's own recent route | Sneaking and tight routes: companions walk where the leader walked |

Rules that make slots behave well:

1. **Heading.** The formation turns towards the leader's movement direction at up to 180° per second, and only while the leader moves faster than 0.5 m/s. A standing leader leaves the formation where it is, so companions do not shuffle.
2. **Validity.** A slot is used only if a body fits there and the straight line from the leader to it is clear (`PartyMotion.canTraverse`). That stops a slot landing behind a thin wall.
3. **Compression.** An invalid slot is first pulled halfway towards the leader; if that also fails, the companion takes their Column slot on the leader's route. This produces single file in the 1.8 m service opening and re-forms the group afterwards.
4. **Assignment.** Which companion takes which slot is chosen to minimise total distance, and changes only when it saves more than 0.5 m. Companions therefore do not swap sides back and forth or cross paths.
5. **Keep-clear areas.** Slots are pushed out of interaction approach areas (planned before Party B in the [architecture](../architecture.md#one-interaction)) and out of very tight cells, so companions do not settle in a doorway or in front of a latch.
6. **Route memory for Column.** A short record of the leader's last 6 m of travel replaces the trail graph. It only places Column slots; companions still steer to them.

### Orders

Each companion is **following**, **going** to a point, or **holding** a point. Orders persist until replaced.

| Command | PS5 / Xbox | Touch | Effect |
|---|---|---|---|
| Both companions go | D-pad up | Press and hold on the ground, release | Both move to spots around the marked point and hold |
| One companion goes | D-pad left or right | Press and hold, slide to their name, release | That companion moves to the point and holds |
| Hold | D-pad down | Press and hold, slide to **Hold**, release | Both stop where they are and hold |
| Follow; cycle formation | Triangle / Y | Formation button | If anyone is going or holding, everyone follows again in the current formation. Otherwise the formation cycles |

- **The marked point.** On a controller it is up to 6 m ahead along the leader's heading, shortened by the first wall and moved to the nearest reachable spot within 1 m. On touch it is the ground point under the finger, found with a ray from the camera to the floor; holding for about 0.35 s opens a small menu there with **Both** (release without sliding), each companion's name and **Hold**, which ignores the point. A point that cannot be reached shows a brief cross and nothing happens.
- **Who is left and right.** The two companions keep a fixed order, shown on the HUD as "◀ Lara · Tomas ▶" for whoever is leading. That is easier to learn than working out who is on which side of the screen.
- **Feedback.** Each going companion gets a ground marker in their colour until they arrive. The HUD shows the formation and squad state, such as "Close · following" or "Spread · holding".
- **Switching.** The new leader's order is cleared. The previous leader takes the squad's state: if the others are holding, they hold where they stand; otherwise they follow.

### Navigation

- **Grid.** A 0.2 m grid over the layout marks a cell walkable when the body radius plus 2 mm skin plus a 3 cm margin fits there. The current 28 m × 20 m layout has 14,000 cells. It is rebuilt when a dynamic blocker changes, such as Party B's barrier opening.
- **Paths.** If the straight line to the target is clear, the companion goes straight. Otherwise an A* search on the grid (eight directions, no cutting past corners) finds a route, which is then straightened with `canTraverse`. Routes are recomputed when the target moves more than 0.5 m from the route's end, at most every 0.25 s per companion and staggered, so the two companions never plan in the same step.
- **Reachability.** Connected areas of the grid are labelled when it is built, so an unreachable target is recognised without a search.

### Motion

Each companion steers towards the next point on their route and is then moved by `PartyMotion`, which slides them along walls.

- **Speed.** A companion matches their slot's own movement and adds a correction towards it, so they keep pace with a moving leader instead of trailing by a slowing-down distance. The correction allows up to 1.25× the leader's speed when more than 1.5 m from the slot, so they never fall permanently behind. Towards a still target they slow down within 0.8 m and stop within 0.25 m.
- **Settling.** A settled companion stays put until their slot is 0.6 m away. That removes idle shuffling.
- **Smoothness.** Acceleration and turning are limited, so they never snap. Facing follows movement; when settled, they face the formation's heading.
- **Personal space.** Party members still do not collide with one another, as now. A gentle push keeps their centres about 0.75 m apart. A companion in the leader's way steps aside.
- **Personality.** Reactions start a fraction of a second apart, Lara first and Tomas last, so the group does not move as one block. The difference is small and does not make orders unreliable.

### When something goes wrong

- A companion whose target cannot be reached goes to the nearest reachable spot and the HUD says so, for example "Tomas can't reach that spot".
- If a companion makes no progress for a second, their route is recomputed. After three failed attempts they hold where they are with a message, and resume by themselves when a route appears or on the next Formation press.
- The leader and the other companion keep moving throughout. There is no party-wide freeze and no teleport; the regroup constraint in ADR 0002 still applies to any later proposal.

### Combat positioning (phase S4)

This part is designed together with the combat systems, because it needs their threats and sight rules. The principles proposed now:

- **Cover near the slot.** In a fight, each companion looks for the best spot within about 1.5 m (Close) or 2.5 m (Spread) of their slot or order point. A spot scores for being hidden from the most dangerous threat, having a firing position close by, being near the slot and being reachable without crossing open ground. They commit to it for at least two seconds.
- **Personality.** Miki prefers 6–10 m from her target with a clear line. Lara prefers an angle away from a threat's facing. Tomas prefers to stand between a close threat and a teammate. These preferences only weigh the choice; orders still win.
- **Sight-aware routes.** Grid cells that an alert threat can see cost more to cross, using the sight rule in [The Quiet Yard](../encounters/the-quiet-yard.md). The same cost keeps following companions out of a patrol's view on a quiet approach where another route exists.
- **Withdrawal.** A Formation press during a fight means "regroup": companions stop pressing targets and follow on sight-aware routes.

## Options considered

| Option | Benefit | Why not now |
|---|---|---|
| Keep the recorded trail | Proven by the soaks | It is the "exact footsteps" behaviour the maintainer wants to replace; only its route memory survives, for Column |
| Steering only, no pathfinding | Least code | Companions stall behind walls, for example around the depot |
| Visibility graph around box corners | Exact shortest routes | Overlapping and touching boxes (the depot walls meet) need special cases; a grid also gives reachability and nearest-spot queries for free |
| Apple's GameplayKit graphs and agents | Ready-made pathfinding and steering | Its agents move themselves, which would add a second movement model beside `PartyMotion`; the plain-Swift parts needed here are small and testable |

## Consequences

- ADR 0002's trail, limits, capacity hold and coalescing are superseded when S1 lands. Its no-teleport rule and peer-collision policy stay.
- Companions now leave the leader's route on purpose. Their safety comes from collision and pathfinding, not from re-walking where the leader was, so the soak tests have to cover this.
- Party B's barrier needs only a grid rebuild when it opens. No member-specific routes are needed, because the gameplay script keeps that action on ordinary ground.
- Tuning values above are starting points; they will change in playtests.

## Phases and checks

Each phase is a separate assignment with its own pull request. S1 depends on #27 and #31 being merged.

| Phase | Adds | Exit check |
|---|---|---|
| **S1** Natural following | Grid, routes, Close formation, motion, switching and keep-clear for tight cells; retires `PartyTrail`. Approach-area keep-clear joins when Party B authors those areas | The service-opening round trip under each leader with no stuck companion. While the leader runs in open ground, each companion is within 0.6 m of their slot 90% of the time. A settled companion does not move while the leader stands still. The #25 and #31 soak batches show no stuck member, no penetration and nothing non-finite. Maintainer playtest in Simulator, then the baseline phone with controller and touch. Target on the phone: the party update averages under 1 ms per frame, with no frame over 4 ms |
| **S2** Formations | Spread and Column, the cycle button, compression and HUD label | Each shape holds in open ground, compresses through the service opening and re-forms; changing formation mid-run causes no crossed paths |
| **S3** Orders | D-pad and touch commands, markers | Orders reach their spots; unreachable spots are refused visibly; switching while holding follows the rule; the touch long-press never fights the stick or buttons. Phone check of the controls |
| **S4** Combat positioning | Cover choice, personality weights, sight-aware routes | Designed and checked with the combat systems |

Stop rule, as for Party A: if S1 is not reliable after three focused work sessions, stop and reassess with the maintainer rather than extending automatically.

## For the maintainer

1. **Direction.** Accept this design, which replaces trail following with pathfinding and formation slots once S1 lands. Recommended.
2. **Formations.** Close, Spread and Column as the first three. Recommended.
3. **Orders.** Go (both or one), Hold, and the Formation button doubling as "follow me"; D-pad on controllers, press-and-hold on touch. Recommended; the touch menu should be confirmed in the S3 phone check.
4. **Order of work.** Recommended: S1 before Party B, so Party B is built on the new movement instead of on the trail. Then Party B, Party C, S2 and S3, with S4 alongside the combat systems. The alternative is S1 to S3 before Party B, which brings formations and orders sooner but delays the first playable slice.
5. **Recovery.** Keep "no teleport": companions recover by themselves and never freeze the party. Recommended.
