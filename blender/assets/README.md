# Models

Each model is a Blender file of its own, in a folder named after it, `<model>/<model>.blend`, stored with Git LFS ([ADR 0006](../../docs/decisions/0006-blender-source-of-truth.md)). Levels link it, so a change to the model reaches every level that uses it. [Models](../../CONTRIBUTING.md#models) in CONTRIBUTING describes placing one in a level, changing it, and bringing one in from a file.

A model's file follows the contract between Blender and the game:

- **One collection**, named after the model, holds it. Levels link that collection.
- **Its size is real**, in metres. It stands on the ground at its origin, centred there, with its front towards −y, which Blender's Front view shows and Blender's glTF import also gives.
- **Its materials** use a Principled BSDF, fed only by image textures on the inputs that [CONTRIBUTING](../../CONTRIBUTING.md#editing-a-level-in-blender) lists, with an image of its own for each map. Each has a name of its own among all the models and levels, since the scene file would merge two materials of the same name: name them after the model, such as `car paint`.
- **Its textures** are PNG or JPEG files in its folder, such as `textures/`, rather than packed into the Blender file. The [visual direction](../../docs/visual-direction.md) allows no new textures for now.
- **Its README.md** says where the model comes from and under which licence, as [CONTRIBUTING](../../CONTRIBUTING.md#assets-and-attribution) asks of every asset. `./scripts/check` fails without it.

The intake check, `check-model.py` or **Check Model** in Blender's Lauder tab, says what a model still needs. The models so far are the Brooklyn Bridge's greybox vehicles, `car`, `van` and `truck`, and the stand-ins that the game creates itself: the party's `miki`, `tom` and `laura`, and `hostile`. Saving one of these four also exports its own scene file, as [CONTRIBUTING](../../CONTRIBUTING.md#models) describes.
