# First-tower strategic guard

**Date:** 26 November 2026\
**Status:** The manual-control prototype was delivered as internal TestFlight **0.1.0 (33)** from `f67bd2c` through [PR #167](https://github.com/RonildoBraga/lauder/pull/167), before merge. Its checks and generic phone feedback are recorded in the [prototype plan](prototype-plan.md#build-33-testflight-preview). [Companion autonomy](companion-autonomy.md) is implemented on `codex/companion-autonomy`, with source and rendered Simulator verification in its [plan section](prototype-plan.md#companion-autonomy--in-development); the [build 34 preview](prototype-plan.md#build-34-testflight-preview) is delivered, while physical acceptance and merge remain separate gates. Build 32 and the [original C encounter](encounters/bridge-spider-bot.md) describe the earlier baseline; the preview does not imply a merge.

The maintainer confirmed build 34's basic Attack/Defend commands and authorised [guard retaliation](guard-retaliation.md) in [issue #171](https://github.com/RonildoBraga/lauder/issues/171). That branch has source and Simulator verification recorded in the [prototype plan](prototype-plan.md#guard-retaliation--in-development), without a new delivery or phone acceptance; current damage, alternating patterns, timing and weakpoint requirements remain unchanged for the comparison.

## The gameplay question

Can one readable encounter make the trio's different roles work together? The player dismantles the existing C guard with their ordinary weapons, directing a leader while companions contribute independently, using the tower for cover and choosing when to cross or retreat. Switching remains available for direct control. Exploration and salvage remain the game's main direction; the bridge still has one optional fight and the west-arch bypass.

This is an introduction to a machine's parts and attack cycle. Build 33 did not add autonomous companion attacks. The new bounded autonomy assignment below extends this same encounter; a general tactical AI, new enemy family and signature-ability system remain outside the task.

## Prototype dismantling sequence

The maintainer assigned required contributions from all three characters, alternating enemy attacks and persistent openings. Build 33 required manual leader switching for each contribution; the newer autonomy choice allows companions to complete their own steps too. The sequence, component positions, four-second window and 12-hit core below are initial implementation choices for playtesting, not settled balance or new story foundations.

| Step | Character contribution | Persistent result |
|---|---|---|
| Read and disrupt | Miki's long rifle disables the sensor | The sensor stays disabled for this attempt |
| Reach a useful side | Laura's energy sword breaches a side coupling | The coupling stays breached for this attempt |
| Exploit the opening | Tom's minigun hits the exposed reactor when its window opens | Accepted core rounds accumulate across windows; 12 disable the guard |

The sensor and coupling need not be redone each cycle. After the breach, entering recovery opens the reactor for **4 seconds**. A breach made during recovery also opens a full four-second window. This independent exposure clock can outlast the robot's recovery; the visible component and countdown remain authoritative. If a window is missed or only partly used, take cover, wait for the next and continue. Retreat within the encounter preserves the dismantling state; retry and Restart restore the encounter's starting state.

Wrong weapons, closed armour and hits outside the required opening do not bypass the sequence through ordinary hit-point damage. Feedback must distinguish armour from accepted component or core damage so that the rule is learnable. This rule belongs to this guard; it does not replace ordinary weapons' rules in other test fixtures or prescribe every future encounter.

## Movement, attacks and control

- The player switches leader manually with L1 / LB, Q or touch **Next**, retaining the existing party order and neutral-input rules. R1 / RB, T or touch **Swap** selects that character's other weapon.
- In delivered build 33, the other two follow or obey move/hold orders without attacks. On the autonomy branch they may fight and complete their own native steps after an explicit Attack order and engagement, respecting the [bounded contract](companion-autonomy.md). Defend stops their attacks and recalls them using nearby cover. The player always owns the leader.
- Tom can use his existing moving shield dome while he leads. Switching away drops it; the player cannot keep an unattended shield active while Miki or Laura attacks.
- The guard alternates a **three-round precision burst** and a **five-round fan cannon attack**. Body/gun movement, a readable wind-up, the committed attack and recovery communicate its state; no red line reveals its exact aim.
- Actual rays and tower geometry decide whether shots meet cover. Laura's sword also respects solid cover. Dodge movement still resolves against the bridge's blockers and the rolling leader retains the agreed temporary shot immunity.
- The west arch and authored safe exit remain a complete non-combat resolution. Withdrawal is available during an unfinished fight; crossing the safe exit clears it without recording a kill.

Existing input and aim/lock rules serve the encounter. No additional ability bar or character-specific command is required. Component identity, attack timing and progress must remain readable at the existing camera framing and phone-sized pawn scale.

The retaliation revision selects a visible recent attacker only between warned cycles, names that member with a HUD cue and one two-note warning, and preserves their identity through recovery. Commitment still freezes a point, so leader switching cannot redirect the burst. Quiet acquisition, real cover, Defend recall and the bypass remain intact. The [retaliation document](guard-retaliation.md) owns the detailed fairness and verification contract; no new enemy, cover geometry or general threat system is assigned.

## Companion autonomy — in development

After the maintainer's generic build 33 feedback **“It worked nice”**, the choice **“Companions can complete the weakpoint steps too”** authorises independent contributions. The maintainer then required an explicit Attack order before they fight, and a Defend command that seeks cover and returns toward the leader. The squad defaults to Defend; Up/Down on the D-pad or keyboard orders Attack/Defend. Defend clears old position orders and revokes firing, while later Go/Hold orders remain defensive. All three roles remain necessary; switching is optional for directing each step. The initial 8 m leash, real geometry, exposure, weapon state and ordinary vulnerability apply. Formation/Follow still regroups temporarily without changing stance. No automatic shield, signature or teleport is added. The [autonomy document](companion-autonomy.md) owns the detailed branch contract and verification requirements.

## Verification boundary

The manual build 33 prototype passed its recorded source/Simulator checks and was delivered for phone testing. The following remain relevant review questions, with new autonomy-specific checks owned by its separate gate:

1. Verify role/weapon eligibility, persistent prerequisites, repeated recovery windows, 12 accepted core rounds, armour feedback and both attack patterns with meaningful rule and integration tests.
2. Exercise the real control path in rendered Simulator: dismantle the guard, miss a window and return, switch leaders and weapons, use cover/dodge, retreat, take the west bypass, retry, Pause/Resume and Restart. For the manual baseline, check that companions remain followers; for the new revision, check their bounded independent contributions and order priority. The shield must still drop on a switch.
3. Inspect the actual component cues, target/order markers and shot feedback in both light and the towers' baked shadows. The branch raises ground markers to one shared height above those shadows.
4. Record source-bound checks and review findings in the PR. Physical controls, multi-touch, readability, balance and sustained frame pacing remain separate phone evidence at the next agreed checkpoint.

The first playtest should ask whether the three contributions are clear, whether repeated windows give enough time to act, and whether the player wants another attempt. More enemies, scenes or detailed art follow that result rather than being prerequisites.
