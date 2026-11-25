# ADR 0019 — Explicit animation profiles for party models

**Status:** Accepted and implemented; local checks and rendered Simulator verification passed\
**Date:** 25 November 2026

## Assignment and context

After accepting the [native Miki motion/export review](../../blender/studies/miki-hand-motion/README.md), the maintainer instructed: **“Go ahead and integrate Miki’s new model, hand rig and animations into the bridge scene, then test running, sneaking and shooting in the simulator.”** Source: the project conversation, without a public permalink. This authorises this model integration and its necessary export/runtime contracts, not new weapons, controls, combat balance, scenes or a release.

The existing canonical party models share a 17-bone rig and eleven clips. The reviewed Miki has 47 bones, fitted rest proportions, articulated fingers and four garment corrective targets. The existing runtime imports variable joint arrays but assumes one clip table, six arm joints and a generic wrist orientation. Simply accepting a larger joint count would lose hand calibration, corrective playback and validation of the intended skeleton.

## Decision

- Keep two explicit named profiles, **party17** and **miki47**. Validate their exact joint names and parent hierarchy, full supported clip/channel coverage, timing and declared morph channels. A bone count alone does not identify a supported model.
- Promote Miki's reviewed geometry, weights, fitted rig and linear skinning into her canonical model. Her local editable Actions and manifest live with that model; Laura and Tom retain the existing shared source and appearance. Extract the exact source JPEG into Miki's asset folder for the normal texture contract. Preserve provenance and the accepted study separately.
- Generate profile timing, calibrated palm/grip data and garment names through the existing Blender export workflow and fingerprint ledger. Runtime constants must not become a second authored source of those values. Validate geometry and all related metadata together before replacing exports.
- Reuse one `PartyAnimation` presenter. It caches immutable imported joint/morph samples and rest data; each actor owns its phase, event state and native morph weights. Resolve grouped animation definitions and bind named joints/morphs explicitly. Restart and lifecycle gates freeze or reset the same owned state.
- Include Miki's fingers in aim/grip presentation. Use the measured palm frames and actual gameplay weapon's grip frame with the existing arm solve. Source rifle placement from the editorial preview does not drive the game weapon. Apply the accepted shot's finger/body reaction after the grip baseline, without playing a lead-in before a shot.
- Preserve resolved-displacement gait timing and simulation authority. Animations cannot move a party body, advance navigation, choose aim, spend ammunition, create shots or cause damage. The existing weapon remains separate and owns its transforms and recoil.
- Fit the actual carbine's low-carry grip height to Miki's shorter arms, through the existing shared `WeaponPose` transform. Keep raised aim, recoil, weapon geometry and shot rules unchanged; test the complete draw/lower transition rather than only its endpoints. Do not hide unreachable hands by stretching bones or silently clamping their targets.
- Derive the presentation's ground axis from the visual coordinate system, independently of a stylised spine lean. Fit the additional Walk source's planted-foot travel to its declared stride when adapting leg lengths; increasing nominal speed to conceal slipping would change gait selection. Preserve the already approved Run/Sneak source poses.

## Options considered

| Option | Preservation | Validation and cost |
| --- | --- | --- |
| Keep every model at 17 bones | Drops approved finger articulation | Smallest code change but does not implement the assignment |
| Convert all three models to Miki's rig | Changes unassigned companion anatomy and skinning | Larger art/motion migration and additional regression risk |
| Accept arbitrary joint counts | Keeps geometry but has no defined hand/morph contract | Hides incompatible hierarchies and missing channels |
| Explicit profiles through one presenter | Preserves Miki's rig and current companions | Adds a bounded contract and per-profile metadata for the demonstrated need |

The explicit-profile option keeps source ownership clear while allowing the party members' proportions and supported deformation to differ. It adds no package hierarchy, animation controller graph, generic retargeting framework, runtime cloth simulation or gameplay animation player.

## Verification and consequences

Verify exact approved raw geometry, weights, rest joints, UV/JPEG/material data and corrective targets against the promoted source. Check the exported named hierarchy, morph tracks, held endpoints, independent clones and reset. Test measured palms/fingers against the actual weapon, including low carry, aim and accepted recoil. Maintain Laura/Tom regressions.

The full `./scripts/check` passes. Rendered Simulator routes pass for normal movement, Shift-sneak, actual combat fire, Pause/Resume, Restart, recruitment and leader switching. The small DEBUG motion route uses ordinary raw input rather than an animation override. The [prototype plan](../prototype-plan.md#miki-articulated-model-on-the-bridge) records exact source-bound results, with retained captures.

Miki's denser mesh, texture and additional joints require a later physical-phone performance checkpoint. Simulator timing is not iPhone evidence. This task does not authorise a merge or TestFlight upload. Future additional models need an explicit profile or a demonstrated extension of this contract rather than a silent count-based fallback.
