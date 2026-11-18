"""Lauder's level layouts in Blender (ADR 0005).

Blender is the editor for a level's layout. Load builds the layout in the open Blender file from
the level's Swift data file, and Save writes that file back after checking the game's rules. The
Swift file stays the source of truth, so a direct edit to it shows up at the next Load.

Open this file in Blender's Text Editor and press Run Script: a Lauder tab appears in the 3D
Viewport's sidebar (press N). Set the repository folder there once, then Load or Save.

Reading, writing and checking a layout need no Blender: test_lauder_levels.py runs them in
./scripts/check. Coordinates in the layout files are the game's, in metres: x across, y up and
z along the level. In Blender, z is up, so a game point (x, y, z) sits at (x, -z, y).
"""

bl_info = {
    "name": "Lauder levels",
    "author": "Lauder contributors",
    "version": (1, 0, 0),
    "blender": (4, 2, 0),
    "location": "3D Viewport > Sidebar > Lauder",
    "description": "Load and save Lauder's level layouts",
    "category": "Import-Export",
}

from dataclasses import dataclass
import math
from pathlib import Path
import re

try:
    import bpy
    from mathutils import Vector
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


LEVELS = {
    "brooklyn-bridge": LevelFile(
        key="brooklyn-bridge",
        title="Brooklyn Bridge",
        path="sources/content/BrooklynBridgeLayout.swift",
        owner="BrooklynBridge",
        header=(
            "// Where everything on the Brooklyn Bridge stands (ADR 0005), in metres: x across the",
            "// deck, y up and z along it, with Brooklyn at +z and Manhattan at -z. Blender edits",
            "// this file through scripts/blender/lauder_levels.py: Load builds the layout in",
            "// Blender and Save writes it back. The numbers can also be edited here, and the next",
            "// Load picks them up. Keep the entries in this form so that the script can read them.",
        ),
        required_boxes=("brooklyn-tower-pier", "manhattan-tower-pier"),
    ),
}

SURFACES = (
    "ground", "concrete", "shelter", "depot", "hazard", "asphalt", "steel", "granite", "vehicle",
)


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


@dataclass
class Layout:
    ground: Box
    boxes: list
    landmarks: list
    areas: list
    markers: list


class LayoutError(Exception):
    """A layout the game cannot use. The message says what to fix."""


# MARK: - Reading a layout file

_LIST = r"\[([^\]]*)\]"
_NAME = r'"([^"\\]+)"'
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
}
_SECTIONS = ("ground", "boxes", "landmarks", "areas", "markers")
_KINDS = {"ground": "box", "boxes": "box", "landmarks": "landmark", "areas": "area",
          "markers": "marker"}


def _numbers(text, count, name):
    parts = [part.strip() for part in text.split(",") if part.strip()]
    if len(parts) != count:
        raise LayoutError(f"{name}: expected {count} numbers but found {len(parts)}.")
    try:
        return tuple(float(part) for part in parts)
    except ValueError:
        raise LayoutError(f"{name}: [{text}] is not a list of numbers.") from None


def parse_layout(text):
    """Read a layout file. Anything that is not read exactly raises, so Save never drops it."""
    code = re.sub(r"//[^\n]*", "", text)
    starts = {}
    for section in _SECTIONS:
        found = list(re.finditer(rf"\b{section}:", code))
        if len(found) != 1:
            raise LayoutError(f"The layout needs exactly one '{section}:' section.")
        starts[section] = found[0].end()
    if sorted(_SECTIONS, key=starts.get) != list(_SECTIONS):
        raise LayoutError("The sections must come in order: " + ", ".join(_SECTIONS) + ".")
    entries = {}
    for index, section in enumerate(_SECTIONS):
        end = starts[_SECTIONS[index + 1]] if index + 1 < len(_SECTIONS) else len(code)
        chunk = code[starts[section]:end]
        kind = _KINDS[section]
        found = _ENTRIES[kind].findall(chunk)
        written = chunk.count(f".{kind}(")
        if len(found) != written:
            raise LayoutError(
                f"{written - len(found)} entry or entries in '{section}:' could not be read. "
                f"Write each as the others are."
            )
        entries[section] = found
    if len(entries["ground"]) != 1:
        raise LayoutError("The layout needs exactly one ground box.")

    def box(entry):
        name, at, size, surface = entry
        return Box(name, _numbers(at, 3, name), _numbers(size, 3, name), surface)

    layout = Layout(
        ground=box(entries["ground"][0]),
        boxes=[box(entry) for entry in entries["boxes"]],
        landmarks=[
            Landmark(name, _numbers(at, 3, name), _numbers(size, 3, name))
            for name, at, size in entries["landmarks"]
        ],
        areas=[
            Area(name, _numbers(low, 2, name), _numbers(high, 2, name))
            for name, low, high in entries["areas"]
        ],
        markers=[Marker(name, _numbers(at, 2, name)) for name, at in entries["markers"]],
    )
    _check_names(layout)
    return layout


def _check_names(layout):
    problems = []
    for kind, items in (
        ("box", [layout.ground] + layout.boxes), ("landmark", layout.landmarks),
        ("area", layout.areas), ("marker", layout.markers),
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
    for item in [layout.ground] + layout.boxes:
        if item.surface not in SURFACES:
            problems.append(f"{item.name} has an unknown surface, {item.surface}.")
    if problems:
        raise LayoutError(" ".join(problems))


# MARK: - Writing a layout file

_WIDTH = 100


def _number(value):
    text = f"{round(value, 3):.3f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def _list(values):
    return "[" + ", ".join(_number(value) for value in values) + "]"


def _call(indent, head, arguments, tail):
    """One call on one line if it fits, otherwise wrapped and filled as swift format does."""
    line = f"{indent}{head}({', '.join(arguments)}){tail}"
    if len(line) <= _WIDTH:
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


def emit_layout(layout, level):
    """The layout file's text, the same every time for the same layout."""
    _check_names(layout)
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
    )
    for index, (section, calls) in enumerate(sections):
        last = index + 1 == len(sections)
        if not calls:
            lines.append(f"    {section}: []" + (")" if last else ","))
            continue
        lines.append(f"    {section}: [")
        for head, arguments in calls:
            lines += _call("      ", head, arguments, ",")
        lines.append("    ]" + (")" if last else ","))
    lines.append("}")
    return "\n".join(lines) + "\n"


# MARK: - Between Blender and the game


def to_blender(point):
    """A game point (x, y, z) in Blender's z-up space."""
    x, y, z = point
    return (x, -z, y)


def size_to_blender(size):
    x, y, z = size
    return (x, z, y)


@dataclass
class Shape:
    """What Save reads from one Blender object, in Blender's coordinates."""
    name: str
    #: ground, box, landmark, area or marker.
    role: str
    #: The object's world bounding box; for a marker, its location twice.
    minimum: tuple
    maximum: tuple
    surface: str = None
    #: Turned only in quarter turns about the vertical, and not mirrored.
    square: bool = True
    #: The mesh is still a box.
    cuboid: bool = True


_TOLERANCE = 0.005


def layout_from_shapes(shapes, level, previous):
    """Build a layout from what Blender holds, or raise with everything that must change first.

    `previous` is the layout last saved. Its landmarks, areas and markers carry the level's words
    in Swift, so none of them may disappear here.
    """
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
            if shape.surface not in SURFACES:
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
    if problems:
        raise LayoutError(" ".join(problems))
    layout = Layout(ground[0], boxes, landmarks, areas, markers)
    _check_names(layout)
    return layout


# MARK: - Blender

def _linear(red, green, blue):
    def channel(value):
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
    return (channel(red), channel(green), channel(blue), 1.0)


#: The game's colours for each surface (SceneStyle), and for landmarks and areas.
COLOURS = {
    "ground": (0.23, 0.31, 0.29), "concrete": (0.56, 0.57, 0.45), "shelter": (0.39, 0.48, 0.44),
    "depot": (0.16, 0.25, 0.25), "hazard": (0.59, 0.33, 0.23), "asphalt": (0.27, 0.29, 0.29),
    "steel": (0.42, 0.48, 0.5), "granite": (0.66, 0.62, 0.54), "vehicle": (0.47, 0.38, 0.33),
    "landmark": (0.62, 0.87, 0.77), "area": (1.0, 0.75, 0.4),
}
_ROLES = (
    ("ground", "Ground"), ("box", "Boxes"), ("landmark", "Landmarks"), ("area", "Areas"),
    ("marker", "Markers"),
)


def _material(name):
    material = bpy.data.materials.get(f"Lauder {name}")
    if material is None:
        material = bpy.data.materials.new(f"Lauder {name}")
    material["lauder_surface"] = name
    colour = _linear(*COLOURS[name])
    material.diffuse_color = colour
    tree = getattr(material, "node_tree", None)
    if tree is not None:
        for node in tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Base Color"].default_value = colour
    return material


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


def _remove(collection):
    for child in list(collection.children):
        _remove(child)
    for item in list(collection.objects):
        data = item.data
        bpy.data.objects.remove(item, do_unlink=True)
        if data is not None and data.users == 0 and data.get("lauder"):
            bpy.data.meshes.remove(data)
    bpy.data.collections.remove(collection)


def build_in_blender(layout, level):
    """Replace the level's collection in the open Blender file with this layout."""
    old = _level_collection(level)
    if old is not None:
        _remove(old)
    root = bpy.data.collections.new(f"Lauder {level.title}")
    root["lauder_level"] = level.key
    bpy.context.scene.collection.children.link(root)
    parts = {}
    for role, title in _ROLES:
        part = bpy.data.collections.new(f"{level.title} {title}")
        part["lauder_role"] = role
        root.children.link(part)
        parts[role] = part

    def block(name, role, centre, size, material, wire=False):
        item = bpy.data.objects.new(name, _cube(name))
        item.location = centre
        item.scale = size
        item.data.materials.append(material)
        if wire:
            item.display_type = "WIRE"
            item.show_name = True
        if role == "landmark":
            item.show_name = True
        parts[role].objects.link(item)
        return item

    block(layout.ground.name, "ground", to_blender(layout.ground.position),
          size_to_blender(layout.ground.size), _material(layout.ground.surface))
    for box in layout.boxes:
        block(box.name, "box", to_blender(box.position), size_to_blender(box.size),
              _material(box.surface))
    for landmark in layout.landmarks:
        x, y, z = landmark.position
        block(landmark.name, "landmark", to_blender((x, y + landmark.size[1] / 2, z)),
              size_to_blender(landmark.size), _material("landmark"))
    for area in layout.areas:
        (x0, z0), (x1, z1) = area.minimum, area.maximum
        block(area.name, "area", ((x0 + x1) / 2, -(z0 + z1) / 2, 0.025),
              (x1 - x0, z1 - z0, 0.05), _material("area"), wire=True)
    for marker in layout.markers:
        item = bpy.data.objects.new(marker.name, None)
        item.empty_display_type = "PLAIN_AXES"
        item.empty_display_size = 0.6
        item.show_name = True
        item.location = (marker.position[0], -marker.position[1], 0)
        parts["marker"].objects.link(item)
    return root


def shapes_from_blender(level):
    """Read the level's collection in the open Blender file."""
    root = _level_collection(level)
    if root is None:
        raise LayoutError(f"This Blender file has no {level.title}; Load it first.")
    shapes = []
    for part in root.children:
        role = part.get("lauder_role")
        for item in part.objects:
            if role == "marker":
                if item.type != "EMPTY":
                    raise LayoutError(f"{item.name} is in Markers but is not an empty.")
                location = tuple(item.matrix_world.translation)
                shapes.append(Shape(item.name, role, location, location))
                continue
            if item.type != "MESH":
                raise LayoutError(f"{item.name} is in {part.name} but is not a mesh box.")
            corners = [item.matrix_world @ Vector(corner) for corner in item.bound_box]
            low = tuple(min(corner[axis] for corner in corners) for axis in range(3))
            high = tuple(max(corner[axis] for corner in corners) for axis in range(3))
            _, rotation, scale = item.matrix_world.decompose()
            matrix = rotation.to_matrix()
            square = all(value > 0 for value in scale) and abs(matrix[2][2] - 1) < 1e-4 and all(
                min(abs(matrix[row][column]), abs(abs(matrix[row][column]) - 1)) < 1e-4
                for row in range(3) for column in range(3))
            local = [tuple(corner) for corner in item.bound_box]
            vertices = [tuple(vertex.co) for vertex in item.data.vertices]
            cuboid = len(vertices) == 8 and all(
                any(all(abs(a - b) < 1e-4 for a, b in zip(vertex, corner)) for corner in local)
                for vertex in vertices)
            surface = None
            if item.material_slots and item.material_slots[0].material is not None:
                surface = item.material_slots[0].material.get("lauder_surface")
            shapes.append(Shape(item.name, role, low, high, surface, square, cuboid))
    return shapes


def load_level(repository, key="brooklyn-bridge"):
    level = LEVELS[key]
    layout = parse_layout((Path(repository) / level.path).read_text())
    build_in_blender(layout, level)
    return layout


def save_level(repository, key="brooklyn-bridge"):
    level = LEVELS[key]
    path = Path(repository) / level.path
    previous = parse_layout(path.read_text())
    layout = layout_from_shapes(shapes_from_blender(level), level, previous)
    text = emit_layout(layout, level)
    changed = text != path.read_text()
    if changed:
        path.write_text(text)
    return layout, changed


def _guess_repository():
    try:
        candidate = Path(__file__).resolve().parents[2]
    except (NameError, IndexError):
        return ""
    return str(candidate) if (candidate / "sources" / "content").is_dir() else ""


if bpy is not None:

    class LAUDER_OT_load_level(bpy.types.Operator):
        """Build the level's layout in this Blender file from the game's layout file"""
        bl_idname = "lauder.load_level"
        bl_label = "Load"
        bl_options = {"REGISTER"}

        def invoke(self, context, event):
            if _level_collection(LEVELS[context.scene.lauder_level]) is not None:
                return context.window_manager.invoke_confirm(self, event)
            return self.execute(context)

        def execute(self, context):
            try:
                load_level(bpy.path.abspath(context.scene.lauder_repository),
                           context.scene.lauder_level)
            except (LayoutError, OSError) as error:
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            self.report({"INFO"}, f"Loaded {LEVELS[context.scene.lauder_level].title}.")
            return {"FINISHED"}

    class LAUDER_OT_save_level(bpy.types.Operator):
        """Check the layout against the game's rules and write the game's layout file"""
        bl_idname = "lauder.save_level"
        bl_label = "Save"
        bl_options = {"REGISTER"}

        def execute(self, context):
            try:
                _, changed = save_level(bpy.path.abspath(context.scene.lauder_repository),
                                        context.scene.lauder_level)
            except (LayoutError, OSError) as error:
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            level = LEVELS[context.scene.lauder_level]
            self.report({"INFO"}, f"Saved {level.path}." if changed else "No changes to save.")
            return {"FINISHED"}

    class LAUDER_PT_levels(bpy.types.Panel):
        bl_label = "Lauder levels"
        bl_idname = "LAUDER_PT_levels"
        bl_space_type = "VIEW_3D"
        bl_region_type = "UI"
        bl_category = "Lauder"

        def draw(self, context):
            layout = self.layout
            layout.prop(context.scene, "lauder_repository")
            layout.prop(context.scene, "lauder_level")
            row = layout.row()
            row.operator("lauder.load_level")
            row.operator("lauder.save_level")

    _CLASSES = (LAUDER_OT_load_level, LAUDER_OT_save_level, LAUDER_PT_levels)

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

    def unregister():
        for cls in reversed(_CLASSES):
            if hasattr(bpy.types, cls.__name__):
                bpy.utils.unregister_class(getattr(bpy.types, cls.__name__))
        del bpy.types.Scene.lauder_repository
        del bpy.types.Scene.lauder_level

    if __name__ == "__main__":
        register()
