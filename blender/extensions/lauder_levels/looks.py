"""What a scene file shows: the materials and textures that the game can show as Blender does, and
the check of a level's Visual collection."""

import math
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from .common import (
    _and, ASSETS, bpy, _collection, is_lfs_pointer, _library_path, model_of_path, name_clashes,
    _relative, usd_name, VISUAL,
)


#: The shader nodes that may feed a material's Principled BSDF. Blender's USD export turns "simple
#: node trees containing Diffuse BSDF, Principled BSDF, Image Textures, UVMap, and Separate RGB
#: nodes" into the preview surfaces that RealityKit shows (Blender's manual, USD export). Lauder
#: keeps to the Principled BSDF and adds the Normal Map node, which carries a normal texture. Math
#: nodes may feed only Alpha, for a cut-off, as the manual describes. Separate Color is left out:
#: RealityKit drops a map read from an image's green or blue channel (ADR 0002).
SHADER_NODES = frozenset({"TEX_IMAGE", "UVMAP", "NORMAL_MAP", "REROUTE"})
#: The surface inputs that may take an image, each checked from Blender into RealityKit (ADR
#: 0002).
MAPPED_INPUTS = ("Base Color", "Roughness", "Metallic", "Normal", "Emission Color", "Alpha")
#: The kinds of texture file that a USDZ carries to the game.
TEXTURE_TYPES = (".png", ".jpg", ".jpeg")
#: The repository's policy (.gitattributes): a PNG or JPEG over 1 MiB needs a Git LFS rule of its
#: own.
LFS_IMAGE_BYTES = 1_048_576


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
    #: The Strength of each Normal Map node that feeds Normal, or None where nodes feed it, and the
    #: surface's Emission Strength. Blender's USD export leaves both out of the scene file when an
    #: image feeds the input.
    normal_strengths: tuple = ()
    emission_strength: float = 1.0


def _material(material):
    return material.name + (f" (from {material.source})" if material.source else "")


def material_problems(materials):
    """What stops the game from showing these materials as Blender does (ADR 0002): a surface
    other than a Principled BSDF, nodes that Blender's USD export cannot carry, images on inputs not
    checked in the game, maps that RealityKit drops or that the scene file would show at another
    strength, and names that USD would make the same, which the scene file would merge into one."""
    problems, by_name = [], {}
    for material in materials:
        by_name.setdefault(usd_name(material.name), []).append(material)
        if material.surface != "BSDF_PRINCIPLED":
            problems.append(f"The material {_material(material)} needs a Principled BSDF as its "
                            f"surface; the game shows nothing else.")
            continue
        for socket, nodes in material.feeds:
            if socket not in MAPPED_INPUTS:
                problems.append(f"The material {_material(material)} feeds its {socket} with "
                                f"nodes, and the game takes images only on "
                                f"{_and(MAPPED_INPUTS)}.")
                continue
            if any(kind == "SEPARATE_COLOR" for kind, _ in nodes):
                problems.append(f"The material {_material(material)} reads its {socket} from one "
                                f"channel of an image with Separate Color, and RealityKit drops "
                                f"the green and blue channels: give the map an image of its own "
                                f"and connect its Color, or its Alpha, straight to {socket}.")
                continue
            allowed = SHADER_NODES | ({"MATH"} if socket == "Alpha" else set())
            others = sorted({label for kind, label in nodes if kind not in allowed})
            if others:
                problems.append(f"The material {_material(material)} makes its {socket} with "
                                f"{_and(others)}, which the game cannot show: bake it into an "
                                f"image texture.")
        glowing = any(kind == "TEX_IMAGE" for socket, nodes in material.feeds
                      if socket == "Emission Color" for kind, _ in nodes)
        if glowing and not math.isclose(material.emission_strength, 1, abs_tol=1e-4):
            problems.append(f"The material {_material(material)} has an Emission Strength of "
                            f"{material.emission_strength:g} on an emission image, which the scene "
                            f"file leaves out, so the game shows the image at strength 1: set the "
                            f"strength to 1 and make the image as bright as it should glow, or "
                            f"disconnect it.")
        for strength in material.normal_strengths:
            if strength is None:
                problems.append(f"The material {_material(material)} feeds a Normal Map's Strength "
                                f"with nodes, which the scene file leaves out, so the game shows "
                                f"the map at full strength: disconnect them and set it to 1.")
            elif not math.isclose(strength, 1, abs_tol=1e-4):
                problems.append(f"The material {_material(material)} has a Normal Map Strength of "
                                f"{strength:g}, which the scene file leaves out, so the game shows "
                                f"the map at full strength: set it to 1, and make the image itself "
                                f"flatter if its bumps are too strong.")
    for key, same in sorted(by_name.items()):
        if len(same) > 1:
            names = _and([_material(each) for each in same])
            problems.append(f"The materials {names} would all be {key} in the scene file, where "
                            f"one replaces the others: give each a name of its own.")
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
    if shader.type != "BSDF_PRINCIPLED":
        return MaterialShape(material.name, source, shader.type), []
    feeds, images, strengths = [], [], []
    for each in shader.inputs:
        if not each.is_linked:
            continue
        nodes = _feeding(each)
        feeds.append((each.name, tuple(sorted({(node.type, node.bl_label) for node in nodes}))))
        images += [node.image for node in nodes if node.type == "TEX_IMAGE" and node.image]
        if each.name == "Normal":
            strengths += [None if node.inputs["Strength"].is_linked
                          else node.inputs["Strength"].default_value
                          for node in nodes if node.type == "NORMAL_MAP"]
    return MaterialShape(material.name, source, shader.type, tuple(feeds), tuple(strengths),
                         shader.inputs["Emission Strength"].default_value), images


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
