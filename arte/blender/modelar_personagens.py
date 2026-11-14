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

Gera três versões de cada personagem:
- voxel (sufixo _voxel): as mesmas formas preenchidas numa grade de cubos
  de 2,2 cm, com sombra de contato e variação de tom por voxel. É a que o jogo usa;
- HD (sufixo _hd): lisa, com chanfros redondos, mais segmentos e curvas
  suaves nos chifres e no rabo;
- low-poly facetada (sem sufixo), do antigo render pixel 320x180.

Saídas:
    arte/blender/<nome>[_hd|_voxel].blend               arquivo editável
    assets/modelos/personagens/<nome>[_hd|_voxel].glb   o que o Godot importa
"""

import math
import os

import bpy  # precisa vir antes do bmesh no módulo do pip
import bmesh
from mathutils import Euler, Matrix, Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SAIDA_BLEND = os.path.join(RAIZ, "arte", "blender")
SAIDA_GLB = os.path.join(RAIZ, "assets", "modelos", "personagens")

# HD = versão lisa e arredondada (mais segmentos, chanfro redondo, normais
# suaves). Sem HD = versão low-poly facetada para o render pixel 320x180.
HD = False

# VOXEL = versão em voxels (cubos de VOXEL_TAM metros). Usa as mesmas
# formas do modelo, preenchidas numa grade; detalhes menores que um voxel
# viram um voxel só, para não sumirem.
VOXEL = False
VOXEL_TAM = 0.022


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


def _lados(n):
    """No HD, cilindros e cones ganham bem mais lados."""
    return max(n * 3, 14) if HD else n


def _suavizar(pontos, raios, ossos, passos=4):
    """Curva Catmull-Rom pelos pontos do tubo (chifres e rabo no HD)."""
    P = [Vector(p) for p in pontos]
    n = len(P)
    novos, rs, os_ = [], [], []
    for i in range(n - 1):
        p0, p1 = P[max(i - 1, 0)], P[i]
        p2, p3 = P[i + 1], P[min(i + 2, n - 1)]
        for k in range(passos):
            t = k / passos
            t2, t3 = t * t, t * t * t
            novos.append(0.5 * ((2 * p1) + (-p0 + p2) * t
                                + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                                + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
            rs.append(raios[i] + (raios[i + 1] - raios[i]) * t)
            os_.append(ossos if isinstance(ossos, str) else ossos[i])
    novos.append(P[-1])
    rs.append(raios[-1])
    return novos, rs, (ossos if isinstance(ossos, str) else os_)


class Modelo:
    """Junta primitivas numa malha só, com material e osso por peça."""

    def __init__(self, nome):
        self.nome = nome
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.mats = []
        self.ossos = []  # (nome, cabeça, cauda, pai)
        self.pecas_voxel = []

    # -- esqueleto
    def osso(self, nome, cabeca, cauda, pai=None):
        self.ossos.append((nome, Vector(cabeca), Vector(cauda), pai))
        return nome

    def _indice_osso(self, nome):
        return [o[0] for o in self.ossos].index(nome)

    # -- fechamento de cada peça
    def _copiar(self, t, matriz, mat, osso, chanfro=0.0):
        """Copia a peça montada no bmesh temporário `t` para a malha final,
        com chanfro opcional nas arestas (tira a cara de caixote)."""
        if VOXEL:
            self._registrar_voxel(t, matriz, mat, osso)
            t.free()
            return
        if chanfro > 0:
            bmesh.ops.bevel(t, geom=list(t.verts) + list(t.edges),
                            offset=chanfro * (2.4 if HD else 1.0),
                            offset_type="OFFSET", segments=3 if HD else 1,
                            profile=0.5, affect="EDGES", clamp_overlap=True)
        if mat not in self.mats:
            self.mats.append(mat)
        mi = self.mats.index(mat)
        bi = self._indice_osso(osso)
        mapa = {}
        for v in t.verts:
            nv = self.bm.verts.new(matriz @ v.co)
            nv[self.deform][bi] = 1.0
            mapa[v] = nv
        for f in t.faces:
            nf = self.bm.faces.new([mapa[v] for v in f.verts])
            nf.material_index = mi
            nf.smooth = HD
        t.free()

    def _registrar_voxel(self, t, matriz, mat, osso):
        """Guarda a peça como volume convexo (planos) ou lâmina (triângulos)
        para preencher a grade de voxels no fim."""
        if mat not in self.mats:
            self.mats.append(mat)
        mi = self.mats.index(mat)
        bi = self._indice_osso(osso)
        pts = [matriz @ v.co for v in t.verts]
        idx = {v: i for i, v in enumerate(t.verts)}
        aberta = any(e.is_boundary for e in t.edges)
        if aberta:
            tris = []
            for f in t.faces:
                vs = [pts[idx[v]] for v in f.verts]
                for k in range(1, len(vs) - 1):
                    tris.append((vs[0], vs[k], vs[k + 1]))
            self.pecas_voxel.append(("lamina", tris, pts, mi, bi))
            return
        centro = sum(pts, Vector()) / len(pts)
        planos = []
        for f in t.faces:
            vs = [pts[idx[v]] for v in f.verts]
            n = (vs[1] - vs[0]).cross(vs[2] - vs[0])
            if n.length < 1e-12:
                continue
            n.normalize()
            if n.dot(vs[0] - centro) < 0:
                n = -n
            planos.append((n.x, n.y, n.z, n.dot(vs[0])))
        self.pecas_voxel.append(("volume", planos, pts, mi, bi))

    def _voxelizar(self):
        """Preenche a grade e devolve a malha de cubos (só faces à mostra)."""
        import numpy as np
        V = VOXEL_TAM
        todos = np.array([p[:] for peca in self.pecas_voxel for p in peca[2]])
        lo = np.floor(todos.min(0) / V).astype(int) - 2
        hi = np.ceil(todos.max(0) / V).astype(int) + 2
        dim = hi - lo
        grade = np.full(dim, -1, dtype=np.int32)      # material
        ossos = np.full(dim, -1, dtype=np.int32)      # osso
        folga = 0.25 * V
        for tipo, dados, pts, mi, bi in self.pecas_voxel:
            P = np.array([p[:] for p in pts])
            a = np.floor(P.min(0) / V).astype(int) - 1 - lo
            b = np.ceil(P.max(0) / V).astype(int) + 1 - lo
            a = np.clip(a, 0, dim - 1)
            b = np.clip(b, 1, dim)
            ii, jj, kk = np.meshgrid(*[np.arange(a[d], b[d]) for d in range(3)],
                                     indexing="ij")
            cel = np.stack([ii.ravel(), jj.ravel(), kk.ravel()], 1)
            c = (cel + lo + 0.5) * V
            if tipo == "volume":
                pl = np.array(dados)
                dist = c @ pl[:, :3].T - pl[:, 3]
                dentro = dist.max(1) <= folga
            else:
                dentro = np.zeros(len(c), bool)
                for t0, t1, t2 in dados:
                    A, B, C = (np.array(t0[:]), np.array(t1[:]), np.array(t2[:]))
                    n = np.cross(B - A, C - A)
                    ln = np.linalg.norm(n)
                    if ln < 1e-12:
                        continue
                    n /= ln
                    d = (c - A) @ n
                    q = c - np.outer(d, n)
                    v0, v1, v2 = B - A, C - A, q - A
                    d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
                    d20, d21 = v2 @ v0, v2 @ v1
                    den = d00 * d11 - d01 * d01
                    bv = (d11 * d20 - d01 * d21) / den
                    bw = (d00 * d21 - d01 * d20) / den
                    m = 0.08
                    dentro |= ((np.abs(d) <= 0.55 * V) & (bv >= -m) & (bw >= -m)
                               & (bv + bw <= 1 + m))
            sel = cel[dentro]
            if len(sel) == 0:  # detalhe pequeno: um voxel no centro
                cc = np.floor(P.mean(0) / V).astype(int) - lo
                sel = cc[None, :]
            grade[sel[:, 0], sel[:, 1], sel[:, 2]] = mi
            ossos[sel[:, 0], sel[:, 1], sel[:, 2]] = bi

        cheio = grade >= 0
        verts, faces, mats, vossos, cores = [], [], [], [], []
        # (direção, 4 cantos da face no cubo unitário, em ordem anti-horária)
        lados = [
            ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
            ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
            ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
            ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
            ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
            ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
        ]
        pad_g = np.pad(grade, 1, constant_values=-1)
        pad_o = np.pad(ossos, 1, constant_values=-1)
        idx = np.argwhere(cheio)
        for d, cantos in lados:
            viz = idx + 1 + np.array(d)
            vg = pad_g[viz[:, 0], viz[:, 1], viz[:, 2]]
            vo = pad_o[viz[:, 0], viz[:, 1], viz[:, 2]]
            meu_o = ossos[idx[:, 0], idx[:, 1], idx[:, 2]]
            mostra = (vg < 0) | (vo != meu_o)  # entre ossos fica a face
            sel = idx[mostra]
            base = len(verts) if not verts else sum(len(v) for v in verts)
            n = len(sel)
            if n == 0:
                continue
            cs = np.array(cantos)
            vv = ((sel[:, None, :] + lo + cs[None, :, :]) * V).reshape(-1, 3)
            verts.append(vv)
            cores.append(self._luz_voxel(pad_g, sel, np.array(d), cs, lo))
            faces.append(base + np.arange(n * 4).reshape(n, 4))
            mats.append(grade[sel[:, 0], sel[:, 1], sel[:, 2]])
            vossos.append(np.repeat(ossos[sel[:, 0], sel[:, 1], sel[:, 2]], 4))
        return (np.concatenate(verts), np.concatenate(faces),
                np.concatenate(mats), np.concatenate(vossos), int(cheio.sum()),
                np.concatenate(cores))

    @staticmethod
    def _luz_voxel(pad_g, sel, d, cantos, lo):
        """Brilho por vértice: sombra de contato (oclusão nos cantos, como em
        jogos de voxel) vezes uma variação leve de tom por voxel."""
        import numpy as np
        ocupado = lambda q: pad_g[q[:, 0], q[:, 1], q[:, 2]] >= 0
        eixo = int(np.nonzero(d)[0][0])
        t1, t2 = [a for a in range(3) if a != eixo]
        frente = sel + 1 + d  # vizinho à frente da face (na grade com borda)
        nivel = np.array([0.5, 0.68, 0.84, 1.0])
        brilho = np.empty((len(sel), 4))
        for k, c in enumerate(cantos):
            s1 = np.zeros(3, int)
            s2 = np.zeros(3, int)
            s1[t1] = 1 if c[t1] else -1
            s2[t2] = 1 if c[t2] else -1
            a = ocupado(frente + s1)
            b = ocupado(frente + s2)
            q = ocupado(frente + s1 + s2)
            ao = np.where(a & b, 0, 3 - (a.astype(int) + b + q))
            brilho[:, k] = nivel[ao]
        # variação de tom estável por voxel (hash da posição)
        g = (sel + lo).astype(np.int64)
        h = (g[:, 0] * 73856093) ^ (g[:, 1] * 19349663) ^ (g[:, 2] * 83492791)
        ruido = 0.88 + 0.12 * ((h & 1023) / 1023.0)
        # o glTF guarda a cor em inteiro normalizado: acima de 1 dá a volta
        brilho = np.clip(brilho * ruido[:, None], 0.0, 1.0)
        return np.repeat(brilho.reshape(-1, 1), 3, 1).reshape(-1, 3)

    @staticmethod
    def _chanfro(*medidas, frac=0.16):
        return max(0.0, min(m for m in medidas if m > 0) * frac)

    # -- primitivas
    def caixa(self, tam, loc, mat, osso, rot=(0, 0, 0), topo=(1, 1),
              base=(1, 1), desloc_topo=(0, 0), chanfro=True):
        """Caixa com afunilamento opcional no topo (+Z local) e na base."""
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        for v in t.verts:
            k = topo if v.co.z > 0 else base
            v.co.x *= tam[0] * k[0]
            v.co.y *= tam[1] * k[1]
            v.co.z *= tam[2]
            if v.co.z > 0:
                v.co.x += desloc_topo[0]
                v.co.y += desloc_topo[1]
        c = self._chanfro(*tam) if chanfro else 0.0
        self._copiar(t, mat4(loc, rot), mat, osso, c)

    def caixa_entre(self, p0, p1, larg, prof, mat, osso, topo=(1, 1),
                    chanfro=True):
        """Caixa esticada de p0 a p1 (membros, cabos)."""
        m, comp = alinhar(p0, p1)
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        for v in t.verts:
            k = topo if v.co.z > 0 else (1, 1)
            v.co.x *= larg * k[0]
            v.co.y *= prof * k[1]
            v.co.z *= comp
        c = self._chanfro(larg, prof, comp) if chanfro else 0.0
        self._copiar(t, m, mat, osso, c)

    def cilindro(self, r1, r2, alt, loc, mat, osso, rot=(0, 0, 0), lados=8,
                 escala=(1, 1, 1)):
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=True, cap_tris=False,
                              segments=_lados(lados), radius1=r1, radius2=r2,
                              depth=alt)
        self._copiar(t, mat4(loc, rot, escala), mat, osso)

    def cilindro_entre(self, p0, p1, r0, r1, mat, osso, lados=8):
        m, comp = alinhar(p0, p1)
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=True, cap_tris=False,
                              segments=_lados(lados), radius1=r0, radius2=r1,
                              depth=comp)
        self._copiar(t, m, mat, osso)

    def bola(self, r, loc, mat, osso, escala=(1, 1, 1), rot=(0, 0, 0), sub=2):
        t = bmesh.new()
        bmesh.ops.create_icosphere(t, subdivisions=min(sub + 2, 4) if HD
                                   else sub, radius=r)
        self._copiar(t, mat4(loc, rot, escala), mat, osso)

    def tubo(self, pontos, raios, mat, ossos, lados=8, juntas=True):
        """Corrente de troncos de cone (chifres, rabo). `ossos` pode ser um
        nome só ou uma lista com um osso por trecho. Bolinhas nas juntas
        escondem as emendas. No HD o caminho vira curva suave."""
        if HD:
            pontos, raios, ossos = _suavizar(pontos, raios, ossos)
        for i in range(len(pontos) - 1):
            osso = ossos if isinstance(ossos, str) else ossos[i]
            self.cilindro_entre(pontos[i], pontos[i + 1], raios[i],
                                raios[i + 1], mat, osso, lados)
            if juntas and 0 < i and raios[i] > 0.02:
                self.bola(raios[i] * 0.98, pontos[i], mat, osso, sub=1)

    def tufo(self, base, direcao, larg, mat, osso, lados=4):
        """Ponta de pelo / espinho: cone fino saindo de `base`."""
        base = Vector(base)
        self.cilindro_entre(base, base + Vector(direcao), larg, 0.0, mat, osso,
                            lados)

    def lamina(self, pontos, faces, mat, osso):
        """Superfície fina feita à mão (membrana da asa)."""
        t = bmesh.new()
        vs = [t.verts.new(Vector(p)) for p in pontos]
        for f in faces:
            t.faces.new([vs[i] for i in f])
        self._copiar(t, Matrix.Identity(4), mat, osso)

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

        me = bpy.data.meshes.new(self.nome + "_malha")
        if VOXEL:
            import numpy as np
            verts, faces, mats, vossos, n, cores = self._voxelizar()
            print(f"{self.nome}: {n} voxels, {len(faces)} faces")
            me.from_pydata([tuple(v) for v in verts], [],
                           [tuple(f) for f in faces])
            me.polygons.foreach_set("material_index", mats.astype(int).tolist())
            cor = me.color_attributes.new("Luz", "FLOAT_COLOR", "POINT")
            rgba = np.ones((len(cores), 4))
            rgba[:, :3] = cores
            cor.data.foreach_set("color", rgba.ravel().tolist())
            me.update()
        else:
            bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
            bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
            self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        malha = bpy.data.objects.new(self.nome + "_malha", me)
        col.objects.link(malha)
        for nome, *_ in self.ossos:
            malha.vertex_groups.new(name=nome)
        if VOXEL:
            import numpy as np
            for bi, vg in enumerate(malha.vertex_groups):
                ids = np.nonzero(vossos == bi)[0].tolist()
                if ids:
                    vg.add(ids, 1.0, "REPLACE")
        malha.parent = arm
        if HD:
            # bordas vivas acima de 40 graus e normais pesadas pela área:
            # faces grandes ficam retas e os chanfros ficam redondos
            me.set_sharp_from_angle(angle=math.radians(40))
            wn = malha.modifiers.new("Normais", "WEIGHTED_NORMAL")
            wn.keep_sharp = True
        mod = malha.modifiers.new("Esqueleto", "ARMATURE")
        mod.object = arm
        return arm, malha


def limpar_cena():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def exportar(nome):
    if HD:
        nome += "_hd"
    if VOXEL:
        nome += "_voxel"
    os.makedirs(SAIDA_BLEND, exist_ok=True)
    os.makedirs(SAIDA_GLB, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(
        filepath=os.path.join(SAIDA_BLEND, nome + ".blend"), compress=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(SAIDA_GLB, nome + ".glb"),
        export_format="GLB",
        export_apply=HD,
        export_skins=True,
        export_animations=False,
        export_yup=True,
        export_vertex_color="ACTIVE" if VOXEL else "MATERIAL",
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
    m.caixa((0.47, 0.64, 0.07), (0.05, 0, 1.0), couro, "tronco", rot=(38, 0, 0))
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


    # ---- detalhes (definição) ----
    chifre_esc = material("bode_chifre_anel", "#33271f")
    iris = material("bode_iris", "#c9963a")
    # peitoral e abdômen marcados
    for s in (1, -1):
        m.caixa((0.08, 0.2, 0.15), (0.3, 0.11 * s, 1.07), pelo, "tronco",
                rot=(0, -8, 0))
    for i, z in enumerate((0.92, 0.84)):
        for s in (1, -1):
            m.caixa((0.05, 0.1, 0.06), (0.31 - i * 0.01, 0.06 * s, z),
                    pelo_sombra, "tronco")
    # rebites na correia e no cinto (lado da câmera)
    for t in (-0.18, 0.0, 0.18):
        m.bola(0.022, (0.04 + t * 0.6, -0.33, 1.0 + t * 0.78), ferro,
               "tronco", sub=1)
    for x in (-0.15, 0.0, 0.15):
        m.bola(0.02, (x, -0.255, 0.75), ferro, "quadril", sub=1)
    # tiras do saiote e franja de pelo na barra
    for x in (-0.14, 0.02, 0.17):
        m.caixa((0.02, 0.012, 0.22), (x, -0.235, 0.58), couro_esc, "quadril",
                chanfro=False)
    for i in range(7):
        a = math.radians(i * 360 / 7)
        b = Vector((0.25 * math.cos(a), 0.23 * math.sin(a), 0.47))
        m.tufo(b, (0.02 * math.cos(a), 0.02 * math.sin(a), -0.07), 0.035,
               pelo_sombra, "quadril")
    # tufos de pelo nos ombros, cotovelos, tornozelos e bochechas
    for s, lado in ((1, "E"), (-1, "D")):
        for k in range(3):
            m.tufo((0.04 - 0.07 * k, 0.4 * s, 1.08 + 0.03 * k),
                   (-0.05, 0.03 * s, -0.08), 0.04, pelo_sombra, f"braco.{lado}")
        for k in range(4):
            a = math.radians(k * 90 + 45)
            m.tufo((0.0 + 0.09 * math.cos(a), 0.14 * s + 0.09 * math.sin(a),
                    0.12), (0.03 * math.cos(a), 0.03 * math.sin(a), -0.06),
                   0.03, pelo_sombra, f"canela.{lado}")
        m.caixa((0.02, 0.01, 0.06), (0.1, 0.14 * s - 0.075 * s, 0.045),
                couro_esc, f"pe.{lado}", chanfro=False)  # fenda do casco
        for k in range(3):
            m.tufo((0.18, 0.16 * s, 1.24 - 0.05 * k), (-0.06, 0.03 * s, -0.04),
                   0.035, pelo, "cabeca")
    # barba em mechas
    for k, (dx, dy) in enumerate(((0.0, 0.0), (0.04, 0.04), (0.04, -0.04),
                                  (-0.03, 0.05), (-0.03, -0.05))):
        m.tufo((0.31 + dx, dy, 1.04), (0.02, dy * 0.3, -0.14 + 0.02 * k),
               0.035, pelo_sombra, "cabeca")
    # rosto: íris âmbar, narinas, boca, pálpebra brava
    for s in (1, -1):
        m.caixa((0.035, 0.014, 0.03), (0.255, 0.174 * s, 1.37), iris,
                "cabeca", chanfro=False)
        m.caixa((0.016, 0.016, 0.026), (0.265, 0.18 * s, 1.37), olho,
                "cabeca", chanfro=False)
        m.caixa((0.02, 0.02, 0.025), (0.488, 0.035 * s, 1.31), olho,
                "cabeca", chanfro=False)
        m.caixa((0.14, 0.012, 0.012), (0.37, 0.101 * s, 1.215), olho,
                "cabeca", rot=(0, 6, 0), chanfro=False)
    # anéis nos chifres
    for s in (1, -1):
        for (x, y, z), r in (((0.075, 0.11 * s, 1.55), 0.072),
                             ((0.0, 0.13 * s, 1.68), 0.062),
                             ((-0.14, 0.145 * s, 1.745), 0.052),
                             ((-0.28, 0.155 * s, 1.7), 0.042)):
            m.bola(r, (x, y, z), chifre_esc, "cabeca", escala=(1, 1, 0.45),
                   sub=1)
    # braçadeiras com tiras e martelo com tiras em X e lascas
    for lado in ("D", "E"):
        cot, mao = bracos[lado][1], bracos[lado][2]
        for t in (0.45, 0.75):
            c = Vector(cot) + (Vector(mao) - Vector(cot)) * t
            m.cilindro_entre(c - Vector((0.015, 0, 0)), c + Vector((0.015, 0, 0)),
                             0.1, 0.1, couro_esc, f"antebraco.{lado}")
    face = centro + Vector((0, -0.165, 0))
    for s in ((1, -1) if not VOXEL else ()):  # tiras em X somem no voxel
        d = (perp * 0.22 + eixo * 0.12 * s)
        m.caixa_entre(face - d, face + d, 0.04, 0.012, couro, "martelo",
                      chanfro=False)
    for s in (1, -1):
        for e in (1, -1):
            q = centro + perp * 0.24 * s + eixo * 0.13 * e
            m.caixa((0.06, 0.06, 0.06), q + Vector((0, -0.15, 0)), pedra_esc,
                    "martelo", rot=(20 * e, 30 * s, 10))

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


    # ---- detalhes (definição) ----
    import random
    sorte = random.Random(7)
    branco = material("ovelha_olho_branco", "#f4efe6")
    # tufos de lã espalhados no corpo, nas pernas e nos braços
    for _ in range(26):
        a = sorte.uniform(0, 2 * math.pi)
        z = sorte.uniform(0.45, 0.8)
        r = 0.3 * (1 - abs(z - 0.66) * 1.4)
        p = (-0.02 + r * math.cos(a), 0.27 * math.sin(a), z)
        if p[0] > 0.22:
            continue
        m.bola(sorte.uniform(0.05, 0.07), p,
               la if (VOXEL or sorte.random() > 0.35) else la_sombra,
               "quadril", sub=1)
    for lado, s in (("E", 1), ("D", -1)):
        for k in range(5):
            a = k * 1.25
            m.bola(0.06, (0.01 + 0.11 * math.cos(a), 0.13 * s + 0.1 * math.sin(a),
                          0.3 + 0.04 * k), la_sombra if (k % 2 and not VOXEL) else la,
                   f"coxa.{lado}", sub=1)
        ombro, cot = bracos[lado][0], bracos[lado][1]
        for k in range(3):
            c = Vector(ombro) + (Vector(cot) - Vector(ombro)) * (0.25 + 0.3 * k)
            m.bola(0.07, c + Vector((0, 0.06 * s, 0)), la, f"braco.{lado}",
                   sub=1)
        m.caixa((0.015, 0.015, 0.05), (0.1, 0.13 * s - 0.06 * s, 0.035),
                ferro, f"canela.{lado}", chanfro=False)  # fenda do casco
    # olhos com branco e pupila, narinas, boca
    for s in (1, -1):
        m.caixa((0.055, 0.012, 0.045), (0.33, 0.106 * s, 1.08), branco,
                "cabeca", chanfro=False)
        m.caixa((0.022, 0.014, 0.03), (0.345, 0.11 * s, 1.078), olho,
                "cabeca", chanfro=False)
        m.caixa((0.015, 0.015, 0.02), (0.462, 0.03 * s, 1.03), olho,
                "cabeca", chanfro=False)
    m.caixa((0.06, 0.13, 0.012), (0.44, 0, 0.96), olho, "cabeca",
            chanfro=False)
    # elmo: rebites no aro, protetores de bochecha e faixa central
    for k in range(10):
        a = math.radians(k * 36)
        m.bola(0.016, (0.19 + 0.235 * math.cos(a), 0.235 * math.sin(a), 1.16),
               ferro, "cabeca", sub=1)
    for s in (1, -1):
        m.caixa((0.1, 0.03, 0.12), (0.26, 0.2 * s, 1.08), ferro, "cabeca",
                rot=(0, -10, 0))
    m.caixa((0.3, 0.05, 0.03), (0.19, 0, 1.33), ferro_claro, "cabeca",
            rot=(0, 0, 0))
    # tabardo: barra rasgada em pontas e brasão em forma de escudo
    for k in range(9):
        a = math.radians(k * 40 + 10)
        b = Vector((0.04 + 0.25 * math.cos(a), 0.25 * math.sin(a), 0.45))
        m.tufo(b, (0, 0, -0.06 - 0.04 * (k % 3)), 0.05, tabardo, "quadril",
               lados=3)
    m.tufo((0.302, 0, 0.56), (0, 0, -0.06), 0.06, emblema, "tronco", lados=3)
    # peitoral com rebites e cinto com fivela
    for z in (0.86, 0.98):
        for s in (1, -1):
            m.bola(0.016, (0.05, 0.215 * s, z), ferro_claro, "tronco", sub=1)
    m.caixa((0.03, 0.07, 0.06), (0.27, 0, 0.74), ferro_claro, "tronco")
    # escudo: tábuas e rebites na borda
    nrm = frente
    lado_esc = Matrix.Rotation(math.radians(-40), 3, "Z") @ Vector((0, 1, 0))
    for k in (-1, 1):
        c = centro_escudo + nrm * 0.032 + lado_esc * 0.09 * k
        m.caixa_entre(c - Vector((0, 0, 0.24)), c + Vector((0, 0, 0.24)), 0.012,
                      0.012, ferro, "escudo", chanfro=False)
    for k in range(0 if VOXEL else 10):  # rebites viram ruído no voxel
        a = math.radians(k * 36)
        p = (centro_escudo + nrm * 0.03 + lado_esc * 0.24 * math.cos(a)
             + Vector((0, 0, 0.24 * math.sin(a))))
        m.bola(0.015, p, ferro_claro, "escudo", sub=1)
    # lança: tiras de couro na pegada e amarração da ponta
    for t in (0.5, 0.6, 0.97):
        c = lanca0 + (lanca1 - lanca0) * t
        m.cilindro_entre(c - eixo * 0.02, c + eixo * 0.02, 0.036, 0.036,
                         couro, "lanca")

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
        m.caixa((0.025, 0.025, 0.05), p + Vector((0, 0, -0.03)), pinta, "tronco",
                rot=(0, 0, math.degrees(a)), chanfro=False)

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


    # ---- detalhes (definição) ----
    dente = material("dragao_dente", "#f2ead6")
    escama = material("dragao_escama", "#871f24")
    # dentes na boca
    for k in range(5):
        x = 0.8 + k * 0.06
        for s in (1, -1):
            m.tufo((x, 0.09 * s, 2.645), (0, 0, -0.05), 0.015, dente,
                   "cabeca", lados=3)
    m.tufo((1.03, -0.09, 2.66), (0.0, 0, -0.08), 0.02, dente, "cabeca",
           lados=3)
    # narina, sobrancelha, pupila
    for s in (1, -1):
        m.caixa((0.03, 0.02, 0.02), (1.1, 0.06 * s, 2.79), pinta, "cabeca",
                chanfro=False)
        m.caixa((0.02, 0.012, 0.045), (0.79, 0.168 * s, 2.82), pinta,
                "cabeca", chanfro=False)
    # crista de espinhos no pescoço, nas costas e no topo da cabeça
    for p, d in (((0.33, 0, 2.5), (-0.12, 0, 0.1)), ((0.21, 0, 2.3), (-0.14, 0, 0.1)),
                 ((0.47, 0, 2.7), (-0.12, 0, 0.1)), ((0.0, 0, 2.15), (-0.12, 0, 0.12))):
        m.tufo(p, d, 0.05, verm_esc, "pescoco" if p[0] > 0.1 else "tronco")
    # escamas em placas nas coxas e nos braços
    for lado, s in (("E", 1), ("D", -1)):
        for k in range(3):
            m.caixa((0.14, 0.03, 0.09), (0.04 + 0.06 * k, 0.455 * s,
                    1.15 - 0.15 * k), escama, f"coxa.{lado}", rot=(0, 20, 0))
        ombro, cot = bracos[lado][0], bracos[lado][1]
        c = (Vector(ombro) + Vector(cot)) / 2 + Vector((0, 0.09 * s, 0))
        m.caixa((0.1, 0.03, 0.08), c, escama, f"braco.{lado}")
        # esporão no calcanhar
        m.tufo((-0.08, 0.3 * s, 0.14), (-0.1, 0, -0.04), 0.035, garra,
               f"pe.{lado}")
    # dobras no manto e pintas de arminho na barra
    for k in range(3):
        for s in (1, -1):
            m.caixa((0.035, 0.07, 1.0), (-0.28 + 0.11 * k, 0.39 * s, 1.55),
                    roxo_esc, "tronco", rot=(0, 10, 0), chanfro=False)
    # ponta do rabo em lâmina
    m.lamina([(-2.45, 0, 0.5), (-2.75, 0, 0.82), (-2.5, 0, 0.75),
              (-2.65, 0, 0.55)], [(0, 3, 1, 2)], verm_esc, "rabo.5")
    # garras nas pontas dos dedos das asas
    for s in (1, -1):
        for p in ((-1.35, 0.5 * s, 3.05), (-1.3, 0.5 * s, 2.35)):
            m.tufo(p, (-0.06, 0, -0.08), 0.025, garra,
                   "asa_ponta." + ("E" if s > 0 else "D"))

    m.construir()
    exportar("rei_dragao")


if __name__ == "__main__":
    for HD, VOXEL in ((False, False), (True, False), (False, True)):
        for gerar in (bode, ovelha, rei_dragao):
            limpar_cena()
            gerar()
    print("modelos gerados em", SAIDA_GLB)
