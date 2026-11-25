"""Refresh a fitted study's derived clips from the unchanged shared motion library.

Call refresh_target(rig, skinned_meshes, source_library, fit) inside Blender.
This function changes only local derived Actions; the caller owns study-file saving.
fit stores the captured source boot/palm anchors and chosen target palm anchors.
The helper does not author new source motion or save canonical files.
"""
import hashlib
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector, Matrix


def refresh_target(rig, body_objects, source_library, fit):
    if rig.type != 'ARMATURE' or rig.library or rig.data.library:
        raise ValueError('A local fitted study rig is required')
    if 'fullbody' not in rig.name.lower() or not rig.get('review_only'):
        raise ValueError('This helper is restricted to the fitted full-body study')
    source_library = Path(source_library).resolve()
    if Path(bpy.data.filepath).resolve() == source_library:
        raise ValueError('The shared source cannot be a fitted target')
    if any(abs(rig.matrix_world[i][j] - (1. if i == j else 0.)) > 1e-6 for i in range(4) for j in range(4)):
        raise ValueError('Fitted rig object transform must be identity')
    scene = bpy.context.scene
    scene.render.fps = 120
    scene.render.fps_base = 1.
    # Pose correctives are tied to the exact shared-motion revision used to sculpt them.
    # A changed source needs a deliberate corrective review, not stale automatic reuse.
    source_digest = hashlib.sha256(source_library.read_bytes()).hexdigest()
    if any(o.type == 'MESH' and o.data.shape_keys for o in body_objects):
        if rig.get('motion_source_sha256') != source_digest:
            raise ValueError('Shared motion changed; reauthor and review garment correctives before refreshing')
    previous_actions = set(bpy.data.actions)
    previous_armatures = set(bpy.data.armatures)
    with bpy.data.libraries.load(str(source_library), link=True) as (src, dst):
        dst.armatures = list(src.armatures)
        dst.actions = [n for n in src.actions if n.startswith('party.') and n != 'party.runtime']
    source = bpy.data.objects.new('Temporary shared motion sampler', dst.armatures[0])
    scene.collection.objects.link(source)
    bpy.context.view_layer.update()
    for pb in source.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    source.animation_data_create()
    shared = list(dst.actions)
    if len(shared) != 11 or set(source.data.bones.keys()) != set(rig.data.bones.keys()):
        raise ValueError('Expected the unchanged 17-bone/11-clip shared contract')
    src_rest = {b.name: b.matrix_local.copy() for b in source.data.bones}
    target_rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
    rest_signature = hashlib.sha256(json.dumps([
        [b.name, b.parent.name if b.parent else None, [[round(v, 8) for v in row] for row in b.matrix_local]]
        for b in sorted(source.data.bones, key=lambda b: b.name)
    ], separators=(',', ':')).encode()).hexdigest()
    if fit.get('source_rest_signature') not in (None, rest_signature):
        raise ValueError('Shared rest hierarchy changed; refit the target before refreshing motion')
    fit['source_rest_signature'] = rest_signature

    source_feet = {s: [Vector(p) for p in fit['source_feet'][s]] for s in ['L', 'R']}
    source_palms = {s: Vector(fit['source_palms'][s]) for s in ['L', 'R']}
    target_palms = {s: Vector(fit['target_palms'][s]) for s in ['L', 'R']}
    target_feet = {s: [] for s in ['L', 'R']}
    for obj in body_objects:
        if obj.type != 'MESH':
            continue
        groups = {g.index: g.name for g in obj.vertex_groups}
        for v in obj.data.vertices:
            p = obj.matrix_world @ v.co
            if p.z >= .026:
                continue
            side = 'L' if p.x > 0 else 'R'
            if any(groups.get(g.group) == 'foot.' + side and g.weight > .99999 for g in v.groups):
                target_feet[side].append(p)
    if not all(target_feet.values()):
        raise ValueError('Both actual sole regions must have rigid foot weights')
    ratio = ((rig.data.bones['thigh.L'].head_local.z - rig.data.bones['foot.L'].head_local.z)
             / (source.data.bones['thigh.L'].head_local.z - source.data.bones['foot.L'].head_local.z))
    rig.animation_data_create()
    previous_action = rig.animation_data.action
    previous_frame, previous_subframe = scene.frame_current, scene.frame_subframe
    previous_basis = {pb.name: pb.matrix_basis.copy() for pb in rig.pose.bones}
    track_mutes = [(t, t.mute) for t in rig.animation_data.nla_tracks]
    for t, _ in track_mutes:
        t.mute = True
    source_hash = hashlib.sha256(source_library.read_bytes()).hexdigest()

    def hand_ik(pose):
        src_chest = source.pose.bones['chest'].matrix
        def mapped(point):
            v = src_chest.inverted() @ point
            v.x *= .85
            v.y *= .95
            v.z *= 1.15
            return pose['chest'] @ v
        goals = {side: mapped(source.pose.bones['hand.' + side].matrix @ src_rest['hand.' + side].inverted() @ source_palms[side]) for side in ['L', 'R']}
        if fit.get('weapon_grip_delta'):
            grip = Vector(fit['weapon_grip_delta'])
            original = goals['L'] - goals['R']
            horizontal = Vector((original.x, original.y, 0))
            if horizontal.length < 1e-6:
                horizontal = Vector((0, -1, 0))
            horizontal.normalize()
            pitch = math.radians(fit.get('weapon_low_ready_pitch_degrees', -6.))
            forward = horizontal * math.cos(pitch) + Vector((0, 0, math.sin(pitch)))
            right = forward.cross(Vector((0, 0, 1))).normalized()
            up = right.cross(forward).normalized()
            rotation = Matrix((right, forward, up)).transposed()
            goals['L'] = goals['R'] + rotation @ grip * (original.length / grip.length)
        for side in ['L', 'R']:
            upper, fore, hand = ('upper_arm.' + side, 'forearm.' + side, 'hand.' + side)
            source_palm = source.pose.bones[hand].matrix @ src_rest[hand].inverted() @ source_palms[side]
            goal = goals[side]
            delta = pose[hand].to_3x3() @ target_rest[hand].to_3x3().inverted()
            wrist = goal - delta @ (target_palms[side] - rig.data.bones[hand].head_local)
            shoulder = pose[upper].translation.copy()
            direction = (wrist - shoulder).normalized()
            u, f = rig.data.bones[upper].length, rig.data.bones[fore].length
            distance = min(max((wrist - shoulder).length, abs(u - f) + .001), u + f - .001)
            wrist = shoulder + direction * distance
            pole = mapped(source.pose.bones[fore].matrix.translation) - shoulder
            pole -= direction * pole.dot(direction)
            if pole.length < 1e-5:
                pole = Vector((0, 1, 0))
                pole -= direction * pole.dot(direction)
            along = (u*u - f*f + distance*distance) / (2*distance)
            height = math.sqrt(max(0., u*u - along*along))
            elbow = shoulder + direction*along + pole.normalized()*height
            for name, head, tail in [(upper, shoulder, elbow), (fore, elbow, wrist)]:
                orient = pose[name].to_3x3()
                swing = orient.col[1].normalized().rotation_difference((tail-head).normalized())
                matrix = (swing.to_matrix() @ orient).to_4x4()
                matrix.translation = head
                pose[name] = matrix
            pose[hand].translation = wrist

    records = {}
    try:
        for src_action in shared:
            source.animation_data.action = src_action
            source.animation_data.action_slot = src_action.slots[0]
            name = 'miki.fitted.' + src_action.name.removeprefix('party.')
            action = bpy.data.actions.get(name)
            if action and action.library:
                raise ValueError('Cannot overwrite a linked source Action')
            if action:
                for layer in action.layers:
                    for strip in layer.strips:
                        for bag in strip.channelbags:
                            for curve in list(bag.fcurves):
                                bag.fcurves.remove(curve)
            else:
                action = bpy.data.actions.new(name)
            action.use_fake_user = True
            action['source_action'] = src_action.name
            action['source_library'] = 'blender/animations/party.blend'
            action['source_sha256'] = source_hash
            action['method'] = 'fitted FK global rotation deltas; source sole contact; source-relative palm IK with optional independent weapon grip span for aim/fire'
            action['fps'] = 120
            rig.animation_data.action = action
            start, end = map(int, src_action.frame_range)
            if start != 1:
                raise ValueError('Shared clips must begin at frame 1')
            for frame in range(start, end+1):
                scene.frame_set(frame)
                bpy.context.view_layer.update()
                pose = {}
                for bone in rig.data.bones:
                    n = bone.name
                    delta = source.pose.bones[n].matrix.to_3x3() @ src_rest[n].to_3x3().inverted()
                    matrix = (delta @ target_rest[n].to_3x3()).to_4x4()
                    matrix.translation = (pose[bone.parent.name] @ target_rest[bone.parent.name].inverted() @ bone.head_local
                                          if bone.parent else Vector((0, 0, 0)))
                    pose[n] = matrix
                if src_action.name in ['party.fire', 'party.aim']:
                    hand_ik(pose)
                source_min = min((source.pose.bones['foot.'+s].matrix @ src_rest['foot.'+s].inverted() @ p).z
                                 for s in ['L', 'R'] for p in source_feet[s])
                target_min = min((pose['foot.'+s] @ target_rest['foot.'+s].inverted() @ p).z
                                 for s in ['L', 'R'] for p in target_feet[s])
                correction = max(0., source_min)*ratio - target_min
                for matrix in pose.values():
                    matrix.translation.z += correction
                for bone in rig.data.bones:
                    parent = bone.parent
                    pb = rig.pose.bones[bone.name]
                    pb.rotation_mode = 'QUATERNION'
                    pb.matrix_basis = bone.convert_local_to_pose(
                        pose[bone.name], bone.matrix_local,
                        parent_matrix=pose[parent.name] if parent else Matrix.Identity(4),
                        parent_matrix_local=parent.matrix_local if parent else Matrix.Identity(4), invert=True)
                    for prop in ['location', 'rotation_quaternion', 'scale']:
                        pb.keyframe_insert(prop, frame=frame, group=bone.name)
                if frame == start:
                    rig.animation_data.action_slot = action.slots[0]
            for layer in action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for curve in bag.fcurves:
                            for key in curve.keyframe_points:
                                key.interpolation = 'LINEAR'
            records[src_action.name] = {'target_action': name, 'frames': [start, end]}
        rig['motion_source_sha256'] = source_hash
        rig['motion_fit'] = json.dumps(fit, separators=(',', ':'))
        return records
    finally:
        rig.animation_data.action = None
        for pb in rig.pose.bones:
            pb.matrix_basis = previous_basis[pb.name]
        rig.animation_data.action = previous_action
        if previous_action:
            rig.animation_data.action_slot = previous_action.slots[0]
        for track, mute in track_mutes:
            track.mute = mute
        bpy.data.objects.remove(source, do_unlink=True)
        for action in list(bpy.data.actions):
            if action not in previous_actions and action.library:
                bpy.data.actions.remove(action)
        for data in list(bpy.data.armatures):
            if data not in previous_armatures and data.users == 0:
                bpy.data.armatures.remove(data)


        scene.frame_set(previous_frame, subframe=previous_subframe)

def main():
    """Refresh only this unregistered study; save no canonical model/library."""
    folder = Path(__file__).resolve().parent
    expected = folder / 'character' / 'miki-fullbody-fit.blend'
    if Path(bpy.data.filepath).resolve() != expected:
        raise ValueError('Open this study character source before refreshing its motion')
    rigs = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    if len(rigs) != 1:
        raise ValueError('Expected one fitted study rig')
    rig = rigs[0]
    fit = json.loads(rig['motion_fit'])
    source = folder.parents[2] / 'blender' / 'animations' / 'party.blend'
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    refresh_target(rig, meshes, source, fit)
    rig.animation_data_clear()
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.scene.frame_set(0)
    bpy.data.orphans_purge(do_recursive=True)
    import sys
    sys.path.insert(0, str(folder.parents[1] / 'extensions'))
    from lauder_levels import forget_local_paths
    for scene in bpy.data.scenes:
        scene.render.filepath = ' ' * 1023
        scene.render.filepath = '//'
    forget_local_paths(expected)
    bpy.ops.wm.save_as_mainfile(filepath=str(expected), relative_remap=False, compress=True)

if __name__ == '__main__':
    main()
