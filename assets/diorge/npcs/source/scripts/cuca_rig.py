# Rig da Cuca (NPC): mesmo esqueleto/skin do rig.py dos bosses, depois baixa os braços (nova pose de repouso)
# e cria idle-loop, talk-loop e walk-loop (no Godot: idle, talk, walk, em loop).
# 1) blender -b -P cuca_prep.py -- <cuca_tripo.glb> <scratch>/cuca_prep.blend
# 2) blender -b <scratch>/cuca_prep.blend -P cuca_rig.py -- assets/diorge/npcs assets/diorge/rigged/bosses/source/scripts/rig.py
# Opcional: DOWN/FWD/ELB (graus) ajustam a pose de braços baixos.
import bpy, sys, os, math, json
from mathutils import Vector, Quaternion, Matrix
out_dir, boss_rig = sys.argv[sys.argv.index("--") + 1:]
CFG = {
    "style": "cast", "robe": True, "weapon": "R",
    "spine": [(256, 335), (256, 285), (256, 235), (256, 180), (256, 140)], "head_top": (256, 25),
    "arm.R": [(208, 202), (150, 228), (80, 272)], "hand_tip.R": (33, 293),
    "arm.L": [(306, 202), (364, 228), (432, 272)], "hand_tip.L": (478, 293),
    "leg.R": [(228, 335), (218, 400), (212, 462)], "leg.L": [(284, 335), (294, 400), (300, 462)],
}
# reaproveita a parte de esqueleto + skin do rig.py dos bosses (tudo antes da seção de animação)
_src = open(boss_rig, encoding="utf-8").read()
_src = _src[:_src.index("# ---------- animation ----------")]
_src = _src.replace('name, out_dir, scratch = sys.argv[sys.argv.index("--") + 1:]', "").replace("sys.path.insert(0, scratch)", "")
_src = _src.replace("from landmarks import MODELS", "").replace("cfg = MODELS[name]", 'name = "cuca"; cfg = CFG')
exec(_src)
STAGE = os.environ.get("STAGE", "all")
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)

# ---------- braços baixos como pose de repouso ----------
for pb in arm.pose.bones: pb.rotation_mode = "QUATERNION"
def set_rot(pb, axis_deg):
    r = pb.bone.matrix_local.to_quaternion()
    # axis in parent-posed armature space ~ armature space (parents unposed for shoulders)
    q = Quaternion()
    for ax, d in axis_deg: q = Quaternion(Vector(ax), math.radians(d)) @ q
    pb.rotation_quaternion = r.inverted() @ q @ r
DOWN = float(os.environ.get("DOWN", "62")); FWD = float(os.environ.get("FWD", "8")); ELB = float(os.environ.get("ELB", "22"))
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for s, sg in (("L", 1), ("R", -1)):
    set_rot(arm.pose.bones[f"upper_arm.{s}"], [(Y, sg * DOWN), (X, -FWD)])
    set_rot(arm.pose.bones[f"forearm.{s}"], [(Y, sg * 10), (X, -ELB)])
bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode="OBJECT")
# bake the deformed mesh, then make the pose the rest pose
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True); bpy.context.view_layer.objects.active = ob
amod = next(m for m in ob.modifiers if m.type == "ARMATURE")
bpy.ops.object.modifier_copy(modifier=amod.name)
bpy.ops.object.modifier_apply(modifier=amod.name)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE"); bpy.ops.pose.select_all(action="SELECT"); bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode="OBJECT")
for m in ob.modifiers:
    if m.type == "ARMATURE": m.object = arm; m.name = "Armature"
bones = arm.data.bones
if STAGE == "rest":
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "cuca_rest.blend")); raise SystemExit

# ---------- animação (relativa à pose de braços baixos) ----------
arm.animation_data_create()
REST = {b.name: b.matrix_local.to_quaternion() for b in bones}
def rot(bn, axis, deg):
    r = REST[bn]
    return r.inverted() @ Quaternion(Vector(axis), math.radians(deg)) @ r
def key(pose, frame):
    for pb in arm.pose.bones:
        spec = pose.get(pb.name, [])
        q = Quaternion(); loc = Vector()
        for item in spec:
            if item[0] == "loc": loc = item[1]
            else: q = rot(pb.name, item[0], item[1]) @ q
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)
        if pb.name in ("root", "hips"):
            pb.location = REST[pb.name].inverted() @ loc
            pb.keyframe_insert("location", frame=frame, group=pb.name)
def new_action(n):
    act = bpy.data.actions.new(n); act.use_fake_user = True
    arm.animation_data.action = act; actions.append(n)
def bump(t, a, b):  # 0 fora de [a,b], sobe e desce suave (cosseno) dentro
    if t <= a or t >= b: return 0.0
    return 0.5 - 0.5 * math.cos(2 * math.pi * (t - a) / (b - a))
def ease(t, a, b, c, d):  # sobe em [a,b], segura, desce em [c,d]
    if t <= a or t >= d: return 0.0
    if t < b: return 0.5 - 0.5 * math.cos(math.pi * (t - a) / (b - a))
    if t <= c: return 1.0
    return 0.5 + 0.5 * math.cos(math.pi * (t - c) / (d - c))
actions = []
TAU = 2 * math.pi

# idle-loop: 3 s, respira, cabeça balança devagar, mãos quase paradas
new_action("idle-loop"); N = 90
for f in range(0, N + 1, 2):
    ph = TAU * f / N; s, s2 = math.sin(ph), math.sin(2 * ph)
    key({"chest": [(X, -2.5 * s2)], "spine": [(Z, 1.2 * s)], "neck": [(X, 1.5 * s2)],
         "head": [(Z, 3 * s), (X, 2 * math.sin(2 * ph + 0.8))],
         "hips": [("loc", Vector((0, 0, -0.004 * (1 - math.cos(2 * ph)))))],
         "upper_arm.L": [(Y, 2 * s2), (X, -2 * s)], "upper_arm.R": [(Y, -2 * s2), (X, 2 * s)],
         "forearm.L": [(X, -3 * (1 - math.cos(2 * ph)))], "forearm.R": [(X, -3 * (1 - math.cos(2 * ph + 1)))],
         "hand.L": [(X, -4 * s2)], "hand.R": [(X, 4 * s2)]}, f)

# talk-loop: 4 s, gesticula com a direita, depois a esquerda, depois as duas abertas; acena a cabeça
new_action("talk-loop"); N = 120
for f in range(0, N + 1, 2):
    t = f / N; ph = TAU * t
    eR = ease(t, 0.02, 0.12, 0.30, 0.42)          # mão direita explica
    eL = ease(t, 0.36, 0.46, 0.62, 0.74)          # mão esquerda responde
    eB = ease(t, 0.70, 0.80, 0.88, 0.98)          # as duas se abrem ("veja só")
    beat = math.sin(TAU * 6 * t)                  # batidas de fala (6 por ciclo)
    p = {"chest": [(X, 4 * (eR + eL) * 0.5 + 3 * eB), (Z, 5 * (eR - eL))], "spine": [(X, 2 * eB)],
         "neck": [(X, 2 * math.sin(TAU * 4 * t))],
         "head": [(X, 5 * math.sin(TAU * 4 * t + 0.4) - 3 * eB), (Z, -7 * eR + 7 * eL), (Y, 4 * math.sin(ph))],
         "hips": [("loc", Vector((0, 0, -0.003 * (1 - math.cos(TAU * 2 * t)))))]}
    for s, e, sg in (("R", eR, -1), ("L", eL, 1)):
        # braço vai à frente e um pouco para fora, antebraço sobe, mão abre para cima; batidas no antebraço
        p[f"upper_arm.{s}"] = [(X, -32 * e - 18 * eB + 3 * e * beat), (Y, -sg * (12 * e + 30 * eB)), (Z, sg * -6 * e)]
        p[f"forearm.{s}"] = [(X, -62 * e - 35 * eB + 8 * e * beat), (Z, sg * 15 * e)]
        p[f"hand.{s}"] = [(X, 18 * e + 12 * eB - 10 * e * beat), (Y, sg * 25 * (e + eB))]
    key(p, f)

# walk-loop: 1 s, passo curto de velhinha (saia), tronco um pouco curvado
new_action("walk-loop"); N = 30
amp = 0.55
for f in range(0, N + 1, 2):
    ph = TAU * f / N; s = math.sin(ph)
    key({"thigh.L": [(X, -26 * amp * s)], "thigh.R": [(X, 26 * amp * s)],
         "shin.L": [(X, 30 * amp * max(0, math.sin(ph + 1.4)))], "shin.R": [(X, 30 * amp * max(0, -math.sin(ph + 1.4)))],
         "foot.L": [(X, -10 * amp * s)], "foot.R": [(X, 10 * amp * s)],
         "upper_arm.L": [(X, 12 * s)], "upper_arm.R": [(X, -12 * s)],
         "forearm.L": [(X, -6 - 4 * s)], "forearm.R": [(X, -6 + 4 * s)],
         "hips": [("loc", Vector((0, 0, -0.01 * abs(math.cos(ph))))), (Z, 5 * s), (Y, 2.5 * s)],
         "chest": [(Z, -5 * s), (X, 6)], "head": [(Z, 3 * s), (X, -4)]}, f)

for act in bpy.data.actions:
    for fc in [fc for layer in getattr(act, "layers", []) for strip in layer.strips for cb in strip.channelbags for fc in cb.fcurves] or getattr(act, "fcurves", []):
        for kp in fc.keyframe_points: kp.interpolation = "BEZIER"
arm.animation_data.action = None
for n in actions:
    tr = arm.animation_data.nla_tracks.new(); tr.name = n
    tr.strips.new(n, 0, bpy.data.actions[n]); tr.mute = True
bpy.context.scene.render.fps = 30

if STAGE == "anim":
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "cuca_anim.blend")); raise SystemExit

# ---------- nomes do SkeletonProfileHumanoid ----------
HUMANOID = {"root": "Root", "hips": "Hips", "spine": "Spine", "chest": "Chest", "neck": "Neck", "head": "Head"}
for s, side in (("L", "Left"), ("R", "Right")):
    HUMANOID.update({f"upper_arm.{s}": f"{side}UpperArm", f"forearm.{s}": f"{side}LowerArm", f"hand.{s}": f"{side}Hand",
                     f"thigh.{s}": f"{side}UpperLeg", f"shin.{s}": f"{side}LowerLeg", f"foot.{s}": f"{side}Foot"})
for b in arm.data.bones:
    if b.name in HUMANOID: b.name = HUMANOID[b.name]

# ---------- texturas menores + export ----------
for img in bpy.data.images:
    if img.size[0] > 2048:
        tgt = 1024 if "roughness" in img.name else 2048
        img.scale(tgt, tgt)
ob.name = "cuca_mesh"
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True); bpy.context.view_layer.objects.active = ob
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
src_dir = os.path.join(out_dir, "source"); os.makedirs(src_dir, exist_ok=True)
open(os.path.join(src_dir, ".gdignore"), "a").close()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(src_dir, "cuca.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "cuca.glb"), export_format="GLB",
                          export_animation_mode="NLA_TRACKS", export_apply=False, export_yup=True,
                          export_image_format="JPEG", export_jpeg_quality=90)
print("INFO" + json.dumps({"method": method, "unweighted": bad, "bones": len(bones), "tris": len(ob.data.polygons), "actions": actions}))
