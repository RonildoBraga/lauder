"""Resample the saved Blender mannequin Actions; update checked JSON and receipt."""
import bpy,hashlib,json,math
from pathlib import Path
from mathutils import Matrix
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
assert bpy.app.background
bpy.ops.wm.open_mainfile(filepath=str(HERE/'mannequin.blend'),load_ui=False)
scene=bpy.context.scene
rig=next(o for o in scene.objects if o.type=='ARMATURE')
bones=list(rig.data.bones);names=[b.name for b in bones]
C=Matrix(((-1,0,0,0),(0,0,1,0),(0,1,0,0),(0,0,0,1)))
def values(matrix):
    p,q,s=matrix.decompose();assert max(abs(v-1) for v in s)<1e-4
    q.normalize();return [round(float(v),6) for v in (*p,q.x,q.y,q.z,q.w)]
rest=[values(b.parent.matrix_local.inverted()@b.matrix_local if b.parent else C@b.matrix_local) for b in bones]
clips={}
for name,spec in sorted(json.loads(scene['mannequin_clip_specs']).items()):
    action=bpy.data.actions['mannequin.'+name]
    rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    frames=[];count=max(2,math.ceil(spec['duration']*30)+1)
    for index in range(count):
        at=1+120*spec['duration']*index/(count-1)
        scene.frame_set(math.floor(at),subframe=at%1);bpy.context.view_layer.update()
        pose={p.name:p.matrix.copy() for p in rig.pose.bones}
        frames.append([values(pose[b.parent.name].inverted()@pose[b.name] if b.parent else C@pose[b.name]) for b in bones])
    clips[name]={**spec,'frames':frames}
source_sha=scene['source_sha256']
result={'version':1,'sourceSHA256':source_sha,'fps':30,'bones':[{'name':b.name,'parent':names.index(b.parent.name) if b.parent else -1,'length':round(b.length,6),'rest':rest[i]} for i,b in enumerate(bones)],'proxies':json.loads(scene['mannequin_proxies']),'clips':clips,'sockets':{side:[round(float(v),6) for v in (lambda q:(q.x,q.y,q.z,q.w))((C@rig.data.bones['hand.'+side].matrix_local).to_quaternion().inverted())] for side in ('L','R')}}
target=ROOT/'apple/sources/content/mannequin.json';target.write_text(json.dumps(result,separators=(',',':'),sort_keys=True)+'\n')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
manifest={'version':1,'historicalCommit':'f80fa1391824432726f45c69d51e13a2f0f49334','sourceSHA256':source_sha,'blendSHA256':sha(HERE/'mannequin.blend'),'jsonSHA256':sha(target),'tools':{name:sha(HERE/name) for name in ('build.py','export.py')},'boneCount':17,'clipCount':len(clips),'sampleRate':30,'sourceClips':['party.'+n for n in ('idle','walk','jog','run','backward','strafe_left','strafe_right','hit')],'meleeClips':['slash','sweep','thrust','guard','dodge'],'maximumAuthoringGripGap':json.loads(scene['mannequin_grip_audit']),'maximumSourceGroundingAdjustment':scene['mannequin_source_grounding_adjustment'],'dodgeStyle':'Direction-neutral quickstep/compression; simulation owns displacement'}
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
print(json.dumps(manifest))
