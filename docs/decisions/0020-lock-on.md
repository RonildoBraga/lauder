# ADR 0020 — Lock-on

**Status:** Accepted, with starting values to tune in play; implemented in the [controls pass](../prototype-plan.md#controls-pass), [PR #156](https://github.com/RonildoBraga/lauder/pull/156). Played on the phone in TestFlight build 32, where the maintainer said the weapons and controls feel right ([playtest](../prototype-plan.md#build-32-playtest)).

**Date:** 26 November 2026

**Touch-parity follow-up, 27 November 2026:** [Issue #186](https://github.com/RonildoBraga/lauder/issues/186) records the maintainer's request to revisit touch targeting and action coverage. The subsequent instruction **“Also please address the Claude comments on git issues”** authorises the bounded follow-up (maintainer chat, no public permalink). The maintainer chose a short contextual touch hint for discovering squad orders. Tapping the selected enemy again to release, adding Status panel to touch Pause and retaining the gameplay button positions are implementation choices under that assignment. The [prototype plan](../prototype-plan.md#touch-parity--in-development) owns implementation and verification status; build 36 is the earlier delivered baseline.

## Assignment

After seeing a map of the controller's buttons, the maintainer asked for a lock-on: **“Also when we press down the right stick button, we should lock on a enemy so we no longer need to aim, pressing it again change it to the next enemy and the enemy should be circled with a red circle to indicate it is selected, pressing the right stick quick twice unselect the enemy and we can aim manualy”**. It was said in a Claude session, which has no public permalink, together with the two other changes in the controls pass.

The initial omission of touch lock-on was the implementer's reading of that controller request. The touch follow-up extends the same native lock while preserving [ADR 0007](0007-aiming-and-shot-feedback.md)'s assisted aim when no enemy is selected.

## Decision

- **Input:**
  - R3 on PS5 or RS on Xbox, a press of the right stick, or O on a keyboard. On touch, a short tap near an eligible enemy selects it; Fire also exposes Target, Next target and Let go accessibility actions.
  - A lock press needs a fresh press while exploring. Dialogue and Pause consume it rather than queueing it.
  - A held press keeps the release gate closed, like every other button.
- **What a lock can take:** a revealed, living hostile who is a target, as for Fire: the armed guard, or someone who has opened fire. They must be within 30 m of the leader. Touch selection additionally requires an on-screen projected body envelope.
- **Pressing:**
  - Without a lock, a press locks on the hostile Fire would take: the nearest ahead and in sight, or else the nearest.
  - With a lock, a press moves it to the next hostile clockwise round the leader, as the screen shows them. With nobody else to take, the lock stays.
  - A press within 0.3 s of the last lets go instead. The first of those two presses still locks or moves on, for that moment.
- **Touch selection:**
  - Down and up in less than 0.35 s, with no more than 12 pt of drift including the release position. Holding still retains the ground-order menu. An empty valid tap retains an on-screen or partly visible lock but releases one whose body envelope is entirely off-screen; moving off-screen alone, an invalid tap or invalid projection data does not release it.
  - At release, choose the nearest eligible enemy's visible projected body envelope, using its full height and navigation radius with 30 screen points of exterior allowance. The touch carries the view size, so the tolerance stays in points on different screens; entirely off-screen bodies cannot be picked. Equal distances use the stable enemy ID. This body envelope is an approximation, not a mesh, weak-point or companion pick.
  - Tap another enemy to change the lock, or the selected enemy again to let go. A tap does not fire, and the controller's double-press timing does not turn a second touch selection into a different gesture.
  - The Target accessibility action keeps a valid current lock or acquires the native first target. Next target cycles deliberately without the controller double-press timer; Let go clears the lock. These actions do not fire.
  - Touch captures feed generation-checked one-shot requests through GameControls and InputRules. Pause, dialogue, source changes and the neutral-input gate consume or cancel requests; the UI does not call targeting directly.
- **Aiming:**
  - While locked, the leader turns to face the hostile at the usual turn rate, whichever way they walk, and draws the weapon as aiming with the stick does. The right stick does not aim until the lock lets go.
  - Fire takes the locked hostile while they are in reach and in sight, once the leader faces them within the help's 8°.
  - Out of reach or behind cover, the shot flies the way the leader faces, towards the locked hostile, and can strike the cover.
  - As before, nobody who is not yet a target is ever shot first.
  - A roll, or a scene that holds the party, stops the aim for its length but keeps the lock.
- **Letting go:** a second controller/keyboard press within 0.3 s, tapping the selected enemy again, an empty valid touch tap while its body is entirely off-screen, the Let go accessibility action, the hostile being down, cleared, hidden, no longer targetable or more than 30 m away, Restart or a retry. A leader switch and a change between controller and touch keep an otherwise valid lock; source changes still cancel captures and require neutral input.
- **Presentation:**
  - A ring on the ground round the locked hostile, in the threats' red that the assisted target's disc and the refusal cross already use, so no colour joins the palette.
  - It is wider than that disc, so it circles it. Round the guard it also clears the legs.
  - The hint strip shows **Lock on**, and while locked **Next target** and **twice · Let go** in place of the stick's Aim.
  - Touch uses the same red ring and native lock; it does not need the controller hint strip. A short contextual order hint appears during a fight while the squad is in Defend.

## Consequences

- Two quick presses cannot move the lock on twice; the next press needs to wait 0.3 s.
- A lock makes aiming in the bridge's small fights easy. The guard fight was tuned without it, as it was without the roll, so its balance needs a playtest.
- Touch keeps assisted aim without a lock and gains an explicit enemy choice with the same ring. No aim stick, tap-to-fire, guard-part targeting, companion taps or gameplay-button relocation are added.
- R3 / RS and O are now taken.

## Verification

Recorded in the prototype plan under [Controls pass](../prototype-plan.md#controls-pass).

The [touch-parity follow-up](../prototype-plan.md#touch-parity--in-development) records the new tap, accessibility, authority and touch-only Simulator checks. Earlier controller-driven captures with the touch layout visible do not verify touch input. Simulator and source checks do not establish real touch, multi-touch, VoiceOver usability or phone acceptance. The [touch-control contract](../touch-controls.md) describes drawn-item selection and the remaining extreme-top cancellation limit.
