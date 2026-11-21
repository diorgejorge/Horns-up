# Refaz as 5 animações (idle, walk, attack, hurt, die) de um personagem rigado por rig.py, com
# movimento de criatura: um quadro-chave por quadro, curvas com aceleração, partes que atrasam
# (cabeça, pescoço, braços, cauda) e rebote. Exporta o GLB ao lado da pasta source/.
# usage: blender -b <dir>/source/<nome>.blend -P reanimar.py -- <pasta com landmarks.py e bosses_landmarks.py>
# Durações (30 fps): idle 60, walk 30, attack 30, hurt 30, die 45 quadros. No ataque o golpe/disparo
# acontece no quadro 10 (0,33 s): o combate aplica o dano / solta o projétil em 0,3 s.
# O Búfalo tem script próprio (attack_buffalo.py, espada com as duas mãos).
import bpy, sys, os, math, importlib.util
from mathutils import Vector, Quaternion

lm_dir = sys.argv[sys.argv.index("--") + 1]


def load(path):
    spec = importlib.util.spec_from_file_location(os.path.basename(path)[:-3], path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m.MODELS


MAIN = load(os.path.join(lm_dir, "landmarks.py")); BOSS = load(os.path.join(lm_dir, "bosses_landmarks.py"))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm or o.find_armature() == arm)
name = arm.name[:-4]
cfg = BOSS.get(name) if name in BOSS else MAIN[name]
W = cfg.get("weapon", cfg.get("weapon_side", "L")); O = "R" if W == "L" else "L"
SG = 1 if W == "L" else -1
style = cfg["style"]; robe = cfg["robe"]
amp = cfg.get("walk_amp", 0.45 if robe else 1.0)
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)

HUM = {"root": "Root", "hips": "Hips", "spine": "Spine", "chest": "Chest", "neck": "Neck", "head": "Head",
       "neck2": "Neck2", "beak": "Beak", "beak2": "Beak2"}
for s, side in (("L", "Left"), ("R", "Right")):
    HUM.update({f"upper_arm.{s}": f"{side}UpperArm", f"forearm.{s}": f"{side}LowerArm", f"hand.{s}": f"{side}Hand",
                f"thigh.{s}": f"{side}UpperLeg", f"shin.{s}": f"{side}LowerLeg", f"foot.{s}": f"{side}Foot"})
bones = arm.data.bones
tails = sorted([b.name for b in bones if b.name.startswith("Tail")], key=lambda n: int(n[4:]))
HUM.update({t.lower(): t for t in tails})
legs = "LeftUpperLeg" in bones; arms = "LeftUpperArm" in bones
REST = {b.name: b.matrix_local.to_quaternion() for b in bones}
TAIL_AX = X if cfg.get("tail_axis") == "X" else Z
TAIL_AMP = cfg.get("tail_amp", 10)
vs = [arm.matrix_world.inverted() @ ob.matrix_world @ v.co for v in ob.data.vertices]
back = max((v.y for v in vs if 0.4 < v.z < 0.9), default=0.05)
half = max((abs(v.x) for v in vs if 0.3 < v.z < 0.9), default=0.15)


def rot(bn, axis, deg):
    r = REST[bn]
    return r.inverted() @ Quaternion(Vector(axis), math.radians(deg)) @ r


def key(pose, f):
    pose = {HUM.get(k, k): v for k, v in pose.items()}
    for pb in arm.pose.bones:
        q, loc = Quaternion(), Vector()
        for item in pose.get(pb.name, []):
            if item[0] == "loc": loc = loc + item[1]
            else: q = rot(pb.name, item[0], item[1]) @ q
        pb.rotation_quaternion = q; pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
        if pb.name in ("Root", "Hips"):
            pb.location = REST[pb.name].inverted() @ loc; pb.keyframe_insert("location", frame=f, group=pb.name)


EASE = {"s": lambda u: u * u * (3 - 2 * u), "i": lambda u: u * u, "o": lambda u: 1 - (1 - u) ** 2, "l": lambda u: u}


def track(keys):
    """keys: [(quadro, valor | tupla, ease)]; ease vale para o trecho que CHEGA no quadro:
    s = suave, i = acelera (golpe), o = desacelera (chegar no topo / depois do impacto)."""
    keys = [(k[0], k[1] if isinstance(k[1], tuple) else (k[1],), k[2] if len(k) > 2 else "s") for k in keys]
    def v(t):
        t = max(keys[0][0], min(keys[-1][0], t))
        for (f0, v0, _), (f1, v1, e) in zip(keys, keys[1:]):
            if t <= f1:
                u = EASE[e]((t - f0) / (f1 - f0))
                r = tuple(a + (b - a) * u for a, b in zip(v0, v1))
                return r if len(r) > 1 else r[0]
        return keys[-1][1] if len(keys[-1][1]) > 1 else keys[-1][1][0]
    return v


def tail_wave(phase, k=1.0, lag=0.8):
    return {t.lower(): [(TAIL_AX, TAIL_AMP * k * math.sin(phase - i * lag))] for i, t in enumerate(tails)}


def reset(n, frames):
    act = bpy.data.actions[n]
    for l in act.layers:
        for s_ in l.strips:
            for cb in s_.channelbags:
                for fc in list(cb.fcurves): cb.fcurves.remove(fc)
    arm.animation_data.action = act
    if act.slots: arm.animation_data.action_slot = act.slots[0]
    for tr in arm.animation_data.nla_tracks:
        for s_ in tr.strips:
            if s_.action == act:
                s_.action_frame_start, s_.action_frame_end = 0, frames; s_.frame_end = frames
    return act


for pb in arm.pose.bones: pb.rotation_mode = "QUATERNION"

# ---------- idle-loop: respiração em cadeia (quadril -> peito -> pescoço -> cabeça), peso trocando de pé ----------
reset("idle-loop", 60)
for f in range(61):
    ph = 2 * math.pi * f / 60; s_, c_ = math.sin(ph), math.cos(ph)
    p = {"chest": [(X, -2.5 * s_)], "spine": [(X, -1.0 * math.sin(ph - 0.4))],
         "neck": [(X, 1.2 * math.sin(ph + 0.3))], "neck2": [(X, 1.2 * math.sin(ph + 0.6))],
         "head": [(X, 2.2 * math.sin(ph + 0.8)), (Z, 1.8 * math.sin(ph + 1.2))],
         "hips": [("loc", Vector((0.006 * s_, 0, -0.005 * (1 - c_))))]}
    if legs:
        p["hips"].append((Y, 1.5 * s_)); p["chest"].append((Z, -1.2 * s_))
        p["thigh.L"] = [(Y, -1.5 * s_)]; p["thigh.R"] = [(Y, -1.5 * s_)]
    else:  # serpente / peixe: o corpo erguido balança devagar
        p["spine"].append((Z, 3 * s_)); p["chest"].append((Z, -3 * math.sin(ph - 0.6))); p["neck"].append((Z, 2 * math.sin(ph - 1.2)))
    if arms and style != "charge":
        p["upper_arm.L"] = [(Y, -2.5 * math.sin(ph + 0.5))]; p["upper_arm.R"] = [(Y, 2.5 * math.sin(ph + 0.5))]
        p["forearm.L"] = [(X, -3 * math.sin(ph + 1.0))]; p["forearm.R"] = [(X, -3 * math.sin(ph + 1.0))]
    p.update(tail_wave(ph)); key(p, f)

# ---------- walk-loop: passada com o quadril indo para o pé de apoio, tronco contra-girando, braço atrasado ----------
reset("walk-loop", 30)
for f in range(31):
    ph = 2 * math.pi * f / 30; s_ = math.sin(ph)
    p = {"hips": [("loc", Vector((0.012 * math.sin(ph + 0.6) * (1 if legs else 0.5), 0, -0.014 * abs(math.cos(ph))))),
                  (Z, 6 * s_), (Y, (3 * s_ if robe else -3 * math.cos(ph)) if legs else 0)],
         "spine": [(Z, -2 * s_)], "chest": [(Z, -6 * math.sin(ph - 0.25)), (X, 4)],
         "neck": [(X, -2)], "head": [(Z, 3 * s_), (X, -1.5 * math.cos(2 * ph))]}
    if legs:
        p.update({"thigh.L": [(X, -28 * amp * s_)], "thigh.R": [(X, 28 * amp * s_)],
                  "shin.L": [(X, 32 * amp * max(0, math.sin(ph + 1.4)))], "shin.R": [(X, 32 * amp * max(0, -math.sin(ph + 1.4)))],
                  "foot.L": [(X, -10 * amp * s_)], "foot.R": [(X, 10 * amp * s_)]})
    else:  # desliza: o corpo ondula e a cauda nada
        p["spine"] = [(Z, 5 * s_)]; p["chest"] = [(Z, -4 * math.sin(ph - 0.8)), (X, 3)]
    if arms:
        lag = math.sin(ph - 0.7)
        p["upper_arm.L"] = [(X, 18 * s_)]; p["upper_arm.R"] = [(X, -18 * s_)]
        if style != "charge":
            p["forearm.L"] = [(X, -6 - 6 * lag)]; p["forearm.R"] = [(X, -6 + 6 * lag)]
    p.update(tail_wave(ph if not legs else 2 * ph, 1.4 if not legs else 1.0)); key(p, f)

# ---------- attack: antecipação (desacelera no topo), golpe que acelera até o quadro 10, follow-through, assenta ----------
reset("attack", 30)
LAG = 2  # cabeça/pescoço/cauda seguem o tronco com 2 quadros de atraso
if style.startswith("melee"):
    T = track([(0, (0, 0, 0, 0, 0)), (3, (-25, 8, -3, 0, 0)), (8, (-150, 35, -14, -0.2, 0.01), "o"),
               (10, (-40, 5, 20, 1, -0.05), "i"), (13, (-22, 0, 24, 1, -0.06), "o"), (17, (-30, 4, 19, 1, -0.055)),
               (24, (-10, 2, 6, 0.35, -0.02)), (30, (0, 0, 0, 0, 0))])
    for f in range(31):
        sh, el, ch, st, lu = T(f); chl = T(f - LAG)[2]
        p = {f"upper_arm.{W}": [(X, sh)], f"forearm.{W}": [(X, -el)], "chest": [(X, ch), (Z, SG * ch * 0.6)],
             "spine": [(X, ch * 0.25)], "hips": [(X, ch * 0.25), ("loc", Vector((0, lu, -0.02 * abs(st))))],
             "head": [(X, -chl * 0.35)], "neck": [(X, -chl * 0.15)]}
        if style == "melee2":
            p[f"upper_arm.{O}"] = [(X, T(f - 1)[0])]; p[f"forearm.{O}"] = [(X, -T(f - 1)[1])]
        elif arms:
            p[f"upper_arm.{O}"] = [(X, ch * 1.2), (Y, -SG * abs(ch) * 0.5)]
        if legs and not robe:
            p[f"thigh.{W}"] = [(X, -25 * st)]; p[f"shin.{W}"] = [(X, 22 * st)]; p[f"thigh.{O}"] = [(X, 12 * st)]
        p.update(tail_wave(f / 4, 1 + abs(chl) / 20)); key(p, f)
elif style == "shoot":  # já mira um arco: puxa a corda, solta, recua
    T = track([(0, (0, 0)), (4, (0.4, 0)), (8, (1, 0), "o"), (10, (-0.3, 1), "i"), (14, (-0.1, 0.6), "o"),
               (20, (0, 0.25)), (30, (0, 0))])
    for f in range(31):
        pull, rec = T(f); recl = T(f - LAG)[1]
        p = {f"upper_arm.{O}": [(Z, -SG * 30 * pull)], f"forearm.{O}": [(Z, -SG * 25 * pull)],
             f"upper_arm.{W}": [(X, 6 * rec)], "chest": [(X, -5 * rec), (Z, SG * 4 * pull)], "head": [(X, 3 * recl)],
             "hips": [("loc", Vector((0, 0.015 * rec, 0)))]}
        p.update(tail_wave(f / 4)); key(p, f)
elif style == "thrust":  # lança: recolhe, estoca com o passo à frente, segura, volta
    T = track([(0, (0, 0, 0, 0)), (4, (8, 15, -4, 0)), (8, (15, 30, -8, 0), "o"), (10, (-40, 140, 14, 1), "i"),
               (13, (-45, 145, 16, 1), "o"), (18, (-35, 130, 12, 1)), (24, (-10, 40, 4, 0.3)), (30, (0, 0, 0, 0))])
    for f in range(31):
        sh, hd, ch, lg = T(f); chl = T(f - LAG)[2]
        p = {f"upper_arm.{W}": [(X, sh)], f"forearm.{W}": [(X, sh * 0.5)], f"hand.{W}": [(X, hd)],
             "chest": [(X, ch), (Z, SG * ch * 0.5)], "head": [(X, -chl * 0.4)],
             "thigh.L": [(X, -20 * lg)], "shin.L": [(X, 15 * lg)], "thigh.R": [(X, 10 * lg)],
             "hips": [("loc", Vector((0, -0.04 * lg, -0.02 * lg)))]}
        p.update(tail_wave(f / 4)); key(p, f)
elif style == "blow":  # zarabatana: inspira (inclina para trás), sopra (estala para a frente), assenta
    T = track([(0, 0), (4, -0.5), (8, -1, "o"), (10, 1, "i"), (13, 0.85, "o"), (19, 0.3), (24, 0.08), (30, 0)])
    for f in range(31):
        k = T(f); kl = T(f - LAG)
        p = {"chest": [(X, 8 * k)], "spine": [(X, 3 * k)], "head": [(X, 5 * kl)], "hips": [(X, 2 * k)],
             "upper_arm.L": [(X, -4 * kl)], "upper_arm.R": [(X, -4 * kl)]}
        p.update(tail_wave(f / 4)); key(p, f)
elif style == "bite":  # serpente: recua o pescoço, dá o bote, recolhe
    T = track([(0, 0), (4, -0.3), (8, -0.7, "o"), (10, 1, "i"), (13, 1.05, "o"), (18, 0.75), (24, 0.2), (30, 0)])
    for f in range(31):
        p = {"chest": [(X, 20 * T(f))], "spine": [(X, 10 * T(f + 1))], "neck": [(X, 25 * T(f - 1))], "head": [(X, -12 * T(f - LAG))]}
        p.update({t.lower(): [(TAIL_AX, TAIL_AMP * (1 + abs(T(f - i))) * math.sin(f / 3 - i * 0.8))] for i, t in enumerate(tails)})
        key(p, f)
elif style == "charge":  # quadrúpede: abaixa a cabeça e investe
    T = track([(0, 0), (4, 0.25), (8, 0.5, "o"), (10, 1, "i"), (14, 1, "o"), (20, 0.8), (25, 0.3), (30, 0)])
    for f in range(31):
        k = T(f); kl = T(f - LAG)
        p = {"neck": [(X, 40 * k)], "head": [(X, 25 * kl)], "chest": [(X, 5 * k)],
             "root": [("loc", Vector((0, -0.18 * max(0, k - 0.3) / 0.7, 0)))],
             "thigh.L": [(X, 10 * k)], "thigh.R": [(X, 10 * k)], "upper_arm.L": [(X, -12 * k)], "upper_arm.R": [(X, -12 * k)]}
        key(p, f)
else:  # cast: ergue a arma, carrega, lança no quadro 10, segura, volta
    T = track([(0, (0, 0, 0)), (4, (-30, -3, -3)), (8, (-80, -8, -6), "o"), (10, (-95, 6, 10), "i"),
               (14, (-92, 5, 9), "o"), (20, (-70, 3, 6)), (25, (-20, 1, 1)), (30, (0, 0, 0))])
    for f in range(31):
        sh, ch, hd = T(f); hdl = T(f - LAG)[2]
        p = {f"upper_arm.{W}": [(Y, SG * sh * 0.6), (X, sh * 0.25)], f"upper_arm.{O}": [(X, T(f - 1)[0] * 0.35)],
             "chest": [(X, ch)], "spine": [(X, ch * 0.4)], "head": [(X, -hdl * 0.5)],
             "hips": [("loc", Vector((0, 0, -0.012 * max(0, ch) / 6)))]}
        p.update(tail_wave(f / 4, 1.3)); key(p, f)

# ---------- hurt: tranco no quadro 3, rebote, passa do ponto e assenta; cabeça e braços atrasam ----------
reset("hurt", 30)
T = track([(0, 0), (3, 1, "o"), (6, 0.85), (10, 0.45), (15, 0.12), (19, -0.08), (24, 0.03), (30, 0)])
for f in range(31):
    k, k1, k2 = T(f), T(f - 1), T(f - LAG)
    p = {"chest": [(X, -14 * k), (Z, 4 * k)], "spine": [(X, -6 * k)], "neck": [(X, -6 * k2)], "head": [(X, -16 * k2), (Z, -5 * k2)],
         "upper_arm.L": [(Y, -12 * k1)], "upper_arm.R": [(Y, 12 * k1)], "forearm.L": [(X, -10 * k2)], "forearm.R": [(X, -10 * k2)],
         "root": [("loc", Vector((0, 0.045 * max(k, 0), 0)))], "hips": [("loc", Vector((0, 0, -0.012 * max(k, 0))))]}
    if legs:
        p.update({"thigh.L": [(X, -8 * max(k, 0))], "shin.L": [(X, 14 * max(k, 0))],
                  "thigh.R": [(X, -6 * max(k, 0))], "shin.R": [(X, 12 * max(k, 0))]})
    p.update({t.lower(): [(TAIL_AX, TAIL_AMP * 1.5 * T(f - i) * math.sin(f / 2.5 - i))] for i, t in enumerate(tails)})
    key(p, f)

# ---------- die: cambaleia, joelhos cedem, a queda acelera, quica no chão e assenta ----------
reset("die", 45)
T = track([(0, (0, 0, 0)), (5, (0.2, 0, -1), "o"), (10, (0.7, -6, -0.4)), (15, (1, -18, 0)), (20, (1, -40, 0), "i"),
           (27, (0.6, -92, 0), "i"), (30, (0.6, -83, 0), "o"), (34, (0.6, -91, 0), "i"), (38, (0.6, -89, 0), "o"),
           (45, (0.6, -90, 0))])
for f in range(46):
    kb, fall, stg = T(f); k = fall / -90; kl = T(f - 3)[1] / -90; hl = T(f - LAG)
    if cfg.get("die_style") == "slump":  # serpente: o rolo fica no chão, o corpo erguido desaba para a frente
        p = {"spine": [(X, 30 * k)], "chest": [(X, 35 * k - 8 * stg)], "neck": [(X, 20 * T(f - 1)[1] / -90)],
             "head": [(X, -15 * kl - 10 * hl[2])], "upper_arm.L": [(Y, -30 * kl)], "upper_arm.R": [(Y, 30 * kl)]}
        p.update({t.lower(): [(Z, 4 * k * math.sin(i))] for i, t in enumerate(tails)}); key(p, f); continue
    p = {"thigh.L": [(X, -25 * kb)], "thigh.R": [(X, -20 * kb)], "shin.L": [(X, 40 * kb)], "shin.R": [(X, 35 * kb)],
         "chest": [(X, 15 * kb - 10 * stg)], "spine": [(X, -4 * stg)], "head": [(X, 20 * hl[0] - 16 * hl[2])],
         "upper_arm.L": [(Y, -40 * kl)], "upper_arm.R": [(Y, 40 * kl)], "forearm.L": [(X, -15 * kl)], "forearm.R": [(X, -15 * kl)],
         "hips": [("loc", Vector((0, 0.03 * abs(stg), 0)))],
         "root": [(X, fall), ("loc", Vector((0, 0.06 * min(1, k * 1.1), (back + 0.01) * k)))]}
    if cfg.get("die_axis") == "Y":  # quadrúpede: tomba de lado
        p["root"] = [(Y, -fall), ("loc", Vector((0, 0, half * 0.6 * k)))]
    p.update({t.lower(): [(X, -30 * min(1, 3 / len(tails)) * T(f - 1 - i)[1] / -90)] for i, t in enumerate(tails)})
    key(p, f)

# um quadro-chave por quadro: interpolação linear entre eles (a curva já está nos valores)
for act in bpy.data.actions:
    for l in act.layers:
        for s_ in l.strips:
            for cb in s_.channelbags:
                for fc in cb.fcurves:
                    for kp in fc.keyframe_points: kp.interpolation = "LINEAR"
arm.animation_data.action = None
for tr in arm.animation_data.nla_tracks: tr.mute = True
bpy.ops.wm.save_mainfile()
out = os.path.join(os.path.dirname(os.path.dirname(bpy.data.filepath)), f"{os.path.basename(bpy.data.filepath)[:-6]}.glb")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="NLA_TRACKS",
                          export_apply=False, export_yup=True)
print("REANIMADO", name, style, "legs" if legs else "nolegs", len(tails), out)
