# Lauder

An open-source Apple game exploring deliberate close combat in a fully 3D world.

## Current prototype

The maintainer approved the first Eitr-inspired gameplay experiment on 28 November 2026. [Issue #236](https://github.com/RonildoBraga/lauder/issues/236) tracks implementation and validation: one hero, sword, directional shield, dodge and stamina against one enemy with a sweep and thrust. The scene uses plain geometry; the hero has no settled story identity.

The duel is implemented in [PR #237](https://github.com/RonildoBraga/lauder/pull/237), with the complete local check and all three rendered Simulator routes passing on the recorded source. It replaces the active bridge/squad/shooting loop. The old project remains available through the [bridge checkpoints](docs/milestones/bridge-prototype.md), including the separate unmerged two-leader pilot. Authored Blender sources, exported reference models, concept art and attribution are preserved. No old model is packaged in the duel.

The camera and enemy-focus follow-up is implemented under [issue #238](https://github.com/RonildoBraga/lauder/issues/238), stacked on PR #237. It adds a lower diagonal camera and a focus toggle for retreating while facing the opponent. The full check and all four recorded Simulator routes pass on source 6c765af; the [prototype plan](docs/prototype-plan.md#camera-and-enemy-focus-follow-up--in-progress) records results and remaining review/phone gates. Build47 below is the earlier revision and does not contain this follow-up.

This is a gameplay experiment, not a claim that combat is enjoyable or phone-ready. The [prototype plan](docs/prototype-plan.md) records exact verification and remaining human playtest gates. **Internal TestFlight 0.1.0 (47) is now available** to existing testers from reviewed source e984b60; see the [delivery record](docs/prototype-plan.md#internal-testflight-build-47--available) for checks, signing, Apple processing and access proof. Choose TestFlight → Lauder → Update. This reviewed preview leaves merge and physical gameplay acceptance open. Build46 remains the earlier bridge comparison.

## Play and contribute

Use Xcode 27.2 and an iOS 27 or later iPhone Simulator. Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup and validation.

    ./apple/scripts/play
    ./scripts/check
    ./apple/scripts/playtest duel-attack duel-defence duel-recovery duel-focus

| Action | Keyboard | PS5 / Xbox | Touch |
| --- | --- | --- | --- |
| Move | WASD | Left stick | Movement stick |
| Attack | F | R1 / RB | Attack |
| Guard | Hold Q | Hold L1 / LB | Hold Guard |
| Dodge | Space | Circle / B | Dodge |
| Focus / unfocus enemy | Tab | R3 / Right stick click | Focus / Unfocus |
| Pause / resume | Escape | Options / Menu | Pause / Resume |
| Menu confirm / outcome Retry | E | Cross / A | Dedicated button |

Focus lets the hero strafe or retreat while turning towards the enemy; a ground ring marks the selection. Without focus, Guard holds the current facing. Committed attacks and dodges keep their direction. Release Guard to recover stamina. Enemy preparation commits its direction; wait for recovery to punish. Dodge has a vulnerable start and finish. Retry immediately resets the duel and clears focus.

Simulator keyboard/pointer iteration is the everyday path. Live controller forwarding has not worked in the tested Simulator setup; controller enumeration is not proof of input delivery. Touch/controller comfort, audio, sustained phone performance and enjoyment need physical playtests.

## Project structure

    apple/
      sources/
        app/          App entry and stable world lifetime
        gameplay/     Session and authoritative value-only duel rules
        interface/    Shared input, touch capture and SwiftUI HUD
        world/        Collision, camera, primitive presentation and DEBUG scenarios
        content/      Three generated combat sounds
      tests/          Combat, input, lifecycle, projection and collision regressions
      scripts/        Simulator, verification and TestFlight tools
    blender/
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
- [Gameplay walkthrough](docs/gameplay-script.md): the duel from the player's perspective.
- [Touch controls](docs/touch-controls.md): capture, source selection and interruption rules.
- [Eitr study and roadmap](docs/research/eitr-gameplay-and-reset-proposal.md): dated evidence, limitations and later proposals.
- [Bridge checkpoints](docs/milestones/bridge-prototype.md) and [verification history](docs/bridge-prototype-plan.md): preserved project and release evidence.
- [Story bible](docs/story/story-bible.md) and [visual direction](docs/visual-direction.md): preserved creative references, not assignments for new production.
- [AGENTS.md](AGENTS.md): shared agent/reviewer workflow.

## Licence

MIT for the project. Preserve the separate provenance and licences of contributed assets; see [art](art/README.md) and [Blender](blender/assets/README.md).
