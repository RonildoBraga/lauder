# ADR 0014 — A repeatable combat arena with real elevation

**Status:** Implemented; integrated validation, review and delivery pending\
**Date:** 22 November 2026

## Assignment and reference

After Relay Run's delivery, the maintainer requested **“continuous enemy spawn”** in the combat test, a larger place with **“elevations and down levels and more places to hide and find cover”**, different enemy types/timings, removal of the enemies' red aiming line and a comparison with the earlier combat plan. [Issue #112](https://github.com/RonildoBraga/lauder/issues/112) records this assignment. The current conversation supplies the maintainer's request; an agent's interpretation of its details is not a separate maintainer quotation.

This extends the combat test. Exploration and salvage remain the main game, with occasional combat, and no additional story encounter is assigned. The continuous Simulator development, reviewed integration and TestFlight authority from [ADR 0011](0011-companion-combat.md) continues. Physical results remain separate evidence.

Ubisoft's [interview with The Division 2's AI designers](https://news.ubisoft.com/en-us/article/5wu3eterDz21wNKiAcDJlJ/the-division-2-making-enemies-tougher-and-friendlies-smarter) describes varied pressure through advancing, retreating, flanking, use of space and differently exposed firing bursts. Lauder adapts those design principles to its top-down camera and small squad. The interview does not establish Ubisoft's exact aiming algorithm, and this implementation does not claim to reproduce it.

## Decisions

### A larger test, with two useful approaches

The greybox yard measures **52 × 60 m**. Its entrance remains protected by the original wall. A **2.4 m raised west deck** and **1.8 m lowered east trench** each have wide ramps at both ends; the middle has several clusters of low cover and tall sight-breaking screens. Cover sits on its actual local floor. These routes give the whole trio alternatives rather than forcing an agility specialist through a passage alone.

`Terrain` defines one walkable surface at each ground point. Flat patches and linear ramps supply height, a terrain mesh and solid cliff-edge collision. Navigation, party and hostile placement, camera targeting, order projection, cover, shot geometry and grenade presentation use that height. This is a bounded height field: no stacked floors, tunnels, jumping, climbing or falling physics.

### Repeated waves with fixed memory and actors

`ArenaWaves` rotates through **eight authored slots**, two slots for each of four roles. Packs alternate **three and four enemies**, with **at most four active**. Every arrival has a **two-second warning**: amber square corners and a shrinking overhead bar, visually distinct from a grenade's blast circle. A slot must remain at least **8 m from every party member**, and the fight also checks occupancy. An unsafe slot cancels; a replacement receives its own full warning. A delayed safe arrival is preferable to creating an enemy inside the party.

After a pack is defeated and its live grenades finish, a **four-second break** restores the trio's hits, the shared ammunition and weapon readiness. The next pack begins without restarting the level. A third hit falls the party back to the entrance and retries the **same wave** after recovery and resupply. **Restart** returns to **wave one**. This supersedes the old combat test's finite “clear the yard” ending and its retain-damage/retain-spent-rounds fallback; finite encounters elsewhere retain their own policies.

The simulation and stage reuse the same hostile IDs, bodies, weapons, shields, warnings and shot effects. Recycling removes the prior life’s damage, defeated and searched records. There is no growing spawn queue, per-wave entity graph or defeated-enemy history. Pause advances no spawn, recovery, weapon or grenade timer. A level change owns a fresh run, as before.

`Level.arena` enables the loop only in the combat yard. The shared `CombatYard.combat` settings do not enable waves in Relay Run or test fixtures that borrow the squad rules.

### Four pressures, with different openings

| Role | Prototype behaviour | Starting weapon timing |
| --- | --- | --- |
| Cover rifle | Chooses nearby shelter, exposes itself to fire, remains within 6 m of home | Three-shot burst; 1.7 s wind-up, 2.4 s recovery, 18 m reach |
| Flanker | Chooses a reachable side angle, remains within 6 m of home | Two-shot burst; 1.2 s wind-up, 1.7 s recovery, 18 m reach |
| Armed rusher | Advances towards a legal close firing position, within 14 m of home | Two-shot burst; 0.8 s wind-up, 1.2 s recovery, 7 m reach |
| Grenadier | Throws at a fixed landing point; warns the ground and makes the squad move | 2.2 s wind-up, 5 s recovery, 19 m reach; existing fuse and blast rules |

These are tunable implementation defaults, not new character canon or a promise of final balance. The armed rusher uses a rifle and ordinary damage rules; the opening's scripted knife attacker retains its existing behaviour. No armour, weak points, boss health or escalating hit totals are added.

### Enemy aim is shown by the weapon

The maintainer's current request supersedes **ADR 0008's earlier choice to retain the red hostile wind-up line**, also retained by ADR 0012. The stage removes that exact aiming line everywhere. Raised rifle props, finite turning, recoil, shot effects and threat text communicate attack readiness; the fixed grenade warning remains.

Ordinary incoming and outgoing shots now use the same actual world heights in every venue. Low cover protects a crouched body; a standing body above a low block remains exposed, including in a level without the optional cover stance. Tall cover still stops the shot. Grenades retain their existing low-cover blast rule, check their visible flight arc against scenery and terrain, and cannot damage an unrelated tier through a retaining wall.

A rifle wind-up now permits discharges rather than awarding a hit. `HostileHandling` turns the barrel at a finite rate, supplies short authored bursts and seeded spread, and cancels queued shots on disruption, defeat or loss of contact. `Ballistics` traces the actual discharge through three-dimensional bodies, cover boxes and terrain. The ray decides which eligible party member it meets, if any; choosing a target does not guarantee damage. Party weapons use the same height-aware trace geometry while keeping their own handling, assistance and spread profiles. The bridge's authored first miss remains non-damaging.

## Ownership

- `CombatYard` supplies the place, terrain, profiles and reusable slots.
- `ArenaWaves` owns bounded cadence and warning state; `FightSimulation` activates actors and owns targeting, weapons, projectiles and presentation values.
- `GameSession` remains the sole owner of ammunition, party hits and hostile progress. Its arena reset clears only those reused IDs and performs the explicit resupply.
- `Terrain` and `Ballistics` supply plain-Swift height and trace queries. Existing navigation and swept-body movement handle the authored ramps and cliff blockers.
- `EncounterStage`, `ArenaArrivalMarker` and existing effect pools only present values. They never schedule arrivals or count damage.

## Verification and remaining limits

The [combat plan audit](../combat-plan-audit.md) maps all five phases and the six original goals to implementation, existing evidence and remaining limitations. Current changes require the full standard check, focused elevation/aim/wave integration tests, long-loop bounded-state checks, rendered combat/terrain routes, source review and signed Release/TestFlight verification before delivery is reported. The [prototype plan](../prototype-plan.md#verification-and-performance) owns actual results and the latest verified build.

Baseline-phone frame pacing, sustained thermals, physical touch/controller combinations, haptics and the maintainer's judgement of enemy readability and enjoyment remain unverified. Simulator evidence cannot establish them. Deferred armour, weak points, rigs, voice work, Laura's Reposition and Tom's Brace remain outside this assignment rather than unfinished parts of this arena implementation.
