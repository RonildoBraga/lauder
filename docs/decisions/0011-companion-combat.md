# ADR 0011 — Shared cover and coordinated companions

**Status:** Implemented; final Simulator/release verification in progress\
**Date:** 22 November 2026

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

Focused tests cover shared cover geometry, exact-step exposure, focus-fire fallback, flanking, order bounds and lifecycle. Rendered squad/combat/cover routes exercise the integrated rules; the existing opening and salvage scenarios remain regressions. The standard check and Release build pass before integration and delivery. Simulator results do not establish phone performance, physical multi-touch, haptics or controller feel. The later maintainer judgement “Do they fight like a squad?” remains a playtest question rather than a fabricated result.
