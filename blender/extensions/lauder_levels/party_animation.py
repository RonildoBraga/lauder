"""The shared humanoid Actions: one baked export timeline and typed runtime clip ranges.

The accepted saved Blender Actions are the motion source; no motion is reconstructed here.
The linked Armature's manifest declares names, loop intent and nominal travel speeds. Clip
durations and offsets are derived from the Actions' actual frame ranges on every export.
"""

import json
import math
from pathlib import Path

from .common import bpy, LayoutError, _library_path

PARTY_MODELS = ("miki", "laura", "tom")
PARTY_ANIMATIONS = "blender/animations/party.blend"
PARTY_SPEC = "lauder_party_animation"
PARTY_CASES = {
    "idle": "idle", "walk": "walk", "jog": "jog", "backward": "backward",
    "strafe_left": "strafeLeft", "strafe_right": "strafeRight", "aim": "aim",
    "fire": "fire", "hit": "hit", "run": "run", "sneak": "sneak",
}


def party_animation_of_file(path):
    """The repository of the exact shared motion source, or None for any other Blender file."""
    if not path:
        return None
    path = Path(path).resolve()
    if len(path.parents) < 3:
        return None
    root = path.parents[2]
    return str(root) if (root / PARTY_ANIMATIONS).resolve() == path else None


def party_manifest(spec, ranges):
    """Validate the shared declaration and derive one-cycle ranges from saved Action bounds."""
    if not isinstance(spec, dict) or spec.get("version") != 1:
        raise LayoutError("The shared party Armature needs a version 1 animation manifest.")
    if spec.get("root_motion") is not False:
        raise LayoutError("The party animation manifest must declare in-place root_motion false.")
    fps = spec.get("fps")
    if isinstance(fps, bool) or not isinstance(fps, int) or fps <= 0:
        raise LayoutError("The party animation manifest needs a positive integer fps.")
    entries = spec.get("clips")
    if not isinstance(entries, list) or [entry.get("name") for entry in entries
                                      if isinstance(entry, dict)] != list(PARTY_CASES):
        raise LayoutError("The party animation manifest must name each supported clip once, "
                          "in the declared order.")
    clips, frame = [], 1
    for entry in entries:
        name = entry["name"]
        action = entry.get("source_action")
        if action != f"party.{name}" or action not in ranges:
            raise LayoutError(f"The party {name} clip needs its saved party.{name} Action.")
        start, end = ranges[action]
        if (not all(math.isfinite(value) for value in (start, end)) or start != 1
                or end <= start or abs(end - round(end)) > 1e-5):
            raise LayoutError(f"The {action} Action must run from frame 1 to an integer endpoint.")
        speed = entry.get("nominal_speed")
        if (isinstance(speed, bool) or not isinstance(speed, (int, float))
                or not math.isfinite(speed) or speed < 0):
            raise LayoutError(f"The {action} Action needs a finite, nonnegative nominal speed.")
        loop = entry.get("loop")
        if not isinstance(loop, bool):
            raise LayoutError(f"The {action} Action needs an explicit loop flag.")
        count = round(end - start)
        event = entry.get("event_start", 0)
        if (isinstance(event, bool) or not isinstance(event, (int, float))
                or not math.isfinite(event) or event < 0 or event >= count / fps
                or (name not in ("fire", "hit") and event != 0)):
            raise LayoutError(f"The {action} event_start must be inside its reaction clip; "
                              "ordinary clips use zero.")
        clips.append(dict(name=name, source_action=action, start_frame=frame,
                          end_frame=frame + count, duration=count / fps,
                          nominal_speed=float(speed), loop=loop, event_start=float(event)))
        frame += count + 1
    return dict(fps=fps, end_frame=frame - 1, clips=clips)


def prepare_party_animation(collection, repository):
    """Bake the linked saved Actions into a scratch local timeline for this model's export."""
    rigs = [item for item in collection.all_objects if item.type == "ARMATURE"]
    if len(rigs) != 1:
        raise LayoutError("A party model needs exactly one humanoid Armature Object.")
    rig = rigs[0]
    if (rig.data.library is None
            or _library_path(rig.data.library) != (Path(repository) / PARTY_ANIMATIONS).resolve()):
        raise LayoutError("A party model must link the shared party.blend Armature and Actions.")
    try:
        spec = json.loads(rig.data[PARTY_SPEC])
    except (KeyError, TypeError, ValueError):
        raise LayoutError("The shared party Armature has no readable animation manifest.") from None
    # Unused linked IDs need not survive a canonical model save. The library owns the editable
    # Actions, so explicitly link them before rebuilding this model's scratch export timeline.
    required = [f"party.{name}" for name in PARTY_CASES]
    with bpy.data.libraries.load(str(_library_path(rig.data.library)), link=True,
                                 relative=True) as (available, wanted):
        wanted.actions = [name for name in required if name in available.actions]
    actions = {action.name: action for action in bpy.data.actions
               if action.library == rig.data.library}
    return bake_party_timeline(rig, spec, actions)


def bake_party_timeline(rig, spec, actions):
    """Concatenate exact saved joint keys, used by library authoring and scratch exports."""
    manifest = party_manifest(spec, {name: tuple(action.frame_range)
                                    for name, action in actions.items()})
    if len(rig.data.bones) != 17 or "ROOT" not in rig.data.bones:
        raise LayoutError("The party model must preserve its 17-bone skeleton including ROOT.")
    if rig.data.bones["ROOT"].use_deform:
        raise LayoutError("The party ROOT bone must remain a nondeforming parent.")
    channels = {}
    for clip in manifest["clips"]:
        action = actions[clip["source_action"]]
        if len(action.slots) != 1 or len(action.layers) != 1 or len(action.layers[0].strips) != 1:
            raise LayoutError(f"{action.name} must contain one baked humanoid Action slot.")
        bag = action.layers[0].strips[0].channelbag(action.slots[0])
        if bag is None or not bag.fcurves:
            raise LayoutError(f"{action.name} has no baked joint channels.")
        keys = set()
        for curve in bag.fcurves:
            key = (curve.data_path, curve.array_index)
            if not curve.data_path.startswith('pose.bones[') or curve.modifiers:
                raise LayoutError(f"{action.name} must contain ordinary baked bone keys only.")
            keys.add(key)
            values = channels.setdefault(key, [])
            for point in curve.keyframe_points:
                if (not all(math.isfinite(value) for value in point.co)
                        or point.co.x < 1 or point.co.x > action.frame_range[1] + 1e-5):
                    raise LayoutError(f"{action.name} has a nonfinite key or a key outside its clip.")
                if point.interpolation != "LINEAR":
                    raise LayoutError(f"{action.name} must use baked linear interpolation.")
                if curve.data_path == 'pose.bones["ROOT"].location':
                    axis = rig.data.bones["ROOT"].matrix_local.to_3x3().col[curve.array_index]
                    if math.hypot(axis.x, axis.y) * abs(point.co.y) > 1e-6:
                        raise LayoutError(f"{action.name} must remain in place without horizontal ROOT motion.")
                values.append((point.co.x + clip["start_frame"] - 1, point.co.y))
        if clip is manifest["clips"][0]:
            expected = keys
        elif keys != expected:
            raise LayoutError("Every party Action must key the same joint channels.")
    timeline = bpy.data.actions.new("party.runtime")
    slot = timeline.slots.new("OBJECT", "Party humanoid")
    layer = timeline.layers.new("Baked party clips")
    strip = layer.strips.new(type="KEYFRAME")
    bag = strip.channelbag(slot, ensure=True)
    for (path, index), values in channels.items():
        curve = bag.fcurves.new(path, index=index)
        curve.keyframe_points.add(len(values))
        curve.keyframe_points.foreach_set("co", [value for point in values for value in point])
        for point in curve.keyframe_points:
            point.interpolation = "LINEAR"
        curve.update()
    for bone in rig.pose.bones:
        bone.rotation_mode = "QUATERNION"
    binding = rig.animation_data_create()
    binding.action = timeline
    binding.action_slot = slot
    scene = bpy.context.scene
    scene.render.fps = manifest["fps"]
    scene.render.fps_base = 1
    scene.frame_start, scene.frame_end = 1, manifest["end_frame"]
    scene.frame_set(1)
    bpy.context.view_layer.update()
    return manifest


def emit_party_clips(manifest):
    """The one shared typed clip table, emitted by Miki's export from the shared source."""
    def number(value):
        return f"{value:.9f}".rstrip("0").rstrip(".") or "0"
    lines = [
        "// Written from blender/animations/party.blend by the Lauder Blender extension.",
        "// Do not edit it here: change the shared Actions, then export the miki model.",
        "// ./scripts/check verifies the source and export fingerprints.",
        "", "import Foundation", "", "enum PartyModelClips {",
        "  enum Clip: String, CaseIterable {",
    ]
    for name, case in PARTY_CASES.items():
        lines.append(f'    case {case}' + (f' = "{name}"' if name != case else ""))
    lines += ["  }", "", "  struct Take {", "    let start: TimeInterval",
              "    let end: TimeInterval", "    let nominalSpeed: Float", "    let loop: Bool",
              "    let eventStart: TimeInterval",
              "", "    var duration: TimeInterval { end - start }", "  }", "",
              "  static func take(for clip: Clip) -> Take {", "    switch clip {"]
    fps = manifest["fps"]
    for clip in manifest["clips"]:
        arguments = (f'start: {number((clip["start_frame"] - 1) / fps)}, '
                     f'end: {number((clip["end_frame"] - 1) / fps)}, '
                     f'nominalSpeed: {number(clip["nominal_speed"])}, '
                     f'loop: {str(clip["loop"]).lower()}, '
                     f'eventStart: {number(clip["event_start"])}')
        lines.append(f'    case .{PARTY_CASES[clip["name"]]}:')
        if len(f"      Take({arguments})") <= 100:
            lines.append(f"      Take({arguments})")
        else:
            lines += ["      Take(", f"        {arguments})"]
    lines += ["    }", "  }", "}", ""]
    return "\n".join(lines)


def package_party_animation(source, target):
    """Hold sparse animation endpoints before packaging the focused skeletal USDZ."""
    from pxr import Sdf, Usd, UsdSkel, UsdUtils

    stage = Usd.Stage.Open(str(source))
    if stage is None:
        raise LayoutError("The party skeletal USD export could not be read.")
    end = stage.GetEndTimeCode()
    animations = [prim for prim in stage.Traverse() if prim.IsA(UsdSkel.Animation)]
    if len(animations) != 1:
        raise LayoutError("The party export must contain exactly one skeletal animation.")
    for attribute in animations[0].GetAttributes():
        if attribute.GetTimeSamples():
            attribute.Set(attribute.Get(Usd.TimeCode(end)), Usd.TimeCode(end))
    stage.GetRootLayer().Save()
    if not UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(source)), str(target)):
        raise LayoutError("The party animated USDZ could not be packaged.")
