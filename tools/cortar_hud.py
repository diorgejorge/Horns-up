# Corta as pecas da HUD marajoara (assets/diorge/HUD/*.jpeg) em PNGs com alpha.
# Uso: python cortar.py <pasta HUD> <pasta de saida>
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as nd

SRC, OUT = sys.argv[1].rstrip('/') + '/', sys.argv[2].rstrip('/') + '/'

def rgb(n): return np.asarray(Image.open(SRC + n).convert('RGB')).astype(np.int16)

def fundo_xadrez(a):
    """Fundo xadrez (transparencia falsa da imagem): neutro e escuro, ligado a borda."""
    mx, mn = a.max(2), a.min(2)
    neutro = (mx - mn < 28) & (mx < 120)
    lab, _ = nd.label(neutro)
    borda = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(borda))

def maior(m):
    lab, k = nd.label(m)
    if k == 0: return m
    s = nd.sum(m, lab, range(1, k + 1))
    return lab == (np.argmax(s) + 1)

def rgba(a, alfa, suave=1.2):
    al = Image.fromarray((alfa * 255).astype(np.uint8))
    if suave: al = al.filter(ImageFilter.GaussianBlur(suave))
    im = Image.fromarray(a.clip(0, 255).astype(np.uint8)).convert('RGBA')
    im.putalpha(al)
    return im

def arred(w, h, r):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), r, fill=255)
    return np.asarray(m) / 255.0

def salvar(im, nome, escala=None, alvo=None):
    if alvo:
        escala = alvo / max(im.size)
    if escala and escala != 1:
        im = im.resize((max(1, round(im.size[0] * escala)), max(1, round(im.size[1] * escala))), Image.LANCZOS)
    im.save(OUT + nome + '.png')
    print(nome, im.size)
    return im

# --- moldura de painel (janela de dialogo) com o miolo de pergaminho limpo ---------------
a = rgb('janela de dialogo.jpeg')
bg = fundo_xadrez(a)
x0, x1, y0, y1 = 345, 2393, 154, 1340
f = a[y0:y1, x0:x1].copy()
alfa = (~bg[y0:y1, x0:x1]).astype(float)
alfa = nd.binary_opening(alfa > 0, iterations=2).astype(float)
# miolo: pergaminho limpo (canto superior direito do dialogo, sem circulo nem linha)
L, T, R, B = 150, 200, 140, 150          # margens do 9-slice (pixels da fonte)
W, H = f.shape[1], f.shape[0]
def sem_emenda(p):
    """Retalho repetível sem emenda: espelha um quarto dele nos dois eixos (as bordas
    de cada cópia sempre casam com a vizinha)."""
    h, w = p.shape[:2]
    q = np.asarray(Image.fromarray(p[:h // 2, :w // 2].astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(float)
    q = q * 0.55 + q.reshape(-1, 3).mean(0) * 0.45   # menos manchas: o espelho não aparece
    cima = np.concatenate([q, q[:, ::-1]], 1)
    t = np.concatenate([cima, cima[::-1]], 0)
    return np.asarray(Image.fromarray(t.astype(np.uint8)).resize((w, h), Image.LANCZOS))
limpo = Image.fromarray(a[380:720, 1300:2240].astype(np.uint8)).resize((W - L - R, H - T - B), Image.LANCZOS)
f[T:H - B, L:W - R] = sem_emenda(np.asarray(limpo))
# linha horizontal que entra na margem esquerda: copia as linhas de cima
ly = 744 - y0
f[ly - 14:ly + 14, 100:L] = f[ly - 42:ly - 14, 100:L]
moldura = rgba(f, alfa)
for nome, esc in (('painel', 0.16), ('painel_p', 0.10)):
    salvar(moldura, nome, esc)

# --- botao de comando (madeira) -------------------------------------------------------
a = rgb('painel de comandos.jpeg')
bx0, by0, bx1, by1 = 780, 330, 1325, 505
c = a[by0:by1, bx0:bx1]
lum = c.mean(2)
madeira = (lum < 150)
forma = nd.binary_fill_holes(nd.binary_closing(madeira, iterations=3))
forma = maior(nd.binary_opening(forma, iterations=2))
ys, xs = np.where(forma)
c = c[ys.min():ys.max() + 1, xs.min():xs.max() + 1]; forma = forma[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
salvar(rgba(c, forma.astype(float)), 'botao', 0.26)

# --- barra de turnos: vazia (pontas + faixa sem casas) ----------------------------------
a = rgb('barra de turnos.jpeg')
bx0, bx1, by0, by1 = 133, 2619, 549, 986
c = a[by0:by1, bx0:bx1]
esq_fim = 470 - bx0
dir_ini = 2275 - bx0
faixa = c[:, 650 - bx0:676 - bx0]
meio_w = dir_ini - esq_fim
reps = int(np.ceil(meio_w / faixa.shape[1]))
meio = np.concatenate([faixa] * reps, axis=1)[:, :meio_w]
vazia = np.concatenate([c[:, :esq_fim], meio, c[:, dir_ini:]], axis=1)
alfa = arred(vazia.shape[1], vazia.shape[0], 40)
salvar(rgba(vazia, alfa), 'barra', 0.2)
# casa quadrada e placa central (borda vermelha)
def peca_arred(a, box, r, nome, esc):
    x0, y0, x1, y1 = box
    c = a[y0:y1, x0:x1]
    return salvar(rgba(c, arred(x1 - x0, y1 - y0, r)), nome, esc)
peca_arred(a, (478, 682, 648, 854), 30, 'casa', 0.42)
peca_arred(a, (1088, 645, 1666, 891), 34, 'placa', 0.3)

# --- anel do retrato e tubo de HP/MP (card do personagem) ------------------------------
a = rgb('card personagem.jpeg')
cx, cy, R = 780 + 259, 350 + 258, 242
yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
d = np.hypot(xx - cx, yy - cy)
anel = np.clip((R - d) / 1.5, 0, 1) * np.clip((d - (R - 34)) / 1.5, 0, 1)
c = a[cy - R - 4:cy + R + 4, cx - R - 4:cx + R + 4]
salvar(rgba(c, anel[cy - R - 4:cy + R + 4, cx - R - 4:cx + R + 4], 0), 'anel', alvo=256)
# tubo: tampa ornamentada + canal vazio (coluna cinza repetida) + ponta
def tubo(y0, y1, nome):
    t = a[y0:y1, 790:1275].copy()
    col = t[:, 1235 - 790:1236 - 790]
    t[:, 864 - 790:1235 - 790] = col
    lum = t.mean(2)
    forma = nd.binary_fill_holes(nd.binary_closing(lum < 165, iterations=4))
    forma = maior(forma)
    ys, xs = np.where(forma)
    t = t[ys.min():ys.max() + 1, xs.min():xs.max() + 1]; forma = forma[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    print(nome, 'forma', forma.shape); salvar(rgba(t, forma.astype(float)), nome, 0.4)
tubo(912, 1035, 'tubo_hp')
tubo(1045, 1170, 'tubo_mp')

# --- d20 (rolagem de dados), sem o "20" pintado -----------------------------------------
a = rgb('rolagem de dados.jpeg')
a = a.copy()
bx0, bx1, by0, by1 = 1314, 1440, 545, 629
for y in range(by0, by1):
    e, d = a[y, bx0 - 2:bx0].mean(0), a[y, bx1:bx1 + 2].mean(0)
    t = np.linspace(0, 1, bx1 - bx0)[:, None]
    a[y, bx0:bx1] = e * (1 - t) + d * t
a[by0:by1, bx0:bx1] = np.asarray(Image.fromarray(a[by0-6:by1+6, bx0-6:bx1+6].astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)))[6:-6, 6:-6]
c = a[320:860, 1130:1625].copy()
lum = c.mean(2)
forma = maior(nd.binary_fill_holes(nd.binary_closing(lum < 170, iterations=4)))
ys, xs = np.where(forma)
c = c[ys.min():ys.max() + 1, xs.min():xs.max() + 1]; forma = forma[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
print('d20 centro do numero (fracao):', ((1377 - 1130 - xs.min()) / c.shape[1]), ((587 - 320 - ys.min()) / c.shape[0]))
salvar(rgba(c, forma.astype(float)), 'd20', alvo=256)

# --- brasao (cocar) e barra de ouro do resultado ---------------------------------------
a = rgb('Resultado da batalha.jpeg')
c = a[100:700, 1080:1680]
mx, mn = c.max(2), c.min(2)
pergaminho = (mx - mn < 70) & (c.mean(2) > 175)
xadrez = fundo_xadrez(c)
dourado = (c[..., 0] > 150) & (c[..., 1] > 110) & (c[..., 2] < 90)
dourado[:, 200:] = False
forma = ~(pergaminho | xadrez | nd.binary_dilation(dourado, iterations=4))
forma = nd.binary_opening(forma, iterations=3)
forma = maior(nd.binary_fill_holes(nd.binary_closing(forma, iterations=6)))
ys, xs = np.where(forma)
c = c[ys.min():ys.max() + 1, xs.min():xs.max() + 1]; forma = forma[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
salvar(rgba(c, forma.astype(float)), 'brasao', alvo=256)
c = a[790:990, 845:1860]
mx, mn = c.max(2), c.min(2)
ouro = (mx - mn > 80) | (c.mean(2) < 140)
forma = maior(nd.binary_fill_holes(nd.binary_closing(ouro, iterations=4)))
ys, xs = np.where(forma)
c = c[ys.min():ys.max() + 1, xs.min():xs.max() + 1]; forma = forma[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
salvar(rgba(c, forma.astype(float)), 'barra_ouro', 0.25)

# --- kit (hud.jpeg): fundo liso ---------------------------------------------------------
a = rgb('hud.jpeg')
cor = np.median(a[5:40, 5:40].reshape(-1, 3), axis=0)
dist = np.abs(a - cor).sum(2)
fg = nd.binary_opening(dist > 40, iterations=2)
fg = nd.binary_fill_holes(fg)
lab, k = nd.label(fg)
pecas = []
for i, sl in enumerate(nd.find_objects(lab)):
    area = (lab[sl] == i + 1).sum()
    if area > 4000:
        pecas.append((sl[0].start, sl[1].start, sl, i + 1))
pecas.sort()
nomes = {}
for y, x, sl, i in pecas:
    print('peca', y, x, sl[0].stop - y, sl[1].stop - x)
def kit(sl, i, nome, alvo):
    m = (lab[sl] == i).astype(float)
    salvar(rgba(a[sl], m), nome, alvo=alvo)
ordem = sorted(pecas, key=lambda p: (p[0] // 150, p[1]))
nm = ['barra_titulo', 'urna_hp', 'urna_mp', 'slot_madeira', 'moeda', 'pocao', 'pocao_mana', 'pena']
for (y, x, sl, i), n in zip(ordem, nm):
    kit(sl, i, n, 512 if n == 'barra_titulo' else 160)
