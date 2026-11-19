"""Export a Lauder level's scene file (ADR 0006): everything the game shows of the level, built
from its layout file and the shared palette and exported as USD for the game to load.

Run it with Blender in the background, from any folder:

    blender -b --factory-startup --python-exit-code 1 --python blender/scripts/export-scene.py -- [level]

The level defaults to brooklyn-bridge. The Lauder extension's Save and Play run this by themselves
whenever the scene file no longer matches the level's files. Run it by hand after editing a layout
file or the palette outside Blender: ./scripts/check fails until the scene file matches again.
"""

from pathlib import Path
import sys

REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "blender/extensions"))
sys.dont_write_bytecode = True

import lauder_levels  # noqa: E402

arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
key = arguments[0] if arguments else "brooklyn-bridge"
if key not in lauder_levels.LEVELS:
    sys.exit(f"Unknown level {key!r}; the levels are {', '.join(lauder_levels.LEVELS)}.")
try:
    path = lauder_levels.export_scene(str(REPOSITORY), key)
except lauder_levels.LayoutError as error:
    sys.exit(f"The scene file was not exported: {error}")
print(f"Exported {path.relative_to(REPOSITORY)}.")
