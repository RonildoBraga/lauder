# ADR 0017 — Keep only the Brooklyn Bridge

**Status:** Implemented, checked, reviewed, merged in PR #122 and delivered in TestFlight 0.1.0 (27)

**Date:** 22 November 2026

## Assignment

The maintainer reported that the game was not enjoyable and asked to remove unused material before reconsidering the design: **“the only scene I want to keep is the bridge scene, all the other scenes should be deleted and everyhing left over should be deleted”.**

This authorises removal of CombatYard, SalvageYard and RelayRun and their dedicated source, controls, tests, debug routes and procedural documentation. It does not assign replacement mechanics, a narrative rewrite, new art or another scene.

## Boundary

Keep the bridge's existing opening, native weapons, encounters, recruitment, party switching, formations/orders, camera, controller/touch/keyboard path, Blender source and shared assets. Remove arena waves, extra test weapons, terrain, automatic combat cover, tactical enemies, grenades, signatures, companion auto-fire and salvage-repair machinery that no retained scene uses. Remove the level selector, transition caches and instrumentation serving those visits.

Small test-only geometry remains where it verifies bridge navigation or weapons. It is outside the app target, not another playable scene. Preserve story foundations and clearly unassigned narrative proposals, historical decisions, Git history, private release evidence and unrelated user data.

## Consequence

[README](../../README.md), the [architecture](../architecture.md), [walkthrough](../gameplay-script.md) and [prototype plan](../prototype-plan.md) describe current scope. Older experiment records remain historical evidence; their past assignments do not authorise restoration after this reset. The next implementation requires a concrete gameplay question and bounded assignment. The reset passed the standard check and retained bridge Simulator checks; the [prototype plan](../prototype-plan.md#verification-and-performance) records the exact source and evidence. App/archive source `de4d0db` matches checked/reviewed `feabb43`. The signed 0.1.0 (27) archive was verified; Apple confirmed completed upload, successful processing and availability to existing internal testers with membership unchanged. The prototype plan records the UTC proof. No new phone result is claimed.
