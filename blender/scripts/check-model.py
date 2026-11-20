"""Check a Lauder model against what the levels and the game need: the intake check (ADR 0002).

Run it with Blender in the background, from any folder, naming a model in blender/assets:

    blender -b --factory-startup --python-exit-code 1 --python blender/scripts/check-model.py -- miki

It lists what must change before a level can use the model, such as materials that the game cannot
show, textures that are not image files in the model's folder, or a README.md without the model's
source and licence, and then what is worth a look, such as the model's size and triangles. It exits
with 1 while anything must change. In Blender, the Lauder tab's Check Model does the same for the
open model.
"""

from pathlib import Path
import sys

import bpy

REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "blender/extensions"))
sys.dont_write_bytecode = True

import lauder_levels  # noqa: E402

arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(arguments) != 1:
    sys.exit("Name the model to check, such as: -- miki")
name = arguments[0]
place = lauder_levels.model_file(name)
path = REPOSITORY / place
if not path.is_file():
    models = lauder_levels.available_models(REPOSITORY)
    sys.exit(f"There is no {place}. The models are: {', '.join(models) or 'none yet'}.")
if lauder_levels.is_lfs_pointer(path):
    sys.exit(f"{place} is not downloaded yet: run git lfs pull.")
bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False)
problems, notes = lauder_levels.check_model(str(REPOSITORY))
print(lauder_levels.report_text(name, problems, notes))
sys.exit(1 if problems else 0)
