# Wall-contact correction

**Date:** 17 November 2026

## Assignment and scope

The maintainer assigned: “Go ahead and fix the wall-contact freeze in issue #25, then ask Claude to review the changes before we merge and move on to TestFlight”. This authorises the resolver and [ADR 0002](decisions/0002-party-following.md) correction integral to [#25](https://github.com/RonildoBraga/lauder/issues/25). Claude recommended the approach; review of this implementation is still required. The [README](../README.md) and [prototype plan](prototype-plan.md) own stage and review status.

## Before-proof

A private fixture hosted the previous GameWorld in a live RealityKit scene and validated a known-wall hit before trusting the query. All **8 reported positions × 16 directions = 128 movement requests** were refused. The raw query returned position `(0, 0, 0)` and distances of **3.07–15.27 metres** for a requested movement of about **4.33 centimetres**. Fixture output stays private.

The old resolver subtracted 2 mm along travel, leaving much less normal clearance on grazing approaches; an unobstructed endpoint could finish even closer. Its invalid-hit guard then prevented escape when the engine reported starting overlap. The [Party A record](party-a.md#runtime-findings) corrects the earlier gap claim without changing its historical phone results.

## Implementation

- Resolve a circular footprint continuously against the authored axis-aligned rectangles derived from visible blocker dimensions. Use exact offset faces and rounded corners, with **radius + 2 mm normal skin**, including no-hit endpoints.
- Allow outward or tangent movement from existing overlap, checking all other blockers. Idle input leaves the body still; no snapping or automatic regroup is introduced.
- Check the initial leg and one possible slide leg, then the final start-to-end chord before recording a trail edge. The chord must not shortcut through another blocker.
- Use the same geometry for trail coalescing, requiring clear endpoints and a clear complete segment without sliding or overlap recovery.
- Collision arithmetic uses Double; strict connector checks allow a 1 micrometre margin for Float entity-position rounding.
- Keep fixed floor height, equal footprints, trail bounds, diagnostics and correction guards. Update the stale gravity comment without rewriting trail recovery.
- RealityKit continues rendering. Remove obsolete engine queries and static physics components; add no slopes, navigation system, dependencies, gameplay or art.

## Validation

The initial `./scripts/check` passed with Xcode 27.2 on iPhone 17 — Lauder / iOS 27.0: strict formatting, build and Swift Testing. It includes all eight escape regressions, grazing/corner/clearance tests and four deterministic 5,000-frame runs through the production `GameWorld.advanceParty` path.

The longer **Release Simulator** acceptance matrix passed against code commit **`4c03e25b`**, calling the production `GameWorld.advanceParty` path:

| Input family | Sessions | Frames per session |
|---|---:|---:|
| Wall-biased analog, with a 40% probability of wall-following segments | 24 | 20,000 |
| Free-heading analog | 24 | 20,000 |
| Eight-direction keyboard | 24 | 20,000 |

Across **72 sessions and 1,440,000 frames**, the matrix mixed 60 Hz, 120 Hz and uneven time steps, with **34,776 escape checks** and **6,768 switch events**. No frozen member, party hold, penetration, non-finite position or excess travel was detected. This is a fixed, comparable acceptance matrix, not a replay of Claude's original random input stream. Private replay inputs and results are retained.

SHA-256 comparisons matched all **28 source, project and shared-scheme files** to the committed code. These checks establish the tested code revision; synthetic Simulator runs do not establish rendered gameplay or phone performance.

Rendered Simulator checks on the same production code passed: Miki entered the depot through the service passage and Lara returned through it; Tomas moved into the south boundary, then moved away without a hold. All three leaders were selected. Keyboard movement, observation and Pause/Resume worked, with switching ignored while paused. The touch source choice, stick movement/release after wall contact, single-press leader switching and Pause/Resume also worked. This single-pointer check does not repeat the phone's two-finger test, and the manual route was not repeated end-to-end under every leader.

Claude review and a phone milestone check for this resolver remain pending. No phone test or performance result is claimed for this fix. Review comes before another phone build so any review changes can be included in that milestone.

The [touch-control observations](touch-controls.md#validation) remain tied to runtime `b592e22`; earlier Party A device/performance evidence and deferred checks keep their existing scope. Physical controller handoff, Xbox hardware and sustained performance gaps are not resolved by this correction.
