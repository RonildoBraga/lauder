# Party A — three-character movement

**Date:** 17 November 2026\
**Status:** Focused work session 1 completed the implementation and Simulator route proof. The baseline phone route/control/recovery checks and short performance sample are now recorded below; the maintainer deferred remaining manual tests. The maintainer has authorised merging [PR #24](https://github.com/RonildoBraga/lauder/pull/24) after the final cleanup and checks. Party implementation is authorised by the maintainer's instruction to continue regardless of Claude's response, recorded in [#13](https://github.com/RonildoBraga/lauder/issues/13#issuecomment-6917260783). This overrides the earlier documentation wait gate; it does not waive the plan's validation or phone checkpoint.

## Scope

Implement the [Party A route proof](prototype-plan.md#party-a--prove-switching-and-following): three named primitive stand-ins, session-owned leadership and Pause, Q/R1/RB cycling, two followers on retained collision-checked trails and an eased camera target. Keep the service passage open. Skill actions, dialogue, mission progress, repair, Restart and persistence belong to later stages.

The animated USDZ assets and their source/provenance remain preserved for future character work. Party A uses primitives so animation does not obscure the movement experiment.

## Session record

| Session | Date | Attempt | Result |
|---|---|---|---|
| 1 | 17 November 2026 | Integrate input/session rules, three bodies, following and camera; run rule/scene checks and the Simulator route | Build/rule checks and Simulator round trips passed; subsequent phone results recorded below |

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
- The subsequent baseline iPhone evidence is recorded below. Xbox hardware and walking-cadence calibration remain unverified; these checks do not establish those separate results.

## Phone checkpoint — 17 November 2026

A signed **Release** build of `fc53d52` (version 0.1.0, build 1) built with Xcode 27.2 / iPhoneOS SDK 27.2 was installed and launched on the baseline **iPhone 13 Pro Max / iOS 27.2.1**, connected over USB. A live device preview showed all three stand-ins and the PS5 source, Cross, R1 and Options prompts. Installation, rendering and controller recognition are directly verified. The maintainer subsequently confirmed actual left-stick movement/release, R1 cycling through Miki/Lara/Tomas, both followers and clear camera/HUD during warm-up.

The maintainer also confirmed moving switches, whole-party Pause, ignored paused movement/R1, correct resumption after centring/release, controller disconnect/reconnect and background plus lock/unlock recovery without stuck movement. These are user-reported physical checks of this build. The maintainer confirmed completing the unpaused service-passage → depot → return route during the timed recording, switching leaders with both followers and no party diagnostic. The 75-second physical-device capture saved successfully and its results follow. Remaining manual tests, including the awake-screen/normal-lock timing check, were deferred at the maintainer's request: “We dont need to do all these tests now”. This is a deferral, not a passed observation. The installation did not itself assign a merge or Party B; the later merge/cleanup instruction is recorded below.

## Phone performance sample

Game Performance Overview captured the physical phone through its all-processes target after name/PID attachment failed. Analysis selected **one Lauder Metal layer**, with no FPS combining across layers. The live phone preview was removed before capture. The maintainer confirmed active, unpaused route play during the recording.

The first 15 seconds and partial boundary buckets were excluded. The [sanitised metric CSV](party-a-phone-metrics.csv) contains 59 complete aggregation buckets from **15.304 to 74.224 seconds**, covering **58.921 seconds** and **3,534 reported frames**.

| Metric | Reported result |
|---|---:|
| Duration-weighted FPS | 59.9791 |
| Bucket FPS range | 59.1622–60.7713 |
| Frame-weighted mean display interval | 16.6725 ms |
| Maximum reported display interval | 33.3355 ms |
| Reported skipped-frame counter | 0 |

The nominal **60 fps mean target was met for this short representative Release run**. One bucket reported a 33.3355 ms maximum interval; zero reported skipped frames does not mean every interval met 16.7 ms. Thermal state changed from Nominal to Fair during capture, with no Serious or Critical state reported.

These are instrument-reported aggregate display-pacing statistics. The trace's per-frame tables exported no rows, so no p95/p99 or exact individual-hitch count is claimed. Frame-count/duration and interval-based FPS crosschecks agree. The trace saved and metrics exported despite symbol-timeline warnings during postprocessing. Raw traces remain private; the CSV contains only relative times and numeric metrics. Profiling overhead, sustained thermal behaviour, memory reliability and other devices remain outside this short result.

## Milestone checklist

- Standard formatting/build/Swift Testing, including input/session, trail bounds/connectivity and scene collision setup.
- Manual Simulator round trip under every leader, reversals, switching at the passage, Pause/Resume and fresh input recovery.
- No automatic teleport; diagnostic/capacity holds must be reported, not hidden.
- At the accepted Party A milestone, phone controller/camera/lifecycle observations and measured frame pacing. Simulator results do not satisfy this checkpoint; Xbox hardware and older deferred checks remain distinct.

## Merge and cleanup — 17 November 2026

The maintainer instructed: “Merge and commit everything and delete any left over or dead code or anything that is no longer needed”. This authorises integrating Party A into main with the confirmed cleanup; it does not start Party B or revoke the remaining test deferrals.

- Moved the unused production asset validator unchanged into `tests/support`. The USD sources, deliberate exports, generator, provenance and real import/rejection checks remain.
- Removed the ground's unqueried collider and its collision group. The ground remains visible, and every queried blocker retains the same geometry and obstacle group. Scene tests cover that boundary.
- Updated the active architecture and moved-file references. Historical Stage 1/2 evidence remains historical.
- Reproduced and fixed the automated review's slow-turning capacity failure: at 60 Hz, 1 mm leader steps turning by 0.001 radians per frame previously stopped the party at frame 508. Short, gentle, unoccupied bends now coalesce only after a complete world footprint sweep, with at most three checks per step and rotating candidates. Blocked or unavailable clearance preserves the route; occupied cursors, branches and the 512-node/64-metre limits remain intact.
- Removed confirmed generated preview/device build caches and the DerivedData from two failed check runs. Preserved the tested signed Release app/dSYM, manifests, traces, metric exports, installation/launch receipts and failed-test result bundles/logs, with private before/after checksum receipts.

The final `./scripts/check` passed strict formatting, the shared-scheme build and Swift Testing after cleanup and the slow-turn fix. The new regression covers 2,000 slow curved steps followed by 600 rear-leader reversal steps; additional checks cover denied shortcuts, the query budget and rotation, occupied/pending cursors and zero-length chords. The updated iPhone 17 / iOS 27.0 Simulator build completed a shelter → service opening → depot → shelter round trip with both followers, mixed leadership, wall contact, an observation, Pause/Resume and ignored paused input, without a party diagnostic. This is separate from the earlier three individual-leader route runs.

All 115 local Markdown links and 18 anchors passed validation. About 590.3 MiB of net generated cache data was removed before private audit receipts; protected evidence checksums and the preserved app signature matched. Disposable local slow-turn reproducer scripts were also removed. The phone results above apply to `fc53d52`; the cleanup and trail fix have not had another phone or performance run. The maintainer's remaining manual-test deferrals stand, and no further phone tests are requested.
