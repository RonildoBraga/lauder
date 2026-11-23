# First tower — armed spider-bot proposal

**Updated:** 23 November 2026.

**Status:** Behaviour draft for maintainer review. Replacing the first human shooter remains selected. The first Blender blockout of the dark armed [v3 reference](../../art/robot/README.md) was rejected for its proportions. Three [bulkier concept options](../../art/robot/bulk-studies/README.md) now await selection; further modelling and runtime work are paused. The gameplay movement, combat rules and tuning below remain proposals; no playable robot encounter is assigned or reported complete.

## Goal and placement

Make one short encounter about reading a machine, choosing a position and exploiting a predictable opening. Exploration and salvage still lead the game. More enemy health or a new model alone will not make the bridge enjoyable.

The robot replaces the human shooter at the **first tower**, while **Miki is alone**. It does not appear after Laura joins. The tower's existing piers and two arches provide the space; this proposal adds no arena, new cover, elevation or control bindings. The current app still has the human encounter.

The selected art's three travellers are scale references, not this encounter's party composition.

The intended loop is **observe → provoke or avoid → bait the aim → move or use stone cover → return fire during recovery → advance**. Retreat remains possible. Test this short loop before expanding the rest of the crossing.

## Movement and awareness

- Walk more slowly than Miki: about **1.6 m/s** is a starting hypothesis. Use two or three reachable patrol positions around the tower, not a route across the whole bridge.
- Alternate diagonal leg pairs. A planted foot holds its ground while the other pair steps; turning uses short pivot steps. The body settles slightly after acceleration or stopping. Avoid sliding, hopping, skating and instant whole-body turns.
- Turn the head and gun mounts toward what it sees at a limited rate. Keep actual firing direction aligned with the visible barrels. Small secondary body motion must not misrepresent an attack or move the gameplay collision body.
- Sight needs an unobstructed front-facing view; sound and posture announce notice. A starting view cone is **100°**, with detection around **14 m** and attack initiation within **12 m**. These values must fit the visible camera and existing arches.
- On losing sight, use the last seen position within the tower's bounded guard area. Do not track Miki through a pier or chase down the entire bridge. Search briefly, then return to patrol.
- A blocked route stops or redirects the robot locally. It must not teleport, clip its full leg footprint through stone, push Miki off the route or freeze the world.

A small set of behaviour states chooses goals and attack timing. The gait and spring-like body motion express those goals; cosmetic smoothing must preserve honest collision and gun direction.

## Attack cycle

| Phase | Proposed behaviour | Starting timing |
|---|---|---:|
| Notice | Turn toward Miki, raise the guns and give a short mechanical warning. A visible hostile stance makes it a valid assisted-aim target. | 0.5 s |
| Track and brace | Stop walking, plant all four feet and track Miki with a finite turn speed. | 1.0 s |
| Commit | Stop following Miki and commit to a world-space aim point. The planted pose and a distinct click announce this moment. | 0.35 s |
| Burst | Fire **three rounds total**, alternating the two guns, toward the committed point. No late correction toward Miki. | 0.2 s between rounds |
| Recover | Guns dip and the chassis settles. Miki can reposition, shoot or withdraw. | 1.8 s |
| Reposition | Take one short reachable move if useful, then begin a fresh warned cycle. If Miki crowds it, a short backward step may create room. | At walking speed |

The two guns create a readable alternating rhythm, not two simultaneous damage streams. The initial version uses this one ranged pattern. The old pose sheet's lunge is not a second attack assignment; jumping, melee, grenades and extra weapon modes wait until this pattern proves useful.

## Fair shooting and reactions

- Show **no red aim line or projected warning cone**. Head direction, gun pose, sound and the committed pause provide the warning. Tracers, muzzle flashes and stone impacts may describe shots after they fire.
- Use actual barrel origins and tower geometry. A pier can block one gun, both guns or a shot after commitment. Do not shoot through cover or from the head centre.
- Start with tight robot spread, around **1° or less**, so a timely ordinary sidestep after commitment is a reliable counter. Do not copy the existing rifle's spread blindly. The visual streak does not create a slow projectile that can be dodged after a hitscan shot has already resolved.
- Losing sight before commitment cancels that attempt; reacquisition needs a fresh warning. A committed burst may finish into the pier, spending its attack and entering recovery. Start no fresh attack while the robot is offscreen.
- Range limits attack initiation, not the length of an already fired ray. Retain real cover impacts and the existing level-wide ballistics rules.
- A robot hit gives a small shell reaction and impact sound. It does **not** reset every wind-up or create an indefinite stun lock. Try cosmetic hit reaction first; add an interrupt only if playtests demonstrate a need.
- Try **six carbine hits** to disable the robot, with Miki's existing **12 starting rounds**. This is a tuning hypothesis, not accepted balance or a reason to make an armoured damage sponge. No separate leg health, gun destruction or hidden weak point is needed.
- Accept at most **one player hit per burst**. This is a proposed robot-specific rule: the three rounds must not consume Miki's existing three-hit retry allowance in one mistake. Do not describe this protection as current behaviour.
- On defeat, cancel both guns and all queued attacks immediately. Let the body settle and the sensor go dark, without an explosion or an extra obstructing wreck.

## Retreat, bypass and the story handoff

Retreat is always available: break sight behind a pier or leave the guard area. The robot checks the last seen position for roughly **three seconds**, then returns to patrol. Preserve its received damage and Miki's spent ammunition during retreat; only an actual encounter retry restores its checkpoint. No health or ammunition farming through a leash reset.

**Recommended additional choice:** let Miki pass through the other arch while the robot watches elsewhere. This needs a verified reachable, covered exit outside its guard/fire area; it must not be promised solely from the concept image. If the existing geometry cannot support that route, review its placement and ranges before adding scenery or a new ability.

Defeat or a safe bypass resolves this first encounter once. Before the follow-on search starts, clear every pending robot shot and close the encounter. On a bypass it returns to its guard post; the initial slice does not reactivate this encounter until Restart. A later revisit fight is outside this first experiment. The handoff must be visible and consistent, not a hidden invulnerability boundary while the robot still appears to aim at Miki.

Replace the old dead-stranger search with **one small nonblocking supply case** on the outgoing, safe side of the tower. Its exact position and the bypass handoff need approval and a geometry check. The case supplies the existing **six rounds and one medical kit**, once, whether Miki fought or bypassed the guard. It is an interaction prop, not new cover or a salvage minigame.

The current search is gated on the stranger's defeat and the ambush grants the stranger's loot. Those dependencies must become the resolved robot encounter and the case, rather than disguising a robot as the dead human. The human-specific “Friendly!” and “He opened fire” cues also need replacement. Brief mechanical notice and a short Miki reaction are sufficient; no explanation of the collapse is required.

Searching the case then triggers the existing knife-attacker scene, Tom's intervention and introduction. Laura is still helped with that same medical kit later. Miki is alone during the robot fight, so this experiment does not assign autonomous companion combat or change how recruited members take damage. Bypass and the case ensure missing shots or spending all ammunition cannot lock the player out of progress.

## Example play

Miki reaches the first arch. The robot pivots, warns and plants its feet. She steps behind a pier as its guns stop tracking. The burst strikes stone. While it recovers, she returns fire and shifts position before it braces again. Repeating that decision disables it; the safe-side case leads into Tom's scene.

Alternatively, she observes the patrol, uses the other arch during its turn, breaks contact and reaches the verified safe exit. The robot returns to guard, the encounter closes and the same case remains available. If a fight goes badly, she can retreat and reassess instead of being chased along the entire crossing.

## Prototype questions and acceptance

These are checks for a later assigned implementation, not results from this planning task:

- After two cycles, can the player recognise tracking, commitment and recovery from motion and sound?
- In five deliberate sidestep/cover trials, do at least four avoid the committed burst without needing a new dodge control? Check this on controller and touch at an agreed checkpoint.
- Do actual left/right barrel rays hit the pier correctly, with no damage through stone or instant reacquisition around an arch?
- Does a burst cost at most one hit, leaving room to learn across three mistakes? Does defeat clear all scheduled fire immediately?
- Is positioning useful compared with standing still and holding Fire? Six hits and these timings might permit a simple damage race; test and revise the numbers rather than assuming the pattern is already balanced.
- Can Miki retreat, return, win or bypass without resetting ammunition, farming the case, or leaving a live attack in Tom's scene? Verify the zero-ammunition route too.
- Do Pause, interruptions, neutral-input recovery and retry freeze/reset the robot without replaying shots or leaving sliding feet?
- Can the encounter be repeated from its checkpoint without walking the whole 644 m bridge after every failure? Does the short loop feel worth replaying before expanding it?

## Before implementation

Choose a bulkier concept before another modelling pass. Before assigning the playable tower encounter, review the attack cycle, damage cap, six-hit candidate and supply-case/bypass handoff. The earlier modelling assignment and selected first-encounter placement do not approve all these rules. The rejected model's technical checks do not establish visual approval or authorise continued implementation.
