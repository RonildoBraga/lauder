# ADR 0015 — Weapon variety and map-wide firearm travel

**Status:** Implemented, checked, reviewed, merged and delivered in TestFlight 0.1.0 (25)\
**Date:** 22 November 2026


**Current scope:** The bridge-only reset retired the non-bridge experiments described here. Shared rules remain only where the bridge uses them; this record preserves the earlier decisions and measurements, not an assignment to restore deleted systems. See [ADR 0017](0017-bridge-only-reset.md) and the current [architecture](../architecture.md).

## Assignment

After playing build 24, the maintainer asked for more enemy variety using The Division 2 as a reference, different weapons, and shots that cover the map rather than stopping after a short distance. [Issue #115](https://github.com/RonildoBraga/lauder/issues/115) records this assignment. It extends [ADR 0014](0014-continuous-combat-arena.md)'s greybox combat test without assigning new story encounters, character histories or a change from exploration and salvage as the main game.

The arena's small paused weapon selector is an implementation choice under the request for different weapons. It permits comparisons without a loot or inventory system. No separate explicit selection reply or change to the trio's story weapons is claimed. The values below are tunable prototype defaults, not final balance or new narrative foundations.

Ubisoft's AI designers describe varied pressure through positioning, flanks, aggression and differently exposed bursts in [their Division 2 interview](https://news.ubisoft.com/en-us/article/5wu3eterDz21wNKiAcDJlJ/the-division-2-making-enemies-tougher-and-friendlies-smarter). This experiment uses those design principles with its own small deterministic rules; it does not reproduce proprietary algorithms, factions or assets.

[ADR 0016](0016-combat-balance-and-readability.md) records the subsequent assigned tuning pass. The starting values below describe build 25; the later record supersedes scatter timing and passive precision acquisition while retaining map-wide physical travel.

## Separate the three meanings of range

The original firearm distances served several purposes at once: player target help, AI acquisition and the actual bullet trace. The carbine stopped at 14 m, the burst weapon at 12 m, the scatter weapon at 7 m and the arena rifle at 18 m. These camera-sized limits became conspicuous in the larger 52 × 60 m arena.

The new contract separates them:

- **Assistance and acquisition:** weapon assistance and each enemy's engagement reach remain explicit. A long-travelling round does not give every actor map-wide target knowledge or automatic offscreen targeting. Companions and tactical movement still choose useful positions within their weapon roles.
- **Physical travel:** `Ballistics.traceAcrossLevel` follows the fired three-dimensional ray to the first forward x/z level-boundary exit. The first real body, cover box, gate or terrain surface wins. A nonphysical map edge is `.nothing`, with no invisible impact. The calculation uses each level's bounds, so the long bridge is not limited to an arena-sized constant. The existing explicit-range trace remains available for geometry rules and tests.
- **Effective damage:** accuracy, cadence and stopping power distinguish weapons even when bullets travel farther. Scatter and marksman shots lose their two-hit bonus beyond their weapon's effective reach and deal one hit. A distant valid hit does not silently become zero damage at an arbitrary distance.

Arrival reactions and recovery readiness may advance before a target enters acquisition reach. The actual wind-up countdown, preparing-shot HUD/cue, Disrupt eligibility and a fresh discharge require an acquired target within reach; being ready is not map-wide awareness. An out-of-range or unacquired `.blocked` result must not grant a fresh damaging burst simply because its ray now travels farther. A burst already committed may finish as its target moves beyond that distance; its actual path still meets cover and other eligible bodies. Losing a target or repositioning must not preserve an almost-finished precision shot that fires immediately on reacquisition.

The opening's deliberate warning remains non-damaging to every party member. A visible person who is not yet a legitimate target still blocks intentional first fire, including beyond assistance distance. Longer travel must not shoot through that person to hit a hostile behind them or make scatter damage them accidentally.

## A tracer is a short moving visual

Damage remains hitscan. `ShotEffects` keeps a short **2.5 m moving streak**, rather than drawing the whole trajectory as an aiming beam. Its baseline presentation speed becomes **500 m/s**, increasing for unusually long paths so the head reaches the endpoint within **0.15 s**; the tail clears shortly afterwards. Impact feedback remains immediate with the hitscan result.

Fixed pools of **eight party streaks and sixteen hostile streaks** cover supported simultaneous rapid-fire cadence, including four hostile shooters and the leader's companions. Firing allocates no entity and a long bridge path does not grow the pool. Tests must show that a new volley cannot recycle a still-travelling streak early. Grenade danger circles and arrival warnings retain their separate meanings; exact red hostile aiming lines remain removed.

## Distinct enemy pressures

The existing arena gains a marksman and support gunner, and its old flanker/rusher use different firearm profiles. The pool grows from eight to **ten fixed slots**, covering **six roles**, while retaining **three-/four-actor packs**, **at most four active**, safe arrival warnings and inter-wave resupply.

| Role | Pressure and opening | Starting firearm/engagement values |
| --- | --- | --- |
| Cover rifle | Shelters near home and exposes itself for a short burst | Rifle; three shots, 1.7 s wind-up, 2.4 s recovery, 18 m acquisition |
| Flanker | Seeks a reachable side angle and fires less precise rapid rounds | SMG; four shots 0.1 s apart, 1.2 s wind-up, 1.7 s recovery, 18 m acquisition |
| Close rusher | Advances to threaten a close approach; weak against distance and cover | Scatter weapon; one blast, 0.8 s wind-up, 1.2 s recovery, 7 m acquisition |
| Grenadier | Moves the squad out of a fixed warned area | Existing grenade; 2.2 s wind-up, 5 s recovery, 19 m acquisition |
| Marksman | Uses a long clear lane, yields ground when crowded and needs a new wind-up after moving | Marksman rifle; one shot, 2.4 s wind-up, 2.5 s recovery, 45 m acquisition |
| Support gunner | Holds a lane with a longer burst, followed by a clear recovery opportunity | Support gun; six shots 0.14 s apart, 1.8 s wind-up, 3 s recovery, 22 m acquisition |

Primitive weapon shapes, role marks, raised weapons, reaction poses, sound and non-directional wind-up cues help distinguish these threats. A cue can warn that a distant marksman is preparing a shot without exposing the exact future impact point. These are role differences, not armoured health sponges or an escalating enemy count. Existing authored enemies retain their prior firearm unless a level explicitly assigns another.

## Six arena test weapons

The paused **Test weapon** choice cycles the active member's arena loadout. It uses the existing Pause-menu controls on touch, controller and keyboard, rather than adding a combat button. Each stable member keeps the selected kind when switching between leader and companion.

| Test firearm | Assisted/effective reach | Magazine / reload | Purpose |
| --- | ---: | --- | --- |
| Carbine | 14 m | 12 / 1.2 s | Measured precision fire |
| Burst weapon | 12 m | 18 / 1.4 s | Three-shot supporting bursts |
| Scatter weapon | 7 m | 4 / 1.8 s | A wide, close two-hit blast; one trace rather than simulated pellets |
| SMG | 12 m | 24 / 1.5 s | Quick handling and rapid fire with wider bloom |
| Marksman rifle | 64 m | 5 / 2.1 s | Slow, accurate settled shots with a stopping bonus |
| Support gun | 22 m | 36 / 2.8 s | Sustained fire and a longer exposed reload |

A deliberate kind change starts that test gun's magazine afresh, cancels its old queued rounds, targeting state and pose, and requires fresh neutral input. It **does not add shared ammunition**. Merely pressing Previous/Next does not reset a magazine or reload. Restart restores the arena's default character loadouts; leaving the arena creates the destination level's ordinary fresh session.

The bridge and Relay Run retain Miki's carbine, Laura's burst weapon and Tom's scatter weapon. The bench adds no interchangeable inventory, dropped guns, attachments, ammunition types, crafting or saved equipment. Generated sound, primitive props and feedback profiles are prototype support, not final art/audio or verified physical haptics.

## Ownership and verification

`GameSession` owns arena selections and shared resources. `FightSimulation` synchronises equipment into per-member handling, spread and poses, and keeps acquisition separate from actual traces. `EnemyTactics` retains bounded navigation and role-specific destinations. `EncounterStage` caches the finite set of needed props and presents roles; `ShotEffects` presents the bounded fast tracer. No new engine, ECS, physics-projectile framework or navigation dependency is introduced.

[PR #116](https://github.com/RonildoBraga/lauder/pull/116) merged as `8128368` with the exact tree of checked/reviewed source `08c0c4e`. The final standard check passed 51 Blender tests, ten generated sounds, strict formatting, the app build and Swift Testing, including all **18 headless scenarios** and **30 repeated waves**. New coverage exercises long-map hits and nearer obstructions, short assistance versus long travel, acquisition versus committed bursts, neutral/first-miss safety, weapon/equipment lifecycle, Pause/recovery/Restart and bounded effects. The marksman sight-loss review finding is fixed and regressed: reacquisition requires a full new wind-up. Final automatic review completed without findings; Claude had not replied to the GitHub request at integration.

Final-source rendered `arsenal-bench` **167/167** and `enemy-arsenal` **35/35** passed. Six broader rendered regressions passed on preceding `1a5d79f`, whose only later code change was the HUD layout; they are not claimed as six final-layout runs. The final menu and long-compass layout were inspected without overlap. [The prototype plan](../prototype-plan.md#historical-delivery) owns exact-source results, measurements and release status.

A fresh signed **0.1.0 (25)** archive from main `8128368` passed bundle, team, signature and matching-dSYM verification. API-authenticated upload is **COMPLETE** with zero errors, processing is **VALID**, and the unexpired build is **IN_BETA_TESTING**, **INTERNAL_ONLY** and available to the existing internal testers with group/tester membership unchanged. The earlier **0.1.0 (24)** record remains historical, separate from these new results. All five earlier combat phases remain functional prototypes. Phone frame pacing, sustained thermals, physical touch/controller feel, haptics and enjoyment remain unverified in the [deferred checklist](../prototype-plan.md#deferred-phone-and-playtest-checks). Armour/weak points, finished rigs and voice work, Laura's Reposition, Tom's Brace and further story encounters remain outside this assignment.
