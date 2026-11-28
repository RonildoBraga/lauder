"""Render authoring-only review media from the saved source, without saving it."""
import bpy,hashlib,json,math,sys
from pathlib import Path
from mathutils import Vector,Matrix
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
OUT=ROOT/'.local/mannequin/preview';OUT.mkdir(parents=True,exist_ok=True)
source=HERE/'mannequin.blend';before=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
s=bpy.context.scene;rig=next(o for o in s.objects if o.type=='ARMATURE')
C=Matrix(((-1,0,0,0),(0,0,1,0),(0,1,0,0),(0,0,0,1)))
def material(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*color,1);n.inputs['Roughness'].default_value=.95;return m
floor_mat=material('Review floor',(.20,.23,.25));weapon_mat=material('Review blade',(.55,.58,.57));shield_mat=material('Review shield',(.30,.32,.34))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.001));floor=bpy.context.object;floor.data.materials.append(floor_mat)
bpy.ops.object.camera_add(location=(3.2,-5.0,2.6));camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,.84))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=2.65;s.camera=camera
bpy.ops.object.light_add(type='AREA',location=(2,-3,4));light=bpy.context.object;light.data.energy=450;light.data.shape='DISK';light.data.size=4;light.rotation_euler=(Vector((0,0,.8))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.light_add(type='SUN',location=(-2,2,5));light=bpy.context.object;light.data.energy=1.6;light.rotation_euler=(math.radians(25),math.radians(-25),math.radians(-25))
world=bpy.data.worlds.new('Review neutral world');world.use_nodes=True;world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.3,.3,.3,1);world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.4;s.world=world
s.render.engine='BLENDER_EEVEE';s.render.resolution_x=960;s.render.resolution_y=960;s.render.resolution_percentage=100;s.eevee.taa_render_samples=16;s.render.image_settings.file_format='PNG';s.view_settings.view_transform='Standard';s.view_settings.look='None'
def cube(name,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat);return o
sword=cube('Review sword',(.045,1.0,.035),weapon_mat)
shield=cube('Review shield',(.42,.07,.50),shield_mat)
proxies=json.loads(s['mannequin_proxies']);specs=json.loads(s['mannequin_clip_specs'])
font=bpy.data.curves.new('Review title','FONT');font.body='MANNEQUIN';font.size=.065
textmat=bpy.data.materials.new('Review text');textmat.use_nodes=True;n=textmat.node_tree.nodes;n.clear();e=n.new('ShaderNodeEmission');e.inputs['Color'].default_value=(.8,.8,.75,1);o=n.new('ShaderNodeOutputMaterial');textmat.node_tree.links.new(e.outputs[0],o.inputs['Surface']);font.materials.append(textmat)
title=bpy.data.objects.new('Review title',font);s.collection.objects.link(title);title.parent=camera;title.location=(-1.15,1.13,-5)
worst_proxy=0;maximum_lift=0

def render_pose(name,t,path):
    global worst_proxy,maximum_lift
    rig.location.z=0
    action=bpy.data.actions['mannequin.'+name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    at=1+t*120;s.frame_set(math.floor(at),subframe=at%1);bpy.context.view_layer.update()
    minimum=min((o.matrix_world@v.co).z for o in s.objects if o.type=='MESH' and o.name.startswith('Mannequin / foot.') for v in o.data.vertices)
    lift=max(0,-minimum);rig.location.z=lift;bpy.context.view_layer.update();maximum_lift=max(maximum_lift,lift)
    for proxy in proxies:
        o=bpy.data.objects['Mannequin / '+proxy['name']];bone=rig.pose.bones[rig.data.bones[proxy['bone']].name]
        expected=rig.matrix_world@bone.matrix@Vector(proxy['position']);worst_proxy=max(worst_proxy,(o.matrix_world.translation-expected).length)
    sword.hide_render=name not in ('slash','sweep','thrust','guard')
    shield.hide_render=name!='guard'
    if name in ('slash','sweep','thrust'):
        markers=specs[name]['phases'];wind=markers['active'];active=markers['recovery']-wind;recovery=markers['end']-markers['recovery']
        reach,half={'slash':(1.8,math.pi/3),'sweep':(2.05,math.pi*.58),'thrust':(2.75,math.pi/9)}[name]
        phase=0 if t<wind else (1 if t<wind+active else 2);p=t/wind if phase==0 else ((t-wind)/active if phase==1 else min(1,(t-wind-active)/recovery))
        angle=0 if name=='thrust' else ((.15+(-half-.15)*p) if phase==0 else ((-half+2*half*p) if phase==1 else (half*(1-p)+.15*p)))
        tip=(2.05-.5*p if phase==0 else (1.55+1.2*p if phase==1 else 2.75-.7*p)) if name=='thrust' else reach
        length=1.70 if name=='thrust' else reach-.35;hilt=tip-length if name=='thrust' else .35
    else:angle=0;length=1.45;hilt=.35
    root=Matrix.Translation(Vector((0,0,1.08)))@Matrix.Rotation(angle,4,'Z')
    sword.matrix_world=root@Matrix.Translation((0,-hilt-length*.5,0))@Matrix.Diagonal((1,length,1,1))
    shield.location=Vector((.18,-.52,1.05))
    title.data.body='MANNEQUIN / '+name.upper()+' / AUTHORED SOURCE'
    s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
for name,t in [('idle',.7),('walk',.22),('run',.25),('guard',.4),('slash',.50),('sweep',.50),('thrust',.60),('dodge',.50),('hit',.18)]:
    render_pose(name,t,OUT/f'{name}.png')
if '--reel' in sys.argv:
    reel=OUT/'reel';reel.mkdir(exist_ok=True);counter=0
    for name,repeat in [('idle',1),('walk',2),('run',2),('slash',1),('guard',1),('dodge',1),('hit',1),('sweep',1),('thrust',1)]:
        duration=specs[name]['duration'];count=max(2,math.ceil(duration*30))
        for cycle in range(repeat):
            for index in range(count):
                render_pose(name,duration*index/count,reel/f'{counter:04d}.png');counter+=1
    (OUT/'reel.json').write_text(json.dumps({'frames':counter,'fps':30,'width':960,'height':960,'duration':counter/30,'sourceSHA256':before},indent=2)+'\n')
assert worst_proxy<.00001,('Bone proxy parenting diverges from runtime descriptor',worst_proxy)
assert hashlib.sha256(source.read_bytes()).hexdigest()==before
(OUT/'audit.json').write_text(json.dumps({'sourceSHA256':before,'maximumProxyPositionError':worst_proxy,'sourceUnchanged':True,'maximumReviewFloorLift':maximum_lift},indent=2)+'\n')
print('maximum bone proxy error',worst_proxy)
