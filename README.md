# Lauder

An open-source, Apple-only survival exploration game about three travellers finding belonging through the ruins of a futuristic world.

The player switches between three characters while the other two follow. Their distinct abilities support exploration and purposeful salvage; their connections and histories emerge through the journey. Humans may have discreet internal synthetic replacements or biological enhancements. The full cause of the warfare and infrastructure collapse remains uncertain.

## Project status

The game opens on the snowbound **Brooklyn Bridge** ([ADR 0004](docs/decisions/0004-brooklyn-bridge-opening.md)): Miki crosses alone towards Manhattan and meets Tom and Laura as strangers, through a first fight, an ambush and a rescue, and the three reach the Manhattan end together. This opening is the first playable. It is built, it passed its phone checkpoint, and on 21 November 2026 the maintainer judged it worth building on; the [prototype plan](docs/prototype-plan.md) sets out its scope and what comes next. The maintainer has approved gameplay-first development, and on 20 November 2026 chose a minimalist low-poly look for a frozen world as the [visual direction](docs/visual-direction.md). The bridge moves to it in small steps from today's greybox, reusing the current scene and stand-ins where they serve.

- **Blender holds the levels and models** ([ADR 0002](docs/decisions/0002-blender-source-of-truth.md)). The bridge's source is its Blender file, `blender/levels/brooklyn-bridge.blend`. Saving it exports the scene file the game shows and the layout file it plays from, as [Editing a level in Blender](CONTRIBUTING.md#editing-a-level-in-blender) describes. Levels can link [models](CONTRIBUTING.md#models) from `blender/assets`, and the party and the hostiles are models the game creates.
- **Companions move as a squad** ([ADR 0003](docs/decisions/0003-squad-movement.md), phases S1 to S3). Once Laura joins, the formation button cycles **Close**, **Spread** and **Column**, and tight places squeeze the group into single file until it can spread out again: the opening's M5. Squad orders send both companions, or one of them, to a marked point or hold them where they stand, and the formation button then calls them back. The combat design review settled a first squad combat experiment ([ADR 0005](docs/decisions/0005-squad-combat-experiment.md)), which the maintainer assigned on 21 November 2026: “Yes, build it”. It is built in a greybox combat yard outside the story, which the pause menu's **Combat test** opens. After its first session the maintainer chose cover next, “Yes, try cover next”, so the yard's companions now take cover near their places, which on build 0.1.0 (13) “Worked well”. The maintainer then chose to finish S4 there, “Yes, finish S4”: the yard now has all of ADR 0003's combat positioning, with each companion's own preferences in cover, routes that keep out of the shooters' sight, and **Regroup** on the formation button. On build 0.1.0 (15) that “Worked well”, the last of the experiment's three sessions. Next, the maintainer chose salvage and exploration, and settled a [first salvage and exploration experiment](docs/decisions/0006-salvage-and-exploration-experiment.md): a greybox salvage yard where the trio recovers a part for a repair, which the maintainer assigned, “Yes, build it”. It is built, and the pause menu's third choice reaches it from the combat yard. On build 0.1.0 (16) its first session “went well”, and for the second, each run deals the cabinets' contents afresh. Asked to play build 0.1.0 (17) in the Simulator instead, Claude found the rules sound but the yard unclear from the camera, and the maintainer chose to fix that, “Yes, do both”: the gate, its latch and panel, the transmitter and what the party knows of each cabinet now show in the palette's colours. On build 0.1.0 (18) the maintainer found that it “reads well”. The maintainer then asked for a better shooting system, which [ADR 0007](docs/decisions/0007-aiming-and-shot-feedback.md) records: on a controller the right stick aims Miki's carbine, shots that hit nobody strike the scenery, every shot shows a streak, flashes and impacts, and the lens narrows in a fight. Asked next to take combat further, with The Division 2 as the reference, the maintainer chose a five-phase plan, which [ADR 0008](docs/decisions/0008-weapon-feel-and-combat-plan.md) records, and its first phase is built: no aim line, Miki's pose shows her aim, shots spread, enemies flinch and fall, and fights have sound and vibration.
- Changes are checked with tests, [scripted Simulator playtests](CONTRIBUTING.md#scripted-simulator-playtests) and a maintainer playtest, and milestones on the baseline iPhone 13 Pro Max, where the target is 60 fps. TestFlight builds reach internal testers; see [TestFlight builds](CONTRIBUTING.md#testflight-builds).

Current iteration uses Simulator; the maintainer deferred phone deployment on 22 November 2026. The first weapon-feel phase still awaits its phone checkpoint. The assigned active-character cover prototype is built in the combat yard ([ADR 0009](docs/decisions/0009-leader-cover.md)): automatic cover near a block, a directional shield for the leader, and exposure while firing over low cover or peeking past a tall edge. It passes Simulator checks and awaits its phone session. Combat phases 3 to 5 remain proposals, as the [prototype plan](docs/prototype-plan.md#combat-design-review-gate) records.

The technical direction is Swift, RealityKit and SwiftUI, with iPhone first ([ADR 0001](docs/decisions/0001-engine.md)). The game plays with a PS5 or Xbox controller, with touch, or with the keyboard in the Simulator; the [input contract](docs/prototype-plan.md#input-and-interaction-contract) lists the controls, and [Touch controls](docs/touch-controls.md) describes the touch layout.

## Start here

- [Story bible](docs/story/story-bible.md): current ensemble direction, proposed trio, enhancements and Chapter One outline.
- [Gameplay walkthrough](docs/gameplay-script.md): the Brooklyn Bridge opening as the player meets it, and the future squad and combat design.
- [The Quiet Yard](docs/encounters/the-quiet-yard.md): future optional salvage encounter with avoidance, coordinated combat and retreat, a proposal, not assigned for implementation.
- [Architecture](docs/architecture.md): ownership, input, movement, fights, scenes, Restart and later saving.
- [Decision records](docs/decisions): the engine, Blender as the source of levels and models, squad movement, the Brooklyn Bridge opening, squad combat and salvage experiments, aiming and shot feedback, weapon feel with a plan for combat, and active-character cover.
- [First playable prototype](docs/prototype-plan.md): the scope, the input contract, the checks and what comes next.
- [Visual direction](docs/visual-direction.md): the frozen, minimalist low-poly look the maintainer chose on 20 November 2026, with its palette, light, camera and rendering budget.

The proposed cast has Miki, Laura and Tom as the playable trio and Nina as a supporting character. The three meet as strangers on the Brooklyn Bridge; their role assignments, enhancement histories and relationships remain proposals that unfold through play. Narrative proposals do not imply implemented interactions or approval of every detail.

## Project structure

```text
apple/                          The iPhone game: Swift, RealityKit and SwiftUI
  Lauder.xcodeproj/             App/test targets and the shared Lauder scheme
  sources/
    app/                        App entry point, world ownership and bundle configuration
    interface/                  HUD, controller/keyboard/touch input and shared input rules
    gameplay/                   Party identity, session-owned party, leadership, Pause and story beats
    combat/                     Plain-Swift weapons, sight lines, aiming and hostiles
    world/                      RealityKit bodies, squad movement, fights, shots' effects, camera and scene presentation
    content/
      Level.swift               A playable place as a value, and the party's shared body
      LevelLayout.swift         The shape of a layout file: where a level's parts stand, its camera and lights
      BrooklynBridge.swift      The opening's greybox bridge: its places' names and lines, and the stranger
      CombatYard.swift          The combat experiment's temporary greybox yard, defined in Swift, and its fight rules
      SalvageYard.swift         The salvage experiment's temporary greybox yard, defined in Swift, and its salvage task
      LevelCycle.swift          The pause menu's cycle through the bridge and the two test yards
      BrooklynBridgeLayout.swift Where everything that plays on the bridge stands, its camera and lights, exported by Blender
      BrooklynBridge.usdz       Everything the player sees of the bridge, exported by Blender
      models/                   The party's and the hostiles' looks, exported by Blender from their models
      MissionScript.swift       Conversations; the lines are provisional
  tests/                        Party/session, movement, input, combat, layout and look tests
    support/                    The squad tests' yard and the helpers that play a world without rendering; not in the app target
  scripts/                      Simulator playtests, Play and the app icon
  .swift-format                 Swift formatting rules
blender/                        The levels' Blender files, in levels/, the models, in assets/, and the Lauder extension for Blender, in extensions/lauder_levels, with its tests
docs/                           Architecture, decision records, the prototype plan, the gameplay walkthrough, touch controls and the visual direction
  story/                        Story bible
  encounters/                   Encounter designs
scripts/check                   Checks every part: the Blender extension's tests, then the app's formatting, build and tests
.github/                        Pull request template
```

Each platform and tool keeps its own top-level folder, so that later platforms, such as Android or Steam, can sit beside `apple/`. What a second platform will share, such as the level layouts, stays in `apple/` until then, when it moves to a shared folder in a form both can read. The [architecture](docs/architecture.md) sets out which part owns what, and [Assets and attribution](CONTRIBUTING.md#assets-and-attribution) how to add art.

## Contribute

People and AI-assisted contributors are welcome. Useful contributions now include story feedback, prototype-scope review, level-layout proposals, technical research and improvements to the documentation.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a focused pull request. Coding agents should also read [AGENTS.md](AGENTS.md). Use issues for proposals and questions; maintainers review changes before merging. The project plans alone are not an assignment to start implementation.

Open `apple/Lauder.xcodeproj` and the shared `Lauder` scheme to run the game, and run `./scripts/check` before a pull request; [Validation](CONTRIBUTING.md#validation) sets out the toolchain, the checks, local signing and the phone checkpoints.

## Licence

[MIT](LICENSE) applies to the repository's original code, story and documentation unless a file or directory explicitly states another licence. Third-party material retains its own licence and attribution notices.
