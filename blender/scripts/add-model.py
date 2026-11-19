"""Bring a model into Lauder from a file (ADR 0002): a Blender file, or a glTF, FBX, OBJ or USD
file that Blender imports.

Run it with Blender in the background, from any folder, with the file and a name for the model in
lowercase letters, digits and hyphens:

    blender -b --factory-startup --python-exit-code 1 --python blender/scripts/add-model.py -- taxi.glb taxi

It makes blender/assets/<name>, which it refuses to overwrite:

- <name>.blend, holding what the file shows, without its lights and cameras, in one collection
  named after the model, which levels link. From a Blender file, that is what its first scene
  shows, and each instance of a collection becomes copies of its parts, where it stands;
- textures/, a copy of every image the model uses, unpacked from the file if need be;
- README.md, whose Source and Licence lines are left for you to fill in, as CONTRIBUTING asks of
  every asset.

It then runs the intake check (check-model.py) and lists what must change before a level can use
the model, always including those two lines until they are filled in. Open the model in Blender to
look at it, and place it in a level with the Lauder tab's Add Model.
"""

from pathlib import Path
import sys

REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "blender/extensions"))
sys.dont_write_bytecode = True

import lauder_levels  # noqa: E402

arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(arguments) != 2:
    sys.exit("Give the file to bring in and a name for the model, such as: -- taxi.glb taxi")
source, name = arguments
try:
    problems, notes = lauder_levels.add_model(str(REPOSITORY), source, name)
except lauder_levels.LayoutError as error:
    sys.exit(f"The model was not added: {error}")
print(f"Added {lauder_levels.ASSETS}/{name}, from {Path(source).name}.")
print(lauder_levels.report_text(name, problems, notes))
