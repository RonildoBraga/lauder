# ADR 0020 — Lock-on

**Status:** Accepted, with starting values to tune in play; implemented in the [controls pass](../prototype-plan.md#controls-pass). Physical-phone behaviour is unverified.

**Date:** 26 November 2026

## Assignment

After seeing a map of the controller's buttons, the maintainer asked for a lock-on: **“Also when we press down the right stick button, we should lock on a enemy so we no longer need to aim, pressing it again change it to the next enemy and the enemy should be circled with a red circle to indicate it is selected, pressing the right stick quick twice unselect the enemy and we can aim manualy”**. It was said in a Claude session, which has no public permalink, together with the two other changes in the controls pass.

## Decision

- **Input:**
  - R3 on PS5 or RS on Xbox, a press of the right stick, or O on a keyboard. Touch has none: Fire's assisted aim already picks the target there.
  - A lock press needs a fresh press while exploring. Dialogue and Pause consume it rather than queueing it.
  - A held press keeps the release gate closed, like every other button.
- **What a lock can take:** a hostile standing in view who is a target, as for Fire: the armed guard, or someone who has opened fire. They must be within 30 m of the leader.
- **Pressing:**
  - Without a lock, a press locks on the hostile Fire would take: the nearest ahead and in sight, or else the nearest.
  - With a lock, a press moves it to the next hostile clockwise round the leader, as the screen shows them. With nobody else to take, the lock stays.
  - A press within 0.3 s of the last lets go instead. The first of those two presses still locks or moves on, for that moment.
- **Aiming:**
  - While locked, the leader turns to face the hostile at the usual turn rate, whichever way they walk, and draws the weapon as aiming with the stick does. The right stick does not aim until the lock lets go.
  - Fire takes the locked hostile while they are in reach and in sight, once the leader faces them within the help's 8°.
  - Out of reach or behind cover, the shot flies the way the leader faces, towards the locked hostile, and can strike the cover.
  - As before, nobody who is not yet a target is ever shot first.
  - A roll, or a scene that holds the party, stops the aim for its length but keeps the lock.
- **Letting go:** a second press within 0.3 s; the hostile being down, cleared, out of view or more than 30 m away; Restart or a retry; and the touch controls taking over from a controller. A leader switch keeps the lock.
- **Presentation:**
  - A ring on the ground round the locked hostile, in the threats' red that the assisted target's disc and the refusal cross already use, so no colour joins the palette.
  - It is wider than that disc, so it circles it. Round the guard it also clears the legs.
  - The hint strip shows **Lock on**, and while locked **Next target** and **twice · Let go** in place of the stick's Aim.

## Consequences

- Two quick presses cannot move the lock on twice; the next press needs to wait 0.3 s.
- A lock makes aiming in the bridge's small fights easy. The guard fight was tuned without it, as it was without the roll, so its balance needs a playtest.
- Touch keeps assisted aim and has no ring.
- R3 / RS and O are now taken.

## Verification

Recorded in the prototype plan under [Controls pass](../prototype-plan.md#controls-pass).
