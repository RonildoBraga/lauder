"""Isolated source→USD skin reference probe; never saves the authored Blender file."""
from pathlib import Path
import bpy,json,hashlib,sys,math,argparse
from mathutils import Matrix
from pxr import Usd,UsdGeom,UsdSkel,UsdUtils,Sdf,Vt,Gf
parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--action',default='miki.hands.controls');parser.add_argument('--frames',default='1,61,181');parser.add_argument('--bake-world',action='store_true');parser.add_argument('--materials',action='store_true')
parser.add_argument('--rifle-report',type=Path)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);source=args.source.resolve()
raw_output=args.output.expanduser().absolute()
if raw_output.exists() or raw_output.is_symlink():raise ValueError('Output must be a new directory; existing outputs are never overwritten')
if any(p.is_symlink() for p in raw_output.parents):raise ValueError('Output ancestors must not be symbolic links')
out=raw_output.resolve()
repository=next((p for p in source.parents if (p/'AGENTS.md').is_file()),None)
if repository:
 for protected in ('blender','apple','art','docs','.git'):
  if out.is_relative_to(repository/protected):raise ValueError('Use a scratch output outside authored source directories')
out.mkdir(parents=True,exist_ok=False)
source_sha=hashlib.sha256(source.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
scene=bpy.context.scene;body=next(o for o in scene.objects if o.type=='MESH' and o.data.attributes.get('source_vertex_id'));rig=next(m.object for m in body.modifiers if m.type=='ARMATURE' and m.object)
rig.data.pose_position='POSE';ad=rig.animation_data_create()
for tr in ad.nla_tracks:tr.mute=True
action=bpy.data.actions[args.action];ad.action=action;ad.action_slot=action.slots[0]
frames=[float(x) for x in args.frames.split(',')]
ids=[d.value for d in body.data.attributes['source_vertex_id'].data]
def sample(frame):
 scene.frame_set(math.floor(frame),subframe=frame%1);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);me=ev.to_mesh(preserve_all_data_layers=True,depsgraph=dg)
 pts=[list(body.matrix_world@v.co) for v in me.vertices];ev.to_mesh_clear();return pts
before={};shape_weights={}
for f in frames:
 before[str(f)]=sample(f)
 shape_weights[str(f)]={k.name:k.value for k in body.data.shape_keys.key_blocks[1:]} if body.data.shape_keys else {}
world=body.matrix_world.copy();local_before=[list(v.co) for v in body.data.vertices]
preserve_volume=next(m.use_deform_preserve_volume for m in body.modifiers if m.type=='ARMATURE')
if args.bake_world:
 # Explicitly bake the measured world matrix, not transform_apply's TRS cache.
 normals=[(world.to_3x3().inverted().transposed()@n.vector).normalized() for n in body.data.corner_normals]
 body.data.transform(world,shape_keys=True);body.data.normals_split_custom_set(normals)
 body.parent=None
 body.matrix_parent_inverse=Matrix.Identity(4);body.matrix_basis=Matrix.Identity(4);body.matrix_world=Matrix.Identity(4)
 body.update_tag(refresh={'OBJECT','DATA'});bpy.context.view_layer.update()
after={str(f):sample(f) for f in frames}
max_bake=max(math.dist(p,q) for f in before for p,q in zip(before[f],after[f]))
assert max_bake<2e-6,(max_bake,'World skin appearance changed during scratch normalization')
groups={g.index:g.name for g in body.vertex_groups}
weights=[{groups[w.group]:w.weight for w in v.groups if w.weight>0} for v in body.data.vertices]
rest_positions=[list(v.co) for v in body.data.vertices]
scene.render.fps=120;scene.render.fps_base=1;scene.frame_start=int(min(frames));scene.frame_end=int(max(frames));scene.frame_set(scene.frame_start)
# Preserve alignment parents: they are part of the skin's geometric bind space.
# A focused source has no studio objects; only lights/cameras are irrelevant here.
for o in list(scene.objects):
 if o.type in {'LIGHT','CAMERA'}:bpy.data.objects.remove(o,do_unlink=True)
usd=out/'character.usdc';usdz=out/'character.usdz'
options=dict(export_materials=args.materials,export_lights=False,export_cameras=False,export_animation=True,export_armatures=True,
 only_deform_bones=False,merge_parent_xform=False,convert_orientation=True,export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y',
 export_custom_properties=False,author_blender_name=False)
bpy.ops.wm.usd_export(filepath=str(usd),**options)
stage=Usd.Stage.Open(str(usd));mesh=next(p for p in stage.Traverse() if p.GetTypeName()=='Mesh');skel=UsdSkel.Skeleton(next(p for p in stage.Traverse() if p.GetTypeName()=='Skeleton'))
points=list(mesh.GetAttribute('points').Get());joints=list(skel.GetJointsAttr().Get());binding=UsdSkel.BindingAPI(mesh)
blend_anims=[UsdSkel.Animation(p) for p in stage.Traverse() if p.GetTypeName()=='SkelAnimation' and UsdSkel.Animation(p).GetBlendShapesAttr().Get()]
usd_shape_weights={}
for f in frames:
 values={}
 for anim in blend_anims:
  values.update({str(n):float(w) for n,w in zip(anim.GetBlendShapesAttr().Get(),anim.GetBlendShapeWeightsAttr().Get(Usd.TimeCode(f)))})
 usd_shape_weights[str(f)]=values
# Source IDs retain exact exported point order only if numeric geometry agrees.
point_order_error=max(math.dist(p,q) for p,q in zip(points,rest_positions))
if point_order_error<2e-6:
 pv=UsdGeom.PrimvarsAPI(mesh).CreatePrimvar('source_vertex_id',Sdf.ValueTypeNames.IntArray,UsdGeom.Tokens.vertex);pv.Set(Vt.IntArray(ids))
stage.GetRootLayer().Save();assert UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(usd)),str(usdz))
ref={'source_sha256':source_sha,'action':args.action,'fps':120,'frames':frames,'source_vertex_ids':ids,'weights':weights,
 'blender_world_positions':before,'scratch_world_positions':after,'max_scratch_normalization_world_error_m':max_bake,
 'blender_preserve_volume':preserve_volume,'blender_shape_weights':shape_weights,'usd_shape_weights':usd_shape_weights,
 'usd_skinning_method':str(binding.GetSkinningMethodAttr().Get()),
 'source_mesh_world_matrix':[list(r) for r in world],'explicit_world_bake':args.bake_world,
 'retained_object_hierarchy':[(o.name,o.type,o.parent.name if o.parent else None) for o in scene.objects],
 'exported_point_order_error_m':point_order_error,'mesh_points':[[float(x) for x in p] for p in points],
 'usd_mesh_to_world':[list(r) for r in UsdGeom.XformCache().GetLocalToWorldTransform(mesh)],
 'usd_skeleton_to_world':[list(r) for r in UsdGeom.XformCache().GetLocalToWorldTransform(skel.GetPrim())],
 'usd_geom_bind':[list(r) for r in binding.GetGeomBindTransformAttr().Get()],
 'usd_joint_names':[str(n) for n in joints],'usd_bind_transforms':[[list(row) for row in m] for m in skel.GetBindTransformsAttr().Get()],
 'usdz_sha256':hashlib.sha256(usdz.read_bytes()).hexdigest(),'export_options':options}
if args.rifle_report:
 rifle=json.loads(args.rifle_report.read_text());samples=dict(rifle.get('rifle_world_samples',rifle.get('rifle_world_bookmarks',[])))
 ref['rifle_source']=rifle['rifle_source'];ref['rifle_asset']='../rifle/character.usdz'
 ref['rifle_world_matrices']={str(f):samples[int(f)] for f in frames}
(out/'reference.json').write_text(json.dumps(ref,separators=(',',':'))+'\n')
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_sha
print(json.dumps({k:ref[k] for k in ('source_sha256','action','explicit_world_bake','max_scratch_normalization_world_error_m','exported_point_order_error_m','usdz_sha256')}),flush=True)
