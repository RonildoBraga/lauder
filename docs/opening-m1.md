# Opening M1 — the bridge, Miki alone

**Date:** 18 November 2026

## Assignment and scope

The maintainer accepted [ADR 0004](decisions/0004-brooklyn-bridge-opening.md) as recommended (**“Accept as recommended”**), then assigned its first milestone: **“Yes, start M1”**. M1 adds levels as values, the greybox Brooklyn Bridge, a party of one, trigger areas and Restart. Following the ADR's first two decisions, it also renames Tomas and Lara as Tom and Laura, and rewrites the opening in the story bible, the Chapter One outline and the gameplay walkthrough.

Claude implemented and checked M1, so nothing below is an independent review. The [README](../README.md) and [prototype plan](prototype-plan.md#opening--the-brooklyn-bridge) own stage and review status.

## What changed

- **Levels are values.** A `Level` holds a place's floor, blocker boxes, points of interest, interactions, trigger areas, starting party, spawn points, starting heading and camera offset. `RelayHouse`, formerly `PrototypeLayout`, and the new `BrooklynBridge` each build one. `GameWorld`, `GameSession`, the navigation grid and the scene dressing take the level they are given. The app opens on the bridge. In Debug builds, `-LauderLevel relay-house` opens Relay House, and each scripted playtest loads its own level.
- **The bridge.** A flat deck about 250 m long and 24 m wide, Brooklyn at +z and Manhattan at -z. Two roadways run either side of the raised walkway's base, which has collapsed in a 12 m gap at mid-span. Two granite towers stand at 100 m and 200 m from the start, with arches 14 m high so the camera, 10 m up, passes through behind Miki. The walkway on posts, cables with suspenders and stays, lane lines and the river 30 m below are decoration that blocks nothing. Cars, a van, a truck and debris stand where the later scenes need them. A bus jammed across the east roadway sends the route through the gap, and barricades close both ends. A checkpoint booth, the bus and the Manhattan barricade can be looked at.
- **Lines that show once.** Six trigger areas each show a line the first time Miki enters them in a run: cars ahead, the first tower, mid-span, the blocked lanes, the second tower and the Manhattan end. They do not fire while paused, and Restart clears them.
- **A party of one.** The session holds who has joined, in switching order. The bridge starts with Miki alone; Relay House starts with all three, as before. **Next** and its hint stay hidden until there is someone to switch to. Tom's and Laura's bodies are created at load but stay hidden, out of movement and out of the squad, at the places their scenes will use. The squad planner places whichever companions are present. A `recruit` command exists for M3, but nothing in play calls it yet.
- **Camera.** The bridge keeps the accepted height and distance but looks straight along the deck, so pushing up walks towards Manhattan. Relay House keeps its offset.
- **Navigation grid.** Each obstacle now checks only the cells within its reach, which gives exactly the same grid as checking every cell against every obstacle. That matters on the bridge, whose grid has about 150,000 cells. It is built once at load.
- **Names.** Tom and Laura replace Tomas and Lara in code, in the lines, prompts, playtest steps and trace columns, and in the living design documents. Dated records and accepted ADRs keep the names they were written with.

## Checks

- `./scripts/check` passes: formatting, build and Swift Testing on the iPhone 17 / iOS 27 Simulator, with 97 tests in 16 suites.
- New tests cover both levels' content; the grid against the clearance rule, every cell at Relay House and a sample on the bridge; the bridge's connection from end to end through the gap; Miki alone, with Tom and Laura hidden; each trigger firing once along the crossing and not again; Restart three times without adding entities; recruiting order; and one companion keeping a Close slot. The `bridge-walk` playtest also runs headless in the check.
- Every Relay House test and headless playtest passes unchanged.
- Rendered Simulator run of `bridge-walk`: pass, 31 of 31 steps in 99.6 s. Frames averaged 16.7 ms, with a 99th percentile of 16.8 ms and a maximum of 33.4 ms. The party update averaged 0.24 ms, with a maximum of 1.8 ms. These are Simulator figures from a Debug build, not phone performance.
- The run's screenshots show the deck with its lane line and railings, the towers' piers either side of the arch as Miki passes through, the bus closing the east roadway, and the west roadway after the crossing. During a scripted run the HUD's line shows the playtest's progress, so the trigger lines are checked by the headless tests rather than seen in the screenshots.

## Limits

- Nobody has played the bridge by hand. Whether the camera reads well, part of M1's exit, is the maintainer's judgement.
- Simulator only. The opening's planned phone checkpoint comes with M4. The bridge has more scenery than Relay House, including about a hundred thin cable and walkway pieces, and its phone performance is unmeasured.
- The towers' upper parts and the cables' high sections are above the camera, so the bridge reads mostly at deck level.
- Crossing the empty deck takes about a minute and a half with nothing to do but read a few lines. The encounters, and the ordered story beats that start them, arrive with M2 to M4.
- TestFlight build 0.1.0 (1) predates M1. A new upload would need build 2.
