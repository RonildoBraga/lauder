"""Export a Lauder level (ADR 0006): its layout file, typed Swift for what plays, and its scene file,
a USDZ for what the player sees, both from the level's Blender file in blender/levels.

Run it with Blender in the background, from any folder:

    blender -b --factory-startup --python-exit-code 1 --python blender/scripts/export-level.py -- [level]

The level defaults to brooklyn-bridge. The Lauder extension runs this by itself when the level's
Blender file is saved, or a model that the level uses, and Play runs it before building. Run it by
hand after changing the level or its models outside Blender's interface, such as with a script, or
after changing a texture: ./scripts/check fails until the exports match their files again.
"""

from pathlib import Path
import sys

import bpy

REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "blender/extensions"))
sys.dont_write_bytecode = True

import lauder_levels  # noqa: E402

arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
key = arguments[0] if arguments else "brooklyn-bridge"
if key not in lauder_levels.LEVELS:
    sys.exit(f"Unknown level {key!r}; the levels are {', '.join(lauder_levels.LEVELS)}.")
level = lauder_levels.LEVELS[key]
blend = REPOSITORY / level.blend
if lauder_levels.is_lfs_pointer(blend):
    sys.exit(f"{level.blend} is not downloaded yet: run git lfs pull.")
try:
    made_from = lauder_levels.open_level_file(str(REPOSITORY), key)
    lauder_levels.export_level(str(REPOSITORY), key, made_from)
except lauder_levels.LayoutError as error:
    sys.exit(f"The level was not exported: {error}")
print(f"Exported {level.layout} and {level.scene} from {level.blend}.")
