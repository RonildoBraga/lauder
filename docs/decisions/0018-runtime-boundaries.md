# ADR 0018 — Smaller runtime responsibilities and shared contract checks

**Status:** Accepted; verification and integration tracked in [issue #124](https://github.com/RonildoBraga/lauder/issues/124)

**Date:** 22 November 2026

## Assignment

After reviewing the current directory tree and architecture, the maintainer instructed:
**“proceed with your suggestions”.** This assigns behaviour-preserving structural improvements
to the bridge-only prototype. It adds no scenes, mechanics, art or story changes.

## Boundaries

- `GameWorld` coordinates input, spatial movement, encounters, retries and presentation. Body
  positions remain entity-backed; a wholesale spatial-state rewrite is not assigned.
- `WorldCamera` owns the camera entity and landmark fading. `CameraRig` owns follow, encounter
  lean, leader-switch easing, lens and projection as values. The world supplies current intent.
- `GameSession` remains the authority for mode, inventory, checkpoints, party and commands.
  `BridgeProgress` owns the concrete bridge's action/progression/recruitment policy, copied into
  checkpoints. `StoryBeat` is content data independent of the session; `ActionResult` is a
  standalone value. Checkpoint creation still precedes a Help cost.
- `EncounterSimulation` coordinates the existing combat and story cues in `gameplay/`; its
  name reflects both duties. Native combat values stay in `combat/`, split into cohesive files.
  `EncounterStage` remains presentation only.

Keep one app module and one hosted test target. Introduce no package hierarchy, generic quest
engine, event bus or dependency-injection framework. Future extractions follow demonstrated
gameplay or testing needs.

## Shared contracts and collaboration

Remove the unread greybox `Look` field. A small portable source checker compares the Swift and
Python playtest lists and the exporter/preflight/runtime/sound resource names. Mutation tests
verify that drift fails with a useful diagnostic; sources remain ordinary declarations.

The standard check runs in GitHub Actions on a compatible hosted Xcode image as well as locally.
A workflow definition is not proof of a successful run: record its actual result on the PR.
Reproducible TestFlight tooling is a separate focused change under the same assignment; keys,
team configuration and release evidence stay private.

## Verification

Preserve camera framing/transition/reset, story eligibility and costs, recruitment, checkpoint
retry, Observation delivery, shared input authority and foreground lifecycle. Run
`./scripts/check` and representative rendered bridge routes before integration. Existing
TestFlight build 27 proves the prior source only. A new delivery needs its own checked/reviewed
source and Apple processing/tester proof. Phone checks remain deferred by the maintainer.
