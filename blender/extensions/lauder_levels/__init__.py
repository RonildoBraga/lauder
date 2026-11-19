"""Lauder's levels and models in Blender (ADR 0006), as a Blender extension.

Each level is a Blender file in the repository, blender/levels/<level>.blend, stored with Git LFS:
the level's source. Its collections decide where each object goes:

- Visual: everything the player sees. Export writes it to the level's scene file, a USDZ that the
  game loads. A model appears in it as an instance of the model's collection, linked from the
  model's own file.
- Gameplay: the ground, the boxes that block movement and sight, the landmarks, the trigger and
  fight areas, and the markers where people start and stand, each with its role. Export writes
  them to the level's layout file, typed Swift that the game compiles. They show as outlines, and
  the game never draws them. A visual part or model parented to a gameplay box moves with it.
- Lights and Camera: the level's sun lights and the game camera's rig, written to the layout file
  too.
- Preview: the party's stand-ins at their start markers, which the game draws itself. It is never
  exported.

Each model is a Blender file of its own, blender/assets/<model>/<model>.blend, also stored with
Git LFS. It holds one collection named after the model, at its real size in metres and standing on
the ground at its origin. Beside it are a README.md, which says where the model comes from and
under which licence, and any textures it uses. Levels link the model, so a change to it reaches
every level that uses it: saving a model exports the levels whose last export used it. The intake
check, Check Model or blender/scripts/check-model.py, says what a model needs before a level can
use it. blender/scripts/add-model.py brings a model in from a Blender, glTF, FBX, OBJ or USD file.

Install it once: in Blender's Preferences, add a local extension repository at this repository's
blender/extensions folder, then enable Lauder levels. A Lauder tab appears in the 3D Viewport's
sidebar (press N). Open Level opens the level's Blender file. Add Model places a model in it, and
Open Model opens the selected model's own file. Saving a level checks the game's rules, then
exports in a Blender of its own, in the background, with blender/scripts/export-level.py, which
agents run too. Play saves, exports when needed, then builds the game and opens it in the iOS
Simulator through apple/scripts/play. blender/level-exports.json records what each export was made
from and what it wrote, and ./scripts/check fails when they no longer match.

Writing and checking a layout, and the intake check's rules, need no Blender:
blender/test_lauder_levels.py runs those parts in ./scripts/check. Coordinates in the layout file
are the game's, in metres: x across, y up and z along the level. In Blender, z is up, so a game
point (x, y, z) sits at (x, -z, y).
"""

from dataclasses import dataclass, field
import datetime
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap

try:
    import bpy
    from bpy.app.handlers import persistent
    from mathutils import Matrix, Vector
except ImportError:  # Outside Blender: the tests use the plain functions below.
    bpy = None


# MARK: - Levels


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
ROLES = ("ground", "box", "landmark", "area", "marker")

#: Where the models are, relative to the repository: blender/assets/<model>/<model>.blend.
ASSETS = "blender/assets"
#: A model's name, which is also its folder's, its file's and its collection's.
MODEL_NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")

#: The script that builds the game and opens it in the iOS Simulator.
PLAY_SCRIPT = "apple/scripts/play"
#: The script that exports a level in a Blender of its own.
EXPORT_SCRIPT = "blender/scripts/export-level.py"
#: The scripts that check a model, and that bring one in from a file.
CHECK_MODEL_SCRIPT = "blender/scripts/check-model.py"
ADD_MODEL_SCRIPT = "blender/scripts/add-model.py"
#: Where each export records what it was made from and what it wrote, relative to the repository.
EXPORT_RECORD = "blender/level-exports.json"
#: Raised whenever Export changes what it writes, so that every level is exported again.
EXPORT_FORMAT = 1

#: The visual direction's budget (docs/visual-direction.md).
MOST_LIGHTS = 2
MOST_SHADOWED_LIGHTS = 1
#: The shadow distance a light gets when its shadow is turned on in Blender.
DEFAULT_SHADOW_DISTANCE = 25
#: Blender's sun strength, in W/m², for each lux of a game light. Blender and RealityKit render
#: differently, so this only brings Blender's preview close; the game shows the real result.
SUN_STRENGTH_PER_LUX = 1 / 700
#: How far from the origin the layout file puts a light's source. Only its direction matters.
SOURCE_LENGTH = 10


# MARK: - Layouts, in the game's coordinates


@dataclass
class Box:
    name: str
    #: The centre, (x, y, z).
    position: tuple
    size: tuple


@dataclass
class Landmark:
    name: str
    #: The centre of the base, on the floor.
    position: tuple
    size: tuple


@dataclass
class Area:
    name: str
    #: The corners on the floor, (x, z).
    minimum: tuple
    maximum: tuple


@dataclass
class Marker:
    name: str
    #: A point on the floor, (x, z).
    position: tuple


@dataclass
class Camera:
    #: From the camera's target to the camera, (x, y, z).
    offset: tuple
    #: The vertical field of view, in degrees.
    field_of_view: float


@dataclass
class Light:
    """A light as far away as the sun, shining from one direction over the whole level."""
    name: str
    #: A point in the direction the light comes from, (x, y, z); only the direction matters.
    source: tuple
    #: In sRGB, each channel from 0 to 1.
    color: tuple
    #: In lux.
    intensity: float
    #: How far from the camera its shadows reach, in metres, or None when it casts none.
    shadow_distance: float = None


@dataclass
class Layout:
    ground: Box
    boxes: list
    landmarks: list
    areas: list
    markers: list
    camera: Camera = None
    lights: list = field(default_factory=list)


class LayoutError(Exception):
    """A level the game cannot use. The message says what to fix."""


def to_blender(point):
    """A game point (x, y, z) in Blender's z-up space."""
    x, y, z = point
    return (x, -z, y)


def from_blender(point):
    x, y, z = point
    return (x, z, -y)


def size_to_blender(size):
    x, y, z = size
    return (x, z, y)


def _linear(red, green, blue):
    """sRGB as scene-linear RGB."""
    def channel(value):
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
    return (channel(red), channel(green), channel(blue))


def _srgb(linear):
    """Scene-linear RGB as sRGB, each channel from 0 to 1."""
    def channel(value):
        value = min(max(value, 0.0), 1.0)
        return value * 12.92 if value <= 0.0031308 else 1.055 * value ** (1 / 2.4) - 0.055
    return tuple(channel(value) for value in linear[:3])


def _unit(vector):
    length = math.sqrt(sum(value * value for value in vector)) or 1.0
    return tuple(value / length for value in vector)


# MARK: - Checking a layout


def _check_names(layout):
    problems = []
    for kind, items in (
        ("box", [layout.ground] + layout.boxes), ("landmark", layout.landmarks),
        ("area", layout.areas), ("marker", layout.markers), ("light", layout.lights),
    ):
        seen = set()
        for item in items:
            if item.name in seen:
                plural = "boxes" if kind == "box" else kind + "s"
                problems.append(f"Two {plural} are named {item.name}.")
            seen.add(item.name)
            if re.search(r"\.\d{3}$", item.name):
                problems.append(
                    f"{item.name} has Blender's duplicate suffix; give it a name of its own.")
    if layout.camera is None:
        problems.append("The level needs its game camera.")
    elif not 10 <= layout.camera.field_of_view <= 120:
        problems.append("The camera's field of view should be between 10 and 120 degrees.")
    problems += _light_problems(layout.lights)
    if problems:
        raise LayoutError(" ".join(problems))


def _light_problems(lights):
    """The visual direction's budget for lights, and lights the game can use."""
    problems = []
    if not lights:
        problems.append("The level needs a light.")
    if len(lights) > MOST_LIGHTS:
        problems.append(
            f"The visual direction allows at most {MOST_LIGHTS} lights, not {len(lights)}.")
    shadowed = [light.name for light in lights if light.shadow_distance is not None]
    if len(shadowed) > MOST_SHADOWED_LIGHTS:
        problems.append(
            f"The visual direction allows {MOST_SHADOWED_LIGHTS} light with shadows, but "
            f"{len(shadowed)} cast them: {', '.join(shadowed)}.")
    for light in lights:
        if light.intensity <= 0:
            problems.append(f"{light.name} needs some intensity.")
        if any(not 0 <= value <= 1 for value in light.color):
            problems.append(f"{light.name}'s colour channels should be between 0 and 1.")
        if light.shadow_distance is not None and light.shadow_distance <= 0:
            problems.append(f"{light.name}'s shadow distance should be more than 0.")
        if all(abs(value) < 1e-6 for value in light.source):
            problems.append(f"{light.name} needs a direction to shine from.")
    return problems


# MARK: - Writing a layout file

_WIDTH = 100


def _number(value, places=3):
    text = f"{round(value, places):.{places}f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def _list(values, places=3):
    return "[" + ", ".join(_number(value, places) for value in values) + "]"


def _call(indent, head, arguments, tail):
    """One call on one line if it fits, otherwise wrapped and filled as swift format does."""
    line = f"{indent}{head}({', '.join(arguments)}){tail}"
    # swift format wraps a one-line call followed by a comma once it passes 98 columns.
    if len(line) <= _WIDTH - (2 if tail == "," else 0):
        return [line]
    inner = indent + "  "
    pieces = [argument + "," for argument in arguments[:-1]] + [arguments[-1] + ")" + tail]
    lines = [f"{indent}{head}("]
    current = ""
    for piece in pieces:
        candidate = f"{current} {piece}" if current else piece
        if current and len(inner + candidate) > _WIDTH:
            lines.append(inner + current)
            current = piece
        else:
            current = candidate
    lines.append(inner + current)
    return lines


def _box_arguments(box):
    return [f'"{box.name}"', f"at: {_list(box.position)}", f"size: {_list(box.size)}"]


def _light_arguments(light):
    arguments = [f'"{light.name}"', f"from: {_list(light.source)}", f"color: {_list(light.color)}",
                 f"intensity: {_number(light.intensity)}"]
    if light.shadow_distance is not None:
        arguments.append(f"shadowDistance: {_number(light.shadow_distance)}")
    return arguments


def layout_header(level):
    """The layout file's opening comment: what it is, and that Blender writes it."""
    text = (
        f"Generated by the Lauder extension from {level.blend} (ADR 0006): where everything that "
        "plays on the level stands, and how it is lit, in metres, with x across, y up and z along "
        f"the level. Do not edit it here: change the level in Blender and save, or run "
        f"{EXPORT_SCRIPT}. ./scripts/check fails while this file no longer matches the Blender "
        "file."
    )
    return tuple("// " + line for line in textwrap.wrap(text, _WIDTH - 3))


def emit_layout(layout, level):
    """The layout file's text, the same every time for the same layout."""
    _check_names(layout)
    lines = list(layout_header(level)) + [
        "",
        f"extension {level.owner} {{",
        "  static let layout = Level.Layout(",
    ]
    lines += _call("    ", "ground: .box", _box_arguments(layout.ground), ",")
    sections = (
        ("boxes", [(".box", _box_arguments(box)) for box in layout.boxes]),
        ("landmarks", [
            (".landmark", [f'"{item.name}"', f"at: {_list(item.position)}",
                           f"size: {_list(item.size)}"])
            for item in layout.landmarks
        ]),
        ("areas", [
            (".area", [f'"{item.name}"', f"from: {_list(item.minimum)}",
                       f"to: {_list(item.maximum)}"])
            for item in layout.areas
        ]),
        ("markers", [
            (".marker", [f'"{item.name}"', f"at: {_list(item.position)}"])
            for item in layout.markers
        ]),
    )
    for section, calls in sections:
        if not calls:
            lines.append(f"    {section}: [],")
            continue
        lines.append(f"    {section}: [")
        for head, arguments in calls:
            lines += _call("      ", head, arguments, ",")
        lines.append("    ],")
    camera = layout.camera
    lines += _call(
        "    ", "camera: .camera",
        [f"offset: {_list(camera.offset)}", f"fieldOfView: {_number(camera.field_of_view)}"], ",")
    lines.append("    lights: [")
    for light in layout.lights:
        lines += _call("      ", ".sun", _light_arguments(light), ",")
    lines += ["    ])", "}"]
    return "\n".join(lines) + "\n"


# MARK: - Reading what Blender holds


@dataclass
class Shape:
    """What Export reads from one gameplay object, in Blender's coordinates."""
    name: str
    #: ground, box, landmark, area or marker.
    role: str
    #: The object's world bounding box; for a marker, its location twice.
    minimum: tuple
    maximum: tuple
    #: Turned only in quarter turns about the vertical, and not mirrored.
    square: bool = True
    #: The mesh is still a box.
    cuboid: bool = True


@dataclass
class CameraShape:
    """The game camera as Blender holds it: from its target to the camera, and its field of
    view in degrees."""
    offset: tuple
    field_of_view: float


@dataclass
class LightShape:
    """What Export reads from one Blender light."""
    name: str
    #: Blender's kind of light: SUN, POINT, SPOT or AREA.
    kind: str
    #: Where the light comes from, as a unit vector in Blender's space: the sun's own +z.
    direction: tuple
    #: Scene-linear RGB, as Blender holds it.
    color: tuple
    #: Blender's strength, in W/m² for a sun.
    energy: float
    shadow: bool
    #: The shadow distance kept on the light, if it has one.
    shadow_distance: float = None


_TOLERANCE = 0.005
#: A layout file's entries, as Export writes them: (kind, name).
_ENTRY_NAME = re.compile(r'\.(box|landmark|area|marker)\(\s*"([^"]+)"')


def required_names(layout_text, story_text):
    """The names in the layout file that the level's Swift file uses, as (kind, name): Export
    refuses to drop them, since the game would stop at the missing name."""
    literals = set(re.findall(r'"([^"\\\n]+)"', story_text))
    return {(kind, name) for kind, name in _ENTRY_NAME.findall(layout_text) if name in literals}


def names_the_story_uses(repository, level):
    """The (kind, name) pairs in the level's layout file that its Swift file quotes
    (required_names). Without the layout file Export cannot tell, so it refuses."""
    root = Path(repository)
    written, story = root / level.layout, root / level.story
    if not story.exists():
        return set()
    if not written.exists():
        raise LayoutError(
            f"{level.layout} is missing, so Export cannot tell which of its names {story.name} "
            f"uses. Restore it with git restore {level.layout}, then export again.")
    return required_names(written.read_text(), story.read_text())


def lights_from_shapes(shapes):
    """The layout's lights from Blender's, and anything that stops an export."""
    lights, problems = [], []
    for shape in shapes:
        if shape.kind != "SUN":
            problems.append(
                f"{shape.name} is a {shape.kind.lower()} light; the game has only sun lights so far.")
            continue
        source = tuple(round(value * SOURCE_LENGTH, 2) for value in _unit(from_blender(shape.direction)))
        colour = tuple(round(value, 3) for value in _srgb(shape.color))
        intensity = round(shape.energy / SUN_STRENGTH_PER_LUX, 1)
        shadow = (shape.shadow_distance or DEFAULT_SHADOW_DISTANCE) if shape.shadow else None
        lights.append(Light(shape.name, source, colour, intensity, shadow))
    return lights, problems


def layout_from_shapes(shapes, level, camera, lights, required=()):
    """Build a layout from what Blender holds, or raise with everything that must change first.
    `required` holds the (kind, name) pairs that the level's Swift file uses (required_names)."""
    problems = []
    ground, boxes, landmarks, areas, markers = [], [], [], [], []
    for shape in shapes:
        low, high = shape.minimum, shape.maximum
        centre = tuple((a + b) / 2 for a, b in zip(low, high))
        extent = tuple(b - a for a, b in zip(low, high))
        if shape.role != "marker":
            if not shape.square:
                problems.append(
                    f"{shape.name} is turned at an angle or mirrored. The game's boxes stay square "
                    f"to the level: turn it only in quarter turns about the vertical.")
                continue
            if not shape.cuboid:
                problems.append(f"{shape.name} is no longer a box; the game only has boxes.")
                continue
            if shape.role != "area" and min(extent) <= 0:
                problems.append(f"{shape.name} is flat; give it some size.")
                continue
        if shape.role in ("ground", "box"):
            if shape.role == "ground" and abs(high[2]) > _TOLERANCE:
                problems.append(f"The deck's top should be at height 0, not {_number(high[2])}.")
            if shape.role == "box" and abs(low[2]) > _TOLERANCE:
                problems.append(
                    f"{shape.name} should stand on the deck: its base is at {_number(low[2])} m.")
            item = Box(shape.name, (centre[0], centre[2], -centre[1]),
                       (extent[0], extent[2], extent[1]))
            (ground if shape.role == "ground" else boxes).append(item)
        elif shape.role == "landmark":
            if abs(low[2]) > _TOLERANCE:
                problems.append(
                    f"{shape.name} should stand on the deck: its base is at {_number(low[2])} m.")
            landmarks.append(Landmark(
                shape.name, (centre[0], low[2], -centre[1]), (extent[0], extent[2], extent[1])))
        elif shape.role == "area":
            areas.append(Area(shape.name, (low[0], -high[1]), (high[0], -low[1])))
        elif shape.role == "marker":
            markers.append(Marker(shape.name, (low[0], -low[1])))
        else:
            problems.append(f"{shape.name} has a role the game does not know, {shape.role}.")
    if len(ground) != 1:
        problems.append(f"The level needs exactly one ground, not {len(ground)}.")
    names = {
        "box": {item.name for item in ground + boxes},
        "landmark": {item.name for item in landmarks},
        "area": {item.name for item in areas},
        "marker": {item.name for item in markers},
    }
    for kind, name in sorted(required):
        if name not in names[kind]:
            problems.append(
                f"The {kind} {name} is missing, and {Path(level.story).name} uses it. Keep it, or "
                f"change the level's Swift file first.")
    saved_camera = None
    if camera is not None:
        saved_camera = Camera(from_blender(camera.offset), camera.field_of_view)
    saved_lights, light_problems = lights_from_shapes(lights or [])
    problems += light_problems
    if problems:
        raise LayoutError(" ".join(problems))
    layout = Layout(ground[0], boxes, landmarks, areas, markers, saved_camera, saved_lights)
    _check_names(layout)
    return layout


# MARK: - What each export was made from (ADR 0006)


_LFS_POINTER = b"version https://git-lfs.github.com/spec/v1"


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


def _records(repository):
    path = Path(repository) / EXPORT_RECORD
    try:
        return json.loads(path.read_text()) if path.exists() else {}
    except ValueError:
        return {}  # Unreadable: every level counts as stale, and the next export rewrites it.


def stale_exports(repository, key="brooklyn-bridge"):
    """Why the level's exports no longer match what they were made from, or None when they do."""
    level = LEVELS[key]
    root = Path(repository)
    record = _records(repository).get(key)
    if record is None:
        return f"{level.title} has not been exported."
    if record.get("format") != EXPORT_FORMAT:
        return f"{level.title} was exported by an earlier version of the Lauder extension."
    made_from, wrote = record.get("made from", {}), record.get("wrote", {})
    if level.blend not in made_from or {level.layout, level.scene} - set(wrote):
        return f"{EXPORT_RECORD} does not say how {level.title} was exported."
    for name, fingerprint in made_from.items():
        if not (root / name).exists():
            return f"{name} is missing."
        if file_fingerprint(root / name) != fingerprint:
            return f"{name} changed since {level.title} was exported."
    for name, fingerprint in wrote.items():
        if not (root / name).exists():
            return f"{name} is missing."
        if file_fingerprint(root / name) != fingerprint:
            return (f"{name} changed since it was exported. Export writes it: change the level in "
                    f"Blender instead.")
    return None


def record_exports(repository, level, made_from, wrote):
    """Record what the level's export was made from and what it wrote, with fingerprints."""
    records = _records(repository)
    records[level.key] = {"format": EXPORT_FORMAT, "made from": made_from, "wrote": wrote}
    path = Path(repository) / EXPORT_RECORD
    path.write_text(json.dumps(records, indent=2, sort_keys=True) + "\n")


def levels_using(repository, name):
    """The levels whose last export used this file, such as a model, relative to the repository."""
    return [key for key, record in _records(repository).items()
            if key in LEVELS and name in record.get("made from", {})]


# MARK: - Models, and what a scene file can show (ADR 0006)


#: The shader nodes that may feed a material's Principled BSDF. Blender's USD export turns "simple
#: node trees containing Diffuse BSDF, Principled BSDF, Image Textures, UVMap, and Separate RGB
#: nodes" into the preview surfaces that RealityKit shows (Blender's manual, USD export). Lauder
#: keeps to the Principled BSDF and adds the Normal Map node, which carries a normal texture. Math
#: nodes may feed only Alpha, for a cut-off, as the manual describes.
SHADER_NODES = frozenset({"TEX_IMAGE", "UVMAP", "SEPARATE_COLOR", "NORMAL_MAP", "REROUTE"})
#: The kinds of texture file that a USDZ carries to the game.
TEXTURE_TYPES = (".png", ".jpg", ".jpeg")
#: The repository's policy (.gitattributes): a PNG or JPEG over 1 MiB needs a Git LFS rule of its
#: own.
LFS_IMAGE_BYTES = 1_048_576
#: The intake check's starting budgets for one model. They give notes, not refusals, until phone
#: measurements set real ones.
MOST_TRIANGLES = 10_000
MOST_TEXTURE_PIXELS = 2048
#: Beyond these sizes, in metres, a model was probably made in other units.
LARGEST_MODEL, SMALLEST_MODEL = 50, 0.05


def _and(items):
    """Names in a sentence: "a", "a and b", "a, b and c"."""
    items = list(items)
    return items[0] if len(items) == 1 else ", ".join(items[:-1]) + " and " + items[-1]


def usd_name(name):
    """The name a Blender name has in USD, which allows only letters, digits and underscores and
    no digit first: Blender's USD export replaces every other byte with an underscore, so
    `car-a1 model` becomes `car_a1_model`."""
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


@dataclass
class MaterialShape:
    """What Export and the intake check read from one material that a scene file would show."""
    name: str
    #: The model file it comes from, relative to the repository, or None for the open file's own.
    source: str = None
    #: The kind of node that makes its surface, such as BSDF_PRINCIPLED, or None when none does.
    surface: str = None
    #: For each input of the surface that nodes feed: the input's name, and the kind and label of
    #: each node that feeds it, however indirectly.
    feeds: tuple = ()


def _material(material):
    return material.name + (f" (from {material.source})" if material.source else "")


def material_problems(materials):
    """What stops the game from showing these materials as Blender does (ADR 0006, decision 8): a
    surface other than a Principled BSDF, nodes that Blender's USD export cannot carry, and names
    that USD would make the same, which the scene file would merge into one."""
    problems, by_name = [], {}
    for material in materials:
        by_name.setdefault(usd_name(material.name), []).append(material)
        if material.surface != "BSDF_PRINCIPLED":
            problems.append(f"The material {_material(material)} needs a Principled BSDF as its "
                            f"surface; the game shows nothing else.")
            continue
        for socket, nodes in material.feeds:
            allowed = SHADER_NODES | ({"MATH"} if socket == "Alpha" else set())
            others = sorted({label for kind, label in nodes if kind not in allowed})
            if others:
                problems.append(f"The material {_material(material)} makes its {socket} with "
                                f"{_and(others)}, which the game cannot show: bake it into an "
                                f"image texture.")
    for key, same in sorted(by_name.items()):
        if len(same) > 1:
            problems.append(f"The materials {_and([_material(each) for each in same])} would all be "
                            f"{key} in the scene file, where one replaces the others: give each "
                            f"a name of its own.")
    return problems


@dataclass
class TextureShape:
    """What Export and the intake check read from one image that a material uses."""
    name: str
    #: Its file, relative to the repository, or as an absolute path when outside it.
    path: str = ""
    #: Blender's source for the image: FILE for an image file, or GENERATED, TILED and others.
    source: str = "FILE"
    packed: bool = False
    exists: bool = True
    #: The file's size in bytes, and the image's in pixels.
    bytes: int = 0
    pixels: tuple = (0, 0)
    #: Whether Git LFS stores the file, as .gitattributes says, or None when Git cannot tell.
    lfs: bool = None
    #: Whether the Blender file holds the image by its full path, rather than relative to itself.
    full_path: bool = False
    #: Whether the file is a Git LFS pointer, not yet downloaded with git lfs pull.
    pointer: bool = False


def texture_problems(textures, folder=None):
    """What stops these textures from reaching the game as image files of their own in the
    repository, kept out of the Blender files. With a folder, such as a model's, each texture must
    be in it."""
    problems = []
    home = folder or "the repository"
    for texture in textures:
        if texture.source != "FILE":
            problems.append(f"The texture {texture.name} is {texture.source.lower()} in Blender; "
                            f"save it as a PNG or JPEG file in {home} and use that.")
        elif texture.packed:
            problems.append(f"The texture {texture.name} is packed into the Blender file; unpack "
                            f"it into {home}, so that it stays a file of its own.")
        elif not texture.exists:
            problems.append(f"The texture {texture.name} is missing: {texture.path or 'no file'}.")
        elif texture.pointer:
            problems.append(f"The texture {texture.name}, {texture.path}, is not downloaded yet: "
                            f"run git lfs pull.")
        elif texture.path.startswith("/"):
            problems.append(f"The texture {texture.name} is outside the repository; copy it into "
                            f"{home}.")
        else:
            if folder and not texture.path.startswith(folder.rstrip("/") + "/"):
                problems.append(f"The texture {texture.name} is in {Path(texture.path).parent}; "
                                f"copy it into {folder}.")
            if Path(texture.path).suffix.lower() not in TEXTURE_TYPES:
                problems.append(f"The texture {texture.name} is a {Path(texture.path).suffix} "
                                f"file; the game takes PNG and JPEG.")
            if texture.bytes > LFS_IMAGE_BYTES and texture.lfs is False:
                problems.append(f"The texture {texture.name} is over 1 MiB, so the repository "
                                f"stores it with Git LFS: add a rule for {texture.path} to "
                                f".gitattributes.")
            if texture.full_path:
                problems.append(f"The texture {texture.name} is held by its full path; save its "
                                f"Blender file with the Lauder extension, which makes it "
                                f"relative.")
    return problems


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


def _is(names):
    return "is" if len(names) == 1 else "are"


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


# MARK: - Work in the background


#: Work running in the background, one step after another, so that Blender stays usable: the
#: steps still to run; the running step, its process, log and log's path; the repository the work
#: is for; and how often it exported again because a level's files changed while it ran.
_JOB = {"steps": [], "step": None, "process": None, "log": None, "path": None,
        "repository": None, "refreshes": 0}
#: How often one run of background work exports again while a level's files keep changing, so
#: that it cannot go on for ever.
MOST_REFRESHES = 3


def _export_step(repository, key):
    """The background step that exports the level in a Blender of its own: (name, command, log,
    level)."""
    blender = bpy.app.binary_path if bpy is not None else "blender"
    return ("export", [
        blender, "-b", "--factory-startup", "--python-exit-code", "1",
        "--python", str(Path(repository) / EXPORT_SCRIPT), "--", key,
    ], "export.log", key)


def background_steps(repository, key, play):
    """The background steps that saving (play=False) or Play needs: exporting the level when its
    exports no longer match its files, then, for Play, building and opening the game. Each is
    (name, command, log, level)."""
    steps = [_export_step(repository, key)] if stale_exports(repository, key) is not None else []
    if play:
        steps.append(("play", [sys.executable, "-I", str(Path(repository) / PLAY_SCRIPT)],
                      "play.log", key))
    return steps


def queue_steps(running, waiting, steps):
    """The steps to add after the background step running, if any, and those waiting. An export
    of the same level already running or waiting stands in for a new one, which could only race it
    for the same files: when it finishes, the exports' freshness is checked again
    (refresh_needed)."""
    exporting = {step[3] for step in ([running] if running else []) + list(waiting)
                 if step[0] == "export"}
    return [step for step in steps if step[0] != "export" or step[3] not in exporting]


def refresh_needed(finished, waiting, stale, refreshes):
    """Whether to export the finished step's level again before going on, once the step has
    finished well: when the level's files changed while it ran, such as by a second save, and its
    export is not next anyway."""
    upcoming = waiting[0] if waiting else None
    exporting_next = upcoming is not None and upcoming[0] == "export" and upcoming[3] == finished[3]
    return stale and not exporting_next and refreshes < MOST_REFRESHES


def _finished(step):
    """What a background step says when it finishes well."""
    if step[0] == "export":
        return f"Exported {LEVELS[step[3]].title}. The game shows it from the next build."
    return "The game is running in the Simulator."


def _start_job(repository, steps):
    """Run the steps in the background, in order, stopping at the first that fails."""
    _JOB.update(steps=list(steps), repository=repository, refreshes=0)
    _next_step()
    # Persistent, so that opening another Blender file keeps watching.
    bpy.app.timers.register(_watch_job, first_interval=1.0, persistent=True)


def _next_step():
    step = _JOB["steps"].pop(0)
    path = Path(_JOB["repository"]) / ".local/play" / step[2]
    path.parent.mkdir(parents=True, exist_ok=True)
    log = path.open("w")
    process = subprocess.Popen(step[1], cwd=_JOB["repository"], stdout=log,
                               stderr=subprocess.STDOUT)
    _JOB.update(step=step, process=process, log=log, path=path)


def _job_running():
    """Whether background work is still running. Work that stopped while nothing watched it is
    finished off here, so that saving and Play are never stuck."""
    if _JOB["process"] is None:
        return False
    if _JOB["process"].poll() is None:
        return True
    _watch_job()
    return _JOB["process"] is not None


def _watch_job():
    process = _JOB["process"]
    if process is None:
        return None
    if process.poll() is None:
        return 0.5
    _JOB["log"].close()
    _JOB["process"] = None
    step, path = _JOB["step"], _JOB["path"]
    if process.returncode == 0:
        try:
            stale = stale_exports(_JOB["repository"], step[3]) is not None
        except (OSError, ValueError):
            stale = False
        if refresh_needed(step, _JOB["steps"], stale, _JOB["refreshes"]):
            _JOB["steps"].insert(0, _export_step(_JOB["repository"], step[3]))
            _JOB["refreshes"] += 1
        if _JOB["steps"]:
            try:
                _next_step()
            except OSError as error:
                _JOB["steps"] = []
                _announce(f"The next step could not start: {error}", error=True)
                return None
            return 0.5
        _announce(_finished(step))
        return None
    _JOB["steps"] = []
    lines = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    # The export says why it refused in one line; otherwise the log's last lines tell.
    detail = next((line for line in reversed(lines) if line.startswith("The level was not")),
                  " ".join(lines[-3:]))
    what = f"Exporting {LEVELS[step[3]].title}" if step[0] == "export" else "Play"
    _announce(f"{what} failed{': ' + detail if detail else '.'} The log is "
              f".local/play/{path.name}.", error=True)
    return None


def _queued(name):
    """Whether a background step of this name is running or waiting to run."""
    if not _job_running():
        return False
    return _JOB["step"][0] == name or any(step[0] == name for step in _JOB["steps"])


def _queue(repository, steps):
    """Run the steps in the background, after the work already running, if any (queue_steps)."""
    if _job_running():
        _JOB["steps"].extend(queue_steps(_JOB["step"], _JOB["steps"], steps))
    elif steps:
        _start_job(repository, steps)


def _export_if_stale(repository, key):
    """Export the level in the background when its exports no longer match its files, after the
    work already running. Returns whether an export is running or waiting."""
    _queue(repository, background_steps(repository, key, play=False))
    return _queued("export")


def _export_levels_using(repository, name):
    """Export, in the background, each level whose last export used the model and whose exports
    no longer match its files. Returns the message to show."""
    relative = f"{ASSETS}/{name}/{name}.blend"
    keys = levels_using(repository, relative)
    if not keys:
        return f"No level uses {name} yet: place it in one with Add Model."
    exporting = [LEVELS[key].title for key in keys if stale_exports(repository, key) is not None]
    for key in keys:
        _export_if_stale(repository, key)
    if not exporting:
        return f"The exports of the levels that use {name} are up to date."
    verb = "uses" if len(exporting) == 1 else "use"
    return f"Exporting {_and(exporting)}, which {verb} {name}…"


def _announce(message, error=False):
    """Tell the person from a handler or a timer, which cannot report: in the Lauder tab, and in
    Blender's status bar."""
    bpy.context.window_manager.lauder_message = message
    print(f"Lauder: {message}")

    def report():
        try:
            bpy.ops.lauder.report(message=message, error=error)
        except (AttributeError, RuntimeError):
            pass

    bpy.app.timers.register(report, first_interval=0.1)


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


def _guess_repository():
    """The repository this extension was installed from, found by its folders."""
    try:
        here = Path(__file__).resolve()
    except NameError:
        return ""
    for folder in here.parents:
        if (folder / "apple" / "sources" / "content").is_dir():
            return str(folder)
    return ""


# MARK: - Blender


#: Blender's USD export for a scene file: the game's axes (y up, metres), each object as one
#: prim, the materials as preview surfaces, and nothing that the game makes itself. Each instance
#: of a model is written out as real meshes: in a test, RealityKit shared each part's mesh among a
#: model's copies either way, and USD's instancing only added an entity to each part.
SCENE_EXPORT = {
    "use_instancing": False,
    "export_materials": True,
    "generate_preview_surface": True,
    "generate_materialx_network": False,
    "export_lights": False,
    "export_cameras": False,
    "export_animation": False,
    "export_custom_properties": False,
    "author_blender_name": False,
    "merge_parent_xform": True,
    "convert_orientation": True,
    "export_global_forward_selection": "NEGATIVE_Z",
    "export_global_up_selection": "Y",
    "evaluation_mode": "RENDER",
}


def _collection(name):
    return bpy.data.collections.get(name)


def shapes_from_blender():
    """What Export reads from the Gameplay collection of the open Blender file."""
    part = _collection(GAMEPLAY)
    if part is None:
        raise LayoutError("This Blender file has no Gameplay collection; open the level's own file.")
    # Bring every object's place up to date, as the interface does between clicks, so that an
    # export straight after a script's edits reads where things are.
    bpy.context.view_layer.update()
    shapes = []
    for item in part.all_objects:
        if item.instance_type == "COLLECTION" and item.instance_collection is not None:
            raise LayoutError(f"{item.name} shows a model but is in Gameplay; put models in "
                              f"Visual, parented to their box.")
        role = item.get("lauder_role") or {"MESH": "box", "EMPTY": "marker"}.get(item.type)
        if role not in ROLES:
            raise LayoutError(
                f"{item.name} is in Gameplay but is neither a mesh box nor an empty marker.")
        if role == "marker":
            if item.type != "EMPTY":
                raise LayoutError(f"{item.name} is a marker but not an empty.")
            location = tuple(item.matrix_world.translation)
            shapes.append(Shape(item.name, role, location, location))
            continue
        if item.type != "MESH":
            raise LayoutError(f"{item.name} is a {role} but not a mesh box.")
        local = [tuple(corner) for corner in item.bound_box]
        vertices = [tuple(vertex.co) for vertex in item.data.vertices]
        cuboid = len(vertices) == 8 and all(
            any(all(abs(a - b) < 1e-4 for a, b in zip(vertex, corner)) for corner in local)
            for vertex in vertices)
        _, rotation, scale = item.matrix_world.decompose()
        corners = [item.matrix_world @ Vector(corner) for corner in item.bound_box]
        low = tuple(min(corner[axis] for corner in corners) for axis in range(3))
        high = tuple(max(corner[axis] for corner in corners) for axis in range(3))
        matrix = rotation.to_matrix()
        square = all(value > 0 for value in scale) and abs(matrix[2][2] - 1) < 1e-4 and all(
            min(abs(matrix[row][column]), abs(abs(matrix[row][column]) - 1)) < 1e-4
            for row in range(3) for column in range(3))
        shapes.append(Shape(item.name, role, low, high, square, cuboid))
    return shapes


def camera_from_blender():
    """The game camera's offset and field of view, or None when the rig is gone."""
    part = _collection(CAMERA)
    items = {item.get("lauder_rig"): item for item in part.objects} if part is not None else {}
    target, camera = items.get("target"), items.get("camera")
    if target is None or camera is None or camera.type != "CAMERA":
        return None
    if camera.data.sensor_fit != "VERTICAL":
        raise LayoutError("Keep the game camera's Sensor Fit at Vertical.")
    offset = camera.matrix_world.translation - target.matrix_world.translation
    return CameraShape(tuple(offset), math.degrees(camera.data.angle_y))


def lights_from_blender():
    """What Export reads from the level's lights."""
    part = _collection(LIGHTS)
    if part is None:
        return []
    shapes = []
    for item in part.all_objects:
        if item.type != "LIGHT":
            raise LayoutError(f"{item.name} is in Lights but is not a light.")
        data = item.data
        direction = item.matrix_world.to_quaternion() @ Vector((0, 0, 1))
        distance = data.get("lauder_shadow_distance")
        shapes.append(LightShape(
            item.name, data.type, tuple(direction), tuple(data.color), data.energy,
            data.use_shadow, None if distance is None else float(distance)))
    return shapes


def lights_outside_the_level(view_layer):
    """The visible lights that are not in the level's Lights, such as the one in Blender's default
    scene. Game Look would show them, but the game has no such light."""
    part = _collection(LIGHTS)
    own = set(part.all_objects) if part is not None else set()
    return [item.name for item in view_layer.objects
            if item.type == "LIGHT" and item not in own and item.visible_get(view_layer=view_layer)]


def layout_from_blender(repository, level):
    """The layout that the open level file holds, after the game's rules."""
    return layout_from_shapes(shapes_from_blender(), level, camera_from_blender(),
                              lights_from_blender(), names_the_story_uses(repository, level))


def what_collection_shows(collection):
    """Every object a collection shows: its own, and those of the models and other collections
    that its instances show, however deep."""
    shown, waiting = {}, list(collection.all_objects)
    while waiting:
        item = waiting.pop()
        if item in shown:
            continue
        shown[item] = None
        if item.instance_type == "COLLECTION" and item.instance_collection is not None:
            waiting.extend(item.instance_collection.all_objects)
    return list(shown)


def _relative(path, root):
    """A path relative to the repository, or as it is when outside it."""
    try:
        return str(Path(path).resolve().relative_to(Path(root).resolve()))
    except ValueError:
        return str(path)


def _library_path(library):
    """Where a linked Blender file is, resolved from the file that links it."""
    return Path(bpy.path.abspath(library.filepath, library=library.parent)).resolve()


def _model_file_of(item):
    """The model file whose collection the object shows, or None."""
    collection = item.instance_collection if item is not None else None
    if item is None or item.instance_type != "COLLECTION" or collection is None:
        return None
    return _library_path(collection.library) if collection.library is not None else None


def _feeding(socket):
    """Every node that feeds an input socket, however indirectly."""
    found, waiting = {}, [link.from_node for link in socket.links if not link.is_muted]
    while waiting:
        node = waiting.pop()
        if node.name in found:
            continue
        found[node.name] = node
        waiting.extend(link.from_node for each in node.inputs for link in each.links
                       if not link.is_muted)
    return list(found.values())


def _material_shape(material, root):
    """What Export reads from a material (MaterialShape), and the images that it shows."""
    source = _relative(_library_path(material.library), root) if material.library else None
    tree = material.node_tree
    output = tree.get_output_node("ALL") if tree is not None else None
    socket = output.inputs.get("Surface") if output is not None else None
    if socket is None or not socket.is_linked:
        return MaterialShape(material.name, source), []
    shader = socket.links[0].from_node
    feeds, images = [], []
    if shader.type == "BSDF_PRINCIPLED":
        for each in shader.inputs:
            if not each.is_linked:
                continue
            nodes = _feeding(each)
            feeds.append((each.name, tuple(sorted({(node.type, node.bl_label) for node in nodes}))))
            images += [node.image for node in nodes if node.type == "TEX_IMAGE" and node.image]
    return MaterialShape(material.name, source, shader.type, tuple(feeds)), images


def _stored_with_lfs(root, relative):
    """Whether .gitattributes has Git LFS store the file, or None when Git cannot tell."""
    git = shutil.which("git") or "/usr/bin/git"
    try:
        result = subprocess.run([git, "check-attr", "filter", "--", relative], cwd=root,
                                capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip().endswith(": lfs")


def _texture_shape(image, root):
    """What Export and the intake check read from an image (TextureShape)."""
    if image.source != "FILE":
        return TextureShape(image.name, source=image.source)
    if image.packed_file is not None:
        return TextureShape(image.name, packed=True)
    path = Path(bpy.path.abspath(image.filepath, library=image.library)).resolve()
    if not image.filepath or not path.is_file():
        return TextureShape(image.name, image.filepath, exists=False)
    relative = _relative(path, root)
    if is_lfs_pointer(path):
        return TextureShape(image.name, relative, pointer=True)
    size = path.stat().st_size
    lfs = _stored_with_lfs(root, relative) if size > LFS_IMAGE_BYTES and not relative.startswith(
        "/") else None
    return TextureShape(image.name, relative, bytes=size, pixels=tuple(image.size), lfs=lfs,
                        full_path=not image.filepath.startswith("//"))


def _looks(objects, root):
    """The materials that these objects show, each once (MaterialShape), and their textures
    (TextureShape)."""
    materials = {}
    for item in objects:
        for slot in getattr(item, "material_slots", ()):
            if slot.material is not None:
                materials[slot.material] = None
    shapes, images = [], {}
    for material in materials:
        shape, used = _material_shape(material, root)
        shapes.append(shape)
        images.update((image, None) for image in used)
    return shapes, [_texture_shape(image, root) for image in images]


def visual_problems(repository):
    """What stops the open level's Visual collection from reaching the game as Blender shows it:
    linked files that are not models or not there, materials beyond the contract or sharing a name,
    textures that are not image files of their own in the repository, and names that USD would
    make the same."""
    root = Path(repository)
    visual = _collection(VISUAL)
    if visual is None:
        return ["This Blender file has no Visual collection; open the level's own file."]
    problems = []
    for library in bpy.data.libraries:
        path = _library_path(library)
        if model_of_path(root, path) is None:
            problems.append(f"The level links {_relative(path, root)}, which is not a model: link "
                            f"models from {ASSETS}/<model>/<model>.blend.")
        elif path.is_file() and is_lfs_pointer(path):
            problems.append(f"{_relative(path, root)} is not downloaded yet: run git lfs pull.")
        elif library.is_missing or not path.is_file():
            problems.append(f"{_relative(path, root)} is missing, and the level uses it.")
        elif not library.filepath.startswith("//"):
            problems.append(f"{_relative(path, root)} is linked by its full path; save the level "
                            f"with the Lauder extension, which makes it relative.")
    shown = what_collection_shows(visual)
    for item in shown:
        collection = item.instance_collection if item.instance_type == "COLLECTION" else None
        if (collection is not None and collection.is_missing and collection.library is not None
                and not collection.library.is_missing):
            problems.append(f"{item.name} shows {collection.name}, which "
                            f"{_relative(_library_path(collection.library), root)} no longer has: "
                            f"keep the model's collection named after it.")
    materials, textures = _looks(shown, root)
    problems += material_problems(materials)
    problems += texture_problems(textures)
    problems += name_clashes([item.name for item in visual.all_objects], "objects in Visual")
    return problems


def check_level(repository, level):
    """The layout that the open level file holds, once the game's rules hold for both what plays
    and what shows."""
    layout = layout_from_blender(repository, level)
    problems = visual_problems(repository)
    if problems:
        raise LayoutError(" ".join(problems))
    return layout


def _files_used(repository):
    """The files the open Blender file uses besides itself, such as linked models and textures,
    relative to the repository."""
    root = Path(repository).resolve()
    used = set()
    for path in bpy.utils.blend_paths(absolute=True, packed=False, local=False):
        resolved = Path(path).resolve()
        try:
            used.add(str(resolved.relative_to(root)))
        except ValueError:
            raise LayoutError(f"{path} is outside the repository; keep the level's files in it.")
    return sorted(used)


def open_level_file(repository, key, attempts=3):
    """Open the level's Blender file, and return the fingerprints of it and of every file it uses,
    such as its models and their textures, relative to the repository. Each fingerprint is taken
    before its file is read, so a save that lands meanwhile leaves the exports stale, to be
    exported again, and never recorded as current. The level is opened to find the files it uses,
    then again to read them, until no file it then uses went without a fingerprint first."""
    root = Path(repository)
    level = LEVELS[key]
    made_from = {level.blend: file_fingerprint(root / level.blend)}
    bpy.ops.wm.open_mainfile(filepath=str(root / level.blend), load_ui=False)
    for _ in range(attempts):
        for name in _files_used(root):
            if name not in made_from and (root / name).is_file():
                made_from[name] = file_fingerprint(root / name)
        bpy.ops.wm.open_mainfile(filepath=str(root / level.blend), load_ui=False)
        # A file still missing has no fingerprint, and the export refuses it.
        unread = [name for name in _files_used(root)
                  if name not in made_from and (root / name).is_file()]
        if not unread:
            return made_from
    raise LayoutError(f"The files {level.blend} uses kept changing while it was read; export it "
                      f"again.")


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


def export_level(repository, key="brooklyn-bridge", made_from=None):
    """Write the level's layout file and scene file from its Blender file, open in this Blender,
    and record what they were made from. `made_from` holds the fingerprints of the level's files
    from before they were read (open_level_file), so that a save made since counts as a change. It
    changes the open file, so it runs in a Blender of its own: blender/scripts/export-level.py."""
    level = LEVELS[key]
    root = Path(repository)
    text = emit_layout(check_level(repository, level), level)
    made_from = dict(made_from or {})
    for name in [level.blend] + _files_used(root):
        if not (root / name).is_file():
            raise LayoutError(f"{name} is missing, and the level file refers to it.")
        if name not in made_from:
            made_from[name] = file_fingerprint(root / name)
    # Only the Visual collection is exported, each of its own parts where it stands in the world;
    # the models it shows come with their instances, from their own files.
    visual = _collection(VISUAL)
    own = [item for item in visual.all_objects if item.library is None]
    shown = set(what_collection_shows(visual))
    places = {item: item.matrix_world.copy() for item in own}
    for item in own:
        item.parent = None
        item.matrix_world = places[item]
        item.hide_render = False
    # Nothing else stays in the scene, which the USD export writes whole: not even a model linked
    # straight into another collection, whose objects belong to its own file.
    scene = bpy.context.scene
    if visual not in list(scene.collection.children):
        scene.collection.children.link(visual)
    for child in list(scene.collection.children):
        if child != visual:
            scene.collection.children.unlink(child)
    for item in list(scene.collection.objects):
        scene.collection.objects.unlink(item)
    for item in list(bpy.data.objects):
        if item.library is None and item not in shown:
            bpy.data.objects.remove(item, do_unlink=True)
    written, target = root / level.layout, root / level.scene
    with tempfile.TemporaryDirectory() as folder:
        exported = Path(folder) / target.name
        bpy.ops.wm.usd_export(filepath=str(exported), **SCENE_EXPORT)
        # Both exports are ready: only now is either written, so a refusal or a failure before
        # this leaves the pair as it was.
        if not written.exists() or written.read_text() != text:
            written.write_text(text)
        shutil.copyfile(exported, target)
    record_exports(repository, level, made_from,
                   {name: file_fingerprint(root / name) for name in (level.layout, level.scene)})
    return target


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
    """Make the model blender/assets/<name> from a file: a Blender file's objects, or what Blender
    imports from a glTF, FBX, OBJ or USD file, in a collection named after the model, with its
    textures copied beside it and a README.md whose source and licence are to fill in. Returns the
    intake check's findings, (problems, notes). It replaces the open file, so it runs in a Blender
    of its own: blender/scripts/add-model.py."""
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


if bpy is not None:

    def _open_level():
        """The repository and level whose Blender file is open, or None."""
        return level_of_file(bpy.data.filepath)

    @persistent
    def _forget_local_paths_before_save(path=None, *_):
        """A level or model file keeps no local paths in the repository (forget_local_paths)."""
        path = path if isinstance(path, str) and path else bpy.data.filepath
        if level_of_file(path) or model_of_file(path):
            forget_local_paths(path)

    @persistent
    def _export_after_save(_):
        """Saving a level's Blender file exports it in the background, once the game's rules hold;
        saving a model's exports the levels that use it. The Blender file is saved whatever the
        rules find."""
        model = model_of_file(bpy.data.filepath)
        if model is not None:
            try:
                _announce(_export_levels_using(*model))
            except OSError as error:
                _announce(f"The model is saved, but its levels were not exported: {error}",
                          error=True)
            return
        found = _open_level()
        if found is None:
            return
        repository, level = found
        try:
            check_level(repository, level)
            exporting = _export_if_stale(repository, level.key)
        except (LayoutError, OSError) as error:
            _announce(f"The Blender file is saved, but the level was not exported: {error}",
                      error=True)
            return
        if exporting:
            _announce("Exporting the level…")

    class LAUDER_OT_open_level(bpy.types.Operator):
        """Open the level's Blender file from the repository"""
        bl_idname = "lauder.open_level"
        bl_label = "Open Level"
        bl_options = {"REGISTER"}

        def invoke(self, context, event):
            if bpy.data.is_dirty:
                return context.window_manager.invoke_confirm(
                    self, event, title="Open the level?",
                    message="The open Blender file has unsaved changes, which this discards.")
            return self.execute(context)

        def execute(self, context):
            repository = bpy.path.abspath(context.scene.lauder_repository)
            level = LEVELS[context.scene.lauder_level]
            path = Path(repository) / level.blend
            if not path.exists():
                self.report({"ERROR"}, f"There is no {level.blend} in the repository folder.")
                return {"CANCELLED"}
            if is_lfs_pointer(path):
                self.report({"ERROR"}, f"{level.blend} is not downloaded yet: run git lfs pull.")
                return {"CANCELLED"}
            bpy.ops.wm.open_mainfile(filepath=str(path))
            return {"FINISHED"}

    class LAUDER_OT_export(bpy.types.Operator):
        """Save the level's Blender file and export it, or the levels that use the open model,
        when their exports are out of date"""
        bl_idname = "lauder.export"
        bl_label = "Export"
        bl_options = {"REGISTER"}

        def execute(self, context):
            found, model = _open_level(), model_of_file(bpy.data.filepath)
            if found is None and model is None:
                self.report({"ERROR"}, "Open the level first, with Open Level.")
                return {"CANCELLED"}
            if bpy.data.is_dirty:
                bpy.ops.wm.save_mainfile()  # Its handler checks the rules and exports.
                return {"FINISHED"}
            if model is not None:
                try:
                    message = _export_levels_using(*model)
                except OSError as error:
                    self.report({"ERROR"}, str(error))
                    return {"CANCELLED"}
                context.window_manager.lauder_message = message
                self.report({"INFO"}, message)
                return {"FINISHED"}
            repository, level = found
            try:
                check_level(repository, level)
                exporting = _export_if_stale(repository, level.key)
            except (LayoutError, OSError) as error:
                context.window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            message = "Exporting the level…" if exporting else "The level's exports are up to date."
            context.window_manager.lauder_message = message
            self.report({"INFO"}, message)
            return {"FINISHED"}

    class LAUDER_OT_play(bpy.types.Operator):
        """Save and export the level, then build the game and open it in the iOS Simulator"""
        bl_idname = "lauder.play"
        bl_label = "Play"
        bl_options = {"REGISTER"}

        def execute(self, context):
            window_manager = context.window_manager
            found = _open_level()
            if found is None:
                self.report({"ERROR"}, "Open the level first, with Open Level.")
                return {"CANCELLED"}
            if _queued("play"):
                self.report({"WARNING"}, "The game is still building; it opens when it is ready.")
                return {"CANCELLED"}
            repository, level = found
            try:
                check_level(repository, level)
            except (LayoutError, OSError) as error:
                window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            if bpy.data.is_dirty:
                bpy.ops.wm.save_mainfile()  # Its handler starts the export; the build waits for it.
            try:
                _queue(repository, background_steps(repository, level.key, play=True))
            except OSError as error:
                self.report({"ERROR"}, f"Play could not start: {error}")
                return {"CANCELLED"}
            message = ("Exporting the level, then building the game for the Simulator…"
                       if _queued("export") else "Building the game for the Simulator…")
            window_manager.lauder_message = message
            self.report({"INFO"}, message)
            return {"FINISHED"}

    #: The models Add Model offers, kept here because Blender needs its list to stay alive. NONE
    #: stands for an empty list, and is no model's name, which is in lowercase.
    _MODEL_ITEMS = []

    def _model_items(self, context):
        found = _open_level()
        names = available_models(found[0]) if found is not None else []
        _MODEL_ITEMS[:] = [(name, name, f"{ASSETS}/{name}") for name in names] or [
            ("NONE", "No models", f"There is no model in {ASSETS} yet")]
        return _MODEL_ITEMS

    def _gameplay_box(item):
        """The object, when it is a gameplay box or landmark that a model can stand on."""
        part = _collection(GAMEPLAY)
        if item is None or item.type != "MESH" or part is None or item not in set(part.all_objects):
            return None
        return item if item.get("lauder_role", "box") in ("box", "landmark") else None

    class LAUDER_OT_add_model(bpy.types.Operator):
        """Place a model from blender/assets in the level: on the selected gameplay box, parented
        to it, or at the 3D cursor"""
        bl_idname = "lauder.add_model"
        bl_label = "Add Model"
        bl_options = {"REGISTER", "UNDO"}
        bl_property = "model"

        model: bpy.props.EnumProperty(name="Model", items=_model_items)

        def invoke(self, context, event):
            if _open_level() is None:
                self.report({"ERROR"}, "Open the level first, with Open Level.")
                return {"CANCELLED"}
            context.window_manager.invoke_search_popup(self)
            return {"RUNNING_MODAL"}

        def execute(self, context):
            found = _open_level()
            if found is None or self.model == "NONE":
                self.report({"ERROR"}, f"Open the level, and add a model to {ASSETS} first.")
                return {"CANCELLED"}
            box = _gameplay_box(context.active_object)
            try:
                holder = place_model(found[0], self.model, box, context.scene.cursor.location)
            except LayoutError as error:
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            for item in context.selected_objects:
                item.select_set(False)
            holder.select_set(True)
            context.view_layer.objects.active = holder
            where = f"on {box.name}" if box is not None else "at the 3D cursor"
            message = f"Placed {self.model} {where}, in Visual."
            context.window_manager.lauder_message = message
            self.report({"INFO"}, message)
            return {"FINISHED"}

    class LAUDER_OT_open_model(bpy.types.Operator):
        """Open the selected model's own Blender file, to change it for every level that uses it"""
        bl_idname = "lauder.open_model"
        bl_label = "Open Model"
        bl_options = {"REGISTER"}

        def invoke(self, context, event):
            if bpy.data.is_dirty:
                return context.window_manager.invoke_confirm(
                    self, event, title="Open the model?",
                    message="The open Blender file has unsaved changes, which this discards.")
            return self.execute(context)

        def execute(self, context):
            path = _model_file_of(context.active_object)
            if path is None:
                self.report({"ERROR"}, "Select a model in Visual first.")
                return {"CANCELLED"}
            if not path.is_file() or is_lfs_pointer(path):
                self.report({"ERROR"}, f"{path.name} is missing or not downloaded yet: run git lfs "
                                       f"pull.")
                return {"CANCELLED"}
            bpy.ops.wm.open_mainfile(filepath=str(path))
            return {"FINISHED"}

    class LAUDER_OT_check_model(bpy.types.Operator):
        """Check the open model against what levels and the game need: the intake check"""
        bl_idname = "lauder.check_model"
        bl_label = "Check Model"
        bl_options = {"REGISTER"}

        def execute(self, context):
            found = model_of_file(bpy.data.filepath)
            if found is None:
                self.report({"ERROR"}, f"Open a model from {ASSETS} first.")
                return {"CANCELLED"}
            problems, notes = check_model(found[0])
            text = report_text(found[1], problems, notes)
            context.window_manager.lauder_message = text
            self.report({"WARNING" if problems else "INFO"}, text.splitlines()[0])
            return {"FINISHED"}

    class LAUDER_OT_game_look(bpy.types.Operator):
        """Light the view with the level's own lights and show its materials, close to the game;
        press again to go back to Solid shading"""
        bl_idname = "lauder.game_look"
        bl_label = "Game Look"
        bl_options = {"REGISTER"}

        def execute(self, context):
            space = context.space_data
            if space is None or space.type != "VIEW_3D":
                self.report({"ERROR"}, "Use Game Look from the 3D Viewport's Lauder tab.")
                return {"CANCELLED"}
            shading = space.shading
            if shading.type == "MATERIAL" and shading.use_scene_lights:
                shading.type = "SOLID"
                return {"FINISHED"}
            others = lights_outside_the_level(context.view_layer)
            if others:
                self.report(
                    {"ERROR"},
                    f"Hide {', '.join(others)} first (H): Game Look shows every visible light, "
                    f"and only the level's Lights reach the game.")
                return {"CANCELLED"}
            shading.type = "MATERIAL"
            # Only the level's own lights, as in the game: no studio light or world.
            shading.use_scene_lights = True
            shading.use_scene_world = False
            shading.studiolight_intensity = 0
            return {"FINISHED"}

    class LAUDER_OT_report(bpy.types.Operator):
        """Show a message from Lauder in the status bar"""
        bl_idname = "lauder.report"
        bl_label = "Lauder message"
        bl_options = {"INTERNAL"}

        message: bpy.props.StringProperty()
        error: bpy.props.BoolProperty()

        def execute(self, context):
            self.report({"ERROR" if self.error else "INFO"}, self.message)
            return {"FINISHED"}

    class LAUDER_PT_levels(bpy.types.Panel):
        bl_label = "Lauder levels"
        bl_idname = "LAUDER_PT_levels"
        bl_space_type = "VIEW_3D"
        bl_region_type = "UI"
        bl_category = "Lauder"

        def draw(self, context):
            layout = self.layout
            scene, window_manager = context.scene, context.window_manager
            layout.prop(scene, "lauder_repository")
            layout.prop(scene, "lauder_level")
            layout.operator("lauder.open_level", icon="FILE_BLEND")
            level, model = _open_level(), model_of_file(bpy.data.filepath)
            item = context.active_object
            if model is not None:
                layout.label(text=f"The model {model[1]}", icon="MESH_DATA")
                layout.operator("lauder.check_model", icon="CHECKMARK")
                layout.operator("lauder.export", icon="EXPORT")
                layout.label(text="Saving exports the levels using it.")
            else:
                row = layout.row()
                row.operator("lauder.export", icon="EXPORT")
                row.operator("lauder.play", icon="PLAY")
                layout.operator("lauder.game_look", icon="LIGHT_SUN")
            if level is not None:
                layout.operator("lauder.add_model", icon="LINKED")
                shown = _model_file_of(item)
                if shown is not None:
                    layout.operator("lauder.open_model", text=f"Open {shown.stem}",
                                    icon="FILE_BLEND")
            if (item is not None and level is not None
                    and any(owner.name == GAMEPLAY for owner in item.users_collection)):
                if "lauder_role" in item:
                    layout.prop(item, '["lauder_role"]', text="Role")
                else:
                    role = "marker" if item.type == "EMPTY" else "box"
                    layout.label(text=f"{item.name} counts as a {role}")
            if window_manager.lauder_message:
                box = layout.box()
                for paragraph in window_manager.lauder_message.splitlines():
                    for line in textwrap.wrap(paragraph, 42) or [""]:
                        box.label(text=line)

    _CLASSES = (
        LAUDER_OT_open_level, LAUDER_OT_export, LAUDER_OT_play, LAUDER_OT_add_model,
        LAUDER_OT_open_model, LAUDER_OT_check_model, LAUDER_OT_game_look, LAUDER_OT_report,
        LAUDER_PT_levels,
    )
    _HANDLERS = (
        (bpy.app.handlers.save_pre, _forget_local_paths_before_save),
        (bpy.app.handlers.save_post, _export_after_save),
    )

    def _remove_handlers():
        for handlers, handler in _HANDLERS:
            for existing in [item for item in handlers
                             if getattr(item, "__name__", None) == handler.__name__]:
                handlers.remove(existing)

    def register():
        for cls in _CLASSES:
            if hasattr(bpy.types, cls.__name__):
                bpy.utils.unregister_class(getattr(bpy.types, cls.__name__))
            bpy.utils.register_class(cls)
        bpy.types.Scene.lauder_repository = bpy.props.StringProperty(
            name="Repository", subtype="DIR_PATH", default=_guess_repository(),
            description="The Lauder repository folder")
        bpy.types.Scene.lauder_level = bpy.props.EnumProperty(
            name="Level",
            items=[(key, level.title, "") for key, level in LEVELS.items()])
        bpy.types.WindowManager.lauder_message = bpy.props.StringProperty()
        _remove_handlers()
        for handlers, handler in _HANDLERS:
            handlers.append(handler)

    def unregister():
        _remove_handlers()
        for cls in reversed(_CLASSES):
            if hasattr(bpy.types, cls.__name__):
                bpy.utils.unregister_class(getattr(bpy.types, cls.__name__))
        del bpy.types.Scene.lauder_repository
        del bpy.types.Scene.lauder_level
        del bpy.types.WindowManager.lauder_message

    if __name__ == "__main__":
        register()
