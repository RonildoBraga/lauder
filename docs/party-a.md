# Party A — three-character movement

**Date:** 17 November 2026\
**Status:** Focused work session 1 completed the implementation and Simulator route proof. The phone milestone remains pending; Party A has not exited and is not ready to merge. Party implementation is authorised by the maintainer's instruction to continue regardless of Claude's response, recorded in [#13](https://github.com/RonildoBraga/lauder/issues/13#issuecomment-6917260783). This overrides the earlier documentation wait gate; it does not waive the plan's validation or phone checkpoint.

## Scope

Implement the [Party A route proof](prototype-plan.md#party-a--prove-switching-and-following): three named primitive stand-ins, session-owned leadership and Pause, Q/R1/RB cycling, two followers on retained collision-checked trails and an eased camera target. Keep the service passage open. Skill actions, dialogue, mission progress, repair, Restart and persistence belong to later stages.

The animated USDZ assets and their source/provenance remain preserved for future character work. Party A uses primitives so animation does not obscure the movement experiment.

## Session record

| Session | Date | Attempt | Result |
|---|---|---|---|
| 1 | 17 November 2026 | Integrate input/session rules, three bodies, following and camera; run rule/scene checks and the Simulator route | Build/rule checks and Simulator round trips passed; phone milestone pending |

The accepted stop criterion remains three focused sessions. If the round trip is still unreliable under any leader after session 3, stop before adding B/C and reassess the route or a separately approved recovery policy.

## Runtime findings

The first Simulator implementation reported character-controller peer contacts despite filters excluding the party group, both with constructor filters and a separate scenery group. Party A now uses one shared RealityKit sphere to sweep the common circular footprint against scenery and plain party body transforms. Sweeps stop with a 2 mm gap and every wall slide receives a second sweep; body height remains fixed for the existing flat floor. This is an observed execution issue in the tested runtime, not a claim about every RealityKit version. Capsule probes also exposed inconsistent axis/contact-distance behaviour; the sphere query uses validated contact geometry to recover travel along the requested segment. All current blockers must cross the authored horizontal query plane. The [architecture](architecture.md) and [ADR](decisions/0002-party-following.md) record the resulting scope.

Trace-driven regressions also separate small physical offsets from exact route topology. They preserve corners, correct residual offsets before advancing to another edge, retain the first failure diagnostic, and enforce node/length bounds without a teleport fallback.

The loop uses one `SceneEvents.Update` subscription, cancelled on teardown, so input remains active when static physics is idle. Spatial simulation state stays outside SwiftUI observation.

## Verification

- `./scripts/check` passes with Xcode 27.2: strict formatting, shared-scheme build and Swift Testing. The final run includes the query-plane integration.
- On the iPhone 17 / iOS 27.0 Simulator, the final sphere/contact-geometry implementation completed the full shelter → service opening → depot → shelter trip separately under Miki, Lara and Tomas, with both followers and no route/capacity/stall hold.
- A separate mixed-leader run switched at the opening, entered under Lara, selected rear member Tomas, reversed and returned through the retained route. All three remained visible without persistent separation in these runs.
- The fallen-panel contact/slide, blocked transmitter/shelter approach, movement away from contact, idle follower settling, one switch per held Q, whole-party Pause, ignored movement/switch while paused, resume and Home → foreground recovery were observed. HUD/marker/next-leader labels and the eased camera remained readable. These are manual observations, not measured device performance.
- Simultaneous held movement/switch, Pause priority and neutral/held-input lifecycle edge cases have pure rule tests. They are not claimed as live controller or held-input phone observations.
- No automatic warp/regroup, skill barrier, mission, dialogue, repair or Restart was implemented. Capacity, disconnected-route and follower-stall holds have rule tests; nominal route checks did not trigger them.
- The baseline iPhone controller/camera/lifecycle run and measured frame pacing are pending. Xbox hardware and previously deferred Stage 2 checks remain unverified; Simulator keyboard results do not close them.

## Phone checkpoint — 17 November 2026

A signed **Release** build of `fc53d52` (version 0.1.0, build 1) built with Xcode 27.2 / iPhoneOS SDK 27.2 was installed and launched on the baseline **iPhone 13 Pro Max / iOS 27.2.1**, connected over USB. A live device preview showed all three stand-ins and the PS5 source, Cross, R1 and Options prompts. Installation, rendering and controller recognition are verified; these observations alone do not establish input delivery, following, lifecycle recovery or performance.

The phone is ready for warm-up and an active-play performance capture; the maintainer's warm-up result is awaited. Control/route observations, interruptions, disconnect/reconnect, awake-screen behaviour and measured frame pacing remain pending. No merge or Party B implementation is assigned by this installation.

## Milestone checklist

- Standard formatting/build/Swift Testing, including input/session, trail bounds/connectivity and scene collision setup.
- Manual Simulator round trip under every leader, reversals, switching at the passage, Pause/Resume and fresh input recovery.
- No automatic teleport; diagnostic/capacity holds must be reported, not hidden.
- At the accepted Party A milestone, phone controller/camera/lifecycle observations and measured frame pacing. Simulator results do not satisfy this checkpoint; Xbox hardware and older deferred checks remain distinct.
