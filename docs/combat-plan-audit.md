# Combat plan coverage

**Updated:** 22 November 2026\
**Current work:** [ADR 0014](decisions/0014-continuous-combat-arena.md), implemented with integrated validation, review and delivery pending.\
**Latest verified delivery:** **0.1.0 (23)**, source `2199ad7`, as recorded in the [prototype plan](prototype-plan.md#verification-and-performance).

The original five combat phases are implemented and delivered. That is an implementation result, not a finding that combat already feels finished. This audit distinguishes the delivered prototype, the current arena extension and deliberately deferred features. Exploration and salvage still lead the game; the combat yard is a separate place to repeat and tune encounters.

## The five phases

The previous source passed the standard check, fifteen headless scenarios and the rendered routes recorded in the prototype plan before build 23's verified Apple processing and internal availability. Those results do not validate the new source automatically. The named tests below are the concrete regression coverage to rerun, not a claim that the current run has passed.

| Phase from ADR 0008 | Implemented prototype | Evidence and current regression coverage | What remains |
| --- | --- | --- | --- |
| **1. The shot** | Finite turning, raised-weapon whole-figure pose, spread, recoil, muzzle flashes, impacts, flinch/fall, generated sound and feedback events | [ADR 0008](decisions/0008-weapon-feel-and-combat-plan.md); [WeaponFeelTests](../apple/tests/WeaponFeelTests.swift), [FightSimulationTests](../apple/tests/FightSimulationTests.swift); delivered in build 23 | Current enemy-line removal and actual-ray changes need revalidation. Physical sound/haptics and subjective weight remain unverified. Poses use primitive figures rather than a rig. |
| **2. Cover for the leader** | Automatic proximity cover, directional protection, crouch at low cover, validated tall-edge peek and timed firing exposure; no cover button | [ADR 0009](decisions/0009-leader-cover.md); [LeaderCoverTests](../apple/tests/LeaderCoverTests.swift), [LeaderCoverIntegrationTests](../apple/tests/LeaderCoverIntegrationTests.swift), rendered `leader-cover` route | New tier-aware cover and incoming/outgoing agreement need revalidation. Phone usability, stickiness, edge readability and performance remain unverified. |
| **3. The squad's weapons** | Every recruited leader uses their own carbine, burst or close scatter weapon; per-character magazines, automatic reload, spread and readiness survive role switches; one shared round total | [ADR 0010](decisions/0010-squad-weapons.md); [SquadWeaponTests](../apple/tests/SquadWeaponTests.swift), [SquadWeaponPresentationTests](../apple/tests/SquadWeaponPresentationTests.swift), rendered `squad-weapons` route | Current traces across heights need revalidation. Hardware trigger/haptic differences and touch combinations remain unverified. Tom's scatter is a wide single shot with two-hit damage, rather than a pellet simulation. |
| **4. Companion combat** | Companions fire and seek nearby cover, share cover stances/shields, prefer a valid leader target, react to a flank and retain orders; Regroup suppresses fire | [ADR 0011](decisions/0011-companion-combat.md); [CompanionCombatTests](../apple/tests/CompanionCombatTests.swift), [CompanionCoverPlannerTests](../apple/tests/CompanionCoverPlannerTests.swift), combat routes | Tiered travel, sight and cover need revalidation. The maintainer's “Do they fight like a squad?” remains unanswered. Companions stay near their orders/formation rather than running a global battle plan. |
| **5. Enemies that fight back** | Cover-seeking rifles, flankers and grenadiers; fixed grenade warnings and companion escape. ADR 0014 adds an armed rusher, role-specific bursts, finite tracking and actual-ray damage | [ADR 0012](decisions/0012-tactical-enemies.md), [ADR 0014](decisions/0014-continuous-combat-arena.md); [EnemyTacticsTests](../apple/tests/EnemyTacticsTests.swift), [HostileHandlingTests](../apple/tests/HostileHandlingTests.swift), [EnemyPresentationTests](../apple/tests/EnemyPresentationTests.swift), [BallisticsTests](../apple/tests/BallisticsTests.swift) | Current mixed waves and height-aware fighting need revalidation. Readability, fairness after removing red aim lines, balance, phone performance and “Is each fight a readable puzzle?” remain unverified. |

## The six original combat goals

These are the six requests recorded in [ADR 0008's context](decisions/0008-weapon-feel-and-combat-plan.md#context), rather than additional assignments inferred from a reference game.

| Original goal | Coverage now | Remaining boundary |
| --- | --- | --- |
| **No visible aim line; physical weapon aim** | The player line was removed in phase 1. ADR 0014 now removes hostile exact aim lines too; raised props, limited turning, pitch, recoil and actual shot traces show aim. The target disc and grenade/arrival warnings have separate purposes. | Whole-figure and prop motion are implemented; natural limb animation would need a rig. Enemy readability without the line is a playtest question. |
| **Weapon-specific controller vibration** | Separate player-shot feedback and DualSense trigger settings exist for the three weapon kinds, with the Vibration preference, correct device routing and interruption clearing. | Simulator rules and events do not establish physical output, supported Xbox capabilities or subjective feedback quality. |
| **Different weapons for leaders and companions** | Miki's precision carbine, Laura's light burst weapon and Tom's close scatter weapon work in both roles. Props, timing, spread, magazine and automatic reload differ. | The prototype has no inventory of interchangeable guns, attachments, new weapon art or selectable ammunition. |
| **Cover, peek, aim and protected firing** | Directional proximity cover, low-cover rise, tall-edge peek and firing exposure are shared across the trio and tactical enemies where enabled. ADR 0014 resolves height in actual sight/shot geometry. | Exposure is intentional: firing is not invulnerability. No cover-to-cover button, free climbing or jump system is assigned. |
| **Active, coordinated companions** | Automatic support, cover preferences, focus fire, flank replanning, grenade escape, formations, move/hold orders and Regroup coexist under shared command priority. | Miki's Disrupt is the only signature implemented. Laura's Reposition and Tom's Brace remain proposed. Combat feel and orders under pressure need personal play. |
| **Convincing recoil, flashes, impacts, sound and reactions** | Pooled traces/flashes/impacts, recoil, flinch, falls and generated spatial sound are implemented. Hostile hits now depend on actual rays rather than target selection alone. | This is lightweight ray-based combat, not a physical projectile simulation. Finished animation, recorded voice and a final sound pass are not implied. |

## The current arena request

| Requested change | Implemented scope in ADR 0014 | Validation still required before this delivery |
| --- | --- | --- |
| Continuous enemy arrivals | Repeating three-/four-enemy packs from eight fixed IDs; maximum four alive, two-second safe warnings and a four-second resupply break; fallback retries the same wave, Restart begins wave one | [ArenaWavesTests](../apple/tests/ArenaWavesTests.swift), [ArenaIntegrationTests](../apple/tests/ArenaIntegrationTests.swift), repeated-wave rendered checks; confirm stable actor/entity counts and lifecycle |
| Bigger space, upper/lower ground and more cover/hiding | A 52 × 60 m arena, +2.4 m west deck, −1.8 m east trench, broad ramps at both ends, central crossings and sixteen cover/screen boxes | [CombatYardTests](../apple/tests/CombatYardTests.swift), [TerrainTests](../apple/tests/TerrainTests.swift), [BallisticsTests](../apple/tests/BallisticsTests.swift), rendered whole-party routes through both tiers |
| Different enemy types and timings | Cover rifle, flanker, armed close rusher and grenadier; different ranges, wind-ups, bursts and recoveries, without escalating health each wave | Role/tactic/weapon tests and live mixed-wave scenarios; distinguish useful pressure from merely prolonging a wave |
| Remove the hostile red aiming line | Shared finite barrel turning and seeded spread; short bursts feed actual three-dimensional trace geometry, while threat text, weapon pose and grenade warnings remain | Enemy presentation/handling tests, actual miss/hit/cover tests, opening regressions preserving its authored first miss, and rendered readability |
| Check the earlier plan | All five phases and six original goals mapped above; explicitly deferred items below | Reconcile final source, check results, review and delivery with the shared prototype status |

The Division 2 supplies design inspiration for varied pressure, flanks, space and differently exposed bursts, as described by its designers in [Ubisoft's interview](https://news.ubisoft.com/en-us/article/5wu3eterDz21wNKiAcDJlJ/the-division-2-making-enemies-tougher-and-friendlies-smarter). The prototype uses its own small deterministic rules. Similar design goals do not establish identical AI, aiming or balance.

## Deliberately deferred, rather than open implementation bugs

- Armour plates, weak points, boss systems, health inflation and gear progression.
- Rigged character animation, finished assets, spoken callouts and voice acting.
- Laura's Reposition and Tom's Brace; new ability bars or extra combat controls.
- Free jumping/climbing, stacked floors, full three-dimensional navigation and physics-based traversal.
- The complete Quiet Yard screenplay, new story encounters and a campaign combat-frequency increase.
- Persistent Continue/checkpoints, broader survival meters and new inventory systems.

An observed correctness, collision, lifecycle or input regression in the assigned feature is a bug to fix. An excluded system above is a later design choice requiring a concrete gameplay need and assignment. Unperformed physical and subjective checks remain in the [deferred checklist](prototype-plan.md#deferred-phone-and-playtest-checks); issue closure, passing Simulator routes and TestFlight availability do not answer them.
