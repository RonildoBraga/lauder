# Stage 2 — movement and controls

**Status:** The PS5-only route is built, tested and running on the baseline iPhone after merged [Stage 1 PR #8](https://github.com/RonildoBraga/lauder/pull/8). PR review remains open.

The maintainer authorised Stage 2 including [#5](https://github.com/RonildoBraga/lauder/issues/5) and [#10](https://github.com/RonildoBraga/lauder/issues/10), then specified PS5-controller-only input, the iPhone as the primary test device, and an awake screen while the foreground game is open. Claude communication stays on GitHub.

## Input decision

Use the paired PS5 DualSense exclusively: left stick moves, Cross performs the current action and Options pauses/resumes. The interface is informational, with no clickable screen actions. If the controller disconnects, freeze the live world and show a connection message. Reconnection requires centred/released input before play continues. The app does not pair Bluetooth devices or change system controller settings.

The logical action uses `buttonA` and its `sfSymbolsName` to show the actual Cross glyph. `buttonMenu` supplies Options input, including while paused. SwiftUI presents the objective, action label, connection status and pause message. Sources: [controller glyphs](https://developer.apple.com/documentation/gamecontroller/gccontrollerelement/sfsymbolsname), [menu button](https://developer.apple.com/documentation/gamecontroller/gcextendedgamepad/buttonmenu).

The controller owner samples the selected DualSense profile in the world's update path. Connection notifications retain or replace that controller. On inactivity, teardown, reconnection and Pause/Resume, input is cleared or gated until the stick centres and action/menu buttons are released. While paused, Options remains available but movement and action are neutral.

For #5, the native virtual-controller option was evaluated first against SDK 27.2 and Apple documentation. The maintainer then chose PS5-only operation; virtual-controller and generic-gamepad paths were removed. No custom thumbstick is implemented or planned in the current prototype.

The generated app plist merges typed Game Controllers support declarations from `App/Info.plist`: a Boolean `GCSupportsControllerUserInteraction` and an `ExtendedGamepad` entry in the `GCSupportedGameControllers` dictionary array, following [Apple's configuration workflow](https://developer.apple.com/documentation/xcode/configuring-game-controllers). No direct Bluetooth scanning or extra Bluetooth permission is used.

## World and lifecycle

- One typed Swift layout places the shelter, stationary Tomas, street obstacles, depot and blocked front entrance. The west service opening is 1.8 metres wide; low walls preserve the elevated camera's view. The existing interaction IDs name Tomas, the transmitter and regulator.
- `GameWorld` owns the RealityKit scene, character controller, animation playback and cancellable physics-update subscription. Movement uses screen-relative camera axes, an analog dead zone, limited diagonal magnitude and elapsed simulation time. The camera follows the actual character position with a fixed perspective.
- Movement uses `PhysicsSimulationEvents.WillSimulate`, as [Apple recommends for character-controller motion](https://developer.apple.com/documentation/realitykit/charactercontrollercomponent). The subscription is cancelled on teardown; loading has cancellation and stale-result protection. Frame time is reset after interruption rather than catching up with a large move.
- Pause or loss of the PS5 controller freezes character progression and animation; foreground restoration clears held input. The app sets [the idle-timer flag](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled) while active, including Pause, and resets it when inactive or leaving the view. It does not alter the phone's Auto-Lock setting.
- The action currently gives a short observation. Mission phases, pickup, repair, dialogue progression, restart and saving remain later work.

The reusable [character loader](../Lauder/World/CharacterAsset.swift) is separate from the removed diagnostic preview. Rejection tests reuse real imported mesh/animation data to verify incompatible bindings and a skinned model without its authored clip; no extra binary fixtures are needed. The [folder-group decision and membership checks](stage-2-project-groups.md) record the project changes for #10.

## Validation record

- Xcode 27.2 / SDK 27.2 parsed and built the folder-synchronised project. Scratch probes confirmed new app/test Swift files are included automatically, editable sources are excluded recursively, and exactly the two USDZ payloads are bundled.
- The initial integrated simulator formatting, build and five Swift Testing checks passed: real asset import, two rejection paths and two movement-input checks.
- After the PlayStation and awake-screen changes, the standard `./scripts/check` passed on the **physical iPhone 13 Pro Max / iOS 27.2.1** with Xcode 27.2 / SDK 27.2. Formatting, signed build and all five checks passed; the script removed its successful temporary output.
- The updated app was installed and launched on that phone. A live device capture shows the scene and character, the PlayStation input source, its Cross glyph and no virtual-control overlay. This establishes recognition and rendering; movement, camera behaviour, interruption, switching and awake-screen timing remain separate playtest checks below.
- The maintainer then confirmed left-stick movement, Cross while moving, Options/Menu Pause/Resume, stopping after release/centring, camera follow and wall collision on the phone. They also confirmed the game stays awake during the requested idle/Pause check; no numeric timing interval was recorded.
- The maintainer also confirmed background/manual-lock recovery without stuck movement on that build. These observations precede the removal of the touch paths and on-screen buttons; the PS5-only revision needs its own final device check. Normal Auto-Lock timing after leaving the app has not been measured.
- After simplification to PS5-only input, the standard physical-iPhone check passed all five tests again. The installed revision's live capture shows the PS5 input source, Cross action prompt and read-only Options instruction. Source inspection confirms no SwiftUI buttons, touch gestures or virtual-controller path remain.
- The maintainer confirmed movement, Cross and Options Pause/Resume on the PS5-only revision, with no clickable screen actions. They also confirmed disconnecting stops the game with the connection message and reconnecting returns control after centring/releasing, without stuck movement.

## Phone acceptance checks

1. With the paired PlayStation controller, confirm the source and action glyph; walk the route, enter the service opening and return. Check collision, framing and visible feet/ground contact.
2. Hold movement while pressing Cross. Release the stick; motion must stop. Pause/Resume with Options; held input must not resume motion. Verify there are no clickable screen actions.
3. Disconnect the PS5 controller: the world must stop and show a connection message. Reconnect, centre/release input, and confirm control returns without stale movement.
4. Background, lock/unlock and return while input was held. Centre/release controls before resuming. Repeat without duplicate controls or frame callbacks.
5. Leave the active game untouched beyond the phone's normal Auto-Lock interval, including on Pause. Check that it remains awake, then verify normal locking after leaving the app.

These checks and measured first-playable performance must not be inferred from a passing import test. No Stage 3 implementation or Stage 2 merge is implied by this record.
