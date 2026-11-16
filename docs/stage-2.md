# Stage 2 — movement and controls

**Status:** The route has passed PS5 playtests on the baseline iPhone after merged [Stage 1 PR #8](https://github.com/RonildoBraga/lauder/pull/8). PS5 and Xbox share an extended-gamepad input path; keyboard gameplay has been verified in Simulator. PR review remains open.

The maintainer authorised Stage 2 including [#5](https://github.com/RonildoBraga/lauder/issues/5) and [#10](https://github.com/RonildoBraga/lauder/issues/10), then added Xbox alongside PS5 and adopted Simulator for everyday testing, with the baseline iPhone at key milestones. After confirming that their PS5 did not control the visible Simulator game, they authorised WASD keyboard controls. No touch/clickable actions and an awake foreground screen remain agreed. Claude communication stays on GitHub.

## Input decision

Use one `GCExtendedGamepad` path for PS5 DualSense and Xbox: left stick moves, Cross/A performs the current action and Options/Menu pauses/resumes. Generic extended profiles are accepted too, since Simulator can omit vendor-specific subclasses. The right stick is unused; the camera remains fixed. For Simulator play, the same input owner polls `GCKeyboard`: WASD moves, E acts and Escape pauses/resumes. Held movement keys take priority over the stick, and the HUD reflects the input in use. No touch controls or clickable screen actions are added.

If a controller disconnects, retain or select another connected extended gamepad, or use the keyboard. Without an available input device, freeze the live world and show a connection message. Selection and keyboard connection changes require centred/released input before play continues. The app does not pair devices or change system controller settings.

The logical action uses `buttonA` and its `sfSymbolsName` for the selected controller's action glyph. `buttonMenu` supplies Options/Menu input, including while paused. Vendor-specific profiles show PS5/Options or Xbox/Menu labels; a generic profile shows Game controller/Menu. SwiftUI presents the objective, action label, connection status and pause message. Sources: [controller glyphs](https://developer.apple.com/documentation/gamecontroller/gccontrollerelement/sfsymbolsname), [menu button](https://developer.apple.com/documentation/gamecontroller/gcextendedgamepad/buttonmenu).

The input owner samples the extended profile and coalesced keyboard in the world's update path. Typed connection notifications refresh input availability. On inactivity, teardown, reconnection and Pause/Resume, input is cleared or gated until the left stick centres and all gameplay buttons/keys are released. Opposite held keys cannot clear the gate merely by cancelling the movement vector. While paused, Options/Menu/Escape remains available but movement and action are neutral. The keyboard HUD shows WASD, an E glyph and Escape, following [Apple's keyboard polling approach](https://developer.apple.com/videos/play/wwdc2020/10617/).

For #5, the native virtual-controller option was evaluated first against SDK 27.2 and Apple documentation. The maintainer then chose PS5-only operation, removing virtual controls and generic-gamepad support. Their later Xbox approval restores a shared extended-gamepad path, while virtual controls remain excluded. No custom thumbstick is implemented or planned in the current prototype.

The generated app plist merges typed Game Controllers support declarations from `App/Info.plist`: a Boolean `GCSupportsControllerUserInteraction` and an `ExtendedGamepad` entry in the `GCSupportedGameControllers` dictionary array, following [Apple's configuration workflow](https://developer.apple.com/documentation/xcode/configuring-game-controllers). No direct Bluetooth scanning or extra Bluetooth permission is used.

## World and lifecycle

- One typed Swift layout places the shelter, stationary Tomas, street obstacles, depot and blocked front entrance. The west service opening is 1.8 metres wide; low walls preserve the elevated camera's view. The existing interaction IDs name Tomas, the transmitter and regulator.
- `GameWorld` owns the RealityKit scene, character controller, animation playback and cancellable physics-update subscription. Movement uses screen-relative camera axes, an analog dead zone, limited diagonal magnitude and elapsed simulation time. The camera follows the actual character position with a fixed perspective.
- Movement uses `PhysicsSimulationEvents.WillSimulate`, as [Apple recommends for character-controller motion](https://developer.apple.com/documentation/realitykit/charactercontrollercomponent). The subscription is cancelled on teardown; loading has cancellation and stale-result protection. Frame time is reset after interruption rather than catching up with a large move.
- Pause or absence of an available input device freezes character progression and animation; foreground restoration clears held input. The app sets [the idle-timer flag](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled) while active, including Pause, and resets it when inactive or leaving the view. It does not alter the phone's Auto-Lock setting.
- The action currently gives a short observation. Mission phases, pickup, repair, dialogue progression, restart and saving remain later work.

### Camera framing

The maintainer requested a slightly wider, more top-down action-RPG view. The camera offset is now `[5.25, 10, 8.4]` from the same follow target, replacing `[5, 7.5, 8]`: about 17% farther away and 45.3° above the ground instead of 38.5°. The 42° perspective field of view and horizontal direction are unchanged, so the screen-relative stick axes stay the same. The standard physical-iPhone check passed all five tests for this change, and the maintainer accepted the framing while moving, with Miki and the route clear.

The reusable [character loader](../Lauder/World/CharacterAsset.swift) is separate from the removed diagnostic preview. Rejection tests reuse real imported mesh/animation data to verify incompatible bindings and a skinned model without its authored clip; no extra binary fixtures are needed. The [folder-group decision and membership checks](stage-2-project-groups.md) record the project changes for #10.

## Validation record

- Xcode 27.2 / SDK 27.2 parsed and built the folder-synchronised project. Scratch probes confirmed new app/test Swift files are included automatically, editable sources are excluded recursively, and exactly the two USDZ payloads are bundled.
- The initial integrated simulator formatting, build and five Swift Testing checks passed: real asset import, two rejection paths and two movement-input checks.
- After the PlayStation and awake-screen changes, the standard `./scripts/check` passed on the **physical iPhone 13 Pro Max / iOS 27.2.1** with Xcode 27.2 / SDK 27.2. Formatting, signed build and all five checks passed; the script removed its successful temporary output.
- The updated app was installed and launched on that phone. A live device capture shows the scene and character, the PlayStation input source, its Cross glyph and no virtual-control overlay. This establishes recognition and rendering; movement, camera behaviour, interruption, switching and awake-screen timing remain separate playtest checks below.
- The maintainer then confirmed left-stick movement, Cross while moving, Options/Menu Pause/Resume, stopping after release/centring, camera follow and wall collision on the phone. They also confirmed the game stays awake during the requested idle/Pause check; no numeric timing interval was recorded.
- The maintainer also confirmed background/manual-lock recovery without stuck movement on that build. These observations precede the removal of the touch paths and on-screen buttons; the subsequent PS5-only phone checks are recorded below. Normal Auto-Lock timing after leaving the app has not been measured.
- After simplification to PS5-only input, the standard physical-iPhone check passed all five tests again. The installed revision's live capture shows the PS5 input source, Cross action prompt and read-only Options instruction. Source inspection confirms no SwiftUI buttons, touch gestures or virtual-controller path remain.
- The maintainer confirmed movement, Cross and Options Pause/Resume on the PS5-only revision, with no clickable screen actions. They also confirmed disconnecting stops the game with the connection message and reconnecting returns control after centring/releasing, without stuck movement.
- After the shared PS5/Xbox input change, `./scripts/check` passed strict formatting, build and all five Swift Testing checks on the **iPhone 17 / iOS 27.0 Simulator**, with Xcode 27.2 / SDK 27.2. No new assets, dependencies or targets were added.
- The maintainer switched to a PS5 controller connected to the Mac and explicitly deferred Xbox hardware testing. macOS HID reports a Bluetooth DualSense; the native GameController framework identifies its `GCDualSenseGamepad` profile. Simulator reports a generic MFi/`GCExtendedGamepad`, which the updated input owner accepts as ready. The app was opened in Device Hub in landscape; this verifies loading and profile acceptance, not physical input delivery.
- Two temporary 45-second Simulator input recordings captured no raw or mapped axis/button changes; a parallel native Mac recording also captured none. The maintainer separately confirmed that the visible game did not respond to the PS5. The live probes' no-input assertions failed separately from the passing standard suite. Controller forwarding is not working in this tested Simulator setup; no underlying framework cause has been isolated. Xbox hardware testing is deferred at the maintainer's request.
- After adding keyboard input, the standard Simulator check passed all five tests again. In the visible landscape game, Codex exercised W/A/S/D movement, observed stopping after release, used E beside the transmitter and Tomas to display their different observations, and used Escape to pause/resume. Holding D while paused did not move the character. Immediately held input after resume stayed gated until release and a fresh press. Device Hub's **Capture Keyboard** was enabled for this test and switched off afterward. Keyboard focus changes, the latest phone milestone checks and physical Xbox gameplay remain unverified.

## Everyday Simulator and milestone phone checks

Run formatting, build and Swift Testing with `./scripts/check` on Simulator during everyday development. In Device Hub, enable **Capture Keyboard** and use WASD, E and a short Escape press; holding Escape releases keyboard capture. Check movement release and Pause/Resume while playing the route. Controller enumeration alone does not prove physical stick/button delivery; use keyboard play for this setup until forwarding is verified.

At playable-feature milestones before merging, repeat the checks below on the baseline iPhone. Check actual device performance and Bluetooth/lifecycle behaviour on the phone; Simulator timing does not establish them. The earlier phone results above apply to the recorded PS5 revisions, not automatically to later input changes.

1. With each supported controller, confirm the source and action glyph; walk the route, enter the service opening and return. Check collision, framing and visible feet/ground contact.
2. Hold movement while pressing Cross/A. Release the stick; motion must stop. Pause/Resume with Options/Menu; held input must not resume motion. Verify there are no clickable screen actions.
3. Disconnect the selected controller with no other controller connected: the world must stop and show a connection message. Reconnect, centre/release input, and confirm control returns without stale movement.
4. Background, lock/unlock and return while input was held. Centre/release controls before resuming. Repeat without duplicate controls or frame callbacks.
5. Leave the active game untouched beyond the phone's normal Auto-Lock interval, including on Pause. Check that it remains awake, then verify normal locking after leaving the app.

These checks and measured first-playable performance must not be inferred from a passing import test. No Stage 3 implementation or Stage 2 merge is implied by this record.
