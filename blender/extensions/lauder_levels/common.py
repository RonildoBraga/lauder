"""What every part of the extension shares: the levels and the repository's paths, the collections'
names, names as USD writes them, the game's coordinates and colours, files' fingerprints, and
keeping a saved file free of local paths."""

import hashlib
import math
import re
from dataclasses import dataclass
from pathlib import Path

try:
    import bpy
    from bpy.app.handlers import persistent
    from mathutils import Matrix, Vector
except ImportError:  # Outside Blender: the tests use the plain functions.
    bpy = persistent = Matrix = Vector = None


@dataclass(frozen=True)
class LevelFile:
    key: str
    title: str
    #: The level's Blender file, relative to the repository: the level's source.
    blend: str
    #: The layout file that Export writes, relative to the repository.
    layout: str
    #: The Swift type whose `layout` the layout file defines.
    owner: str
    #: The level's own Swift file, with its words. The layout's names it uses must stay.
    story: str
    #: The scene file that Export writes, relative to the repository.
    scene: str


LEVELS = {
    "brooklyn-bridge": LevelFile(
        key="brooklyn-bridge",
        title="Brooklyn Bridge",
        blend="blender/levels/brooklyn-bridge.blend",
        layout="apple/sources/content/BrooklynBridgeLayout.swift",
        owner="BrooklynBridge",
        story="apple/sources/content/BrooklynBridge.swift",
        scene="apple/sources/content/BrooklynBridge.usdz",
    ),
}

#: The level file's collections (see above).
VISUAL, GAMEPLAY, LIGHTS, CAMERA, PREVIEW = "Visual", "Gameplay", "Lights", "Camera", "Preview"
#: What a gameplay object can be, in its `lauder_role` property. Without one, a mesh is a box and
#: an empty is a marker.
ROLES = ("ground", "box", "area", "marker")

#: Where the models are, relative to the repository: blender/assets/<model>/<model>.blend.
ASSETS = "blender/assets"
#: A model's name, which is also its folder's, its file's and its collection's.
MODEL_NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
#: The models that the game creates itself while it plays, rather than a level placing them: the
#: party and the hostiles (ADR 0002). Each gets a scene file of its own in
#: SPAWNED_SCENES, named after it, which the game loads by the model's name.
SPAWNED = ("hostile", "laura", "miki", "spider-bot-heavy", "tom")
SPAWNED_SCENES = "apple/sources/content/models"
#: Typed model metadata. Miki owns the one shared party clip table; the robot owns its geometry.
MODEL_METADATA = {
    "miki": "apple/sources/content/PartyModelClips.swift",
    "spider-bot-heavy": "apple/sources/content/RobotModelGeometry.swift",
}

#: The script that builds the game and opens it in the iOS Simulator.
PLAY_SCRIPT = "apple/scripts/play"
#: The scripts that export a level, and a model that the game creates, in a Blender of its own.
EXPORT_SCRIPT = "blender/scripts/export-level.py"
EXPORT_MODEL_SCRIPT = "blender/scripts/export-model.py"
#: The script that brings a model in from a file.
ADD_MODEL_SCRIPT = "blender/scripts/add-model.py"
#: Where each export records what it was made from and what it wrote, relative to the repository.
EXPORT_RECORD = "blender/level-exports.json"
#: Raised whenever Export changes what it writes, so that every level is exported again.
EXPORT_FORMAT = 1


class LayoutError(Exception):
    """A level the game cannot use. The message says what to fix."""


def from_blender(point):
    """A Blender point (x, y, z), z up, in the game's space, y up."""
    x, y, z = point
    return (x, z, -y)


def _srgb(linear):
    """Scene-linear RGB as sRGB, each channel from 0 to 1."""
    def channel(value):
        value = min(max(value, 0.0), 1.0)
        return value * 12.92 if value <= 0.0031308 else 1.055 * value ** (1 / 2.4) - 0.055
    return tuple(channel(value) for value in linear[:3])


def _unit(vector):
    length = math.sqrt(sum(value * value for value in vector)) or 1.0
    return tuple(value / length for value in vector)


_LFS_POINTER = b"version https://git-lfs.github.com/spec/v1"
#: The suffix Blender gives a duplicate's name, such as `.001`.
DUPLICATE_SUFFIX = re.compile(r"\.\d{3}$")


def file_fingerprint(path):
    """A file's SHA-256, in hex. A Git LFS pointer stands for its file, so it gives the file's."""
    data = Path(path).read_bytes()
    if data.startswith(_LFS_POINTER):
        found = re.search(rb"oid sha256:([0-9a-f]{64})", data)
        if found:
            return found.group(1).decode()
    return hashlib.sha256(data).hexdigest()


def is_lfs_pointer(path):
    """Whether the file is a Git LFS pointer, not yet downloaded with git lfs pull."""
    with Path(path).open("rb") as stream:
        return stream.read(len(_LFS_POINTER)) == _LFS_POINTER


def model_file(name):
    """A model's Blender file, relative to the repository."""
    return f"{ASSETS}/{name}/{name}.blend"


def _and(items):
    """Names in a sentence: "a", "a and b", "a, b and c"."""
    items = list(items)
    return items[0] if len(items) == 1 else ", ".join(items[:-1]) + " and " + items[-1]


def usd_name(name):
    """The name a Blender name has in USD, which allows only letters, digits and underscores and
    no digit first: Blender's USD export replaces every other byte with an underscore, so
    `tower-top brooklyn` becomes `tower_top_brooklyn`."""
    letters = "".join(chr(byte) if chr(byte).isascii() and (chr(byte).isalnum() or byte == 95)
                      else "_" for byte in name.encode()) or "_"
    return "_" + letters[1:] if letters[0].isdigit() else letters


def name_clashes(names, what):
    """Problems for names that USD would make the same (usd_name)."""
    found = {}
    for name in names:
        found.setdefault(usd_name(name), []).append(name)
    return [f"The {what} {_and(sorted(same))} would all be {key} in the scene file: give each a "
            f"name of its own." for key, same in sorted(found.items()) if len(same) > 1]


def model_of_path(repository, path):
    """The model whose Blender file this is, blender/assets/<model>/<model>.blend, or None."""
    if not path:
        return None
    try:
        parts = Path(path).resolve().relative_to(Path(repository).resolve()).parts
    except ValueError:
        return None
    if (len(parts) == 4 and "/".join(parts[:2]) == ASSETS and MODEL_NAME.fullmatch(parts[2])
            and parts[3] == f"{parts[2]}.blend"):
        return parts[2]
    return None


def _is(names):
    return "is" if len(names) == 1 else "are"


def level_of_file(path):
    """The repository and level whose Blender file this is, or None."""
    if not path:
        return None
    path = Path(path).resolve()
    if len(path.parents) < 3:
        return None
    repository = path.parents[2]
    for level in LEVELS.values():
        if (repository / level.blend).resolve() == path:
            return str(repository), level
    return None


def model_of_file(path):
    """The repository and model whose Blender file this is, or None."""
    if not path:
        return None
    path = Path(path).resolve()
    if len(path.parents) < 4:
        return None
    name = model_of_path(path.parents[3], path)
    return (str(path.parents[3]), name) if name else None


def _collection(name):
    return bpy.data.collections.get(name)


def _relative(path, root):
    """A path relative to the repository, or as it is when outside it."""
    try:
        return str(Path(path).resolve().relative_to(Path(root).resolve()))
    except ValueError:
        return str(path)


def _library_path(library):
    """Where a linked Blender file is, resolved from the file that links it."""
    return Path(bpy.path.abspath(library.filepath, library=library.parent)).resolve()


def _overwrite(owner, attribute, value):
    """Set text that Blender keeps in a buffer of fixed size, filling the whole buffer first.
    Blender saves a buffer's bytes beyond the end of its text, so a shorter text alone would keep
    the tail of the one before it, such as the end of a home folder's path."""
    filler = "_" * 1100  # Longer than any such buffer, which keeps what fits.
    if isinstance(getattr(owner, attribute), bytes):
        filler, value = filler.encode(), value.encode()
    setattr(owner, attribute, filler)
    setattr(owner, attribute, value)


def forget_local_paths(path=None):
    """Keep a level's or model's file in the public repository free of paths from the computer it
    was saved on, at `path` or where it is:

    - point Blender's file browsers, which start in the home folder, at the file's own folder;
    - drop the Repository folder that the Lauder tab stores on a scene, since an open level finds
      its repository from where it is;
    - hold linked models and textures relative to the file, as Blender's Relative Path does;
    - forget where appended data came from, which Blender keeps to reuse it when appending again.

    Each is overwritten in full (_overwrite): even when Blender makes a path relative itself, it
    shortens the full path in place, and the rest of the full path stays behind it."""
    for screen in bpy.data.screens:
        for area in screen.areas:
            for space in area.spaces:
                params = getattr(space, "params", None)
                if params is not None and hasattr(params, "directory"):
                    _overwrite(params, "directory", "//")
                    _overwrite(params, "filename", "")
    for scene in bpy.data.scenes:
        try:
            scene.property_unset("lauder_repository")
        except TypeError:
            pass  # The extension's settings are not registered in this Blender.
    start = str(Path(path or bpy.data.filepath).parent)
    # An image's raw path changes without reloading it, which would lose unsaved painting.
    held = [(item, "filepath") for item in bpy.data.libraries if item.parent is None]
    held += [(image, "filepath_raw") for image in bpy.data.images
             if image.library is None and image.source == "FILE" and image.packed_file is None]
    for item, attribute in held:
        if item.filepath:
            _overwrite(item, attribute,
                       bpy.path.relpath(bpy.path.abspath(item.filepath), start=start))
    for name in dir(bpy.data):
        collection = getattr(bpy.data, name, None)
        if not isinstance(collection, bpy.types.bpy_prop_collection):
            continue
        for item in collection:
            reference = getattr(item, "library_weak_reference", None)
            if reference is not None and item.library is None:
                _overwrite(reference, "filepath", "")
                _overwrite(reference, "id_name", "")
