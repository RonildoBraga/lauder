# Party C — close the shared loop

**Date:** 18 November 2026

## Assignment and scope

After merging [Party B](party-b.md), the maintainer instructed: **“Merge and proceed with the next step”**. Under ADR 0003's accepted order of work and the [prototype plan](prototype-plan.md#party-c--close-and-evaluate-the-shared-loop), the next step is Party C: the keeper's briefing, one regulator, the transmitter repair, a short crew call, completion, **Read plan** and an in-memory Restart. The plan's phone session at the end of Party C is recorded [below](#phone-checkpoint--18-november-2026).

Claude implemented and checked Party C, so nothing below is an independent review. The [README](../README.md) and [prototype plan](prototype-plan.md) own stage and review status.

### What this does not settle

The plan asked for the relationships and ending dialogue to be finalised before Party C, and the walkthrough keeps its water-tap exchange for review before it becomes game content. Neither has happened. When authorising the merge, the maintainer [accepted Claude's recommendation](https://github.com/RonildoBraga/lauder/pull/37#issuecomment-6968168004) to keep the provisional dialogue for now and settle the relationships later: **“I'm ok merge and proceed with your recommendation”**. So:

- Every line is provisional and lives in `MissionScript.swift`. Most come from the [gameplay walkthrough](gameplay-script.md). The keeper's two lines, Miki's inspection, the call's opening and the meeting plan were added to connect them.
- The water-tap exchange and the meal coda are left out. The beat of leaving the water supply connected stays, carried by Miki's inspection and a visible bypass pipe.
- No line uses a family title or implies kinship.

## What changed

- **Mission phase:** `GameSession` owns the phase: briefing, seeking the regulator, carrying it, radio repaired, meeting agreed. The passage flag stays separate. The carried-part indicator, the regulator in its housing or in the transmitter, the transmitter's status light and the objective line are all derived from the phase.
- **Five actions,** defined in `PrototypeLayout.interactions` like Party B's:
  - **Talk to keeper** (any leader) starts the briefing.
  - **Take regulator** (Miki), the plan's "Inspect and take regulator" shortened to fit the touch button. It inspects, takes the part and leaves the water bypass connected.
  - **Repair** (Miki) fits the regulator once. Without it, Miki explains what is missing and nothing changes.
  - **Call** (any leader) reaches the coastal operator and agrees the Old Lock meeting.
  - **Read plan** (any leader) repeats the meeting details without changing progress.
- **Approaches:** the four transmitter actions share one approach inside the shelter, which includes where the party starts, and exactly one is offered in each phase. The regulator's approach is inside the depot, so it is reachable only through the open passage. Every press rechecks the leader, the approach and the phase.
- **Role feedback:** another leader at the housing is told that Miki should inspect the regulator; at the transmitter, that Miki can fit it. Before the briefing, the housing says to talk to the keeper first.
- **Conversations:** an accepted step starts a short speaker-labelled conversation in a panel at the bottom of the screen, and takes effect when it ends: the regulator leaves its housing after Miki's inspection, and finishing the call secures the meeting, as the architecture specifies. The action button shows the next line. Movement, switching and world actions wait until the last line, and the HUD shows the step's result afterwards. Pause keeps the line, and Resume returns to it.
- **Pause menu:** two choices, **Resume** and **Restart**, opening on Resume. Up or down (W/S or the stick) chooses, the action confirms and Pause resumes. On touch the action button reads **Restart** while paused. Confirming straight away resumes, so a habitual press does not lose the run.
- **Restart in place:** the same scene, bodies and update subscription return to the beginning: everyone on their spawn points with Miki leading, the barrier closed, the regulator in its housing and the transmitter unrepaired. The [architecture](architecture.md#restart-and-lifecycle) lists the exact steps. Nothing is rebuilt or reloaded, and the new run waits for every control to be released.
- **Layout data:** the landmarks now carry their own size, so nothing selects per-object data by ID. That addresses #19 L4. Their observations change with the phase.
- **HUD:** the objective line follows the phase, and a "Carrying the regulator" line appears while the part is carried. During a conversation the HUD shows only the leader, the objective and the party, and the conversation's panel carries the Continue hint.
- **Playtests:** the new `mission` scenario plays the whole loop with leader changes, then restarts from the pause menu and starts a new briefing. `all` now ends with a Restart and `mission`. The headless check drives every scenario through the same input rules, release gate and mode handling as the rendered run.

## Validation

All results are from the iPhone 17 / iOS 27.0 Simulator with Xcode 27.2. Nothing here is phone evidence.

- `./scripts/check` passes, including the new `PartyCTests`:
  - the mission advances through its phases in order and only once: any leader can hear the briefing and make the call, and only Miki can take the regulator and repair;
  - a step takes effect when its conversation ends, and Restart part-way through a conversation discards it;
  - repair without the part explains what is missing and changes nothing, and Read plan changes no progress;
  - each phase offers exactly one transmitter action;
  - a conversation holds actions and switching until its last line, and Pause keeps the line;
  - the pause menu opens on Resume; confirming at once resumes without touching the latch Lara stands at; down then confirm restarts, and so does the touch Restart button;
  - the approaches lie on the usable side of their walls;
  - the whole loop works across leader changes, and the part survives every switch;
  - a regulator prompt does not survive a switch or a move;
  - three Restarts each restore the beginning without adding an entity.
- `InputRulesTests` cover conversation presses, menu moves, a direction held when pausing, the touch Restart button and its release gate. Party B's tests still pass. Every scripted scenario, `mission` included, also runs headless in the check, through the same input rules, release gate and mode handling as the rendered run.
- **Rendered playtests** with `./scripts/playtest` on the final code, all passing:

| Scenario | What it does | Result | Bodies overlapping |
|---|---|---|---|
| `mission` | The whole loop with leader changes, then Restart from the pause menu and a new briefing | Pass, 67/67 steps | 0.7% of frames |
| `closed` | Miki, then Tomas, at the latch; both refused | Pass, 15/15 steps | 2.3% |
| `route` | Lara opens with the latch, then the depot round trip | Pass, 24/24 steps | 0.9% |
| `panel` | Tomas opens with the panel, and the party goes into the depot | Pass, 12/12 steps | 3.9% |
| `leaders` | Lara opens, then the round trip under each leader | Pass, 59/59 steps | 1.5% |
| `all` | `closed`, `route`, reversals, switches, walls, a Restart and `mission` in one run | Pass, 165/165 steps | 2.5% |

Frame times averaged 16.7–16.9 ms. In five of the six launches the first frame took 124–150 ms, before any input. Merged main showed the same, 123–142 ms, in a comparison run in this session, while Party B's runs earlier in the day did not, so this comes from the Simulator, not this change. Every other frame over 25 ms, the slowest at 32 ms, came in the first 1.1 s. In `mission`, which includes a Restart, no frame took longer than 32 ms.

The party update averaged about 0.7 ms per frame in this Debug build. Its slowest frame was 5.8 ms in `mission` and 4.1 ms in `all`, the two runs with a Restart, and at most 2.4 ms in the others. On the phone, display pacing is in the [phone performance sample](#phone-performance-sample); the party update's cost was not measured there.

The first rendered runs of this change found two problems, now fixed. An early version built the closed-passage route grid on the first frame of play, costing 44 ms; both grids are built at load again, as on main. And a step's result and new objective appeared while its conversation was still playing; the step now takes effect when the conversation ends, as the architecture says, and the HUD hides the result line until then.

The screenshots show the keeper's lines with the objective unchanged until the briefing ends, Tomas told that Miki can fit the regulator, the regulator gone from its housing beside the water bypass, the regulator fitted on the transmitter during the call, the pause menu with Restart chosen, and everyone back at the start afterwards.

## Phone checkpoint — 18 November 2026

Claude built a signed Release build of `main` at `4cd58ab` (version 0.1.0, build 1) with Xcode 27.2 and installed it directly on the baseline iPhone 13 Pro Max, on iOS 27.2.1, without TestFlight. Claude then gave the maintainer the Party C checks [listed on #18](https://github.com/RonildoBraga/lauder/issues/18#issuecomment-6965256982), with frame pacing reduced to noting any stutter:

1. The whole loop with touch, then with the PS5 controller: the keeper's briefing, through the passage, Miki taking the regulator, the return under another leader, the repair, the call and **Read plan**.
2. Pause during a conversation, then resume: the same line comes back.
3. Confirm the pause menu straight away: it resumes. Then choose Restart, on touch with **Restart**: everyone is back at the start with the barrier closed, and nothing moves until every finger and button is released.
4. Restart a few times part-way through a run, and note any hitch.
5. Note any stutter.

After playing it, the maintainer reported: **“everything worked as expected”**.

That is the maintainer's summary; Claude observed nothing on the phone. It does not cover:

- The party update's cost per frame, which is S1's timing check. The [performance sample](#phone-performance-sample) below measures display pacing only.
- The earlier lists on #18, which were not part of this session's checks: running along walls at shallow angles, controller handoff and the switch between touch and controller, system gestures, follower spacing on long runs, the squad observations for S1, the awake screen and normal locking, walking cadence and Xbox hardware.
- The plan's exits for Parties B and C, which ask whether a new or unfamiliar player understands the goal without coaching.

### Phone performance sample

Claude then recorded 120 seconds with Instruments' Game Performance Overview template through the phone's all-processes target, the method of the [Party A sample](party-a.md#phone-performance-sample). A first recording held no frames from Lauder, because the app was not in the foreground while it ran. For the second, Claude brought Lauder to the front from the Mac and started recording; the maintainer was asked to play the loop without stopping and to restart if finished early. The trace shows Lauder presenting frames throughout, not what was on screen. Exactly one Lauder Metal layer contributed.

The first 15 seconds and partial boundary buckets were excluded. The [sanitised metric CSV](party-c-phone-metrics.csv) contains 104 complete aggregation buckets from **15.168 to 119.174 seconds**, covering **104.006 seconds** and **6,236 reported frames**.

| Metric | Reported result |
|---|---:|
| Duration-weighted FPS | 59.9581 |
| Bucket FPS range | 57.9981–60.8130 |
| Frame-weighted mean display interval | 16.6785 ms |
| Maximum reported display interval | 50.0033 ms |
| Reported skipped-frame counter | 0 |

The nominal **60 fps mean target was met in this short Release sample**. Three buckets reported a longer frame: 33.3 ms, one frame shown for two refreshes, at about 70 and 79 seconds, and 50.0 ms, shown for three, at about 105 seconds. What was happening in the game at those moments, and so their cause, is not known. Thermal state stayed Nominal throughout.

These are aggregate statistics reported by the instrument, as for Party A. The per-frame tables exported no rows, so no p95/p99 or exact count of individual hitches is claimed. Frame count over covered time, 59.9581 fps, and 1,000 over the mean interval, 59.9576 fps, agree. The raw traces stay private; the CSV holds only relative times and numeric metrics. Profiling overhead, sustained thermal behaviour, memory and other devices are outside this short result.

## Limits

- Only the maintainer has played it by hand, so the plan's exit question, whether an unfamiliar player understands the goal and completes the loop without coaching, is open.
- Apart from the phone checkpoint above, every check ran in the Simulator with scripted input. The earlier [#18 lists](https://github.com/RonildoBraga/lauder/issues/18) remain open, and the phone sample is short, not a sustained or thermal test.
- The dialogue is provisional, as described above.
- The run is in memory only. Saving and Continue remain later hardening.
