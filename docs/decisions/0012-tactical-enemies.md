# ADR 0012 — Enemies that take cover, flank and flush

**Status:** Implemented and delivered in TestFlight 0.1.0 (21)\
**Date:** 22 November 2026

**Later change:** [ADR 0014](0014-continuous-combat-arena.md) supersedes the retained hostile red aiming line and the combat yard's finite encounter/fallback policy. This record preserves the earlier phase's assignment and delivery evidence.

## Assignment and scope

The maintainer's continuous implementation and TestFlight assignment is recorded in [ADR 0011](0011-companion-combat.md). This record covers phase 5 of the [combat plan](0008-weapon-feel-and-combat-plan.md), [issue #95](https://github.com/RonildoBraga/lauder/issues/95). The following settings are implementer-selected, tunable defaults. They do not change the story foundations or add encounters to the bridge.

## Decisions

- **The combat yard remains the venue.** Its left shooter seeks cover, its right shooter flanks, and one additional thrower provides a different pressure. Existing hostile and party hit limits stay unchanged. The opening's stationary shooter, deliberate miss and knife rusher keep their defaults.
- **Shared cover.** Tactical shooters use the same body clearance, crouch, low-cover exposure, tall-edge peek and firing/hit point as the party. They react for 0.35 seconds before their first wind-up, rather than knowing the player's aim immediately. The red wind-up line remains the warning. Movement pauses their weapon timer; it does not produce a shot while they run.
- **Bounded movement.** Rifle enemies walk at 1.7 m/s using the existing grid and collision rules, stay within 6 m of their starting point and outside each other. Cover choices are reconsidered about every two seconds, flank choices every three. The flanker seeks a reachable side angle rather than increasing its damage or hit count. A single navigation grid serves the tactical actors; the bridge pays no new tactical-grid cost.
- **A grenade is a warning and a deadline.** The thrower fixes the landing point at launch. An airborne marker travels there; a large ground ring stays at that point for a 2.5-second fuse, with a 2.2 m blast radius. Walking away is enough. One blast deals one hit to each party member still inside, at most once. Tall scenery blocks the blast; low cover does not. There is no homing, damage over time, knockback or extra input. A thrown grenade remains live if its thrower is downed.
- **Companions avoid immediate danger.** An active grenade can temporarily displace a companion from its formation or held spot to reachable safe ground. Its order is retained, and normal positioning resumes after the danger passes. Regroup still prevents firing and continues to govern the squad's destination.
- **Readable stand-ins.** Existing red figures, their cover poses/shields, a distinct thrower marker and the ground warning explain the behaviour without new art or voice work. No armour, weak points, new signatures or health system are introduced.
- **Lifecycle.** Pause freezes all timers and movement. Restart clears tactical plans, projectiles and damage; fallback clears plans and grenades while retaining the existing hostile-damage and shared-ammunition policy. A level change owns a fresh simulation.

## Verification and delivery

Tests cover reaction, navigation, cover, flanking, grenade launch/fuse/radius/obstruction, one-time damage and lifecycle. Scripted Simulator routes exercise the new enemies, warnings, escape, party recovery and the existing opening/salvage flow. Final source `cec1a33` passed the standard check, all thirteen headless scenarios and six rendered routes; automatic source review completed with no findings. A fresh signed Release archive was verified and uploaded using API authentication. Apple confirmed **0.1.0 (21)** as **VALID**, **IN_BETA_TESTING** and available to the existing internal TestFlight group with membership unchanged. The [prototype plan](../prototype-plan.md#verification-and-performance) holds the full evidence.

Physical-controller feel, baseline-phone frame pacing and the maintainer's judgement “Is each fight a readable puzzle?” remain unverified. This assignment permitted delivery using Simulator evidence without repeated phone sessions.
