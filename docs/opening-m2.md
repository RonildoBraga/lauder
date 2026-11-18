# Opening M2 — the first fight

**Date:** 18 November 2026

## Assignment and scope

After M1 merged, the maintainer assigned the second milestone of [ADR 0004](decisions/0004-brooklyn-bridge-opening.md): **“Yes, start M2”**. M2 adds **Fire**, assisted aim, line of sight, hits, the stranger and the retry, as the ADR's fourth and sixth decisions describe. Searching, loot, the ambush and Tom follow in M3.

Claude implemented and checked M2, so nothing below is an independent review. The [README](../README.md) and [prototype plan](prototype-plan.md#opening--the-brooklyn-bridge) own stage and review status.

## What changed

- **Fire.** R2 or RT on a controller, **F** in the Simulator, and a touch **Fire** button that appears when the fight begins. It passes through `InputRules` like every other intent: a fresh press, a hold, consumed while paused or in a conversation, and part of the release gate. The first press draws Miki's carbine, which takes 0.35 s; until then it is holstered, so a quiet walk never starts a fight. Held, it fires every 0.4 s. The touch layout now has four buttons: the action, **Next**, **Pause/Resume** and **Fire**.
- **Assisted aim.** Fire shoots at the nearest hostile within 14 m and in sight, preferring one within 75° of where Miki faces. A red disc on the deck marks the target. There is no manual aiming. A hostile becomes a target only once it has opened fire: until then nobody knows it is hostile, so Miki cannot shoot the man she has just called out to. That is an implementation choice for playtesting, not part of the ADR.
- **Line of sight and cover.** A shot is a straight line against the same blocker footprints that movement uses, so cars give cover to both sides.
- **The stranger.** He waits unseen behind the car turned across the east roadway, before the first tower. When Miki comes within about 10 m, he steps out into the lane, she calls “Friendly!” and a second later he starts to aim. Before each shot a red line runs from him to her for 1.5 s and the HUD reads “The stranger is aiming.”; after it he pauses for 1.4 s. His first shot misses on purpose, passing just beside her, and the HUD then says “He opened fire. Fire back, or take cover.” A shot blocked by cover ends at the cover, and one at a target beyond his 14 m reach falls short. He stands his ground; he does not move to cover or advance.
- **Keeping the fight on screen.** The bridge camera shows only about 10 m ahead of Miki at head height. The first rendered runs showed the stranger above the top of the screen, with only his aim line visible, because the fight began about 15 m from him. Now the fight begins nearer, and while a hostile stands in the open the camera's target leans up to 3 m towards him, so both are on screen. It eases back when he is down. Both weapons reach 14 m, about what the camera shows ahead during the fight, so nobody is shot from off screen.
- **Hits and rounds.** The [placeholder hit rule](encounters/the-quiet-yard.md#placeholder-hit-rule): Miki can take three hits, shown as pips beside her name during the fight, and the stranger two. The carbine starts with 12 rounds, shown as “Carbine · 12”. When the stranger is down, he lies on the deck, the HUD reads “The stranger is down.”, the fight ends and Miki's hits recover. An empty carbine says “Out of ammunition.” once. Searching bodies for more comes with M3.
- **The retry.** On the third hit the screen fades out over 0.6 s. The fight is then put back as it began: the stranger unseen, Miki's rounds and hits as they were, and Miki just short of the cars, facing Manhattan, with “Try again.” The screen fades back in over 0.4 s, and play waits for every control to be released, as after Resume. Lines already shown along the way stay shown. Pause holds both the fight and the fade.
- **Ownership.** The session owns the story's beat, now *alone* then *stranger*, and starts a beat only in order, once and while exploring. It also owns the hits taken, the rounds, who is down and the checkpoint a retry returns to. `EncounterStage`, which the world owns, holds the hostiles' bodies and moment-to-moment state: where they stand, their aim and shots, the target and whether the carbine is drawn. `StoryDirector` plays an encounter's timed cues (stepping out, a line, starting to fight) in the fixed simulation step. `Weapon`, `LineOfSight`, `Targeting` and `HostileState` are plain Swift in a new `combat` folder. Each encounter is a value in its level: its beat, area, retry point, hostiles and cues.
- **The world.** `GameWorld` grows from 691 to 820 lines for the fight's step, the retry's fade and reset, the camera's lean and the fight's HUD state. The fight itself is in `EncounterStage`. Every combat entity is made at load: the stranger's stand-in, the carbine in Miki's hands, the aim line, the shot tracers and the target disc.
- **Restart.** Restart also puts the stranger back unseen, returns the beat to Miki alone, restores her rounds and hits, holsters the carbine, straightens the camera and cancels a retry in progress. It still adds no entities.
- **The crossing.** The `bridge-walk` scenario now wins the fight on the way to Manhattan. The test that each trigger's line shows once leaves the fight out of its copy of the level; the new fight tests play it.

## Checks

- `./scripts/check` passes: formatting, build and Swift Testing on the iPhone 17 / iOS 27 Simulator, with 115 tests in 18 suites. The `first-fight` and `fight-retry` scenarios, and `bridge-walk` with its fight, also run headless in the check.
- New tests cover:
  - Sight lines against boxes, and the bridge's cover for both sides.
  - Assisted aim's choice of target.
  - The stranger's timing: the deliberate miss, hits and blocked shots.
  - The cue timeline.
  - The session's beat order, hits, rounds, retry checkpoint and Restart.
  - Fire as a press and a hold, consumed while paused or talking and kept by the release gate.
  - On the bridge: the stranger waiting unseen; Fire before he has fired; the miss and the two shots; cover; range; the camera's lean; Pause holding the fight and the fade; the retry after the third hit; and Restart three times, once during a retry, without adding entities.
- Every Relay House test and headless playtest passes unchanged. The M1 test that each trigger shows its line once now leaves the fight out of its copy of the level.
- Rendered Simulator runs of the final code, in a Debug build:

  | Scenario | Steps | Time | Longest frame |
  |---|---|---|---|
  | `first-fight` | 23 of 23 | 34.4 s | 18.6 ms |
  | `fight-retry` | 19 of 19 | 47.1 s | 32.9 ms |
  | `bridge-walk` | 37 of 37 | 105.1 s | 32.6 ms |

  Frames averaged 16.7 ms in each run. The party update averaged about 0.2 ms, with a maximum of 0.8 ms. The earlier runs, before the framing change, had single long frames outside the fight: 383 ms in one, 134 ms in a rerun of `bridge-walk`. None recurred in the final runs. These are Simulator figures, not phone performance.
- In the first round's screenshots the stranger was above the top of the screen. In the final ones he stands beside the turned car, with Miki and the car she can hide behind in view, along with his aim line, the target disc and, after the fight, his body on the deck.
- A short hand-driven run used the Simulator's touch controls, with a pointer rather than physical multi-touch:
  - **Fire** appeared beside **Look** when the fight began.
  - The HUD showed the pips, the rounds, the aiming warning and “He opened fire. Fire back, or take cover.”
  - The first **Fire** press came too late: he landed three hits, and the retry put Miki back with the fight reset.
  - On the second try, holding **Fire** put him down with two rounds, and the camera settled back.

## Limits

- **The exit check needs a person.** M2's exit is that “a new player answers the stranger without help, with touch and with a controller; cover works for both sides”. Tests and scripted runs show that cover works for both sides. They cannot show that a new player reads the fight. That needs a playtest on the baseline iPhone with touch and with a controller. The ADR's stop rule applies: if the fight is not readable on the phone after three focused work sessions on M2, stop and reassess with the maintainer.
- The timings and distances (the 1.5 s wind-up, the 1.4 s pause, the 14 m reach, the 3 m camera lean, the 0.35 s draw, 0.4 s between shots and 12 rounds) are starting values for playtests.
- The stranger stands still once he has stepped out, and bodies do not block movement: Miki can walk through his stand-in.
- Nothing holsters the carbine after the fight; it stays drawn and the HUD keeps showing it.
- If Miki walks on without fighting, the fight stays open. He keeps firing while she is within reach and in sight, and the pips stay on the HUD. M3's ambush starts from his body, so the story cannot move on without the fight. On the west roadway the walkway's base covers both of them, so the fight cannot be fought from there.
- There is no sound, muzzle flash, hit reaction or animation. A hit shows as a pip and a red tracer that reaches Miki.
- The checks ran in the Simulator. Physical touch and controller play, and the phone's frame pacing with the fight, are unmeasured. The opening's planned phone checkpoint comes with M4.
- TestFlight build 0.1.0 (1) predates M1 and M2.
