# Follower-spacing correction

**Date:** 17 November 2026

## Assignment and scope

[#28](https://github.com/RonildoBraga/lauder/issues/28) found that followers lost distance when frame times varied and could not regain it while the leader kept running. The maintainer decided to [fix it before TestFlight](https://github.com/RonildoBraga/lauder/issues/28#issuecomment-6942735006) and [authorised the fixed-step approach, including the architecture wording change](https://github.com/RonildoBraga/lauder/issues/28#issuecomment-6942750650). The [README](../README.md) and [prototype plan](prototype-plan.md) own stage and review status.

Claude proposed this fix, implemented it after [Codex's handover](https://github.com/RonildoBraga/lauder/issues/30) and ran the checks below. No other agent has reviewed it yet.

## Cause

A follower may travel at most the leader's full-speed step, and each follower step ends at the next trail node. The leader records one node per update, so with a variable update length the follower's step and the edge ahead no longer match. The difference is lost, and the speed cap prevents recovering it while the leader runs. The [issue](https://github.com/RonildoBraga/lauder/issues/28) gives the measurements and mechanism.

## Change

- `GameWorld.advanceParty` adds each frame's elapsed time, capped at 1/30 s, runs whole **1/120 s** steps and carries the remainder. At most four steps run in one frame. The first update after an interruption discards any remainder rather than replaying it.
- Each step is the previous update body unchanged: trail observation, step preparation, collision resolution and orientation. Camera easing and the nearby-point check run once per frame with the frame's elapsed time.
- No follower-speed change, trail-limit change or `PartyTrail` reconciliation change. No timer; the single owned scene update remains.
- The [architecture](architecture.md#movement-and-presentation) records the fixed step and its trade-off.

Trade-off: bodies move in whole steps without interpolation, so a frame can show up to one step (about 2 cm at full speed) more or less than its elapsed time. The whole-party soak's per-frame travel bound now allows that one extra step.

## Validation

All runs below are in the iPhone 17 / iOS 27.0 Simulator with Xcode 27.2 and synthetic input. None is phone evidence.

- `./scripts/check` passes: formatting, build and Swift Testing, including the new spacing tests and the existing collision regressions and whole-party soaks.
- The new `PartySpacingTests` circle test fails on the code before this change: the farther follower reached **5.00 m** with random 12–24 ms frames, **5.00 m** with alternating blocks of 1/120 and 1/60 s, and **2.67 m** with one 1/30 s frame per second, against a 1.7 m limit. Fixed 1/60 s passed.

**Spacing matrix from #28.** Release build, `GameWorld.advanceParty`, leader at full speed for 60 s, six runs per row. Distance from the leader to the farther follower after the first 5 s; nominal route spacing is 1.6 m and the acceptance limit was 2.4 m.

| Path | Frame times | Worst before | Worst after |
|---|---|---:|---:|
| 2.5 m circle | Fixed 1/60 s | 1.61 | 1.59 |
| 2.5 m circle | Phone-like: 16.6677 ms, one 33.3 ms frame every 500 | 2.02 | 1.59 |
| 2.5 m circle | One 1/30 s frame per second | 3.66 | 1.59 |
| 2.5 m circle | 90-frame blocks alternating 1/120 and 1/60 s | 5.00 | 1.59 |
| 2.5 m circle | Random 12–24 ms | 5.00 | 1.59 |
| Wander, analog headings | Fixed 1/60 s | 2.68 | 2.03 |
| Wander | Phone-like | 2.55 | 2.20 |
| Wander | 1/60 s with 3% jitter | 3.80 | 2.01 |
| Wander | 90-frame blocks alternating 1/120 and 1/60 s | 7.69 | 1.83 |
| Wander | Random 12–24 ms | 8.74 | 2.19 |
| Wander with leader switches | Random 12–24 ms | 6.36 | 1.81 |

All 24 rows of the matrix stay within 2.4 m after the change; the worst is 2.20 m. Fixed 1/120 s rows were already unaffected and are unchanged.

**#25 soak replay.** The four batches from the [#27 review](https://github.com/RonildoBraga/lauder/pull/27#issuecomment-6942687632), 96 sessions of 20,000 frames (1.92 million frames) with the same input: no frozen member, no hold, no non-finite position, travel within the one-step bound, and clearance never below 1.9992 mm. Two half-second leader stops were the body pressed into an inside corner touching two blocks, which is correct. The largest leader-to-follower distance in any session fell from **6.83 m to 3.12 m**.

## Limits

- Simulator and synthetic input only. Not observed by hand or on a phone; the next phone milestone should include long runs without stopping, as listed in [#18](https://github.com/RonildoBraga/lauder/issues/18).
- Frame time no longer causes lag, but changes of speed can. When the leader speeds up after walking slowly along a curve, a follower crosses the short edges recorded meanwhile one per step and loses some distance until the leader slows or stops. This is the likely cause of the soak sessions above 2.4 m, which include slow walking and stops; it was not measured separately. Fixing it would change `PartyTrail`, which this assignment excludes.
- Doubling the step rate at 60 Hz doubles the party update cost per frame. No phone performance result is claimed.
- Independent review is pending; Claude both proposed and implemented this change.
