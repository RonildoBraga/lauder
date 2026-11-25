"""Reproduce three native hand-review Actions on the measured 47-bone Miki.

API: author(rig, body, landmark_record). Direct pose bones remain the hand controls.
CLI after --: --source CHARACTER.blend --landmarks RECORD.json --output NEW.blend --report NEW.json
No mesh, rest joint, weight, texture or garment target is changed; no weapon is embedded.
"""
import bpy,json,math,hashlib
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
TARGET_REST_SHA256='a07229051b24eba057b6544a4e2f274e04277c8f5c824f0bdf7478ef549cdb7d'
DIGITS=['thumb','index','middle','ring','pinky']

def frame(direction,palm,side):
 y=direction.normalized();z=palm-y*palm.dot(y);z.normalize();z*=(-1 if side=='L' else 1);x=y.cross(z).normalized()
 return Matrix((x,y,z)).transposed()

def rest_frames(data):
 return {side:frame(Vector(row['distal_wrist_to_middle']),Vector(row['palm_normal_landmarks']),side) for side,row in data['hand_frames'].items()}

def arm_pose(rig,rest,side,wrist,hand_rotation,direction):
 upper,fore,hand=[n+'.'+side for n in ['upper_arm','forearm','hand']];shoulder=rest[upper].translation;u=rig.data.bones[upper].length;f=rig.data.bones[fore].length;axis=wrist-shoulder;distance=axis.length
 if not abs(u-f)+1e-5<distance<u+f-1e-5:raise ValueError('Hand target is outside native arm reach')
 axis.normalize();pole=wrist-direction*f-shoulder;pole-=axis*pole.dot(axis)
 if pole.length<1e-6:pole=Vector((1 if side=='L' else -1,0,0));pole-=axis*pole.dot(axis)
 along=(u*u-f*f+distance*distance)/(2*distance);elbow=shoulder+axis*along+pole.normalized()*math.sqrt(u*u-along*along)
 result={}
 for name,start,end in [(upper,shoulder,elbow),(fore,elbow,wrist)]:
  rotation=rest[name].to_3x3();swing=rotation.col[1].normalized().rotation_difference((end-start).normalized());result[name]=(swing.to_matrix()@rotation).to_4x4();result[name].translation=start
 result[hand]=hand_rotation.to_4x4();result[hand].translation=wrist
 return result,math.degrees((wrist-elbow).normalized().angle(direction.normalized()))

def palm_patch(body,rig,side,data):
 normal=Vector(data['hand_frames'][side]['palm_normal_landmarks']);sign=1 if side=='L' else -1;hand_index=body.vertex_groups['hand.'+side].index
 verts=[v for v in body.data.vertices if (body.matrix_world@v.co).x*sign>.28 and .900<(body.matrix_world@v.co).z<.922 and .005<(body.matrix_world@v.co).y<.065 and next((g.weight for g in v.groups if g.group==hand_index),0)>.999]
 if len(verts)<5:raise ValueError('Measured rigid palm patch is missing')
 points=[body.matrix_world@v.co for v in verts];centre=sum(points,Vector())/len(points);ranked=sorted(zip(verts,points),key=lambda item:normal.dot(item[1]-centre),reverse=True);selected=ranked[:max(3,len(ranked)//4)]
 return sum((p for v,p in selected),Vector())/len(selected),[int(body.data.attributes['source_vertex_id'].data[v.index].value) for v,p in selected]

def pose_setup(rig,body,data,mode):
 rest={b.name:b.matrix_local.copy() for b in rig.data.bones};frames=rest_frames(data);poses={n:m.copy() for n,m in rest.items()};details={};rifle=None
 if mode=='rifle':
  forward=Vector((.6,-.8,0));up=Vector((0,0,1));right=forward.cross(up);rotation=Matrix((right,forward,up)).transposed();stock=Vector((-.22,.02,1.35));rifle=rotation.to_4x4();rifle.translation=stock-rotation@Vector((0,-.04,-.055))
 for side,sign in [('L',1),('R',-1)]:
  if mode=='readable':
   direction=Vector((0,-.6,-.8));normal=Vector((0,-.8,.6));wrist=Vector((sign*.335,-.20,1.11));target_frame=frame(direction,normal,side);skin=target_frame@frames[side].inverted();patch_ids=[];contact=None
  else:
   point,patch_ids=palm_patch(body,rig,side,data)
   if side=='R':direction=(forward*.94-up*.34).normalized();normal=-right;local_contact=Vector((.0535,.318,-.085))
   else:direction=(right*.85+forward*.527).normalized();normal=up;local_contact=Vector((0,.535,-.071))
   target_frame=frame(direction,normal,side);skin=target_frame@frames[side].inverted();contact=rifle@local_contact;wrist=contact-skin@(point-rest['hand.'+side].translation)
  hand_rotation=skin@rest['hand.'+side].to_3x3();arms,bend=arm_pose(rig,rest,side,wrist,hand_rotation,direction);poses.update(arms)
  details[side]={'wrist':list(wrist),'distal_direction':list(direction),'palm_normal':list(normal),'thumb_side':list(target_frame.col[0]),'palm_frame':[list(r) for r in target_frame],'physical_forearm_palm_bend_degrees':bend,'palm_contact_world':list(contact) if contact else None,'palm_patch_source_vertex_ids':patch_ids}
 return rest,poses,details,rifle

def apply_pose(rig,rest,poses):
 for bone in rig.data.bones:
  pb=rig.pose.bones[bone.name]
  if bone.name.split('.')[0] in DIGITS:
   pb.matrix_basis=Matrix.Identity(4);pb.rotation_mode='XYZ';continue
  pb.matrix_basis=bone.convert_local_to_pose(poses[bone.name],bone.matrix_local,parent_matrix=poses[bone.parent.name] if bone.parent else Matrix.Identity(4),parent_matrix_local=bone.parent.matrix_local if bone.parent else Matrix.Identity(4),invert=True)
  pb.rotation_mode='XYZ' if bone.name.split('.')[0] in DIGITS else 'QUATERNION'

def ease(x):return max(0.,min(1.,x))**2*(3-2*max(0.,min(1.,x)))
def envelope(f):
 if f<61:return 0.
 if f<181:return ease((f-61)/120)
 if f<241:return 1.
 if f<361:return 1-ease((f-241)/120)
 return 0.
def curls(rig,amount,rifle=False,index_amount=0.,thumb_amount=None):
 for side in ['L','R']:
  for digit in DIGITS:
   digit_amount=thumb_amount if digit=='thumb' and thumb_amount is not None else amount
   angles=([15,35,25] if digit=='thumb' else ([50,65,25] if digit=='index' else [50,65,35]))
   opposition=35*digit_amount if digit=='thumb' else 0.
   if rifle:
    if digit=='thumb':angles=([-20,-10,-5] if side=='L' else [-30,-15,-10]);opposition=(-20 if side=='L' else -10)
    elif side=='R' and digit=='index':angles=[-15+10*index_amount,10*index_amount,5*index_amount]
    else:angles=[5,55,55] if side=='R' else [0,55,45]
   for i,angle in enumerate(angles,1):
    pb=rig.pose.bones[f'{digit}.{i:02}.{side}'];pb.rotation_euler=(math.radians(angle*(1 if rifle else digit_amount)),0,math.radians(((-1 if side=='L' else 1)*opposition if i==1 and digit=='thumb' else (-20 if rifle and side=='R' and digit=='index' and i==1 else 0))))

def author(rig,body,data):
 if rig.type!='ARMATURE' or rig.library or rig.data.library or body.type!='MESH':raise ValueError('Expected the local fitted character source')
 rows=[[b.name,b.parent.name if b.parent else None,[[round(v,8) for v in row] for row in b.matrix_local]] for b in sorted(rig.data.bones,key=lambda b:b.name)]
 if hashlib.sha256(json.dumps(rows,separators=(',',':')).encode()).hexdigest()!=TARGET_REST_SHA256:raise ValueError('The reviewed 47-bone rest skeleton changed; recalibrate before authoring')
 bpy.context.view_layer.update()
 if any(abs(rig.matrix_world[i][j]-float(i==j))>1e-6 for i in range(4) for j in range(4)):raise ValueError('The fitted rig object transform must remain identity')
 if len(body.data.vertices)!=10269 or 'source_vertex_id' not in body.data.attributes:raise ValueError('Expected the preserved Miki mesh and vertex lineage')
 scene=bpy.context.scene;old_frame,old_subframe=scene.frame_current,scene.frame_subframe;old_fps,old_base=scene.render.fps,scene.render.fps_base
 rig.animation_data_create();old_action,old_slot=rig.animation_data.action,rig.animation_data.action_slot;old_bases={pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones};old_tracks=[(t,t.mute) for t in rig.animation_data.nla_tracks]
 scene=bpy.context.scene;scene.render.fps=120;scene.render.fps_base=1;rig.animation_data_create();rig.animation_data.action=None
 for track in rig.animation_data.nla_tracks:track.mute=True
 for side in ['L','R']:
  collection=rig.data.collections.get('Hand controls '+side) or rig.data.collections.new('Hand controls '+side)
  for bone in rig.data.bones:
   if bone.name.split('.')[0] in DIGITS and bone.name.endswith('.'+side):collection.assign(bone);bone.color.palette='THEME04';rig.pose.bones[bone.name]['control_help']='Local X curls toward palm; proximal thumb local Z opposes: negative Left, positive Right.'
 setups={mode:pose_setup(rig,body,data,mode) for mode in ['readable','rifle']};report={'fps':120,'bone_count':len(rig.data.bones),'measured_rest_hand_frames':{s:[list(r) for r in m] for s,m in rest_frames(data).items()},'poses':{mode:setup[2] for mode,setup in setups.items()},'rifle_world_matrix':[list(r) for r in setups['rifle'][3]],'rifle_source':'blender/studies/equipment/rifle-precision/rifle-precision.blend','rifle_collection':'rifle-precision','rifle_assembly':'rifle-precision / precision / rifle assembly','actions':{}}
 for name,last in [('relax-fist',481),('rifle',481),('controls',1441)]:
  rest,base_poses,details,rifle=setups['rifle' if name=='rifle' else 'readable'];action=bpy.data.actions.get('miki.hands.'+name)
  if action is None:action=bpy.data.actions.new('miki.hands.'+name)
  elif action.library:raise ValueError('Cannot replace a linked Action')
  else:
   for layer in action.layers:
    for strip in layer.strips:
     for bag in strip.channelbags:
      for curve in list(bag.fcurves):bag.fcurves.remove(curve)
  action.use_fake_user=True;rig.animation_data.action=action
  for f in range(1,last+1):
   poses={n:m.copy() for n,m in base_poses.items()}
   if name=='controls' and f>1201:
    t=f-1201;angle=(20*math.sin(t/240*2*math.pi))
    for side in ['L','R']:
     direction=Vector(details[side]['distal_direction']);normal=Vector(details[side]['palm_normal']);axis=direction.cross(normal).normalized();rotation=Quaternion(axis,math.radians(angle)).to_matrix();poses['hand.'+side]=(rotation@poses['hand.'+side].to_3x3()).to_4x4();poses['hand.'+side].translation=base_poses['hand.'+side].translation
   apply_pose(rig,rest,poses)
   if name=='relax-fist':
    finger_amount=ease((f-61)/120) if f<181 else (1. if f<361 else 1-ease((f-361)/60))
    thumb_amount=ease((f-181)/60) if f<241 else (1. if f<301 else 1-ease((f-301)/60))
    curls(rig,finger_amount,thumb_amount=thumb_amount)
   elif name=='rifle':curls(rig,1,True,envelope(f))
   elif f<=1201:
    index=min(9,max(0,(f-1)//120));side=['L','R'][index//5];digit=DIGITS[index%5];phase=((f-1)%120)/120;angle=25*math.sin(math.pi*phase)**2 if f<1201 else 0;rig.pose.bones[f'{digit}.01.{side}'].rotation_euler.x=math.radians(angle)
   for pb in rig.pose.bones:
    digit=pb.name.split('.')[0] in DIGITS
    if digit:pb.keyframe_insert('rotation_euler',frame=f,group=pb.name)
    elif f in [1,last] or (name=='controls' and pb.name.startswith(('upper_arm.','forearm.','hand.'))):pb.keyframe_insert('rotation_quaternion',frame=f,group=pb.name)
    if f in [1,last]:
     pb.keyframe_insert('location',frame=f,group=pb.name);pb.keyframe_insert('scale',frame=f,group=pb.name)
   if f==1:rig.animation_data.action_slot=action.slots[0]
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for curve in bag.fcurves:
      for key in curve.keyframe_points:key.interpolation='LINEAR'
  action['fps']=120;action['review_only']=True;report['actions'][name]={'name':action.name,'frames':[1,last],'duration_seconds':(last-1)/120}
 rig.animation_data.action=old_action
 if old_action is not None:rig.animation_data.action_slot=old_slot
 for pb in rig.pose.bones:pb.matrix_basis=old_bases[pb.name]
 for track,mute in old_tracks:track.mute=mute
 scene.render.fps,scene.render.fps_base=old_fps,old_base
 scene.frame_set(old_frame,subframe=old_subframe);report['pose_frames']={'relaxed':1,'fist':241,'rifle_off_trigger':1,'rifle_index_flex':181,'digit_isolation_peaks':{f'{digit}.{side}':(i*120+61) for i,(side,digit) in enumerate((s,d) for s in ['L','R'] for d in DIGITS)},'wrist_flexion':1261,'wrist_extension':1381}
 return report

if __name__=='__main__':
 import argparse,sys
 parser=argparse.ArgumentParser(description=__doc__)
 for name in ['source','landmarks','output','report']:parser.add_argument('--'+name,required=True,type=Path)
 args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);outputs=[args.output,args.report];protected={args.source.resolve(),args.landmarks.resolve()}
 if len({p.resolve() for p in outputs})!=2 or any(p.resolve() in protected for p in outputs):raise ValueError('Output and report must be distinct from each other and both inputs')
 if any(p.exists() or p.is_symlink() for p in outputs):raise ValueError('Output and report must both be new files')
 before=hashlib.sha256(args.source.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(args.source.resolve()),load_ui=False)
 rigs=[o for o in bpy.data.objects if o.type=='ARMATURE'];meshes=[o for o in bpy.data.objects if o.type=='MESH']
 if len(rigs)!=1 or len(meshes)!=1:raise ValueError('Use the focused character source, not a review composition')
 report=author(rigs[0],meshes[0],json.loads(args.landmarks.read_text()));report['source_sha256']=before;assert hashlib.sha256(args.source.read_bytes()).hexdigest()==before
 rigs[0].animation_data.action=None
 for pb in rigs[0].pose.bones:pb.matrix_basis=Matrix.Identity(4)
 bpy.context.scene.render.fps=120;bpy.context.scene.render.fps_base=1;bpy.context.scene.frame_set(0)
 bpy.ops.wm.save_as_mainfile(filepath=str(args.output.resolve()));report['output_sha256']=hashlib.sha256(args.output.read_bytes()).hexdigest();args.report.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
