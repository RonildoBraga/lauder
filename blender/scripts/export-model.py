"""Export a model that the game creates itself, such as a member of the party or a hostile (ADR
0002): its scene file, apple/sources/content/models/<model>.usdz, from its Blender file in
blender/assets.

Run it with Blender in the background, from any folder:

    blender -b --factory-startup --python-exit-code 1 --python blender/scripts/export-model.py -- <model>

The Lauder extension runs this by itself when the model's Blender file is saved, and Play runs it
before building when a scene file no longer matches. Run it by hand after changing the model
outside Blender's interface, such as with a script, or after changing a texture: ./scripts/check
fails until the scene file matches its files again.
"""

from pathlib import Path
import sys

REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "blender/extensions"))
sys.dont_write_bytecode = True

import lauder_levels  # noqa: E402

arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(arguments) != 1 or arguments[0] not in lauder_levels.SPAWNED:
    sys.exit(f"Name one model that the game creates: {', '.join(lauder_levels.SPAWNED)}.")
name = arguments[0]
blend = REPOSITORY / lauder_levels.model_file(name)
if not blend.is_file():
    sys.exit(f"{lauder_levels.model_file(name)} is missing.")
if lauder_levels.is_lfs_pointer(blend):
    sys.exit(f"{lauder_levels.model_file(name)} is not downloaded yet: run git lfs pull.")
try:
    made_from = lauder_levels.open_model_file(str(REPOSITORY), name)
    lauder_levels.export_model(str(REPOSITORY), name, made_from)
except lauder_levels.LayoutError as error:
    sys.exit(f"The model was not exported: {error}")
print(f"Exported {lauder_levels.spawned_scene(name)} from {lauder_levels.model_file(name)}.")
