# First-tower strategic guard

**Date:** 27 November 2026\
**Status:** Shared health, optional weak-point bonuses and [damage feedback](damage-feedback.md) are in development on `codex/guard-damage` under [issue #183](https://github.com/RonildoBraga/lauder/issues/183), based on [PR #175](https://github.com/RonildoBraga/lauder/pull/175), source `5421873`. New source/rendered verification is pending in the [prototype plan](prototype-plan.md#guard-damage-and-feedback--in-development). Internal [TestFlight 0.1.0 (35)](prototype-plan.md#build-35-testflight-preview) remains the delivered preview. Earlier records below describe its mandatory dismantling baseline, not proof of this revision.

The maintainer confirmed build 34's basic Attack/Defend commands and authorised [guard retaliation](guard-retaliation.md) in [issue #171](https://github.com/RonildoBraga/lauder/issues/171). That earlier comparison retained the mandatory damage rules and is delivered in build 35. On 27 November the maintainer asked for every successful hit to cause damage and then said **“Proceed with your recommendations”** to shared health, meaningful normal attacks and optional weakness rewards (chat; no public permalink). The [damage contract](damage-feedback.md) records that new authorisation; it does not authorise merge or another release.

## The gameplay question

Can one readable encounter make the trio's different roles work together? The player dismantles the existing C guard with their ordinary weapons, directing a leader while companions contribute independently, using the tower for cover and choosing when to cross or retreat. Switching remains available for direct control. Exploration and salvage remain the game's main direction; the bridge still has one optional fight and the west-arch bypass.

This is an introduction to a machine's parts and attack cycle. Ordinary attacks now have an assigned positive-damage path, while the parts supply optional high-value opportunities. A general tactical AI, new enemy family and signature-ability system remain outside the task.

## Prototype dismantling sequence

The guard has one shared health pool, initially **1,500**. Every actual damaging enemy contact reduces it. Body armour, a closed component and an unmatched weapon receive normal damage; the matching weapon hitting an exposed part receives **×3**. These are prototype tuning values. A character's name alone supplies no damage bonus, and reaching zero health is the sole damage-based victory condition.

| Optional step | Preferred native weapon | Persistent result |
|---|---|---|
| Read and disrupt | Miki's long rifle on the exposed sensor | Bonus health damage; the sensor stays disabled for this attempt |
| Reach a useful side | Laura's energy sword on an exposed coupling | Bonus health damage; the coupling stays breached for this attempt |
| Exploit the opening | Tom's minigun on an exposed reactor | Bonus damage to the same shared health pool |

The sensor and coupling need not be redone each cycle. After the breach, entering recovery opens the reactor for **4 seconds**. A breach made during recovery also opens a full four-second window. This independent exposure clock can outlast the robot's recovery; the visible component and countdown identify the bonus opportunity. A closed or missed window does not make ordinary attacks ineffective. Retreat within the encounter preserves health loss and optional structural progress; Retry and Restart restore their starting state.

Normal and unmatched contacts show white applied-damage numbers. Matched exposed-part contacts show red numbers and another weak-point cue; effective impacts use restrained existing effects. The [damage contract](damage-feedback.md) owns weapon values, aggregation, health presentation and the contact-validation rules. There is no required core-round total and no compulsory three-character chain before a kill.

## Movement, attacks and control

- The player switches leader manually with L1 / LB, Q or touch **Next**, retaining the existing party order and neutral-input rules. R1 / RB, T or touch **Swap** selects that character's other weapon.
- After an explicit Attack order and engagement, companions prefer exposed matching parts and may use safe ordinary fire when that opportunity is unavailable, respecting the [bounded contract](companion-autonomy.md). Defend stops their attacks and recalls them using nearby cover. The player always owns the leader.
- Tom can use his existing moving shield dome while he leads. Switching away drops it; the player cannot keep an unattended shield active while Miki or Laura attacks.
- The guard alternates a **three-round precision burst** and a **five-round fan cannon attack**. Body/gun movement, a readable wind-up, the committed attack and recovery communicate its state; no red line reveals its exact aim.
- Actual rays and tower geometry decide whether shots meet cover. Laura's sword also respects solid cover. Dodge movement still resolves against the bridge's blockers and the rolling leader retains the agreed temporary shot immunity.
- The west arch and authored safe exit remain a complete non-combat resolution. Withdrawal is available during an unfinished fight; crossing the safe exit clears it without recording a kill.

Existing input and aim/lock rules serve the encounter. No additional ability bar or character-specific command is required. Component identity, attack timing and progress must remain readable at the existing camera framing and phone-sized pawn scale.

The retaliation revision selects a visible recent attacker only between warned cycles, names that member with a HUD cue and one two-note warning, and preserves their identity through recovery. Commitment still freezes a point, so leader switching cannot redirect the burst. Quiet acquisition, real cover, Defend recall and the bypass remain intact. The [retaliation document](guard-retaliation.md) owns the detailed fairness and verification contract. This damage assignment retains [PR #175's cover](bridge-cover-spacing.md); it adds no further enemy or cover geometry.

## Companion autonomy — in development

After the maintainer's generic build 33 feedback **“It worked nice”**, the choice **“Companions can complete the weakpoint steps too”** authorised independent contributions. The later explicit Attack/Defend requirement still governs them. The squad defaults to Defend; Up/Down on the D-pad or keyboard orders Attack/Defend. Defend clears old position orders and revokes firing, while later Go/Hold orders remain defensive. The 27 November revision makes ordinary companion attacks useful alongside their preferred weak-point roles. The existing destination bounds, real geometry, exposure, weapon state and ordinary vulnerability apply. Formation/Follow still regroups temporarily without changing stance. No automatic shield, signature or teleport is added. The [autonomy document](companion-autonomy.md) owns the detailed branch contract and verification requirements.

## Earlier mandatory prototype

The maintainer's 26 November assignment required all three contributions. Build 33 delivered the manual sequence: Miki's long rifle disabled the sensor, Laura's sword breached the coupling, and twelve accepted Tom minigun core contacts across four-second windows defeated the guard. Wrong-role/body/closed-part hits caused no ordinary health damage. Build 34 added bounded companions with explicit Attack/Defend; build 35 added retaliation. Those earlier checks and deliveries remain historical evidence in the prototype plan, not validation of the new health rules.

## Verification boundary

The manual build 33 prototype passed its recorded source/Simulator checks and was delivered for phone testing. Current damage/feedback verification is pending; earlier results do not establish this revision. The review questions are:

1. Verify positive ordinary/closed/unmatched damage, matched exposed bonuses, optional structural progress, repeated recovery windows, shared-health victory, truthful feedback and both attack patterns with meaningful rule and integration tests. Check solo victory and player/companion equality rather than retaining the old compulsory-role tests.
2. Exercise the real control path in rendered Simulator: defeat the guard through ordinary fire and through useful weakness opportunities, miss a window and return, switch leaders and weapons, use cover/dodge, retreat, take the west bypass, retry, Pause/Resume and Restart. Check bounded companion contributions and order priority. The shield must still drop on a switch.
3. Inspect the actual component cues, target/order markers and shot feedback in both light and the towers' baked shadows. The branch raises ground markers to one shared height above those shadows.
4. Record source-bound checks and review findings in the PR. Physical controls, multi-touch, readability, balance and sustained frame pacing remain separate phone evidence at the next agreed checkpoint.

The first playtest should ask whether ordinary hits feel useful, the matching weapon produces a clear improvement, the numbers remain legible without hiding warnings and the player wants another attempt. More enemies, scenes or detailed art follow that result rather than being prerequisites.
