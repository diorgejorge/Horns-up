# Búfalo Guerreiro: espada com as DUAS mãos em todas as animações + ataque novo; exporta o GLB.
# usage: blender -b source/buffalo.blend -P source/scripts/attack_buffalo.py -- <out_dir>
# Roda sobre o buffalo.blend gerado por rig.py (a espada é rígida no osso LeftHand).
#
# Como funciona: um alvo "Grip" (preso ao osso Chest) diz onde fica a espada; a mão esquerda
# segue o Grip por IK, a direita pega o cabo logo abaixo (lado do pomo). O resultado é gravado
# quadro a quadro nos ossos dos braços e os alvos são apagados (o GLB não leva constraints).
# Os braços deste modelo são curtos: as duas mãos só se encontram na frente do peito, então o
# golpe vem do corpo (tronco, quadril, passo) e do giro da espada, não de esticar os braços.
#
# Ataque (30 fps): antecipação 0-7, golpe 7-9 (contato no quadro 9 = 0,3 s, quando o combate
# aplica o dano), follow-through 9-12, pausa no impacto até 15, recuperação até 30.
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Quaternion, Matrix

out_dir = sys.argv[sys.argv.index("--") + 1]
arm = bpy.data.objects["buffalo_rig"]; ob = bpy.data.objects["buffalo_mesh"]
bones = arm.data.bones
REST = {b.name: b.matrix_local.to_quaternion() for b in bones}
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
ARM_BONES = ["LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"]


def fcurves(act):
    return [fc for l in act.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]


def channelbags(act):
    return [cb for l in act.layers for s in l.strips for cb in s.channelbags]


def use_action(ob_, act):
    ob_.animation_data_create(); ob_.animation_data.action = act
    if act and act.slots: ob_.animation_data.action_slot = act.slots[0]


# ---------- geometria da espada (rest, espaço da armature) ----------
gi = ob.vertex_groups["LeftHand"].index
P = np.array([tuple(ob.matrix_world @ v.co) for v in ob.data.vertices
              if any(g.group == gi and g.weight > 0.99 for g in v.groups)])
c = P.mean(0); _, _, vt = np.linalg.svd(P - c)
ax = vt[0] if np.abs((P - c) @ vt[0]).max() == ((P - c) @ vt[0]).max() else -vt[0]  # ponta da lâmina = +ax
ax = Vector(ax); gd = Vector(vt[1])                                                   # gd ~ largura da guarda
hb = bones["LeftHand"]
wrist = hb.head_local.copy()
on_axis = Vector(c) + ax * (wrist - Vector(c)).dot(ax)
off_l = wrist - on_axis                         # do eixo da espada até o pulso esquerdo
REST_FRAME = Matrix((ax, gd, ax.cross(gd))).transposed()   # colunas: lâmina, guarda, normal
GAP = 0.085                                     # distância entre as mãos no cabo (pomo = -ax)


def sword_rot(d):
    """Rotação (armature) que leva a lâmina de rest para a direção d, guarda na horizontal."""
    d = Vector(d).normalized()
    g = Vector(X) - d * d.x; g.normalize()
    if g.dot(gd) < 0: g = -g
    new = Matrix((d, g, d.cross(g))).transposed()
    return (new @ REST_FRAME.transposed()).to_quaternion()


# ---------- alvos (presos ao Chest) ----------
def empty(n):
    e = bpy.data.objects.new(n, None); bpy.context.scene.collection.objects.link(e)
    e.parent = arm; e.parent_type = "BONE"; e.parent_bone = "Chest"; e.rotation_mode = "QUATERNION"
    return e


grip_l, grip_r, aim_r = empty("GripL"), empty("GripR"), empty("AimR")
pole_l, pole_r = empty("PoleL"), empty("PoleR")


def place(e, loc, q=None):
    m = Matrix.Translation(loc) @ (q.to_matrix().to_4x4() if q else Matrix())
    e.matrix_world = m
    bpy.context.view_layer.update()


def key_grip(frame, mid, d):
    """mid: ponto do cabo entre as mãos; d: direção da lâmina (espaço do peito em rest)."""
    q = sword_rot(d); dv = Vector(d).normalized()
    ol = q @ off_l
    orr = Vector((-ol.x, ol.y, ol.z))           # a mão direita vem do outro lado do cabo
    axis_l = Vector(mid) + dv * GAP / 2; axis_r = Vector(mid) - dv * GAP / 2
    place(grip_l, axis_l + ol, q @ REST["LeftHand"])
    place(grip_r, axis_r + orr)
    place(aim_r, axis_r - dv * 0.03 + Vector((0, -0.04, 0)))
    for e in (grip_l, grip_r, aim_r):
        e.keyframe_insert("location", frame=frame); e.keyframe_insert("rotation_quaternion", frame=frame)


place(pole_l, Vector((0.65, 0.35, 0.40))); place(pole_r, Vector((-0.65, 0.35, 0.40)))
pb = arm.pose.bones
for s, g in (("Left", grip_l), ("Right", grip_r)):
    ik = pb[f"{s}LowerArm"].constraints.new("IK"); ik.target = g; ik.chain_count = 2
    ik.pole_target = pole_l if s == "Left" else pole_r; ik.pole_angle = math.radians(-90)
cr = pb["LeftHand"].constraints.new("COPY_ROTATION"); cr.target = grip_l
dt = pb["RightHand"].constraints.new("DAMPED_TRACK"); dt.target = aim_r; dt.track_axis = "TRACK_Y"

GUARD = ((0, -0.175, 0.67), (0, -0.40, 0.92))   # em guarda: espada em pé, ponta um pouco à frente

# ---------- ataque: corpo ----------
# (quadro, tronco X, giro, quadril (frente, baixo), passo, cabeça, cabo (mid), lâmina (d))
SEQ = [
    (0,    0,   0, (0.00, 0.000),  0.0,  0, *GUARD),
    (4,  -12, -14, (-0.01, 0.015), 0.0,  6, (0.02, -0.170, 0.75), (0.08, 0.15, 0.99)),
    (7,  -20, -22, (0.02, 0.025), -0.2, 10, (0.03, -0.165, 0.78), (0.15, 0.55, 0.82)),  # topo
    (9,   18,  14, (-0.07, 0.040), 1.0, -12, (-0.01, -0.175, 0.64), (-0.06, -0.86, 0.50)),  # contato
    (12,  22,  18, (-0.08, 0.045), 1.0, -14, (-0.02, -0.170, 0.62), (-0.09, -0.97, 0.15)),  # follow
    (15,  20,  16, (-0.075, 0.042), 1.0, -13, (-0.02, -0.170, 0.62), (-0.08, -0.96, 0.22)),  # pausa
    (22,  10,   6, (-0.03, 0.014), 0.4, -5, (0.0, -0.175, 0.65), (0.0, -0.75, 0.40)),
    (30,   0,   0, (0.00, 0.000),  0.0,  0, *GUARD),
]


def rot(bn, axis, deg):
    r = REST[bn]
    return r.inverted() @ Quaternion(Vector(axis), math.radians(deg)) @ r


act = bpy.data.actions["attack"]
for cb in channelbags(act):
    for fc in list(cb.fcurves): cb.fcurves.remove(fc)
use_action(arm, act)
for p in pb: p.rotation_mode = "QUATERNION"
for f, ch, tw, (fw, dn), st, hd, *_ in SEQ:
    pose = {"Chest": [(X, ch), (Z, tw)], "Spine": [(X, ch * 0.4), (Z, tw * 0.5)],
            "Hips": [("loc", Vector((0, fw, -dn))), (X, ch * 0.2)], "Head": [(X, hd)], "Neck": [(X, -ch * 0.2)],
            "LeftUpperLeg": [(X, -32 * st)], "LeftLowerLeg": [(X, 30 * st)], "LeftFoot": [(X, 4 * st)],
            "RightUpperLeg": [(X, 16 * st)], "RightLowerLeg": [(X, 6 * st)], "RightFoot": [(X, -14 * st)]}
    for p in pb:
        if p.name in ARM_BONES: continue
        q, loc = Quaternion(), Vector()
        for item in pose.get(p.name, []):
            if item[0] == "loc": loc = item[1]
            else: q = rot(p.name, item[0], item[1]) @ q
        p.rotation_quaternion = q; p.keyframe_insert("rotation_quaternion", frame=f, group=p.name)
        if p.name in ("Root", "Hips"):
            p.location = REST[p.name].inverted() @ loc; p.keyframe_insert("location", frame=f, group=p.name)
for fc in fcurves(act):
    for kp in fc.keyframe_points:
        kp.interpolation = "LINEAR" if int(round(kp.co.x)) == 7 else "BEZIER"  # golpe seco 7->9
for tr in arm.animation_data.nla_tracks:
    for s in tr.strips:
        if s.action == act: s.action_frame_start, s.action_frame_end = 0, 30; s.frame_end = 30

# ---------- grava os braços (IK) em cada animação ----------
sc = bpy.context.scene
for tr in arm.animation_data.nla_tracks: tr.mute = True
for act in [a for a in bpy.data.actions if a.name in ("idle-loop", "walk-loop", "attack", "hurt", "die")]:
    f0, f1 = (int(x) for x in act.frame_range)
    use_action(arm, act)
    arm.data.pose_position = "REST"; bpy.context.view_layer.update()
    ga = bpy.data.actions.new("grip_" + act.name)
    for e in (grip_l, grip_r, aim_r): use_action(e, None); e.animation_data.action = ga
    if act.name == "attack":
        for f, *_, mid, d in SEQ: key_grip(f, mid, d)
        for fc in fcurves(ga):
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR" if int(round(kp.co.x)) == 7 else "BEZIER"
    else:
        key_grip(f0, *GUARD)
    arm.data.pose_position = "POSE"
    baked = {}
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        baked[f] = {n: arm.convert_space(pose_bone=pb[n], matrix=pb[n].matrix, from_space="POSE",
                                         to_space="LOCAL").to_quaternion() for n in ARM_BONES}
    for cb in channelbags(act):
        for fc in list(cb.fcurves):
            if any(f'"{n}"' in fc.data_path for n in ARM_BONES): cb.fcurves.remove(fc)
    for c_ in [cn for n in ARM_BONES for cn in pb[n].constraints]: c_.mute = True
    for f, qs in baked.items():
        for n, q in qs.items():
            pb[n].rotation_quaternion = q; pb[n].keyframe_insert("rotation_quaternion", frame=f, group=n)
    for c_ in [cn for n in ARM_BONES for cn in pb[n].constraints]: c_.mute = False

# ---------- limpa e exporta ----------
for n in ARM_BONES:
    for c_ in list(pb[n].constraints): pb[n].constraints.remove(c_)
for e in (grip_l, grip_r, aim_r, pole_l, pole_r): bpy.data.objects.remove(e)
for a in [a for a in bpy.data.actions if a.name.startswith("grip_")]: bpy.data.actions.remove(a)
arm.animation_data.action = None
for tr in arm.animation_data.nla_tracks: tr.mute = True
arm.data.pose_position = "POSE"
bpy.ops.wm.save_mainfile()
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "buffalo.glb"), export_format="GLB",
                          export_animation_mode="NLA_TRACKS", export_apply=False, export_yup=True)
print("OK", [(a.name, a.frame_range[:]) for a in bpy.data.actions])
