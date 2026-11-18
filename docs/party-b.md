# Party B — alternative specialist actions

**Date:** 18 November 2026

## Assignment and scope

ADR 0003's accepted order of work puts Party B after squad movement S1. On 18 November Claude asked, "Shall I start Party B now, or polish S1's overlaps first?" and the maintainer answered, "Yes". Claude took that as Party B and said so, leaving room for a correction. The scope is the [Party B section of the prototype plan](prototype-plan.md#party-b--prove-alternative-specialist-actions) and the [interaction design](architecture.md#one-interaction). The plan's phone checkpoints are after Party A and Party C, so Party B is checked in the Simulator and on the phone with Party C.

Claude implemented and checked Party B, so nothing below is an independent review. The [README](../README.md) and [prototype plan](prototype-plan.md) own stage and review status.

## What changed

- **Barrier:** a closed barrier now fills the 1.8 m service opening in the depot's west wall, so neither the leader nor the companions can enter the depot. The front entrance stays blocked.
- **Two methods:** with **Lara** leading, standing at the latch spot, the action is **Reach latch**. With **Tomas** leading, standing at the panel spot, it is **Shift panel**: the plan's "Shift loose panel", shortened to fit the touch button. Both spots are on the street side, at the existing floor markers. The latch is a small block on top of the barrier and the loose panel sits at its foot.
- **Role feedback:** with **Miki** leading near the barrier, the HUD explains both methods. Another member at the wrong spot is told who could act there, for example "Lara could reach the latch at the top of the barrier." No companion acts remotely.
- **One shared flag:** either method opens the passage for everyone. The open flag lives in `GameSession`, and repeating either action, by anyone, does nothing more. The world removes the barrier and switches movement and routes to the open layout.
- **Fresh checks:** each press rechecks who leads, where they stand and the current progress, so a prompt left over from a move or a switch cannot act.
- **Data, not special cases:** each action is a small definition in `PrototypeLayout` with its ID, eligible member, standing area, suggestion and result text. The barrier's footprint is there too, and the game checks at load that each action is defined exactly once.
- **Companions:** while the passage is closed they never stop in either standing spot, so they cannot block the leader there, though a moving companion may cross one. After it opens they route through it in either direction.
- **HUD and touch:** the controller hint and the touch action button show the action, such as "Reach latch", where one is available, and otherwise "Look". The HUD shows the role feedback near the barrier.
- **Load time:** the open-passage route grid is built while the game loads. Building it when the passage opened caused a 150 ms hitch in the first Simulator runs.

## Validation

All results are from the iPhone 17 / iOS 27.0 Simulator with Xcode 27.2. Nothing here is phone evidence.

- `./scripts/check` passes, including the new `PartyBTests`:
  - each action is defined exactly once in the layout;
  - the session accepts only the eligible member and only once, and nothing while paused;
  - the closed barrier blocks movement and routes while both standing spots stay reachable;
  - each method opens the passage from a fresh run, and the whole party then goes in and back out;
  - Miki explains both methods and cannot open either;
  - prompts do not survive a move or a switch;
  - repeating either action after opening changes nothing;
  - companions do not stop in the standing spots.
- The S1 round trip now opens the passage with Lara first. Every scripted playtest also runs without rendering in the standard check.
- **Rendered playtests** with `./scripts/playtest` on the final code, all passing:

| Scenario | What it does | Result | Bodies overlapping |
|---|---|---|---|
| `closed` | Miki at the latch, then Tomas at the latch; both actions refused | Pass, 15/15 steps | 2.3% of frames |
| `route` | Lara opens with the latch, then the depot round trip | Pass, 24/24 steps | 0.9% |
| `panel` | Tomas opens with the panel, and the party goes into the depot | Pass, 12/12 steps | 3.8% |
| `leaders` | Lara opens, then the round trip under each leader | Pass, 59/59 steps | 1.5% |
| `all` | `closed`, `route`, reversals, switches and walls in one run | Pass, 88/88 steps | 2.8% |

Frame times averaged 16.7 ms in every run. Every frame over 25 ms, the slowest at 37 ms, came in the first half second after launch, before any input. None came when the passage opened, now that the open grid is built at load. In no run did a companion stand still in a standing spot while the passage was closed. In `all`, one companion's target crossed both spots for 0.3 s just after a switch, as the new leader walked away. The screenshots show the HUD at each step: "Reach latch" with Lara at the latch, "Shift panel" with Tomas at the panel, Miki's explanation, and the party inside the depot afterwards.

## Limits

- The maintainer has played it on the phone within [Party C's loop](party-c.md#phone-checkpoint--18-november-2026), but whether a new player understands why to switch is untested. That is the plan's exit question for Party B.
- Apart from that phone checkpoint, every check ran in the Simulator with scripted input.
- Both methods are single presses with text feedback, as the plan specifies. They show role-gated prompts and alternatives, not different movement skills.
- Party C's Restart, which would close the passage again, does not exist yet; a new launch starts with it closed.
