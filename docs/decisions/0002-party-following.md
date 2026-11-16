# ADR 0002 — bounded party following

**Status:** Planning defaults accepted for consolidation; latest Claude confirmation pending before implementation\
**Date:** 16 November 2026\
**Deciders:** Maintainer, following Claude's documentation review

## Context

The approved party direction adds two followers and switchable leadership to a small scene with a 1.8-metre service opening. It is a larger risk than the previous solo slice. [Claude's B1/B3 review](https://github.com/RonildoBraga/lauder/pull/21#issuecomment-6916286122) asks for an explicit method, party-collision policy and failure behaviour before Party A. The [prototype plan](../prototype-plan.md) owns milestones and the stop criterion; the [architecture](../architecture.md) owns session/input/camera boundaries.

## Decision

Propose a **bounded recorded-path trail**, implemented as plain Swift values inside the existing app, with world execution owned by GameWorld.

- Record collision-resolved positions actually reached, not requested destinations. Keep connected breadcrumb segments and a cursor for each member. Space targets along travelled distance; do not steer followers directly toward the leader across corners.
- Retain enough ordered route to connect all three cursors. On a switch, the selected member becomes the trail head at their actual position. Preserve the old segments needed by the other members, including an old leader now ahead of the new one. They can retrace those connected segments to join the new trail; positions do not change instantly.
- Track route connections explicitly. Geometrically close points on opposite sides of a wall or different passes through a loop are not interchangeable. Never rebase by nearest point or replace a missing connector with a straight line. A proposed connector needs a world-swept clearance check before use.
- Advance followers through short segments using world collision checking and response. Advance a cursor only by actual movement, then record the next resolved position. Leader clearance alone does not establish follower clearance, even with equal initial controller footprints: interpolation, corners, reversal and switching still need checks. RealityKit's [character movement](https://developer.apple.com/documentation/realitykit/entity/movecharacter%28by%3Adeltatime%3Arelativeto%3Acollisionhandler%3A%29) performs continuous collision checking; observe resolved state at the appropriate engine update rather than assuming requested motion succeeded.
- Start with initial hard limits of **512 breadcrumb nodes total** and **64 metres of retained segment length across all branches**, whichever is reached first. Record movement-distance/turn samples rather than one point per idle frame, preserving corners needed for clearance. These are initial test budgets, not measured tuning results.
- Prune only segments no member or pending connector still needs. Before accepting a step that would require exceeding either limit, prune safely or hold **all party movement, including the leader**, and report a capacity diagnostic. Keep Pause available. Never discard required connections, allocate indefinitely or jump to a target. A capacity hold fails the nominal route check and needs correction; it is not a hidden regroup policy. Pure tests should exercise the same rule with deliberately small limits.
- Keep world collisions enabled but exclude collisions among party members. Use equal controller footprints initially and best-effort trail spacing. Temporary overlap is acceptable for this graybox; permanent obstruction or repeated separation fails the route check.

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

The maintainer accepted proceeding with these recommendations and the plan's stop/phone checkpoints when consolidating PRs #20–#22. Obtain confirmation of the latest architecture review before the implementation assignment and route proof. No new animation requirement or recovery subsystem is added by this record.
