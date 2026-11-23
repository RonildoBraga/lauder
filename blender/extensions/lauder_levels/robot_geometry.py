"""The heavy robot's joint geometry, read from its Blender source alongside its scene export.

This is deliberately one model's contract, not an animation or rig interchange framework.
"""

import math

from .common import bpy, LayoutError
from .layouts import _number


ROBOT = "spider-bot-heavy"


def _vector(point):
    return "[" + ", ".join(_number(value, 6) for value in point) + "]"


def _canonical(point):
    # USD's axis conversion, followed by SceneStyle.figure's half turn.
    return (-point.x, point.z, point.y)


def _foot_radius(boots):
    """A conservative source-XY circle around each ankle, independent of placement/lift."""
    maximum = 0
    for ankle, points in boots:
        radius = 0
        for point in points:
            across = point[0] - ankle[0]
            along = point[1] - ankle[1]
            if not math.isfinite(across) or not math.isfinite(along):
                raise LayoutError("The robot's foot vertices and ankle pivots must be finite.")
            radius = max(radius, math.hypot(across, along))
        if radius <= 0:
            raise LayoutError("Every robot foot needs vertices with a positive ankle radius.")
        maximum = max(maximum, radius)
    if maximum <= 0:
        raise LayoutError("The robot needs feet to measure its ankle clearance.")
    # The generated decimal must contain the measured corners rather than rounding inward.
    return math.ceil(maximum * 1_000_000) / 1_000_000


def emit_robot_geometry():
    """Typed geometry in game axes, with local source axes retained for rigid joint solves."""
    scene = bpy.context.scene
    previous = scene.frame_current
    scene.frame_set(1)
    bpy.context.view_layer.update()
    collection = bpy.data.collections.get(ROBOT)
    if collection is None:
        raise LayoutError(f"The robot needs its {ROBOT} collection.")
    meshes = [item for item in collection.all_objects if item.type == "MESH"]

    def part(label):
        item = bpy.data.objects.get(f"{ROBOT} {label}")
        if item is None or item not in set(collection.all_objects):
            raise LayoutError(f"The robot needs its {label} joint or marker.")
        return item

    root = part("root")
    legs = []
    boots = []
    for label in ("front-left", "front-right", "rear-left", "rear-right"):
        connector = part(f"{label} connector")
        foot = part(f"{label} ankle pivot")
        legs.append((label, connector.location.copy(), foot.matrix_world.translation.copy(),
                     connector.rotation_euler.z))
        boot = part(f"{label} foot")
        if boot.type != "MESH":
            raise LayoutError(f"The robot's {label} foot must be a mesh.")
        boots.append((foot, boot))
    upper = part("front-left knee pivot").location.z
    lower = part("front-left ankle pivot").location.z
    mounts = [_canonical(part(f"gun-{side} recoil").matrix_world.translation)
              for side in ("left", "right")]
    muzzles = [_canonical(part(f"muzzle-{side}").matrix_world.translation)
               for side in ("left", "right")]
    points = [item.matrix_world @ vertex.co for item in meshes for vertex in item.data.vertices]
    half_height = max(point.z for point in points) / 2
    # A cylinder through the visible torso and upper legs at the existing 1.25 m shot height.
    # Floor feet do not make the body a map-wide target.
    radius = 0
    for item in meshes:
        vertices = [item.matrix_world @ vertex.co for vertex in item.data.vertices]
        for face in item.data.polygons:
            indices = list(face.vertices)
            for first, second in zip(indices, indices[1:] + indices[:1]):
                a, b = vertices[first], vertices[second]
                if (a.z - 1.25) * (b.z - 1.25) <= 0 and abs(b.z - a.z) > 1e-8:
                    point = a.lerp(b, (1.25 - a.z) / (b.z - a.z))
                    radius = max(radius, math.hypot(point.x, point.y))
    if radius <= 0 or upper <= 0 or lower <= 0:
        raise LayoutError("The robot's body slice and two leg links must have positive size.")
    navigation, lift, brace_depth, foot_radius = 0, 0, 0, 0
    try:
        # Include the complete authored crawl/turn/brace envelope, then 5 cm of clearance.
        for frame in range(scene.frame_start, scene.frame_end + 1):
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            origin = root.matrix_world.translation
            brace_depth = max(brace_depth, -origin.z)
            for item in meshes:
                for vertex in item.data.vertices:
                    point = item.matrix_world @ vertex.co - origin
                    navigation = max(navigation, math.hypot(point.x, point.y))
            for label, _, foot, _ in legs:
                lift = max(lift, part(f"{label} ankle pivot").matrix_world.translation.z - foot.z)
            foot_radius = max(foot_radius, _foot_radius(
                (ankle.matrix_world.translation,
                 (boot.matrix_world @ vertex.co for vertex in boot.data.vertices))
                for ankle, boot in boots))
    finally:
        scene.frame_set(previous)
        bpy.context.view_layer.update()
    lines = [
        "// Generated from blender/assets/spider-bot-heavy/spider-bot-heavy.blend. Do not edit.",
        "import simd", "", "enum RobotModelGeometry {",
        "  struct Leg: Sendable {", "    let name: String", "    let hip: SIMD3<Float>",
        "    let foot: SIMD3<Float>", "    let angle: Float", "  }", "",
        "  // Combat offsets use game axes, facing -z. Gun 0 is the source's left gun.",
        f"  static let bodyRadius: Float = {_number(radius, 6)}",
        f"  static let halfHeight: Float = {_number(half_height, 6)}",
        f"  static let navigationRadius: Float = {_number(navigation + 0.05, 6)}",
        f"  static let footRadius: Float = {_number(foot_radius, 6)}",
        "  static let gunMounts: [SIMD3<Float>] = [",
        *[f"    {_vector(point)}," for point in mounts], "  ]",
        "  static let muzzles: [SIMD3<Float>] = [",
        *[f"    {_vector(point)}," for point in muzzles], "  ]", "",
        "  // Rigid-joint calculations retain Blender's local x/y ground plane and z up.",
        f"  static let upperLength: Float = {_number(upper, 6)}",
        f"  static let lowerLength: Float = {_number(lower, 6)}",
        f"  static let stepLift: Float = {_number(lift, 6)}",
        f"  static let braceDepth: Float = {_number(brace_depth, 6)}",
        "  static let legs: [Leg] = [",
    ]
    for label, hip, foot, angle in legs:
        lines += ["    Leg(", f'      name: "{label}", hip: {_vector(hip)},',
                  f"      foot: {_vector(foot)}, angle: {_number(angle, 6)}),"]
    return "\n".join(lines + ["  ]", "}", ""])
