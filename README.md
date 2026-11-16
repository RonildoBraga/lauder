# Lauder

An open-source, Apple-only survival exploration game about three travellers finding belonging through the ruins of a futuristic world.

The player switches between three characters while the other two follow. Their distinct abilities support exploration and purposeful salvage; their connections and histories emerge through the journey. Humans may have discreet internal synthetic replacements or biological enhancements. The full cause of the warfare and infrastructure collapse remains uncertain.

## Project status

**Party A is implemented, with Simulator route proof and a baseline PS5 phone route/control/recovery check. A short phone sample averaged about 60 fps; remaining manual checks are deferred by the maintainer. The scope is: three primitive stand-ins, session-owned leadership/Pause, Q/R1/RB switching and recorded-trail following. The maintainer explicitly authorised proceeding regardless of Claude's response. See the [Party A record](docs/party-a.md) for actual checks and remaining gaps. Skill actions and the repair loop remain later stages.**

The technical direction is Swift, RealityKit and SwiftUI, with iPhone first. Scenes are built in Swift; the validated USDZ pipeline is preserved while Party A uses primitives. Phone inputs are left stick to move, Cross/A to observe, R1/RB to cycle leader and Options/Menu to pause/resume. Simulator uses WASD, E, Q and Escape. There are no touch controls or clickable screen actions. Physical-controller validation of switching belongs to the Party A checkpoint.

## Start here

- [Story bible](docs/story/story-bible.md): current ensemble direction, proposed trio, enhancements and Chapter One outline.
- [Gameplay script](docs/gameplay-script.md): proposed party controls, shared access problem, salvage, repair and coastal contact.
- [Chapter One — A Place to Meet](docs/story/chapter-01.md): index to the current outline and playable walkthrough; detailed dialogue remains a later writing pass.
- [Architecture](docs/architecture.md): party ownership, input, following, camera, restart and later saving design.
- [First playable prototype](docs/prototype-plan.md): party movement and switching first, then access and the repair loop, with staged checks.
- [Stage 1 evidence](docs/stage-1.md): toolchain, device checks, session outcomes and remaining work.
- [Stage 2 evidence](docs/stage-2.md): controller decisions, simulator iteration and physical-device checks.

The proposed cast has Miki, Lara and Tomas as the playable trio and Nina as a supporting character. Their role assignments, enhancement histories and exact relationships remain proposals. The earlier family relationships are under review.

## Project structure

```text
Lauder.xcodeproj/              App/test targets and the shared Lauder scheme
sources/
  app/                        App entry point, world ownership and bundle configuration
  interface/                  SwiftUI HUD, controller/keyboard input and input rules
  gameplay/                   Party identity and session-owned leadership/Pause
  world/                      RealityKit bodies, recorded trails, camera and scene presentation
  content/
    PrototypeLayout.swift     Route geometry, collision dimensions and interaction anchors
    character/                Current animated stand-in, editable sources and provenance
      source/                 Editable USD layers; excluded from the app bundle
      Idle.usdz, Walk.usdz    Validated delivery assets preserved for later characters
tests/                        Asset import/rejection, movement, input-rule and layout tests
docs/                         Architecture, decisions, prototype plan and validation evidence
  story/                      Story bible and Chapter One outline index
scripts/                      Standard checks and the current character asset generator
.github/                      Pull request template
```

Keep presentation in SceneStyle and SceneDressing, route/collision anchors in PrototypeLayout, party rules in GameSession/InputRules and bounded path bookkeeping in PartyTrail. Mission rules and persistence remain planned. Keep one app target and one test target; add folders or shared abstractions when real content requires them.

For new art, group an asset's editable inputs, deliberate delivery exports and provenance together, following the [asset policy](CONTRIBUTING.md#assets-and-attribution). Sources and runtime exports serve different purposes; retain both. Review Xcode target exclusions before adding authoring files beneath `sources/content`, so they are not copied into the app. See the [verified membership rules](docs/stage-2-project-groups.md#target-membership).

## First prototype

The accepted planning sequence proves movement, switching and following with three stand-ins first. It then adds one service barrier with alternative agile/strength actions and a regulator-and-transmitter round trip ending in a coastal water-crew call. Party A has a three-focused-session stop criterion, initial hold-and-diagnose recovery without automatic warps, and R1/RB/Q switching defaults to validate. Phone checkpoints are after A and C, with B covered alongside C. Party A movement and switching are implemented and tested as recorded in the [evidence](docs/party-a.md); B/C interactions remain planned. A new playthrough duration will come from testing; the performance target remains 60 fps on an iPhone 13 Pro Max.

The maintainer has approved gameplay-first development with simple shapes and colours. Reuse the current scene and stand-in when testing the revised scope. Further visual polish and original asset production follow a worthwhile playable loop; [Death's Door remains a later visual reference](docs/visual-direction.md). Narrative proposals do not imply implemented interactions or approval of every detail.

## Contribute

People and AI-assisted contributors are welcome. Useful contributions now include story feedback, prototype-scope review, level-layout proposals, technical research and improvements to the documentation.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a focused pull request. Coding agents should also read [AGENTS.md](AGENTS.md). Use issues for proposals and questions; maintainers review changes before merging. The project plans alone are not an assignment to start implementation.

With Xcode 27.2 selected and LFS assets downloaded, run `./scripts/check` for formatting, build and unit tests. Open `Lauder.xcodeproj` and the shared `Lauder` scheme for the route prototype. Use Simulator for everyday iteration, with iPhone 13 Pro Max checks at milestones before merging playable features. The app keeps the screen awake while active, including when paused. See [validation and local signing](CONTRIBUTING.md#validation) for the testing workflow.

## Licence

[MIT](LICENSE) applies to the repository's original code, story and documentation unless a file or directory explicitly states another licence. Third-party material retains its own licence and attribution notices.
