# Touch controls

**Date:** 17 November 2026

## Authorisation

The maintainer requested: “because I don’t have the joystick with me all the time, can you build an option to use the touch screen to control the character?” This supersedes the earlier controller-only/no-touch decision.

The change adds an input option to the existing Party A scene. It adds no character art, animation, dependencies, specialist actions or collision changes. The [README](../README.md) and [prototype plan](prototype-plan.md) own stage and review status.

## Behaviour

- Without an extended controller, show a fixed bottom-left analog stick and **Look**, **Next: name** and **Pause/Resume** controls.
- With a controller attached, prefer it unless the player selects **Use touch controls**. **Use controller** returns to it. The preference is in memory and is not persisted across app launches.
- Keep keyboard WASD/E/Q/Escape and the existing PS5/Xbox mappings. Touch **Look** currently requests the same observation as Cross/A/E.
- Support a stick finger alongside button fingers. Lift the stick finger to stop; all contacts must release before a neutral-input gate clears, even when the stick is centred.

## Input ownership

TouchInput supplies raw values to GameControls and the shared InputRules. Session mode, Pause priority, fresh action/switch edges and whole-party freezing use the existing path; touch does not bypass the session.

Each control tracks its finger. Source changes and inactivity cancel captures through generation tokens, preventing callbacks from an old capture from affecting the new source. Pause keeps the capture surface mounted so held contacts remain visible to the release gate. The foreground idle-timer policy is unchanged.

Button presses are latched until the next sample so quick taps are not lost between scene updates. Source/lifecycle cancellation clears pending presses; InputRules still decides whether an intent is permitted.

## Validation pending

- `./scripts/check` passed with Xcode 27.2: strict formatting, build and Swift Testing.
- Simulator launch rendered the controller-mode HUD and **Use touch controls** button. Live touch layout/movement and manual keyboard checks are pending; launch alone does not establish them.
- Desktop automation could not access the Simulator window. The maintainer deferred the live check until available and asked to complete the independent work first. This is a deferral, not a passed touch playtest.
- Physical phone multi-touch, source changes and PS5/Xbox behaviour on this build: unverified. Earlier Party A phone results apply to their recorded revision, not this change.

The existing phone-test deferrals remain in force. Single-pointer Simulator checks cannot prove simultaneous fingers or physical controller delivery.

The independently reported [wall-contact freeze in #25](https://github.com/RonildoBraga/lauder/issues/25) remains open; this input change does not change the collision resolver.
