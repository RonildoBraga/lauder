# Touch controls

The game can be played with the touch screen alone, for when no controller is at hand.

## Behaviour

- Without an extended controller, the screen shows a fixed bottom-left analog stick and **Look**, **Next: name** and **Pause/Resume** controls.
- With a controller attached, the controller is preferred unless the player selects **Use touch controls**; **Use controller** returns to it. The choice is kept in memory, not across launches.
- Keyboard WASD/E/Q/R/F/Escape and the PS5/Xbox mappings stay available. Touch **Look** requests the same intent as Cross/A/E: it shows the leader's action where there is one, such as **Search**, **Continue** in a conversation and **Restart** while paused.
- A **Fire** button beside the action button shows during a fight or once the carbine is drawn. It requests the same intent as R2/RT/F and follows the same rules: a fresh press draws, a hold keeps firing, and its finger must lift before the release gate clears.
- A **Formation** button above **Next** shows once there are two companions. It requests the same intent as Triangle/Y/R and cycles **Close**, **Spread** and **Column**; the HUD names the formation after the party's names. A finger already on it keeps it shown until it lifts, so the release gate still sees it let go.
- Four buttons sit around the right thumb, within the [proposed five](gameplay-script.md#future-squad-and-combat-design), with **Pause/Resume** at the top.
- A stick finger works alongside button fingers. Lifting the stick finger stops; every contact must release before the neutral-input gate clears, even when the stick is centred.

## Input ownership

TouchInput supplies raw values to GameControls and the shared InputRules. Session mode, Pause priority, fresh action and switch edges and freezing the whole party use the same path as every other input; touch never bypasses the session.

Each control tracks its own finger. Source changes and inactivity cancel captures through generation tokens, so callbacks from an old capture cannot affect the new source. Pause keeps the capture surface mounted, so held contacts stay visible to the release gate. The screen stays awake while the game is in the foreground, Pause included.

Button presses are latched until the next sample, so quick taps are not lost between scene updates. Cancelling a source or a lifecycle change clears pending presses; InputRules still decides whether an intent is allowed.

## Checking

Touch play has been checked on the baseline iPhone 13 Pro Max: two-finger stick use alongside the buttons, one switch per press, stopping on release, Pause with held fingers, Resume after every finger lifts, and recovery after the app goes to the background. Handing over between a physical controller and touch, and Xbox controllers, have not been tested on hardware. The Simulator, with a pointer, checks the interface but not physical controllers or multi-touch.
