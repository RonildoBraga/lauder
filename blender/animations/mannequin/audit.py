"""Read-only dense Blender pose/geometry audit. Not required by portable CI."""
import bpy,hashlib,json,math
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
assert bpy.app.background
before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (HERE/'original-party.blend',HERE/'mannequin.blend')}
bpy.ops.wm.open_mainfile(filepath=str(HERE/'mannequin.blend'),load_ui=False)
s=bpy.context.scene;r=next(o for o in s.objects if o.type=='ARMATURE');bones=list(r.data.bones)
assert len(bones)==17 and r.data.library and r.data.library.filepath=='//original-party.blend'
assert all(not lib.is_missing for lib in bpy.data.libraries)
assert len([a for a in bpy.data.actions if a.name.startswith('party.')])==11
spec=json.loads(s['mannequin_clip_specs']);proxies=json.loads(s['mannequin_proxies'])
poses=0;minimum=0;maximum_gap=0;proxy_error=0;finite=True
for name,clip in spec.items():
 a=bpy.data.actions['mannequin.'+name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
 for i in range(math.ceil(clip['duration']*240)+1):
  t=min(clip['duration'],i/240);at=1+t*120;s.frame_set(math.floor(at),subframe=at%1);bpy.context.view_layer.update();poses+=1
  for b in r.pose.bones:
   assert all(math.isfinite(v) for row in b.matrix for v in row)
   if b.name.startswith(('forearm.','hand.','shin.','foot.')):
    maximum_gap=max(maximum_gap,(b.head-b.parent.tail).length)
  for d in proxies:
   o=bpy.data.objects['Mannequin / '+d['name']];b=r.pose.bones[bones[d['bone']].name]
   m=b.matrix@Matrix.LocRotScale(Vector(d['position']),Quaternion((d['rotation'][3],*d['rotation'][:3])),Vector((1,1,1)))
   proxy_error=max(proxy_error,(m.translation-o.matrix_world.translation).length)
   if d['name'].startswith('foot.'):
    minimum=min(minimum,min((o.matrix_world@v.co).z for v in o.data.vertices))
assert maximum_gap<.00002,(maximum_gap,'joint continuity')
assert proxy_error<.000002,(proxy_error,'proxy source/runtime descriptor mismatch')
assert minimum>-.01,(minimum,'raw source foot interpolation exceeded1cm; runtime floor lift must be reviewed')
assert before=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (HERE/'original-party.blend',HERE/'mannequin.blend')}
result={'sampleRate':240,'poses':poses,'maximumJointGap':maximum_gap,'minimumUncorrectedSourceFootZ':minimum,'maximumProxyPositionError':proxy_error,'sourceFilesUnchanged':True,'runtimeGrounding':'Runtime derives a vertical visual correction from foot proxy corners after interpolation; see native tests.'}
print(json.dumps(result,sort_keys=True))
output=ROOT/'.local/mannequin/blender-audit.json';output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
