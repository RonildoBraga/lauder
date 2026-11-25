"""Regenerate this review's two fitted clips from the preserved shared source.

Inside Blender call refresh_target(rig, body, source_library).
rig.motion_fit stores source/target rest signatures, source_soles and sole binding signature.
The target is a local identity-transform 17-bone study rig, never the canonical source.
No mesh, rest joint, skin weight, source Action or saved file is changed.
"""
from pathlib import Path
import hashlib
import json
import math
import bpy
from mathutils import Matrix, Vector, Quaternion


def source_rest_signature(data):
    return hashlib.sha256(json.dumps([
        [bone.name, bone.parent.name if bone.parent else None,
         [[round(value, 8) for value in row] for row in bone.matrix_local]]
        for bone in sorted(data.bones, key=lambda bone: bone.name)
    ], separators=(',', ':')).encode()).hexdigest()


def sole_binding(body):
    if body.type != 'MESH':
        raise ValueError('Expected the fitted study body')
    groups = {group.index: group.name for group in body.vertex_groups}
    soles, signature = {'L': [], 'R': []}, []
    for vertex in body.data.vertices:
        point = body.matrix_world @ vertex.co
        if point.z >= .025:
            continue
        side = 'L' if point.x > 0 else 'R'
        weights = {groups[item.group]: item.weight for item in vertex.groups}
        if weights.get('foot.' + side, 0.) < .99999:
            raise ValueError('Every actual sole vertex must remain rigidly foot-bound')
        soles[side].append(point)
        signature.append([vertex.index, side, *[round(value, 8) for value in point]])
    return soles, hashlib.sha256(json.dumps(signature, separators=(',', ':')).encode()).hexdigest()


def offset_sneak_arms(poses, rig, rest, fit):
    outset = fit.get('sneak_hand_outset_m', 0.)
    if not outset:
        return
    chest_delta = poses['chest'].to_3x3() @ rest['chest'].to_3x3().inverted()
    for side, sign in [('L', 1), ('R', -1)]:
        upper, fore, hand = ('upper_arm.' + side, 'forearm.' + side, 'hand.' + side)
        shoulder = poses[upper].translation.copy()
        goal = poses[hand].translation + chest_delta @ Vector((sign * outset, fit.get('sneak_hand_forward_m', -.02), fit.get('sneak_hand_up_m', .01)))
        direction = (goal - shoulder).normalized()
        u, f = rig.data.bones[upper].length, rig.data.bones[fore].length
        distance = min(max((goal - shoulder).length, abs(u - f) + .0001), u + f - .0001)
        wrist = shoulder + direction * distance
        pole = poses[fore].translation - shoulder
        pole -= direction * pole.dot(direction)
        if pole.length < 1e-6:
            pole = chest_delta @ Vector((0, 1, 0))
            pole -= direction * pole.dot(direction)
        along = (u*u - f*f + distance*distance) / (2 * distance)
        elbow = shoulder + direction * along + pole.normalized() * math.sqrt(max(0., u*u - along*along))
        for name, head, tail in [(upper, shoulder, elbow), (fore, elbow, wrist)]:
            rotation = poses[name].to_3x3()
            swing = rotation.col[1].normalized().rotation_difference((tail - head).normalized())
            poses[name] = (swing.to_matrix() @ rotation).to_4x4()
            poses[name].translation = head
        poses[hand].translation = wrist


def refresh_target(rig, body, source_library):
    if rig.type != 'ARMATURE' or rig.library or rig.data.library or not rig.get('review_only'):
        raise ValueError('Expected a local fitted review rig')
    if len(rig.data.bones) != 17:
        raise ValueError('Expected the fitted 17-bone hierarchy')
    if any(abs(rig.matrix_world[i][j] - float(i == j)) > 1e-6 for i in range(4) for j in range(4)):
        raise ValueError('Review rig object transform must be identity')
    fit = json.loads(rig['motion_fit'])
    if source_rest_signature(rig.data) != fit['target_rest_signature']:
        raise ValueError('Target rest skeleton changed; refit before refreshing')
    target_soles, binding = sole_binding(body)
    if binding != fit['sole_binding_signature']:
        raise ValueError('Target sole geometry/binding changed; refit before refreshing')
    source_library = Path(source_library).resolve()
    if Path(bpy.data.filepath).resolve() == source_library:
        raise ValueError('The shared source cannot be the fitted target')
    source_sha = hashlib.sha256(source_library.read_bytes()).hexdigest()
    if source_sha != fit['source_sha256']:
        raise ValueError('Shared motion changed; refit and review rather than reusing stale fitting')
    scene = bpy.context.scene
    old_frame, old_subframe = scene.frame_current, scene.frame_subframe
    old_actions, old_data = set(bpy.data.actions), set(bpy.data.armatures)
    rig.animation_data_create()
    old_action, old_slot = rig.animation_data.action, rig.animation_data.action_slot
    old_bases = {pb.name: pb.matrix_basis.copy() for pb in rig.pose.bones}
    tracks = [(track, track.mute) for track in rig.animation_data.nla_tracks]
    sampler = None
    try:
        for track, _ in tracks:
            track.mute = True
        with bpy.data.libraries.load(str(source_library), link=True) as (available, wanted):
            wanted.armatures = list(available.armatures)
            wanted.actions = [n for n in available.actions if n in {'party.run', 'party.sneak'}]
        if len(wanted.armatures) != 1 or len(wanted.actions) != 2:
            raise ValueError('Expected one shared armature and the two authoritative clips')
        shared_data = wanted.armatures[0]
        if source_rest_signature(shared_data) != fit['source_rest_signature']:
            raise ValueError('Shared rest hierarchy changed; refit before retargeting')
        if {b.name: b.parent.name if b.parent else None for b in shared_data.bones} != {
                b.name: b.parent.name if b.parent else None for b in rig.data.bones}:
            raise ValueError('Target hierarchy differs from shared source')
        sampler = bpy.data.objects.new('Temporary Option A shared sampler', shared_data)
        scene.collection.objects.link(sampler)
        sampler.animation_data_create()
        bpy.context.view_layer.update()
        for pb in sampler.pose.bones:
            pb.rotation_mode = 'QUATERNION'
        source_rest = {b.name: b.matrix_local.copy() for b in shared_data.bones}
        target_rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
        source_soles = {side: [Vector(p) for p in fit['source_soles'][side]] for side in ['L', 'R']}
        if not all(source_soles.values()) or not all(target_soles.values()):
            raise ValueError('Both actual rigid-foot sole regions are required')
        ratio = ((rig.data.bones['thigh.L'].head_local.z - rig.data.bones['foot.L'].head_local.z)
                 / (shared_data.bones['thigh.L'].head_local.z - shared_data.bones['foot.L'].head_local.z))
        records = {}
        for shared in wanted.actions:
            sampler.animation_data.action = shared
            sampler.animation_data.action_slot = shared.slots[0]
            target_name = 'miki.option-a.' + shared.name.removeprefix('party.')
            action = bpy.data.actions.get(target_name)
            if action is not None:
                if action.library:
                    raise ValueError('Cannot refresh a linked source Action')
                for layer in action.layers:
                    for strip in layer.strips:
                        for bag in strip.channelbags:
                            for curve in list(bag.fcurves):
                                bag.fcurves.remove(curve)
            else:
                action = bpy.data.actions.new(target_name)
            action.use_fake_user = True
            action['source_action'] = shared.name
            action['source_library'] = 'blender/animations/party.blend'
            action['source_sha256'] = source_sha
            action['fps'] = 120
            rig.animation_data.action = action
            start, end = map(int, shared.frame_range)
            if start != 1:
                raise ValueError('Source clip must begin at frame 1')
            for sample in range((end - start) * 4 + 1):
                frame = start + sample * .25
                scene.frame_set(math.floor(frame), subframe=frame % 1)
                bpy.context.view_layer.update()
                poses = {}
                for bone in rig.data.bones:
                    name = bone.name
                    delta = sampler.pose.bones[name].matrix.to_3x3() @ source_rest[name].to_3x3().inverted()
                    pose = (delta @ target_rest[name].to_3x3()).to_4x4()
                    pose.translation = (poses[bone.parent.name] @ target_rest[bone.parent.name].inverted() @ bone.head_local
                                        if bone.parent else Vector((0, 0, 0)))
                    poses[name] = pose
                if shared.name == 'party.sneak':
                    offset_sneak_arms(poses, rig, target_rest, fit)
                source_min = min((sampler.pose.bones['foot.' + side].matrix @ source_rest['foot.' + side].inverted() @ p).z
                                 for side in ['L', 'R'] for p in source_soles[side])
                target_min = min((poses['foot.' + side] @ target_rest['foot.' + side].inverted() @ p).z
                                 for side in ['L', 'R'] for p in target_soles[side])
                correction = max(0., source_min) * ratio - target_min + .0002
                for matrix in poses.values():
                    matrix.translation.z += correction
                for bone in rig.data.bones:
                    pb = rig.pose.bones[bone.name]
                    pb.rotation_mode = 'QUATERNION'
                    parent = bone.parent
                    pb.matrix_basis = bone.convert_local_to_pose(
                        poses[bone.name], bone.matrix_local,
                        parent_matrix=poses[parent.name] if parent else Matrix.Identity(4),
                        parent_matrix_local=parent.matrix_local if parent else Matrix.Identity(4), invert=True)
                    pb.rotation_quaternion.normalize()
                    if shared.name == 'party.run' and bone.name.startswith('hand.'):
                        sign = 1 if bone.name.endswith('.L') else -1
                        pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion((0, 1, 0), math.radians(fit.get('run_hand_roll_degrees', 0.) * sign))
                        pb.rotation_quaternion.normalize()
                    pb.scale = (1., 1., 1.)
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
            records[shared.name] = {'target_action': target_name, 'frames': [start, end],
                                    'sample_rate': 480, 'contact_guard_m': .0002}
        return records
    finally:
        rig.animation_data.action = old_action
        if old_action is not None:
            rig.animation_data.action_slot = old_slot
        for name, basis in old_bases.items():
            rig.pose.bones[name].matrix_basis = basis
        for track, mute in tracks:
            track.mute = mute
        if sampler is not None:
            bpy.data.objects.remove(sampler, do_unlink=True)
        for action in list(bpy.data.actions):
            if action not in old_actions and action.library:
                bpy.data.actions.remove(action)
        for data in list(bpy.data.armatures):
            if data not in old_data and data.users == 0:
                bpy.data.armatures.remove(data)
        scene.frame_set(old_frame, subframe=old_subframe)
