# Lauder

An open-source Apple game exploring deliberate close combat in a fully 3D world.

## Current prototype

The maintainer approved the first Eitr-inspired gameplay experiment on 28 November 2026. [Issue #236](https://github.com/RonildoBraga/lauder/issues/236) tracks implementation and validation: one hero, sword, directional shield, dodge and stamina against one enemy with a sweep and thrust. The scene uses plain geometry; the hero has no settled story identity.

The duel replaces the active bridge/squad/shooting loop. The old project remains available through the [bridge checkpoints](docs/milestones/bridge-prototype.md), including the separate unmerged two-leader pilot. Authored Blender sources, exported reference models, concept art and attribution are preserved. No old model is packaged in the duel.

This is a gameplay experiment, not a claim that combat is enjoyable or phone-ready. The [prototype plan](docs/prototype-plan.md) records exact verification and remaining human playtest gates. Merge and TestFlight delivery remain separate operations. Existing TestFlight 0.1.0 (46) still contains the old bridge.

## Play and contribute

Use Xcode 27.2 and an iOS 27 or later iPhone Simulator. Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup and validation.

    ./apple/scripts/play
    ./scripts/check
    ./apple/scripts/playtest duel-attack duel-defence duel-recovery

| Action | Keyboard | PS5 / Xbox | Touch |
| --- | --- | --- | --- |
| Move | WASD | Left stick | Movement stick |
| Attack | F | R1 / RB | Attack |
| Guard | Hold Q | Hold L1 / LB | Hold Guard |
| Dodge | Space | Circle / B | Dodge |
| Pause / resume | Escape | Options / Menu | Pause / Resume |
| Menu confirm / outcome Retry | E | Cross / A | Dedicated button |

Guard holds facing so the hero can back away behind the shield. Release it to turn normally and recover stamina. Enemy preparation commits its direction; wait for recovery to punish. Dodge has a vulnerable start and finish. Retry immediately resets the duel.

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
