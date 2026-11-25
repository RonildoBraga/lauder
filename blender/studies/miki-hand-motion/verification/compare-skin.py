"""Compare actual native imported buffers/poses to source-ID Blender world references."""
from pathlib import Path
import sys,json,math,collections
import numpy as np
from mathutils import Vector,kdtree
arguments=sys.argv[sys.argv.index('--')+1:];folder=Path(arguments[0]).resolve()
destination=(Path(arguments[arguments.index('--report')+1]) if '--report' in arguments else folder/'native-comparison.json').expanduser().absolute()
if destination.exists() or destination.is_symlink():raise ValueError('Comparison report destination must be new')
if any(p.is_symlink() for p in destination.parents):raise ValueError('Output ancestors must not be symbolic links')
destination=destination.resolve()
repository=next((p for p in folder.parents if (p/'AGENTS.md').is_file()),None)
if repository:
 for name in ('blender','apple','art','docs','.git'):
  if destination.is_relative_to(repository/name):raise ValueError('Use a scratch report outside authored source directories')
ref=json.loads((folder/'reference.json').read_text());native=json.loads((folder/'native.json').read_text())
source_points=np.asarray(ref['mesh_points'],dtype=np.float32);lookup=collections.defaultdict(list)
for i,p in enumerate(source_points):lookup[p.tobytes()].append(i)
tree=kdtree.KDTree(len(source_points))
for i,p in enumerate(source_points):tree.insert(Vector(p),i)
tree.balance()
names=native['joint_names'];skel_names=native['skeleton_joint_names'];name_to_model={n:i for i,n in enumerate(names)}
parent_model=[None if native['joint_parent_indices'][skel_names.index(n)] is None else name_to_model[skel_names[native['joint_parent_indices'][skel_names.index(n)]]] for n in names]
inverse_bind=np.asarray(native['inverse_bind_matrices_columns'],dtype=np.float64).transpose(0,2,1)
geom_bind=np.asarray(ref['usd_geom_bind'],dtype=np.float64).T
normalize=lambda n:''.join(c.lower() for c in n if c.isalnum())
records=[];part_cache=[];all_covered=set();pose_samples={}
for part in native['parts']:
 p=np.asarray(part['positions'],dtype=np.float32);per=part['influences_per_vertex'];w=part['influences'];idx=np.asarray([x['index'] for x in w],dtype=int).reshape(-1,per);weight=np.asarray([x['weight'] for x in w]).reshape(-1,per)
 mapping=[];max_near=0.;max_weight_error=0.
 for row,point in enumerate(p):
  options=lookup.get(point.tobytes(),[])
  if not options:
   _,i,distance=tree.find(Vector(point));assert distance<2e-6,(distance,point);options=[i];max_near=max(max_near,distance)
  actual={skel_names[j].rsplit('/',1)[-1]:float(v) for j,v in zip(idx[row],weight[row]) if v>0}
  def delta(i):
   expected={n.replace('.','_'):v for n,v in ref['weights'][i].items()}
   return sum(abs(actual.get(n,0)-expected.get(n,0)) for n in set(actual)|set(expected))
  selected=min(options,key=delta);max_weight_error=max(max_weight_error,delta(selected));mapping.append(selected)
 assert max_weight_error<1e-5,max_weight_error
 all_covered.update(mapping);part_cache.append((part,p.astype(np.float64),idx,weight,np.asarray(mapping),max_near,max_weight_error))
for key,frame in native['frames'].items():
 local=np.asarray(frame['joint_local_matrices_columns'],dtype=np.float64).transpose(0,2,1);global_m=[]
 for i,m in enumerate(local):
  parent=parent_model[i];assert parent is None or parent<i
  global_m.append(m if parent is None else global_m[parent]@m)
 # Influence indices address the skeleton palette, not an assumed model ordering.
 skin=np.asarray([global_m[name_to_model[n]] for n in skel_names])@inverse_bind@geom_bind
 errs=[];worst=None;tip_errors=collections.defaultdict(list);tip_points=collections.defaultdict(list);native_shapes=frame['blend_weights'];source_shapes=ref['usd_shape_weights'][key]
 assert set(map(normalize,native_shapes))==set(map(normalize,source_shapes)),(native_shapes,source_shapes)
 shape_error=max((abs(next(v for n,v in native_shapes.items() if normalize(n)==normalize(k))-v) for k,v in source_shapes.items()),default=0)
 for part,base,indices,weights,mapping,near,werr in part_cache:
  positions=base.copy()
  for name,offsets in part['blend_shape_offsets'].items():
   matches=[v for n,v in native_shapes.items() if normalize(n)==normalize(name)];assert len(matches)==1,(name,native_shapes)
   offsets=np.asarray(offsets);assert len(offsets)==len(positions)
   positions+=matches[0]*offsets
  h=np.column_stack((positions,np.ones(len(positions))))
  posed=(np.einsum('nvij,nj->nvi',skin[indices],h)*weights[:,:,None]).sum(axis=1)[:,:3]
  expected=np.asarray(ref['blender_world_positions'][key])[mapping]
  distance=np.linalg.norm(posed-expected,axis=1);errs.extend(distance.tolist());j=int(np.argmax(distance))
  for row in range(len(posed)):
   labels=[skel_names[joint].rsplit('/',1)[-1] for joint,w in zip(indices[row],weights[row]) if w>=.75 and (skel_names[joint].endswith('_03_L') or skel_names[joint].endswith('_03_R'))]
   if labels:tip_errors[labels[0]].append(float(distance[row]));tip_points[labels[0]].append(posed[row].tolist())
  if worst is None or distance[j]>worst['error_m']:worst={'error_m':float(distance[j]),'source_vertex_id':ref['source_vertex_ids'][int(mapping[j])],'actual':posed[j].tolist(),'expected':expected[j].tolist()}
 pose_samples[float(key)]=tip_points
 records.append({'frame':float(key),'native_vertices':len(errs),'maximum_error_m':max(errs),'mean_error_m':sum(errs)/len(errs),'shape_weight_max_error':shape_error,'active_shape_weights':native_shapes,'distal_digit_max_pose_error_m':{n:max(v) for n,v in tip_errors.items()},'worst':worst})
first,last=min(pose_samples),max(pose_samples);tip_motion={n:float(np.max(np.linalg.norm(np.asarray(v)-np.asarray(pose_samples[last][n]),axis=1))) for n,v in pose_samples[first].items()}
result={'source_sha256':ref['source_sha256'],'usdz_sha256':ref['usdz_sha256'],'action':ref['action'],'preserve_volume':ref['blender_preserve_volume'],
 'native_joint_count':native['joint_count'],'matched_original_vertex_count':len(all_covered),'source_vertex_count':len(ref['source_vertex_ids']),
 'native_independent_instances':native['independent_instance_pose'],'native_independent_blend_weights':native.get('independent_instance_blend_weights'),
 'native_blend_animation_count':native['blend_animation_count'],
 'geometry_bind_applied_before_skin':True,'pose_reference_space':'Blender world / identity-rig skeleton space, metres; USD stage axis wrapper is excluded on both sides.',
 'records':records,'maximum_error_m':max(r['maximum_error_m'] for r in records),'maximum_shape_weight_error':max(r['shape_weight_max_error'] for r in records),
 'distal_digit_motion_first_to_last_m':tip_motion,'native_reset_joint_pose_exact':native.get('reset_joint_pose_exact'),
 'tolerance_m':1e-5,'passes_10um':max(r['maximum_error_m'] for r in records)<1e-5,
 'diagnostic_passes_5um':max(r['maximum_error_m'] for r in records)<5e-6}
destination.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
