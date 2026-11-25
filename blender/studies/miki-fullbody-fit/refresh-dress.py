"""Reusable, asset-local dress motion fitting; no changes to body Actions or canonical source."""
import bpy,json,hashlib,sys
from pathlib import Path
from mathutils import Matrix,Vector
sys.path.insert(0,str(Path(__file__).parent))
from dress_clearance import clear_dress

def evaluated(obj,selected_polygons):
 e=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());me=e.to_mesh();me.calc_loop_triangles();points=[e.matrix_world@v.co for v in me.vertices];triangles=[tuple(t.vertices)for t in me.loop_triangles if t.polygon_index in selected_polygons];e.to_mesh_clear();return points,triangles

def refresh_coat(rig,coat,lining,colliders,clip_frames):
 """Regenerate matching local KeyActions from unchanged body motion.

 colliders is [(Object, polygon-index list)] of true pants/underlayers. Existing
 core Actions/rest/meshes remain immutable. The clean dress is pelvis-rigid;
 field corrections are source-bind-space deltas copied by outer_vertex_index.
 """
 assert len(rig.data.bones)==17 and rig.library is None,'Use the local seventeen-bone fitted study rig'
 for obj in [coat,lining]:
  assert obj.library is None and max(abs(obj.matrix_world[i][j]-(1. if i==j else 0.))for i in range(4)for j in range(4))<1e-6,'Refresh the source actor, not a transformed review instance'
  assert all(len(v.groups)==1 and obj.vertex_groups[v.groups[0].group].name=='pelvis'and abs(v.groups[0].weight-1.)<1e-6 for v in obj.data.vertices),'The clean dress field assumes pelvis-rigid skin'
 assert 'outer_vertex_index'in lining.data.attributes and all(0<=a.value<len(coat.data.vertices)for a in lining.data.attributes['outer_vertex_index'].data)
 saved_basis={p.name:p.matrix_basis.copy()for p in rig.pose.bones};saved_pose=rig.data.pose_position;saved_mutes=[(t,t.mute)for t in rig.animation_data.nla_tracks]if rig.animation_data else[]
 for track,mute in saved_mutes:track.mute=True
 rig.data.pose_position='POSE'
 scene=bpy.context.scene;saved_action=rig.animation_data.action if rig.animation_data else None;saved_slot=rig.animation_data.action_slot if rig.animation_data else None;saved_frame=scene.frame_current;saved_sub=scene.frame_subframe
 rig.animation_data_create();rest=[v.co.copy()for v in coat.data.vertices];faces=[tuple(f.vertices)for f in coat.data.polygons]
 for obj in [coat,lining]:obj.shape_key_clear();obj.shape_key_add(name='Basis')
 for action in list(bpy.data.actions):
  if action.name.startswith('miki.coat.corrective.')or action.name.startswith('miki.coat_lining.corrective.'):bpy.data.actions.remove(action)
 fitted={};report={'method':'Clean open dress; fixed radial nonnegative field with face/edge/vertex constraints against retained pants and lean closed underlayers. No nearest normals or bag constraints.','clips':{},'key_action_map':{}}
 for clip,frames in clip_frames.items():
  action=bpy.data.actions['miki.fitted.'+clip];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0];clip_offsets=[];rows=[]
  for frame in frames:
   scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
   P=rig.matrix_world@rig.pose.bones['pelvis'].matrix@rig.data.bones['pelvis'].matrix_local.inverted();Pi=P.inverted();body_points=[];body_faces=[]
   for obj,indices in colliders:
    off=len(body_points);evaluated_points,evaluated_faces=evaluated(obj,set(indices));body_points.extend(Pi@p for p in evaluated_points);body_faces.extend([[v+off for v in face]for face in evaluated_faces])
   points,offsets,stats=clear_dress(rest,faces,body_points,body_faces);clip_offsets.append([p-r for p,r in zip(points,rest)]);rows.append({'frame':frame,**stats})
   print('DRESS_POSE',clip,frame,stats['max_offset_m'],len(stats['iterations']),flush=True)
  # Positive envelope over adjacent dense samples; fixed directions make this conservative.
  if len(frames)>10:
   period=len(frames)-1
   direction=[Vector((p.x,p.y-.025,0)).normalized()for p in rest]
   magnitude=[[delta.dot(d)for delta,d in zip(row,direction)]for row in clip_offsets]
   clip_offsets=[[direction[i]*max(magnitude[(j-1)%period][i],magnitude[j%period][i],magnitude[(j+1)%period][i])for i in range(len(rest))]for j in range(len(frames))]
  fitted[clip]=[]
  for index,(frame,deltas)in enumerate(zip(frames,clip_offsets)):
   label=f'coat.{clip}.{index:03d}';outer=coat.shape_key_add(name=label);inner=lining.shape_key_add(name=label)
   for i,p in enumerate(rest):outer.data[i].co=p+deltas[i]
   for i,ref in enumerate(lining.data.attributes['outer_vertex_index'].data):inner.data[i].co=lining.data.shape_keys.key_blocks['Basis'].data[i].co+deltas[ref.value]
   fitted[clip].append((frame,label))
  report['clips'][clip]=rows
 for clip,rows in fitted.items():
  first,last=rows[0][0],rows[-1][0];keyframe={label:(j,frame)for j,(frame,label)in enumerate(rows)}
  for obj in [coat,lining]:
   kd=obj.data.shape_keys;kd.animation_data_create();action=bpy.data.actions.new(f'miki.{obj.get("semantic_part")}.corrective.{clip}');action.use_fake_user=True;kd.animation_data.action=action
   for key in kd.key_blocks:
    if key.name=='Basis':continue
    if key.name in keyframe:
     index,frame=keyframe[key.name];prev=rows[max(0,index-1)][0];nxt=rows[min(len(rows)-1,index+1)][0]
     for time in sorted({first,prev,frame,nxt,last}):key.value=1. if time==frame else 0.;key.keyframe_insert('value',frame=time,group=clip)
    else:
     for time in [first,last]:key.value=0.;key.keyframe_insert('value',frame=time,group='Reset other clips')
   for layer in action.layers:
    for strip in layer.strips:
     for bag in strip.channelbags:
      for curve in bag.fcurves:
       for key in curve.keyframe_points:key.interpolation='LINEAR'
   report['key_action_map'].setdefault(clip,{})[obj.get('semantic_part')]=action.name
   kd.animation_data.action=None;kd.use_fake_user=True
   for key in kd.key_blocks:key.value=0.
 rig.animation_data.action=saved_action
 if saved_action and saved_slot:rig.animation_data.action_slot=saved_slot
 for name,matrix in saved_basis.items():rig.pose.bones[name].matrix_basis=matrix
 for track,mute in saved_mutes:track.mute=mute
 rig.data.pose_position=saved_pose;scene.frame_set(saved_frame,subframe=saved_sub);bpy.context.view_layer.update()
 return report

def main():
 """Regenerate only this unregistered study, never a canonical character/library."""
 folder=Path(__file__).resolve().parent;expected=folder/'character/miki-fullbody-fit.blend'
 if Path(bpy.data.filepath).resolve()!=expected:
  raise ValueError('Open this study character source before refreshing the dress')
 scene=bpy.context.scene;rigs=[o for o in scene.objects if o.type=='ARMATURE']
 if len(rigs)!=1 or len(rigs[0].data.bones)!=17:raise ValueError('Expected one fitted 17-bone actor')
 rig=rigs[0];shared=folder.parents[2]/'blender/animations/party.blend'
 if rig.get('motion_source_sha256')!=hashlib.sha256(shared.read_bytes()).hexdigest():
  raise ValueError('Shared body motion changed; refit and review body clips before regenerating dress motion')
 parts={o.get('semantic_part'):o for o in scene.objects if o.type=='MESH'}
 legs={'thigh.L','thigh.R','shin.L','shin.R','foot.L','foot.R'};colliders=[]
 for role in ['body','upper_leggings']:
  obj=parts[role];leg=[sum(g.weight for g in v.groups if obj.vertex_groups[g.group].name in legs)for v in obj.data.vertices]
  indices=[f.index for f in obj.data.polygons if role=='upper_leggings' or sum(leg[i]for i in f.vertices)/len(f.vertices)>.5]
  colliders.append((obj,indices))
 frames={clip:list(range(1,int(bpy.data.actions['miki.fitted.'+clip].frame_range[1])+1))for clip in ['run','sneak','fire']}
 report=refresh_coat(rig,parts['coat'],parts['coat_lining'],colliders,frames)
 rig['garment_correctives']=json.dumps(report);rig.animation_data_clear()
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 scene.frame_set(0)
 bpy.context.preferences.filepaths.save_version=0
 import sys
 sys.path.insert(0, str(folder.parents[1] / 'extensions'))
 from lauder_levels import forget_local_paths
 for scene in bpy.data.scenes:
     scene.render.filepath = ' ' * 1023
     scene.render.filepath = '//'
 forget_local_paths(expected)
 bpy.ops.wm.save_as_mainfile(filepath=str(expected),relative_remap=False,compress=True)

if __name__=='__main__':
 main()
