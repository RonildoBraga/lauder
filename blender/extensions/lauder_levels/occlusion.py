"""Baked occlusion: Bake Occlusion and Clear Occlusion, which bake ambient occlusion into the colour
of a level's parts and take it away again."""

import json
import math
from pathlib import Path

from .common import _and, bpy, _collection, LayoutError, usd_name, VISUAL
from .looks import _material_shape, _surface_shader


#: Where each level's baked occlusion is kept, relative to the repository: a PNG for each baked
#: part, in a folder named after the level (ADR 0002).
BAKED = "blender/levels/baked"
#: A baked part's properties: that its occlusion is baked, and the materials and UV map it showed
#: before, which Clear Occlusion gives back. Each material is kept as its slot's link, its name,
#: and whether Bake Occlusion gave it a fake user to keep it in the file meanwhile.
BAKED_PROPERTY = "lauder_baked"
UNBAKED_MATERIALS, UNBAKED_UV = "lauder_unbaked_materials", "lauder_unbaked_uv"
#: The UV map, made for each baked part, that its baked colour uses.
BAKED_UV = "baked"
#: The property that marks a material or an image as one that Bake Occlusion made, with the name
#: of the part it was made for: only those are ever replaced or removed.
BAKED_FOR = "lauder_baked_for"
#: Texels of baked colour for each metre, and the smallest and largest images, in pixels on a side.
BAKE_TEXELS_PER_METRE = 8
BAKE_PIXELS = (64, 1024)
#: How much of a box's faces Blender's Smart UV Project fills, on the whole.
BAKE_PACKING = 0.6
#: How far, in metres, ambient occlusion looks for what shades a surface: near enough for the
#: shade where a part meets another, such as a tower's leg on the snow.
BAKE_OCCLUSION_DISTANCE = 1.5
BAKE_SAMPLES = 64


def bake_size(dimensions):
    """The side, in pixels, of the square image for a part's baked colour: BAKE_TEXELS_PER_METRE
    over its box's faces, allowing for the gaps that packing them leaves, as a power of two within
    BAKE_PIXELS."""
    x, y, z = (max(value, 0.0) for value in dimensions)
    wanted = math.sqrt(2 * (x * y + y * z + z * x) / BAKE_PACKING) * BAKE_TEXELS_PER_METRE
    side = BAKE_PIXELS[0]
    while side < wanted and side < BAKE_PIXELS[1]:
        side *= 2
    return side


def baked_image(level_key, name):
    """Where a part's baked colour is kept, relative to the repository."""
    return f"{BAKED}/{level_key}/{usd_name(name)}.png"


def baked_material(name):
    """The name of the material that shows a part's baked colour."""
    return f"{name} baked"


def bake_problems(part, materials):
    """What stops a part's occlusion from being baked into its colour: each of its materials
    (MaterialShape) needs a Principled BSDF, and nodes may feed only its Base Color, since the
    baked colour takes a UV map of its own that the part's other images could not share."""
    problems = []
    for material in materials:
        if material.surface != "BSDF_PRINCIPLED":
            problems.append(f"{part} shows {material.name}, which needs a Principled BSDF to "
                            f"bake.")
            continue
        others = sorted(socket for socket, _ in material.feeds if socket != "Base Color")
        if others:
            problems.append(f"{part} shows {material.name}, whose {_and(others)} "
                            f"{'is' if len(others) == 1 else 'are'} fed by nodes: only its "
                            f"Base Color can be, to bake.")
    return problems


def _select_only(item):
    for other in bpy.context.view_layer.objects:
        other.select_set(other == item)
    bpy.context.view_layer.objects.active = item


def _baked_uv(item):
    """The part's UV map for its baked colour, made with Smart UV Project when it has none."""
    layers = item.data.uv_layers
    if BAKED_UV not in layers:
        before = layers.active
        layers.new(name=BAKED_UV)
        layers.active = layers[BAKED_UV]
        _select_only(item)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        if before is not None:
            layers.active = before
    return layers[BAKED_UV]


def _unbaked_materials(item):
    """The materials the part shows unbaked: those it showed before its occlusion was baked, or
    those it shows now."""
    if item.get(BAKED_PROPERTY):
        names = [entry[1] for entry in json.loads(item[UNBAKED_MATERIALS]) if entry[1]]
        return [bpy.data.materials.get(name) for name in names]
    return [slot.material for slot in item.material_slots if slot.material is not None]


def _keep_unbaked(item):
    """Record the materials the part shows before its occlusion is baked. One held only by the
    part's own slot gets a fake user, so that it stays in the file while the part shows its baked
    look."""
    record = []
    for slot in item.material_slots:
        material = slot.material
        kept = slot.link == "OBJECT" and material is not None and not material.use_fake_user
        if kept:
            material.use_fake_user = True
        record.append([slot.link, material.name if material else "", kept])
    item[UNBAKED_MATERIALS] = json.dumps(record)


def _unbake(item):
    """Show the part's materials and UV map from before its occlusion was baked, letting go of
    its baked material."""
    if not item.get(BAKED_PROPERTY):
        return
    for slot, entry in zip(item.material_slots, json.loads(item[UNBAKED_MATERIALS])):
        link, name = entry[0], entry[1]
        slot.link = "OBJECT"
        material = bpy.data.materials.get(name) if name else None
        slot.material = material if link == "OBJECT" else None
        slot.link = link
    before = item.data.uv_layers.get(item.get(UNBAKED_UV, ""))
    if before is not None:
        before.active_render = True


def _made_by_bake(collection, item):
    """The material or image that Bake Occlusion made for the part (BAKED_FOR), or None."""
    return next((each for each in collection
                 if each.library is None and each.get(BAKED_FOR) == item.name), None)


def _surface(material):
    """The material's Principled BSDF and its output, or (None, None)."""
    shader, output = _surface_shader(material)
    principled = shader is not None and shader.type == "BSDF_PRINCIPLED"
    return (shader, output) if principled else (None, None)


def _bake_into(item, canvas, kind, materials):
    """Bake one pass of the part into the image: its colour (EMIT, through a temporary Emission
    shader fed as its Base Color is) or its ambient occlusion (AO)."""
    added, rewired = [], []
    for material in materials:
        tree = material.node_tree
        shader, output = _surface(material)
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = canvas
        tree.nodes.active = node
        added.append((tree, node))
        if kind == "EMIT":
            glow = tree.nodes.new("ShaderNodeEmission")
            source = shader.inputs["Base Color"]
            if source.is_linked:
                tree.links.new(source.links[0].from_socket, glow.inputs["Color"])
            else:
                glow.inputs["Color"].default_value = source.default_value
            glow.inputs["Strength"].default_value = 1.0
            tree.links.new(glow.outputs["Emission"], output.inputs["Surface"])
            added.append((tree, glow))
            rewired.append((tree, shader, output))
    try:
        _select_only(item)
        bpy.ops.object.bake(type=kind, margin=4, use_clear=True)
    finally:
        for tree, node in reversed(added):
            tree.nodes.remove(node)
        for tree, shader, output in rewired:
            tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])


def _bake_part(root, level, item, materials):
    """Bake one part's colour times its ambient occlusion into its image (bake_level)."""
    import numpy
    side = bake_size(item.dimensions)
    layers = item.data.uv_layers
    before = layers.active
    layers.active = _baked_uv(item)
    passes = {}
    try:
        for kind in ("EMIT", "AO"):
            canvas = bpy.data.images.new(f"{item.name} {kind.lower()}", side, side,
                                         float_buffer=True)
            try:
                _bake_into(item, canvas, kind, materials)
                pixels = numpy.empty(side * side * 4, dtype=numpy.float32)
                canvas.pixels.foreach_get(pixels)
                passes[kind] = pixels.reshape(-1, 4)
            finally:
                bpy.data.images.remove(canvas)
    finally:
        if before is not None:
            layers.active = before
    colour = numpy.clip(passes["EMIT"][:, :3] * passes["AO"][:, :1], 0.0, 1.0)
    encoded = numpy.where(colour <= 0.0031308, colour * 12.92,
                          1.055 * colour ** (1 / 2.4) - 0.055)
    relative = baked_image(level.key, item.name)
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    image = bpy.data.images.new(baked_material(item.name), side, side, alpha=False)
    image[BAKED_FOR] = item.name
    image.colorspace_settings.name = "sRGB"
    rgba = numpy.ones((side * side, 4), dtype=numpy.float32)
    rgba[:, :3] = encoded
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    image.filepath_raw = bpy.path.relpath(str(path))
    image.reload()
    return image


def _baked_look(item, image, material):
    """A material of the part's own: a copy of what it showed, with the baked colour as its Base
    Color through the part's baked UV map."""
    look = material.copy()
    look.name = baked_material(item.name)
    look[BAKED_FOR] = item.name
    tree = look.node_tree
    shader, _ = _surface(look)
    for link in list(shader.inputs["Base Color"].links):
        tree.links.remove(link)
    texture = tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    coordinates = tree.nodes.new("ShaderNodeUVMap")
    coordinates.uv_map = BAKED_UV
    tree.links.new(coordinates.outputs["UV"], texture.inputs["Vector"])
    tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    for node in [node for node in tree.nodes if node.type in ("TEX_IMAGE", "UVMAP", "REROUTE")
                 and node not in (texture, coordinates) and not any(
                     socket.is_linked for socket in node.outputs)]:
        tree.nodes.remove(node)
    return look


def bake_level(repository, level, chosen=()):
    """Bake ambient occlusion into the colour of each chosen part of the open level's Visual, and
    of each part already baked (ADR 0002). Cycles bakes the part's colour and its
    occlusion, within BAKE_OCCLUSION_DISTANCE, into an image in BAKED, and the part then shows a
    copy of its material with that image as Base Color. The game's lights, shadows and sky light
    light it as before. Linked models are not baked here. Returns the baked parts' names."""
    root = Path(repository)
    visual = _collection(VISUAL)
    if visual is None:
        raise LayoutError("This Blender file has no Visual collection; open the level's own file.")
    picked = set(chosen)
    parts = [item for item in visual.all_objects
             if item.library is None and item.type == "MESH"
             and (item in picked or item.get(BAKED_PROPERTY))]
    if not parts:
        raise LayoutError("Select the parts of Visual to bake first. Models linked into the "
                          "level are not baked here.")
    # Everything is checked before any part changes, so that a refusal leaves the level as it was.
    problems = []
    for item in parts:
        materials = list(dict.fromkeys(_unbaked_materials(item)))
        if None in materials or len(materials) != 1:
            problems.append(f"{item.name} shows {len(materials)} materials; give it one to bake.")
            continue
        problems += bake_problems(item.name, [_material_shape(materials[0], root)[0]])
        if not item.get(BAKED_PROPERTY) and BAKED_UV in item.data.uv_layers:
            problems.append(f"{item.name} already has a UV map named {BAKED_UV}: rename it to "
                            f"bake.")
    if problems:
        raise LayoutError(" ".join(problems))
    for item in parts:
        # A mesh of its own, so that its UV map for baking, and the UV map the game reads, are
        # the part's alone, not those of the other parts sharing its mesh.
        if item.data.users > 1:
            item.data = item.data.copy()
        _unbake(item)
    scene, view_layer = bpy.context.scene, bpy.context.view_layer
    kept = (scene.render.engine, scene.cycles.samples, scene.world, view_layer.objects.active,
            [item for item in view_layer.objects if item.select_get()])
    world = bpy.data.worlds.new("Lauder bake")
    try:
        scene.render.engine = "CYCLES"
        scene.cycles.samples = BAKE_SAMPLES
        world.light_settings.distance = BAKE_OCCLUSION_DISTANCE
        scene.world = world
        for item in parts:
            materials = list(dict.fromkeys(_unbaked_materials(item)))
            earlier = (_made_by_bake(bpy.data.materials, item),
                       _made_by_bake(bpy.data.images, item))
            image = _bake_part(root, level, item, materials)
            if not item.get(BAKED_PROPERTY):
                _keep_unbaked(item)
                item[UNBAKED_UV] = next((layer.name for layer in item.data.uv_layers
                                         if layer.active_render), "")
            look = _baked_look(item, image, materials[0])
            for slot in item.material_slots:
                slot.link = "OBJECT"
                slot.material = look
            item.data.uv_layers[BAKED_UV].active_render = True
            item[BAKED_PROPERTY] = True
            # The earlier bake's material and image go, unless something else still shows them.
            for made, kind in zip(earlier, (bpy.data.materials, bpy.data.images)):
                if made is not None and made.users == 0:
                    kind.remove(made)
    finally:
        engine, samples, world_before, active, selected = kept
        scene.render.engine, scene.cycles.samples, scene.world = engine, samples, world_before
        bpy.data.worlds.remove(world)
        for item in view_layer.objects:
            item.select_set(item in selected)
        view_layer.objects.active = active
    return [item.name for item in parts]


def clear_occlusion(repository, level, chosen):
    """Give the chosen baked parts back the materials and UV map they showed before, and remove
    what their bake made: its UV map, and its material and image, with the image's file, unless
    something else, such as a duplicate of the part, still shows them. Returns their names."""
    root = Path(repository)
    parts = [item for item in chosen if item.library is None and item.get(BAKED_PROPERTY)]
    for item in parts:
        # A mesh of its own, so that removing the UV map for baking spares a linked duplicate.
        if item.data.users > 1:
            item.data = item.data.copy()
        look, image = _made_by_bake(bpy.data.materials, item), _made_by_bake(bpy.data.images, item)
        _unbake(item)
        for entry in json.loads(item[UNBAKED_MATERIALS]):
            material = bpy.data.materials.get(entry[1]) if entry[2] else None
            if material is not None:
                material.use_fake_user = False
        layer = item.data.uv_layers.get(BAKED_UV)
        if layer is not None:
            item.data.uv_layers.remove(layer)
        if look is not None and look.users == 0:
            bpy.data.materials.remove(look)
        if image is not None and image.users == 0:
            path = Path(bpy.path.abspath(image.filepath)).resolve()
            bpy.data.images.remove(image)
            if path == (root / baked_image(level.key, item.name)).resolve():
                path.unlink(missing_ok=True)
        for key in (BAKED_PROPERTY, UNBAKED_MATERIALS, UNBAKED_UV):
            if key in item:
                del item[key]
    return [item.name for item in parts]
