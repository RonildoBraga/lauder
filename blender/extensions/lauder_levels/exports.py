"""Exporting: writing a level's or a model's files for the game from Blender, and the record of what
each export was made from, which ./scripts/check holds them to."""

import json
import shutil
import tempfile
from pathlib import Path

from .common import (
    bpy, _collection, EXPORT_FORMAT, EXPORT_RECORD, file_fingerprint, LayoutError, LEVELS,
    model_file, MODEL_METADATA, PREVIEW, SPAWNED, SPAWNED_SCENES, VISUAL,
)
from .layouts import emit_layout, layout_from_blender
from .looks import visual_problems, what_collection_shows
from .models import check_model
from .robot_geometry import emit_robot_geometry, ROBOT


def _records(repository):
    path = Path(repository) / EXPORT_RECORD
    try:
        return json.loads(path.read_text()) if path.exists() else {}
    except ValueError:
        return {}  # Unreadable: every level counts as stale, and the next export rewrites it.


def _stale(repository, key, title, source, outputs, what):
    """Why the export recorded under `key` no longer matches what it was made from, or None. It
    must have been made from `source` and have written `outputs`; `what` names what to change."""
    root = Path(repository)
    start = title[0].upper() + title[1:]
    record = _records(repository).get(key)
    if record is None:
        return f"{start} has not been exported."
    if record.get("format") != EXPORT_FORMAT:
        return f"{start} was exported by an earlier version of the Lauder extension."
    made_from, wrote = record.get("made from", {}), record.get("wrote", {})
    if source not in made_from or set(outputs) - set(wrote):
        return f"{EXPORT_RECORD} does not say how {title} was exported."
    for name, fingerprint in made_from.items():
        if not (root / name).exists():
            return f"{name} is missing."
        if file_fingerprint(root / name) != fingerprint:
            return f"{name} changed since {title} was exported."
    for name, fingerprint in wrote.items():
        if not (root / name).exists():
            return f"{name} is missing."
        if file_fingerprint(root / name) != fingerprint:
            return (f"{name} changed since it was exported. Export writes it: change {what} in "
                    f"Blender instead.")
    return None


def stale_exports(repository, key="brooklyn-bridge"):
    """Why the level's exports no longer match what they were made from, or None when they do."""
    level = LEVELS[key]
    return _stale(repository, key, level.title, level.blend, (level.layout, level.scene),
                  "the level")


def spawned_scene(name):
    """The scene file of a model that the game creates (SPAWNED), relative to the repository."""
    return f"{SPAWNED_SCENES}/{name}.usdz"


def _model_key(name):
    """Where the export record keeps a spawned model's export."""
    return f"models/{name}"


def stale_model_export(repository, name):
    """Why the scene file of a model that the game creates (SPAWNED) no longer matches its files,
    or None when it does."""
    outputs = (spawned_scene(name),) + ((MODEL_METADATA[name],) if name in MODEL_METADATA else ())
    return _stale(repository, _model_key(name), f"the {name} model", model_file(name),
                  outputs, "the model")


def record_exports(repository, key, made_from, wrote):
    """Record what the export kept under `key`, a level's key or a spawned model's (_model_key),
    was made from and what it wrote, with fingerprints."""
    records = _records(repository)
    records[key] = {"format": EXPORT_FORMAT, "made from": made_from, "wrote": wrote}
    path = Path(repository) / EXPORT_RECORD
    path.write_text(json.dumps(records, indent=2, sort_keys=True) + "\n")


def levels_using(repository, name):
    """The levels whose last export used this file, such as a model, relative to the repository."""
    return [key for key, record in _records(repository).items()
            if key in LEVELS and name in record.get("made from", {})]


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


def _open_for_export(path):
    """Open a level's or model's Blender file to export it, without its Preview collection, which
    is never exported, and without the models and textures that only Preview uses, so that they
    count neither among the files an export is made from nor among what it checks."""
    bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False)
    preview = _collection(PREVIEW)
    if preview is None:
        return
    inside = {preview, *preview.children_recursive}
    for item in list(preview.all_objects):
        if set(item.users_collection) <= inside:
            bpy.data.objects.remove(item, do_unlink=True)
    for collection in inside:
        bpy.data.collections.remove(collection)
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    for library in [item for item in bpy.data.libraries if not item.users_id]:
        bpy.data.libraries.remove(library)


#: How often an export opens a file again while the files it uses keep changing.
_OPEN_ATTEMPTS = 3


def _open_with_fingerprints(repository, blend):
    """Open a level's or model's Blender file to export it (_open_for_export), and return the
    fingerprints of it and of every file it uses, such as models and textures, relative to the
    repository. Each fingerprint is taken before its file is read, so a save that lands meanwhile
    leaves the export stale, to be exported again, and never recorded as current. The file is
    opened to find the files it uses, then again to read them, until no file it then uses went
    without a fingerprint first."""
    root = Path(repository)
    made_from = {blend: file_fingerprint(root / blend)}
    _open_for_export(root / blend)
    for _ in range(_OPEN_ATTEMPTS):
        for name in _files_used(root):
            if name not in made_from and (root / name).is_file():
                made_from[name] = file_fingerprint(root / name)
        _open_for_export(root / blend)
        # A file still missing has no fingerprint, and the export refuses it.
        unread = [name for name in _files_used(root)
                  if name not in made_from and (root / name).is_file()]
        if not unread:
            return made_from
    raise LayoutError(f"The files {blend} uses kept changing while it was read; export it again.")


def open_level_file(repository, key):
    """Open the level's Blender file to export it, with the fingerprints of its files
    (_open_with_fingerprints)."""
    return _open_with_fingerprints(repository, LEVELS[key].blend)


def open_model_file(repository, name):
    """Open the Blender file of a model that the game creates to export it, with the fingerprints
    of its files (_open_with_fingerprints)."""
    return _open_with_fingerprints(repository, model_file(name))


def _fingerprints(root, blend, made_from, whose):
    """The fingerprints of `blend` and of every file it uses, keeping those taken before the files
    were read (`made_from`). A missing file refuses the export: `whose` file refers to it."""
    made_from = dict(made_from or {})
    for name in [blend] + _files_used(root):
        if not (root / name).is_file():
            raise LayoutError(f"{name} is missing, and {whose} refers to it.")
        if name not in made_from:
            made_from[name] = file_fingerprint(root / name)
    return made_from


def _keep_only(collection, kept):
    """Leave only `collection` in the scene, which the USD export writes whole, and remove every
    local object not in `kept`: not even a model linked straight into another collection stays,
    since its objects belong to its own file."""
    scene = bpy.context.scene
    if collection not in list(scene.collection.children):
        scene.collection.children.link(collection)
    for child in list(scene.collection.children):
        if child != collection:
            scene.collection.children.unlink(child)
    for item in list(scene.collection.objects):
        scene.collection.objects.unlink(item)
    for item in list(bpy.data.objects):
        if item.library is None and item not in kept:
            bpy.data.objects.remove(item, do_unlink=True)


def export_level(repository, key, made_from=None):
    """Write the level's layout file and scene file from its Blender file, open in this Blender,
    and record what they were made from. `made_from` holds the fingerprints of the level's files
    from before they were read (open_level_file), so that a save made since counts as a change. It
    changes the open file, so it runs in a Blender of its own: blender/scripts/export-level.py."""
    level = LEVELS[key]
    root = Path(repository)
    text = emit_layout(check_level(repository, level), level)
    made_from = _fingerprints(root, level.blend, made_from, "the level file")
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
    _keep_only(visual, shown)
    written, target = root / level.layout, root / level.scene
    with tempfile.TemporaryDirectory() as folder:
        exported = Path(folder) / target.name
        bpy.ops.wm.usd_export(filepath=str(exported), **SCENE_EXPORT)
        # Both exports are ready: only now is either written, so a refusal or a failure before
        # this leaves the pair as it was.
        if not written.exists() or written.read_text() != text:
            written.write_text(text)
        shutil.copyfile(exported, target)
    record_exports(repository, level.key, made_from,
                   {name: file_fingerprint(root / name) for name in (level.layout, level.scene)})
    return target


def export_model(repository, name, made_from=None):
    """Write the scene file of a model that the game creates (SPAWNED) from its Blender file, open
    in this Blender (open_model_file), once the intake check finds nothing to fix, and record what
    it was made from. It changes the open file, so it runs in a Blender of its own:
    blender/scripts/export-model.py."""
    root = Path(repository)
    if name not in SPAWNED:
        raise LayoutError(f"The game does not create {name} itself, so it has no scene file of its "
                          f"own: the levels that use it show it.")
    problems, _ = check_model(repository)
    if problems:
        raise LayoutError(" ".join(problems))
    made_from = _fingerprints(root, model_file(name), made_from, "the model's file")
    if name == ROBOT:
        generator = "blender/extensions/lauder_levels/robot_geometry.py"
        made_from[generator] = file_fingerprint(root / generator)
    metadata = emit_robot_geometry() if name == ROBOT else None
    options = dict(SCENE_EXPORT)
    if name == ROBOT:
        # Local joint transforms and leaf muzzle names are part of this model's contract.
        bpy.context.scene.frame_set(1)
        options["merge_parent_xform"] = False
    # Only the model's collection is exported, as the level export exports only Visual. Parts
    # hidden from renders stay out, as the intake check says.
    model = next(each for each in bpy.data.collections
                 if each.library is None and each.name == name)
    _keep_only(model, set(model.all_objects))
    target = root / spawned_scene(name)
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as folder:
        exported = Path(folder) / target.name
        bpy.ops.wm.usd_export(filepath=str(exported), **options)
        shutil.copyfile(exported, target)
    wrote = {spawned_scene(name): file_fingerprint(target)}
    if metadata is not None:
        path = root / MODEL_METADATA[name]
        path.write_text(metadata)
        wrote[MODEL_METADATA[name]] = file_fingerprint(path)
    record_exports(repository, _model_key(name), made_from, wrote)
    return target
