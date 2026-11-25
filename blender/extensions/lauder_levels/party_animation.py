"""Named humanoid profiles: saved Actions, a focused timeline and typed runtime metadata.

Laura/Tom link the shared party17 source; canonical Miki owns its fitted miki47 Actions.
Each Armature manifest declares names, loop intent and nominal speeds. Durations and offsets
come from the actual saved Action bounds; this exporter does not reconstruct character motion.
"""

import json
import math
from pathlib import Path

from .common import bpy, LayoutError, _library_path

PARTY_MODELS = ("miki", "laura", "tom")
PARTY_ANIMATIONS = "blender/animations/party.blend"
PARTY_SPEC = "lauder_party_animation"
PARTY_HIERARCHY = {"ROOT": None, "pelvis": "ROOT", "spine": "pelvis", "chest": "spine", "head": "chest"}
for _side in ("L", "R"):
    for _child, _parent in (("upper_arm", "chest"), ("forearm", "upper_arm"),
                            ("hand", "forearm"), ("thigh", "pelvis"),
                            ("shin", "thigh"), ("foot", "shin")):
        PARTY_HIERARCHY[f"{_child}.{_side}"] = (_parent if _parent in ("chest", "pelvis")
                                               else f"{_parent}.{_side}")
MIKI_HIERARCHY = dict(PARTY_HIERARCHY)
for _side in ("L", "R"):
    for _digit in ("thumb", "index", "middle", "ring", "pinky"):
        for _segment in range(1, 4):
            MIKI_HIERARCHY[f"{_digit}.{_segment:02}.{_side}"] = (
                f"hand.{_side}" if _segment == 1 else f"{_digit}.{_segment - 1:02}.{_side}")
PARTY_SCHEMAS = {"party17": PARTY_HIERARCHY, "miki47": MIKI_HIERARCHY}
MIKI_GARMENTS = ("Skirt_front_L", "Skirt_front_R", "Skirt_back_L", "Skirt_back_R")


def party_skeleton(profile, hierarchy, root_deforms=False):
    """Validate the named complete hierarchy; accepting a larger count alone is unsafe."""
    if profile not in PARTY_SCHEMAS or hierarchy != PARTY_SCHEMAS[profile]:
        raise LayoutError(f"The {profile} model must preserve its declared complete bone hierarchy.")
    if root_deforms:
        raise LayoutError("The party ROOT bone must remain a nondeforming parent.")
PARTY_CASES = {
    "idle": "idle", "walk": "walk", "jog": "jog", "backward": "backward",
    "strafe_left": "strafeLeft", "strafe_right": "strafeRight", "aim": "aim",
    "fire": "fire", "hit": "hit", "run": "run", "sneak": "sneak",
}



def party_channels(profile, channels):
    """Require each profile's complete joint channels, without silent finger/Euler loss."""
    if profile not in PARTY_SCHEMAS:
        raise LayoutError("Unknown party skeleton profile.")
    keys = list(channels)
    if any(not isinstance(key, (tuple, list)) or len(key) != 2
           or not isinstance(key[0], str) or isinstance(key[1], bool)
           or not isinstance(key[1], int) for key in keys):
        raise LayoutError("A party channel needs a bone property and integer component index.")
    keys = [tuple(key) for key in keys]
    if len(keys) != len(set(keys)):
        raise LayoutError("Duplicate party animation channels are not supported.")
    # Legacy party17 owns TR channels; its scale remains the unanimated bind scale.
    properties = (("location", 3), ("rotation_quaternion", 4))
    if profile == "miki47":
        properties += (("scale", 3),)
    expected = {(f'pose.bones["{bone}"].{prop}', index)
                for bone in PARTY_SCHEMAS[profile] for prop, count in properties
                for index in range(count)}
    if set(keys) != expected:
        raise LayoutError(f"Every {profile} Action must key its complete declared joint components "
                          "using quaternions, with no missing or additional channels.")

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
    profile = spec.get("profile", "party17")
    if profile not in PARTY_SCHEMAS:
        raise LayoutError("Unknown party skeleton profile.")
    prefix = "party" if profile == "party17" else "miki"
    entries = spec.get("clips")
    if not isinstance(entries, list) or [entry.get("name") for entry in entries
                                      if isinstance(entry, dict)] != list(PARTY_CASES):
        raise LayoutError("The party animation manifest must name each supported clip once, "
                          "in the declared order.")
    clips, frame = [], 1
    for entry in entries:
        name = entry["name"]
        action = entry.get("source_action")
        if action != f"{prefix}.{name}" or action not in ranges:
            raise LayoutError(f"The {profile} {name} clip needs its saved {prefix}.{name} Action.")
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
    return dict(profile=profile, fps=fps, end_frame=frame - 1, clips=clips)


def prepare_party_animation(collection, repository):
    """Bake the linked saved Actions into a scratch local timeline for this model's export."""
    rigs = [item for item in collection.all_objects if item.type == "ARMATURE"]
    if len(rigs) != 1:
        raise LayoutError("A party model needs exactly one humanoid Armature Object.")
    rig = rigs[0]
    try:
        spec = json.loads(rig.data[PARTY_SPEC])
    except (KeyError, TypeError, ValueError):
        raise LayoutError("The party Armature has no readable animation manifest.") from None
    profile = spec.get("profile", "party17")
    if profile == "miki47":
        if collection.name != "miki" or rig.data.library is not None:
            raise LayoutError("The miki47 profile belongs to Miki's local canonical source.")
        actions = {a.name: a for a in bpy.data.actions if a.library is None}
    else:
        if (profile != "party17" or rig.data.library is None
                or _library_path(rig.data.library) != (Path(repository) / PARTY_ANIMATIONS).resolve()):
            raise LayoutError("The party17 model must link the shared party.blend Armature and Actions.")
        required = [f"party.{name}" for name in PARTY_CASES]
        with bpy.data.libraries.load(str(_library_path(rig.data.library)), link=True,
                                     relative=True) as (available, wanted):
            wanted.actions = [name for name in required if name in available.actions]
        actions = {action.name: action for action in bpy.data.actions
                   if action.library == rig.data.library}
    manifest = bake_party_timeline(rig, spec, actions)
    if profile == "miki47":
        manifest["hand_calibration"] = json.loads(rig.data["lauder_hand_calibration"])
        manifest["garment_names"] = list(MIKI_GARMENTS)
    return manifest


def bake_party_timeline(rig, spec, actions):
    """Concatenate exact saved joint keys, used by library authoring and scratch exports."""
    manifest = party_manifest(spec, {name: tuple(action.frame_range)
                                    for name, action in actions.items()})
    party_skeleton(manifest["profile"],
                   {b.name: b.parent.name if b.parent else None for b in rig.data.bones},
                   rig.data.bones["ROOT"].use_deform if "ROOT" in rig.data.bones else True)
    channels = {}
    for clip in manifest["clips"]:
        action = actions[clip["source_action"]]
        if len(action.slots) != 1 or len(action.layers) != 1 or len(action.layers[0].strips) != 1:
            raise LayoutError(f"{action.name} must contain one baked humanoid Action slot.")
        bag = action.layers[0].strips[0].channelbag(action.slots[0])
        if bag is None or not bag.fcurves:
            raise LayoutError(f"{action.name} has no baked joint channels.")
        party_channels(manifest["profile"], [(c.data_path, c.array_index) for c in bag.fcurves])
        for curve in bag.fcurves:
            key = (curve.data_path, curve.array_index)
            if curve.modifiers or not curve.keyframe_points:
                raise LayoutError(f"{action.name} must contain ordinary nonempty baked bone keys only.")
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


def shared_party_manifest(repository):
    """Read the unchanged shared source for its independent party17 timing table."""
    path = Path(repository) / PARTY_ANIMATIONS
    with bpy.data.libraries.load(str(path), link=True, relative=True) as (available, wanted):
        wanted.armatures = ["Party humanoid skeleton"]
        wanted.actions = [f"party.{name}" for name in PARTY_CASES]
    data = wanted.armatures[0]
    spec = json.loads(data[PARTY_SPEC])
    return party_manifest(spec, {a.name: tuple(a.frame_range) for a in wanted.actions})


def emit_party_clips(manifest):
    """Typed per-profile source timings, measured hand frames and exact named rig contracts."""
    def number(value):
        return f"{value:.9f}".rstrip("0").rstrip(".") or "0"

    def quaternion(values):
        w, x, y, z = values
        return f"simd_quatf(real: {number(w)}, imag: [{number(x)}, {number(y)}, {number(z)}])"

    profiles = manifest if "clips" not in manifest else {manifest["profile"]: manifest}
    lines = [
        "// Written from canonical Miki and blender/animations/party.blend by the Lauder Blender extension.",
        "// Do not edit: change the saved Actions/calibration, then export the miki model.",
        "// ./scripts/check verifies the source and export fingerprints.",
        "", "import Foundation", "import simd", "", "enum PartyModelClips {",
        "  enum Profile: String, CaseIterable {",
    ]
    for profile in profiles:
        lines.append(f"    case {profile}")
    lines += ["  }", "", "  enum Clip: String, CaseIterable {"]
    for name, case in PARTY_CASES.items():
        lines.append(f'    case {case}' + (f' = "{name}"' if name != case else ""))
    lines += ["  }", "", "  struct Take {", "    let start: TimeInterval",
              "    let end: TimeInterval", "    let nominalSpeed: Float", "    let loop: Bool",
              "    let eventStart: TimeInterval", "", "    var duration: TimeInterval { end - start }",
              "  }", "", "  struct HandGrip {", "    let offset: SIMD3<Float>",
              "    let rotation: simd_quatf", "  }", "",
              "  static func profile(for jointNames: [String]) -> Profile? {",
              '    let names = jointNames.map { String($0.split(separator: "/").last ?? "") }',
              "    guard Set(names).count == names.count else { return nil }"]
    for profile in profiles:
        names = sorted(name.replace(".", "_") for name in PARTY_SCHEMAS[profile])
        lines += ["    if Set(names)", "      == Set(["]
        lines += ['        ' + ', '.join(json.dumps(n) for n in names[i:i + 4]) + ','
                  for i in range(0, len(names), 4)]
        lines += ["      ])", "    {", f"      return .{profile}", "    }"]
    lines += ["    return nil", "  }", "",
              "  static func take(for clip: Clip, profile: Profile = .party17) -> Take {",
              "    switch profile {"]
    for profile, data in profiles.items():
        lines += [f"    case .{profile}:", "      switch clip {"]
        fps = data["fps"]
        for clip in data["clips"]:
            arguments = (f'start: {number((clip["start_frame"] - 1) / fps)}, '
                         f'end: {number((clip["end_frame"] - 1) / fps)}, '
                         f'nominalSpeed: {number(clip["nominal_speed"])}, '
                         f'loop: {str(clip["loop"]).lower()}, '
                         f'eventStart: {number(clip["event_start"])}')
            lines += [f'      case .{PARTY_CASES[clip["name"]]}:']
            if len(f"        Take({arguments})") <= 100:
                lines.append(f"        Take({arguments})")
            else:
                lines += ["        Take(", f"          {arguments}", "        )"]
        lines.append("      }")
    lines += ["    }", "  }", "",
              "  static func handGrip(left: Bool, profile: Profile) -> HandGrip? {"]
    if "miki47" in profiles:
        lines += ["    guard profile == .miki47 else { return nil }", "    if left {"]
        for side in ("L", "R"):
            grip = profiles["miki47"]["hand_calibration"]["grips"][side]
            offset = ', '.join(number(v) for v in grip["offset"])
            lines += ["      return HandGrip(", f"        offset: [{offset}],", f"        rotation: {quaternion(grip['rotation'])})"]
            if side == "L": lines.append("    } else {")
        lines.append("    }")
    else:
        lines.append("    return nil")
    lines += ["  }", "", "  static func garmentNames(profile: Profile) -> [String] {"]
    if "miki47" in profiles:
        names = ', '.join(json.dumps(n) for n in MIKI_GARMENTS)
        lines += [f"    profile == .miki47 ? [{names}] : []"]
    else:
        lines.append("    []")
    lines += ["  }", "}", ""]
    return "\n".join(lines)


def package_party_animation(source, target, profile="party17"):
    """Hold sparse animation endpoints before packaging the focused skeletal USDZ."""
    from pxr import Sdf, Usd, UsdSkel, UsdUtils

    stage = Usd.Stage.Open(str(source))
    if stage is None:
        raise LayoutError("The party skeletal USD export could not be read.")
    end = stage.GetEndTimeCode()
    animations = [prim for prim in stage.Traverse() if prim.IsA(UsdSkel.Animation)]
    joints = [prim for prim in animations if UsdSkel.Animation(prim).GetJointsAttr().Get()]
    if len(joints) != 1:
        raise LayoutError("The party export must contain exactly one joint animation.")
    morphs = {str(name) for prim in animations
              for name in (UsdSkel.Animation(prim).GetBlendShapesAttr().Get() or [])}
    expected = set(MIKI_GARMENTS) if profile == "miki47" else set()
    if morphs != expected:
        raise LayoutError("The party export's morph channels do not match its declared profile.")
    for animation in animations:
        for attribute in animation.GetAttributes():
            if attribute.GetTimeSamples():
                attribute.Set(attribute.Get(Usd.TimeCode(end)), Usd.TimeCode(end))
    stage.GetRootLayer().Save()
    if not UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(source)), str(target)):
        raise LayoutError("The party animated USDZ could not be packaged.")
