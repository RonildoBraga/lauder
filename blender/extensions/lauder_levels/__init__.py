"""Lauder's levels in Blender (ADR 0005), as a Blender extension.

Blender is the editor for a level's scene. Load builds it in the open Blender file from the
level's Swift layout file and the shared surface palette, and Save writes both back after checking
the game's rules. The Swift files stay the source of truth: a direct edit to them shows up at the
next Load, and Save will not overwrite one made since the last Load or Save.

The layout holds what blocks movement and sight (the ground and boxes), what can be looked at,
the trigger and fight areas, the markers where people start and stand, the decoration that blocks
nothing (pieces such as the bridge's walkway and cables, turned as they need), the game camera and
the lights. The palette holds how each surface looks, for every level: its colour, roughness and
metalness. Load also draws what the game adds by its own rules, so that Blender shows what the
game shows: the details on every vehicle and landmark, and the party at its start markers. They
follow their box or marker and are not saved.

Install it once: in Blender's Preferences, add a local extension repository at this repository's
blender/extensions folder, then enable Lauder levels. A Lauder tab appears in the 3D Viewport's
sidebar (press N). Open Level keeps each level in a working Blender file in .local/blender, which
Git ignores, and saving that file saves the level too. Play saves the level, then builds the game
and opens it in the iOS Simulator through apple/scripts/play.

Save and Play also keep the level's scene file up to date (ADR 0006): everything the game shows of
the level, built from the layout and the palette and exported as USD, which the game loads instead
of drawing boxes. Each export records what it was made from in blender/scene-exports.json, and
./scripts/check fails when a scene file no longer matches. blender/scripts/export-scene.py exports
one in a Blender of its own, for example after a layout file is edited by hand.

Reading, writing and checking layouts and the palette need no Blender: blender/test_lauder_levels.py
runs them in ./scripts/check. Coordinates in the layout files are the game's, in metres: x across,
y up and z along the level. In Blender, z is up, so a game point (x, y, z) sits at (x, -z, y).

Moving something else into Blender follows the same recipe: give it a typed entry in a Swift data
file, read and write that entry here exactly, build it in Load and read it back in Save, check the
game's rules before anything is written, and test the round trip.
"""

from dataclasses import dataclass, field
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
    import bmesh
    import bpy
    from bpy.app.handlers import persistent
    from mathutils import Quaternion, Vector
except ImportError:  # Outside Blender: the tests use the plain functions below.
    bpy = None


# MARK: - Levels


@dataclass(frozen=True)
class LevelFile:
    key: str
    title: str
    #: The layout file, relative to the repository.
    path: str
    #: The Swift type whose `layout` the file defines.
    owner: str
    #: The opening comment of the file, written on every save.
    header: tuple
    #: Boxes the game looks up by name, which Save will not drop.
    required_boxes: tuple
    #: Where the game camera's preview target starts.
    camera_target: str
    #: The scene file, relative to the repository: everything the game shows of the level.
    scene: str


LEVELS = {
    "brooklyn-bridge": LevelFile(
        key="brooklyn-bridge",
        title="Brooklyn Bridge",
        path="apple/sources/content/BrooklynBridgeLayout.swift",
        owner="BrooklynBridge",
        header=(
            "// Where everything on the Brooklyn Bridge stands and how it is lit (ADR 0005), in metres: x",
            "// across the deck, y up and z along it, with Brooklyn at +z and Manhattan at -z. Blender edits",
            "// this file through its Lauder extension (blender/extensions/lauder_levels): Load builds the",
            "// layout in Blender and Save writes it back. The numbers can also be edited here, and the next",
            "// Load picks them up. Keep the entries in this form so that the script can read them.",
            "// After an edit here, export the scene file again: blender/scripts/export-scene.py.",
        ),
        required_boxes=("brooklyn-tower-pier", "manhattan-tower-pier"),
        camera_target="spawn.miki",
        scene="apple/sources/content/BrooklynBridge.usdz",
    ),
}

#: How each surface looks, for every level: the game's shared material palette. Its entries are
#: the surfaces a box or piece may have.
PALETTE_PATH = "apple/sources/content/Surfaces.swift"
PALETTE_HEADER = (
    "// How each surface looks (ADR 0005): the game's small shared material palette, for every",
    "// level. Colours are sRGB, each channel from 0 to 1. Blender edits this file through its Lauder",
    "// extension (blender/extensions/lauder_levels): Load builds Blender's materials from it and Save",
    "// writes them back. The numbers can also be edited here, and the next Load picks them up. Keep",
    "// the entries in this form so that the script can read them.",
    "// After an edit here, export the scene file again: blender/scripts/export-scene.py.",
)

#: Where each level's working Blender file lives, relative to the repository; Git ignores it.
WORKING_FOLDER = ".local/blender"
#: The script that builds the game and opens it in the iOS Simulator.
PLAY_SCRIPT = "apple/scripts/play"
#: The script that exports a level's scene file in a Blender of its own.
EXPORT_SCRIPT = "blender/scripts/export-scene.py"
#: Where each scene file records what it was made from, relative to the repository.
SCENE_RECORD = "blender/scene-exports.json"
#: Raised whenever the export changes what a scene file holds, so that every scene file is
#: exported again.
SCENE_FORMAT = 1


def working_file(repository, level):
    """The level's working Blender file. Saving it saves the level's files too."""
    return Path(repository) / WORKING_FOLDER / f"{level.key}.blend"

#: Surfaces that the game's own rules draw vehicles and landmarks with; the palette keeps them.
GAME_LOOKS = ("vehicle", "glass", "metal", "paint")

#: The visual direction's budget (docs/visual-direction.md).
MOST_LIGHTS = 2
MOST_SHADOWED_LIGHTS = 1
#: The shadow distance a light gets when its shadow is turned on in Blender.
DEFAULT_SHADOW_DISTANCE = 25
#: Blender's sun strength, in W/m², for each lux of a game light. Blender and RealityKit render
#: differently, so this only brings Blender's preview close; the game shows the real result.
SUN_STRENGTH_PER_LUX = 1 / 700

#: The height of the camera's target above the floor: a stand-in's centre, plus 0.1 m.
CAMERA_TARGET_HEIGHT = 0.95


# MARK: - Layouts, in the game's coordinates


@dataclass
class Box:
    name: str
    #: The centre, (x, y, z).
    position: tuple
    size: tuple
    surface: str


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


IDENTITY = (1.0, 0.0, 0.0, 0.0)


@dataclass
class Piece:
    """Decoration that blocks nothing: a box at any angle."""
    name: str
    #: The centre, (x, y, z).
    position: tuple
    #: Along the piece's own axes.
    size: tuple
    surface: str
    #: A unit quaternion (w, x, y, z) in the game's space.
    rotation: tuple = IDENTITY


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
class Finish:
    """How a surface looks: a colour in sRGB and a roughness and metalness, each from 0 to 1."""
    color: tuple
    roughness: float
    metallic: float = 0.0


@dataclass
class Layout:
    ground: Box
    boxes: list
    landmarks: list
    areas: list
    markers: list
    pieces: list = field(default_factory=list)
    camera: Camera = None
    lights: list = field(default_factory=list)


class LayoutError(Exception):
    """A layout the game cannot use. The message says what to fix."""


# MARK: - Rotations


def _multiply(a, b):
    aw, ax, ay, az = a
    bw, bx, by, bz = b
    return (
        aw * bw - ax * bx - ay * by - az * bz,
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
    )


def _conjugate(q):
    w, x, y, z = q
    return (w, -x, -y, -z)


def _canonical(q):
    """The same rotation, unit length and with w >= 0, so that it is written one way."""
    length = math.sqrt(sum(value * value for value in q)) or 1.0
    q = tuple(value / length for value in q)
    return q if q[0] >= 0 else tuple(-value for value in q)


#: Blender's axes to the game's: a quarter turn about x.
_AXES = (math.sqrt(0.5), -math.sqrt(0.5), 0.0, 0.0)


def rotation_to_blender(q):
    return _canonical(_multiply(_multiply(_conjugate(_AXES), q), _AXES))


def rotation_from_blender(q):
    return _canonical(_multiply(_multiply(_AXES, q), _conjugate(_AXES)))


#: A turn is written to four places, which holds turns down to about a hundredth of a degree.
_TURN_PLACES = 4


def _turn_values(q):
    """A rotation as a layout file writes it: (x, y, z, w), as Swift's simd_quatf takes it, with w
    not negative."""
    w, x, y, z = q
    if w < 0:
        w, x, y, z = -w, -x, -y, -z
    return (x, y, z, w)


def is_identity(q):
    """Whether a rotation is written as no turn at all, because its x, y and z round to zero. Any
    turn that the file can hold is written, however small: half a degree swings the ends of a
    248 m lane line by a metre."""
    x, y, z, _ = _turn_values(q)
    return all(_number(value, _TURN_PLACES) == "0" for value in (x, y, z))


def _same_rotation(a, b, tolerance=1e-9):
    """Whether two quaternions give the same turn, to within a hundredth of a degree."""
    a, b = _canonical(a), _canonical(b)
    return abs(sum(x * y for x, y in zip(a, b))) > 1 - tolerance


# MARK: - Reading a layout file

_LIST = r"\[([^\]]*)\]"
_NAME = r'"([^"\\]+)"'
_NUMBER = r"(-?\d+(?:\.\d+)?)"
_ENTRIES = {
    "box": re.compile(
        r"\.box\(\s*" + _NAME + r"\s*,\s*at:\s*" + _LIST + r"\s*,\s*size:\s*" + _LIST
        + r"\s*,\s*surface:\s*\.(\w+)\s*\)"
    ),
    "landmark": re.compile(
        r"\.landmark\(\s*" + _NAME + r"\s*,\s*at:\s*" + _LIST + r"\s*,\s*size:\s*" + _LIST
        + r"\s*\)"
    ),
    "area": re.compile(
        r"\.area\(\s*" + _NAME + r"\s*,\s*from:\s*" + _LIST + r"\s*,\s*to:\s*" + _LIST + r"\s*\)"
    ),
    "marker": re.compile(r"\.marker\(\s*" + _NAME + r"\s*,\s*at:\s*" + _LIST + r"\s*\)"),
    "piece": re.compile(
        r"\.piece\(\s*" + _NAME + r"\s*,\s*at:\s*" + _LIST + r"\s*,\s*size:\s*" + _LIST
        + r"\s*(?:,\s*turn:\s*" + _LIST + r"\s*)?,\s*surface:\s*\.(\w+)\s*\)"
    ),
    "camera": re.compile(
        r"\.camera\(\s*offset:\s*" + _LIST + r"\s*,\s*fieldOfView:\s*" + _NUMBER + r"\s*\)"
    ),
    "sun": re.compile(
        r"\.sun\(\s*" + _NAME + r"\s*,\s*from:\s*" + _LIST + r"\s*,\s*color:\s*" + _LIST
        + r"\s*,\s*intensity:\s*" + _NUMBER + r"\s*(?:,\s*shadowDistance:\s*" + _NUMBER
        + r"\s*)?\)"
    ),
}
_SECTIONS = ("ground", "boxes", "landmarks", "areas", "markers", "pieces", "camera", "lights")
#: The kinds of entry each section holds. A section may hold several, as the lights will once the
#: game has more kinds than the sun.
_KINDS = {"ground": ("box",), "boxes": ("box",), "landmarks": ("landmark",), "areas": ("area",),
          "markers": ("marker",), "pieces": ("piece",), "camera": ("camera",), "lights": ("sun",)}


#: All that may come before the first section: the layout's opening.
_LAYOUT_OPENING = re.compile(r"\s*extension\s+\w+\s*\{\s*static\s+let\s+layout\s*=\s*Level\.Layout\(\s*")


def _unread(chunk, spans):
    """What is left of the code once its entries are taken out, apart from the brackets, commas,
    closing marks and spaces between them: anything else is something the script did not read,
    which a save would drop."""
    pieces, at = [], 0
    for start, finish in sorted(spans):
        pieces.append(chunk[at:start])
        at = finish
    pieces.append(chunk[at:])
    leftover = "".join(pieces)
    first = re.search(r"[^\s\[\](),}]", leftover)
    return " ".join(leftover[first.start():].split())[:48] if first else ""


def _numbers(text, count, name):
    parts = [part.strip() for part in text.split(",") if part.strip()]
    if len(parts) != count:
        raise LayoutError(f"{name}: expected {count} numbers but found {len(parts)}.")
    try:
        return tuple(float(part) for part in parts)
    except ValueError:
        raise LayoutError(f"{name}: [{text}] is not a list of numbers.") from None


def parse_layout(text, surfaces=None):
    """Read a layout file. Anything that is not read exactly raises, so Save never drops it. Given
    the palette's surfaces, every box and piece must have one of them."""
    code = re.sub(r"//[^\n]*", "", text)
    heads, starts = {}, {}
    for section in _SECTIONS:
        found = list(re.finditer(rf"\b{section}:", code))
        if len(found) != 1:
            raise LayoutError(f"The layout needs exactly one '{section}:' section.")
        heads[section], starts[section] = found[0].start(), found[0].end()
    if sorted(_SECTIONS, key=starts.get) != list(_SECTIONS):
        raise LayoutError("The sections must come in order: " + ", ".join(_SECTIONS) + ".")
    if not re.fullmatch(_LAYOUT_OPENING, code[:heads[_SECTIONS[0]]]):
        raise LayoutError(
            "Before 'ground:', the file should only open the layout: "
            "extension … { static let layout = Level.Layout(")
    entries = {}
    for index, section in enumerate(_SECTIONS):
        end = heads[_SECTIONS[index + 1]] if index + 1 < len(_SECTIONS) else len(code)
        chunk = code[starts[section]:end]
        kinds = _KINDS[section]
        # In the order written, whatever their kinds.
        found = sorted(
            (match.start(), match.end(), kind, match.groups())
            for kind in kinds for match in _ENTRIES[kind].finditer(chunk))
        written = sum(chunk.count(f".{kind}(") for kind in kinds)
        if len(found) != written:
            raise LayoutError(
                f"{written - len(found)} entry or entries in '{section}:' could not be read. "
                f"Write each as the others are."
            )
        unread = _unread(chunk, [(start, finish) for start, finish, _, _ in found])
        if unread:
            raise LayoutError(
                f"'{section}:' holds something the script cannot read: {unread}… "
                f"Write each entry as the others are.")
        entries[section] = [(kind, groups) for _, _, kind, groups in found]
    if len(entries["ground"]) != 1:
        raise LayoutError("The layout needs exactly one ground box.")
    if len(entries["camera"]) != 1:
        raise LayoutError("The layout needs exactly one camera.")

    def box(entry):
        _, (name, at, size, surface) = entry
        return Box(name, _numbers(at, 3, name), _numbers(size, 3, name), surface)

    def piece(entry):
        _, (name, at, size, turn, surface) = entry
        rotation = IDENTITY
        if turn:
            # Kept exactly as written, so that reading and writing the file changes nothing.
            x, y, z, w = _numbers(turn, 4, name)
            rotation = (w, x, y, z)
        return Piece(name, _numbers(at, 3, name), _numbers(size, 3, name), surface, rotation)

    def light(entry):
        _, (name, source, colour, intensity, shadow) = entry
        return Light(name, _numbers(source, 3, name), _numbers(colour, 3, name), float(intensity),
                     None if shadow is None else float(shadow))

    _, (offset, field_of_view) = entries["camera"][0]
    layout = Layout(
        ground=box(entries["ground"][0]),
        boxes=[box(entry) for entry in entries["boxes"]],
        landmarks=[
            Landmark(name, _numbers(at, 3, name), _numbers(size, 3, name))
            for _, (name, at, size) in entries["landmarks"]
        ],
        areas=[
            Area(name, _numbers(low, 2, name), _numbers(high, 2, name))
            for _, (name, low, high) in entries["areas"]
        ],
        markers=[Marker(name, _numbers(at, 2, name)) for _, (name, at) in entries["markers"]],
        pieces=[piece(entry) for entry in entries["pieces"]],
        camera=Camera(_numbers(offset, 3, "camera"), float(field_of_view)),
        lights=[light(entry) for entry in entries["lights"]],
    )
    _check_names(layout, surfaces)
    return layout


def _check_names(layout, surfaces=None):
    problems = []
    for kind, items in (
        ("box", [layout.ground] + layout.boxes), ("landmark", layout.landmarks),
        ("area", layout.areas), ("marker", layout.markers), ("piece", layout.pieces),
        ("light", layout.lights),
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
    if surfaces is not None:
        for item in [layout.ground] + layout.boxes + layout.pieces:
            if item.surface not in surfaces:
                problems.append(f"{item.name} has an unknown surface, {item.surface}.")
    if layout.camera is None:
        problems.append("The layout needs a camera.")
    elif not 10 <= layout.camera.field_of_view <= 120:
        problems.append("The camera's field of view should be between 10 and 120 degrees.")
    problems += _light_problems(layout.lights)
    if problems:
        raise LayoutError(" ".join(problems))


def _light_problems(lights):
    """The visual direction's budget for lights, and lights the game can use."""
    problems = []
    if not lights:
        problems.append("The layout needs a light.")
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
    return [f'"{box.name}"', f"at: {_list(box.position)}", f"size: {_list(box.size)}",
            f"surface: .{box.surface}"]


def _piece_arguments(piece):
    arguments = [f'"{piece.name}"', f"at: {_list(piece.position)}", f"size: {_list(piece.size)}"]
    if not is_identity(piece.rotation):
        arguments.append(f"turn: {_list(_turn_values(piece.rotation), _TURN_PLACES)}")
    return arguments + [f"surface: .{piece.surface}"]


def _light_arguments(light):
    arguments = [f'"{light.name}"', f"from: {_list(light.source)}", f"color: {_list(light.color)}",
                 f"intensity: {_number(light.intensity)}"]
    if light.shadow_distance is not None:
        arguments.append(f"shadowDistance: {_number(light.shadow_distance)}")
    return arguments


def emit_layout(layout, level, surfaces=None):
    """The layout file's text, the same every time for the same layout."""
    _check_names(layout, surfaces)
    lines = list(level.header) + [
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
        ("pieces", [(".piece", _piece_arguments(piece)) for piece in layout.pieces]),
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


# MARK: - The surface palette

_FINISH = re.compile(
    r"\.(\w+):\s*\.finish\(\s*color:\s*" + _LIST + r"\s*,\s*roughness:\s*" + _NUMBER
    + r"\s*(?:,\s*metallic:\s*" + _NUMBER + r"\s*)?\)"
)


#: All that may come before the palette's first entry.
_PALETTE_SCAFFOLD = re.compile(
    r"\s*enum\s+Surfaces\s*\{\s*static\s+let\s+palette\s*:\s*\[\s*Level\.Surface\s*:\s*"
    r"Level\.Finish\s*\]\s*=\s*\[\s*"
)


def parse_palette(text):
    """Read the palette file: each surface's finish, in the file's order. Anything that is not
    read exactly raises, so Save never drops it."""
    code = re.sub(r"//[^\n]*", "", text)
    matches = list(_FINISH.finditer(code))
    written = code.count(".finish(")
    if len(matches) != written:
        raise LayoutError(
            f"{written - len(matches)} surface or surfaces in the palette could not be read. "
            f"Write each as the others are.")
    scaffold = re.fullmatch(_PALETTE_SCAFFOLD, code[:matches[0].start()] if matches else code)
    unread = _unread(code[matches[0].start():], [
        (match.start() - matches[0].start(), match.end() - matches[0].start()) for match in matches
    ]) if matches else ""
    if scaffold is None or unread:
        raise LayoutError(
            "The palette file holds something the script cannot read. Keep it as `enum Surfaces` "
            "with one `.surface: .finish(...)` entry for each surface.")
    palette = {}
    for name, colour, roughness, metallic in (match.groups() for match in matches):
        if name in palette:
            raise LayoutError(f"The palette has two finishes for {name}.")
        palette[name] = Finish(_numbers(colour, 3, name), float(roughness), float(metallic or 0))
    problems = _palette_problems(palette)
    if problems:
        raise LayoutError(" ".join(problems))
    return palette


def _palette_problems(palette):
    problems = []
    for name in GAME_LOOKS:
        if name not in palette:
            problems.append(f"The palette needs {name}: the game draws vehicles and landmarks with it.")
    for name, finish in palette.items():
        if any(not 0 <= value <= 1 for value in finish.color):
            problems.append(f"{name}'s colour channels should be between 0 and 1.")
        if not 0 <= finish.roughness <= 1:
            problems.append(f"{name}'s roughness should be between 0 and 1.")
        if not 0 <= finish.metallic <= 1:
            problems.append(f"{name}'s metallic should be between 0 and 1.")
    return problems


def emit_palette(palette):
    """The palette file's text, the same every time for the same palette."""
    problems = _palette_problems(palette)
    if problems:
        raise LayoutError(" ".join(problems))
    lines = list(PALETTE_HEADER) + [
        "",
        "enum Surfaces {",
        "  static let palette: [Level.Surface: Level.Finish] = [",
    ]
    for name, finish in palette.items():
        arguments = [f"color: {_list(finish.color)}", f"roughness: {_number(finish.roughness)}"]
        if _number(finish.metallic) != "0":
            arguments.append(f"metallic: {_number(finish.metallic)}")
        lines += _call("    ", f".{name}: .finish", arguments, ",")
    lines += ["  ]", "}"]
    return "\n".join(lines) + "\n"


# MARK: - Changes made outside Blender


class FilesChanged(LayoutError):
    """The level's files changed since Blender last loaded or saved them, so a save would undo
    someone else's work: an agent's edit, a pull or a branch switch."""

    def __init__(self, changes):
        self.changes = changes
        shown = ", ".join(changes[:8]) + (", and more" if len(changes) > 8 else "")
        super().__init__(
            f"The level's files changed since your last Load or Save: {shown}. Load to take those "
            f"changes, or Save Anyway to replace them with what Blender holds.")


def _layout_entries(layout):
    """Each entry of a layout, in the file's order, by how a person would name it."""
    entries = {"the ground": layout.ground}
    for items in (layout.boxes, layout.landmarks, layout.areas, layout.markers, layout.pieces):
        entries.update({item.name: item for item in items})
    entries["the camera"] = layout.camera
    entries.update({light.name: light for light in layout.lights})
    return entries


def _differences(before, after, name=lambda key: key):
    """Which entries were changed, removed or added, in the order the files have them."""
    changes = []
    for key, value in before.items():
        if key not in after:
            changes.append(f"{name(key)} removed")
        elif after[key] != value:
            changes.append(f"{name(key)} changed")
    return changes + [f"{name(key)} added" for key in after if key not in before]


def changes_since(synced_layout, synced_palette, layout_text, palette_text):
    """What changed in the level's files since Blender last loaded or saved them, for a person to
    read; empty when nothing did."""
    changes = []
    if layout_text != synced_layout:
        try:
            found = _differences(_layout_entries(parse_layout(synced_layout)),
                                 _layout_entries(parse_layout(layout_text)))
        except LayoutError:
            found = ["the layout file, in a form the script cannot read"]
        changes += found or ["the layout file's comments or spacing"]
    if palette_text != synced_palette:
        try:
            found = _differences(parse_palette(synced_palette), parse_palette(palette_text),
                                 lambda name: f"the {name} surface")
        except LayoutError:
            found = ["the palette file, in a form the script cannot read"]
        changes += found or ["the palette file's comments or spacing"]
    return changes


# MARK: - Between Blender and the game


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


@dataclass
class Shape:
    """What Save reads from one Blender object, in Blender's coordinates."""
    name: str
    #: ground, box, landmark, area, marker or piece.
    role: str
    #: The object's world bounding box; for a marker, its location twice.
    minimum: tuple
    maximum: tuple
    surface: str = None
    #: Turned only in quarter turns about the vertical, and not mirrored.
    square: bool = True
    #: The mesh is still a box.
    cuboid: bool = True
    #: For a piece, which may be turned at any angle: its centre, its size along its own axes and
    #: its rotation (w, x, y, z), all in Blender's space.
    centre: tuple = None
    size: tuple = None
    rotation: tuple = IDENTITY
    mirrored: bool = False


@dataclass
class CameraShape:
    """The game camera as Blender holds it: from its target to the camera, and its field of
    view in degrees."""
    offset: tuple
    field_of_view: float


@dataclass
class LightShape:
    """What Save reads from one Blender light."""
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


@dataclass
class MaterialShape:
    """What Save reads from one Lauder material, as (scene-linear colour, roughness, metallic):
    its Principled BSDF, which renders and Material Preview show, and its viewport display
    settings, which Solid shading shows."""
    name: str
    node: tuple = None
    viewport: tuple = None


_TOLERANCE = 0.005
#: Half the last place that a colour, roughness or metallic is written to.
_FINISH_TOLERANCE = 0.0005


def _srgb(linear):
    """Scene-linear RGB as sRGB, each channel from 0 to 1."""
    def channel(value):
        value = min(max(value, 0.0), 1.0)
        return value * 12.92 if value <= 0.0031308 else 1.055 * value ** (1 / 2.4) - 0.055
    return tuple(channel(value) for value in linear[:3])


def _length(vector):
    return math.sqrt(sum(value * value for value in vector))


def _unit(vector):
    length = _length(vector) or 1.0
    return tuple(value / length for value in vector)


def _close(a, b, tolerance):
    return all(abs(x - y) <= tolerance for x, y in zip(a, b))


def _known(surface, surfaces):
    """Whether a box or piece has a Lauder surface: one of the palette's, when it is given."""
    return surface is not None and (surfaces is None or surface in surfaces)


def lights_from_shapes(shapes, previous):
    """The layout's lights from Blender's, and anything that stops a save. A value that Blender
    hands back unchanged is kept as written, so a save without edits changes nothing."""
    before = {light.name: light for light in previous}
    lights, problems = [], []
    for shape in shapes:
        if shape.kind != "SUN":
            problems.append(
                f"{shape.name} is a {shape.kind.lower()} light; the game has only sun lights so far.")
            continue
        old = before.get(shape.name)
        direction = _unit(from_blender(shape.direction))
        if old is not None and sum(a * b for a, b in zip(_unit(old.source), direction)) > 1 - 1e-6:
            source = old.source
        else:
            # Written at the length the file had, so that the numbers stay easy to read.
            length = _length(old.source) if old is not None else 10.0
            source = tuple(round(value * length, 2) for value in direction)
        colour = tuple(round(value, 3) for value in _srgb(shape.color))
        if old is not None and _close(colour, old.color, _FINISH_TOLERANCE):
            colour = old.color
        intensity = shape.energy / SUN_STRENGTH_PER_LUX
        if old is not None and abs(intensity - old.intensity) <= max(0.01, old.intensity * 1e-5):
            intensity = old.intensity
        else:
            intensity = round(intensity, 1)
        shadow = None
        if shape.shadow:
            shadow = (shape.shadow_distance or (old.shadow_distance if old is not None else None)
                      or DEFAULT_SHADOW_DISTANCE)
        lights.append(Light(shape.name, source, colour, intensity, shadow))
    return lights, problems


def finish_reading(finish):
    """A finish as each of a Lauder material's two settings holds it: (scene-linear colour,
    roughness, metallic). Load sets both to it, and so does Save once it has written the palette,
    so that the setting left stale by an edit cannot undo that edit at the next Save."""
    return (_linear(*finish.color)[:3], finish.roughness, finish.metallic)


def palette_from_shapes(shapes, previous):
    """The palette from Blender's Lauder materials. Each surface takes whichever of its settings
    was changed, the material's own or the viewport's; when Blender hands both back unchanged, or
    the material is gone, the finish stays as written."""
    readings = {shape.name: shape for shape in shapes}
    palette = {}
    for name, old in previous.items():
        finish = old
        shape = readings.get(name)
        for reading in (shape.node, shape.viewport) if shape is not None else ():
            if reading is None:
                continue
            colour, roughness, metallic = reading
            candidate = Finish(tuple(round(value, 3) for value in _srgb(colour)),
                               round(roughness, 3), round(metallic, 3))
            if not (_close(candidate.color, old.color, _FINISH_TOLERANCE)
                    and abs(candidate.roughness - old.roughness) <= _FINISH_TOLERANCE
                    and abs(candidate.metallic - old.metallic) <= _FINISH_TOLERANCE):
                finish = candidate
                break
        palette[name] = finish
    return palette


def layout_from_shapes(shapes, level, previous, camera=None, lights=None, surfaces=None):
    """Build a layout from what Blender holds, or raise with everything that must change first.

    `previous` is the layout last saved. Its landmarks, areas and markers carry the level's words
    in Swift, so none of them may disappear here. Without a camera or lights in Blender, the
    previous ones are kept. Given the palette's surfaces, every box and piece needs one of them.
    """
    problems = []
    ground, boxes, landmarks, areas, markers, pieces = [], [], [], [], [], []
    previous_pieces = {piece.name: piece for piece in previous.pieces} if previous else {}
    for shape in shapes:
        if shape.role == "piece":
            if not shape.cuboid:
                problems.append(f"{shape.name} is no longer a box; the game only has boxes.")
                continue
            if shape.mirrored:
                problems.append(f"{shape.name} is mirrored; scale it without negative values.")
                continue
            if not _known(shape.surface, surfaces):
                problems.append(
                    f"{shape.name} has no Lauder surface. Give it one of the Lauder materials.")
                continue
            if min(shape.size) <= 0:
                problems.append(f"{shape.name} is flat; give it some size.")
                continue
            rotation = rotation_from_blender(shape.rotation)
            # Keep a rotation as written when Blender hands it back unchanged, so that a save
            # without edits leaves the file alone.
            before = previous_pieces.get(shape.name)
            if before is not None and _same_rotation(before.rotation, rotation):
                rotation = before.rotation
            pieces.append(Piece(
                shape.name, from_blender(shape.centre), size_to_blender(shape.size),
                shape.surface, rotation))
            continue
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
            if not _known(shape.surface, surfaces):
                problems.append(
                    f"{shape.name} has no Lauder surface. Give it one of the Lauder materials.")
                continue
            if shape.role == "ground" and abs(high[2]) > _TOLERANCE:
                problems.append(f"The deck's top should be at height 0, not {_number(high[2])}.")
            if shape.role == "box" and abs(low[2]) > _TOLERANCE:
                problems.append(
                    f"{shape.name} should stand on the deck: its base is at {_number(low[2])} m.")
            item = Box(
                shape.name, (centre[0], centre[2], -centre[1]),
                (extent[0], extent[2], extent[1]), shape.surface)
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
            problems.append(f"{shape.name} is in an unknown part of the layout, {shape.role}.")
    if len(ground) != 1:
        problems.append(f"The layout needs exactly one ground box, not {len(ground)}.")
    names = {
        "box": {item.name for item in boxes},
        "landmark": {item.name for item in landmarks},
        "area": {item.name for item in areas},
        "marker": {item.name for item in markers},
    }
    for name in level.required_boxes:
        if name not in names["box"]:
            problems.append(f"The box {name} is missing; the game needs it.")
    if previous is not None:
        for kind, items in (
            ("landmark", previous.landmarks), ("area", previous.areas),
            ("marker", previous.markers),
        ):
            for item in items:
                if item.name not in names[kind]:
                    problems.append(
                        f"The {kind} {item.name} is missing. The level's words in Swift refer to "
                        f"it, so remove it there first.")
    if camera is not None:
        saved_camera = Camera(from_blender(camera.offset), camera.field_of_view)
    else:
        saved_camera = previous.camera if previous is not None else None
    if lights is not None:
        saved_lights, light_problems = lights_from_shapes(
            lights, previous.lights if previous is not None else [])
        problems += light_problems
    else:
        saved_lights = previous.lights if previous is not None else []
    if problems:
        raise LayoutError(" ".join(problems))
    layout = Layout(
        ground[0], boxes, landmarks, areas, markers, pieces, saved_camera, saved_lights)
    _check_names(layout, surfaces)
    return layout


# MARK: - The game's details on vehicles and landmarks


def details(box_or_landmark, kind):
    """The parts the game draws for a vehicle box or a landmark (SceneStyle.vehicle and
    SceneStyle.landmark), as (name, centre, size, look) relative to the box's centre in the
    game's space. Blender shows them so that it looks like the game; they are not saved."""
    size = box_or_landmark.size
    sx, sy, sz = size
    if kind == "landmark":
        return [("band", (0, -sy * 0.27, 0), (sx * 0.85, sy * 0.15, sz * 1.03), "paint")]
    along_z = sz >= sx
    length = max(sx, sz)
    if sy > 2:
        band = (sx + 0.02, 0.5, length * 0.9) if along_z else (length * 0.9, 0.5, sz + 0.02)
        return [("body", (0, 0, 0), size, "vehicle"), ("windows", (0, sy * 0.25, 0), band, "glass")]
    lower = sy * 0.55
    if along_z:
        cabin = (sx * 0.9, sy - lower, length * 0.5)
    else:
        cabin = (length * 0.5, sy - lower, sz * 0.9)
    return [
        ("body", (0, (lower - sy) / 2, 0), (sx, lower, sz), "vehicle"),
        ("cabin", (0, (sy - cabin[1]) / 2, 0), cabin, "glass"),
    ]


#: The party's stand-ins as SceneStyle.partyMember draws them: clothing colour (sRGB) and width.
#: Blender shows them at their start markers, so keep the two in step.
PARTY = {
    "miki": ((0.25, 0.65, 0.59), 0.38),
    "tom": ((0.38, 0.51, 0.81), 0.49),
    "laura": ((0.9, 0.61, 0.29), 0.31),
}
#: The stand-ins' other colours in SceneStyle: the head, the legs and the front mark.
FIGURE_COLOURS = {"head": (0.65, 0.68, 0.55), "gear": (0.16, 0.25, 0.25), "front": (0.62, 0.87, 0.77)}
#: The height of a stand-in's centre above the floor.
FIGURE_CENTRE = CAMERA_TARGET_HEIGHT - 0.1


def figure(member):
    """A stand-in's parts as SceneStyle.standIn draws it, facing Manhattan: (name, centre, size,
    look) in the game's space, from the floor below the stand-in. Blender shows one at each spawn
    marker; it follows the marker and is not saved."""
    _, width = PARTY[member]
    centre = FIGURE_CENTRE
    parts = [
        ("body", (0, centre + 0.04, 0), (width, 0.72, 0.3), member),
        ("head", (0, centre + 0.57, 0), (0.32, 0.32, 0.32), "head"),
        ("front", (0, centre + 0.12, -0.16), (0.15, 0.2, 0.025), "front"),
    ]
    for number, side in ((1, -1), (2, 1)):
        parts += [
            (f"leg {number}", (side * 0.105, centre - 0.55, 0), (0.13, 0.55, 0.18), "gear"),
            (f"foot {number}", (side * 0.105, centre - 0.8, -0.04), (0.18, 0.1, 0.28), member),
        ]
    return parts


# MARK: - The level's scene file (ADR 0006)


def usd_name(name):
    """The name an object takes in a USD file, where only letters, digits and underscores are
    allowed: `car-a1` becomes `car_a1`. The game finds the scene's parts by these names."""
    safe = re.sub(r"[^A-Za-z0-9_]", "_", name)
    return "_" + safe if safe[:1].isdigit() else safe


@dataclass(frozen=True)
class ScenePart:
    """One block that the game shows, with its centre and size in the game's space, in metres."""
    name: str
    centre: tuple
    size: tuple
    surface: str
    rotation: tuple = IDENTITY


def _plus(a, b):
    return tuple(x + y for x, y in zip(a, b))


def scene_parts(layout):
    """Everything the game shows of a level, as its code drew it from the layout before the scene
    file: the ground and each box; a vehicle as the body and windows inside its box, which only
    blocks; each landmark in metal, with its painted band; and each piece, turned."""
    ground = layout.ground
    parts = [ScenePart(ground.name, ground.position, ground.size, ground.surface)]
    for box in layout.boxes:
        if box.surface != "vehicle":
            parts.append(ScenePart(box.name, box.position, box.size, box.surface))
            continue
        for part, offset, size, look in details(box, "vehicle"):
            parts.append(ScenePart(f"{box.name} {part}", _plus(box.position, offset), size, look))
    for landmark in layout.landmarks:
        x, y, z = landmark.position
        centre = (x, y + landmark.size[1] / 2, z)
        parts.append(ScenePart(landmark.name, centre, landmark.size, "metal"))
        for part, offset, size, look in details(landmark, "landmark"):
            parts.append(ScenePart(f"{landmark.name} {part}", _plus(centre, offset), size, look))
    for piece in layout.pieces:
        parts.append(ScenePart(piece.name, piece.position, piece.size, piece.surface,
                               piece.rotation))
    names = [usd_name(part.name) for part in parts]
    clashes = sorted({name for name in names if names.count(name) > 1})
    if clashes:
        raise LayoutError(f"These names would be the same in the scene file: {', '.join(clashes)}.")
    return parts


_LFS_POINTER = b"version https://git-lfs.github.com/spec/v1"


def file_fingerprint(path):
    """A file's SHA-256, in hex. A Git LFS pointer stands for its file, so it gives the file's."""
    data = Path(path).read_bytes()
    if data.startswith(_LFS_POINTER):
        found = re.search(rb"oid sha256:([0-9a-f]{64})", data)
        if found:
            return found.group(1).decode()
    return hashlib.sha256(data).hexdigest()


def scene_inputs(repository, level):
    """What the level's scene file is made from: its layout file and the palette, each with its
    fingerprint."""
    root = Path(repository)
    return {name: file_fingerprint(root / name) for name in (level.path, PALETTE_PATH)}


def _scene_records(repository):
    path = Path(repository) / SCENE_RECORD
    try:
        return json.loads(path.read_text()) if path.exists() else {}
    except ValueError:
        return {}  # Unreadable: every scene file counts as stale, and the next export rewrites it.


def stale_scene(repository, key="brooklyn-bridge"):
    """Why the level's scene file no longer matches what it is made from, or None when it does."""
    level = LEVELS[key]
    record = _scene_records(repository).get(level.scene)
    if record is None or not (Path(repository) / level.scene).exists():
        return f"{level.scene} has not been exported."
    if record.get("format") != SCENE_FORMAT:
        return f"{level.scene} was exported by an earlier version of the Lauder extension."
    made_from = record.get("made from", {})
    for name, fingerprint in scene_inputs(repository, level).items():
        if made_from.get(name) != fingerprint:
            return f"{name} changed since {level.scene} was exported."
    if record.get("fingerprint") != file_fingerprint(Path(repository) / level.scene):
        return f"{level.scene} changed since it was exported."
    return None


def record_scene(repository, level, inputs):
    """Record what the level's scene file, just exported, was made from."""
    records = _scene_records(repository)
    records[level.scene] = {
        "format": SCENE_FORMAT,
        "made from": inputs,
        "fingerprint": file_fingerprint(Path(repository) / level.scene),
    }
    path = Path(repository) / SCENE_RECORD
    path.write_text(json.dumps(records, indent=2, sort_keys=True) + "\n")


# MARK: - Blender


def _linear(red, green, blue):
    def channel(value):
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
    return (channel(red), channel(green), channel(blue), 1.0)


#: The areas' colour. The game does not draw areas, so only Blender has it.
AREA_COLOUR = (1.0, 0.75, 0.4)
_EDITABLE = (
    ("ground", "Ground"), ("box", "Boxes"), ("landmark", "Landmarks"), ("area", "Areas"),
    ("marker", "Markers"), ("piece", "Pieces"),
)
#: A phone's screen in landscape, for the game camera's frame: the baseline iPhone 13 Pro Max.
_SCREEN = (2778, 1284)
#: How far from the camera's target Load puts each sun, so that it is easy to find and turn. A
#: sun's place does not change its light.
_SUN_DISTANCE = 8


def _principled(material, create=False):
    """The material's Principled BSDF, giving the material nodes first when asked. Only a material
    without nodes, made by Blender before 5, needs `use_nodes`, which Blender 6 removes."""
    tree = material.node_tree
    if tree is None and create:
        material.use_nodes = True
        tree = material.node_tree
    if tree is None:
        return None
    return next((node for node in tree.nodes if node.type == "BSDF_PRINCIPLED"), None)


def _material(name, palette):
    """The Blender material for a surface, set to its finish in the palette: its Principled BSDF,
    which Material Preview and renders show, and its viewport display, which Solid shading
    shows."""
    material = bpy.data.materials.get(f"Lauder {name}")
    if material is None:
        material = bpy.data.materials.new(f"Lauder {name}")
    material["lauder_surface"] = name
    _apply_finish(material, palette[name])
    return material


def _apply_finish(material, finish):
    """Set both of a Lauder material's settings to the finish (finish_reading)."""
    colour, roughness, metallic = finish_reading(finish)
    material.diffuse_color = colour + (1.0,)
    material.roughness = roughness
    material.metallic = metallic
    node = _principled(material, create=True)
    if node is not None:
        node.inputs["Base Color"].default_value = colour + (1.0,)
        node.inputs["Roughness"].default_value = roughness
        node.inputs["Metallic"].default_value = metallic


def _display_material(name, colour):
    """A material that only Blender shows, such as the areas' or the party's, in an sRGB colour."""
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
    # Earlier versions of this script tagged the areas' material like a surface; it has none.
    if "lauder_surface" in material:
        del material["lauder_surface"]
    linear = _linear(*colour)
    material.diffuse_color = linear
    node = _principled(material, create=True)
    if node is not None:
        node.inputs["Base Color"].default_value = linear
        node.inputs["Roughness"].default_value = 1.0
    return material


def _area_material():
    return _display_material("Lauder area", AREA_COLOUR)


def _figure_material(look):
    colour = PARTY[look][0] if look in PARTY else FIGURE_COLOURS[look]
    return _display_material(f"Lauder figure {look}", colour)


def _sphere(name):
    """A sphere one unit across, as the game's stand-ins have for a head."""
    mesh = bpy.data.meshes.new(name)
    shape = bmesh.new()
    bmesh.ops.create_uvsphere(shape, u_segments=16, v_segments=8, radius=0.5)
    shape.to_mesh(mesh)
    shape.free()
    mesh["lauder"] = True
    return mesh


def _cube(name):
    mesh = bpy.data.meshes.new(name)
    corners = [(x, y, z) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    mesh.from_pydata(corners, [], faces)
    mesh.update()
    mesh["lauder"] = True
    return mesh


def _level_collection(level):
    for collection in bpy.data.collections:
        if collection.get("lauder_level") == level.key:
            return collection
    return None


def _part(level, role):
    """One of the level's collections, by role."""
    root = _level_collection(level)
    for part in root.children if root is not None else []:
        if part.get("lauder_role") == role:
            return part
    return None


def _remove(collection):
    for child in list(collection.children):
        _remove(child)
    for item in list(collection.objects):
        data = item.data
        bpy.data.objects.remove(item, do_unlink=True)
        if data is not None and data.users == 0 and data.get("lauder"):
            if isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)
            elif isinstance(data, bpy.types.Camera):
                bpy.data.cameras.remove(data)
            elif isinstance(data, bpy.types.Light):
                bpy.data.lights.remove(data)
    bpy.data.collections.remove(collection)


def build_in_blender(layout, level, palette):
    """Replace the level's collection in the open Blender file with this layout, its surfaces
    made from the palette."""
    old = _level_collection(level)
    if old is not None:
        _remove(old)
    scene = bpy.context.scene
    root = bpy.data.collections.new(f"Lauder {level.title}")
    root["lauder_level"] = level.key
    scene.collection.children.link(root)
    parts = {}
    for role, title in _EDITABLE + (
        ("detail", "Details"), ("camera", "Game camera"), ("light", "Lights"),
    ):
        part = bpy.data.collections.new(f"{level.title} {title}")
        part["lauder_role"] = role
        root.children.link(part)
        parts[role] = part
    parts["detail"].hide_select = True

    def block(name, role, centre, size, material, rotation=None):
        item = bpy.data.objects.new(name, _cube(name))
        item.location = centre
        if rotation is not None:
            # Shown as angles in degrees, as on every other object; Save reads the transform.
            item.rotation_euler = Quaternion(rotation).to_euler("XYZ")
        item.scale = size
        item.data.materials.append(material)
        parts[role].objects.link(item)
        return item

    def add_details(owner, box, kind):
        for part_name, offset, part_size, look in details(box, kind):
            name = f"{owner.name} {part_name}"
            detail = bpy.data.objects.new(name, _cube(name))
            detail.data.materials.append(_material(look, palette))
            parts["detail"].objects.link(detail)
            detail.parent = owner
            # The owner's scale is its size, so the detail is placed in fractions of it.
            ox, oy, oz = to_blender(tuple(o / s for o, s in zip(offset, box.size)))
            detail.location = (ox, oy, oz)
            detail.scale = size_to_blender(tuple(p / s for p, s in zip(part_size, box.size)))
            detail.hide_select = True

    def add_figure(marker, member):
        # The party as the game draws it at the start, following its marker, and not saved.
        for part_name, offset, part_size, look in figure(member):
            name = f"{member} {part_name}"
            part = bpy.data.objects.new(name, _sphere(name) if part_name == "head" else _cube(name))
            part.data.materials.append(_figure_material(look))
            parts["detail"].objects.link(part)
            part.parent = marker
            part.location = to_blender(offset)
            part.scale = size_to_blender(part_size)
            part.hide_select = True

    block(layout.ground.name, "ground", to_blender(layout.ground.position),
          size_to_blender(layout.ground.size), _material(layout.ground.surface, palette))
    for box in layout.boxes:
        item = block(box.name, "box", to_blender(box.position), size_to_blender(box.size),
                     _material(box.surface, palette))
        if box.surface == "vehicle":
            # The game draws a vehicle as a body and windows inside its box: show those, and the
            # box that blocks movement and sight as an outline around them.
            item.display_type = "WIRE"
            add_details(item, box, "vehicle")
    for landmark in layout.landmarks:
        x, y, z = landmark.position
        # The game draws a landmark in metal, with a painted band.
        item = block(landmark.name, "landmark", to_blender((x, y + landmark.size[1] / 2, z)),
                     size_to_blender(landmark.size), _material("metal", palette))
        item.show_name = True
        add_details(item, landmark, "landmark")
    for area in layout.areas:
        (x0, z0), (x1, z1) = area.minimum, area.maximum
        item = block(area.name, "area", ((x0 + x1) / 2, -(z0 + z1) / 2, 0.025),
                     (x1 - x0, z1 - z0, 0.05), _area_material())
        item.display_type = "WIRE"
        item.show_name = True
    for marker in layout.markers:
        item = bpy.data.objects.new(marker.name, None)
        item.empty_display_type = "PLAIN_AXES"
        item.empty_display_size = 0.6
        item.show_name = True
        item.location = (marker.position[0], -marker.position[1], 0)
        parts["marker"].objects.link(item)
        member = marker.name.removeprefix("spawn.")
        if marker.name.startswith("spawn.") and member in PARTY:
            add_figure(item, member)
    for piece in layout.pieces:
        block(piece.name, "piece", to_blender(piece.position), size_to_blender(piece.size),
              _material(piece.surface, palette), rotation_to_blender(piece.rotation))
    _build_camera(layout, level, parts["camera"])
    _build_lights(layout, level, parts["light"])
    scene.view_settings.view_transform = "Standard"
    return root


def _camera_start(layout, level):
    """Where the camera's target starts: just above the marker that the level names."""
    start = next((m.position for m in layout.markers if m.name == level.camera_target), (0, 0))
    return (start[0], -start[1], CAMERA_TARGET_HEIGHT)


def _build_camera(layout, level, collection):
    """The game camera: a target to drag anywhere on the level, and the camera at the game's
    offset from it, looking at it with the game's field of view."""
    target = bpy.data.objects.new("camera-target", None)
    target.empty_display_type = "SPHERE"
    target.empty_display_size = 0.3
    target.show_name = True
    target["lauder_rig"] = "target"
    target.location = _camera_start(layout, level)
    collection.objects.link(target)
    data = bpy.data.cameras.new("game-camera")
    data["lauder"] = True
    data.sensor_fit = "VERTICAL"
    data.lens_unit = "FOV"
    data.angle_y = math.radians(layout.camera.field_of_view)
    data.clip_end = 1000
    camera = bpy.data.objects.new("game-camera", data)
    camera["lauder_rig"] = "camera"
    collection.objects.link(camera)
    camera.parent = target
    camera.location = to_blender(layout.camera.offset)
    look = camera.constraints.new("TRACK_TO")
    look.target = target
    look.track_axis = "TRACK_NEGATIVE_Z"
    look.up_axis = "UP_Y"
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y = _SCREEN


def _build_lights(layout, level, collection):
    """The lights, as Blender suns. A sun shines along its own -z, so each is turned to shine from
    its source, and placed above the camera's target in that direction."""
    start = Vector(_camera_start(layout, level))
    for light in layout.lights:
        data = bpy.data.lights.new(light.name, type="SUN")
        data["lauder"] = True
        data.color = _linear(*light.color)[:3]
        data.energy = light.intensity * SUN_STRENGTH_PER_LUX
        data.use_shadow = light.shadow_distance is not None
        if light.shadow_distance is not None:
            data["lauder_shadow_distance"] = light.shadow_distance
        item = bpy.data.objects.new(light.name, data)
        direction = Vector(to_blender(light.source)).normalized()
        item.rotation_euler = Vector((0, 0, 1)).rotation_difference(direction).to_euler("XYZ")
        item.location = start + direction * _SUN_DISTANCE
        item.show_name = True
        collection.objects.link(item)


def _rig(level):
    part = _part(level, "camera")
    if part is not None:
        items = {item.get("lauder_rig"): item for item in part.objects}
        if "target" in items and "camera" in items:
            return items["target"], items["camera"]
    return None


def shapes_from_blender(level):
    """Read the level's collection in the open Blender file."""
    root = _level_collection(level)
    if root is None:
        raise LayoutError(f"This Blender file has no {level.title}; Load it first.")
    # Bring every object's place up to date, as the interface does between clicks, so that a
    # Save run straight after a Load or a script's edits reads where things are.
    bpy.context.view_layer.update()
    editable = {role for role, _ in _EDITABLE}
    shapes = []
    for part in root.children:
        role = part.get("lauder_role")
        if role not in editable:
            continue
        for item in part.objects:
            if role == "marker":
                if item.type != "EMPTY":
                    raise LayoutError(f"{item.name} is in Markers but is not an empty.")
                location = tuple(item.matrix_world.translation)
                shapes.append(Shape(item.name, role, location, location))
                continue
            if item.type != "MESH":
                raise LayoutError(f"{item.name} is in {part.name} but is not a mesh box.")
            local = [tuple(corner) for corner in item.bound_box]
            vertices = [tuple(vertex.co) for vertex in item.data.vertices]
            cuboid = len(vertices) == 8 and all(
                any(all(abs(a - b) < 1e-4 for a, b in zip(vertex, corner)) for corner in local)
                for vertex in vertices)
            surface = None
            if item.material_slots and item.material_slots[0].material is not None:
                surface = item.material_slots[0].material.get("lauder_surface")
            _, rotation, scale = item.matrix_world.decompose()
            if role == "piece":
                low = Vector(tuple(min(c[axis] for c in local) for axis in range(3)))
                high = Vector(tuple(max(c[axis] for c in local) for axis in range(3)))
                centre = item.matrix_world @ ((low + high) / 2)
                size = tuple(abs((high[axis] - low[axis]) * scale[axis]) for axis in range(3))
                mirrored = item.matrix_world.to_3x3().determinant() < 0
                shapes.append(Shape(
                    item.name, role, tuple(centre), tuple(centre), surface, True, cuboid,
                    centre=tuple(centre), size=size, rotation=tuple(rotation), mirrored=mirrored))
                continue
            corners = [item.matrix_world @ Vector(corner) for corner in item.bound_box]
            low = tuple(min(corner[axis] for corner in corners) for axis in range(3))
            high = tuple(max(corner[axis] for corner in corners) for axis in range(3))
            matrix = rotation.to_matrix()
            square = all(value > 0 for value in scale) and abs(matrix[2][2] - 1) < 1e-4 and all(
                min(abs(matrix[row][column]), abs(abs(matrix[row][column]) - 1)) < 1e-4
                for row in range(3) for column in range(3))
            shapes.append(Shape(item.name, role, low, high, surface, square, cuboid))
    return shapes


def camera_from_blender(level):
    """The game camera's offset and field of view, or None when the rig is gone."""
    rig = _rig(level)
    if rig is None:
        return None
    target, camera = rig
    if camera.data.sensor_fit != "VERTICAL":
        raise LayoutError("Keep the game camera's Sensor Fit at Vertical; Load again to reset it.")
    offset = camera.matrix_world.translation - target.matrix_world.translation
    return CameraShape(tuple(offset), math.degrees(camera.data.angle_y))


def lights_from_blender(level):
    """What Save reads from the level's lights, or None when the Lights collection is gone."""
    part = _part(level, "light")
    if part is None:
        return None
    shapes = []
    for item in part.objects:
        if item.type != "LIGHT":
            raise LayoutError(f"{item.name} is in Lights but is not a light.")
        data = item.data
        direction = item.matrix_world.to_quaternion() @ Vector((0, 0, 1))
        distance = data.get("lauder_shadow_distance")
        shapes.append(LightShape(
            item.name, data.type, tuple(direction), tuple(data.color), data.energy,
            data.use_shadow, None if distance is None else float(distance)))
    return shapes


def lights_outside_the_level(level, view_layer):
    """The visible lights that are not in the level's Lights, such as the one in Blender's default
    scene. Game Look would show them, but the game has no such light: Save neither writes them
    nor counts them against the budget."""
    part = _part(level, "light")
    own = {item.name for item in part.objects} if part is not None else set()
    return [item.name for item in view_layer.objects
            if item.type == "LIGHT" and item.name not in own
            and item.visible_get(view_layer=view_layer)]


def palette_from_blender(previous):
    """The palette as the Lauder materials hold it. A surface whose material is gone keeps its
    finish."""
    shapes = []
    for name in previous:
        material = bpy.data.materials.get(f"Lauder {name}")
        if material is None:
            continue
        node = _principled(material)
        reading = None
        if node is not None:
            reading = (tuple(node.inputs["Base Color"].default_value),
                       node.inputs["Roughness"].default_value,
                       node.inputs["Metallic"].default_value)
        viewport = (tuple(material.diffuse_color), material.roughness, material.metallic)
        shapes.append(MaterialShape(name, reading, viewport))
    return palette_from_shapes(shapes, previous)


def _files(repository, level):
    """The text of the level's layout file and of the palette."""
    root = Path(repository)
    return (root / level.path).read_text(), (root / PALETTE_PATH).read_text()


def _synced(level):
    """The text of the level's files when Blender last loaded or saved them, or None for a level
    loaded by an earlier version of this script."""
    root = _level_collection(level)
    if root is None or "_lauder_synced_layout" not in root:
        return None
    return root["_lauder_synced_layout"], root["_lauder_synced_palette"]


def _remember(level, layout_text, palette_text):
    """Record the text of the level's files as Blender now holds them, on the level's collection,
    under names that Blender's interface does not show."""
    root = _level_collection(level)
    root["_lauder_synced_layout"] = layout_text
    root["_lauder_synced_palette"] = palette_text


def _scene_level(scene):
    """The repository and the level that the scene's Lauder settings name, or None."""
    repository = bpy.path.abspath(getattr(scene, "lauder_repository", "") or "")
    level = LEVELS.get(getattr(scene, "lauder_level", ""))
    return (repository, level) if repository and level is not None else None


def is_working_file(scene):
    """Whether the open Blender file is the working file of the level that the scene names."""
    named = _scene_level(scene)
    if named is None or not bpy.data.filepath:
        return False
    return Path(bpy.data.filepath).resolve() == working_file(*named).resolve()


def _holds_unsaved_edits(level, synced):
    """Whether Blender holds level edits that were never written to the files it last synced.
    Both sides are compared as Save writes them, so the synced files' own comments and spacing
    do not count as edits."""
    try:
        synced_palette = parse_palette(synced[1])
        synced_layout = parse_layout(synced[0])
        palette = palette_from_blender(synced_palette)
        surfaces = set(palette)
        layout = layout_from_shapes(
            shapes_from_blender(level), level, synced_layout, camera_from_blender(level),
            lights_from_blender(level), surfaces)
        unsaved = emit_layout(layout, level, surfaces) != emit_layout(synced_layout, level)
    except LayoutError:
        return True
    return unsaved or emit_palette(palette) != emit_palette(synced_palette)


def refresh(scene):
    """Bring a reopened working file up to date with the level's files. When they changed while
    it was closed, Blender loads them again, unless the file holds level edits never saved to
    them; then it raises FilesChanged and leaves the choice to the person. Returns what it did."""
    repository, level = _scene_level(scene)
    texts = _files(repository, level)
    if _level_collection(level) is None:
        load_level(repository, level.key)
        return f"Loaded {level.title} from its files."
    synced = _synced(level)
    if synced is None or tuple(synced) == texts:
        return None
    changes = changes_since(*synced, *texts)
    if _holds_unsaved_edits(level, synced):
        raise FilesChanged(changes)
    load_level(repository, level.key)
    return ("The level's files changed while this file was closed, so Blender loaded them again: "
            + ", ".join(changes[:8]) + ".")


def make_working_file(repository, key):
    """Start the level's working file: an empty Blender file holding just the level."""
    bpy.ops.wm.read_homefile(use_empty=True)
    scene = bpy.context.scene
    scene.lauder_repository = repository
    scene.lauder_level = key
    load_level(repository, key)
    path = working_file(repository, LEVELS[key])
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    return path


#: Blender's USD export for a scene file: the game's axes (y up, metres), each object as one
#: prim, the materials as preview surfaces, and nothing that the game makes itself.
SCENE_EXPORT = {
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
}


def build_scene(layout, palette):
    """Build everything the game shows of the level (scene_parts) in the open Blender file."""
    for part in scene_parts(layout):
        name = usd_name(part.name)
        item = bpy.data.objects.new(name, _cube(name))
        item.location = to_blender(part.centre)
        if not is_identity(part.rotation):
            item.rotation_euler = Quaternion(rotation_to_blender(part.rotation)).to_euler("XYZ")
        item.scale = size_to_blender(part.size)
        material = _material(part.surface, palette)
        # The blocks are closed, so their inside never shows: single-sided, as the game drew them.
        material.use_backface_culling = True
        item.data.materials.append(material)
        bpy.context.scene.collection.objects.link(item)


def export_scene(repository, key="brooklyn-bridge"):
    """Write the level's scene file from its layout file and the palette, and record what it was
    made from. It empties the open Blender file first, so it runs in a Blender of its own:
    blender/scripts/export-scene.py."""
    level = LEVELS[key]
    root = Path(repository)
    # Fingerprinted as read, so that a file changed during the export makes the scene stale.
    texts = {name: (root / name).read_bytes() for name in (level.path, PALETTE_PATH)}
    inputs = {name: hashlib.sha256(data).hexdigest() for name, data in texts.items()}
    palette = parse_palette(texts[PALETTE_PATH].decode())
    layout = parse_layout(texts[level.path].decode(), set(palette))
    bpy.ops.wm.read_homefile(use_empty=True)
    build_scene(layout, palette)
    target = root / level.scene
    with tempfile.TemporaryDirectory() as folder:
        written = Path(folder) / target.name
        bpy.ops.wm.usd_export(filepath=str(written), **SCENE_EXPORT)
        shutil.copyfile(written, target)
    record_scene(repository, level, inputs)
    return target


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


#: Work running in the background, one step after another, so that Blender stays usable: the
#: steps still to run; the running step's name, process, log and log's path; the repository and
#: level the work is for; and how often it exported the scene file again because the level's
#: files changed while it ran.
_JOB = {"steps": [], "name": None, "process": None, "log": None, "path": None,
        "repository": None, "key": None, "refreshes": 0}
#: What each background step says when it finishes well.
_FINISHED = {
    "export": "Exported the scene file. The game shows it from the next build.",
    "play": "The game is running in the Simulator.",
}
#: How often one run of background work exports the scene file again while the level's files keep
#: changing, so that it cannot go on for ever.
MOST_REFRESHES = 3


def _export_step(repository, key):
    """The background step that exports the level's scene file in a Blender of its own."""
    blender = bpy.app.binary_path if bpy is not None else "blender"
    return ("export", [
        blender, "-b", "--factory-startup", "--python-exit-code", "1",
        "--python", str(Path(repository) / EXPORT_SCRIPT), "--", key,
    ], "export.log")


def background_steps(repository, key, play):
    """The background steps that Save (play=False) or Play needs: exporting the level's scene file
    when it no longer matches the level's files, then, for Play, building and opening the game.
    Each is (name, command, log)."""
    steps = [_export_step(repository, key)] if stale_scene(repository, key) is not None else []
    if play:
        steps.append(("play", [sys.executable, "-I", str(Path(repository) / PLAY_SCRIPT)],
                      "play.log"))
    return steps


def queue_steps(running, waiting, steps):
    """The steps to add after the background work already running and waiting. An export already
    running or waiting stands in for a new one, which could only race it for the same files: when
    it finishes, the scene file's freshness is checked again (refresh_needed)."""
    names = ([running] if running else []) + [name for name, _, _ in waiting]
    if "export" in names:
        return [step for step in steps if step[0] != "export"]
    return list(steps)


def refresh_needed(waiting, stale, refreshes):
    """Whether to export the scene file again before going on, once a step has finished well:
    when the level's files changed while it ran, such as by a second save, and no export is next
    anyway."""
    upcoming = waiting[0][0] if waiting else None
    return stale and upcoming != "export" and refreshes < MOST_REFRESHES


def _start_job(repository, key, steps):
    """Run the steps in the background, in order, stopping at the first that fails."""
    _JOB.update(steps=list(steps), repository=repository, key=key, refreshes=0)
    _next_step()
    # Persistent, so that opening another Blender file, such as the working file, keeps watching.
    bpy.app.timers.register(_watch_job, first_interval=1.0, persistent=True)


def _next_step():
    name, command, log_name = _JOB["steps"].pop(0)
    path = Path(_JOB["repository"]) / ".local/play" / log_name
    path.parent.mkdir(parents=True, exist_ok=True)
    log = path.open("w")
    process = subprocess.Popen(command, cwd=_JOB["repository"], stdout=log,
                               stderr=subprocess.STDOUT)
    _JOB.update(name=name, process=process, log=log, path=path)


def _job_running():
    """Whether background work is still running. Work that stopped while nothing watched it is
    finished off here, so that Save and Play are never stuck."""
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
    name, path = _JOB["name"], _JOB["path"]
    if process.returncode == 0:
        try:
            stale = stale_scene(_JOB["repository"], _JOB["key"]) is not None
        except (OSError, ValueError):
            stale = False
        if refresh_needed(_JOB["steps"], stale, _JOB["refreshes"]):
            _JOB["steps"].insert(0, _export_step(_JOB["repository"], _JOB["key"]))
            _JOB["refreshes"] += 1
        if _JOB["steps"]:
            try:
                _next_step()
            except OSError as error:
                _JOB["steps"] = []
                _announce(f"The next step could not start: {error}", error=True)
                return None
            return 0.5
        _announce(_FINISHED[name])
        return None
    _JOB["steps"] = []
    lines = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    detail = " ".join(lines[-3:])
    what = "The scene's export" if name == "export" else "Play"
    _announce(f"{what} failed{': ' + detail if detail else '.'} The log is "
              f".local/play/{path.name}.", error=True)
    return None


def _queued(name):
    """Whether a background step of this name is running or waiting to run."""
    if not _job_running():
        return False
    return _JOB["name"] == name or any(step[0] == name for step in _JOB["steps"])


def _queue(repository, key, steps):
    """Run the steps in the background, after the work already running, if any (queue_steps)."""
    if _job_running():
        _JOB["steps"].extend(queue_steps(_JOB["name"], _JOB["steps"], steps))
    elif steps:
        _start_job(repository, key, steps)


def _export_if_stale(repository, key):
    """Export the level's scene file in the background when it no longer matches the level's
    files, after the work already running. Returns whether an export is running or waiting."""
    _queue(repository, key, background_steps(repository, key, play=False))
    return _queued("export")


def load_level(repository, key="brooklyn-bridge"):
    level = LEVELS[key]
    layout_text, palette_text = _files(repository, level)
    palette = parse_palette(palette_text)
    layout = parse_layout(layout_text, set(palette))
    build_in_blender(layout, level, palette)
    _remember(level, layout_text, palette_text)
    return layout


def save_level(repository, key="brooklyn-bridge", force=False):
    """Write what Blender holds to the level's layout file and the palette, after checking both:
    if anything fails, neither is written. Unless forced, it also refuses when the files changed
    since Blender last loaded or saved them. Returns the layout and the files that changed."""
    level = LEVELS[key]
    root = Path(repository)
    paths = {level.path: root / level.path, PALETTE_PATH: root / PALETTE_PATH}
    before = {name: path.read_text() for name, path in paths.items()}
    synced = _synced(level)
    if synced is not None and not force:
        changes = changes_since(*synced, before[level.path], before[PALETTE_PATH])
        if changes:
            raise FilesChanged(changes)
    # Blender's material edits are what changed since its last Load or Save, so they are found
    # against the palette as it was then, even when Save Anyway replaces a newer palette.
    palette = palette_from_blender(
        parse_palette(synced[1] if synced is not None else before[PALETTE_PATH]))
    surfaces = set(palette)
    previous = parse_layout(before[level.path])
    layout = layout_from_shapes(
        shapes_from_blender(level), level, previous, camera_from_blender(level),
        lights_from_blender(level), surfaces)
    after = {level.path: emit_layout(layout, level, surfaces), PALETTE_PATH: emit_palette(palette)}
    changed = [name for name in paths if after[name] != before[name]]
    for name in changed:
        paths[name].write_text(after[name])
    # Both settings of each material now hold what was written, so the one an edit did not touch
    # cannot undo that edit at the next Save.
    for name, finish in palette.items():
        material = bpy.data.materials.get(f"Lauder {name}")
        if material is not None:
            _apply_finish(material, finish)
    _remember(level, after[level.path], after[PALETTE_PATH])
    return layout, changed


def _guess_repository():
    """The repository this script was installed from, found by its folders."""
    try:
        here = Path(__file__).resolve()
    except NameError:
        return ""
    for folder in here.parents:
        if (folder / "apple" / "sources" / "content").is_dir():
            return str(folder)
    return ""


if bpy is not None:

    @persistent
    def _save_level_with_file(_):
        """Saving the level's working file saves the level's files too, after the usual checks.
        The Blender file is saved whatever they find."""
        scene = bpy.context.scene
        if not is_working_file(scene):
            return
        repository, level = _scene_level(scene)
        window_manager = bpy.context.window_manager
        try:
            _, changed = save_level(repository, level.key)
        except FilesChanged as error:
            window_manager.lauder_files_changed = True
            _announce(f"{error} The Blender file is saved.", error=True)
        except (LayoutError, OSError) as error:
            _announce(f"The Blender file is saved, but the level is not: {error}", error=True)
        else:
            window_manager.lauder_files_changed = False
            try:
                exporting = _export_if_stale(repository, level.key)
            except OSError as error:
                _announce(f"The level is saved, but its scene file could not be exported: {error}",
                          error=True)
                return
            said = [f"Saved {' and '.join(changed)} too."] if changed else []
            if exporting:
                said.append("Exporting the scene file…")
            if said:
                _announce(" ".join(said))

    @persistent
    def _refresh_opened_file(_):
        """Opening a level's working file brings it up to date with the level's files."""
        scene = bpy.context.scene
        if not is_working_file(scene):
            return
        window_manager = bpy.context.window_manager
        try:
            message = refresh(scene)
        except FilesChanged as error:
            window_manager.lauder_files_changed = True
            _announce(f"{error} This file also holds level edits that were never saved to them.",
                      error=True)
        except (LayoutError, OSError) as error:
            _announce(f"The level's files could not be checked: {error}", error=True)
        else:
            window_manager.lauder_files_changed = False
            window_manager.lauder_message = ""
            if message:
                _announce(message)

    class LAUDER_OT_open_level(bpy.types.Operator):
        """Open the level's working Blender file in .local/blender, making it from the level's
        files the first time. Saving it saves the level too"""
        bl_idname = "lauder.open_level"
        bl_label = "Open Level"
        bl_options = {"REGISTER"}

        def invoke(self, context, event):
            if bpy.data.is_dirty and not is_working_file(context.scene):
                return context.window_manager.invoke_confirm(
                    self, event, title="Open the level's working file?",
                    message="The open Blender file has unsaved changes, which this discards.")
            return self.execute(context)

        def execute(self, context):
            named = _scene_level(context.scene)
            if named is None:
                self.report({"ERROR"}, "Set the repository folder first.")
                return {"CANCELLED"}
            repository, level = named
            if is_working_file(context.scene):
                _refresh_opened_file(None)
                return {"FINISHED"}
            path = working_file(repository, level)
            if path.exists():
                # The load handler brings it up to date with the level's files.
                bpy.ops.wm.open_mainfile(filepath=str(path))
                return {"FINISHED"}
            try:
                made = make_working_file(repository, level.key)
            except (LayoutError, OSError) as error:
                _announce(f"The working file could not be made: {error}", error=True)
                return {"CANCELLED"}
            _announce(f"{level.title} is open in its working file, "
                      f"{made.relative_to(repository)}. Saving it saves the level too.")
            return {"FINISHED"}

    class LAUDER_OT_load_level(bpy.types.Operator):
        """Build the level in this Blender file from the game's layout file and surface palette"""
        bl_idname = "lauder.load_level"
        bl_label = "Load"
        bl_options = {"REGISTER"}

        def invoke(self, context, event):
            if _level_collection(LEVELS[context.scene.lauder_level]) is not None:
                return context.window_manager.invoke_confirm(self, event)
            return self.execute(context)

        def execute(self, context):
            window_manager = context.window_manager
            try:
                load_level(bpy.path.abspath(context.scene.lauder_repository),
                           context.scene.lauder_level)
            except (LayoutError, OSError) as error:
                window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            window_manager.lauder_files_changed = False
            window_manager.lauder_message = ""
            self.report({"INFO"}, f"Loaded {LEVELS[context.scene.lauder_level].title}.")
            return {"FINISHED"}

    class LAUDER_OT_save_level(bpy.types.Operator):
        """Check the level against the game's rules and write its layout file and the palette"""
        bl_idname = "lauder.save_level"
        bl_label = "Save"
        bl_options = {"REGISTER"}

        force: bpy.props.BoolProperty(
            name="Save Anyway", options={"SKIP_SAVE"},
            description="Replace the changes made to the level's files since the last Load or Save")

        def execute(self, context):
            window_manager = context.window_manager
            try:
                _, changed = save_level(bpy.path.abspath(context.scene.lauder_repository),
                                        context.scene.lauder_level, force=self.force)
            except FilesChanged as error:
                window_manager.lauder_files_changed = True
                window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            except (LayoutError, OSError) as error:
                window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            window_manager.lauder_files_changed = False
            message = f"Saved {' and '.join(changed)}." if changed else "No changes to save."
            try:
                if _export_if_stale(bpy.path.abspath(context.scene.lauder_repository),
                                    context.scene.lauder_level):
                    message += " Exporting the scene file…"
            except OSError as error:
                message += f" The scene file could not be exported: {error}"
            window_manager.lauder_message = message
            self.report({"INFO"}, message)
            return {"FINISHED"}

    class LAUDER_OT_play(bpy.types.Operator):
        """Save the level, then build the game and open it in the iOS Simulator"""
        bl_idname = "lauder.play"
        bl_label = "Play"
        bl_options = {"REGISTER"}

        def execute(self, context):
            window_manager = context.window_manager
            named = _scene_level(context.scene)
            if named is None:
                self.report({"ERROR"}, "Set the repository folder first.")
                return {"CANCELLED"}
            if _queued("play"):
                self.report({"WARNING"}, "The game is still building; it opens when it is ready.")
                return {"CANCELLED"}
            repository, level = named
            try:
                save_level(repository, level.key)
            except FilesChanged as error:
                window_manager.lauder_files_changed = True
                window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            except (LayoutError, OSError) as error:
                window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            window_manager.lauder_files_changed = False
            if is_working_file(context.scene) and bpy.data.is_dirty:
                bpy.ops.wm.save_mainfile()
            # Saving the working file may already have started an export: the build waits for it.
            try:
                _queue(repository, level.key, background_steps(repository, level.key, play=True))
            except OSError as error:
                self.report({"ERROR"}, f"Play could not start: {error}")
                return {"CANCELLED"}
            message = ("Exporting the scene file, then building the game for the Simulator…"
                       if _queued("export") else "Building the game for the Simulator…")
            window_manager.lauder_message = message
            self.report({"INFO"}, message)
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
            others = lights_outside_the_level(LEVELS[context.scene.lauder_level], context.view_layer)
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
            row = layout.row()
            row.operator("lauder.load_level")
            row.operator("lauder.save_level")
            if window_manager.lauder_files_changed:
                layout.operator("lauder.save_level", text="Save Anyway", icon="ERROR").force = True
            row = layout.row()
            row.operator("lauder.play", icon="PLAY")
            row.operator("lauder.game_look", icon="LIGHT_SUN")
            if window_manager.lauder_message:
                box = layout.box()
                for line in textwrap.wrap(window_manager.lauder_message, 42):
                    box.label(text=line)

    _CLASSES = (
        LAUDER_OT_open_level, LAUDER_OT_load_level, LAUDER_OT_save_level, LAUDER_OT_play,
        LAUDER_OT_game_look, LAUDER_OT_report, LAUDER_PT_levels,
    )
    _HANDLERS = (
        (bpy.app.handlers.save_pre, _save_level_with_file),
        (bpy.app.handlers.load_post, _refresh_opened_file),
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
        bpy.types.WindowManager.lauder_files_changed = bpy.props.BoolProperty()
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
        del bpy.types.WindowManager.lauder_files_changed

    if __name__ == "__main__":
        register()
