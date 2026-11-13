"""Gera os modelos 3D dos personagens do Horns Up no Blender.

Modelos low-poly com cor chapada, feitos para o render de 320x180 do jogo
(câmera lateral ortográfica, ~20 px por metro). Cada personagem sai com:

- um esqueleto simples (ossos nomeados, prontos para animar no Blender);
- uma malha única com pesos rígidos (cada peça segue 100% um osso);
- frente para +X, pés na origem, lado da câmera em -Y do Blender
  (+Z no Godot), igual às cenas atuais do jogo.

Uso (Blender 4.2+):
    blender --background --python arte/blender/modelar_personagens.py
ou, com o módulo bpy do pip:
    python arte/blender/modelar_personagens.py

Saídas:
    arte/blender/<nome>.blend            arquivo editável
    assets/modelos/personagens/<nome>.glb    o que o Godot importa
"""

import math
import os

import bpy  # precisa vir antes do bmesh no módulo do pip
import bmesh
from mathutils import Euler, Matrix, Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SAIDA_BLEND = os.path.join(RAIZ, "arte", "blender")
SAIDA_GLB = os.path.join(RAIZ, "assets", "modelos", "personagens")


# ---------------------------------------------------------------- utilidades

def srgb(hexcor):
    """'#rrggbb' em sRGB -> tupla linear (Blender e glTF guardam linear)."""
    hexcor = hexcor.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(hexcor[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def material(nome, hexcor, dupla_face=False):
    m = bpy.data.materials.get(nome)
    if m:
        return m
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    cor = (*srgb(hexcor), 1.0)
    bsdf.inputs["Base Color"].default_value = cor
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    m.diffuse_color = cor
    m.use_backface_culling = not dupla_face
    return m


def mat4(loc=(0, 0, 0), rot=(0, 0, 0), escala=(1, 1, 1)):
    r = Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
    s = Matrix.Diagonal((*escala, 1.0))
    return Matrix.Translation(Vector(loc)) @ r @ s


def alinhar(p0, p1):
    """Matriz que leva o eixo Z local para o segmento p0->p1, centrada nele."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return Matrix.Translation((p0 + p1) / 2) @ q.to_matrix().to_4x4(), d.length


class Modelo:
    """Junta primitivas numa malha só, com material e osso por peça."""

    def __init__(self, nome):
        self.nome = nome
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.mats = []
        self.ossos = []  # (nome, cabeça, cauda, pai)

    # -- esqueleto
    def osso(self, nome, cabeca, cauda, pai=None):
        self.ossos.append((nome, Vector(cabeca), Vector(cauda), pai))
        return nome

    def _indice_osso(self, nome):
        return [o[0] for o in self.ossos].index(nome)

    # -- fechamento de cada peça
    def _peca(self, verts, matriz, mat, osso):
        bmesh.ops.transform(self.bm, matrix=matriz, verts=verts)
        if mat not in self.mats:
            self.mats.append(mat)
        mi = self.mats.index(mat)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = mi
            f.smooth = False
        bi = self._indice_osso(osso)
        for v in verts:
            v[self.deform][bi] = 1.0

    # -- primitivas
    def caixa(self, tam, loc, mat, osso, rot=(0, 0, 0), topo=(1, 1),
              base=(1, 1), desloc_topo=(0, 0)):
        """Caixa com afunilamento opcional no topo (+Z local) e na base."""
        vs = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in vs:
            t = topo if v.co.z > 0 else base
            v.co.x *= tam[0] * t[0]
            v.co.y *= tam[1] * t[1]
            v.co.z *= tam[2]
            if v.co.z > 0:
                v.co.x += desloc_topo[0]
                v.co.y += desloc_topo[1]
        self._peca(vs, mat4(loc, rot), mat, osso)

    def caixa_entre(self, p0, p1, larg, prof, mat, osso, topo=(1, 1)):
        """Caixa esticada de p0 a p1 (membros, cabos)."""
        m, comp = alinhar(p0, p1)
        vs = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in vs:
            t = topo if v.co.z > 0 else (1, 1)
            v.co.x *= larg * t[0]
            v.co.y *= prof * t[1]
            v.co.z *= comp
        self._peca(vs, m, mat, osso)

    def cilindro(self, r1, r2, alt, loc, mat, osso, rot=(0, 0, 0), lados=6,
                 escala=(1, 1, 1)):
        vs = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False,
                                   segments=lados, radius1=r1, radius2=r2,
                                   depth=alt)["verts"]
        self._peca(vs, mat4(loc, rot, escala), mat, osso)

    def cilindro_entre(self, p0, p1, r0, r1, mat, osso, lados=6):
        m, comp = alinhar(p0, p1)
        vs = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False,
                                   segments=lados, radius1=r0, radius2=r1,
                                   depth=comp)["verts"]
        self._peca(vs, m, mat, osso)

    def bola(self, r, loc, mat, osso, escala=(1, 1, 1), rot=(0, 0, 0), sub=1):
        vs = bmesh.ops.create_icosphere(self.bm, subdivisions=sub,
                                        radius=r)["verts"]
        self._peca(vs, mat4(loc, rot, escala), mat, osso)

    def tubo(self, pontos, raios, mat, ossos, lados=6):
        """Corrente de troncos de cone (chifres, rabo). `ossos` pode ser um
        nome só ou uma lista com um osso por trecho."""
        for i in range(len(pontos) - 1):
            osso = ossos if isinstance(ossos, str) else ossos[i]
            self.cilindro_entre(pontos[i], pontos[i + 1], raios[i],
                                raios[i + 1], mat, osso, lados)

    def lamina(self, pontos, faces, mat, osso):
        """Superfície fina feita à mão (membrana da asa)."""
        vs = [self.bm.verts.new(Vector(p)) for p in pontos]
        for f in faces:
            self.bm.faces.new([vs[i] for i in f])
        self._peca(vs, Matrix.Identity(4), mat, osso)

    # -- montagem final no Blender
    def construir(self):
        col = bpy.context.scene.collection

        arm_data = bpy.data.armatures.new(self.nome + "_esqueleto")
        arm = bpy.data.objects.new(self.nome, arm_data)
        col.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode="EDIT")
        for nome, cabeca, cauda, _ in self.ossos:
            eb = arm_data.edit_bones.new(nome)
            eb.head, eb.tail = cabeca, cauda
        for nome, _, _, pai in self.ossos:
            if pai:
                eb = arm_data.edit_bones[nome]
                eb.parent = arm_data.edit_bones[pai]
                eb.use_connect = False
        bpy.ops.object.mode_set(mode="OBJECT")

        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.nome + "_malha")
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        malha = bpy.data.objects.new(self.nome + "_malha", me)
        col.objects.link(malha)
        for nome, *_ in self.ossos:
            malha.vertex_groups.new(name=nome)
        malha.parent = arm
        mod = malha.modifiers.new("Esqueleto", "ARMATURE")
        mod.object = arm
        return arm, malha


def limpar_cena():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def exportar(nome):
    os.makedirs(SAIDA_BLEND, exist_ok=True)
    os.makedirs(SAIDA_GLB, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(
        filepath=os.path.join(SAIDA_BLEND, nome + ".blend"), compress=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(SAIDA_GLB, nome + ".glb"),
        export_format="GLB",
        export_apply=False,
        export_skins=True,
        export_animations=False,
        export_yup=True,
    )


# ------------------------------------------------------------------- o bode

def bode():
    """Bode Mjolnir: atarracado, cabeça e tronco grandes, pernas curtas,
    chifres longos curvados para trás, cicatriz no olho, correias de couro,
    martelo de pedra amarrado. Altura ~1,75 m até a ponta do chifre."""
    pelo = material("bode_pelo", "#d8c095")
    pelo_sombra = material("bode_pelo_sombra", "#b59a70")
    chifre = material("bode_chifre", "#4b3b34")
    casco = material("bode_casco", "#3a2c27")
    couro = material("bode_couro", "#6e4129")
    couro_esc = material("bode_couro_escuro", "#4a2b1c")
    ferro = material("bode_ferro", "#6f737a")
    pedra = material("martelo_pedra", "#80838a")
    pedra_esc = material("martelo_pedra_escura", "#5a5d63")
    madeira = material("martelo_madeira", "#4f3526")
    cicatriz = material("bode_cicatriz", "#b0342c")
    olho = material("bode_olho", "#2a1b16")
    focinho = material("bode_focinho", "#6e4844")
    orelha_in = material("bode_orelha", "#c9958a")

    m = Modelo("bode")
    m.osso("quadril", (0, 0, 0.62), (0, 0, 0.8))
    m.osso("tronco", (0, 0, 0.8), (0.02, 0, 1.15), "quadril")
    m.osso("cabeca", (0.08, 0, 1.18), (0.2, 0, 1.5), "tronco")

    for lado, s in (("E", 1), ("D", -1)):  # E = lado de longe, D = da câmera
        y = 0.14 * s
        m.osso(f"coxa.{lado}", (0.02, y, 0.6), (0.04, y, 0.32), "quadril")
        m.osso(f"canela.{lado}", (0.04, y, 0.32), (-0.02, y, 0.08), f"coxa.{lado}")
        m.osso(f"pe.{lado}", (-0.02, y, 0.08), (0.12, y, 0.02), f"canela.{lado}")

        m.caixa_entre((0.02, y, 0.62), (0.05, y, 0.3), 0.3, 0.22, pelo,
                      f"coxa.{lado}", topo=(0.8, 0.85))
        m.caixa_entre((0.05, y, 0.32), (-0.02, y, 0.1), 0.17, 0.16, pelo,
                      f"canela.{lado}")
        m.caixa((0.19, 0.18, 0.06), (0.0, y, 0.12), pelo_sombra, f"canela.{lado}")
        m.caixa((0.2, 0.15, 0.09), (0.04, y, 0.045), casco, f"pe.{lado}",
                topo=(0.8, 0.85))

    # saiote de couro com barra de pelo e cinto
    m.caixa((0.5, 0.46, 0.26), (0.0, 0, 0.6), couro, "quadril", topo=(0.86, 0.9))
    m.caixa((0.04, 0.22, 0.3), (0.25, 0, 0.55), couro_esc, "quadril",
            base=(1, 0.8))
    m.caixa((0.52, 0.48, 0.05), (0.0, 0, 0.48), pelo_sombra, "quadril")
    m.caixa((0.47, 0.5, 0.08), (0.02, 0, 0.75), couro_esc, "quadril")
    m.cilindro(0.075, 0.075, 0.04, (0.27, 0, 0.75), ferro, "quadril",
               rot=(0, 90, 0), lados=8)

    # tronco largo no peito, com correia em diagonal e argola de ferro
    m.caixa((0.48, 0.52, 0.45), (0.03, 0, 0.98), pelo, "tronco",
            topo=(1.12, 1.18))
    m.caixa((0.1, 0.38, 0.26), (0.27, 0, 1.0), pelo, "tronco", topo=(1.1, 1))
    m.caixa((0.6, 0.64, 0.07), (0.04, 0, 1.0), couro, "tronco", rot=(38, 0, 0))
    m.cilindro(0.06, 0.06, 0.03, (0.33, 0, 0.98), ferro, "tronco",
               rot=(0, 90, 0), lados=8)
    m.caixa((0.2, 0.62, 0.08), (0.0, 0, 1.2), pelo_sombra, "tronco")  # pelo do pescoço

    # cabeça: crânio, focinho, sobrancelha brava, barba, orelhas, olhos
    m.caixa((0.3, 0.32, 0.3), (0.13, 0, 1.33), pelo, "cabeca")
    m.caixa((0.24, 0.2, 0.17), (0.33, 0, 1.27), pelo, "cabeca", topo=(0.9, 0.9))
    m.caixa((0.06, 0.13, 0.07), (0.46, 0, 1.3), focinho, "cabeca")
    m.caixa((0.1, 0.34, 0.06), (0.26, 0, 1.42), pelo_sombra, "cabeca",
            rot=(0, 12, 0))
    m.caixa((0.18, 0.15, 0.24), (0.3, 0, 1.11), pelo_sombra, "cabeca",
            base=(0.45, 0.6))
    for s in (1, -1):
        m.caixa((0.06, 0.02, 0.04), (0.25, 0.166 * s, 1.37), olho, "cabeca")
        m.caixa((0.07, 0.17, 0.06), (0.06, 0.24 * s, 1.37), pelo, "cabeca",
                rot=(-25 * s, 0, 0))
        m.caixa((0.05, 0.12, 0.02), (0.06, 0.25 * s, 1.385), orelha_in,
                "cabeca", rot=(-25 * s, 0, 0))
        # chifres: sobem e curvam para trás e para baixo
        m.tubo([(0.1, 0.1 * s, 1.46), (0.05, 0.12 * s, 1.62),
                (-0.07, 0.14 * s, 1.73), (-0.22, 0.15 * s, 1.74),
                (-0.33, 0.16 * s, 1.64), (-0.37, 0.17 * s, 1.5)],
               [0.075, 0.065, 0.055, 0.045, 0.035, 0.018], chifre, "cabeca")
    # cicatriz vermelha atravessando o olho do lado da câmera
    m.caixa((0.022, 0.012, 0.17), (0.235, -0.168, 1.37), cicatriz, "cabeca",
            rot=(0, -28, 0))

    # braços segurando o martelo na diagonal, cabeça do martelo no alto
    cabo0 = Vector((0.1, -0.1, 0.42))
    cabo1 = Vector((0.6, -0.1, 1.3))
    eixo = (cabo1 - cabo0).normalized()
    mao_baixa = cabo0 + (cabo1 - cabo0) * 0.3
    mao_alta = cabo0 + (cabo1 - cabo0) * 0.72

    bracos = {
        "D": ((0.04, -0.32, 1.12), (0.18, -0.38, 0.88), mao_alta),
        "E": ((0.04, 0.32, 1.12), (0.12, 0.36, 0.84), mao_baixa),
    }
    for lado, (ombro, cotovelo, mao) in bracos.items():
        mao = Vector(mao) + Vector((0, 0.0 if lado == "D" else 0.06, 0))
        m.osso(f"braco.{lado}", ombro, cotovelo, "tronco")
        m.osso(f"antebraco.{lado}", cotovelo, mao, f"braco.{lado}")
        m.osso(f"mao.{lado}", mao, mao + Vector((0.08, 0, 0)), f"antebraco.{lado}")
        m.bola(0.16, ombro, pelo, f"braco.{lado}", escala=(1, 0.9, 1))
        m.caixa_entre(ombro, cotovelo, 0.19, 0.19, pelo, f"braco.{lado}")
        m.caixa_entre(cotovelo, mao, 0.17, 0.17, couro, f"antebraco.{lado}",
                      topo=(0.85, 0.85))
        m.cilindro_entre(Vector(cotovelo) - Vector((0, 0, 0.02)),
                         Vector(cotovelo) + (Vector(mao) - Vector(cotovelo)) * 0.2,
                         0.12, 0.12, pelo_sombra, f"antebraco.{lado}", lados=7)
        m.caixa((0.16, 0.15, 0.15), mao, pelo, f"mao.{lado}")

    m.osso("martelo", cabo0, cabo1, "mao.D")
    m.cilindro_entre(cabo0, cabo1, 0.04, 0.04, madeira, "martelo")
    for t in (0.15, 0.45, 0.85):
        c = cabo0 + (cabo1 - cabo0) * t
        m.cilindro_entre(c - eixo * 0.05, c + eixo * 0.05, 0.05, 0.05, couro,
                         "martelo")
    m.cilindro_entre(cabo0 - eixo * 0.08, cabo0 + eixo * 0.02, 0.065, 0.055,
                     ferro, "martelo")
    m.cilindro_entre(cabo1 - eixo * 0.12, cabo1, 0.055, 0.055, ferro, "martelo")
    perp = Vector((-eixo.z, 0, eixo.x))  # perpendicular ao cabo no plano XZ
    centro = cabo1 + eixo * 0.12
    m.caixa_entre(centro - perp * 0.28, centro + perp * 0.28, 0.3, 0.32, pedra,
                  "martelo")
    for s in (1, -1):
        p = centro + perp * 0.28 * s
        m.caixa_entre(p, p + perp * 0.05 * s, 0.26, 0.28, pedra_esc, "martelo")
        b = centro + perp * 0.1 * s
        m.caixa_entre(b - perp * 0.03, b + perp * 0.03, 0.32, 0.34, couro,
                      "martelo")

    m.construir()
    exportar("bode")


# ---------------------------------------------------------------- a ovelha

def ovelha():
    """Ovelha soldado: corpo de lã, elmo de ferro, peitoral, tabardo cáqui
    rasgado, lança e escudo redondo. Altura ~1,35 m."""
    la = material("ovelha_la", "#d2cbbd")
    la_sombra = material("ovelha_la_sombra", "#a39b8d")
    pele = material("ovelha_pele", "#e9dccb")
    focinho = material("ovelha_focinho", "#dcb9ab")
    casco = material("ovelha_casco", "#3a312d")
    ferro = material("ovelha_ferro", "#5e554e")
    ferro_claro = material("ovelha_ferro_claro", "#8c8780")
    tabardo = material("ovelha_tabardo", "#8b7547")
    emblema = material("ovelha_emblema", "#4d5a33")
    couro = material("ovelha_couro", "#5c3d26")
    madeira = material("ovelha_madeira", "#6a4a2e")
    lamina = material("ovelha_lamina", "#a3a9ae")
    olho = material("ovelha_olho", "#231a17")

    m = Modelo("ovelha")
    m.osso("quadril", (0, 0, 0.48), (0, 0, 0.66))
    m.osso("tronco", (0, 0, 0.66), (0.04, 0, 0.98), "quadril")
    m.osso("cabeca", (0.12, 0, 1.0), (0.24, 0, 1.28), "tronco")

    for lado, s in (("E", 1), ("D", -1)):
        y = 0.13 * s
        m.osso(f"coxa.{lado}", (0.0, y, 0.5), (0.04, y, 0.28), "quadril")
        m.osso(f"canela.{lado}", (0.04, y, 0.28), (0.0, y, 0.06), f"coxa.{lado}")
        m.bola(0.15, (0.01, y, 0.38), la, f"coxa.{lado}", escala=(1, 0.9, 1.1))
        m.caixa_entre((0.03, y, 0.3), (0.0, y, 0.06), 0.09, 0.09, casco,
                      f"canela.{lado}")
        m.caixa((0.15, 0.12, 0.07), (0.04, y, 0.035), casco, f"canela.{lado}",
                topo=(0.8, 0.85))

    # massa de lã do corpo (vários tufos para a silhueta fofa)
    m.bola(0.34, (-0.02, 0, 0.66), la, "quadril", escala=(1.05, 0.95, 0.85),
           sub=2)
    m.bola(0.17, (-0.27, 0, 0.62), la_sombra, "quadril")

    # tabardo rasgado sobre o corpo, cinto, emblema na frente
    m.caixa((0.48, 0.5, 0.42), (0.04, 0, 0.72), tabardo, "tronco",
            topo=(0.85, 0.85), base=(1.05, 1.05))
    for i, x in enumerate((-0.15, 0.0, 0.15)):
        m.caixa((0.12, 0.5, 0.08 + 0.03 * (i % 2)), (x + 0.04, 0, 0.47),
                tabardo, "quadril")
    m.caixa((0.46, 0.5, 0.06), (0.04, 0, 0.74), couro, "tronco")
    m.caixa((0.02, 0.14, 0.15), (0.29, 0, 0.62), emblema, "tronco",
            topo=(1, 0.5))

    # peitoral e ombreiras de ferro
    m.caixa((0.38, 0.42, 0.26), (0.05, 0, 0.92), ferro, "tronco",
            topo=(0.9, 0.95))
    for s in (1, -1):
        m.bola(0.14, (0.02, 0.26 * s, 1.0), ferro, "tronco",
               escala=(1.1, 1, 0.8))
        m.bola(0.03, (0.04, 0.38 * s, 1.03), ferro_claro, "tronco", sub=1)

    # cabeça: tufo de lã, cara clara, focinho rosado, orelhas caídas, elmo
    m.bola(0.16, (0.13, 0, 1.12), la, "cabeca")
    m.caixa((0.2, 0.2, 0.2), (0.28, 0, 1.04), pele, "cabeca", topo=(0.9, 0.95))
    m.caixa((0.1, 0.15, 0.11), (0.41, 0, 1.0), focinho, "cabeca",
            topo=(0.8, 0.9))
    for s in (1, -1):
        m.caixa((0.05, 0.02, 0.05), (0.33, 0.1 * s, 1.08), olho, "cabeca")
        m.caixa((0.08, 0.17, 0.05), (0.18, 0.18 * s, 1.08), pele, "cabeca",
                rot=(30 * s, 0, 0))
    m.bola(0.21, (0.19, 0, 1.19), ferro, "cabeca", escala=(1.05, 1, 0.72), sub=2)
    m.cilindro(0.23, 0.23, 0.035, (0.19, 0, 1.16), ferro_claro, "cabeca",
               lados=10)
    m.caixa((0.035, 0.045, 0.12), (0.41, 0, 1.12), ferro_claro, "cabeca")
    m.cilindro(0.03, 0.0, 0.07, (0.19, 0, 1.36), ferro_claro, "cabeca")

    # lança na mão do lado da câmera, escudo no braço de longe
    lanca0 = Vector((-0.45, -0.3, 0.38))
    lanca1 = Vector((0.92, -0.3, 1.3))
    eixo = (lanca1 - lanca0).normalized()
    mao_lanca = lanca0 + (lanca1 - lanca0) * 0.55
    centro_escudo = Vector((0.4, -0.04, 0.72))

    bracos = {
        "D": ((0.02, -0.28, 0.98), (0.12, -0.34, 0.78), mao_lanca),
        "E": ((0.02, 0.28, 0.98), (0.14, 0.26, 0.74), centro_escudo
              + Vector((-0.08, 0.06, 0))),
    }
    for lado, (ombro, cotovelo, mao) in bracos.items():
        m.osso(f"braco.{lado}", ombro, cotovelo, "tronco")
        m.osso(f"antebraco.{lado}", cotovelo, mao, f"braco.{lado}")
        m.osso(f"mao.{lado}", mao, Vector(mao) + Vector((0.08, 0, 0)),
               f"antebraco.{lado}")
        m.bola(0.11, (Vector(ombro) + Vector(cotovelo)) / 2, la,
               f"braco.{lado}", escala=(1, 1, 1.3))
        m.caixa_entre(cotovelo, mao, 0.11, 0.11, couro, f"antebraco.{lado}")
        m.caixa((0.1, 0.1, 0.1), mao, casco, f"mao.{lado}")

    m.osso("lanca", lanca0, lanca1, "mao.D")
    m.cilindro_entre(lanca0, lanca1, 0.028, 0.028, madeira, "lanca", lados=5)
    m.cilindro_entre(lanca1, lanca1 + eixo * 0.06, 0.04, 0.04, ferro,
                     "lanca", lados=6)
    m.cilindro_entre(lanca1 + eixo * 0.06, lanca1 + eixo * 0.3, 0.06, 0.0,
                     lamina, "lanca", lados=4)

    m.osso("escudo", centro_escudo, centro_escudo + Vector((0.1, -0.1, 0)),
           "mao.E")
    rot_escudo = (0, 90, -40)  # disco virado para frente e um pouco para a câmera
    m.cilindro(0.29, 0.29, 0.035, centro_escudo, ferro, "escudo",
               rot=rot_escudo, lados=12)
    m.cilindro(0.26, 0.26, 0.06, centro_escudo, madeira, "escudo",
               rot=rot_escudo, lados=12)
    frente = Matrix.Rotation(math.radians(-40), 3, "Z") @ Vector((1, 0, 0))
    m.bola(0.07, centro_escudo + frente * 0.04, ferro_claro, "escudo")

    m.construir()
    exportar("ovelha")


# -------------------------------------------------------------- o rei dragão

def rei_dragao():
    """Rei Dragão, o chefe: dragão vermelho de pé, barriga dourada, coroa,
    manto roxo com gola de arminho, asas erguidas e a lança de Odin.
    Altura ~3,4 m até a ponta da asa."""
    verm = material("dragao_vermelho", "#a5272b")
    verm_esc = material("dragao_vermelho_escuro", "#6c1a1e")
    barriga = material("dragao_barriga", "#caa35b")
    barriga_esc = material("dragao_barriga_escura", "#9a773c")
    membrana = material("dragao_membrana", "#8c2e2c", dupla_face=True)
    ouro = material("dragao_ouro", "#e2b33b")
    ouro_esc = material("dragao_ouro_escuro", "#a67e1f")
    roxo = material("dragao_manto", "#5c2d84")
    roxo_esc = material("dragao_manto_escuro", "#3e1f5b")
    arminho = material("dragao_arminho", "#ede7db")
    pinta = material("dragao_pinta", "#1d1b1b")
    garra = material("dragao_garra", "#e6dac0")
    joia = material("dragao_joia", "#c81f2a")
    olho = material("dragao_olho", "#f3d24b")

    m = Modelo("rei_dragao")
    m.osso("quadril", (0, 0, 1.1), (0.05, 0, 1.5))
    m.osso("tronco", (0.05, 0, 1.5), (0.15, 0, 2.15), "quadril")
    m.osso("pescoco", (0.2, 0, 2.15), (0.5, 0, 2.6), "tronco")
    m.osso("cabeca", (0.5, 0, 2.6), (0.95, 0, 2.72), "pescoco")

    # tronco, quadril e placas da barriga
    m.caixa((0.72, 0.66, 0.45), (0.0, 0, 1.25), verm, "quadril")
    m.caixa((0.66, 0.66, 0.8), (0.08, 0, 1.8), verm, "tronco", rot=(0, 12, 0),
            topo=(0.85, 0.9))
    for i in range(6):
        z = 1.2 + i * 0.17
        x = 0.33 + i * 0.03
        m.caixa((0.08, 0.42 - i * 0.02, 0.14), (x, 0, z),
                barriga if i % 2 == 0 else barriga_esc,
                "quadril" if i < 2 else "tronco", rot=(0, 12, 0))

    # pernas grossas de dragão, com garras
    for lado, s in (("E", 1), ("D", -1)):
        y = 0.3 * s
        m.osso(f"coxa.{lado}", (0.0, y, 1.2), (0.2, y, 0.7), "quadril")
        m.osso(f"canela.{lado}", (0.2, y, 0.7), (-0.02, y, 0.18), f"coxa.{lado}")
        m.osso(f"pe.{lado}", (-0.02, y, 0.12), (0.3, y, 0.06), f"canela.{lado}")
        m.caixa_entre((-0.02, y, 1.28), (0.2, y, 0.68), 0.42, 0.3, verm,
                      f"coxa.{lado}", topo=(0.7, 0.8))
        m.caixa_entre((0.2, y, 0.72), (-0.02, y, 0.14), 0.2, 0.2, verm_esc,
                      f"canela.{lado}")
        m.caixa((0.38, 0.24, 0.12), (0.12, y, 0.06), verm_esc, f"pe.{lado}",
                topo=(0.9, 0.9))
        for dy in (-0.08, 0, 0.08):
            m.cilindro_entre((0.3, y + dy, 0.05), (0.42, y + dy, 0.02), 0.035,
                             0.0, garra, f"pe.{lado}", lados=4)

    # rabo longo que encosta no chão e sobe na ponta, com espinhos
    pontos_rabo = [(-0.3, 0, 1.15), (-0.75, 0, 0.8), (-1.25, 0, 0.42),
                   (-1.75, 0, 0.22), (-2.2, 0, 0.3), (-2.5, 0, 0.55)]
    raios_rabo = [0.3, 0.24, 0.17, 0.11, 0.07, 0.03]
    pai = "quadril"
    nomes = []
    for i in range(len(pontos_rabo) - 1):
        nome = f"rabo.{i + 1}"
        m.osso(nome, pontos_rabo[i], pontos_rabo[i + 1], pai)
        nomes.append(nome)
        pai = nome
    m.tubo(pontos_rabo, raios_rabo, verm, nomes, lados=6)
    for i in range(len(pontos_rabo) - 1):
        a, b = Vector(pontos_rabo[i]), Vector(pontos_rabo[i + 1])
        c = (a + b) / 2 + Vector((0, 0, raios_rabo[i] * 0.85))
        m.cilindro_entre(c, c + Vector((-0.08, 0, 0.12 * (1 - i * 0.15))),
                         0.05 * (1 - i * 0.15), 0.0, verm_esc, nomes[i], lados=4)
    m.cilindro_entre((-2.5, 0, 0.55), (-2.68, 0, 0.72), 0.08, 0.0, verm_esc,
                     "rabo.5", lados=4)

    # pescoço e cabeça
    m.tubo([(0.18, 0, 2.05), (0.4, 0, 2.42), (0.56, 0, 2.66)],
           [0.24, 0.2, 0.17], verm, "pescoco", lados=7)
    for i, (x, z) in enumerate(((0.38, 2.22), (0.5, 2.42))):
        m.caixa((0.08, 0.26, 0.14), (x, 0, z), barriga, "pescoco",
                rot=(0, 30, 0))
    m.caixa((0.36, 0.32, 0.3), (0.64, 0, 2.76), verm, "cabeca")
    m.caixa((0.36, 0.24, 0.17), (0.93, 0, 2.73), verm, "cabeca",
            topo=(0.9, 0.85))
    m.caixa((0.32, 0.2, 0.08), (0.9, 0, 2.6), verm_esc, "cabeca", rot=(0, -8, 0))
    m.caixa((0.06, 0.18, 0.08), (1.09, 0, 2.76), verm_esc, "cabeca")
    m.caixa((0.16, 0.34, 0.06), (0.74, 0, 2.89), verm_esc, "cabeca",
            rot=(0, 14, 0))
    for s in (1, -1):
        m.caixa((0.07, 0.02, 0.05), (0.78, 0.161 * s, 2.82), olho, "cabeca")
        m.tubo([(0.58, 0.12 * s, 2.86), (0.42, 0.14 * s, 2.98),
                (0.24, 0.15 * s, 2.98), (0.12, 0.15 * s, 2.9)],
               [0.06, 0.045, 0.03, 0.01], garra, "cabeca", lados=5)
        # babados das bochechas
        m.cilindro_entre((0.55, 0.15 * s, 2.7), (0.4, 0.2 * s, 2.6), 0.05,
                         0.0, verm_esc, "cabeca", lados=4)
    # coroa: aro dourado, cinco pontas e joias vermelhas
    m.cilindro(0.17, 0.19, 0.1, (0.6, 0, 2.96), ouro, "cabeca", lados=8)
    for i in range(5):
        a = math.radians(i * 72)
        p = Vector((0.6 + 0.15 * math.cos(a), 0.15 * math.sin(a), 3.06))
        m.cilindro_entre(p, p + Vector((0, 0, 0.12)), 0.04, 0.0, ouro,
                         "cabeca", lados=4)
        m.bola(0.025, Vector((0.6 + 0.18 * math.cos(a), 0.18 * math.sin(a),
                              2.96)), joia, "cabeca", sub=1)

    # manto roxo: costas e laterais, com barra dourada e gola de arminho
    m.caixa((0.12, 0.84, 1.25), (-0.33, 0, 1.55), roxo, "tronco",
            rot=(0, 10, 0), base=(1, 1.12))
    for s in (1, -1):
        m.caixa((0.42, 0.06, 1.15), (-0.12, 0.38 * s, 1.58), roxo, "tronco",
                rot=(0, 10, 0), base=(1.15, 1))
        m.caixa((0.05, 0.065, 1.1), (0.09, 0.385 * s, 1.6), ouro_esc, "tronco",
                rot=(0, 10, 0))
        m.caixa((0.48, 0.065, 0.05), (-0.16, 0.385 * s, 0.98), ouro_esc,
                "tronco", rot=(0, 10, 0))
    m.caixa((0.14, 0.8, 0.05), (-0.42, 0, 0.94), roxo_esc, "tronco")
    m.cilindro(0.48, 0.38, 0.2, (0.12, 0, 2.18), arminho, "tronco",
               rot=(0, 12, 0), lados=9)
    for i in range(7):
        a = math.radians(i * 360 / 7 + 15)
        p = Vector((0.12 + 0.44 * math.cos(a), 0.44 * math.sin(a), 2.17))
        m.caixa((0.04, 0.04, 0.07), p, pinta, "tronco", rot=(0, 0, math.degrees(a)))

    # braços: o da câmera segura a lança de Odin em pé
    lanca_x, lanca_y = 0.78, -0.42
    bracos = {
        "D": ((0.22, -0.38, 2.02), (0.36, -0.48, 1.72), (lanca_x, lanca_y, 1.82)),
        "E": ((0.22, 0.38, 2.02), (0.4, 0.44, 1.7), (0.58, 0.32, 1.86)),
    }
    for lado, (ombro, cotovelo, mao) in bracos.items():
        m.osso(f"braco.{lado}", ombro, cotovelo, "tronco")
        m.osso(f"antebraco.{lado}", cotovelo, mao, f"braco.{lado}")
        m.osso(f"mao.{lado}", mao, Vector(mao) + Vector((0.1, 0, 0)),
               f"antebraco.{lado}")
        m.bola(0.15, ombro, verm, f"braco.{lado}")
        m.caixa_entre(ombro, cotovelo, 0.18, 0.18, verm, f"braco.{lado}")
        m.caixa_entre(cotovelo, mao, 0.15, 0.15, verm, f"antebraco.{lado}")
        m.caixa((0.15, 0.14, 0.15), mao, verm_esc, f"mao.{lado}")
        for dz in (-0.05, 0.05):
            m.cilindro_entre(Vector(mao) + Vector((0.06, 0, dz)),
                             Vector(mao) + Vector((0.14, 0, dz - 0.03)),
                             0.025, 0.0, garra, f"mao.{lado}", lados=4)

    base_lanca = Vector((lanca_x, lanca_y, 0.08))
    topo_lanca = Vector((lanca_x, lanca_y, 3.05))
    m.osso("lanca_odin", base_lanca, topo_lanca, "mao.D")
    m.cilindro_entre(base_lanca, topo_lanca, 0.035, 0.035, ouro_esc,
                     "lanca_odin", lados=6)
    m.cilindro_entre(base_lanca - Vector((0, 0, 0.06)), base_lanca, 0.0, 0.05,
                     ouro, "lanca_odin", lados=4)
    m.cilindro(0.09, 0.05, 0.1, topo_lanca + Vector((0, 0, 0.02)), ouro,
               "lanca_odin", lados=6)
    m.bola(0.05, topo_lanca + Vector((0, 0, 0.1)), joia, "lanca_odin")
    m.cilindro_entre(topo_lanca + Vector((0, 0, 0.12)),
                     topo_lanca + Vector((0, 0, 0.5)), 0.08, 0.0, ouro,
                     "lanca_odin", lados=4)
    for s in (1, -1):  # aletas da ponta
        m.cilindro_entre(topo_lanca + Vector((0, 0, 0.1)),
                         topo_lanca + Vector((0.12 * s, 0, 0.0)), 0.025, 0.0,
                         ouro, "lanca_odin", lados=4)

    # asas erguidas atrás do corpo: braço ósseo, dedos e membrana
    for lado, s, ajuste in (("E", 1, 0.12), ("D", -1, 0.0)):
        y = 0.45 * s
        ombro = Vector((-0.05, y * 0.8, 2.15))
        cotovelo = Vector((-0.35, y, 2.85 + ajuste))
        pulso = Vector((-0.55, y * 1.05, 3.45 + ajuste))
        pontas = [Vector((-1.35, y * 1.1, 3.05 + ajuste)),
                  Vector((-1.3, y * 1.1, 2.35 + ajuste)),
                  Vector((-0.85, y * 1.05, 1.85 + ajuste * 0.5))]
        raiz = Vector((-0.3, y * 0.85, 1.75))
        m.osso(f"asa.{lado}", ombro, cotovelo, "tronco")
        m.osso(f"asa_ponta.{lado}", cotovelo, pulso, f"asa.{lado}")
        m.tubo([ombro, cotovelo, pulso], [0.09, 0.07, 0.05], verm_esc,
               [f"asa.{lado}", f"asa_ponta.{lado}"])
        m.cilindro_entre(pulso, pulso + Vector((0.08, 0, 0.14)), 0.04, 0.0,
                         garra, f"asa_ponta.{lado}", lados=4)
        for p in pontas:
            m.cilindro_entre(pulso, p, 0.035, 0.015, verm_esc,
                             f"asa_ponta.{lado}", lados=4)
        pts = [ombro, cotovelo, pulso, *pontas, raiz]
        faces = [(2, 3, 4), (2, 4, 5), (1, 2, 5), (1, 5, 6), (0, 1, 6)]
        m.lamina(pts, faces, membrana, f"asa_ponta.{lado}")

    m.construir()
    exportar("rei_dragao")


if __name__ == "__main__":
    for gerar in (bode, ovelha, rei_dragao):
        limpar_cena()
        gerar()
    print("modelos gerados em", SAIDA_GLB)
