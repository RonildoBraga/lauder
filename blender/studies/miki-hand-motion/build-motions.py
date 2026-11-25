"""Build isolated 47-joint Run/Sneak/Shoot review Actions without appearance edits."""
import bpy,json,math,hashlib,importlib.util
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
DIGITS=['thumb','index','middle','ring','pinky']
TARGET_REST='a07229051b24eba057b6544a4e2f274e04277c8f5c824f0bdf7478ef549cdb7d'
BODY_SHA='d3b2480f847bfcdcb51271d128a8f12470aedb112cace7721af854a6ac625864'

def signature(rig):
 return hashlib.sha256(json.dumps([[b.name,b.parent.name if b.parent else None,[[round(v,8) for v in r] for r in b.matrix_local]] for b in sorted(rig.data.bones,key=lambda b:b.name)],separators=(',',':')).encode()).hexdigest()
def linear(action):
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for curve in bag.fcurves:
     for key in curve.keyframe_points:key.interpolation='LINEAR'
def finger_pose(rig,clip):
 for side in ['L','R']:
  for digit in DIGITS:
   angles=([5,5,5] if digit=='thumb' else ([20,30,15] if clip=='run' else [5,10,5]))
   for i,a in enumerate(angles,1):
    pb=rig.pose.bones[f'{digit}.{i:02}.{side}'];pb.rotation_mode='XYZ';pb.location=(0,0,0);pb.scale=(1,1,1);pb.rotation_euler=(math.radians(a),0,0)
def key_pose(rig,frame):
 for pb in rig.pose.bones:
  digit=pb.name.split('.')[0] in DIGITS
  for prop in ['location','scale','rotation_euler' if digit else 'rotation_quaternion']:pb.keyframe_insert(prop,frame=frame,group=pb.name)
def replace_action(source,name):
 action=bpy.data.actions.get(name)
 if action is None:
  action=source.copy() if source else bpy.data.actions.new(name);action.name=name;action.use_fake_user=True;return action
 if action.library:raise ValueError('Cannot replace a linked review Action')
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for curve in list(bag.fcurves):bag.fcurves.remove(curve)
 if source:
  destination=action.layers[0].strips[0].channelbag(action.slots[0]);origin=source.layers[0].strips[0].channelbag(source.slots[0])
  for original in origin.fcurves:
   curve=destination.fcurves.new(original.data_path,index=original.array_index);curve.keyframe_points.add(len(original.keyframe_points));values=[0.]*(len(original.keyframe_points)*2);original.keyframe_points.foreach_get('co',values);curve.keyframe_points.foreach_set('co',values)
 action.use_fake_user=True;return action

def validate_channels(rig,action):
 expected=set()
 for bone in rig.data.bones:
  rotation='rotation_euler' if bone.name.split('.')[0] in DIGITS else 'rotation_quaternion'
  for prop,count in [('location',3),('scale',3),(rotation,3 if rotation=='rotation_euler' else 4)]:
   for axis in range(count):expected.add((f'pose.bones["{bone.name}"].{prop}',axis))
 actual={(curve.data_path,curve.array_index) for layer in action.layers for strip in layer.strips for bag in strip.channelbags for curve in bag.fcurves}
 if actual!=expected:raise ValueError('The review Action must cover all 47 named joints with ordinary local channels')

def reused_clip(rig,source,clip):
 action=replace_action(source,'miki.hand-motion.'+clip)
 # Remove the rejected hand-roll/palm-lock adjustments; inherit the measured bind wrist.
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for curve in bag.fcurves:
     if curve.data_path in ['pose.bones["hand.L"].rotation_quaternion','pose.bones["hand.R"].rotation_quaternion']:
      for key in curve.keyframe_points:key.co.y=1. if curve.array_index==0 else 0.
 rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 for f in action.frame_range:
  bpy.context.scene.frame_set(int(f));finger_pose(rig,clip)
  for pb in rig.pose.bones:
   if pb.name.split('.')[0] in DIGITS:
    for prop in ['rotation_euler','location','scale']:pb.keyframe_insert(prop,frame=f,group=pb.name)
 linear(action);action['source_action']=source.name;action['source_file']='blender/studies/miki-option-a-motion/character/miki-option-a-motion.blend';action['fps']=120
 return action

def fit_run_arms(rig,action,data,hand):
 rest={b.name:b.matrix_local.copy() for b in rig.data.bones};frames=hand.rest_frames(data);refs=[];scene=bpy.context.scene
 rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 for tick in range(313):
  f=1+tick*.25;scene.frame_set(math.floor(f),subframe=f%1);bpy.context.view_layer.update();refs.append((f,{pb.name:pb.matrix.copy() for pb in rig.pose.bones}))
 for f,old in refs:
  chest=old['chest'].to_3x3()@rest['chest'].to_3x3().inverted()
  for side,sign in [('L',1),('R',-1)]:
   fore='forearm.'+side;wrist=old['hand.'+side].translation+chest@Vector((sign*.13,0,0));direction=(wrist-old[fore].translation).normalized();arms,_=hand.arm_pose(rig,old,side,wrist,rest['hand.'+side].to_3x3(),direction)
   normal=chest@Vector((-sign,0,0));fr=hand.frame(rest[fore].to_3x3().col[1],Vector(data['hand_frames'][side]['palm_normal_landmarks']),side);target=hand.frame(arms[fore].to_3x3().col[1],normal,side);rotation=target@fr.inverted()@rest[fore].to_3x3();position=arms[fore].translation.copy();arms[fore]=rotation.to_4x4();arms[fore].translation=position
   distal=rotation@rest[fore].to_3x3().inverted()@Vector(data['hand_frames'][side]['distal_wrist_to_middle']);rotation=hand.frame(distal,normal,side)@frames[side].inverted()@rest['hand.'+side].to_3x3();arms['hand.'+side]=rotation.to_4x4();arms['hand.'+side].translation=wrist
   for name in ['upper_arm.'+side,fore,'hand.'+side]:
    b=rig.data.bones[name];pb=rig.pose.bones[name];parent=arms.get(b.parent.name,old[b.parent.name]);pb.matrix_basis=b.convert_local_to_pose(arms[name],b.matrix_local,parent_matrix=parent,parent_matrix_local=b.parent.matrix_local,invert=True);pb.rotation_mode='QUATERNION';pb.rotation_quaternion.normalize();pb.keyframe_insert('rotation_quaternion',frame=f,group=name);pb.keyframe_insert('location',frame=f,group=name)
 linear(action)

def shoot_pose(rig,body,data,hand,f):
 rest={b.name:b.matrix_local.copy() for b in rig.data.bones};raise_amount=hand.ease((f-1)/80)*(1-hand.ease((f-281)/80))
 kick=hand.ease((f-181)/5) if f<=186 else 1-hand.ease((f-186)/35)
 forward=Vector((.6,-.8,0));up=Vector((0,0,1));right=forward.cross(up);base=Matrix((right,forward,up)).transposed();pitch=math.radians(-10*(1-raise_amount)+3*kick);rot=base@Matrix.Rotation(pitch,3,'X');stock=Vector((-.20,.02,1.40))-forward*.02*kick;rifle=rot.to_4x4();rifle.translation=stock-rot@Vector((0,-.04,-.055))
 poses={}
 for bone in rig.data.bones:
  parent=bone.parent
  pose=poses[parent.name]@rest[parent.name].inverted()@rest[bone.name] if parent else rest[bone.name].copy()
  extra=None
  if bone.name=='spine':extra=Quaternion((1,0,0),math.radians(2*raise_amount-1.2*kick))
  elif bone.name=='chest':extra=Quaternion((0,0,1),math.radians(5*raise_amount))
  elif bone.name=='head':extra=Quaternion((0,0,1),math.radians(31.87*raise_amount))
  if extra:
   xyz=pose.translation.copy();pose=(extra.to_matrix()@pose.to_3x3()).to_4x4();pose.translation=xyz
  poses[bone.name]=pose
 measured=hand.rest_frames(data);details={};right,forward,up=[rot.col[i].copy() for i in range(3)]
 for side in ['L','R']:
  point,ids=hand.palm_patch(body,rig,side,data)
  if side=='R':direction=(forward*.94-up*.34).normalized();normal=-right;contact=rifle@Vector((.0535,.318,-.085))
  else:direction=(right*.85+forward*.527).normalized();normal=up;contact=rifle@Vector((0,.535,-.071))
  skin=hand.frame(direction,normal,side)@measured[side].inverted();wrist=contact-skin@(point-rest['hand.'+side].translation);rotation=skin@rest['hand.'+side].to_3x3();arms,bend=hand.arm_pose(rig,poses,side,wrist,rotation,direction);poses.update(arms);details[side]={'physical_wrist_bend_degrees':bend,'palm_normal':list(normal),'distal_direction':list(direction),'wrist':list(wrist)}
 hand.apply_pose(rig,rest,poses);index=hand.ease((f-171)/15)*(1-hand.ease((f-206)/35));hand.curls(rig,1,True,index)
 return rifle,details

def build(rig,body,data,library,hand):
 if rig.type!='ARMATURE' or rig.library or rig.data.library or body.type!='MESH':raise ValueError('Expected the local focused character source')
 bpy.context.view_layer.update()
 if any(abs(rig.matrix_world[i][j]-float(i==j))>1e-6 for i in range(4) for j in range(4)):raise ValueError('The fitted rig object transform must remain identity')
 if len(body.data.vertices)!=10269 or 'source_vertex_id' not in body.data.attributes:raise ValueError('Expected the preserved Miki mesh and vertex lineage')
 if signature(rig)!=TARGET_REST:raise ValueError('The reviewed 47-joint rest skeleton changed')
 if hashlib.sha256(Path(library).read_bytes()).hexdigest()!=BODY_SHA:raise ValueError('Expected the reviewed fitted body-motion source')
 modifiers=[m for m in body.modifiers if m.type=='ARMATURE']
 if len(modifiers)!=1 or modifiers[0].object!=rig:raise ValueError('Expected one bound Armature modifier')
 modifiers[0].use_deform_preserve_volume=False
 scene=bpy.context.scene;rig.animation_data_create();old_frame,old_subframe=scene.frame_current,scene.frame_subframe;old_fps,old_base=scene.render.fps,scene.render.fps_base;old_action,old_slot=rig.animation_data.action,rig.animation_data.action_slot;old_bases={pb.name:pb.matrix_basis.copy() for pb in rig.pose.bones};tracks=[(t,t.mute) for t in rig.animation_data.nla_tracks]
 scene.render.fps=120;scene.render.fps_base=1;rig.animation_data.action=None
 for track in rig.animation_data.nla_tracks:track.mute=True
 with bpy.data.libraries.load(str(Path(library).resolve()),link=False) as (available,wanted):wanted.actions=['miki.option-a.run','miki.option-a.sneak']
 report={'fps':120,'bone_count':47,'deformation_method':'classicLinear; Preserve Volume disabled only on this new derivative to match the tested RealityKit path','body_motion_source':'blender/studies/miki-option-a-motion/character/miki-option-a-motion.blend','body_motion_sha256':BODY_SHA,'body_motion_lineage':'Original project party.run/party.sneak, previously fitted to Miki; not Quaternius motion capture. Body/leg paths retained, Sneak wrist positions retained, Run receives a 13 cm lateral arm clearance fit and measured inward palms. Old hand-roll and world-palm locks removed.','wrist_policy':'Measured bind-wrist orientation follows forearm; relaxed digits are original hand poses.','garment_policy':'All four garment Key targets/drivers, mesh, weights and rest skeleton remain unchanged.','actions':{},'rifle_source':'blender/studies/equipment/rifle-precision/rifle-precision.blend','rifle_collection':'rifle-precision','rifle_assembly':'rifle-precision / precision / rifle assembly','rifle_muzzle_local':[0,1.02,.012],'run_arm_outset_m':.13,'rifle_world_samples':[]}
 for clip,source in zip(['run','sneak'],wanted.actions):
  action=reused_clip(rig,source,clip)
  if clip=='run':fit_run_arms(rig,action,data,hand)
  report['actions'][clip]={'name':action.name,'frames':list(map(int,action.frame_range)),'loop':True,'source_action':source.name,'duration_seconds':(action.frame_range[1]-action.frame_range[0])/120,'markers':{'inspect':25 if clip=='run' else 73}}
 action=replace_action(None,'miki.hand-motion.shoot');rig.animation_data.action=action;wrists={'L':0.,'R':0.}
 for f in range(1,362):
  rifle,details=shoot_pose(rig,body,data,hand,f);key_pose(rig,f)
  if f==1:rig.animation_data.action_slot=action.slots[0]
  for side in wrists:wrists[side]=max(wrists[side],details[side]['physical_wrist_bend_degrees'])
  report['rifle_world_samples'].append([f,[list(r) for r in rifle]])
 linear(action);action['fps']=120;action['review_only']=True;action['source']='Original aim/recoil/recovery from the measured hand-pilot grip; no gameplay event or trigger geometry'
 report['actions']['shoot']={'name':action.name,'frames':[1,361],'loop':True,'duration_seconds':3.,'markers':{'low-ready':1,'aimed-ready':121,'shot':181,'peak-recoil':186,'recovered':241},'maximum_physical_wrist_bend_degrees':wrists};report['shoot_notes']='Shoulder-ready stock height; authored 3-degree/2cm recoil. Existing prop has no modelled trigger gap: small off-trigger index flex, not trigger actuation or scoped aim.'
 for entry in report['actions'].values():validate_channels(rig,bpy.data.actions[entry['name']])
 for source in wanted.actions:bpy.data.actions.remove(source)
 rig.animation_data.action=old_action
 if old_action is not None:rig.animation_data.action_slot=old_slot
 for pb in rig.pose.bones:pb.matrix_basis=old_bases[pb.name]
 for track,mute in tracks:track.mute=mute
 scene.render.fps,scene.render.fps_base=old_fps,old_base;scene.frame_set(old_frame,subframe=old_subframe)
 return report

if __name__=='__main__':
 import argparse,sys
 p=argparse.ArgumentParser(description=__doc__)
 for name in ['character','body-motion','palm-frames','hand-helper','output','report']:p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);inputs=[a.character,a.body_motion,a.palm_frames,a.hand_helper];outputs=[a.output,a.report]
 if len({x.resolve() for x in outputs})!=2 or any(x.resolve() in {i.resolve() for i in inputs} for x in outputs):raise ValueError('Output and report must be distinct from all inputs and each other')
 if any(x.exists() or x.is_symlink() for x in outputs):raise ValueError('Output and report must be new files')
 hashes={x:hashlib.sha256(x.read_bytes()).hexdigest() for x in inputs};spec=importlib.util.spec_from_file_location('measured_hands',a.hand_helper);hand=importlib.util.module_from_spec(spec);spec.loader.exec_module(hand)
 bpy.ops.wm.open_mainfile(filepath=str(a.character.resolve()),load_ui=False);rigs=[o for o in bpy.data.objects if o.type=='ARMATURE'];meshes=[o for o in bpy.data.objects if o.type=='MESH']
 if len(rigs)!=1 or len(meshes)!=1:raise ValueError('Use the focused character source, not a review composition')
 rig,body=rigs[0],meshes[0];result=build(rig,body,json.loads(a.palm_frames.read_text()),a.body_motion,hand);assert all(hashlib.sha256(x.read_bytes()).hexdigest()==h for x,h in hashes.items());result['appearance_source_sha256']=hashes[a.character];result['hand_helper_sha256']=hashes[a.hand_helper]
 rig.animation_data.action=None
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 bpy.context.scene.render.fps=120;bpy.context.scene.render.fps_base=1;bpy.context.scene.frame_set(0)
 bpy.ops.wm.save_as_mainfile(filepath=str(a.output.resolve()));result['candidate_sha256']=hashlib.sha256(a.output.read_bytes()).hexdigest();a.report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='rifle_world_samples'},indent=2))
