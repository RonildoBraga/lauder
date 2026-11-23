# Models

Each model is a Blender file of its own, in a folder named after it, `<model>/<model>.blend`, stored with Git LFS ([ADR 0002](../../docs/decisions/0002-blender-source-of-truth.md)). Levels link it, so a change to the model reaches every level that uses it. [Models](../../CONTRIBUTING.md#models) in CONTRIBUTING describes placing one in a level, changing it, and bringing one in from a file.

A model's file follows the contract between Blender and the game:

- **One collection**, named after the model, holds it. Levels link that collection.
- **Its size is real**, in metres. It stands on the ground at its origin, centred there, with its front towards −y, which Blender's Front view shows and Blender's glTF import also gives.
- **Its materials** use a Principled BSDF, fed only by image textures on the inputs that [CONTRIBUTING](../../CONTRIBUTING.md#editing-a-level-in-blender) lists, with an image of its own for each map. Each has a name of its own among all the models and levels, since the scene file would merge two materials of the same name: name them after the model, such as `miki clothing`.
- **Its textures** are PNG or JPEG files in its folder, such as `textures/`, rather than packed into the Blender file. The [visual direction](../../docs/visual-direction.md) allows no textures apart from baked ambient occlusion.
- **Its README.md** says where the model comes from and under which licence, as [CONTRIBUTING](../../CONTRIBUTING.md#assets-and-attribution) asks of every asset. `./scripts/check` fails without it.

The intake check, `check-model.py` or **Check Model** in Blender's Lauder tab, says what a model still needs. The runtime-spawned models are the stand-ins that the game creates itself: the party's `miki`, `tom` and `laura`, `hostile` and the C guard, `spider-bot-heavy`. Saving one of them also exports its own scene file, as [CONTRIBUTING](../../CONTRIBUTING.md#models) describes.

The [spider-bot](spider-bot/README.md) is a rejected authoring model and motion study, retained as historical reference. It is not registered as spawned or placed in a level, so saving it creates no runtime export. Its README records the reference-derived CC BY 4.0 licence, proportions, mesh budget and source-only motion. The other models keep their existing licences.

The selected C [heavy walker](spider-bot-heavy/README.md) now has the assigned Blender motion studies and reusable linked leg/gun components, with reference-derived CC BY 4.0 source and renders. It is registered as a spawned runtime model for the first-tower guard. Its export preserves named joint transforms and generates source measurements for the runtime presenter. A remains a possible later different-weapon variant, not a current asset assignment.

The [party character study](../studies/party-characters/README.md) contains original larger-head Miki, Laura and Tom candidates with a shared humanoid rig and nine animation clips, under MIT. It is an unregistered multi-character review scene named `character-study.blend`; saving it does not replace the existing party models or export its review context. Visual review precedes canonical promotion and runtime integration.
