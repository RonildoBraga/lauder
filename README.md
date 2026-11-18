# Lauder

An open-source, Apple-only survival exploration game about three travellers finding belonging through the ruins of a futuristic world.

The player switches between three characters while the other two follow. Their distinct abilities support exploration and purposeful salvage; their connections and histories emerge through the journey. Humans may have discreet internal synthetic replacements or biological enhancements. The full cause of the warfare and infrastructure collapse remains uncertain.

## Project status

**Party A is implemented, with Simulator route proof and a baseline PS5 phone route/control/recovery check. A short phone sample averaged about 60 fps; remaining manual checks are deferred by the maintainer. See the [Party A record](docs/party-a.md) for actual checks and remaining gaps. Party B's alternative access actions and Party C's repair loop are merged. Optional touch controls are merged; the maintainer confirmed [phone multi-touch, Pause and recovery](docs/touch-controls.md#validation).**

The [wall-contact freeze fix for #25](docs/wall-contact.md) and the [follower-spacing fix for #28](docs/follower-spacing.md) are merged. So is phase S1 of the accepted [squad movement design](https://github.com/RonildoBraga/lauder/blob/a5437e5/docs/decisions/0003-squad-movement.md): companions keep a Close formation, take their own routes and fall into single file in narrow places. After playing it on the baseline iPhone the maintainer reported “it looks good”; the [S1 record](docs/squad-s1.md) lists the checks still open, including phone timing. Debug builds can run [scripted Simulator playtests](CONTRIBUTING.md#scripted-simulator-playtests). TestFlight build 0.1.0 (2), made from M3's branch at `ecb1031` before its merge, is available to internal testers; build 0.1.0 (1), from main at `e63c0a0`, predates the bridge. Both use the app ID `com.ronildo.lauder`; see [TestFlight builds](CONTRIBUTING.md#testflight-builds).

[Party B](docs/party-b.md) is merged: a closed barrier in the service passage that Laura can open by reaching a latch or Tom by shifting a loose panel, with Miki explaining both. It passes build/tests and rendered Simulator playtests. The maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/36#issuecomment-6964336936) without an independent review, and has since played it on the phone as part of Party C's loop.

[Party C](docs/party-c.md) is merged: the keeper's briefing, Miki's regulator, the repair, a call that agrees the Old Lock meeting, **Read plan**, and an in-place Restart from a two-choice pause menu. It passes build/tests and rendered Simulator playtests. The maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/37#issuecomment-6968168004) without an independent review. After playing it on the baseline iPhone, the maintainer reported “everything worked as expected”; the [phone checkpoint](docs/party-c.md#phone-checkpoint--18-november-2026) lists what that covers, and a short sample of the loop averaged about 60 fps. Its dialogue stays provisional: the maintainer chose to settle the relationships later.

The maintainer [accepted ADR 0004](docs/decisions/0004-brooklyn-bridge-opening.md) on 18 November 2026: the game opens with Miki alone on a greybox Brooklyn Bridge, meeting Tom and Laura as strangers through a first fight, an ambush and a rescue. It is built in five milestones, each assigned separately. The maintainer assigned the first, and [M1](docs/opening-m1.md) is merged: the app opens on a flat greybox of the bridge, about 250 m long, which Miki crosses alone, with lines that show once at points along the way. Tomas and Lara are renamed Tom and Laura. The maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/41#issuecomment-6971880003) without an independent review. The Relay House slice stays as a second level. The maintainer then assigned [M2](docs/opening-m2.md), the first fight, which is merged: before the first tower a stranger steps out, Miki calls “Friendly!”, and after his deliberate near miss she can return fire with assisted aim while cars give cover to both sides. It passes build/tests and rendered Simulator playtests. After playing it on the baseline iPhone, the maintainer reported “It read well” and [authorised the merge](https://github.com/RonildoBraga/lauder/pull/42#issuecomment-6973249055) without an independent review.

The maintainer then chose Blender as the level editor ([ADR 0005](docs/decisions/0005-blender-level-editor.md)). The bridge's layout is a plain-data Swift file that Blender loads and saves through `scripts/blender/lauder_levels.py`, as [Editing a level in Blender](CONTRIBUTING.md#editing-a-level-in-blender) describes; the game still builds from the Swift file. The maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/43#issuecomment-6973768300) without an independent review.

The maintainer then assigned [M3](docs/opening-m3.md), the search, the ambush and Tom, which is in review: searching the stranger's body begins a short scene in which Tom drops an attacker running at Miki, and after a brief exchange he joins and follows her. It passes build/tests and rendered Simulator playtests, without an independent review. After playing it on the baseline iPhone, the maintainer reported “It played well”.

The maintainer has endorsed occasional combat supporting exploration and salvage, and assigned documentation of the trio's [combat identities](docs/story/story-bible.md#combat-identities) and [The Quiet Yard](docs/encounters/the-quiet-yard.md). Claude's review is addressed and the maintainer [agreed the character definitions](https://github.com/RonildoBraga/lauder/pull/29#issuecomment-6943836774); the [squad movement design](docs/decisions/0003-squad-movement.md) is accepted, with its first phase, natural following, assigned before Party B. Weapons, signature abilities and squad behaviour are working designs, with [review required before implementation](docs/prototype-plan.md#combat-design-review-gate). The encounter takes place after Chapter One and remains outside the current first playable. This documentation assignment starts no combat or formation implementation.

The technical direction is Swift, RealityKit and SwiftUI, with iPhone first. Scenes are built in Swift; the validated USDZ pipeline is preserved while Party A uses primitives. Controller inputs are left stick to move, Cross/A to observe, act or continue a conversation, R1/RB to cycle leader, R2/RT to fire on the bridge and Options/Menu to pause/resume. In the pause menu, up or down chooses Resume or Restart and Cross/A confirms. Touch controls appear without an attached extended controller: a bottom-left analog stick, **Look** (showing the action, such as **Reach latch**, where one is available, **Continue** in a conversation and **Restart** while paused), **Next: name**, **Pause/Resume** and, once a fight begins, **Fire**. An attached controller is preferred unless **Use touch controls** is selected; **Use controller** returns to it. The selection is not persisted across app launches. Simulator keyboard controls are WASD, E, Q, F to fire and Escape. The [touch-control decision](docs/touch-controls.md) supersedes the earlier no-touch rule; older PS5 phone results do not validate this new build.

## Start here

- [Story bible](docs/story/story-bible.md): current ensemble direction, proposed trio, enhancements and Chapter One outline.
- [Gameplay script](docs/gameplay-script.md): the Brooklyn Bridge opening, party controls, and the Relay House level's access problem, salvage, repair and coastal contact.
- [The Quiet Yard](docs/encounters/the-quiet-yard.md): future optional salvage encounter with avoidance, coordinated combat and retreat, a proposal, not assigned for implementation.
- [Chapter One — Across the bridge](docs/story/chapter-01.md): index to the bridge opening's outline and walkthrough; the dialogue remains a later writing pass.
- [Architecture](docs/architecture.md): party ownership, input, following, camera, restart and later saving design.
- [First playable prototype](docs/prototype-plan.md): party movement and switching first, then access and the repair loop, with staged checks.
- [Stage 1 evidence](docs/stage-1.md): toolchain, device checks, session outcomes and remaining work.
- [Stage 2 evidence](docs/stage-2.md): controller decisions, simulator iteration and physical-device checks.

The proposed cast has Miki, Laura and Tom as the playable trio and Nina as a supporting character. The three meet as strangers on the Brooklyn Bridge; their role assignments, enhancement histories and relationships remain proposals that unfold through play.

## Project structure

```text
Lauder.xcodeproj/              App/test targets and the shared Lauder scheme
sources/
  app/                        App entry point, world ownership and bundle configuration
  interface/                  HUD, controller/keyboard/touch input and shared input rules
  gameplay/                   Party identity, session-owned party, leadership, Pause and story beats
  combat/                     Plain-Swift weapons, sight lines, assisted aim and hostiles
  world/                      RealityKit bodies, squad movement, fights, camera and scene presentation
  content/
    Level.swift               A playable place as a value, and the party's shared body
    BrooklynBridge.swift      The opening's greybox bridge: its places' names and lines, and the stranger
    BrooklynBridgeLayout.swift Where everything on the bridge stands, edited in Blender (ADR 0005)
    RelayHouse.swift          The second level's geometry, collision and interactions
    MissionScript.swift       Conversations, Relay House's objectives; the lines are provisional
    character/                Current animated stand-in, editable sources and provenance
      source/                 Editable USD layers; excluded from the app bundle
      Idle.usdz, Walk.usdz    Validated delivery assets preserved for later characters
tests/                        Party/session, asset import, movement, input and layout tests
  support/                    Test-only asset validator; excluded from the app target
docs/                         Architecture, decisions, prototype plan and validation evidence
  story/                      Story bible and Chapter One outline index
scripts/                      Standard checks, Simulator playtests, the Blender level script, the character asset generator and the app icon
.github/                      Pull request template
```

Keep presentation in SceneStyle and SceneDressing, each level's geometry, collision and anchors in its `Level` (BrooklynBridge, RelayHouse), party, mission and fight rules in GameSession/InputRules, mission text in MissionScript, squad movement in NavigationGrid, SquadPlanner and CompanionMotor, and fights in the combat types, StoryDirector and EncounterStage. Persistence remains planned. Keep one app target and one test target; add folders or shared abstractions when real content requires them.

For new art, group an asset's editable inputs, deliberate delivery exports and provenance together, following the [asset policy](CONTRIBUTING.md#assets-and-attribution). Sources and runtime exports serve different purposes; retain both. Review Xcode target exclusions before adding authoring files beneath `sources/content`, so they are not copied into the app. See the [verified membership rules](docs/stage-2-project-groups.md#target-membership).

## First prototype

The accepted planning sequence proves movement, switching and following with three stand-ins first. It then adds one service barrier with alternative agile/strength actions and a regulator-and-transmitter round trip ending in a coastal water-crew call. Party A has a three-focused-session stop criterion, initial hold-and-diagnose recovery without automatic warps, and R1/RB/Q switching defaults to validate. Phone checkpoints are after A and C, with B covered alongside C. Party A movement and switching are implemented and tested as recorded in the [evidence](docs/party-a.md); Party B's barrier and Party C's loop are merged. A new playthrough duration will come from testing; the performance target remains 60 fps on an iPhone 13 Pro Max.

The maintainer has approved gameplay-first development with simple shapes and colours. Reuse the current scene and stand-in when testing the revised scope. Further visual polish and original asset production follow a worthwhile playable loop; [Death's Door remains a later visual reference](docs/visual-direction.md). Narrative proposals do not imply implemented interactions or approval of every detail.

## Contribute

People and AI-assisted contributors are welcome. Useful contributions now include story feedback, prototype-scope review, level-layout proposals, technical research and improvements to the documentation.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a focused pull request. Coding agents should also read [AGENTS.md](AGENTS.md). Use issues for proposals and questions; maintainers review changes before merging. The project plans alone are not an assignment to start implementation.

With Xcode 27.2 selected and LFS assets downloaded, run `./scripts/check` for formatting, build and unit tests. Open `Lauder.xcodeproj` and the shared `Lauder` scheme for the route prototype. Use Simulator for everyday iteration, with iPhone 13 Pro Max checks at milestones before merging playable features. The app keeps the screen awake while active, including when paused. See [validation and local signing](CONTRIBUTING.md#validation) for the testing workflow.

## Licence

[MIT](LICENSE) applies to the repository's original code, story and documentation unless a file or directory explicitly states another licence. Third-party material retains its own licence and attribution notices.
