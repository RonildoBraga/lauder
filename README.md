# Lauder

An open-source, Apple-only survival exploration game about three travellers finding belonging through the ruins of a futuristic world.

The player switches between three characters while the other two follow. Their distinct abilities support exploration and purposeful salvage; their connections and histories emerge through the journey. Humans may have discreet internal synthetic replacements or biological enhancements. The full cause of the warfare and infrastructure collapse remains uncertain.

## Project status

The game opens on a greybox **Brooklyn Bridge** ([ADR 0004](docs/decisions/0004-brooklyn-bridge-opening.md)): Miki crosses alone towards Manhattan and meets Tom and Laura as strangers, through a first fight, an ambush and a rescue. It is built in five milestones, each assigned separately.

- **M1 to M3 are merged:** the bridge with Miki alone, the stranger's fight with assisted aim and cover, and the search, the ambush and Tom joining. After playing M2 and M3 on the baseline iPhone, the maintainer reported “It read well” and “It played well”. The [opening record](docs/opening.md) lists what each milestone built and how it was checked; none had an independent review.
- **M4 is in review:** Laura found hurt at mid-span, **Help** with the medical kit, Laura joining, and the end of the opening at the Manhattan end. It passes the checks and Simulator playtests. On the baseline iPhone, a two-minute sample of TestFlight build 0.1.0 (3) held 60 fps; the maintainer's playtest report, which completes the opening's phone checkpoint, is still to come.
- **Blender is the level editor** ([ADR 0005](docs/decisions/0005-blender-level-editor.md)). The bridge's layout, decoration and game camera are a plain-data Swift file that Blender loads and saves, as [Editing a level in Blender](CONTRIBUTING.md#editing-a-level-in-blender) describes; the game still builds from the Swift file.
- **Companions follow as a squad** in a Close formation ([ADR 0003](docs/decisions/0003-squad-movement.md), phase S1). The trio's [combat identities](docs/story/story-bible.md#combat-identities) and [The Quiet Yard](docs/encounters/the-quiet-yard.md) are agreed working designs; formations and further combat need their own assignment, after the [review gate](docs/prototype-plan.md#combat-design-review-gate).
- **The earlier Relay House slice**, Stages 1 and 2 and Parties A to C, is summarised in the [project history](docs/history.md), with its phone results and the checks still open. The maintainer removed its level on 18 November 2026.
- TestFlight build 0.1.0 (3), from M4's branch at `c6af7c1`, is available to internal testers; see [TestFlight builds](CONTRIBUTING.md#testflight-builds). Debug builds can run [scripted Simulator playtests](CONTRIBUTING.md#scripted-simulator-playtests).

The technical direction is Swift, RealityKit and SwiftUI, with iPhone first. Scenes are built in Swift; the validated USDZ pipeline is preserved while the prototype uses primitives. Controller inputs are left stick to move, Cross/A to look, act or continue a conversation, R1/RB to cycle leader, R2/RT to fire and Options/Menu to pause/resume. In the pause menu, up or down chooses Resume or Restart and Cross/A confirms. Touch controls appear without an attached extended controller: a bottom-left analog stick, **Look** (showing the action, such as **Search**, where one is available, **Continue** in a conversation and **Restart** while paused), **Next: name**, **Pause/Resume** and, once a fight begins, **Fire**. An attached controller is preferred unless **Use touch controls** is selected; **Use controller** returns to it. The selection is not persisted across app launches. Simulator keyboard controls are WASD, E, Q, F to fire and Escape. The [touch-control decision](docs/touch-controls.md) supersedes the earlier no-touch rule.

## Start here

- [Story bible](docs/story/story-bible.md): current ensemble direction, proposed trio, enhancements and Chapter One outline.
- [Gameplay walkthrough](docs/gameplay-script.md): the Brooklyn Bridge opening and its controls, and the future squad and combat design.
- [The Quiet Yard](docs/encounters/the-quiet-yard.md): future optional salvage encounter with avoidance, coordinated combat and retreat, a proposal, not assigned for implementation.
- [Architecture](docs/architecture.md): ownership, input, movement, fights, scenes, Restart and later saving.
- [First playable prototype](docs/prototype-plan.md): the opening's milestones, the input contract and the checks.
- [Opening record](docs/opening.md): what each milestone built, how it was checked and what stays open.
- [Project history](docs/history.md): Stages 1 and 2 and Parties A to C, their phone results and the checks still open.

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
      BrooklynBridgeLayout.swift Where everything on the bridge stands, its decoration and camera, edited in Blender (ADR 0005)
      MissionScript.swift       Conversations; the lines are provisional
      character/                Current animated stand-in, editable sources and provenance
        source/                 Editable USD layers; excluded from the app bundle
        Idle.usdz, Walk.usdz    Validated delivery assets preserved for later characters
  tests/                        Party/session, asset import, movement, input, combat and layout tests
    support/                    Test-only asset validator and the squad tests' yard; not in the app target
  scripts/                      Simulator playtests, the character asset generator and the app icon
  .swift-format                 Swift formatting rules
blender/                        The level editor: the Blender script that loads and saves layouts, and its tests
docs/                           Architecture, decisions, prototype plan, opening record and project history
  story/                        Story bible
scripts/check                   Checks every part: the Blender script, then the app's formatting, build and tests
.github/                        Pull request template
```

Keep presentation in SceneStyle and SceneDressing, the level's geometry, collision and anchors in its `Level` (BrooklynBridge and its layout file), party, story and fight rules in GameSession/InputRules, conversations in MissionScript, squad movement in NavigationGrid, SquadPlanner and CompanionMotor, and fights in the combat types, StoryDirector and EncounterStage. Persistence remains planned. Keep one app target and one test target; add folders or shared abstractions when real content requires them. Each platform and tool keeps its own top-level folder, so that later platforms, such as Android or Steam, can sit beside `apple/`. What a second platform will share, such as the level layouts, stays in `apple/` until then, when it moves to a shared folder in a form both can read.

For new art, group an asset's editable inputs, deliberate delivery exports and provenance together, following the [asset policy](CONTRIBUTING.md#assets-and-attribution). Sources and runtime exports serve different purposes; retain both. Review Xcode target exclusions before adding authoring files beneath `apple/sources/content`, so they are not copied into the app; see [target membership](CONTRIBUTING.md#target-membership).

## First prototype

The first playable is the Brooklyn Bridge opening, built milestone by milestone with simple shapes and colours, as the [prototype plan](docs/prototype-plan.md) sets out. Each milestone is checked with tests, scripted Simulator playtests and a maintainer playtest. The opening's phone checkpoint comes with M4; the performance target remains 60 fps on an iPhone 13 Pro Max. A playthrough's duration will come from testing.

The maintainer has approved gameplay-first development with simple shapes and colours. Reuse the current scene and stand-ins when testing. Further visual polish and original asset production follow a worthwhile playable loop; [Death's Door remains a later visual reference](docs/visual-direction.md). Narrative proposals do not imply implemented interactions or approval of every detail.

## Contribute

People and AI-assisted contributors are welcome. Useful contributions now include story feedback, prototype-scope review, level-layout proposals, technical research and improvements to the documentation.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a focused pull request. Coding agents should also read [AGENTS.md](AGENTS.md). Use issues for proposals and questions; maintainers review changes before merging. The project plans alone are not an assignment to start implementation.

With Xcode 27.2 selected and LFS assets downloaded, run `./scripts/check` for formatting, build and unit tests. Open `apple/Lauder.xcodeproj` and the shared `Lauder` scheme for the prototype. Use Simulator for everyday iteration, with iPhone 13 Pro Max checks at milestones before merging playable features. The app keeps the screen awake while active, including when paused. See [validation and local signing](CONTRIBUTING.md#validation) for the testing workflow.

## Licence

[MIT](LICENSE) applies to the repository's original code, story and documentation unless a file or directory explicitly states another licence. Third-party material retains its own licence and attribution notices.
