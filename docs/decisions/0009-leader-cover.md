# ADR 0009 — Cover for the active character

**Status:** Accepted; combat-yard prototype built and checked in Simulator; phone session pending\
**Date:** 22 November 2026

## Context and assignment

Phase 2 of [ADR 0008](0008-weapon-feel-and-combat-plan.md) gives the active character cover. [Issue #92](https://github.com/RonildoBraga/lauder/issues/92) asks for the control style, firing exposure and shield scope before implementation.

Codex recommended: “automatic cover near a wall, a shield indicator only for the active character, and 0.3 seconds of exposure after firing.” After being told this was the next prototype and its control choice was pending, the maintainer answered in the Codex chat: **“Proceed and let me know if you need anything from me”**. This accepts that recommendation and assigns the prototype; the settings are Codex's recommendation accepted by that instruction, not a separate quotation from the maintainer.

The maintainer previously asked to continue building and testing in Simulator and deploy later. This prototype follows that instruction. Phone checks, TestFlight delivery and merge remain separate steps.

## Decision

- **Combat yard first.** Enable this rule only in the greybox combat yard. The bridge and salvage yard retain their current rules. Companions keep their existing cover behaviour; their shared cover rule and shields belong to phase 4.
- **Position, without a button.** Within 0.5 m of a block, measured from the body's edge, a nearby face offers cover. Walking away leaves it immediately. There is no snapping or automatic player movement. The selected face faces the shield; a shot from another side can still reach the character.
- **Low cover.** A block whose top is below the 1.25 m firing height conceals the character only while crouched beside it. Firing rises above it, exposing the character to incoming shots for 0.3 seconds after each shot. A standing character outside cover also receives shots above low blocks; standing farther back must not be safer than taking cover. Tall blocks still stop shots. This height rule applies only to the active character in this experiment.
- **Tall cover.** Near a face's end, a clear lateral peek can place the firing pose past the edge. The same exposed point supplies outgoing shots, incoming shots and hostile warning endpoints. It must fit the body, stay on the floor and have a clear route around other blocks. A valid firing peek stays exposed for the 0.3-second interval even if the weapon turns; movement still revalidates its clearance. In the middle of a wall there is no peek; shots into it stop at the wall. Shooting away from it needs no peek.
- **One shield.** A half-ring on the ground points towards the selected face. It uses the existing signal colour when protected and red while any standing shooter in range has a clear shot at the active character, including during firing exposure or from a flank. The pose also distinguishes crouching from firing.
- **Whole-figure poses.** Lower the figure behind cover, rise above low cover and lean out at a tall edge. Compose these offsets with recoil and hit reactions. No rig, art production or new input control is needed.
- **Lifecycle.** Pause freezes exposure. Restart, fallback and a leader change clear it. A new character evaluates cover at their own position. Device/source changes continue through the existing input rules.

## Ownership and validation

Plain Swift geometry finds the face and a valid peek. `FightSimulation` owns firing exposure, the effective firing/hit point and the shield's state. `EncounterStage` presents the reusable shield; `GameWorld` composes the party pose. Target selection, incoming damage, shot impacts and warning endpoints use the same effective point and blockers.

Focused tests cover proximity and exit, directional protection, low-cover exposure, tall-edge clearance, firing and damage agreement, leadership and reset. A scripted Simulator route exercises both kinds of cover, Pause and recovery, followed by the standard check and existing opening/combat/salvage regressions.

The prototype is not a completed phone milestone until its affected controls and feel are played on the baseline iPhone and representative frame pacing is measured. Those checks and the maintainer's judgement are deferred, not inferred from Simulator results.
