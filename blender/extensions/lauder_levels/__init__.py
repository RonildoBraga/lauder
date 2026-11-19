"""Lauder's levels in Blender (ADR 0006), as a Blender extension.

Each level is a Blender file in the repository, blender/levels/<level>.blend, stored with Git LFS:
the level's source. Its collections decide where each object goes:

- Visual: everything the player sees. Export writes it to the level's scene file, a USDZ that the
  game loads.
- Gameplay: the ground, the boxes that block movement and sight, the landmarks, the trigger and
  fight areas, and the markers where people start and stand, each with its role. Export writes
  them to the level's layout file, typed Swift that the game compiles. They show as outlines, and
  the game never draws them. A visual part parented to a gameplay box moves with it.
- Lights and Camera: the level's sun lights and the game camera's rig, written to the layout file
  too.
- Preview: the party's stand-ins at their start markers, which the game draws itself. It is never
  exported.

Install it once: in Blender's Preferences, add a local extension repository at this repository's
blender/extensions folder, then enable Lauder levels. A Lauder tab appears in the 3D Viewport's
sidebar (press N). Open Level opens the level's Blender file. Saving it checks the game's rules,
then exports in a Blender of its own, in the background, with blender/scripts/export-level.py,
which agents run too. Play saves, exports when needed, then builds the game and opens it in the iOS
Simulator through apple/scripts/play. blender/level-exports.json records what each export was made
from and what it wrote, and ./scripts/check fails when they no longer match.

Writing and checking a layout needs no Blender: blender/test_lauder_levels.py runs those parts in
./scripts/check. Coordinates in the layout file are the game's, in metres: x across, y up and z
along the level. In Blender, z is up, so a game point (x, y, z) sits at (x, -z, y).
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
    import bpy
    from bpy.app.handlers import persistent
    from mathutils import Vector
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

#: The script that builds the game and opens it in the iOS Simulator.
PLAY_SCRIPT = "apple/scripts/play"
#: The script that exports a level in a Blender of its own.
EXPORT_SCRIPT = "blender/scripts/export-level.py"
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


# MARK: - Work in the background


#: Work running in the background, one step after another, so that Blender stays usable: the
#: steps still to run; the running step's name, process, log and log's path; the repository and
#: level the work is for; and how often it exported again because the level's Blender file changed
#: while it ran.
_JOB = {"steps": [], "name": None, "process": None, "log": None, "path": None,
        "repository": None, "key": None, "refreshes": 0}
#: What each background step says when it finishes well.
_FINISHED = {
    "export": "Exported the level. The game shows it from the next build.",
    "play": "The game is running in the Simulator.",
}
#: How often one run of background work exports again while the level's Blender file keeps
#: changing, so that it cannot go on for ever.
MOST_REFRESHES = 3


def _export_step(repository, key):
    """The background step that exports the level in a Blender of its own."""
    blender = bpy.app.binary_path if bpy is not None else "blender"
    return ("export", [
        blender, "-b", "--factory-startup", "--python-exit-code", "1",
        "--python", str(Path(repository) / EXPORT_SCRIPT), "--", key,
    ], "export.log")


def background_steps(repository, key, play):
    """The background steps that saving (play=False) or Play needs: exporting the level when its
    exports no longer match its Blender file, then, for Play, building and opening the game. Each
    is (name, command, log)."""
    steps = [_export_step(repository, key)] if stale_exports(repository, key) is not None else []
    if play:
        steps.append(("play", [sys.executable, "-I", str(Path(repository) / PLAY_SCRIPT)],
                      "play.log"))
    return steps


def queue_steps(running, waiting, steps):
    """The steps to add after the background work already running and waiting. An export already
    running or waiting stands in for a new one, which could only race it for the same files: when
    it finishes, the exports' freshness is checked again (refresh_needed)."""
    names = ([running] if running else []) + [name for name, _, _ in waiting]
    if "export" in names:
        return [step for step in steps if step[0] != "export"]
    return list(steps)


def refresh_needed(waiting, stale, refreshes):
    """Whether to export again before going on, once a step has finished well: when the level's
    Blender file changed while it ran, such as by a second save, and no export is next anyway."""
    upcoming = waiting[0][0] if waiting else None
    return stale and upcoming != "export" and refreshes < MOST_REFRESHES


def _start_job(repository, key, steps):
    """Run the steps in the background, in order, stopping at the first that fails."""
    _JOB.update(steps=list(steps), repository=repository, key=key, refreshes=0)
    _next_step()
    # Persistent, so that opening another Blender file keeps watching.
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
    name, path = _JOB["name"], _JOB["path"]
    if process.returncode == 0:
        try:
            stale = stale_exports(_JOB["repository"], _JOB["key"]) is not None
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
    what = "The export" if name == "export" else "Play"
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
    """Export the level in the background when its exports no longer match its Blender file, after
    the work already running. Returns whether an export is running or waiting."""
    _queue(repository, key, background_steps(repository, key, play=False))
    return _queued("export")


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
    root = Path(repository)
    written = root / level.layout
    required = required_names(written.read_text() if written.exists() else "",
                              (root / level.story).read_text())
    return layout_from_shapes(shapes_from_blender(), level, camera_from_blender(),
                              lights_from_blender(), required)


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
    """Open the level's Blender file and return its fingerprint as it was read. A save that lands
    while it is read shows as a different fingerprint after, and the file is read again."""
    path = Path(repository) / LEVELS[key].blend
    for _ in range(attempts):
        before = file_fingerprint(path)
        bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False)
        if file_fingerprint(path) == before:
            return before
    raise LayoutError(f"{LEVELS[key].blend} kept changing while it was read; export it again.")


def forget_folders():
    """Point Blender's file browsers at the level's own folder, so that a level file in the public
    repository keeps no paths from the computer it was saved on, such as the home folder that a
    file browser starts in."""
    for screen in bpy.data.screens:
        for area in screen.areas:
            for space in area.spaces:
                params = getattr(space, "params", None)
                if params is not None and hasattr(params, "directory"):
                    params.directory = b"//" if isinstance(params.directory, bytes) else "//"


def export_level(repository, key="brooklyn-bridge", loaded=None):
    """Write the level's layout file and scene file from its Blender file, open in this Blender,
    and record what they were made from. `loaded` is the fingerprint of the Blender file as it was
    read (open_level_file), so that a save made since counts as a change. It changes the open
    file, so it runs in a Blender of its own: blender/scripts/export-level.py."""
    level = LEVELS[key]
    root = Path(repository)
    made_from = {name: file_fingerprint(root / name) for name in _files_used(root)}
    made_from[level.blend] = loaded or file_fingerprint(root / level.blend)
    text = emit_layout(layout_from_blender(repository, level), level)
    written = root / level.layout
    if not written.exists() or written.read_text() != text:
        written.write_text(text)
    visual = _collection(VISUAL)
    if visual is None:
        raise LayoutError("This Blender file has no Visual collection; open the level's own file.")
    # Only the Visual collection is exported, each part where it stands in the world.
    shown = list(visual.all_objects)
    places = {item: item.matrix_world.copy() for item in shown}
    for item in shown:
        item.parent = None
        item.matrix_world = places[item]
        item.hide_render = False
    for item in list(bpy.data.objects):
        if item not in places:
            bpy.data.objects.remove(item, do_unlink=True)
    target = root / level.scene
    with tempfile.TemporaryDirectory() as folder:
        exported = Path(folder) / target.name
        bpy.ops.wm.usd_export(filepath=str(exported), **SCENE_EXPORT)
        shutil.copyfile(exported, target)
    record_exports(repository, level, made_from,
                   {name: file_fingerprint(root / name) for name in (level.layout, level.scene)})
    return target


if bpy is not None:

    def _open_level():
        """The repository and level whose Blender file is open, or None."""
        return level_of_file(bpy.data.filepath)

    @persistent
    def _forget_folders_before_save(path=None, *_):
        """A level file keeps no local folder paths in the repository (forget_folders)."""
        if level_of_file(path if isinstance(path, str) and path else bpy.data.filepath):
            forget_folders()

    @persistent
    def _export_after_save(_):
        """Saving a level's Blender file exports it in the background, once the game's rules hold.
        The Blender file is saved whatever they find."""
        found = _open_level()
        if found is None:
            return
        repository, level = found
        try:
            layout_from_blender(repository, level)
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
        """Save the level's Blender file and export it, when its exports are out of date"""
        bl_idname = "lauder.export"
        bl_label = "Export"
        bl_options = {"REGISTER"}

        def execute(self, context):
            found = _open_level()
            if found is None:
                self.report({"ERROR"}, "Open the level first, with Open Level.")
                return {"CANCELLED"}
            if bpy.data.is_dirty:
                bpy.ops.wm.save_mainfile()  # Its handler checks the rules and exports.
                return {"FINISHED"}
            repository, level = found
            try:
                layout_from_blender(repository, level)
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
                layout_from_blender(repository, level)
            except (LayoutError, OSError) as error:
                window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            if bpy.data.is_dirty:
                bpy.ops.wm.save_mainfile()  # Its handler starts the export; the build waits for it.
            try:
                _queue(repository, level.key, background_steps(repository, level.key, play=True))
            except OSError as error:
                self.report({"ERROR"}, f"Play could not start: {error}")
                return {"CANCELLED"}
            message = ("Exporting the level, then building the game for the Simulator…"
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
            row = layout.row()
            row.operator("lauder.export", icon="EXPORT")
            row.operator("lauder.play", icon="PLAY")
            layout.operator("lauder.game_look", icon="LIGHT_SUN")
            item = context.active_object
            if (item is not None and _open_level() is not None
                    and any(owner.name == GAMEPLAY for owner in item.users_collection)):
                if "lauder_role" in item:
                    layout.prop(item, '["lauder_role"]', text="Role")
                else:
                    role = "marker" if item.type == "EMPTY" else "box"
                    layout.label(text=f"{item.name} counts as a {role}")
            if window_manager.lauder_message:
                box = layout.box()
                for line in textwrap.wrap(window_manager.lauder_message, 42):
                    box.label(text=line)

    _CLASSES = (
        LAUDER_OT_open_level, LAUDER_OT_export, LAUDER_OT_play, LAUDER_OT_game_look,
        LAUDER_OT_report, LAUDER_PT_levels,
    )
    _HANDLERS = (
        (bpy.app.handlers.save_pre, _forget_folders_before_save),
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
