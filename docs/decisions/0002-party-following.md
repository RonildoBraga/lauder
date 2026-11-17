# ADR 0002 — bounded party following

**Status:** Accepted for the bounded Party A experiment; collision method revised by the maintainer's #25 assignment\
**Date:** 16 November 2026; collision revision 17 November 2026\
**Deciders:** Maintainer

## Context

The approved party direction adds two followers and switchable leadership to a small scene with a 1.8-metre service opening. It is a larger risk than the previous solo slice. [Claude's B1/B3 review](https://github.com/RonildoBraga/lauder/pull/21#issuecomment-6916286122) asks for an explicit method, party-collision policy and failure behaviour before Party A. The [prototype plan](../prototype-plan.md) owns milestones and the stop criterion; the [architecture](../architecture.md) owns session/input/camera boundaries.

## Decision

Use a **bounded recorded-path trail**, implemented as plain Swift values inside the existing app, with world execution owned by GameWorld.

- Record collision-resolved positions actually reached, not requested destinations. Keep connected breadcrumb segments and a cursor for each member. Space targets along travelled distance; do not steer followers directly toward the leader across corners.
- Retain enough ordered route to connect all three cursors. On a switch, the selected member becomes the trail head at their actual position. Preserve the old segments needed by the other members, including an old leader now ahead of the new one. They can retrace those connected segments to join the new trail; positions do not change instantly.
- Track route connections explicitly. Geometrically close points on opposite sides of a wall or different passes through a loop are not interchangeable. Never rebase by nearest point or replace a missing connector with a straight line. A proposed connector needs a complete footprint-clearance check before use.
- Advance followers through short segments using world collision checking and response. Advance a cursor only by actual movement, then record the next resolved position. Leader clearance alone does not establish follower clearance: interpolation, corners, reversal and switching still need checks. Resolve the common circular footprint continuously against authored axis-aligned rectangles in plain Swift. Offset faces and exact rounded corners use radius plus a 2 mm normal skin, including unobstructed endpoints. Permit outward or tangent movement from existing overlap without idle snapping. Check the initial leg, at most one slide leg and the final start-to-end chord before recording an edge. RealityKit renders bodies and scenery; movement needs no engine shape queries or static physics components. Keep the current flat floor and fixed body height, excluding ground, decorations and party members from horizontal blockers. No slopes, vertical traversal or new physics/navigation system are added.
- Start with initial hard limits of **512 breadcrumb nodes total** and **64 metres of retained segment length across all branches**, whichever is reached first. Record movement-distance/turn samples rather than one point per idle frame, preserving corners needed for clearance. These are initial test budgets, not measured tuning results.
- Coalesce tiny, gentle bends only after clearance is established for the complete replacement segment. Party A may remove an unoccupied degree-two node across at most 0.08 metres of route and a turn of at most 0.1 radians, with no pending movement. GameWorld uses the same footprint, skin and authored rectangles as movement; both endpoints and the full chord must be clear, without sliding or overlap recovery. Limit these checks to three per step and rotate candidates so blocked old bends cannot starve later ones. Exact straight-line pruning remains check-free. This addresses slow analog steering exhausting the node budget while preserving occupied cursors, branch identity and the existing capacity hold.
- Prune only segments no member or pending connector still needs. Before accepting a step that would require exceeding either limit, prune safely or hold **all party movement, including the leader**, and report a capacity diagnostic. Keep Pause available. Never discard required connections, allocate indefinitely or jump to a target. A capacity hold fails the nominal route check and needs correction; it is not a hidden regroup policy. Pure tests should exercise the same rule with deliberately small limits.
- Retain scenery blocking but exclude party members from one another's collision checks. Use equal circular footprints initially and best-effort trail spacing. Temporary overlap is acceptable for this graybox; permanent obstruction or repeated separation fails the route check.

**Initial recovery is hold and diagnose.** A blocked or disconnected follower stops safely and exposes a diagnostic identifying the member/segment. Adjust the bounded route or trail before adding content. Party A has no automatic teleport or regroup.

## Options considered

| Option | Complexity and benefit | Limitation |
|---|---|---|
| Recorded trail with retained connections | Bounded, testable value logic; reuses the route actually walked | Switching/reversal needs careful rebasing; not general navigation |
| Direct steering toward leader | Smallest steering loop | Cuts corners and cannot reliably traverse the service route |
| General navigation or a larger authored route network | Better candidate for varied destinations and larger levels | More setup/state than this proof justifies; revisit only if the bounded trail fails |

## Consequences and review

This avoids a navigation package and party-body blockage, but does not guarantee collision-free or visually separated followers. Test corners, reversals, repeated leader changes, a leader behind the party, retained branches, history bounds and closed/open passage state. Use manual Simulator route checks in addition to pure trail tests.

At the plan's stop review, a simpler layout is the first alternative. A **future regroup option requires maintainer approval**: only an inactive follower could move to an authored safe point in the same currently reachable/open region, outside solids and without crossing a closed barrier. Both its old position and destination must be outside current camera framing, including any switch transition. Never warp the active leader or change mission progress; if no valid point exists, hold. This is a constraint on a possible later option, not an implemented or approved fallback.

The maintainer accepted the recommendations and stop/phone checkpoints, then explicitly assigned Party A regardless of Claude's response. The [Party A record](../party-a.md) tracks the experiment and actual checks. No new animation requirement or recovery subsystem is added by this record.

On 17 November the maintainer assigned: “Go ahead and fix the wall-contact freeze in issue #25, then ask Claude to review the changes before we merge and move on to TestFlight”. This authorises the collision-method correction integral to [#25](https://github.com/RonildoBraga/lauder/issues/25), replacing the original RealityKit sweeps. It is a maintainer assignment, not Claude's approval of the implementation. The [wall-contact record](../wall-contact.md) tracks reproduction and validation; trail bounds, diagnostics and correction guards remain in place.
