"""Promote the reviewed Miki surface and fit the remaining runtime clips, without reshaping it.

Run in background Blender. --output and --report must be new scratch files; the resulting
model and its exact JPEG can then replace the canonical source after verification.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
APPROVED_SHA = '899ebf7f3986b666419a26d5a38b1d4c6c278cf915e072c4ce4a5944a6c7af95'
KINDS = ('idle', 'walk', 'jog', 'backward', 'strafe_left', 'strafe_right',
         'aim', 'fire', 'hit', 'run', 'sneak')
DIGITS = ('thumb', 'index', 'middle', 'ring', 'pinky')


def choose(rig, action):
    rig.animation_data_create().action = action
    rig.animation_data.action_slot = action.slots[0]


def sample(rig, action, frame):
    choose(rig, action)
    bpy.context.scene.frame_set(math.floor(frame), subframe=frame % 1)
    bpy.context.view_layer.update()
    return {bone.name: bone.matrix.copy() for bone in rig.pose.bones}


def write_action(rig, name, samples):
    action = bpy.data.actions.new('miki.' + name)
    action.use_fake_user = True
    rig.animation_data_create().action = action
    rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
    for frame, poses in samples:
        for bone in rig.data.bones:
            pb = rig.pose.bones[bone.name]
            pb.rotation_mode = 'QUATERNION'
            pb.matrix_basis = bone.convert_local_to_pose(
                poses[bone.name], bone.matrix_local,
                parent_matrix=poses[bone.parent.name] if bone.parent else Matrix.Identity(4),
                parent_matrix_local=rest[bone.parent.name] if bone.parent else Matrix.Identity(4),
                invert=True)
            pb.rotation_quaternion.normalize()
            for prop in ('location', 'rotation_quaternion', 'scale'):
                pb.keyframe_insert(prop, frame=frame, group=bone.name)
        if frame == 1:
            rig.animation_data.action_slot = action.slots[0]
    for curve in action.layers[0].strips[0].channelbag(action.slots[0]).fcurves:
        for point in curve.keyframe_points:
            point.interpolation = 'LINEAR'
    action['fps'] = 120
    return action



def fit_walk_ankles(rig, rest, poses, donor_rest, donor_pose):
    """Preserve the donor's planted linear ankle travel despite different segment lengths.

    This is the same two-segment geometry used by the runtime limb solve, baked into only the
    new Walk source. Forward travel stays at its declared speed; source hips/body remain fitted.
    """
    for side in ('L', 'R'):
        upper, lower, foot = ('thigh.' + side, 'shin.' + side, 'foot.' + side)
        shoulder = poses[upper].translation.copy()
        target = (rest[foot].translation + donor_pose[foot].translation
                  - donor_rest[foot].translation + Vector((0, 0, .0005)))
        axis = target - shoulder
        distance = axis.length
        first, second = rig.data.bones[upper].length, rig.data.bones[lower].length
        if not abs(first - second) + 1e-5 < distance < first + second - 1e-5:
            raise ValueError('The fitted Walk ankle is outside its unchanged leg reach')
        along = axis.normalized()
        pole = poses[lower].translation - shoulder
        pole -= along * pole.dot(along)
        if pole.length < 1e-6:
            pole = Vector((0, -1, 0)); pole -= along * pole.dot(along)
        projection = (first * first - second * second + distance * distance) / (2 * distance)
        knee = shoulder + along * projection + pole.normalized() * math.sqrt(max(0, first * first - projection * projection))
        old_knee, old_ankle = poses[lower].translation.copy(), poses[foot].translation.copy()
        for name, origin, old_vector, new_vector in (
                (upper, shoulder, old_knee - shoulder, knee - shoulder),
                (lower, knee, old_ankle - old_knee, target - knee)):
            swing = old_vector.normalized().rotation_difference(new_vector.normalized())
            rotation = swing.to_matrix() @ poses[name].to_3x3()
            poses[name] = rotation.to_4x4(); poses[name].translation = origin
        poses[foot] = rest[foot].to_3x3().to_4x4()
        poses[foot].translation = target

def build(source, shared, output, report):
    if hashlib.sha256(source.read_bytes()).hexdigest() != APPROVED_SHA:
        raise ValueError('Use the approved hand-motion source, not an edited review scene')
    for path in (output, report):
        if path.exists() or path.is_symlink():
            raise ValueError('Outputs must be new files')
    if output.resolve() == report.resolve():
        raise ValueError('Output and report must be distinct')
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False)
    scene = bpy.context.scene
    rig = next(o for o in scene.objects if o.type == 'ARMATURE')
    body = next(o for o in scene.objects if o.type == 'MESH')
    if len(rig.data.bones) != 47 or len(body.data.vertices) != 10269:
        raise ValueError('The approved surface or hand skeleton changed')
    source_actions = {name: bpy.data.actions['miki.hand-motion.' + name]
                      for name in ('run', 'sneak', 'shoot')}
    rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
    # Retain the reviewed 120 Hz poses while normalizing all 47 controls to quaternion
    # channels. A timeline cannot switch a bone's Euler/quaternion mode between clips.
    run_samples = {f: sample(rig, source_actions['run'], f) for f in range(1, 80)}
    sneak_samples = {f: sample(rig, source_actions['sneak'], f) for f in range(1, 146)}
    shoot_samples = {f: sample(rig, source_actions['shoot'], f) for f in range(1, 362)}
    with bpy.data.libraries.load(str(shared), link=False) as (available, wanted):
        wanted.armatures = ['Party humanoid skeleton']
        wanted.actions = ['party.' + name for name in KINDS]
    if len(wanted.armatures) != 1 or any(x is None for x in wanted.actions):
        raise ValueError('Expected the complete unchanged shared humanoid source')
    donor = bpy.data.objects.new('Temporary shared body sampler', wanted.armatures[0])
    scene.collection.objects.link(donor)
    shared_spec = json.loads(donor.data['lauder_party_animation'])
    donor_rest = {b.name: b.matrix_local.copy() for b in donor.data.bones}
    sole_points = {side: [body.matrix_world @ v.co for v in body.data.vertices
                         if (body.matrix_world @ v.co).z < .025
                         and ((body.matrix_world @ v.co).x > 0) == (side == 'L')]
                   for side in ('L', 'R')}
    records = {}
    for name in KINDS:
        if name in ('run', 'sneak'):
            cached = run_samples if name == 'run' else sneak_samples
            written = write_action(rig, name, sorted(cached.items()))
            records[name] = {'source': 'approved miki.hand-motion.' + name,
                             'frames': list(written.frame_range)}
            continue
        if name in ('aim', 'fire'):
            start, end = (81, 171) if name == 'aim' else (181, 241)
            samples = [(f - start + 1, shoot_samples[f]) for f in range(start, end + 1)]
        else:
            action = next(a for a in wanted.actions if a.name == 'party.' + name)
            end = round(action.frame_range[1])
            samples = []
            for frame in range(1, end + 1):
                old = sample(donor, action, frame)
                poses = {}
                for bone in rig.data.bones:
                    if bone.name not in donor_rest:
                        poses[bone.name] = (poses[bone.parent.name]
                                            @ rest[bone.parent.name].inverted() @ rest[bone.name])
                        continue
                    delta = old[bone.name].to_3x3() @ donor_rest[bone.name].to_3x3().inverted()
                    rotation = delta @ rest[bone.name].to_3x3()
                    if name in ('strafe_left', 'strafe_right') and bone.name.startswith('thigh.'):
                        parent = bone.parent.name
                        target_local = rest[parent].to_3x3().inverted() @ rest[bone.name].to_3x3()
                        local = poses[parent].to_3x3().inverted() @ rotation
                        bend = (target_local.inverted() @ local).to_euler('XYZ')
                        # Preserve the authored forward flexion (local Z), which also drives
                        # the unchanged dress corrections; narrow lateral hip abduction only.
                        bend.x *= .3
                        bend.y *= .3
                        rotation = poses[parent].to_3x3() @ target_local @ bend.to_matrix()
                    pose = rotation.to_4x4()
                    pose.translation = (poses[bone.parent.name] @ rest[bone.parent.name].inverted()
                                        @ bone.head_local if bone.parent else old[bone.name].translation)
                    poses[bone.name] = pose
                # Use the reviewed inward-palm relaxed arm silhouettes in ordinary locomotion.
                # Their chest-relative rotation/position follows each fitted body's own lean.
                phase = 1 + round((frame - 1) / max(1, end - 1) * 78)
                arm_reference = run_samples[phase if name != 'idle' else 1]
                chest_delta = poses['chest'] @ arm_reference['chest'].inverted()
                for bone in rig.data.bones:
                    if bone.name.startswith(('upper_arm.', 'forearm.', 'hand.')) or bone.name.split('.')[0] in DIGITS:
                        poses[bone.name] = chest_delta @ arm_reference[bone.name]
                # Actual approved boot soles, not a generic ankle marker, define ground clearance.
                lowest = min((poses['foot.' + side] @ rest['foot.' + side].inverted() @ point).z
                             for side in sole_points for point in sole_points[side])
                for pose in poses.values():
                    pose.translation.z += .0005 - lowest
                if name == 'walk':
                    fit_walk_ankles(rig, rest, poses, donor_rest, old)
                samples.append((frame, poses))
        written = write_action(rig, name, samples)
        records[name] = {'source': ('approved shooting' if name in ('aim', 'fire') else 'party.' + name),
                         'frames': list(written.frame_range)}
    # Measured full wrist transforms relative to the separate rifle, converted to runtime's
    # weapon-local axes. Fingers remain joint-local, independently articulated quaternion data.
    motion_record = json.loads((ROOT / 'blender/studies/miki-hand-motion/motion-record.json').read_text())
    rifle = Matrix(dict(motion_record['rifle_world_bookmarks'])[121])
    conversion = Matrix.Rotation(math.radians(-90), 4, 'X')
    grips = {}
    for side in ('L', 'R'):
        wrist = shoot_samples[121]['hand.' + side]
        relative = conversion @ rifle.inverted() @ wrist
        relative.translation -= conversion.to_3x3() @ Vector((0, .303, -.09))
        # Pose-only clearance fit from the reviewed precision foreend/pistol-grip to the
        # unchanged gameplay carbine box (7 cm wide, 8 cm high). The weapon stays authoritative.
        relative.translation += Vector((.004, -.078, .15) if side == 'L' else (.0125, 0, 0))
        grips[side] = {'offset': list(relative.translation),
                       'rotation': list(relative.to_quaternion())}  # Blender w,x,y,z
    rig.data['lauder_hand_calibration'] = json.dumps({'version': 1, 'runtime_prop_fit': 'carbine-box-v3', 'grips': grips})
    spec = dict(shared_spec, profile='miki47')
    for entry in spec['clips']:
        entry['source_action'] = 'miki.' + entry['name']
        if entry['name'] in ('strafe_left', 'strafe_right'): entry['nominal_speed'] *= .5
        if entry['name'] == 'aim': entry['loop'] = True
        if entry['name'] == 'fire': entry['event_start'] = 0
    rig.data['lauder_party_animation'] = json.dumps(spec)
    # One local canonical collection. Preserve the alignment parent; deleting it loses scale.
    collection = bpy.data.collections.new('miki')
    scene.collection.children.link(collection)
    keep = {body, rig, body.parent}
    for obj in keep:
        for old in list(obj.users_collection): old.objects.unlink(obj)
        collection.objects.link(obj)
    for obj in list(bpy.data.objects):
        if obj not in keep: bpy.data.objects.remove(obj, do_unlink=True)
    for old in list(bpy.data.collections):
        if old != collection: bpy.data.collections.remove(old)
    for action in list(bpy.data.actions):
        if action.name not in {'miki.' + name for name in KINDS}:
            bpy.data.actions.remove(action)
    for armature in list(bpy.data.armatures):
        if armature != rig.data and armature.users == 0: bpy.data.armatures.remove(armature)
    body.name, rig.name, body.parent.name = 'miki body', 'miki rig', 'miki alignment'
    for material in body.data.materials: material.name = 'miki surface'
    # The FBX uses UV -> identity Mapping -> image. Express that identical UV sampling
    # directly, rather than broadening the engine's material intake to arbitrary Mapping nodes.
    for material in body.data.materials:
        tree = material.node_tree
        for mapping in list(tree.nodes):
            if mapping.type != 'MAPPING': continue
            if (tuple(mapping.inputs['Location'].default_value) != (0., 0., 0.)
                    or any(abs(v) > 1e-8 for v in mapping.inputs['Rotation'].default_value)
                    or tuple(mapping.inputs['Scale'].default_value) != (1., 1., 1.)):
                raise ValueError('A nonidentity texture transform requires a new material review')
            incoming = list(mapping.inputs['Vector'].links)
            if len(incoming) != 1 or incoming[0].from_node.type != 'TEX_COORD' or incoming[0].from_socket.name != 'UV':
                raise ValueError('Expected original identity UV mapping')
            coordinates = incoming[0].from_node
            uv = tree.nodes.new('ShaderNodeUVMap');uv.uv_map = body.data.uv_layers.active.name
            for link in list(mapping.outputs['Vector'].links):
                tree.links.new(uv.outputs['UV'], link.to_socket)
            tree.nodes.remove(mapping)
            if not any(output.is_linked for output in coordinates.outputs):tree.nodes.remove(coordinates)
    output.parent.mkdir(parents=True, exist_ok=True)
    texture_hashes = {}
    for image in bpy.data.images:
        if image.packed_file:
            contents = bytes(image.packed_file.data)
            texture = output.parent / 'textures/miki-basecolour.jpg'
            texture.parent.mkdir(parents=True, exist_ok=True)
            if texture.exists() and texture.read_bytes() != contents:
                raise ValueError('Refusing to replace an unrelated texture')
            texture.write_bytes(contents)
            image.unpack(method='REMOVE')
            image.filepath = str(texture.resolve())
            image.name = 'miki basecolour'
            texture_hashes[texture.name] = hashlib.sha256(contents).hexdigest()
    rig.animation_data_clear()
    for pb in rig.pose.bones: pb.matrix_basis = Matrix.Identity(4)
    scene.render.fps, scene.render.fps_base = 120, 1
    scene.unit_settings.system, scene.unit_settings.scale_length = 'METRIC', 1
    scene.frame_set(0)
    sys.path.insert(0, str(ROOT / 'blender/extensions'))
    from lauder_levels.common import forget_local_paths
    forget_local_paths(output)
    bpy.ops.wm.save_as_mainfile(filepath=str(output), relative_remap=False)
    result = {'source_sha256': APPROVED_SHA, 'output_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
              'shared_source_sha256': hashlib.sha256(shared.read_bytes()).hexdigest(),
              'profile': 'miki47', 'clips': records, 'textures': texture_hashes,
              'raw_geometry_policy': 'No vertex/topology/UV/normal/weight/rest/garment target edits',
              'source_actions': 'Reviewed Run/Sneak retained; additional body clips fitted from original shared source'}
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--shared-motion', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    print(json.dumps(build(args.source.resolve(), args.shared_motion.resolve(), args.output.resolve(),
                           args.report.resolve()), indent=2))
