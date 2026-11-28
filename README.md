# Lauder

An open-source Apple game exploring deliberate close combat in a fully 3D world.

## Current prototype

**Dungeon implementation in progress:** [issue #243](https://github.com/RonildoBraga/lauder/issues/243) tracks the assigned basic 17-bone mannequin and connected corridor/room route. The external character mesh and detailed hands are excluded. The maintainer found build 48's isolated duel insufficiently Soulslike; the new work evaluates traversal and combat together. Fresh checks, rendered evidence and review remain pending. [ADR 0023](docs/decisions/0023-basic-rig-dungeon-prototype.md) records the scope and reset rules.

The maintainer approved the first Eitr-inspired gameplay experiment on 28 November 2026. [Issue #236](https://github.com/RonildoBraga/lauder/issues/236) tracks implementation and validation: one hero, sword, directional shield, dodge and stamina against one enemy with a sweep and thrust. The scene uses plain geometry; the hero has no settled story identity.

The earlier duel is implemented in [PR #237](https://github.com/RonildoBraga/lauder/pull/237), with the complete local check and all three rendered Simulator routes passing on the recorded source. It replaces the active bridge/squad/shooting loop. The old project remains available through the [bridge checkpoints](docs/milestones/bridge-prototype.md), including the separate unmerged two-leader pilot. Authored Blender sources, exported reference models, concept art and attribution are preserved. No old model is packaged in the duel.

The camera and enemy-focus follow-up is in [PR #239](https://github.com/RonildoBraga/lauder/pull/239), tracked by [issue #238](https://github.com/RonildoBraga/lauder/issues/238) and stacked on PR #237. It adds a diagonal camera and a focus toggle for retreating while facing the opponent. The maintainer selected a **35° downward pitch** after the three-angle comparison. The full check and eight recorded Simulator runs pass on earlier source 83b79e7; decision record 16a202e retains that selection and review triage. The [prototype plan](docs/prototype-plan.md#camera-and-enemy-focus-follow-up--in-progress) preserves those results separately from current work.

[PR #242](https://github.com/RonildoBraga/lauder/pull/242), tracked by [issue #241](https://github.com/RonildoBraga/lauder/issues/241), adds orthographic projection, a bounded lateral enemy approach, committed ground warnings and movement-directed free slashes. The full check and six recorded Simulator runs pass on source 0e57b6d. Orthographic at 35° is the working preview after inspecting the matched-scale comparison; human phone acceptance remains open. The [current plan](docs/prototype-plan.md#duel-readability-follow-up--in-progress) records the verified delivery and remaining feedback gates.

**Earlier flat-duel TestFlight 0.1.0 (48) is available** to existing testers from reviewed delivery source aa1cb30, whose app matches verified source 0e57b6d. The [delivery record](docs/prototype-plan.md#internal-testflight-build-48--available) verifies checks, signing, successful Apple processing and tester access. Choose TestFlight → Lauder → Update. This remains a gameplay experiment: physical controls, phone performance and enjoyment await a human playtest. Merge is not authorised by this delivery. Build47 preserves the earlier duel and build46 the bridge comparison.

## Play and contribute

Use Xcode 27.2 and an iOS 27 or later iPhone Simulator. Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup and validation.

    ./apple/scripts/play
    ./scripts/check
    ./apple/scripts/playtest dungeon-journey dungeon-defence dungeon-recovery dungeon-focus

For the projection comparison, use `./apple/scripts/play --camera-projection orthographic` or `--camera-projection perspective`. Debug scripts also retain `--camera-pitch 30.5`, `35` or `40`. The working preview uses orthographic projection at 35°, including its Release configuration. [Contributing](CONTRIBUTING.md#scripted-simulator-playtests) describes matched-scale recordings.

| Action | Keyboard | PS5 / Xbox | Touch |
| --- | --- | --- | --- |
| Move | WASD | Left stick | Movement stick |
| Attack | F | R1 / RB | Attack |
| Guard | Hold Q | Hold L1 / LB | Hold Guard |
| Dodge | Space | Circle / B | Dodge |
| Focus / unfocus enemy | Tab | R3 / Right stick click | Focus / Unfocus |
| Pause / resume | Escape | Options / Menu | Pause / Resume |
| Menu confirm / outcome Retry | E | Cross / A | Dedicated button |

Focus lets the hero strafe or retreat while turning towards the enemy; a ground ring marks the selection. Without focus, Guard holds facing, while a free slash takes the movement direction when requested and commits when accepted. Release Guard to recover stamina. The enemy briefly seeks a side approach and commits its attack direction before preparation; amber ground shapes supplement the broad sweep and narrow thrust poses. Wait for recovery to punish. Dodge has a vulnerable start and finish. A room kill releases Focus and continues exploration. Death Retry restores the run at the checkpoint while keeping an opened shortcut; Pause Restart resets everything.

Simulator keyboard/pointer iteration is the everyday path. Live controller forwarding has not worked in the tested Simulator setup; controller enumeration is not proof of input delivery. Touch/controller comfort, audio, sustained phone performance and enjoyment need physical playtests.

## Project structure

    apple/
      sources/
        app/          App entry and stable world lifetime
        gameplay/     Session and authoritative value-only duel rules
        interface/    Shared input, touch capture and SwiftUI HUD
        world/        Collision, camera, primitive presentation and DEBUG scenarios
        content/      Checked mannequin poses and three generated combat sounds
      tests/          Combat, input, lifecycle, projection and collision regressions
      scripts/        Simulator, verification and TestFlight tools
    blender/
      animations/     Basic body armature, mannequin poses and reproducible export
      assets/         Preserved model authoring sources
      levels/         Preserved bridge authoring source
      reference-exports/  Historical exports outside the app bundle
      extensions/     Validated export tooling
    docs/             Current contracts, research and historical records
    art/              Preserved concept art and provenance
    scripts/check     Shared full verification command

Keep one app/module and one hosted Swift Testing target. [Architecture](docs/architecture.md) describes the boundaries: input intents → fixed combat rules → resolved presentation. No custom ECS, extra engine or generic combat framework is introduced.

## Design and history

- [Prototype plan](docs/prototype-plan.md): active scope, checks and next gates.
- [Gameplay walkthrough](docs/gameplay-script.md): the dungeon route from the player's perspective.
- [Touch controls](docs/touch-controls.md): capture, source selection and interruption rules.
- [Eitr study and roadmap](docs/research/eitr-gameplay-and-reset-proposal.md): dated evidence, limitations and later proposals.
- [Bridge checkpoints](docs/milestones/bridge-prototype.md) and [verification history](docs/bridge-prototype-plan.md): preserved project and release evidence.
- [Story bible](docs/story/story-bible.md) and [visual direction](docs/visual-direction.md): preserved creative references, not assignments for new production.
- [AGENTS.md](AGENTS.md): shared agent/reviewer workflow.

## Licence

MIT for the project. Preserve the separate provenance and licences of contributed assets; see [art](art/README.md) and [Blender](blender/assets/README.md).
