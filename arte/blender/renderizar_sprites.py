"""Renderiza sprites 2D dos modelos 3D dos personagens (visual 2.5D).

O modelo olha para +X com os pés na origem; o lado da câmera do jogo é -Y
no Blender. A câmera do sprite fica desse lado, ortográfica, inclinada para
baixo como a câmera do jogo, e enquadra a origem (os pés) no centro da
borda de baixo, a FOOT_MARGIN_PX do fim da imagem. Fundo transparente.

Uso, com o bpy do pip (Python 3.11) ou com o Blender:
    python arte/blender/renderizar_sprites.py <modelo> <animacao> <quadros>
    python arte/blender/renderizar_sprites.py bode_hd parado 1

Saída: assets/sprites/<personagem>/<animacao>_<NN>.png, onde <personagem> é
o nome do modelo sem o sufixo (_hd, _voxel). Sem ação no modelo (os modelos
ainda não têm animação), todos os quadros saem na pose de repouso.
"""

import math
import os
import sys

import bpy
from mathutils import Euler, Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELOS = os.path.join(RAIZ, "assets", "modelos", "personagens")
SPRITES = os.path.join(RAIZ, "assets", "sprites")

INCLINACAO_GRAUS = 12.0
PX_POR_METRO = 160
LARGURA_M = 3.2
ALTURA_M = 2.4
FOOT_MARGIN_PX = 16
SUFIXOS = ("_hd", "_voxel")


def personagem_de(modelo):
    for s in SUFIXOS:
        if modelo.endswith(s):
            return modelo[: -len(s)]
    return modelo


def preparar_cena(modelo):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELOS, modelo + ".glb"))
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 48
    cena.cycles.use_denoising = False
    cena.render.film_transparent = True
    cena.render.resolution_x = int(LARGURA_M * PX_POR_METRO)
    cena.render.resolution_y = int(ALTURA_M * PX_POR_METRO)
    cena.render.resolution_percentage = 100
    cena.render.image_settings.file_format = "PNG"
    cena.render.image_settings.color_mode = "RGBA"
    cena.view_settings.view_transform = "Standard"  # cor chapada, sem Filmic
    # céu cinza-claro só para luz ambiente (o fundo sai transparente)
    mundo = bpy.data.worlds.new("Mundo")
    mundo.use_nodes = True
    fundo = mundo.node_tree.nodes["Background"]
    fundo.inputs[0].default_value = (0.55, 0.6, 0.7, 1)
    fundo.inputs[1].default_value = 0.9
    cena.world = mundo
    # sol de cima, um pouco à esquerda e à frente (lado da câmera)
    sol = bpy.data.objects.new("Sol", bpy.data.lights.new("Sol", "SUN"))
    sol.data.energy = 3.0
    sol.data.angle = math.radians(8)
    sol.rotation_euler = Euler((math.radians(40), math.radians(-25), math.radians(-20)))
    cena.collection.objects.link(sol)
    cena.camera = criar_camera(cena)
    return cena


def criar_camera(cena):
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(LARGURA_M, ALTURA_M)
    cam.data.clip_start = 0.1
    cam.data.clip_end = 50
    # câmera do Blender olha para -Z local; (90°, 0, 0) olha para +Y.
    # Tirar a inclinação de X faz ela olhar um pouco para baixo.
    rot = Euler((math.radians(90 - INCLINACAO_GRAUS), 0, 0))
    cam.rotation_euler = rot
    m = rot.to_matrix()
    frente = m @ Vector((0, 0, -1))
    cima = m @ Vector((0, 1, 0))
    # a origem tem de projetar a (ALTURA_M/2 - margem) abaixo do centro
    abaixo = ALTURA_M / 2 - FOOT_MARGIN_PX / PX_POR_METRO
    cam.location = cima * abaixo - frente * 10.0
    cena.collection.objects.link(cam)
    return cam


def renderizar(modelo, animacao, quadros):
    cena = preparar_cena(modelo)
    pasta = os.path.join(SPRITES, personagem_de(modelo))
    os.makedirs(pasta, exist_ok=True)
    acao = bpy.data.actions.get(animacao)
    arm = next((o for o in cena.objects if o.type == "ARMATURE"), None)
    if acao and arm:
        arm.animation_data_create().action = acao
        ini, fim = acao.frame_range
    else:
        ini, fim = 1, 1
    saidas = []
    for i in range(quadros):
        t = ini + (fim - ini) * i / max(quadros - 1, 1) if quadros > 1 else ini
        cena.frame_set(int(round(t)))
        caminho = os.path.join(pasta, f"{animacao}_{i:02d}.png")
        cena.render.filepath = caminho
        bpy.ops.render.render(write_still=True)
        saidas.append(caminho)
    return saidas


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    modelo = args[0] if args else "bode_hd"
    animacao = args[1] if len(args) > 1 else "parado"
    quadros = int(args[2]) if len(args) > 2 else 1
    for p in renderizar(modelo, animacao, quadros):
        print("sprite:", os.path.relpath(p, RAIZ))
