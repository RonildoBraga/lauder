"""Reproduce the isolated Quaternius Run/Crouch motion trial on fitted Miki.

In Blender: retarget(rig, body, source_glb). This changes two local Actions only.
CLI after --: --source FILE.glb --target FILE.blend --output NEW.blend --report FILE.json
The exact CC0 donor and fitted rest rig are checked. No shared library is saved.
"""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
SOURCE_SHA256='69591853d817488edaa8fd9bf8fc1d821eaeaf789f8627b3cd23b41c4ed67997'
TARGET_REST_SHA256='3b38b54ed37c38764d6d62869ee286e25f8d0bda70717d0ed846857f6adb8cc8'

def rest_signature(data):
 return hashlib.sha256(json.dumps([[b.name,b.parent.name if b.parent else None,[[round(v,8) for v in row] for row in b.matrix_local]] for b in sorted(data.bones,key=lambda b:b.name)],separators=(',',':')).encode()).hexdigest()

def anatomical_frame(direction,thumb):
 y=direction.normalized();x=thumb-y*thumb.dot(y);x.normalize();z=x.cross(y).normalized()
 return Matrix((x,y,z)).transposed()

def retarget(rig,body,donor_path):
 if hashlib.sha256(Path(donor_path).read_bytes()).hexdigest()!=SOURCE_SHA256:raise ValueError('Expected the reviewed Quaternius Standard in-place GLB')
 if rig.type!='ARMATURE' or rig.library or rig.data.library or body.type!='MESH':raise ValueError('Expected the local fitted Miki character source')
 if rest_signature(rig.data)!=TARGET_REST_SHA256:raise ValueError('Target rest skeleton changed; calibrate before retargeting')
 bpy.context.view_layer.update()
 if any(abs(rig.matrix_world[i][j]-float(i==j))>1e-6 for i in range(4) for j in range(4)):raise ValueError('Target rig must retain identity object transform')
 scene=bpy.context.scene;old_frame,old_subframe=scene.frame_current,scene.frame_subframe
 old_fps,old_fps_base=scene.render.fps,scene.render.fps_base
 rig.animation_data_create();old_action,old_slot=rig.animation_data.action,rig.animation_data.action_slot
 old_bases={pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones};old_tracks=[(t,t.mute) for t in rig.animation_data.nla_tracks]
 scene.render.fps=120;scene.render.fps_base=1
 original_objects=set(bpy.data.objects);original_actions=set(bpy.data.actions)
 bpy.ops.import_scene.gltf(filepath=str(donor_path))
 donor=next(o for o in bpy.data.objects if o not in original_objects and o.type=='ARMATURE')
 meshes=[o for o in bpy.data.objects if o not in original_objects and o.type=='MESH']
 for track in donor.animation_data.nla_tracks:track.mute=True
 target_rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
 source_rest={b.name:donor.matrix_world@b.matrix_local for b in donor.data.bones}
 names={'ROOT':'root','pelvis':'pelvis','spine':'spine_02','chest':'spine_03','head':'Head'}
 for side,sign in [('L',1),('R',-1)]:
  for target,source in [('upper_arm','upperarm'),('forearm','lowerarm'),('hand','hand'),('thigh','thigh'),('shin','calf'),('foot','foot')]:names[target+'.'+side]=source+'_'+side.lower()
 corrections={}
 for name,source in names.items():
  rt=target_rest[name].to_3x3();rs=source_rest[source].to_3x3()
  if name.startswith(('upper_arm.','forearm.','hand.')):
   side=name[-1];sign=1 if side=='L' else -1;ending=side.lower()
   donor_thumb=source_rest['index_01_'+ending].translation-source_rest['pinky_01_'+ending].translation
   target_thumb=Vector((-sign,0,0))
   ft=anatomical_frame(rt.col[1],target_thumb);fs=anatomical_frame(rs.col[1],donor_thumb)
   corrections[name]=fs@ft.inverted()@rt
  elif name.startswith(('thigh.','shin.','foot.')):
   corrections[name]=rt.col[1].rotation_difference(rs.col[1]).to_matrix()@rt
  else:corrections[name]=rt
 ratio=((rig.data.bones['thigh.L'].head_local.z-rig.data.bones['foot.L'].head_local.z)/
        (source_rest['thigh_l'].translation.z-source_rest['foot_l'].translation.z))
 target_soles={side:[body.matrix_world@v.co for v in body.data.vertices if (body.matrix_world@v.co).z<.025 and ((body.matrix_world@v.co).x>0)==(side=='L')] for side in ['L','R']}
 rig.animation_data_create()
 for track in rig.animation_data.nla_tracks:track.mute=True
 report={'provider':'Quaternius','library':'Universal Animation Library Standard 1','licence':'CC0-1.0','source_url':'https://quaternius.com/packs/universalanimationlibrary.html','donor_sha256':hashlib.sha256(Path(donor_path).read_bytes()).hexdigest(),'method':'Anatomical T/A-pose limb and palm frames; world rest-space torso rotations; donor pelvis bob and actual donor-foot grounding','contact_guard_m':.0005,'fps':120,'key_sample_rate':120,'donor_bones':len(donor.data.bones),'target_bones':len(rig.data.bones),'leg_scale':ratio,'mapping':names,'clips':{}}
 for source_name,clip in [('Sprint_Loop','run'),('Crouch_Fwd_Loop','crouch')]:
  source_action=bpy.data.actions[source_name];donor.animation_data.action=source_action;donor.animation_data.action_slot=source_action.slots[0]
  start,end=source_action.frame_range;duration=(end-start)/120;last=round(duration*120)+1
  target_name='miki.quaternius.'+clip;action=bpy.data.actions.get(target_name)
  if action is None:action=bpy.data.actions.new(target_name)
  elif action.library:raise ValueError('Cannot replace a linked Action')
  else:
   for layer in action.layers:
    for strip in layer.strips:
     for bag in strip.channelbags:
      for curve in list(bag.fcurves):bag.fcurves.remove(curve)
  action.use_fake_user=True;rig.animation_data.action=action
  first_poses=None;end_error=0.;max_wrist=0.;min_floor=math.inf;max_gap=0.;max_scale=0.
  for frame in range(1,last+1):
   donor_frame=start+(frame-1)*(end-start)/(last-1)
   scene.frame_set(math.floor(donor_frame),subframe=donor_frame%1);bpy.context.view_layer.update()
   source_poses={n:donor.matrix_world@donor.pose.bones[n].matrix for n in names.values()}
   poses={}
   for bone in rig.data.bones:
    name=bone.name;source=names[name]
    rotation=source_poses[source].to_3x3()@source_rest[source].to_3x3().inverted()@corrections[name]
    pose=rotation.to_4x4()
    pose.translation=(poses[bone.parent.name]@target_rest[bone.parent.name].inverted()@bone.head_local if bone.parent else Vector((0,0,0)))
    if name=='pelvis':pose.translation=target_rest[name].translation+(source_poses[source].translation-source_rest[source].translation)*ratio
    poses[name]=pose
   # Preserve the donor's real aerial phases while keeping Miki's unchanged rigid soles clear.
   donor_floor=math.inf
   graph=bpy.context.evaluated_depsgraph_get()
   for mesh in meshes:
    ev=mesh.evaluated_get(graph);data=ev.to_mesh()
    donor_floor=min(donor_floor,min((ev.matrix_world@v.co).z for v in data.vertices));ev.to_mesh_clear()
   floor=min((poses['foot.'+side]@target_rest['foot.'+side].inverted()@point).z for side in ['L','R'] for point in target_soles[side])
   shift=max(0,donor_floor)*ratio-floor+.0005
   for pose in poses.values():pose.translation.z+=shift
   if first_poses is None:first_poses={n:m.copy() for n,m in poses.items()}
   if frame==last:
    end_error=max(abs(poses[n][i][j]-first_poses[n][i][j]) for n in poses for i in range(4) for j in range(4))
    poses={n:m.copy() for n,m in first_poses.items()}
   for bone in rig.data.bones:
    pb=rig.pose.bones[bone.name];parent=bone.parent;pb.rotation_mode='QUATERNION'
    pb.matrix_basis=bone.convert_local_to_pose(poses[bone.name],bone.matrix_local,parent_matrix=poses[parent.name] if parent else Matrix.Identity(4),parent_matrix_local=parent.matrix_local if parent else Matrix.Identity(4),invert=True)
    pb.rotation_quaternion.normalize();pb.scale=(1,1,1)
    for prop in ['location','rotation_quaternion','scale']:pb.keyframe_insert(prop,frame=frame,group=pb.name)
   if frame==1:rig.animation_data.action_slot=action.slots[0]
   bpy.context.view_layer.update()
   for side in ['L','R']:
    fore,hand=rig.pose.bones['forearm.'+side],rig.pose.bones['hand.'+side]
    max_wrist=max(max_wrist,math.degrees(fore.matrix.to_3x3().col[1].angle(hand.matrix.to_3x3().col[1])))
    max_gap=max(max_gap,(rig.pose.bones['upper_arm.'+side].tail-fore.head).length,(fore.tail-hand.head).length)
   min_floor=min(min_floor,min((rig.pose.bones['foot.'+side].matrix@target_rest['foot.'+side].inverted()@point).z for side in ['L','R'] for point in target_soles[side]))
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for curve in bag.fcurves:
      for key in curve.keyframe_points:key.interpolation='LINEAR'
  info={'source_action':source_name,'source_seconds':duration,'target_action':action.name,'frames':[1,last],'fps':120,'source_endpoint_matrix_difference':end_error,'endpoint_closed_to_first':True,'maximum_forearm_hand_direction_angle_degrees':max_wrist,'maximum_arm_joint_gap_m':max_gap,'minimum_rigid_sole_height_m':min_floor}
  for key,value in {'source_action':source_name,'source_sha256':report['donor_sha256'],'source_provider':'Quaternius','source_library':'Universal Animation Library Standard 1','source_licence':'CC0-1.0','fps':120,'duration':duration,'loop':True}.items():action[key]=value
  report['clips'][clip]=info
 rig.animation_data.action=old_action
 if old_action is not None:rig.animation_data.action_slot=old_slot
 for pb in rig.pose.bones:pb.matrix_basis=old_bases[pb.name]
 for track,mute in old_tracks:track.mute=mute
 scene.render.fps,scene.render.fps_base=old_fps,old_fps_base
 scene.frame_set(old_frame,subframe=old_subframe)
 for obj in list(bpy.data.objects):
  if obj not in original_objects:bpy.data.objects.remove(obj,do_unlink=True)
 for action in list(bpy.data.actions):
  if action not in original_actions and not action.name.startswith('miki.quaternius.'):bpy.data.actions.remove(action)
 return report

if __name__=='__main__':
 import argparse,sys
 parser=argparse.ArgumentParser(description=__doc__)
 for flag in ['source','target','output','report']:parser.add_argument('--'+flag,required=True,type=Path)
 args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
 protected={args.target.resolve(),args.source.resolve()};outputs=[args.output,args.report]
 if len({p.resolve() for p in outputs})!=2 or any(p.resolve() in protected for p in outputs):raise ValueError('Output and report must be distinct from each other and both sources')
 if any(p.exists() or p.is_symlink() for p in outputs):raise ValueError('Output and report must both be new files')
 original=hashlib.sha256(args.target.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(args.target.resolve()),load_ui=False)
 rigs=[o for o in bpy.data.objects if o.type=='ARMATURE'];meshes=[o for o in bpy.data.objects if o.type=='MESH']
 if len(rigs)!=1 or len(meshes)!=1:raise ValueError('Use the focused character source, not its review scene')
 report=retarget(rigs[0],meshes[0],args.source);report['original_target_sha256']=original
 assert hashlib.sha256(args.target.read_bytes()).hexdigest()==original
 rigs[0].animation_data.action=None
 for pb in rigs[0].pose.bones:pb.matrix_basis=Matrix.Identity(4)
 bpy.context.scene.render.fps=120;bpy.context.scene.render.fps_base=1
 bpy.context.scene.frame_set(0)
 bpy.ops.wm.save_as_mainfile(filepath=str(args.output.resolve()));report['output_sha256']=hashlib.sha256(args.output.read_bytes()).hexdigest()
 args.report.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
