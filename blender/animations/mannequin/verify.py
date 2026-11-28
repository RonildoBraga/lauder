"""Portable generated-pose/provenance checks. Requires Python standard library only."""
import hashlib,json,math
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]

def add(a,b):return [x+y for x,y in zip(a,b)]
def sub(a,b):return [x-y for x,y in zip(a,b)]
def scale(a,s):return [x*s for x in a]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def length(a):return math.sqrt(dot(a,a))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def mul(a,b):
    v=add(add(scale(b[:3],a[3]),scale(a[:3],b[3])),cross(a[:3],b[:3]))
    return v+[a[3]*b[3]-dot(a[:3],b[:3])]
def rot(q,p):return add(p,scale(cross(q[:3],add(cross(q[:3],p),scale(p,q[3]))),2))
def compose(a,b):return add(a[:3],rot(a[3:],b[:3]))+mul(a[3:],b[3:])
def worlds(data,frame):
    out=[]
    for bone,pose in zip(data['bones'],frame):out.append(pose if bone['parent']<0 else compose(out[bone['parent']],pose))
    return out

def verify():
    manifest=json.loads((HERE/'manifest.json').read_text());datafile=ROOT/'apple/sources/content/mannequin.json'
    for filename,key in [('original-party.blend','sourceSHA256'),('mannequin.blend','blendSHA256')]:
        assert hashlib.sha256((HERE/filename).read_bytes()).hexdigest()==manifest[key],filename+' hash drift'
    assert hashlib.sha256(datafile.read_bytes()).hexdigest()==manifest['jsonSHA256'],'JSON hash drift'
    for name,expected in manifest['tools'].items():
        assert hashlib.sha256((HERE/name).read_bytes()).hexdigest()==expected,name+' generator hash drift'
    data=json.loads(datafile.read_text());assert data['version']==1 and data['fps']==30
    names=[b['name'] for b in data['bones']]
    assert len(names)==len(set(names))==17 and names[0]=='ROOT'
    assert data['sourceSHA256']==manifest['sourceSHA256']=='7abc47d922621f1685522083afee445927f3625f86b2c19eb7077f437703a4b8'
    assert {'idle','walk','jog','run','backward','strafe_left','strafe_right','hit','slash','sweep','thrust','guard','dodge'}==set(data['clips'])
    assert 'aim' not in data['clips'] and 'fire' not in data['clips']
    for i,b in enumerate(data['bones']):assert b['parent']<i and b['parent']>=-1 and b['length']>0
    for p in data['proxies']:
        assert 0<=p['bone']<17 and len(p['size'])==3 and all(v>0 and math.isfinite(v) for v in p['size'])
    worst_ground=0;worst_gap=0;poses=0;loop_gap=0;max_guard_gap=0
    for name,clip in data['clips'].items():
        assert clip['duration']>0 and len(clip['frames'])>=2
        assert 0<=clip['eventStart']<=clip['duration']
        if name in ('slash','sweep','thrust','dodge'):
            p=clip['phases'];assert p['windup']==0 and p['windup']<p['active']<p['recovery']<p['end']==clip['duration']
        for frame in clip['frames']:
            poses+=1;assert len(frame)==17
            for bone in frame:
                assert len(bone)==7 and all(math.isfinite(x) for x in bone)
                assert abs(length(bone[3:])-1)<.000002
            world=worlds(data,frame)
            for child in ('forearm.L','forearm.R','hand.L','hand.R','shin.L','shin.R','foot.L','foot.R'):
                index=names.index(child);parent=data['bones'][index]['parent']
                end=add(world[parent][:3],rot(world[parent][3:],[0,data['bones'][parent]['length'],0]))
                worst_gap=max(worst_gap,length(sub(end,world[index][:3])))
            for proxy in data['proxies']:
                if not proxy['name'].startswith('foot.'):continue
                trans=compose(world[proxy['bone']],proxy['position']+proxy['rotation'])
                for x in (-.5,.5):
                    for y in (-.5,.5):
                        for z in (-.5,.5):
                            point=add(trans[:3],rot(trans[3:],[proxy['size'][0]*x,proxy['size'][1]*y,proxy['size'][2]*z]))
                            worst_ground=min(worst_ground,point[1])
            if name in ('walk','backward','strafe_left','strafe_right','run'):
                start=world[names.index('upper_arm.L')][:3];target=[-.18,1.05,-.44]
                max_guard_gap=max(max_guard_gap,length(sub(target,start))-data['bones'][names.index('upper_arm.L')]['length']-data['bones'][names.index('forearm.L')]['length'])
        if clip['loop']:
            first,last=clip['frames'][0],clip['frames'][-1]
            for a,b in zip(first,last):
                loop_gap=max(loop_gap,length(sub(a[:3],b[:3])),1-abs(dot(a[3:],b[3:])))
    assert worst_gap<.00001,('joint gap',worst_gap)
    assert worst_ground>-.00001,('below floor',worst_ground)
    assert loop_gap<.00001,('loop mismatch',loop_gap)
    result=dict(poses=poses,bones=17,clips=len(data['clips']),maximumJointGap=worst_gap,minimumFootY=worst_ground,maximumLoopDifference=loop_gap,unbracedGuardArmGapDuringLocomotion=max_guard_gap)
    print(json.dumps(result,sort_keys=True));return result
if __name__=='__main__':verify()
