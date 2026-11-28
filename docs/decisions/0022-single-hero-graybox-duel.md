# ADR 0022 — single-hero graybox duel

**Date:** 28 November 2026. **Status:** assigned implementation experiment; human gameplay acceptance pending.

## Context and authority

The maintainer found the bridge unsatisfying, requested Eitr research and a reuse audit, then approved the recommendations: **“Proceed with your recommendations but don’t forget to open a git issue and track its progress”** (chat, 28 November 2026; no public permalink). [Issue #236](https://github.com/RonildoBraga/lauder/issues/236) tracks the first increment; [#234](https://github.com/RonildoBraga/lauder/issues/234) retains the research decision history.

## Decision

Keep this repository and Swift/RealityKit. Preserve merged bridge and unmerged two-leader work at separate [checkpoints](../milestones/bridge-prototype.md). Replace active bridge/squad/shooting gameplay with one flat primitive duel: sword, directional guard, dodge, stamina and a two-attack opponent.

Retain input/lifecycle safety, swept collision, camera boundaries, deterministic rule/presentation ownership and Apple verification/release tooling. Retire obsolete active source/test/resource requirements together. Preserve authored Blender/art assets and move historical exports outside the app bundle; do not change the existing open Blender scene.

Use one value-only combat clock for preparation, swept contact, recovery and visible blade pose. Keep one app/module. No new dependency, package hierarchy, ECS or generic combat framework.

## Consequences and gates

This supersedes the active bridge runtime scope of ADRs 0017–0021 for this experiment, not their historical evidence or the preserved narrative foundations. The anonymous hero does not settle the game's protagonist or setting.

Parry, charged attacks, more enemies, exploration/progression and artwork wait for the roadmap's playtest gates. Automated checks establish behaviour, not fun or physical performance. Merge and TestFlight release remain separately authorised. The [prototype plan](../prototype-plan.md) owns source-specific verification.
