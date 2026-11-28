# First-tower strategic guard

> Historical bridge contract, preserved at the [checkpoint](milestones/bridge-prototype.md). The [current duel](prototype-plan.md) does not include this system.

**Date:** 27 November 2026\
**Status:** The current [eye, legs and grenade revision](robot-eye-legs-grenades.md) is implemented under [issue #192](https://github.com/RonildoBraga/lauder/issues/192), based on delivered [build 37](bridge-prototype-plan.md#build-37-testflight-preview). Source/native and rendered Simulator verification passed on `303617b`, recorded in the [prototype plan](bridge-prototype-plan.md#eye-legs-and-grenades--in-development). Internal [build 38](bridge-prototype-plan.md#build-38-testflight-preview) delivers it, and PRs #193/#195 are merged after basic build 38 phone success. The current [locomotion follow-up](bridge-prototype-plan.md#leg-loss-locomotion--in-development), under issue #196, is source/Simulator verified and merged in [PR #197](https://github.com/RonildoBraga/lauder/pull/197), with issue #196 closed. [Build 39](bridge-prototype-plan.md#build-39-testflight-preview) now delivers the locomotion; its physical acceptance remains unverified, and build 38 is the earlier comparison. Builds 33–38 remain source-specific historical evidence, not verification of this follow-up.

**Current delivered revision:** Closed [issue #199](https://github.com/RonildoBraga/lauder/issues/199) adds the [leg-break stagger](robot-eye-legs-grenades.md#leg-break-stagger-follow-up), accepted after basic build 39 phone success. It interrupts unresolved rounds on a new nonlethal leg loss, preserves the interrupted volley’s full recovery or an existing recovery’s remainder and requires a fresh complete warning. Original source and rendered checks pass on `4e114bb`; it merged in [PR #202](https://github.com/RonildoBraga/lauder/pull/202) as `9b5ec53` and is delivered in [build 40](bridge-prototype-plan.md#build-40-testflight-preview). Physical acceptance remains unverified.

The earlier build 34 command feedback, build 35 retaliation and build 36 shared-health authorisation remain recorded in the [prototype plan](prototype-plan.md). After build 37, the maintainer requested critical eye hits, repeated Laura sword strikes that detach an individual leg and slow the robot, and grenades, choosing **“Tom only; manual throws”**. The [robot contract](robot-eye-legs-grenades.md) records that assignment and separates it from prototype tuning choices; it does not change the trio's biographies.

## The gameplay question

Can one readable encounter make the trio's different roles work together? The player dismantles the existing C guard with their ordinary weapons, directing a leader while companions contribute independently, using the tower for cover and choosing when to cross or retreat. Switching remains available for direct control. Exploration and salvage remain the game's main direction; the bridge still has one optional fight and the west-arch bypass.

This is an introduction to a machine's parts and attack cycle. Ordinary attacks now have an assigned positive-damage path, while the parts supply optional high-value opportunities. A general tactical AI, new enemy family and signature-ability system remain outside the task.

## Current eye and leg rules

The guard has one shared health pool, initially **1,500**. Every actual damaging enemy contact reduces it. Ordinary body and leg hits cause normal damage; any gun's actual eye hit receives **×3**, at any attack phase. These are prototype tuning values. A character's name or a lock alone supplies no damage bonus, and reaching zero health is the sole damage-based victory condition.

| Opportunity | Native action | Persistent result |
|---|---|---|
| Aim at the visible red eye | Any firearm that really hits it | Critical shared-health damage; the eye stays available |
| Damage one intact leg | Three Laura sword contacts on that same leg | Normal damage on each hit, then that leg detaches |
| Slow the machine | Detach more of its four independent legs | Translation falls to 75%, 50%, 25%, then zero |

There is no sensor-disable prerequisite, coupling breach or timed core window in this revision. Four lost legs stop translation and settle the hull using one shared native/presentation offset. The current [locomotion follow-up](robot-eye-legs-grenades.md#leg-loss-locomotion-follow-up) also slows physical turning and the remaining feet; a grounded guard retains only a slow emergency pivot and warned attacks. The existing leg assemblies become bounded noncolliding props, while the remaining feet keep their planted gait. Retreat within the encounter preserves health loss and per-leg progress; Retry and Restart restore them.

Normal contacts show white applied-damage numbers. Eye criticals show red numbers and another weak-point cue; effective impacts use restrained existing effects. A damaged leg gains a small indicator and drops on the third accepted sword hit. The [damage contract](damage-feedback.md) owns weapon values, aggregation, health presentation and contact validation. There is no compulsory three-character chain before a kill.

## Movement, attacks and control

- The player switches leader manually with L1 / LB, Q or touch **Next**, retaining the existing party order and neutral-input rules. R1 / RB, T or touch **Swap** selects that character's other weapon.
- After an explicit Attack order and engagement, Miki/Tom prefer reachable eye shots and Laura prefers an intact leg with her sword. Safe ordinary fire remains useful when those opportunities are unavailable, respecting the [bounded contract](companion-autonomy.md). Defend stops their attacks and recalls them using nearby cover. The player always owns the leader.
- Tom can use his existing moving shield dome while he leads. Switching away drops it; the player cannot keep an unattended shield active while Miki or Laura attacks.
- Tom alone can manually throw a grenade with Circle/B, keyboard C or touch Grenade. The initial 8-second recharge, 10 m throw and cover-blocked ordinary blast are in the [robot contract](robot-eye-legs-grenades.md); companions never throw automatically.
- The guard alternates a **three-round precision burst** and a **five-round fan cannon attack**. Body/gun movement, a readable wind-up, the committed attack and recovery communicate its state; no red line reveals its exact aim.
- Actual rays and tower geometry decide whether shots meet cover. Laura's sword also respects solid cover. Dodge movement still resolves against the bridge's blockers and the rolling leader retains the agreed temporary shot immunity.
- The west arch and authored safe exit remain a complete non-combat resolution. Withdrawal is available during an unfinished fight; crossing the safe exit clears it without recording a kill.

Existing input and aim/lock rules serve the encounter, with the assigned Tom grenade control. Eye identity, leg damage and attack timing must remain readable at the existing camera framing and phone-sized pawn scale.

The retaliation revision selects a visible recent attacker only between warned cycles, names that member with a HUD cue and one two-note warning, and preserves their identity through recovery. Commitment still freezes a point, so leader switching cannot redirect the burst. Quiet acquisition, real cover, Defend recall and the bypass remain intact. The [retaliation document](guard-retaliation.md) owns the detailed fairness and verification contract. This damage assignment retains [PR #175's cover](bridge-cover-spacing.md); it adds no further enemy or cover geometry.

## Companion autonomy — in development

After the maintainer's generic build 33 feedback **“It worked nice”**, the choice **“Companions can complete the weakpoint steps too”** authorised independent contributions. The later explicit Attack/Defend requirement still governs them. The squad defaults to Defend; Up/Down on the D-pad or keyboard orders Attack/Defend. Defend clears old position orders and revokes firing, while later Go/Hold orders remain defensive. Ordinary companion attacks stay useful alongside the eye/leg preferences. Existing destination bounds, real geometry, weapon state and ordinary vulnerability apply. Formation/Follow still regroups temporarily without changing stance. No automatic shield, grenade, signature or teleport is added to companion AI. The [autonomy document](companion-autonomy.md) owns its verification requirements.

## Earlier mandatory prototype

The maintainer's 26 November assignment required all three contributions. Build 33 delivered the manual sequence: Miki's long rifle disabled the sensor, Laura's sword breached the coupling, and twelve accepted Tom minigun core contacts across four-second windows defeated the guard. Wrong-role/body/closed-part hits caused no ordinary health damage. Build 34 added bounded companions with explicit Attack/Defend; build 35 added retaliation. Those earlier checks and deliveries remain historical evidence in the prototype plan, not validation of the new health rules.

Builds 36–37 replaced that mandatory gate with 1,500 shared health and optional matched-weapon bonuses: long rifle on the sensor, sword on a coupling and minigun on a core exposed for four seconds after recovery. Those previews retained the sensor/coupling progression. The current revision removes that sequence rather than claiming those older sources already used persistent eye criticals or detachable legs.

## Verification boundary

The earlier previews passed their recorded checks and deliveries, including the damage source `533f012`. They do not validate issue #192. Rule/native and rendered Simulator verification for the delivered eye/leg/grenade baseline passed on `303617b`, recorded in the [prototype plan](bridge-prototype-plan.md#eye-legs-and-grenades--in-development). The newer [locomotion follow-up](bridge-prototype-plan.md#leg-loss-locomotion--in-development) has its own source-specific results. The verification contract is:

1. Verify positive ordinary damage, repeated actual eye criticals with each gun, independent three-hit leg counters, translation penalties, grounded hull/eye/muzzle agreement, shared-health victory, truthful feedback and both attack patterns. Check player/companion equality and one health change per contact.
2. Exercise the real control path in rendered Simulator: use eye shots and sword leg losses, switch leaders/weapons, throw as Tom with real cover and one ordinary blast per target, use cover/dodge, retreat, take the west bypass, retry, Pause/Resume and Restart. Check companion contributions, order priority and fresh input. The shield must still drop on a switch.
3. Inspect the actual component cues, target/order markers and shot feedback in both light and the towers' baked shadows. The branch raises ground markers to one shared height above those shadows.
4. Record source-bound checks and review findings in the PR. Physical controls, multi-touch, readability, balance and sustained frame pacing remain separate phone evidence at the next agreed checkpoint.

The next playtest should ask whether eye hits, progressive leg loss and Tom's grenade are easy to understand, ordinary hits stay useful, feedback leaves warnings clear and the player wants another attempt. More enemies, scenes or detailed art follow that result rather than being prerequisites.
