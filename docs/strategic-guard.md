# First-tower strategic guard

**Date:** 26 November 2026\
**Status:** Maintainer-authorised implementation in development on `codex/strategic-bridge-guard`. The standard check and rendered Simulator verification pass. Review, merge and a new TestFlight delivery remain pending. The [prototype plan](prototype-plan.md#strategic-guard--in-development) owns those gates. Build 32 and the [original C encounter](encounters/bridge-spider-bot.md) describe the preceding baseline.

## The gameplay question

Can one readable encounter make changing leader worthwhile? The player dismantles the existing C guard with the trio's ordinary weapons, using the tower for cover and choosing when to cross or retreat. Exploration and salvage remain the game's main direction; the bridge still has one optional fight and the west-arch bypass.

This is an introduction to a machine's parts and attack cycle. It does not add a general tactical AI, new enemy family, autonomous companion attacks or signature-ability system.

## Prototype dismantling sequence

The maintainer assigned required contributions from all three characters, alternating enemy attacks and manual leader switching with persistent openings. The sequence, component positions, four-second window and 12-hit core below are this branch's initial implementation choices for playtesting, not settled balance or new story foundations.

| Step | Player's contribution | Persistent result |
|---|---|---|
| Read and disrupt | Miki's long rifle disables the sensor | The sensor stays disabled for this attempt |
| Reach a useful side | Laura's energy sword breaches a side coupling | The coupling stays breached for this attempt |
| Exploit the opening | Tom's minigun hits the exposed reactor when its window opens | Accepted core rounds accumulate across windows; 12 disable the guard |

The sensor and coupling need not be redone each cycle. After the breach, entering recovery opens the reactor for **4 seconds**. A breach made during recovery also opens a full four-second window. This independent exposure clock can outlast the robot's recovery; the visible component and countdown remain authoritative. If a window is missed or only partly used, take cover, wait for the next and continue. Retreat within the encounter preserves the dismantling state; retry and Restart restore the encounter's starting state.

Wrong weapons, closed armour and hits outside the required opening do not bypass the sequence through ordinary hit-point damage. Feedback must distinguish armour from accepted component or core damage so that the rule is learnable. This rule belongs to this guard; it does not replace ordinary weapons' rules in other test fixtures or prescribe every future encounter.

## Movement, attacks and control

- The player switches leader manually with L1 / LB, Q or touch **Next**, retaining the existing party order and neutral-input rules. R1 / RB, T or touch **Swap** selects that character's other weapon.
- The other two follow or obey move/hold orders. They do not attack automatically, activate abilities or complete a step while the player directs someone else.
- Tom can use his existing moving shield dome while he leads. Switching away drops it; the player cannot keep an unattended shield active while Miki or Laura attacks.
- The guard alternates a **three-round precision burst** and a **five-round fan cannon attack**. Body/gun movement, a readable wind-up, the committed attack and recovery communicate its state; no red line reveals its exact aim.
- Actual rays and tower geometry decide whether shots meet cover. Laura's sword also respects solid cover. Dodge movement still resolves against the bridge's blockers and the rolling leader retains the agreed temporary shot immunity.
- The west arch and authored safe exit remain a complete non-combat resolution. Withdrawal is available during an unfinished fight; crossing the safe exit clears it without recording a kill.

Existing input and aim/lock rules serve the encounter. No additional ability bar or character-specific command is required. Component identity, attack timing and progress must remain readable at the existing camera framing and phone-sized pawn scale.

## Verification before declaring it complete

1. Verify role/weapon eligibility, persistent prerequisites, repeated recovery windows, 12 accepted core rounds, armour feedback and both attack patterns with meaningful rule and integration tests.
2. Exercise the real control path in rendered Simulator: dismantle the guard, miss a window and return, switch leaders and weapons, use cover/dodge, retreat, take the west bypass, retry, Pause/Resume and Restart. Check that companions remain followers and the shield drops on a switch.
3. Inspect the actual component cues, target/order markers and shot feedback in both light and the towers' baked shadows. The branch raises ground markers to one shared height above those shadows.
4. Record source-bound checks and review findings in the PR. Physical controls, multi-touch, readability, balance and sustained frame pacing remain separate phone evidence at the next agreed checkpoint.

The first playtest should ask whether the three contributions are clear, whether repeated windows give enough time to act, and whether the player wants another attempt. More enemies, scenes or detailed art follow that result rather than being prerequisites.
