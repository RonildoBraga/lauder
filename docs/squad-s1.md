# Squad movement, phase S1

**Date:** 17 November 2026

## Assignment and scope

The maintainer [accepted ADR 0003](https://github.com/RonildoBraga/lauder/pull/32#issuecomment-6944093756) and assigned its first phase before Party B: **“Accept, S1 first”**. [ADR 0003](https://github.com/RonildoBraga/lauder/blob/a5437e5/docs/decisions/0003-squad-movement.md) sets the scope and exit checks. The [README](../README.md) and [prototype plan](prototype-plan.md) own stage and review status.

Claude implemented and checked this phase after [Codex's handover](https://github.com/RonildoBraga/lauder/issues/30). Claude also wrote the design, so nothing below is an independent review.

## What changed

- **`NavigationGrid`:** a 0.2 m grid over the authored rectangles, with walkable, doorway-like and connected-area labels, A* routes that never cut past corners, and route straightening against `PartyMotion`.
- **`RouteMemory`:** the leader's last 6 m of travel, for the narrow-place fallback.
- **`SquadPlanner`:** Close formation slots, 0.9 m to each side and 0.9 m behind, turning with the leader at up to 180° per second. A slot that does not fit is pulled halfway in, then moved onto the leader's route, and spreads out again once it has fitted for 0.3 s. Assignment and route order change only for a clear gain. A waiting companion stands clear of doorways.
- **`CompanionMotor`:** steering that matches the leader's movement and closes the gap, catch-up up to 1.25× the leader's speed, limited acceleration, settling without shuffling, soft personal space, making way for the leader, and small reaction delays (Lara 0.1 s, Miki 0.15 s, Tomas 0.2 s). A companion that stalls re-plans; after three stalls they wait, the HUD names them, and they retry by themselves.
- **`GameWorld`:** runs the leader, then the planner and motors, every fixed step, with every movement still resolved by `PartyMotion`. A leader change is picked up inside the step, so switching works from any caller.
- **Retired:** `PartyTrail` and its tests, 968 lines. The party-wide movement hold is gone; the HUD line no longer says the party has stopped, because it has not.

## Validation

All results are from the iPhone 17 / iOS 27.0 Simulator with Xcode 27.2. None is phone evidence.

- `./scripts/check` passes: formatting, build and Swift Testing, including 11 new squad tests and the existing collision regressions, soaks and spacing tests.
- **A crash found and fixed during these checks.** A fallback place behind a leader standing at an outer wall could fall beyond the floor, and the route search then formed an invalid range. The search now refuses such points and the fallback is checked; two regression tests cover it. The suite had passed before the fix, so the long runs below were what found it.
- **Rendered check.** A Debug build ran in the Simulator with touch controls. Driving with the on-screen stick, Miki led and Lara and Tomas walked in a wedge behind and to either side rather than in single file on her path, with no HUD warning. This was a short single-pointer check, not a playtest of the route.

**Soak replay.** The four random-play batches used for #25 and #31, with the same stick input: 96 sessions of 20,000 frames, 1.92 million frames in all, Release build. Checked every frame for every member: finite position, travel within the leader's speed (1.25× for companions) plus one carried step, and the 2 mm skin from an oracle independent of `PartyMotion`.

| Batch | Input | Warnings | Stuck | Skin, travel or non-finite faults | Bodies overlapping | Within 0.6 m of slot while the leader moves | Within 1 m | Over 1.5 m from slot for 2 s |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| A | Analog, 40% along walls | 0 | 0 | 0 | 8.7% of frames | 48% | 73% | 5 times |
| B | Analog, free headings | 0 | 0 | 0 | 10.3% | 46% | 72% | 6 |
| C | Keyboard | 0 | 0 | 0 | 9.5% | 55% | 76% | 0 |
| D | Batch A with a switch about every 20 frames | 0 | 0 | 0 | 16.7% | 29% | 51% | 53 |

"Bodies overlapping" counts frames where any two centres are closer than two body radii. On the same input (batch B, six sessions) the retired trail overlapped in **33%** of frames; this phase overlaps in 10.5%. Most remaining overlaps happen while the leader is moving, and about a third come within 1.5 s of a switch.

The random input changes direction every 5 to 120 frames and often reverses, so slot figures here are much lower than in the straight-run test. Companions also wait for the leader to pass instead of cutting across their path, which keeps overlaps down but makes them slower to regain their slot after a reversal.

**Spacing matrix from #28.** Distance from the leader to the farther companion after the first 5 s, six runs per row, leader at full speed, Release build:

| Path | Before, recorded trail (#31) | Now |
|---|---|---|
| 2.5 m circle, every frame-time pattern | 1.59 m | 1.40–1.41 m |
| Analog wander, mean | 1.22–1.41 m | 1.18–1.31 m |
| Analog wander, worst moment | 1.83–2.20 m | 2.65–3.42 m |
| Wander with leader switches, worst moment | 1.80–2.05 m | 2.74–3.39 m |

Frame times still make no difference: rows with steady and uneven frame times give the same figures. The worst moments are higher than with the trail, which never let a follower leave the leader's path. They come from reversals, when the formation flips and companions step aside to let the leader through before falling in behind.

**Timing.** The party update took 0.012 ms per frame on average, 0.024 ms at the 99th percentile and at most 0.28 ms, measured in the Release Simulator on a Mac. That is far inside the ADR's phone target, but it is not a phone measurement.

## Exit checks

| ADR 0003 exit check | Status |
|---|---|
| Service-opening round trip under each leader, no stuck companion | Passes: `everyLeaderTakesThePartyThroughTheServiceOpeningAndBack`, all three leaders |
| In open ground, each companion within 0.6 m of their slot 90% of the time | Passes for a straight full-speed run: `companionsKeepCloseSlotsBesideTheLeadersPathInOpenGround`. In random play the figure is lower; see Validation |
| A settled companion does not move while the leader stands still | Passes: no movement at all over 5 s in `settledCompanionsStayStillWhileTheLeaderWaits` |
| #25 and #31 soak batches: no stuck member, no penetration, nothing non-finite | Passes in the Simulator replay under Validation |
| Maintainer playtest in Simulator, then the baseline phone with controller and touch | **Partly done.** On 18 November the maintainer played a Release build on the baseline iPhone and reported: “it looks good”. Which inputs and situations were tried was not recorded, and a Simulator playtest was not separately reported |
| Phone timing: party update under 1 ms per frame on average, no frame over 4 ms | **Pending**; only Mac Simulator timings exist |

## Limits

- Apart from the maintainer's short phone verdict above, the checks used the Simulator, synthetic input and a short rendered touch check. Reversals, switching and the doorway behaviour have not been reported on from the phone.
- Overlaps are reduced, not removed: about 9–10% of frames in random play, mostly after sharp turns and switches.
- Worst-moment spacing is larger than with the trail (up to about 3.4 m during reversals). The figure that #28 used, 2.4 m, was set for trail following; whether the new behaviour reads well is a playtest question.
- Only the Close formation and following exist. Spread, Column, the formation button and orders are phases S2 and S3.
- Tuning values are the ADR's starting points apart from three rules added during these checks: the formation flips on a reversal sharper than 110°, the route memory restarts after a reversal, and companions anticipate the leader's path and do not cross it while the leader is bearing down.
- Claude wrote the design and this implementation and ran every check, so nothing here is independent.
- This is the first of S1's three focused work sessions under the ADR's stop rule.
