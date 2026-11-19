"""Lauder's levels and models in Blender (ADR 0002), as a Blender extension.

Each level is a Blender file in the repository, blender/levels/<level>.blend, stored with Git LFS:
the level's source. Its collections decide where each object goes:

- Visual: everything the player sees. Export writes it to the level's scene file, a USDZ that the
  game loads. A model appears in it as an instance of the model's collection, linked from the
  model's own file.
- Gameplay: the ground, the boxes that block movement and sight, the landmarks, the trigger and
  fight areas, and the markers where people start and stand, each with its role. Export writes
  them to the level's layout file, typed Swift that the game compiles. They show as outlines, and
  the game never draws them. A visual part or model parented to a gameplay box moves with it.
- Lights and Camera: the level's lights, suns, point lights and spot lights, and the game
  camera's rig, written to the layout file too.
- Preview: the party's models at their start markers, which the game places itself. It is never
  exported, and the files that only it uses are not counted among the level's.

Each model is a Blender file of its own, blender/assets/<model>/<model>.blend, also stored with
Git LFS. It holds one collection named after the model, at its real size in metres and standing on
the ground at its origin. Beside it are a README.md, which says where the model comes from and
under which licence, and any textures it uses. Levels link the model, so a change to it reaches
every level that uses it: saving a model exports the levels whose last export used it. The intake
check, Check Model or blender/scripts/check-model.py, says what a model needs before a level can
use it. blender/scripts/add-model.py brings a model in from a Blender, glTF, FBX, OBJ or USD file.
The models that the game creates itself, such as the party and the hostiles (SPAWNED), get scene
files of their own in apple/sources/content/models: saving such a model exports it in the
background, with blender/scripts/export-model.py. Bake Occlusion bakes ambient occlusion into the
colour of the selected parts of a level's Visual, as images in blender/levels/baked.

Install it once: in Blender's Preferences, add a local extension repository at this repository's
blender/extensions folder, then enable Lauder levels. A Lauder tab appears in the 3D Viewport's
sidebar (press N). Open Level opens the level's Blender file. Add Model places a model in it, and
Open Model opens the selected model's own file. Saving a level checks the game's rules, then
exports in a Blender of its own, in the background, with blender/scripts/export-level.py, which
agents run too. Play saves, exports when needed, then builds the game and opens it in the iOS
Simulator through apple/scripts/play. blender/level-exports.json records what each export was made
from and what it wrote, and ./scripts/check fails when they no longer match.

The extension is split by job, each module importing only those before it here: common, what
every part shares; lights; layouts, what plays; looks, what a scene file shows; models; exports;
occlusion, baked occlusion; background, work in a process of its own; and interface, the Lauder
tab.

Writing and checking a layout, and the intake check's rules, need no Blender:
blender/test_lauder_levels.py runs those parts in ./scripts/check. Coordinates in the layout file
are the game's, in metres: x across, y up and z along the level. In Blender, z is up, so a game
point (x, y, z) sits at (x, -z, y).
"""

from . import common, lights, layouts, looks, models, exports, occlusion, background, interface

# The package keeps every name that its modules define, so that the scripts and the tests
# can use lauder_levels.<name> wherever it lives.
for _module in (common, lights, layouts, looks, models, exports, occlusion, background, interface):
    globals().update({name: value for name, value in vars(_module).items()
                      if not (name.startswith("__") and name.endswith("__"))})
del _module


def register():
    interface.register()


def unregister():
    interface.unregister()
