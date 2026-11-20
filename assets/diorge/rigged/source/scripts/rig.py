# Build armature + skin + animations for one enemy and export GLB.
# usage: blender -b <name>_prep.blend -P rig.py -- <name> <out_dir> <scratch_dir>
import bpy, sys, os, math, json, statistics
from mathutils import Vector, Quaternion, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
name, out_dir, scratch = args[:3]
out_name = args[3] if len(args) > 3 else name  # e.g. jabuti -> tartaruga_paladina (hero)
sys.path.insert(0, scratch)
from landmarks import MODELS
cfg = MODELS[name]
FPS = 30

ob = bpy.data.objects[name]
# landmarks were read off renders of the original model: ignore parts moved by prep (groups "rigid:<bone>")
pre_rigid = {vg.index: vg.name[6:] for vg in ob.vertex_groups if vg.name.startswith("rigid:")}
verts = [v.co.copy() for v in ob.data.vertices if not any(g.group in pre_rigid for g in v.groups)]
mn = Vector([min(v[i] for v in verts) for i in range(3)])
mx = Vector([max(v[i] for v in verts) for i in range(3)])
c = (mn + mx) / 2
K = max(mx - mn) * 1.1 / 512

def fx(px): return c.x + (px - 256) * K
def fz(py): return c.z - (py - 256) * K
def sy(px): return c.y + (px - 256) * K   # side render: image right = +Y

def depth(x, z, r=0.03):
    ys = [v.y for v in verts if abs(v.x - x) < r and abs(v.z - z) < r]
    return statistics.median(ys) if ys else c.y

def P(p):  # front landmark -> 3D point with auto depth
    x, z = fx(p[0]), fz(p[1])
    return Vector((x, depth(x, z), z))

# ---------- armature ----------
bpy.ops.object.armature_add(location=(0, 0, 0))
arm = bpy.context.object; arm.name = arm.data.name = f"{name}_rig"
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
eb.remove(eb[0])

def bone(n, h, t, parent=None, connect=False):
    b = eb.new(n); b.head = h; b.tail = t; b.roll = 0
    if parent: b.parent = eb[parent]; b.use_connect = connect
    return b

sp = [P(p) for p in cfg["spine"]]
top = P(cfg["head_top"])
bone("root", Vector((0, 0, 0)), Vector((0, 0.15, 0)))
bone("hips", sp[0], sp[1], "root")
bone("spine", sp[1], sp[2], "hips", True)
bone("chest", sp[2], sp[3], "spine", True)
if "neck_mid" in cfg:
    nm = P(cfg["neck_mid"])
    bone("neck", sp[3], nm, "chest", True); bone("neck2", nm, sp[4], "neck", True); hp = "neck2"
else:
    bone("neck", sp[3], sp[4], "chest", True); hp = "neck"
bone("head", sp[4], Vector((sp[4].x, sp[4].y, top.z)), hp, True)
if "beak" in cfg:
    bk = [P(p) for p in cfg["beak"]]
    bone("beak", bk[0], bk[1], "head"); bone("beak2", bk[1], bk[2], "beak", True)

for s in ("L", "R"):
    a = [P(p) for p in cfg[f"arm.{s}"]]
    tip = P(cfg[f"hand_tip.{s}"])
    bone(f"upper_arm.{s}", a[0], a[1], "chest")
    bone(f"forearm.{s}", a[1], a[2], f"upper_arm.{s}", True)
    bone(f"hand.{s}", a[2], tip, f"forearm.{s}", True)
    l = [P(p) for p in cfg[f"leg.{s}"]]
    bone(f"thigh.{s}", l[0], l[1], "hips")
    bone(f"shin.{s}", l[1], l[2], f"thigh.{s}", True)
    near = [v for v in verts if abs(v.x - l[2].x) < 0.04 and v.z < 0.05]
    toe_y = min(v.y for v in near) + 0.02 if near else l[2].y - 0.06
    bone(f"foot.{s}", l[2], Vector((l[2].x, toe_y, 0.015)), f"shin.{s}", True)

tails = []
if "tail_side" in cfg:
    pts = [Vector((c.x, sy(px), fz(py))) for px, py in cfg["tail_side"]]
    for i in range(len(pts) - 1):
        n = f"tail{i+1}"
        bone(n, pts[i], pts[i + 1], "hips" if i == 0 else tails[-1], i > 0); tails.append(n)

# consistent rolls so local axes are predictable (we convert world rotations anyway)
for b in eb:
    b.select = True
bpy.ops.armature.calculate_roll(type="GLOBAL_POS_X")
bpy.ops.object.mode_set(mode="OBJECT")
arm.data.bones["root"].use_deform = False  # root lies on the floor: auto-weights would pin the feet to it

# ---------- rigid regions (weapons, quivers, capes) -> tagged "rigid:<bone>", weighted 100% after skinning ----------
# Weapons are welded to the body in these meshes; a rigid weapon next to a skinned hand/foot stretches the
# shared edges, so weapon faces are split off (a hairline seam instead of a smear).
segs = [(b.head_local, b.tail_local, 0.045 if b.name.startswith(("upper_arm", "forearm")) else 0.03)
        for b in arm.data.bones
        if b.name.startswith(("upper_arm", "forearm", "shin", "foot"))]  # sleeves, and feet under low weapons
def near_limb(p):
    for h, t, r in segs:
        d = t - h; u = max(0, min(1, (p - h).dot(d) / d.length_squared))
        if (p - (h + d * u)).length < r: return True
    return False
import bmesh
boxes_by_bone = {}  # several boxes for one bone act as one region (a single split, no seam between boxes)
for bn, xr, zr, yr in cfg.get("rigid", []):
    x0, x1 = sorted((fx(xr[0]), fx(xr[1]))); z0, z1 = sorted((fz(zr[0]), fz(zr[1])))
    y0, y1 = (sorted((sy(yr[0]), sy(yr[1]))) if yr else (-9, 9))
    boxes_by_bone.setdefault(bn, []).append((x0, x1, y0, y1, z0, z1))
for bn, boxes in boxes_by_bone.items():
    vg = ob.vertex_groups.get("rigid:" + bn) or ob.vertex_groups.new(name="rigid:" + bn)
    pre_rigid[vg.index] = bn
    bm = bmesh.new(); bm.from_mesh(ob.data)
    inside = {v for v in bm.verts
              if any(x0 <= v.co.x <= x1 and y0 <= v.co.y <= y1 and z0 <= v.co.z <= z1
                     for x0, x1, y0, y1, z0, z1 in boxes)
              and not near_limb(v.co)}
    faces = [f for f in bm.faces if all(v in inside for v in f.verts)]
    # drop small face islands (bits of sleeve/robe/coil caught by the box); keep the weapon-sized ones
    fset, clusters = set(faces), []
    while fset:
        st = [fset.pop()]; cl = []
        while st:
            f = st.pop(); cl.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g in fset: fset.remove(g); st.append(g)
        clusters.append(cl)
    if clusters:
        big = max(len(c) for c in clusters)
        faces = [f for c in clusters if len(c) >= 0.2 * big for f in c]
        inside = {v for f in faces for v in f.verts}
    split = bn.startswith("hand") or (bn == "chest" and cfg.get("split_quiver", True))  # capes (spine) stay welded
    if split:
        res = bmesh.ops.split(bm, geom=faces, use_only_faces=True)  # split replaces the faces: take the new ones
        faces = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
    dl = bm.verts.layers.deform.verify()
    tagged = {v for f in faces for v in f.verts} if split else inside
    for v in tagged: v[dl][vg.index] = 1.0
    bm.to_mesh(ob.data); bm.free()

# ---------- skinning ----------
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")

def unweighted():  # parts tagged "rigid:" get overwritten later, so they don't count
    return sum(1 for v in ob.data.vertices
               if not any(g.group in pre_rigid for g in v.groups)
               and sum(g.weight for g in v.groups if g.group not in pre_rigid) < 1e-4)

bad = unweighted(); method = "direct"; direct_bad = bad
# small holes are patched by nearest-bone below; only a mostly-failed solve goes to the voxel proxy
if bad > len(ob.data.vertices) * 0.10:
    # fallback: auto-weight a voxel-remeshed proxy, transfer to the real mesh
    method = "proxy"
    for vg in list(ob.vertex_groups):
        if not vg.name.startswith("rigid:"): ob.vertex_groups.remove(vg)
    proxy = ob.copy(); proxy.data = ob.data.copy(); proxy.modifiers.clear()
    bpy.context.collection.objects.link(proxy)
    rm = proxy.modifiers.new("rm", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = 0.006
    bpy.ops.object.select_all(action="DESELECT")
    proxy.select_set(True); bpy.context.view_layer.objects.active = proxy
    bpy.ops.object.modifier_apply(modifier="rm")
    proxy.parent = None
    proxy.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for vg in proxy.vertex_groups:
        if not vg.name.startswith("rigid:"): ob.vertex_groups.new(name=vg.name)
    dt = ob.modifiers.new("dt", "DATA_TRANSFER"); dt.object = proxy
    dt.use_vert_data = True; dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"; dt.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_move_to_index(modifier="dt", index=0)
    bpy.ops.object.modifier_apply(modifier="dt")
    bpy.data.objects.remove(proxy)
    bad = unweighted()

rigid_n = 0
# parts tagged by prep (e.g. a snapped sword) -> 100% their bone
for src_name in [vg.name for vg in ob.vertex_groups if vg.name.startswith("rigid:")]:
    src_vg = ob.vertex_groups[src_name]; bn = src_name[6:]
    ids = [v.index for v in ob.data.vertices if any(g.group == src_vg.index for g in v.groups)]
    tgt = ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)
    for vg in ob.vertex_groups:
        if vg != tgt: vg.remove(ids)
    tgt.add(ids, 1.0, "REPLACE"); rigid_n += len(ids)
    ob.vertex_groups.remove(src_vg)

# any still-unweighted verts -> nearest bone
bones = arm.data.bones
def nearest_bone(p):
    best, bd = None, 9
    for b in bones:
        if b.name == "root": continue
        h, t = b.head_local, b.tail_local; d = t - h
        u = max(0, min(1, (p - h).dot(d) / max(d.length_squared, 1e-9)))
        dist = (p - (h + d * u)).length
        if dist < bd: best, bd = b.name, dist
    return best
for v in ob.data.vertices:
    if sum(g.weight for g in v.groups) < 1e-4:
        n = nearest_bone(v.co); (ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n)).add([v.index], 1.0, "REPLACE")
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True); bpy.context.view_layer.objects.active = ob
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)

# ---------- animation ----------
arm.animation_data_create()
for pb in arm.pose.bones: pb.rotation_mode = "QUATERNION"
REST = {b.name: b.matrix_local.to_quaternion() for b in bones}

def rot(bn, axis, deg):
    """Rotation about an armature-space axis, expressed in the bone's local frame."""
    r = REST[bn]
    return r.inverted() @ Quaternion(Vector(axis), math.radians(deg)) @ r

def key(pose, frame):
    """pose: {bone: [(axis, deg), ...] or ('loc', Vector)}"""
    for pb in arm.pose.bones:
        spec = pose.get(pb.name, [])
        q = Quaternion()
        loc = Vector()
        for item in spec:
            if item[0] == "loc": loc = item[1]
            else: q = rot(pb.name, item[0], item[1]) @ q
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)
        if pb.name in ("root", "hips"):
            # bone-local translation from armature-space offset
            pb.location = REST[pb.name].inverted() @ loc
            pb.keyframe_insert("location", frame=frame, group=pb.name)

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
robe = cfg["robe"]; amp = cfg.get("walk_amp", 0.45 if robe else 1.0)
def tail_pose(phase):
    return {t: [(Z, 10 * math.sin(phase + i * 0.8))] for i, t in enumerate(tails)}

def new_action(n):
    act = bpy.data.actions.new(n); act.use_fake_user = True
    arm.animation_data.action = act
    return act

actions = []
# idle-loop: breathing, 2 s
new_action("idle-loop"); actions.append("idle-loop")
for f in range(0, 61, 10):
    ph = 2 * math.pi * f / 60
    p = {"chest": [(X, -2 * math.sin(ph))], "head": [(X, 2 * math.sin(ph + 0.6))],
         "hips": [("loc", Vector((0, 0, -0.004 * (1 - math.cos(ph)))))],
         "upper_arm.L": [(Y, -2 * math.sin(ph))], "upper_arm.R": [(Y, 2 * math.sin(ph))]}
    p.update(tail_pose(ph)); key(p, f)

# walk-loop: 1 s cycle
new_action("walk-loop"); actions.append("walk-loop")
for f in range(0, 31, 4 if False else 3):
    ph = 2 * math.pi * f / 30
    s = math.sin(ph)
    p = {"thigh.L": [(X, -28 * amp * s)], "thigh.R": [(X, 28 * amp * s)],
         "shin.L": [(X, 30 * amp * max(0, math.sin(ph + 1.4)))], "shin.R": [(X, 30 * amp * max(0, -math.sin(ph + 1.4)))],
         "foot.L": [(X, -10 * amp * s)], "foot.R": [(X, 10 * amp * s)],
         "upper_arm.L": [(X, 18 * s)], "upper_arm.R": [(X, -18 * s)],
         "hips": [("loc", Vector((0, 0, -0.012 * abs(math.cos(ph))))), (Z, 6 * s), (Y, 3 * s if robe else 0)],
         "chest": [(Z, -6 * s), (X, 4)], "head": [(Z, 3 * s)]}
    p.update(tail_pose(ph * 2)); key(p, f)

# attack
new_action("attack"); actions.append("attack")
style = cfg["style"]
W = cfg.get("weapon_side", "L"); O = "R" if W == "L" else "L"   # weapon arm / other arm
sgn = 1 if W == "L" else -1                                     # mirrors side-raise and chest twist
if style.startswith("melee"):
    seq = [(0, 0, 0, 0), (9, -140, 30, -10), (14, -35, 5, 18), (20, -30, 5, 15), (28, 0, 0, 0)]
    for f, sh, el, ch in seq:
        p = {f"upper_arm.{W}": [(X, sh)], f"forearm.{W}": [(X, -el)], "chest": [(X, ch), (Z, sgn * ch * 0.6)],
             "hips": [(X, ch * 0.3)], "head": [(X, -ch * 0.3)]}
        if style == "melee2":
            p[f"upper_arm.{O}"] = [(X, sh)]; p[f"forearm.{O}"] = [(X, -el)]
        p.update(tail_pose(f / 4)); key(p, f)
elif style == "shoot":  # model already aims a drawn bow: pull the string hand back, release, recoil
    for f, pull, rec in [(0, 0, 0), (8, 1, 0), (11, -0.3, 1), (18, 0, 0.4), (26, 0, 0)]:
        p = {f"upper_arm.{O}": [(Z, -sgn * 30 * pull)], f"forearm.{O}": [(Z, -sgn * 25 * pull)],
             f"upper_arm.{W}": [(X, 6 * rec)], "chest": [(X, -5 * rec), (Z, sgn * 4 * pull)], "head": [(X, 3 * rec)]}
        p.update(tail_pose(f / 4)); key(p, f)
elif style == "thrust":  # spear: pull back, then drive the arm forward so the shaft levels out, lunge
    # an upright spear tips BACK when the arm swings forward, so the wrist turns it the other way:
    # total shaft rotation = arm + forearm + hand (≈ +80° at the hit = tip forward, level)
    for f, sh, hd, ch, lg in [(0, 0, 0, 0, 0), (8, 15, 30, -8, 0), (13, -40, 140, 14, 1), (19, -35, 130, 12, 1),
                              (27, 0, 0, 0, 0)]:
        p = {f"upper_arm.{W}": [(X, sh)], f"forearm.{W}": [(X, sh * 0.5)], f"hand.{W}": [(X, hd)],
             "chest": [(X, ch), (Z, sgn * ch * 0.5)], "head": [(X, -ch * 0.4)],
             "thigh.L": [(X, -20 * lg)], "shin.L": [(X, 15 * lg)], "thigh.R": [(X, 10 * lg)],
             "hips": [("loc", Vector((0, -0.04 * lg, -0.02 * lg)))]}
        p.update(tail_pose(f / 4)); key(p, f)
elif style == "blow":  # blowgun held at the mouth: inhale (lean back), puff (snap forward), settle
    for f, k in [(0, 0), (8, -1), (12, 1), (20, 0.3), (26, 0)]:
        p = {"chest": [(X, 8 * k)], "spine": [(X, 3 * k)], "head": [(X, 4 * k)], "hips": [(X, 2 * k)]}
        p.update(tail_pose(f / 4)); key(p, f)
else:  # cast: raise weapon arm forward, thrust, hold, return
    seq = [(0, 0, 0, 0), (10, -75, -8, -6), (16, -95, 6, 10), (24, -90, 4, 8), (32, 0, 0, 0)]
    for f, sh, ch, hd in seq:
        # raise the weapon arm out to the side (about Y): staff/bow stays in the frontal plane and
        # leans over the head, no wrist twist (twisting the hand stretched the welded staff)
        p = {f"upper_arm.{W}": [(Y, sgn * sh * 0.6), (X, sh * 0.25)], f"upper_arm.{O}": [(X, sh * 0.35)],
             "chest": [(X, ch)], "head": [(X, -hd * 0.5)]}
        # TODO(human): per-character flavour for the cast/shoot pose (2-6 lines). Ideas: for
        # name == "guara", pull "upper_arm.R"/"forearm.R" back as if drawing the bowstring;
        # for "coruja"/"boto", raise the staff higher at the peak frame (f == 16).
        p.update(tail_pose(f / 4)); key(p, f)

# hurt
new_action("hurt"); actions.append("hurt")
for f, k in [(0, 0), (3, 1), (8, 0.5), (14, 0)]:
    p = {"chest": [(X, -14 * k)], "head": [(X, -18 * k)], "spine": [(X, -6 * k)],
         "upper_arm.L": [(Y, -10 * k)], "upper_arm.R": [(Y, 10 * k)],
         "root": [("loc", Vector((0, 0.04 * k, 0)))]}
    p.update(tail_pose(k * 3)); key(p, f)

# die (no loop): buckle, fall backwards, settle
new_action("die"); actions.append("die")
# falling backwards around the feet sends everything behind the centreline (cape, quiver) below z=0:
# lift by the torso's back depth so the body rests on the floor
back = max((v.y for v in verts if 0.4 < v.z < 0.9), default=0.05)
for f, kb, fall, sl in [(0, 0, 0, 0), (8, 1, 0, 0), (16, 1, -40, 0.03), (24, 0.6, -88, 0.06), (28, 0.6, -84, 0.06), (32, 0.6, -90, 0.06)]:
    p = {"thigh.L": [(X, -25 * kb)], "thigh.R": [(X, -20 * kb)], "shin.L": [(X, 40 * kb)], "shin.R": [(X, 35 * kb)],
         "chest": [(X, 15 * kb)], "head": [(X, 20 * kb)],
         "upper_arm.L": [(Y, -40 * (fall / -90))], "upper_arm.R": [(Y, 40 * (fall / -90))],
         "root": [(X, fall), ("loc", Vector((0, sl, (back + 0.01) * (fall / -90))))]}
    p.update({t: [(X, -30 * (fall / -90))] for t in tails}); key(p, f)

# ease every key; push each action to its own NLA track so the exporter sees them all
for act in bpy.data.actions:
    for fc in [fc for layer in getattr(act, "layers", []) for strip in layer.strips for cb in strip.channelbags for fc in cb.fcurves] or getattr(act, "fcurves", []):
        for kp in fc.keyframe_points: kp.interpolation = "BEZIER"
arm.animation_data.action = None
for n in actions:
    tr = arm.animation_data.nla_tracks.new(); tr.name = n
    st = tr.strips.new(n, 0, bpy.data.actions[n]); tr.mute = True
bpy.context.scene.render.fps = FPS

# ---------- rename to Godot's SkeletonProfileHumanoid names (auto BoneMap / retarget) ----------
HUMANOID = {"root": "Root", "hips": "Hips", "spine": "Spine", "chest": "Chest", "neck": "Neck", "head": "Head"}
for s, side in (("L", "Left"), ("R", "Right")):
    HUMANOID.update({f"upper_arm.{s}": f"{side}UpperArm", f"forearm.{s}": f"{side}LowerArm", f"hand.{s}": f"{side}Hand",
                     f"thigh.{s}": f"{side}UpperLeg", f"shin.{s}": f"{side}LowerLeg", f"foot.{s}": f"{side}Foot"})
EXTRA = {"neck2": "Neck2", "beak": "Beak", "beak2": "Beak2", **{t: t.capitalize() for t in tails}}
for b in arm.data.bones:
    new = HUMANOID.get(b.name) or EXTRA.get(b.name)
    if new: b.name = new  # Blender also renames the vertex groups and the action channels

# ---------- save + export ----------
os.makedirs(out_dir, exist_ok=True)
ob.name = f"{name}_mesh"
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True); bpy.context.view_layer.objects.active = ob
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))  # smaller GLB, softer look
src_dir = os.path.join(out_dir, "source")  # .gdignore'd so Godot doesn't import the .blend
os.makedirs(src_dir, exist_ok=True)
open(os.path.join(src_dir, ".gdignore"), "a").close()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(src_dir, f"{out_name}.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, f"{out_name}.glb"), export_format="GLB",
                          export_animation_mode="NLA_TRACKS", export_apply=False, export_yup=True)
print("INFO" + json.dumps({"name": name, "method": method, "direct_unweighted": direct_bad, "unweighted_before_fix": bad, "rigid_verts": rigid_n,
                           "bones": len(bones), "tris": len(ob.data.polygons), "actions": actions}))
