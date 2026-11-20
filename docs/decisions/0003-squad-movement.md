# ADR 0003 — Squad movement

**Status:** Accepted\
**Date:** 17 November 2026

## Context

The companions should behave **like a coordinated squad rather than just following the player**: one button cycles formations, directional commands position squad members, and companions keep formation, avoid obstacles and react to their surroundings instead of following the leader's exact path. On a phone the controls stay simple while still offering real tactical choices.

"AI" here means ordinary game techniques, pathfinding, steering and simple scoring, all in plain Swift on the device. No machine learning, network service or package is involved.

## What the player experiences

- Companions walk beside and behind the leader in the chosen formation. They do not trace the leader's footsteps; they take their own sensible route around obstacles.
- In a narrow passage they fall into single file, and spread out again afterwards, without a button press.
- When the leader stops, they settle and stay still. When the leader turns round, the group turns with them rather than snapping.
- One button cycles **Close**, **Spread** and **Column**, and calls everyone back after an order.
- The D-pad sends both companions, or one of them, to a spot ahead of the leader, or tells them to hold where they are. On touch, pressing and holding on the ground does the same.
- A companion who cannot reach their spot keeps as close as they can and says so. Nobody teleports, and one stuck companion never freezes the rest of the party.

## Decision

### Ownership

- `GameSession` owns the squad's state as it owns leadership: the formation and each companion's order. It accepts or rejects commands by mode, so Pause and dialogue keep blocking them.
- `InputRules` turns the formation button, D-pad directions and the touch long-press into fresh, edge-triggered intents, with the shared priority and release rules.
- `GameWorld` executes: it moves the leader, works out where each companion should be, and moves them. All movement goes through `PartyMotion`, the plain-Swift collision of round bodies against the level's blocker boxes.

### Formations

Slots are positions relative to the leader, turned to match the leader's heading. Starting values for playtests:

| Formation | Companion slots | Use |
|---|---|---|
| **Close** (default) | 0.9 m to each side, 0.9 m behind | Ordinary travel; mutual support |
| **Spread** | 2.2 m to each side, 0.5 m behind | Open ground and fights: a wider front that is harder to hit together |
| **Column** | 1.0 m and 2.0 m behind, on the leader's own recent route | Sneaking and tight routes: companions walk where the leader walked |

1. **Heading.** The formation turns towards the leader's movement at up to 180° a second, and only while the leader moves faster than 0.5 m/s. A standing leader leaves the formation where it is, so companions do not shuffle.
2. **Validity.** A slot is used only if a body fits there and the straight line from the leader to it is clear (`PartyMotion.canTraverse`), so a slot never lands behind a thin wall.
3. **Compression.** An invalid slot is first pulled halfway towards the leader. If that also fails, the companion takes their Column slot on the leader's route. That makes single file in a narrow passage, and the group re-forms afterwards.
4. **Assignment.** Which companion takes which slot minimises the total distance, and changes only when it saves more than 0.5 m, so companions do not swap sides back and forth or cross paths. A change of formation assigns the new places afresh.
5. **Keep-clear.** Slots are pushed out of very tight cells, and later out of interaction approach areas, so companions do not settle in a doorway or in front of something to use.
6. **Route memory.** A short record of the leader's last 6 m places Column slots and the compression fallback; companions still steer to them.

### Orders

Each companion is **following**, **going** to a point, or **holding** a point. Orders persist until replaced.

| Command | PS5 / Xbox | Touch | Effect |
|---|---|---|---|
| Both companions go | D-pad up | Press and hold on the ground, release | Both move to spots around the marked point and hold |
| One companion goes | D-pad left or right | Press and hold, slide to their name, release | That companion moves to the point and holds |
| Hold | D-pad down | Press and hold, slide to **Hold**, release | Both stop where they are and hold |
| Follow; cycle formation | Triangle / Y | Formation button | If anyone is going or holding, everyone follows again in the current formation; otherwise the formation cycles |

The Simulator keyboard's arrow keys act as the D-pad. Orders are offered with the formation button, once the leader has two companions, since that button calls everyone back; on the bridge, once Laura joins.

- **The marked point.** On a controller it is up to 6 m ahead along the leader's heading, shortened by the first wall and moved to the nearest reachable spot within 1 m. On touch it is the ground under the finger, or the block the finger presses on, since it is what the camera's ray through the finger meets first; holding for about 0.35 s opens a small menu there with **Both** (release without sliding) in the middle, each companion's name to its left and right, and **Hold** below. Sliding up, or moving before the menu opens, gives no order. A point that cannot be reached shows a brief cross, and nothing happens.
- **Spots.** Two companions sent together take spots 1 m apart around the point, side by side across the line from the leader where they fit, by least walking in total. One sent onto the other's point stands 1 m from it. A going companion holds once within 0.35 m of their point.
- **Left and right.** The companions keep a fixed order, shown on the HUD as "◀ Laura · Tom ▶" for whoever leads, which is easier to learn than working out who stands on which side of the screen: the member before the leader in the switching order is on the left, and the one after, whom **Next** would lead as, on the right.
- **Feedback.** Each going companion gets a ground marker, a ring in their colour, until they arrive. The HUD shows the formation and the squad's state, such as "Close · following" or "Laura holding", and the formation button reads **Follow** while anyone is going or holding.
- **Scenes.** A scene for the whole party, such as the end of the opening, waits until both companions are within 5 m of the leader, so companions left holding must be called back first.
- **Switching.** The new leader's order is cleared. The previous leader takes the squad's state: if the others are holding, they hold where they stand; otherwise they follow.

### Navigation

- **Grid.** A 0.2 m grid over the level marks a cell walkable when the body's radius, plus a 2 mm collision skin and a 3 cm margin, fits there. It is built once when the level loads, with connected areas labelled, so an unreachable target is recognised without a search.
- **Routes.** If the straight line to the target is clear, the companion goes straight. Otherwise an A* search on the grid, in eight directions without cutting corners, finds a route, which is then straightened with `canTraverse`. A route is recomputed when its target moves more than 0.5 m, at most every 0.25 s for each companion, staggered so the two never plan in the same step.

### Motion

Each companion steers towards the next point on their route, and `PartyMotion` moves them, sliding them along walls.

- **Speed.** A companion matches their slot's movement and adds a correction towards it, so they keep pace with a moving leader. The correction allows up to 1.25 times the leader's speed when more than 1.5 m from the slot, so they never fall permanently behind. Towards a still target they slow within 0.8 m and stop within 0.25 m.
- **Settling.** A settled companion stays put until their slot is 0.6 m away, which removes idle shuffling.
- **Smoothness.** Acceleration and turning are limited, so they never snap. They face where they move, and when settled, the formation's heading.
- **Personal space.** Party members do not collide with one another; a gentle push keeps their centres about 0.75 m apart, and a companion in the leader's way steps aside.
- **Personality.** Reactions start a fraction of a second apart, so the group does not move as one block; the difference never makes orders unreliable.

### When something goes wrong

- A companion whose target cannot be reached goes to the nearest reachable spot, and the HUD says so.
- A companion who makes no progress for a second has their route recomputed. After three failed attempts they hold where they are, with a message, and resume by themselves when a route appears or on the next Formation press.
- The leader and the other companion keep moving throughout. Nobody teleports, and the party never freezes as a whole.
- Any later regroup option needs the maintainer's approval, and may only move a companion who is not leading to an authored safe point in the same reachable area, out of the camera's view at both ends, without crossing a closed barrier or changing the story's progress.

### Combat positioning

Designed together with the combat systems, since it needs their threats and sight rules:

- **Cover near the slot.** In a fight, each companion looks for the best spot within about 1.5 m (Close) or 2.5 m (Spread) of their slot or order point. A spot scores for being hidden from the most dangerous threat, having a firing position close by, being near the slot and being reachable without crossing open ground. They commit to it for at least two seconds.
- **Personality.** Miki prefers 6–10 m from her target with a clear line. Laura prefers an angle away from a threat's facing. Tom prefers to stand between a close threat and a teammate. These preferences only weigh the choice; orders still win.
- **Sight-aware routes.** Grid cells that an alert threat can see cost more to cross, using the sight rule in [The Quiet Yard](../encounters/the-quiet-yard.md). The same cost keeps following companions out of a patrol's view on a quiet approach, where another route exists.
- **Withdrawal.** A Formation press during a fight means "regroup": companions stop pressing targets and follow on sight-aware routes.

## Options considered

| Option | Benefit | Why not |
|---|---|---|
| A recorded trail of the leader's footsteps | Simple and predictable | It is the "exact footsteps" behaviour the squad replaces; only its route memory survives, for Column |
| Steering only, no pathfinding | Least code | Companions stall behind walls |
| A visibility graph around box corners | Exact shortest routes | Overlapping and touching boxes need special cases; a grid also gives reachability and nearest-spot queries |
| Apple's GameplayKit graphs and agents | Ready-made pathfinding and steering | Its agents move themselves, a second movement model beside `PartyMotion`; the plain-Swift parts needed are small and testable |

## Phases

Each phase is its own assignment and pull request.

| Phase | Adds | Exit check |
|---|---|---|
| **S1** Natural following, built | Grid, routes, the Close formation, motion, switching, and keep-clear for tight cells | No companion gets stuck; while the leader runs in open ground, each companion is within 0.6 m of their slot 90% of the time; a settled companion stays still while the leader stands; soak tests show no stuck member, no overlap with blockers and nothing non-finite |
| **S2** Formations, built | Spread and Column, the cycle button, compression and the HUD label | Each shape holds in open ground, compresses through narrow passages and re-forms; changing formation mid-run crosses no paths |
| **S3** Orders, built | D-pad and touch commands, markers | Orders reach their spots; unreachable spots are refused visibly; switching while holding follows the rule; the touch long-press never fights the stick or buttons; a phone check of the controls |
| **S4** Combat positioning | Cover choice, personality weights, sight-aware routes | Designed and checked with the combat systems |

Tuning values are starting points and will change in playtests. If a phase is not reliable after three focused work sessions, stop and reassess with the maintainer.
