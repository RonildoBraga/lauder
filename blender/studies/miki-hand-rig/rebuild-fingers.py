"""Rebuild measured finger chains on the exact recorded source.

Run in background Blender with SOURCE LANDMARKS OUTPUT after --.
No geometry, UV, material, garment-target or existing rest-bone edits.
The output is a separate review-only derivative; no canonical export is invoked.
"""
from pathlib import Path
import bpy,json,math,hashlib,sys
from mathutils import Vector
import argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('source',type=Path)
parser.add_argument('landmarks',type=Path)
parser.add_argument('output',type=Path)
parser.add_argument('--one-index-pilot',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
# Validate both destinations before creating directories or opening Blender data.
# Check lexical destinations as well as resolved paths so dangling symlinks fail.
source=args.source.resolve(strict=True)
landmarks=args.landmarks.resolve(strict=True)
output_path=args.output.absolute()
if output_path.suffix!='.blend':parser.error('Output must have the .blend extension')
report_path=output_path.with_suffix('.json')
out=output_path.resolve()
report_path_resolved=report_path.resolve()
protected={source,landmarks}
if out in protected or report_path_resolved in protected or out==report_path_resolved:
 parser.error('Output and report must be distinct from each other and both inputs')
for destination in (output_path,report_path):
 if destination.exists() or destination.is_symlink():
  parser.error(f'Destination must be new and must not be a symlink: {destination.name}')
land=json.loads(landmarks.read_text());mode='index' if args.one_index_pilot else 'all'
if hashlib.sha256(source.read_bytes()).hexdigest()!=land['source_sha256']:raise RuntimeError('Finger landmarks require the exact measured source')
root=next((p for p in source.parents if (p/'blender/extensions/lauder_levels/common.py').exists()),None)
if root is None:raise RuntimeError('Source must be inside the Lauder repository with its privacy helper')
out.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False);scene=bpy.context.scene
body=next(o for o in bpy.data.objects if o.type=='MESH');rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');m=body.data
original_bones={b.name:{'matrix':[list(r) for r in b.matrix_local],'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None,'deform':b.use_deform} for b in rig.data.bones}
oldweights=[{body.vertex_groups[g.group].name:g.weight for g in v.groups} for v in m.vertices]
oldshape={k.name:[tuple(p.co) for p in k.data] for k in m.shape_keys.key_blocks};oldcoords=[tuple(v.co) for v in m.vertices]
rig.animation_data_create();rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=True
for pb in rig.pose.bones:pb.matrix_basis.identity()
scene.frame_set(0);bpy.context.view_layer.update()
rig.data.pose_position='REST'
for ob in bpy.context.selected_objects:ob.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT');inverse=rig.matrix_world.inverted();inorm=inverse.to_3x3();records={}
for side,hand in land['hands'].items():
 normal=Vector(hand['palm_normal_landmarks'])
 for name,digit in hand['digits'].items():
  chain=[Vector(p) for p in digit['chain']];held=[]
  for k in range(3):
   bonename=f'{name}.{k+1:02d}.{side}';bone=rig.data.edit_bones.new(bonename);bone.head=inverse@chain[k];bone.tail=inverse@chain[k+1];bone.parent=rig.data.edit_bones['hand.'+side] if k==0 else rig.data.edit_bones[held[-1]];bone.use_connect=k>0;bone.use_deform=True;bone.align_roll((inorm@normal).normalized());held.append(bonename)
  records[name+'.'+side]={'bones':held,'chain_world':[list(v) for v in chain],'palm_normal_world':list(normal),'owned_vertex_ids':digit['owned_ids'],'seed_vertex_ids':digit['seed_ids'],'tip_vertex_ids':digit['tip_ids'],'base_slice_vertex_ids':digit['chain_slices'][0]['ids'],'tip_vertex_id':digit['tip_vertex_id'],'web_merge_z':digit['web_merge_z']}
bpy.ops.object.mode_set(mode='OBJECT')
after_bones={b.name:{'matrix':[list(r) for r in b.matrix_local],'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None,'deform':b.use_deform} for b in rig.data.bones if b.name in original_bones}
assert after_bones==original_bones,'Existing17 rest bones changed'
for side in ['L','R']:
 col=rig.data.collections.new('Fingers '+side)
 for n in records:
  if n.endswith('.'+side):
   for bone in records[n]['bones']:col.assign(rig.data.bones[bone])
for rec in records.values():
 for name in rec['bones']:
  rig.pose.bones[name].rotation_mode='XYZ'
  if body.vertex_groups.get(name) is None:body.vertex_groups.new(name=name)
groups={g.name:g for g in body.vertex_groups};changed=[]
def smooth(t):t=max(0.,min(1.,t));return t*t*(3-2*t)
def along(p,chain):
 lengths=[(b-a).length for a,b in zip(chain,chain[1:])];best=None;offset=0.
 for k,(a,b,length) in enumerate(zip(chain,chain[1:],lengths)):
  t=max(0.,min(1.,(p-a).dot(b-a)/(length*length)));q=a+(b-a)*t;dist=(p-q).length_squared
  if best is None or dist<best[0]:best=(dist,offset+t*length)
  offset+=length
 return best[1],lengths
for token,rec in records.items():
 digit,side=token.split('.')
 if mode=='index' and token!='index.L':continue
 chain=[Vector(p) for p in rec['chain_world']];base_z=chain[0].z
 for i in rec['owned_vertex_ids']:
  p=body.matrix_world@m.vertices[i].co
  factor=1-smooth((p.z-(base_z-.015))/.030)
  if factor<1e-8:continue
  s,lengths=along(p,chain);boundaries=[lengths[0],lengths[0]+lengths[1]];parts={}
  for k,b in enumerate(boundaries):
   blend=.30*min(lengths[k],lengths[k+1])
   if b-blend<=s<=b+blend:
    f=smooth((s-b+blend)/(2*blend));parts={k:1-f,k+1:f};break
  if not parts:parts={0 if s<boundaries[0] else 1 if s<boundaries[1] else 2:1.}
  original=oldweights[i];hand_weight=original.get('hand.'+side,0.)
  weights=dict(original);weights['hand.'+side]=hand_weight*(1-factor)
  for k,w in parts.items():weights[rec['bones'][k]]=hand_weight*factor*w
  # Forearm contribution is preserved; only the old hand weight is redistributed.
  for g in body.vertex_groups:g.remove([i])
  for name,w in weights.items():
   if w>1e-8:groups[name].add([i],w,'REPLACE')
  changed.append({'vertex_id':i,'digit':token,'factor':factor,'before':original,'after':{body.vertex_groups[g.group].name:g.weight for g in m.vertices[i].groups}})
rig.data.pose_position='POSE'
for pb in rig.pose.bones:pb.matrix_basis.identity()
scene.frame_set(0);scene.render.fps=120;scene.render.fps_base=1.
assert oldcoords==[tuple(v.co) for v in m.vertices]
assert oldshape=={k.name:[tuple(p.co) for p in k.data] for k in m.shape_keys.key_blocks}
changedids={d['vertex_id'] for d in changed}
for i,v in enumerate(m.vertices):
 if i not in changedids:assert oldweights[i]=={body.vertex_groups[g.group].name:g.weight for g in v.groups},i
for token,rec in records.items():
 rec['bone_axes_world']={name:{'x':list((rig.matrix_world.to_3x3()@rig.data.bones[name].matrix_local.to_3x3().col[0]).normalized()),'y':list((rig.matrix_world.to_3x3()@rig.data.bones[name].matrix_local.to_3x3().col[1]).normalized()),'z':list((rig.matrix_world.to_3x3()@rig.data.bones[name].matrix_local.to_3x3().col[2]).normalized())} for name in rec['bones']}
rig['hand_pilot_source_sha256']=land['source_sha256'];rig['hand_pilot_note']='Measured three-joint digits; existing17 rest bones preserved; review only'
sys.path.insert(0,str(root/'blender/extensions'))
from lauder_levels.common import _overwrite,forget_local_paths
for image in bpy.data.images:
 name=Path(image.filepath_raw.replace('\\','/')).name;_overwrite(image,'filepath_raw','//'+name)
 for part in image.packed_files:_overwrite(part,'filepath','//'+name)
for scene in bpy.data.scenes:_overwrite(scene.render,'filepath','//')
forget_local_paths(str(out));bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,relative_remap=True)
report={'mode':mode,'source_sha256':land['source_sha256'],'candidate':out.name,'candidate_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'original17_rest_bones_exact':after_bones==original_bones,'bone_count':len(rig.data.bones),'records':records,'changed_hand_vertex_ids':sorted(changedids),'weight_changes':changed,'geometry_exact':True,'garment_targets_exact':True,'non_hand_weights_exact':True,'hand_frames':{s:{k:v for k,v in data.items() if k not in ['digits','hand_ids','palm_ids','palm_pca_eigenvalues','palm_normal_pca']} for s,data in land['hands'].items()}}
report_path_resolved.write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k not in ['records','weight_changes','changed_hand_vertex_ids','hand_frames']}));print('Handweightvertices',len(changedids))
