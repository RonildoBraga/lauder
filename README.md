# Lauder

An open-source, Apple-only survival exploration game about three travellers finding belonging through the ruins of a futuristic world.

The player switches between three characters while the other two follow. Their distinct abilities support exploration and purposeful salvage; their connections and histories emerge through the journey. Humans may have discreet internal synthetic replacements or biological enhancements. The full cause of the warfare and infrastructure collapse remains uncertain.

## Project status

The game opens on a greybox **Brooklyn Bridge** ([ADR 0004](docs/decisions/0004-brooklyn-bridge-opening.md)): Miki crosses alone towards Manhattan and meets Tom and Laura as strangers, through a first fight, an ambush and a rescue, and the three reach the Manhattan end together.

- **Blender holds the levels and models** ([ADR 0002](docs/decisions/0002-blender-source-of-truth.md)). The bridge's source is its Blender file, `blender/levels/brooklyn-bridge.blend`. Saving it exports the scene file the game shows and the layout file it plays from, as [Editing a level in Blender](CONTRIBUTING.md#editing-a-level-in-blender) describes. Levels link [models](CONTRIBUTING.md#models) from `blender/assets`, such as the bridge's vehicles, and the party and the hostiles are models too.
- **Companions follow as a squad** in a Close formation ([ADR 0003](docs/decisions/0003-squad-movement.md), phase S1). Formations come next, as the opening's M5; further combat waits for the [combat design review gate](docs/prototype-plan.md#combat-design-review-gate). Each needs its own assignment.
- TestFlight builds reach internal testers; see [TestFlight builds](CONTRIBUTING.md#testflight-builds). Debug builds can run [scripted Simulator playtests](CONTRIBUTING.md#scripted-simulator-playtests).

The technical direction is Swift, RealityKit and SwiftUI, with iPhone first ([ADR 0001](docs/decisions/0001-engine.md)). Controller inputs are left stick to move, Cross/A to look, act or continue a conversation, R1/RB to cycle leader, R2/RT to fire and Options/Menu to pause/resume. In the pause menu, up or down chooses Resume or Restart and Cross/A confirms. Touch controls appear without an attached extended controller: a bottom-left analog stick, **Look** (showing the action, such as **Search**, where one is available, **Continue** in a conversation and **Restart** while paused), **Next: name**, **Pause/Resume** and, once a fight begins, **Fire**. An attached controller is preferred unless **Use touch controls** is selected; **Use controller** returns to it. The selection is not kept across launches. Simulator keyboard controls are WASD, E, Q, F to fire and Escape. [Touch controls](docs/touch-controls.md) describes the touch layout.

## Start here

- [Story bible](docs/story/story-bible.md): current ensemble direction, proposed trio, enhancements and Chapter One outline.
- [Gameplay walkthrough](docs/gameplay-script.md): the Brooklyn Bridge opening and its controls, and the future squad and combat design.
- [The Quiet Yard](docs/encounters/the-quiet-yard.md): future optional salvage encounter with avoidance, coordinated combat and retreat, a proposal, not assigned for implementation.
- [Architecture](docs/architecture.md): ownership, input, movement, fights, scenes, Restart and later saving.
- [Decision records](docs/decisions): the engine, Blender as the source of levels and models, squad movement and the Brooklyn Bridge opening.
- [First playable prototype](docs/prototype-plan.md): the scope, the input contract, the checks and what comes next.

The proposed cast has Miki, Laura and Tom as the playable trio and Nina as a supporting character. The three meet as strangers on the Brooklyn Bridge; their role assignments, enhancement histories and relationships remain proposals that unfold through play.

## Project structure

```text
apple/                          The iPhone game: Swift, RealityKit and SwiftUI
  Lauder.xcodeproj/             App/test targets and the shared Lauder scheme
  sources/
    app/                        App entry point, world ownership and bundle configuration
    interface/                  HUD, controller/keyboard/touch input and shared input rules
    gameplay/                   Party identity, session-owned party, leadership, Pause and story beats
    combat/                     Plain-Swift weapons, sight lines, assisted aim and hostiles
    world/                      RealityKit bodies, squad movement, fights, camera and scene presentation
    content/
      Level.swift               A playable place as a value, and the party's shared body
      BrooklynBridge.swift      The opening's greybox bridge: its places' names and lines, and the stranger
      BrooklynBridgeLayout.swift Where everything that plays on the bridge stands, its camera and lights, exported by Blender
      BrooklynBridge.usdz       Everything the player sees of the bridge, exported by Blender
      models/                   The party's and the hostiles' looks, exported by Blender from their models
      MissionScript.swift       Conversations; the lines are provisional
  tests/                        Party/session, movement, input, combat, layout and look tests
    support/                    The squad tests' yard; not in the app target
  scripts/                      Simulator playtests, Play and the app icon
  .swift-format                 Swift formatting rules
blender/                        The levels' Blender files, in levels/, the models they link, in assets/, and the Lauder extension for Blender, in extensions/lauder_levels, with its tests
docs/                           Architecture, decision records, the prototype plan, the gameplay walkthrough, touch controls and the visual direction
  story/                        Story bible
  encounters/                   Encounter designs
scripts/check                   Checks every part: the Blender script, then the app's formatting, build and tests
.github/                        Pull request template
```

Keep a level's look in its Blender file, the look of what the game creates, such as the party and the hostiles, in its model's file, and the game's own presentation, such as the gameplay signals, in SceneStyle. Keep the level's geometry, collision and anchors in its `Level` (BrooklynBridge and its layout file), party, story and fight rules in GameSession/InputRules, conversations in MissionScript, squad movement in NavigationGrid, SquadPlanner and CompanionMotor, and fights in the combat types, StoryDirector and EncounterStage. Persistence remains planned. Keep one app target and one test target; add folders or shared abstractions when real content requires them. Each platform and tool keeps its own top-level folder, so that later platforms, such as Android or Steam, can sit beside `apple/`. What a second platform will share, such as the level layouts, stays in `apple/` until then, when it moves to a shared folder in a form both can read.

For new art, group an asset's editable inputs, deliberate delivery exports and provenance together, following the [asset policy](CONTRIBUTING.md#assets-and-attribution). Sources and runtime exports serve different purposes; retain both. Review Xcode target exclusions before adding authoring files beneath `apple/sources/content`, so they are not copied into the app; see [target membership](CONTRIBUTING.md#target-membership).

## First prototype

The first playable is the Brooklyn Bridge opening, made with simple shapes and colours, as the [prototype plan](docs/prototype-plan.md) sets out. Changes are checked with tests, scripted Simulator playtests and a maintainer playtest, and milestones on the baseline iPhone 13 Pro Max, where the target is 60 fps. A playthrough's duration will come from testing.

The maintainer has approved gameplay-first development with simple shapes and colours. Reuse the current scene and stand-ins when testing. Further visual polish and original asset production follow a worthwhile playable loop; [Death's Door remains a later visual reference](docs/visual-direction.md). Narrative proposals do not imply implemented interactions or approval of every detail.

## Contribute

People and AI-assisted contributors are welcome. Useful contributions now include story feedback, prototype-scope review, level-layout proposals, technical research and improvements to the documentation.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a focused pull request. Coding agents should also read [AGENTS.md](AGENTS.md). Use issues for proposals and questions; maintainers review changes before merging. The project plans alone are not an assignment to start implementation.

With Xcode 27.2 selected and LFS assets downloaded, run `./scripts/check` for formatting, build and unit tests. Open `apple/Lauder.xcodeproj` and the shared `Lauder` scheme for the prototype. Use Simulator for everyday iteration, with iPhone 13 Pro Max checks at milestones before merging playable features. The app keeps the screen awake while active, including when paused. See [validation and local signing](CONTRIBUTING.md#validation) for the testing workflow.

## Licence

[MIT](LICENSE) applies to the repository's original code, story and documentation unless a file or directory explicitly states another licence. Third-party material retains its own licence and attribution notices.
