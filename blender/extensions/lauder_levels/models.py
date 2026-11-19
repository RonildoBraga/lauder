"""Models: the intake check, placing a model in a level, and bringing one in from a file."""

import datetime
import math
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path

from .common import (
    ADD_MODEL_SCRIPT, _and, ASSETS, bpy, _collection, forget_local_paths, _is, is_lfs_pointer,
    LayoutError, _library_path, Matrix, MODEL_NAME, model_of_path, name_clashes, Vector, VISUAL,
)
from .layouts import _number
from .looks import _looks, material_problems, texture_problems


#: The intake check's starting budgets for one model. They give notes, not refusals, until phone
#: measurements set real ones.
MOST_TRIANGLES = 10_000
MOST_TEXTURE_PIXELS = 2048
#: Beyond these sizes, in metres, a model was probably made in other units.
LARGEST_MODEL, SMALLEST_MODEL = 50, 0.05


def available_models(repository):
    """The models in blender/assets, by name."""
    folder = Path(repository) / ASSETS
    if not folder.is_dir():
        return []
    return sorted(item.name for item in folder.iterdir()
                  if MODEL_NAME.fullmatch(item.name) and (item / f"{item.name}.blend").is_file())


def provenance_problems(name, readme):
    """What the model's README.md lacks: where the model comes from and its licence, which
    CONTRIBUTING asks of every asset. add-model.py writes a question mark in each, to fill in."""
    place = f"{ASSETS}/{name}/README.md"
    if readme is None:
        return [f"{place} is missing: say there where the model comes from and its licence."]
    problems = []
    for field in ("Source", "Licence"):
        found = re.search(rf"^[ \t]*[-*][ \t]+\*\*{field}:\*\*[ \t]*(.*)$", readme, re.MULTILINE)
        if found is None or not found.group(1).strip() or found.group(1).startswith("?"):
            problems.append(f"{place} needs its **{field}:** line filled in.")
    return problems


@dataclass
class ModelShape:
    """What the intake check reads from a model's Blender file."""
    #: The model's name, from where its file is (model_of_path), or None.
    name: str
    #: The names of the file's own collections.
    collections: tuple = ()
    #: The names of everything in the model's collection, of its parts that have a shape, of its
    #: lights and cameras, and of its parts hidden from renders.
    names: tuple = ()
    shown: tuple = ()
    lights: tuple = ()
    hidden: tuple = ()
    #: Where the model reaches, in metres in Blender's axes: (minimum, maximum), each (x, y, z).
    bounds: tuple = None
    triangles: int = 0
    #: The scene's unit system and unit scale.
    units: tuple = ("METRIC", 1.0)
    materials: tuple = ()
    textures: tuple = ()
    #: The text of the model's README.md, or None.
    readme: str = None


def model_report(model):
    """The intake check (ADR 0006, decision 7): what must change before a level can use the model,
    and what is worth a look. Returns (problems, notes)."""
    if model.name is None:
        return [f"Keep a model as {ASSETS}/<name>/<name>.blend, its name in lowercase letters, "
                f"digits and hyphens."], []
    problems, notes = [], []
    if model.name not in model.collections:
        problems.append(f"The file needs a collection named {model.name}, holding the model: "
                        f"levels link it by that name.")
    elif not model.shown:
        problems.append(f"The {model.name} collection holds nothing with a shape.")
    if model.units[0] != "METRIC" or abs(model.units[1] - 1) > 1e-6:
        problems.append("Set the scene's Unit System to Metric, with a Unit Scale of 1: the game "
                        "counts in metres.")
    if model.lights:
        problems.append(f"Remove {_and(model.lights)}: a level's light comes from its own Lights, "
                        f"and the game drops a model's lights and cameras.")
    problems += material_problems(model.materials)
    problems += texture_problems(model.textures, f"{ASSETS}/{model.name}")
    problems += name_clashes(model.names, "parts")
    problems += provenance_problems(model.name, model.readme)
    if model.bounds is not None:
        low, high = model.bounds
        size = [b - a for a, b in zip(low, high)]
        notes.append(f"It measures {_number(size[0], 2)} m across, {_number(size[1], 2)} m long "
                     f"and {_number(size[2], 2)} m high.")
        if max(size) > LARGEST_MODEL or max(size) < SMALLEST_MODEL:
            notes.append("That is unusually large or small: check that it was made in metres. A "
                         "file made in centimetres comes in a hundred times too big.")
        if abs(low[2]) > 0.01:
            notes.append(f"Its lowest point is at a height of {_number(low[2], 2)} m, not 0. A "
                         f"model stands on the ground at its origin, so that it sits on what it "
                         f"is placed on.")
        offset = math.hypot((low[0] + high[0]) / 2, (low[1] + high[1]) / 2)
        if offset > 0.05:
            notes.append(f"Its middle is {_number(offset, 2)} m from its origin; centre it there, "
                         f"so that it turns about its middle.")
    if model.triangles > MOST_TRIANGLES:
        notes.append(f"It has {model.triangles:,} triangles, more than the starting budget of "
                     f"{MOST_TRIANGLES:,} for a model: check the phone's frame rate when levels "
                     f"use it.")
    if model.textures:
        notes.append("It uses textures, and the visual direction allows no new textures for now "
                     "(docs/visual-direction.md).")
        large = [texture.name for texture in model.textures
                 if max(texture.pixels) > MOST_TEXTURE_PIXELS]
        if large:
            notes.append(f"{_and(large)} {_is(large)} more than {MOST_TEXTURE_PIXELS} pixels on a "
                         f"side, the starting budget.")
    if model.hidden:
        notes.append(f"{_and(model.hidden)} {_is(model.hidden)} hidden from renders, so the game "
                     f"will not show {'it' if len(model.hidden) == 1 else 'them'}.")
    suffixed = [name for name in model.names if re.search(r"\.\d{3}$", name)]
    if suffixed:
        notes.append(f"{_and(suffixed)} {'has' if len(suffixed) == 1 else 'have'} Blender's "
                     f"duplicate suffix; give each a name of its own.")
    return problems, notes


def report_text(name, problems, notes):
    """The intake check's findings as lines to read."""
    count = f"{len(problems)} {'problem' if len(problems) == 1 else 'problems'}"
    lines = [f"{name}: {count} to fix before a level can use it." if problems
             else f"{name} is ready for levels to use."]
    lines += [f"- {problem}" for problem in problems]
    if notes:
        lines += ["Worth a look:"] + [f"- {note}" for note in notes]
    return "\n".join(lines)


def _model_file_of(item):
    """The model file whose collection the object shows, or None."""
    collection = item.instance_collection if item is not None else None
    if item is None or item.instance_type != "COLLECTION" or collection is None:
        return None
    return _library_path(collection.library) if collection.library is not None else None


#: The kinds of object with a shape that a scene file shows.
SHAPED = ("MESH", "CURVE", "SURFACE", "META", "FONT")


def _reach(objects):
    """Where these objects reach, from their shapes as Blender evaluates them: (minimum, maximum),
    each (x, y, z), or None."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    corners = []
    for item in objects:
        evaluated = item.evaluated_get(depsgraph)
        corners += [evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box]
    if not corners:
        return None
    return (tuple(min(corner[axis] for corner in corners) for axis in range(3)),
            tuple(max(corner[axis] for corner in corners) for axis in range(3)))


def model_from_blender(repository):
    """What the intake check reads from the open model file (ModelShape)."""
    root = Path(repository)
    name = model_of_path(root, bpy.data.filepath)
    if name is None:
        return ModelShape(None)
    own = [collection for collection in bpy.data.collections if collection.library is None]
    collection = next((each for each in own if each.name == name), None)
    members = list(collection.all_objects) if collection is not None else []
    shaped = [item for item in members if item.type in SHAPED]
    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    for item in shaped:
        evaluated = item.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        if mesh is not None:
            triangles += sum(len(polygon.vertices) - 2 for polygon in mesh.polygons)
        evaluated.to_mesh_clear()
    materials, textures = _looks(shaped, root)
    readme = root / ASSETS / name / "README.md"
    units = bpy.context.scene.unit_settings
    return ModelShape(
        name, tuple(each.name for each in own), tuple(item.name for item in members),
        tuple(item.name for item in shaped),
        tuple(item.name for item in members if item.type in ("LIGHT", "CAMERA")),
        tuple(item.name for item in members if item.hide_render), _reach(shaped), triangles,
        (units.system, units.scale_length), tuple(materials), tuple(textures),
        readme.read_text() if readme.is_file() else None)


def check_model(repository):
    """The intake check of the open model file: (problems, notes)."""
    return model_report(model_from_blender(repository))


def place_model(repository, name, box=None, cursor=(0, 0, 0)):
    """Link the model into the open level's Visual collection and return its new instance. With a
    box, the model stands on the box's base, turned along its longer side, and is parented to it,
    so that it moves with the box; otherwise it stands at the cursor."""
    path = Path(repository) / ASSETS / name / f"{name}.blend"
    visual = _collection(VISUAL)
    if visual is None:
        raise LayoutError("This Blender file has no Visual collection; open the level's own file.")
    if not path.is_file() or is_lfs_pointer(path):
        raise LayoutError(f"{ASSETS}/{name}/{name}.blend is missing or not downloaded yet: run "
                          f"git lfs pull.")
    with bpy.data.libraries.load(bpy.path.relpath(str(path)), link=True,
                                 relative=True) as (available, wanted):
        if name not in available.collections:
            raise LayoutError(f"{ASSETS}/{name}/{name}.blend has no collection named {name}: "
                              f"check the model.")
        wanted.collections = [name]
    model = wanted.collections[0]
    holder = bpy.data.objects.new(f"{box.name} model" if box is not None else name, None)
    holder.instance_type = "COLLECTION"
    holder.instance_collection = model
    visual.objects.link(holder)
    if box is None:
        holder.location = cursor
        return holder
    bpy.context.view_layer.update()
    low, high = _reach([box])
    parts = _reach([item for item in model.all_objects if item.type in SHAPED])
    turn = 0.0
    if parts is not None:
        box_across = high[0] - low[0] > high[1] - low[1]
        model_across = parts[1][0] - parts[0][0] > parts[1][1] - parts[0][1]
        turn = math.pi / 2 if box_across != model_across else 0.0
    holder.parent = box
    holder.matrix_parent_inverse = box.matrix_world.inverted()
    holder.matrix_world = (Matrix.Translation(((low[0] + high[0]) / 2, (low[1] + high[1]) / 2,
                                               low[2])) @ Matrix.Rotation(turn, 4, "Z"))
    return holder


#: How Blender reads each kind of file that add-model.py takes besides its own.
IMPORTERS = {
    ".glb": "import_scene.gltf", ".gltf": "import_scene.gltf", ".fbx": "import_scene.fbx",
    ".obj": "wm.obj_import", ".usd": "wm.usd_import", ".usda": "wm.usd_import",
    ".usdc": "wm.usd_import", ".usdz": "wm.usd_import",
}
#: The file extension for each image format Blender may have unpacked.
_IMAGE_SUFFIXES = {"PNG": ".png", "JPEG": ".jpg", "OPEN_EXR": ".exr", "HDR": ".hdr",
                   "TIFF": ".tif", "TARGA": ".tga", "BMP": ".bmp", "WEBP": ".webp"}


def _copy_textures(folder):
    """Copy every image file that the open model file uses into the model's textures folder,
    unpacking packed ones, and point each image at its copy, relative to the model's file."""
    textures, taken = folder / "textures", set()
    for image in bpy.data.images:
        if image.source != "FILE" or image.library is not None:
            continue
        original = Path(bpy.path.abspath(image.filepath)) if image.filepath else None
        suffix = (original.suffix.lower() if original is not None and original.suffix
                  else _IMAGE_SUFFIXES.get(image.file_format, ".png"))
        stem = re.sub(r"[^a-z0-9]+", "-", Path(image.name).stem.lower()).strip("-") or "texture"
        file_name, number = stem + suffix, 2
        while file_name in taken:
            file_name, number = f"{stem}-{number}{suffix}", number + 1
        target = textures / file_name
        if image.packed_file is not None:
            textures.mkdir(exist_ok=True)
            target.write_bytes(image.packed_file.data)
            image.filepath = bpy.path.relpath(str(target))
            image.unpack(method="REMOVE")
        elif original is not None and original.is_file():
            textures.mkdir(exist_ok=True)
            shutil.copyfile(original, target)
            image.filepath = bpy.path.relpath(str(target))
        else:
            continue  # Missing: the intake check says so.
        taken.add(file_name)
        image.reload()


def _realize_instances(collection):
    """Turn each of the collection's instances of other collections into copies of the parts it
    shows, where they stand, sharing their meshes and named after the instance, so that a model is
    one collection of its own parts. Instances within instances take further rounds."""
    for _ in range(8):
        holders = [item for item in collection.objects
                   if item.instance_type == "COLLECTION" and item.instance_collection is not None]
        if not holders:
            return
        for item in bpy.context.selected_objects:
            item.select_set(False)
        for holder in holders:
            holder.select_set(True)
        bpy.context.view_layer.objects.active = holders[0]
        before = set(bpy.data.objects)
        # Each copy comes parented to the instance that showed it, which names it.
        bpy.ops.object.duplicates_make_real(use_base_parent=True)
        for made in set(bpy.data.objects) - before:
            holder, place = made.parent, made.matrix_world.copy()
            made.parent = None
            made.matrix_world = place
            part = re.sub(r"[.]\d{3}$", "", made.name)
            made.name = f"{holder.name} {part}" if holder is not None else part
        for holder in holders:
            bpy.data.objects.remove(holder, do_unlink=True)
    raise LayoutError("The file's instances nest too deeply to bring in; make them real first, "
                      "with Object › Apply › Make Instances Real.")


def _readme_template(name, source, model):
    """A model's README.md as add-model.py writes it, with its source and licence to fill in."""
    today = datetime.date.today()
    size = ""
    if model.bounds is not None:
        low, high = model.bounds
        size = " by ".join(_number(b - a, 2) for a, b in zip(low, high)) + " m, "
    count = len(model.textures)
    textures = (f", with {count} {'texture' if count == 1 else 'textures'}" if count
                else ", without textures")
    return "\n".join([
        f"# {name}", "",
        f"Brought into Lauder from `{source}` on {today.day} {today:%B %Y}, with "
        f"`{ADD_MODEL_SCRIPT}`.", "",
        "- **Source:** ? Where it comes from, such as a link, and who made it.",
        "- **Licence:** ? Its licence, and any attribution that the licence asks for.",
        f"- **Size:** {size}{model.triangles:,} triangles{textures}.", "",
    ])


def add_model(repository, source, name):
    """Make the model blender/assets/<name> from a file: what a Blender file's first scene shows,
    or what Blender imports from a glTF, FBX, OBJ or USD file, in a collection named after the
    model, with its textures copied beside it and a README.md whose source and licence are to fill
    in. Returns the intake check's findings, (problems, notes). It replaces the open file, so it
    runs in a Blender of its own: blender/scripts/add-model.py."""
    root = Path(repository)
    source = Path(source).resolve()
    kind = source.suffix.lower()
    folder = root / ASSETS / name
    if not MODEL_NAME.fullmatch(name):
        raise LayoutError(f"Name the model in lowercase letters, digits and hyphens, not {name!r}.")
    if folder.exists():
        raise LayoutError(f"{ASSETS}/{name} already exists; choose another name.")
    if not source.is_file():
        raise LayoutError(f"There is no file {source.name} to bring in.")
    if kind != ".blend" and kind not in IMPORTERS:
        raise LayoutError(f"Blender cannot bring in {source.suffix or 'such'} files here: use a "
                          f"Blender, glTF, FBX, OBJ or USD file.")
    bpy.ops.wm.read_homefile(use_empty=True)
    folder.mkdir(parents=True)
    # Saved first, so that // means the model's folder.
    bpy.ops.wm.save_as_mainfile(filepath=str(folder / f"{name}.blend"))
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    layers = bpy.context.view_layer.layer_collection.children
    bpy.context.view_layer.active_layer_collection = layers[collection.name]
    # What the file shows: for a Blender file, what its first scene's view layer shows, which
    # leaves out collections excluded from it, such as an instance's source.
    if kind == ".blend":
        with bpy.data.libraries.load(str(source), link=False) as (available, wanted):
            wanted.scenes = available.scenes[:1]
        if not wanted.scenes or wanted.scenes[0] is None:
            raise LayoutError(f"{source.name} has no scene to bring in.")
        layer = wanted.scenes[0].view_layers[0]
    else:
        group, operator = IMPORTERS[kind].split(".")
        getattr(getattr(bpy.ops, group), operator)(filepath=str(source))
        layer = bpy.context.view_layer
    layer.update()
    for item in list(layer.objects):
        if collection not in item.users_collection:
            collection.objects.link(item)
    _realize_instances(collection)
    # Lights and cameras would not reach the game, and empties holding nothing, such as the one a
    # USD file's material scope becomes, show nothing.
    for item in list(collection.objects):
        if item.type in ("LIGHT", "CAMERA") or (
                item.type == "EMPTY" and not item.children and item.instance_collection is None):
            bpy.data.objects.remove(item, do_unlink=True)
    # Only the model's collection holds anything now, in the file's one scene.
    for scene in [each for each in bpy.data.scenes if each != bpy.context.scene]:
        bpy.data.scenes.remove(scene)
    for item in collection.objects:
        for other in list(item.users_collection):
            if other is not collection:
                other.objects.unlink(item)
    for other in [each for each in bpy.data.collections if each is not collection]:
        bpy.data.collections.remove(other)
    for item in [each for each in bpy.data.objects if not each.users_collection]:
        bpy.data.objects.remove(item)
    _copy_textures(folder)
    forget_local_paths()
    bpy.ops.wm.save_mainfile(relative_remap=True)
    # The first save's copy, which Blender keeps as a backup, is not part of the model.
    (folder / f"{name}.blend1").unlink(missing_ok=True)
    (folder / "README.md").write_text(_readme_template(name, source.name,
                                                       model_from_blender(repository)))
    return check_model(repository)
