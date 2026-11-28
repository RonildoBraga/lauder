"""Build the original-17-bone mannequin and checked runtime samples. Blender only.

Run from any directory: Blender -b --factory-startup --python-exit-code 1 --python build.py
The preserved input is never saved or modified. No installed extension is used.
"""
import bpy, hashlib, json, math, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
SOURCE=HERE/'original-party.blend'
SOURCE_SHA='7abc47d922621f1685522083afee445927f3625f86b2c19eb7077f437703a4b8'
assert bpy.app.background and hashlib.sha256(SOURCE.read_bytes()).hexdigest()==SOURCE_SHA
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(SOURCE),link=True,relative=True) as (available,wanted):
    wanted.armatures=['Party humanoid skeleton']
    wanted.actions=[n for n in available.actions if n.startswith('party.') and n!='party.runtime']
rig=bpy.data.objects.new('Mannequin - original 17 bones',wanted.armatures[0]);bpy.context.scene.collection.objects.link(rig)
rig.show_in_front=True
binding=rig.animation_data_create()
for action in wanted.actions:
    track=binding.nla_tracks.new();track.name='SOURCE ONLY - '+action.name;track.mute=True
    strip=track.strips.new(action.name,1,action);strip.action_slot=action.slots[0]
actions={a.name:a for a in wanted.actions}
bones=list(rig.data.bones);names=[b.name for b in bones];rest={b.name:b.matrix_local.copy() for b in bones}
assert len(names)==17
C=Matrix(((-1,0,0,0),(0,0,1,0),(0,1,0,0),(0,0,0,1)))
def game(v):return C@Vector(v)
def blender(v):return C@Vector(v)
def qarray(q):return [round(float(v),6) for v in (q.x,q.y,q.z,q.w)]
def va(v):return [round(float(x),6) for x in v]
def set_action(a,t):
    binding.action=a;binding.action_slot=a.slots[0]
    for p in rig.pose.bones:p.rotation_mode='QUATERNION'
    bpy.context.scene.frame_set(math.floor(t),subframe=t%1);bpy.context.view_layer.update()
def curves(a):return [f for l in a.layers for s in l.strips for bag in s.channelbags for f in bag.fcurves]
def direction_matrix(name,head,tail):
    b=rig.data.bones[name]
    r=(b.tail_local-b.head_local).rotation_difference(Vector(tail)-Vector(head)).to_matrix().to_4x4()
    m=r@rest[name];m.translation=Vector(head);return m

def chain(a,b,c,target,pole,pose):
    start=pose[a].translation.copy();target=Vector(target)
    l1=rig.data.bones[a].length;l2=rig.data.bones[b].length
    v=target-start;actual=v.length;d=min(l1+l2,max(abs(l1-l2)+.00001,actual));axis=v.normalized() if actual>1e-8 else Vector((0,0,-1))
    bend=Vector(pole);bend-=axis*bend.dot(axis)
    if bend.length<1e-5:bend=axis.cross(Vector((0,0,1)))
    bend.normalize();along=(l1*l1-l2*l2+d*d)/(2*d)
    elbow=start+axis*along+bend*math.sqrt(max(0,l1*l1-along*along));end=start+axis*d
    pose[a]=direction_matrix(a,start,elbow);pose[b]=direction_matrix(b,elbow,end)
    pose[c]=pose[b]@rest[b].inverted()@rest[c];pose[c].translation=end
    return max(0,actual-l1-l2)

def grip(kind,t,duration):
    if kind in ('slash','sweep','thrust'):
        markers=PHASES[kind];wind=markers['active'];active=markers['recovery']-wind;recovery=markers['end']-markers['recovery']
        reach,half={'slash':(1.8,math.pi/3),'sweep':(2.05,math.pi*.58),'thrust':(2.75,math.pi/9)}[kind]
        if t<wind:phase=0;p=t/wind
        elif t<wind+active:phase=1;p=(t-wind)/active
        else:phase=2;p=min(1,(t-wind-active)/recovery)
        if kind=='thrust':
            r=(2.05-.5*p) if phase==0 else ((1.55+1.2*p) if phase==1 else (2.75-.7*p))
            return Vector((0,1.08,-(r-1.70)+.08)),0,phase,p
        angle=(.15+(-half-.15)*p) if phase==0 else ((-half+2*half*p) if phase==1 else (half*(1-p)+.15*p))
        return Vector((-.27*math.sin(angle),1.08,-.27*math.cos(angle))),angle,phase,p
    return Vector((0,1.08,-.27)),0,0,0

# These are independent authoring beats, not DuelAction.profile timings.
DURATIONS={name:1.0 for name in ('slash','sweep','thrust','guard','dodge')}
PHASES={name:{'windup':0,'active':.4,'recovery':.6,'end':1.0} for name in ('slash','sweep','thrust')}
PHASES['dodge']={'windup':0,'active':.1,'recovery':.6,'end':1.0}
max_grip={}
def custom_pose(kind,t):
    pose={n:m.copy() for n,m in rest.items()}
    target,angle,phase,p=grip(kind,t,DURATIONS[kind])
    lean=.08;yaw=0;forward=0;down=0
    if kind in ('slash','sweep'):
        yaw=angle*.95;lean=.11;down=.025
    elif kind=='thrust':
        extension=max(0,(-target.z-.27)/.70)
        lean=.08+extension*.78;forward=.36*extension;down=.12*extension
    elif kind=='guard':lean=.25;down=.025
    elif kind=='dodge':
        k=math.sin(math.pi*min(1,t/DURATIONS['dodge']));lean=.08;down=.13*k
    pelvis=rest['pelvis'].copy();pelvis.translation=Vector((0,-forward,.78-down))
    rot=Matrix.Rotation(yaw,4,'Z')@Matrix.Rotation(lean,4,'X')
    pelvis=Matrix.Translation(pelvis.translation)@rot@rest['pelvis'].to_quaternion().to_matrix().to_4x4();pose['pelvis']=pelvis
    for n in ('spine','chest','head','upper_arm.L','forearm.L','hand.L','upper_arm.R','forearm.R','hand.R','thigh.L','shin.L','foot.L','thigh.R','shin.R','foot.R'):
        parent=rig.data.bones[n].parent.name;pose[n]=pose[parent]@rest[parent].inverted()@rest[n]
    for side,sign in [('L',1),('R',-1)]:
        foot=rest['foot.'+side].copy();goal=foot.translation.copy()
        chain('thigh.'+side,'shin.'+side,'foot.'+side,goal,(sign*.1,-1,0),pose);pose['foot.'+side]=foot
    error=chain('upper_arm.R','forearm.R','hand.R',blender(target),(-1,.25,-.3),pose)
    max_grip[kind]=max(max_grip.get(kind,0),error)
    if kind=='guard':left=blender((-.18,1.05,-.44))
    else:
        # Relaxed shield follows the left hand and torso, without a second fixed grip target.
        local=Vector((.39,-.10,.98));left=pose['chest']@rest['chest'].inverted()@local
    chain('upper_arm.L','forearm.L','hand.L',left,(1,.2,-.3),pose)
    return pose

# Rigid, deliberately plain geometry is described once and shared by Blender and RealityKit.
proxies=[]
def proxy(name,bone,center,size,accent=False,rotation=None):
    local=rest[bone].inverted()@Matrix.Translation(Vector(center))
    if rotation is not None:local=rotation
    proxies.append({'name':name,'bone':names.index(bone),'position':va(local.translation),'rotation':qarray(local.to_quaternion()),'size':list(size),'accent':accent})
for b in bones:
    n=b.name
    if n=='ROOT':continue
    if n=='head':
        proxy('neck',n,(0,0,1.360),(.080,.080,.170),False)
        proxy('head',n,(0,-.005,1.570),(.210,.180,.280),True);continue
    if n.startswith('foot.'):
        x=b.head_local.x;proxy(n,n,(x,-.065,.061),(.125,.230,.122));continue
    width,depth={'pelvis':(.275,.180),'spine':(.290,.180),'chest':(.350,.210)}.get(n,(.105,.105) if n.startswith('thigh') else ((.085,.085) if n.startswith('shin') else ((.075,.075) if n.startswith('upper_arm') else ((.065,.065) if n.startswith('forearm') else (.075,.075)))))
    m=Matrix.Translation((0,b.length*.5,0))
    proxy(n,n,(0,0,0),(width,b.length,depth),n in ('pelvis','spine','chest'),m)

# Keep transforms in each original bone's local axes. Only ROOT carries Blender→game basis.
def locals_from_world(pose):
    result=[]
    for b in bones:
        local=pose[b.parent.name].inverted()@pose[b.name] if b.parent else C@pose[b.name]
        p,q,s=local.decompose();assert max(abs(v-1) for v in s)<1e-4
        result.append(va(p)+qarray(q.normalized()))
    return result

def ground(pose):
    low=0
    for proxy in proxies:
        if not proxy['name'].startswith('foot.'):continue
        b=bones[proxy['bone']].name
        m=pose[b]@Matrix.LocRotScale(Vector(proxy['position']),Quaternion((proxy['rotation'][3],*proxy['rotation'][:3])),Vector((1,1,1)))
        for x in (-.5,.5):
            for y in (-.5,.5):
                for z in (-.5,.5):low=min(low,(m@Vector((proxy['size'][0]*x,proxy['size'][1]*y,proxy['size'][2]*z))).z)
    if low<0:
        for n in pose:pose[n].translation.z-=low
    return -low

spec=json.loads(rig.data['lauder_party_animation']);meta={c['name']:c for c in spec['clips']}
clips={};samples_for_actions={};max_ground=0
for name in ('idle','walk','jog','run','backward','strafe_left','strafe_right','hit',*DURATIONS):
    if name in DURATIONS:duration=DURATIONS[name];loop=name=='guard';speed=0
    else:
        source=actions['party.'+name];duration=(source.frame_range[1]-source.frame_range[0])/120;loop=meta[name]['loop'];speed=meta[name]['nominal_speed']
    count=max(2,math.ceil(duration*30)+1);frames=[];poses=[]
    for index in range(count):
        t=duration*index/(count-1)
        if name in DURATIONS:pose=custom_pose(name,t)
        else:
            set_action(actions['party.'+name],1+t*120);pose={p.name:p.matrix.copy() for p in rig.pose.bones}
        max_ground=max(max_ground,ground(pose))
        frames.append(locals_from_world(pose));poses.append(pose)
    clip={'duration':round(duration,6),'loop':loop,'nominalSpeed':round(speed,6),'eventStart':meta[name].get('event_start',0) if name in meta else 0,'frames':frames}
    if name in ('slash','sweep','thrust','dodge'):
        clip['phases']=PHASES[name]
    clips[name]=clip
    samples_for_actions[name]=poses

# Real Blender Actions hold the sampled derivative poses and are directly editable.
local_actions={}
for name,clip in clips.items():
    a=bpy.data.actions.new('mannequin.'+name);slot=a.slots.new('OBJECT','Mannequin');bag=a.layers.new('Pose samples').strips.new(type='KEYFRAME').channelbag(slot,ensure=True)
    channels={}
    for index,pose in enumerate(samples_for_actions[name]):
        frame=1+120*clip['duration']*index/(len(clip['frames'])-1)
        for b in bones:
            basis=rest[b.name].inverted()@rest[b.parent.name]@pose[b.parent.name].inverted()@pose[b.name] if b.parent else rest[b.name].inverted()@pose[b.name]
            p,q,s=basis.decompose()
            for suffix,values in [('location',p),('rotation_quaternion',q)]:
                for axis,value in enumerate(values):channels.setdefault((f'pose.bones["{b.name}"].{suffix}',axis),[]).extend((frame,float(value)))
    for (path,axis),values in channels.items():
        f=bag.fcurves.new(data_path=path,index=axis);f.keyframe_points.add(len(values)//2);f.keyframe_points.foreach_set('co',values)
        for k in f.keyframe_points:k.interpolation='LINEAR'
    a.use_fake_user=True;local_actions[name]=a

# Bone-local box meshes. No external mesh, skin weights, detailed fingers or armature modifiers.
def material(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*color,1);n.inputs['Roughness'].default_value=.9;return m
bodymat=material('Mannequin plain teal',(0.13,.40,.42));limbmat=material('Mannequin plain charcoal',(.12,.15,.17))
for d in proxies:
    bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object;o.name='Mannequin / '+d['name'];o.dimensions=d['size'];bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.parent=rig;o.parent_type='BONE';o.parent_bone=bones[d['bone']].name
    # Bone parenting's default tail offset is cancelled explicitly.
    o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=Matrix.LocRotScale(Vector(d['position'])-Vector((0,bones[d['bone']].length,0)),Quaternion((d['rotation'][3],*d['rotation'][:3])),Vector((1,1,1)))
    o.data.materials.append(bodymat if d['accent'] else limbmat)

scene=bpy.context.scene;scene.render.fps=120;scene.frame_start=1;scene.frame_end=round(clips['slash']['duration']*120)+1
set_action(local_actions['slash'],1)
scene['scope']='Original17-bone plain mannequin; project locomotion plus new melee poses; no gameplay authority'
scene['source_sha256']=SOURCE_SHA
scene['mannequin_clips']=json.dumps({n:{'action':a.name,'duration':clips[n]['duration']} for n,a in local_actions.items()},sort_keys=True)
bpy.context.preferences.filepaths.save_version=0
# Only relative external source paths; no private resource output path in saved file.
for lib in bpy.data.libraries:lib.filepath=str(SOURCE)
scene.render.filepath='//'
# The saved Blender file owns export metadata; the exporter resamples the actual Actions.
scene['mannequin_proxies']=json.dumps(proxies,sort_keys=True,separators=(',',':'))
scene['mannequin_clip_specs']=json.dumps({n:{k:v for k,v in c.items() if k!='frames'} for n,c in clips.items()},sort_keys=True,separators=(',',':'))
scene['mannequin_grip_audit']=json.dumps(max_grip,sort_keys=True)
scene['mannequin_source_grounding_adjustment']=max_ground
sys.path.insert(0,str(ROOT/'blender/extensions'))
from lauder_levels.common import forget_local_paths
forget_local_paths(str(HERE/'mannequin.blend'))
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'mannequin.blend'),relative_remap=False,compress=True)
import runpy
runpy.run_path(str(HERE/'export.py'),run_name='__main__')
