"""Directional authoring constraints for the clean dress, with no nearest-normal projection."""
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri
SAMPLES=tuple((i/4,j/4,(4-i-j)/4)for i in range(5)for j in range(5-i))

def smooth(a,b,x):
 t=max(0.,min(1.,(x-a)/(b-a)));return t*t*(3-2*t)

def barycentric(point,tri):
 a,b,c=tri;v0=b-a;v1=c-a;v2=point-a;aa=v0.dot(v0);bb=v0.dot(v1);cc=v1.dot(v1);dd=v2.dot(v0);ee=v2.dot(v1);den=aa*cc-bb*bb
 if abs(den)<1e-14:return None
 v=(cc*dd-bb*ee)/den;w=(aa*ee-bb*dd)/den;return(1-v-w,v,w)

def triangle_witnesses(cloth,body):
 """Strict finite edge/triangle crossings, expressed on the garment triangle."""
 points=[]
 for edges,target in [(body,cloth),(cloth,body)]:
  normal=(target[1]-target[0]).cross(target[2]-target[0]);length=normal.length
  if length<1e-12:continue
  normal/=length
  for i,origin in enumerate(edges):
   end=edges[(i+1)%3];ray=end-origin;length=ray.length
   if length<1e-8:continue
   d0=(origin-target[0]).dot(normal);d1=(end-target[0]).dot(normal)
   if d0*d1>=0 or min(abs(d0),abs(d1))<1e-6:continue
   direction=ray/length;hit=intersect_ray_tri(*target,direction,origin,True)
   if hit is None or not 1e-6<(hit-origin).dot(direction)<length-1e-6:continue
   bc=barycentric(hit,cloth)
   if bc and min(bc)>-1e-6:points.append(bc)
 return points

def clear_dress(points,triangles,body_points,body_faces,margin=.010,iterations=8):
 """Conservative fixed-outward offset with vertex, edge and face constraints.

 Every source point retains its Z, its fixed pelvis-frame radial direction and
 original radial separation. Local offsets spread coherently over the panel.
 The top facing is an intentional dress/torso overlap; sample Z >= .98 is not
 treated as a leg constraint. Returned points remain in pelvis/bind space.
 """
 assert all(len(f)==3 for f in triangles)and all(len(f)==3 for f in body_faces),'Pass actual evaluated triangles'
 base=[Vector(p)for p in points];directions=[];masks=[]
 for p in base:
  d=Vector((p.x,p.y-.025,0));d.normalize();directions.append(d);masks.append(1-smooth(.97,1.04,p.z))
 graph=[{}for p in base]
 for face in triangles:
  for a,b in zip(face,(face[1],face[2],face[0])):
   length=(base[a]-base[b]).length;graph[a][b]=length;graph[b][a]=length
 tree=BVHTree.FromPolygons([Vector(v)for v in body_points],body_faces)
 offset=[0.]*len(base);history=[]
 for step in range(iterations):
  posed=[p+d*o for p,d,o in zip(base,directions,offset)];wanted=offset[:];max_need=0.;constraints=0
  garment_tree=BVHTree.FromPolygons(posed,triangles,all_triangles=True);extra={};witness_pairs=0
  for ci,bi in garment_tree.overlap(tree):
   cloth=[posed[i]for i in triangles[ci]];body=[Vector(body_points[i])for i in body_faces[bi]];witness=triangle_witnesses(cloth,body)
   if witness:extra.setdefault(ci,[]).extend(witness);witness_pairs+=1
  for fi,face in enumerate(triangles):
   samples=list(SAMPLES)+extra.get(fi,[])
   for sample_index,weights in enumerate(samples):
    p=sum((posed[i]*w for i,w in zip(face,weights)),Vector())
    if p.z>=.98:continue
    d=sum((directions[i]*w for i,w in zip(face,weights)),Vector());d.normalize()
    denom=sum(w*masks[i]*directions[i].dot(d)for i,w in zip(face,weights))
    if denom<.05:continue
    # Four millimetres of directional footprint expansion protects unsampled skin facets.
    side=Vector((-d.y,d.x,0));need=0.
    for sx,sz in [(0,0),(-.004,0),(.004,0),(0,-.004),(0,.004)]:
     q=p+side*sx+Vector((0,0,sz));hit,normal,idx,distance=tree.ray_cast(q+d*2.,-d,4.)
     if hit is not None:need=max(need,(hit-q).dot(d)+margin)
    if sample_index>=len(SAMPLES):need=max(need,.005)
    if need<=.00025:continue
    constraints+=1;max_need=max(max_need,need)
    for i in face:wanted[i]=max(wanted[i],offset[i]+need/denom*masks[i])
  # A shared Lipschitz offset rounds the skirt coherently instead of moving isolated points.
  for spread in range(5):
   expanded=wanted[:]
   for i,neighbours in enumerate(graph):
    if masks[i]<.001:continue
    expanded[i]=max(wanted[i],max((wanted[j]-.8*l for j,l in neighbours.items()),default=0.)*masks[i])
   wanted=expanded
  offset=wanted;history.append({'iteration':step,'constraint_count':constraints,'max_required_m':max_need,'max_offset_m':max(offset),'strict_witness_pairs':witness_pairs})
  if max_need<.0005 and witness_pairs==0:break
 result=[p+d*o for p,d,o in zip(base,directions,offset)]
 return result,offset,{'iterations':history,'max_offset_m':max(offset),'fixed_direction':True,'waist_overlap_z':.98,'margin_m':margin}
