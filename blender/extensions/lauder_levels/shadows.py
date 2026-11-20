"""Baked shadows: Bake Shadows, which lays the shadows of a level's tall landmarks on the ground as
parts of its look. The game fades a landmark to a ghost while it hides the party, and the landmark
casts no live shadow there, so that its shadow stays while it fades."""

from .common import _and, bpy, _collection, LayoutError, LIGHTS, Vector, VISUAL


#: The property that makes a part of Visual a baked shadow, with the names of the parts whose
#: shadow it is, separated by commas.
SHADOW_OF = "lauder_shadow_of"
#: How far above the ground, in metres, a baked shadow lies, so that the two never fight over the
#: same depth.
SHADOW_LIFT = 0.03


def shadow_outline(corners, towards):
    """Where a part's shadow falls on the ground, at Blender's z = 0: the convex outline,
    anticlockwise from above, of where its corners fall, each carried away from the sun along the
    light. `towards` points at the sun."""
    x, y, z = towards
    if z <= 0:
        raise LayoutError("The sun that casts the level's shadow stands below the horizon.")
    points = sorted({(round(cx - x * cz / z, 4), round(cy - y * cz / z, 4))
                     for cx, cy, cz in corners})

    def turn(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    # Andrew's monotone chain: the lower edge from left to right, then the upper edge back.
    lower, upper = [], []
    for point in points:
        while len(lower) >= 2 and turn(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    for point in reversed(points):
        while len(upper) >= 2 and turn(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    return lower[:-1] + upper[:-1]


def towards_the_sun():
    """The direction towards the sun that casts the level's shadow, as Export reads it."""
    lights = _collection(LIGHTS)
    suns = [item for item in (lights.all_objects if lights else [])
            if item.type == "LIGHT" and item.data.type == "SUN" and item.data.use_shadow]
    if len(suns) != 1:
        raise LayoutError("Baking shadows needs a sun in Lights that casts the level's shadow.")
    return tuple((suns[0].matrix_world.to_quaternion() @ Vector((0, 0, 1))).normalized())


def bake_shadows():
    """Bake again every shadow in the open level's Visual, and return their names. Each part of
    Visual with a SHADOW_OF property becomes the outlines of its parts' shadows, from the sun that
    casts the level's shadow, just above the ground. It keeps its material, the palette's shadow."""
    towards = towards_the_sun()
    visual = _collection(VISUAL)
    shadows = [item for item in (visual.all_objects if visual else [])
               if item.library is None and SHADOW_OF in item]
    for shadow in shadows:
        names = [name.strip() for name in str(shadow[SHADOW_OF]).split(",") if name.strip()]
        missing = [name for name in names if bpy.data.objects.get(name) is None]
        if shadow.type != "MESH":
            raise LayoutError(f"{shadow.name} has a {SHADOW_OF} property, so it must be a mesh.")
        if not names:
            raise LayoutError(f"{shadow.name}'s {SHADOW_OF} must name the parts whose shadow it "
                              f"is, separated by commas.")
        if missing:
            raise LayoutError(f"{shadow.name} is the shadow of {_and(missing)}, which the level "
                              f"does not hold.")
        to_shadow = shadow.matrix_world.inverted()
        vertices, faces = [], []
        for name in names:
            part = bpy.data.objects[name]
            corners = [tuple(part.matrix_world @ Vector(corner)) for corner in part.bound_box]
            outline = shadow_outline(corners, towards)
            faces.append(tuple(range(len(vertices), len(vertices) + len(outline))))
            vertices += [tuple(to_shadow @ Vector((x, y, SHADOW_LIFT))) for x, y in outline]
        if shadow.data.users > 1:
            shadow.data = shadow.data.copy()
        shadow.data.clear_geometry()
        shadow.data.from_pydata(vertices, [], faces)
        shadow.data.update()
    return [shadow.name for shadow in shadows]
