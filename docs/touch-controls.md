# Touch controls

**Date:** 17 November 2026

## Authorisation

The maintainer requested: “because I don’t have the joystick with me all the time, can you build an option to use the touch screen to control the character?” This supersedes the earlier controller-only/no-touch decision.

The change adds an input option to the existing Party A scene. It adds no character art, animation, dependencies, specialist actions or collision changes. The [README](../README.md) and [prototype plan](prototype-plan.md) own stage and review status.

## Behaviour

- Without an extended controller, show a fixed bottom-left analog stick and **Look**, **Next: name** and **Pause/Resume** controls.
- With a controller attached, prefer it unless the player selects **Use touch controls**. **Use controller** returns to it. The preference is in memory and is not persisted across app launches.
- Keep keyboard WASD/E/Q/Escape and the existing PS5/Xbox mappings. Touch **Look** requests the same intent as Cross/A/E. Later stages relabel it: the leader's action where there is one ([Party B](party-b.md)), **Continue** in a conversation and **Restart** while paused ([Party C](party-c.md)).
- Support a stick finger alongside button fingers. Lift the stick finger to stop; all contacts must release before a neutral-input gate clears, even when the stick is centred.
- [Opening M2](opening-m2.md) adds a **Fire** button beside the action button, shown during a fight or once the carbine is drawn. It requests the same intent as R2/RT/F and follows the same rules: a fresh press draws, a hold keeps firing, and its finger must lift before the gate clears. With it the layout has four buttons, within the [proposed five](gameplay-script.md#future-squad-and-combat-design).

## Input ownership

TouchInput supplies raw values to GameControls and the shared InputRules. Session mode, Pause priority, fresh action/switch edges and whole-party freezing use the existing path; touch does not bypass the session.

Each control tracks its finger. Source changes and inactivity cancel captures through generation tokens, preventing callbacks from an old capture from affecting the new source. Pause keeps the capture surface mounted so held contacts remain visible to the release gate. The foreground idle-timer policy is unchanged.

Button presses are latched until the next sample so quick taps are not lost between scene updates. Source/lifecycle cancellation clears pending presses; InputRules still decides whether an intent is permitted.

## Validation

The earlier live-check deferral was lifted when the maintainer returned on 17 November 2026. Checks below apply to runtime **`b592e22`**, not the earlier Party A phone build.

- `./scripts/check` passed again with Xcode 27.2 on the iPhone 17 / iOS 27.0 Simulator: strict formatting, build and Swift Testing.
- Pointer-based Simulator play confirmed **Use touch controls**, a readable touch layout, stick movement and stopping on release, Look displaying the transmitter observation, and a held Next press selecting Lara only once. Pause froze play; movement, Look and Next were ignored while paused. Switching back to the controller interface and then touch while paused left the selected member unchanged; Resume accepted fresh movement. This verifies interface handoff, not physical gamepad delivery.
- The keyboard smoke check confirmed movement, E observation, Q switching, Escape Pause/Resume and ignored paused movement. Keyboard capture was restored off afterward.
- A signed **Release** build, version **0.1.0 (1)**, built with Xcode 27.2 / SDK 27.2, passed signature verification and was installed and launched on **iPhone 13 Pro Max / iOS 27.2.1**. Build/install receipts remain private.
- The maintainer confirmed two-finger stick use alongside Look/Next, continued movement while using buttons, one switch per press, stopping on stick release, and clear controls/HUD. They also confirmed held/centred-finger Pause guidance, Resume after lifting all fingers, and background/foreground recovery without stale movement, replayed actions or stuck highlights. These are user-reported physical observations.

Physical controller handoff and PS5/Xbox delivery on this revision were not tested. Cross-zone finger dragging was not separately observed on the phone. No new frame-pacing, thermal, battery or idle-timer timing measurement is claimed; earlier phone-test deferrals remain separate. The short input check does not replace those measurements or prove sustained play.

The recurring Simulator PosterBoard startup failure was isolated separately. The [fresh testing device](simulator-troubleshooting.md) passed three boots, the standard check and a post-launch observation without that failure.

The independently reported [wall-contact freeze in #25](https://github.com/RonildoBraga/lauder/issues/25) remains open; this input change does not change the collision resolver.
