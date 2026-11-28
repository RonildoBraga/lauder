# ADR 0016 — Combat balance and readable counterplay

**Status:** Implemented, checked, reviewed, merged and delivered in TestFlight 0.1.0 (26)\
**Date:** 22 November 2026


**Current scope:** The bridge-only reset retired the non-bridge experiments described here. Shared rules remain only where the bridge uses them; this record preserves the earlier decisions and measurements, not an assignment to restore deleted systems. See [ADR 0017](0017-bridge-only-reset.md) and the current [architecture](../architecture.md).

## Assignment

The maintainer replied **“Proceed”** to a focused pass on weapon strengths, readable enemy counterplay and useful companions in the existing arena. [Issue #118](https://github.com/RonildoBraga/lauder/issues/118) records that assignment. Simulator iteration, reviewed integration and internal TestFlight delivery continue; physical and subjective checks remain deferred. This adds no story encounter, ability, inventory, art production or control button.

The following are provisional implementation choices under that assignment, not additional quoted maintainer decisions. Exploration and salvage still lead. [ADR 0015](0015-weapon-variety-and-map-range.md)'s build 25 values form the baseline; this record supersedes its scatter timing and passive precision-targeting defaults.

## Measure before changing the profiles

`CombatBalanceTests` (retired; retained in Git history) uses production `WeaponHandling`, `Scatter`, `SeededRandom` and three-dimensional `Ballistics` against a stationary body. Each of six weapons runs for 20 seconds with 16 fixed seeds, at 5, 10, 20 and 40 metres, both settled and with the full-speed dispersion penalty. The latter is a spread experiment, not moving navigation or a model of player skill. Rays are explicitly directed without target assistance. Passive target selection is measured separately through `FightSimulation`.

Accuracy keeps sampling after the first six hits. Times and rounds describe the first six-hit defeat, including draw/reload waits. Medians include **completed trials only**; completion counts accompany censored cases, and incomplete rows do not imply a population median. Every trial in the following 5 m settled comparison completed:

| Weapon | Build 25 median seconds | Tuned median seconds | Tuned median rounds |
| --- | ---: | ---: | ---: |
| Carbine | 2.39 | 2.39 | 6 |
| Burst | 2.82 | 2.82 | 6 |
| Scatter | 3.73 | 2.18 | 3 |
| SMG | 0.83 | 0.83 | 6 |
| Marksman | 3.38 | 3.38 | 3 |
| Support | 1.47 | 1.47 | 6 |

Scatter's slower close result contradicted its intended use. Its interval changes from **1.5 to 0.8 s** and draw from **0.7 to 0.55 s**. Damage, spread, magazine and reload stay as before. At 10 m its stopping bonus is lost and the tuned completed-trial median remains **10.24 s**, preserving a substantial range cost. Enemy rusher timing still comes from its encounter specification; its damage is not increased. The other weapon profiles need no speculative numerical change in this pass.

## Keep long rounds separate from automatic knowledge

The baseline marksman automatically selected a body 44.7 m away, and an equipped companion fired at it. `Weapon.assistanceRange` now uses an optional local limit: **22 m** for the marksman, with other profiles retaining their prior reach. Passive Fire, companion acquisition and automatic cover positioning share this distance.

Explicit stick/touch aim retains the existing **8-degree cone and real sight checks** through effective reach. This matters for height: a deliberate precision shot must still reach a raised or lowered body beyond the passive limit. The marksman's effective stopping reach remains **64 m** and its actual fired ray still crosses the level until a real body, cover, gate or terrain stops it. Aiming away does not select a distant body. This is bounded passive assistance, not a camera-frustum or new aiming framework.

## Preparation survives neither movement nor array order

Production regressions reproduced a flanker arriving with only **0.20 s** left from an old **3.2 s** wind-up, and a queued pre-movement round replaying on arrival. Arena tactical movement now cancels queued rounds and restarts only unfinished aiming. Arrival reaction and post-shot recovery still have to finish; moving does not refill or bypass them. The original authored non-arena handling stays separate.

The HUD and bearing share the **soonest currently preparing attack**, with stable actor-ID ties. They no longer favour an actor because it appears last in a level array or carries a long gun. The selection is refreshed after party fire so a downed actor cannot own the next warning. It describes preparation, not a new ranking of in-flight grenades or committed burst bullets.

Pooled, world-attached overhead bars show remaining preparation for the arena's actual acquired wind-ups. They retain their orientation as actors turn, freeze on Pause and disappear when their wind-up is interrupted, on death or Restart. Existing role silhouettes remain; no direction ray or future impact endpoint is displayed.

## Make way without losing the ordered place

A settled companion at a static order/cover anchor could wake for an approaching leader, then immediately settle again before taking its intended side step. The regression measured a closest gap of **0.216 m**, below the **0.52 m** body diameter. The settle branch now respects the active dodge. Side-step urgency stays full while predicted bodies overlap and tapers through the existing **0.52–0.8 m** clearance band; detection range, prediction horizon, maximum speed, acceleration and order ownership remain as before.

[CompanionYieldTests](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/apple/tests/CompanionYieldTests.swift) verifies immediate yielding, body-diameter clearance in an open lane, return to the original anchor, and stationary/parallel-leader controls. It does not promise an escape when a side is obstructed. Friendly bodies already do not block party shot damage; this pass introduces no friendly-fire or body-block rule and does not attribute all companion-pair overlaps to this defect.

## Validation and delivery

The standard check passed: 51 Blender tests, ten generated sounds, strict formatting, the app build and Swift Testing, including all 18 headless scenarios and 30-wave integration. Coverage includes the measured weapon roles, passive/explicit targeting at both terrain tiers, aim-away safety, movement-carried aim and bursts, warning priority/ties, preparation presentation, yielding, Pause, Restart and bounded entities. [PR #119](https://github.com/RonildoBraga/lauder/pull/119) merged as `25195e8`, with the exact tree of checked/reviewed `c80a7ac`. Four ordinary-input rendered routes passed on that source: `arsenal-bench` **167/167**, `combat-yard` **101/101** through wave 3, `enemy-arsenal` **35/35** with actual firing/recovery and retreat, and `relay-run-retreat` **104/104**. The world-space preparation bar was inspected above its actor with the same HUD/bearing warning. Automatic source review completed without findings; Claude had not replied to the GitHub request at integration, so no completed Claude review is claimed.

The signed **0.1.0 (26)** archive from main `25195e8` passed bundle, version/build, team, signature and matching-dSYM verification. API-authenticated upload is **COMPLETE** with zero errors, processing is **VALID**, and the unexpired build is **IN_BETA_TESTING**, **INTERNAL_ONLY** and available to the existing internal testers with group/tester membership unchanged. [The prototype plan](../bridge-prototype-plan.md#combat-balance-and-readability) owns exact-source results, measurements and delivery proof, preserving the earlier build 25 evidence as historical.

These measurements establish repeatable mechanics. Phone frame pacing, thermals, physical controls/haptics and whether combat is enjoyable remain unverified in the [deferred checklist](../bridge-prototype-plan.md#deferred-phone-and-playtest-checks).
