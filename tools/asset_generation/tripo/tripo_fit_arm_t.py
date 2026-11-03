# tripo_fit_arm_t.py — the Director's two arm edits of 2026-11-03, made in the T-pose working file and brought back by `tripo_fit_from_tpose.py` (ACTOR D96).
# (1) The shirt's armpit: the sleeve's UNDERSIDE (vertex normal pointing down, below the arm's axis, within ~0.13-0.28 m of the chest) is lowered by LIFT and pushed PUSH toward the ribs, clamped on the torso's own wall so it never enters it
#     (an unclamped push put the sleeve cap's front vertices through the chest and left shards, seen 2026-11-03). (2) The arms are lowered by DROP as ONE smooth field (the shirt's arm-bone weight averaged over a ball of radius R, applied to shirt,
#     hands and coat alike: per-mesh weights tore the coat from the shirt at the shoulder). Env: DROP (m, required), DX (0 female, 0.02 male: the male's torso is wider), PUSH (0.05), LIFT (0.025), R (0.035; 0.08 used). Works IN PLACE on a T file.
#     Chain: tripo_fit_tpose.py -> tripo_coat_fit_round.py -> this -> tripo_fit_from_tpose.py. Per figure (2026-11-03, judged on the posed video): FEMALE DROP 0.01, R 0.08; MALE DROP 0.015, DX 0.02, R 0 (the shirt and hands drop by their OWN arm weight, the coat follows the shirt's nearest vertices within RC 0.015: a smoothed field left knobs on the male's shoulder caps). A top-only extra drop of the cap was tried and crumpled the arm: not kept.
# T file: (1) the shirt's armpit closed along the sleeve's UNDERSIDE (normal-weighted, clamped so it never enters the torso), (2) one smooth drop field for shirt / hands / coat
import bpy, os, numpy as np
from mathutils import kdtree, Vector
DX=float(os.environ.get("DX","0.0")); DROP=float(os.environ["DROP"]); R=float(os.environ.get("R","0.035"))
PUSH=float(os.environ.get("PUSH","0.05")); LIFT=float(os.environ.get("LIFT","0.025"))
def ss(a,b,x):
    t=np.clip((x-a)/(b-a),0,1); return t*t*(3-2*t)
ARM=("mixamorig:LeftArm","mixamorig:LeftForeArm","mixamorig:LeftHand","mixamorig:RightArm","mixamorig:RightForeArm","mixamorig:RightHand")
def own_a(o):
    names={g.index:g.name for g in o.vertex_groups}
    return np.array([min(sum(g.weight for g in v.groups if names[g.group] in ARM),1.0) for v in o.data.vertices])
objs={n:bpy.data.objects[n] for n in ("Outfit_Shirt","Body_Hands","Outfit_Coat.001")}
a_own={n:own_a(o) for n,o in objs.items()}
sh=objs["Outfit_Shirt"]; me=sh.data; M=sh.matrix_world; Mi=M.inverted()
P=np.array([(M@v.co)[:] for v in me.vertices]); N=np.array([(M.to_3x3()@v.normal)[:] for v in me.vertices])
# the torso's outer wall: shirt vertices that are not the arm's, near the armpit, indexed by (y,z)
tor=np.nonzero((a_own["Outfit_Shirt"]<0.05)&(np.abs(P[:,0])<0.2)&(P[:,2]>0.6)&(P[:,2]<0.9))[0]
kd2=kdtree.KDTree(len(tor)); [kd2.insert((P[i,1],P[i,2],0.0),k) for k,i in enumerate(tor)]; kd2.balance()
def wall(y,z):
    hits=kd2.find_range((y,z,0.0),0.02)
    return max((abs(P[tor[k],0]) for _,k,_ in hits),default=None)
arm_b=bpy.data.objects['Armature']; ZC=(arm_b.matrix_world@arm_b.data.bones['mixamorig:LeftArm'].head_local).z
new=P.copy()
for i in range(len(P)):
    x,y,z=P[i]; ax=abs(x); sx=1.0 if x>0 else -1.0
    fx=float(ss(0.28+DX,0.13+DX,ax)); u=float(ss(ZC+0.015,ZC-0.03,z))   # the sleeve's lower half (as the approved T had it); the torso-wall clamp below keeps it out of the chest
    if fx<=0 or u<=0 or ax<0.10+DX: continue
    nx=ax-PUSH*u*fx
    w=wall(y,z)
    if w is not None and ax>w: nx=max(nx,w+0.003)       # lands on the torso's wall, never inside it
    new[i,0]=sx*nx; new[i,2]=z-(LIFT)*u*fx
for i,v in enumerate(me.vertices): v.co=Mi@Vector(new[i])
me.update()
# the drop field
a_sh=a_own["Outfit_Shirt"]; shp=[M@v.co for v in me.vertices]
kd=kdtree.KDTree(len(shp)); [kd.insert(p,i) for i,p in enumerate(shp)]; kd.balance()
RF=R if R>0 else float(os.environ.get("RC","0.015"))   # R=0: the shirt and the hands drop by their own arm weight, the coat follows the shirt's nearest vertices
def field(p):
    hits=kd.find_range(p,RF) or [kd.find(p)]
    return float(np.mean([a_sh[i] for _,i,_ in hits]))
for n,o in objs.items():
    for v in o.data.vertices:
        w=o.matrix_world@v.co; f=(1.0 if n=="Body_Hands" else (a_own[n][v.index] if (R<=0 and n!="Outfit_Coat.001") else field(w)))
        w.z-=DROP*f; v.co=o.matrix_world.inverted()@w
    o.data.update()
bpy.ops.wm.save_mainfile()
