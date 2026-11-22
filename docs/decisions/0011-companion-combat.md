# ADR 0011 — Shared cover and coordinated companions

**Status:** Implemented and delivered in TestFlight 0.1.0 (21)\
**Date:** 22 November 2026


**Retired implementation:** The bridge-only reset removed this experiment and its dedicated runtime. This record preserves the assignment, decisions and historical delivery evidence; it is not current playable scope. See [ADR 0017](0017-bridge-only-reset.md) and the current [architecture](../architecture.md).

## Assignment

After phase 3, the maintainer instructed: **“Continue until the end where everything is delivered and continue testing using the simulator and continue to deliver to my phone using the test Flight but don’t stop on every milestone delivered unless you have questions for me”.** This assigns the remaining phases of the current [combat plan](0008-weapon-feel-and-combat-plan.md), integration of the reviewed work and TestFlight delivery without repeated milestone approval. It supersedes the earlier separate delivery/merge gates for this work. Physical-device evidence remains distinct from Simulator checks.

This record covers phase 4, [issue #94](https://github.com/RonildoBraga/lauder/issues/94). These are implementer-selected prototype details under that assignment, not additional quoted maintainer choices.

## Decisions

- **The combat yard only.** Companions use the same proximity, low-cover rise, tall-edge clearance and 0.3-second firing exposure as the leader in [ADR 0009](0009-leader-cover.md). The bridge and salvage rules retain their defaults.
- **One rule, three stances.** Each party member has an independent cover stance. Incoming damage, outgoing shots, warning lines, whole-figure poses and their directional ground shield use the same effective point and blockers. The movement anchor stays at the selected cover spot; a valid peek moves the presentation and firing point, not the body motor.
- **Focus fire without another button.** A companion prefers the leader's assisted target when it is targetable, in the companion's weapon range and has a clear firing path. Otherwise it chooses its own nearest valid target. Companions never start a fight or activate signatures themselves.
- **Cover can become unsafe.** A changed threat exposing a previously protected side invalidates the planner's usual two-second commitment. It can choose a better nearby shelter, respecting the existing formation/order radius, spacing and character preferences. It does not chase a threat or ignore a move/hold order. Known exposure does not trigger a costly rescan every fixed step.
- **Orders keep priority.** Regroup suppresses companion fire; explicit move and hold points bound their choices as before. A companion ducks while an enemy winds up at it. Pause freezes movement, reloads and exposure; switching, fallback and Restart clear temporary cover state.

## Validation and limits

Focused tests cover shared cover geometry, exact-step exposure, focus-fire fallback, flanking, order bounds and lifecycle. The final integrated source `cec1a33` passed the standard check, all thirteen headless scenarios and six rendered Simulator regressions, including squad weapons, combat, cover, tactical enemies, the opening's first fight and salvage. Automatic source review completed with no findings. A fresh signed Release archive passed bundle, signing and symbol verification, and **0.1.0 (21)** completed Apple processing and became available to the existing internal TestFlight testers. The [prototype plan](../prototype-plan.md#verification-and-performance) records the delivery evidence.

Simulator results and TestFlight availability do not establish phone performance, physical multi-touch, haptics or controller feel. The later maintainer judgement “Do they fight like a squad?” remains a playtest question rather than a recorded result.
