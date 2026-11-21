"""Gera todos os áudios do Ato I do zero, sem amostras de terceiros.

Instrumentos sintetizados aqui mesmo (Python puro, só biblioteca padrão):
  carimbó  -> curimbó (tambor de tronco), maracá, pandeiro
  marujada -> viola (corda dedilhada, Karplus-Strong) e acordeom (palheta dupla)
Melodias originais em compasso binário (2/4).

Uso:   python audio/gerar_audio.py            (gera tudo)
       python audio/gerar_audio.py acoes      (só os efeitos)
       python audio/gerar_audio.py trilhas    (só as músicas)

Saída: assets/diorge/audio/acoes/*.wav e assets/diorge/audio/trilhas/*.wav
Para ajustar: mude as tabelas PERSONAGENS / HABILIDADES e as partituras
EXPLORACAO / CHEFE no fim do arquivo e rode de novo.
"""
import math
import os
import random
import struct
import sys
import wave

SR = 32000
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR_ACOES = os.path.join(RAIZ, "assets", "diorge", "audio", "acoes")
DIR_TRILHAS = os.path.join(RAIZ, "assets", "diorge", "audio", "trilhas")
TAU = 2 * math.pi

rnd = random.Random(1616)  # semente fixa: o mesmo script gera sempre os mesmos sons


# --- básico ------------------------------------------------------------------

def n_am(seg):
    return max(1, int(seg * SR))


def silencio(seg):
    return [0.0] * n_am(seg)


def misturar(dest, src, em=0.0, ganho=1.0):
    """Soma src dentro de dest a partir de `em` segundos (estica dest se precisar)."""
    i0 = int(em * SR)
    fim = i0 + len(src)
    if fim > len(dest):
        dest.extend([0.0] * (fim - len(dest)))
    for i, v in enumerate(src):
        dest[i0 + i] += v * ganho
    return dest


def ruido(seg):
    g = rnd.uniform
    return [g(-1.0, 1.0) for _ in range(n_am(seg))]


def passa_baixa(x, corte):
    a = 1.0 - math.exp(-TAU * corte / SR)
    y, s = [], 0.0
    for v in x:
        s += a * (v - s)
        y.append(s)
    return y


def passa_alta(x, corte):
    lp = passa_baixa(x, corte)
    return [a - b for a, b in zip(x, lp)]


def passa_faixa(x, freq, q):
    """Biquad passa-faixa (RBJ, ganho 0 dB no pico)."""
    w = TAU * min(freq, SR * 0.45) / SR
    al = math.sin(w) / (2 * q)
    a0 = 1 + al
    b0, b2 = al / a0, -al / a0
    a1, a2 = -2 * math.cos(w) / a0, (1 - al) / a0
    x1 = x2 = y1 = y2 = 0.0
    y = []
    for v in x:
        o = b0 * v + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y.append(o)
    return y


def envelope(x, ataque=0.005, queda=0.2, curva=1.0):
    """Ataque linear e queda exponencial (queda = tempo para cair ~63%)."""
    na = n_am(ataque)
    k = math.exp(-1.0 / (queda * SR)) if queda > 0 else 0.0
    y, g = [], 1.0
    for i, v in enumerate(x):
        if i < na:
            e = i / na
        else:
            g *= k
            e = g
        y.append(v * (e ** curva))
    return y


def janela(x, ataque=0.01, soltura=0.05):
    """Liga e desliga suave, sem estalos."""
    n = len(x)
    na, ns = n_am(ataque), n_am(soltura)
    y = list(x)
    for i in range(min(na, n)):
        y[i] *= i / na
    for i in range(min(ns, n)):
        y[n - 1 - i] *= i / ns
    return y


def seno_glide(seg, f0, f1, amp=1.0, curva=1.0):
    """Seno com altura indo de f0 até f1 (curva >1 cai rápido no começo)."""
    n = n_am(seg)
    y, fase = [], 0.0
    for i in range(n):
        t = (i / n) ** (1.0 / curva)
        f = f0 + (f1 - f0) * t
        fase += TAU * f / SR
        y.append(math.sin(fase) * amp)
    return y


def normalizar(x, pico=0.89):
    m = max(1e-9, max(abs(v) for v in x))
    return [v * pico / m for v in x]


def salvar(caminho, x, pico=0.89):
    x = normalizar(x, pico)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with wave.open(caminho, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))
    print("  ", os.path.relpath(caminho, RAIZ), f"{len(x) / SR:.2f}s")


# --- instrumentos do carimbó -----------------------------------------------------

_cache = {}


def _guardado(chave, fazer):
    if chave not in _cache:
        _cache[chave] = fazer()
    return _cache[chave]


def curimba(altura=95.0, tapa=False, seg=0.45):
    """Curimbó: tambor de tronco tocado com a mão. Grave (palma) ou tapa (agudo, seco)."""
    def fazer():
        if tapa:
            pele = envelope(seno_glide(0.18, altura * 3.2, altura * 2.6, curva=3), 0.001, 0.05)
            estalo = envelope(passa_faixa(ruido(0.08), 1800, 1.2), 0.001, 0.02)
            return misturar(pele, estalo, 0, 0.9)
        corpo = envelope(seno_glide(seg, altura * 1.7, altura, curva=4), 0.002, seg * 0.35)
        oco = envelope(seno_glide(seg, altura * 2.6, altura * 2.3, curva=3), 0.002, seg * 0.15)
        mao = envelope(passa_baixa(ruido(0.05), 900), 0.001, 0.015)
        x = misturar(corpo, oco, 0, 0.35)
        return misturar(x, mao, 0, 0.5)
    return _guardado(("curimba", altura, tapa, seg), fazer)


def maraca(seg=0.09, forte=1.0):
    """Maracá: sementes numa cabaça (ruído agudo com 'chiado' de grãos)."""
    def fazer():
        r = passa_alta(ruido(seg), 3500)
        graos = [v * (1.0 if rnd.random() < 0.35 else 0.3) for v in r]
        return janela(envelope(graos, seg * 0.25, seg * 0.35), 0.002, 0.01)
    return [v * forte for v in _guardado(("maraca", seg), fazer)]


def pandeiro(platinela=True):
    """Pandeiro: pele curta + platinelas metálicas (parciais inarmônicas)."""
    def fazer():
        pele = envelope(seno_glide(0.12, 260, 190, curva=3), 0.001, 0.04)
        x = list(pele)
        if platinela:
            for f in (5200, 6900, 8300, 9700):
                p = envelope([math.sin(TAU * f * i / SR + rnd.random()) for i in range(n_am(0.25))], 0.001, 0.07)
                misturar(x, p, 0.002, 0.08)
            misturar(x, envelope(passa_alta(ruido(0.2), 6000), 0.001, 0.06), 0, 0.25)
        return x
    return _guardado(("pandeiro", platinela), fazer)


# --- instrumentos da marujada ------------------------------------------------------

def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def viola(nota, seg=0.8, brilho=0.5, abafar=False):
    """Viola de corda (Karplus-Strong). `brilho` 0..1, `abafar` = palma da mão na corda."""
    def fazer():
        f = midi_hz(nota)
        p = max(2, int(SR / f))
        buf = [rnd.uniform(-1, 1) for _ in range(p)]
        buf = passa_baixa(buf, 1500 + 6000 * brilho)
        perda = 0.985 if abafar else 0.9975
        y = []
        n = n_am(seg)
        i = 0
        for _ in range(n):
            a = buf[i]
            b = buf[(i + 1) % p]
            buf[i] = (a + b) * 0.5 * perda
            y.append(a)
            i = (i + 1) % p
        # corpo de madeira: realça uns 250 Hz
        corpo = passa_faixa(y, 250, 1.0)
        y = [a + 0.6 * c for a, c in zip(y, corpo)]
        return janela(y, 0.001, 0.03)
    return _guardado(("viola", nota, seg, brilho, abafar), fazer)


def _tabela_palheta():
    """Um ciclo da onda de palheta do acordeom (ímpares fortes, pares fracos)."""
    n = 2048
    harm = [(1, 1.0), (2, 0.55), (3, 0.6), (4, 0.3), (5, 0.35), (6, 0.15), (7, 0.2), (8, 0.08), (9, 0.1)]
    t = [sum(a * math.sin(TAU * h * i / n) for h, a in harm) for i in range(n)]
    m = max(abs(v) for v in t)
    return [v / m for v in t]


TAB_PALHETA = _tabela_palheta()


def acordeom(nota, seg, vol=1.0):
    """Acordeom: duas palhetas levemente desafinadas (som 'musette') + fole."""
    def fazer():
        n = n_am(seg)
        tab, tn = TAB_PALHETA, len(TAB_PALHETA)
        f = midi_hz(nota)
        d1, d2 = f * tn / SR, f * 1.004 * tn / SR
        p1, p2 = 0.0, rnd.random() * tn
        y = []
        for _ in range(n):
            y.append(tab[int(p1) % tn] + tab[int(p2) % tn])
            p1 += d1
            p2 += d2
        y = passa_baixa(y, 3800)
        # fole: ataque macio, leve inchaço e soltura curta
        ntot = len(y)
        na, ns = n_am(min(0.04, seg * 0.3)), n_am(min(0.06, seg * 0.3))
        for i in range(ntot):
            e = 1.0
            if i < na:
                e = i / na
            elif i > ntot - ns:
                e = (ntot - i) / ns
            y[i] *= e * (0.85 + 0.15 * math.sin(TAU * 0.8 * i / SR))
        return y
    return [v * vol for v in _guardado(("acordeom", nota, seg), fazer)]


def sino(freq, seg=0.9):
    """Plaquinha de metal/cristal para curas (parciais de sino, decaimento lento)."""
    def fazer():
        x = [0.0] * n_am(seg)
        for mult, amp, q in ((1.0, 1.0, 0.45), (2.76, 0.4, 0.2), (5.4, 0.2, 0.1)):
            p = envelope([math.sin(TAU * freq * mult * i / SR) for i in range(n_am(seg))], 0.002, seg * q)
            misturar(x, p, 0, amp)
        return x
    return _guardado(("sino", freq, seg), fazer)


def reverb(x, sala=0.5, mistura=0.25, circular=False):
    """Reverb de Schroeder (4 pentes + 2 passa-tudo). `circular` dobra a cauda
    no começo, para a música emendar em loop sem buraco."""
    n = len(x)
    cauda = n_am(1.5)
    entrada = x + [0.0] * cauda
    molhado = [0.0] * len(entrada)
    for atraso, fb in ((1557, 0.84), (1617, 0.83), (1491, 0.85), (1422, 0.82)):
        atraso = int(atraso * SR / 44100)
        fb = fb * (0.85 + 0.15 * sala)
        buf = [0.0] * atraso
        j = 0
        for i, v in enumerate(entrada):
            s = buf[j]
            buf[j] = v + s * fb
            molhado[i] += s
            j = (j + 1) % atraso
    for atraso in (225, 556):
        atraso = int(atraso * SR / 44100)
        buf = [0.0] * atraso
        j = 0
        for i, v in enumerate(molhado):
            s = buf[j]
            buf[j] = v + s * 0.5
            molhado[i] = s - v * 0.5
            j = (j + 1) % atraso
    molhado = passa_baixa(molhado, 5000)
    saida = [a * (1 - mistura) + b * mistura * 0.25 for a, b in zip(entrada, molhado)]
    if circular:
        for i in range(cauda):
            saida[i] += saida[n + i]
        saida = saida[:n]
    return saida


# --- vozes dos bichos (dano e morte) ---------------------------------------------

def voz(tipo, f0, seg, queda=0.8, aspereza=0.0):
    """Uma 'voz' curta de bicho. tipo: grito, ave, coruja, sapo, chiado, madeira, agua."""
    n = n_am(seg)
    if tipo in ("grito", "sapo"):
        y, fase = [], 0.0
        for i in range(n):
            t = i / n
            f = f0 * (1.15 - (1.15 - queda) * t)
            if aspereza:  # rosnado: sub-modulação
                f *= 1 + 0.06 * aspereza * math.sin(TAU * 31 * i / SR)
            fase += f / SR
            y.append(2 * (fase % 1.0) - 1)
        y = misturar(y, passa_baixa(ruido(seg), 2500), 0, 0.25 + 0.3 * aspereza)
        tam = max(0.4, min(1.6, 140.0 / f0)) if tipo == "grito" else 1.4
        f1 = passa_faixa(y, 700 / tam ** 0.5, 3)
        f2 = passa_faixa(y, 1250 / tam ** 0.5, 4)
        y = [a + 0.7 * b for a, b in zip(f1, f2)]
        if tipo == "sapo":  # coaxar: pulsos rápidos
            y = [v * (0.5 + 0.5 * math.sin(TAU * 28 * i / SR)) ** 2 for i, v in enumerate(y)]
        return janela(envelope(y, 0.015, seg * 0.5), 0.005, seg * 0.3)
    if tipo == "ave":
        y = []
        fase = 0.0
        for i in range(n):
            t = i / n
            f = f0 * 6 * (1.2 - 0.6 * t) * (1 + 0.08 * math.sin(TAU * 22 * i / SR))
            fase += TAU * f / SR
            y.append(math.sin(fase))
        return janela(envelope(y, 0.005, seg * 0.4), 0.003, seg * 0.3)
    if tipo == "coruja":
        x = envelope(seno_glide(seg * 0.5, f0 * 1.1, f0 * queda), 0.04, seg * 0.3)
        x = misturar(x, envelope(seno_glide(seg * 0.5, f0, f0 * queda * 0.9), 0.04, seg * 0.3), seg * 0.45)
        return janela(misturar(x, passa_faixa(ruido(seg), f0 * 2, 2), 0, 0.15), 0.01, 0.05)
    if tipo == "chiado":
        h = passa_alta(ruido(seg), 4500)
        h = [v * (0.7 + 0.3 * math.sin(TAU * 40 * i / SR)) for i, v in enumerate(h)]
        return janela(envelope(h, 0.02, seg * 0.5), 0.005, seg * 0.3)
    if tipo == "madeira":  # rangido de planta/tronco: estalos que aceleram
        y = [0.0] * n
        t = 0.0
        while t < seg * 0.9:
            k = int(t * SR)
            if k < n:
                y[k] = rnd.uniform(0.6, 1.0)
            t += 0.03 * (1.0 - 0.6 * t / seg) * (220.0 / f0)
        y = passa_faixa(y, f0 * 3, 5)
        y = misturar(y, passa_faixa(ruido(seg), 2500, 1), 0, 0.08)
        return janela(envelope(y, 0.005, seg * 0.5), 0.003, seg * 0.3)
    if tipo == "agua":  # boto: assobio + cliques
        y = envelope(seno_glide(seg, f0 * 5, f0 * 5 * queda), 0.02, seg * 0.4)
        for k in range(6):
            misturar(y, envelope(passa_alta(ruido(0.01), 3000), 0.0005, 0.003), k * 0.035, 0.6)
        return janela(y, 0.005, seg * 0.3)
    raise ValueError(tipo)


def baque(peso=1.0):
    """Pancada surda de corpo acertado (grave + 'tapa')."""
    x = list(curimba(70 + 40 * (1 - peso), seg=0.3))
    return misturar(x, envelope(passa_baixa(ruido(0.06), 1200), 0.001, 0.02), 0, 0.6)


def queda_corpo(peso=1.0):
    x = list(curimba(55 + 30 * (1 - peso), seg=0.5))
    misturar(x, envelope(passa_baixa(ruido(0.4), 500), 0.005, 0.12), 0, 0.5 * peso)
    return x


# --- ataques -------------------------------------------------------------------

def vulto(seg=0.18, f0=600, f1=2400, forca=1.0):
    """Zunido do golpe no ar (ruído filtrado varrendo)."""
    r = ruido(seg)
    y, partes = [], 8
    m = len(r) // partes
    for p in range(partes):
        f = f0 + (f1 - f0) * p / (partes - 1)
        y += passa_faixa(r[p * m:(p + 1) * m], f, 1.5)
    env = [math.sin(math.pi * i / len(y)) ** 1.5 * forca for i in range(len(y))]
    return [a * b for a, b in zip(y, env)]


def lamina(f=2400):
    x = [0.0] * n_am(0.4)
    for mult, amp in ((1.0, 1.0), (1.53, 0.6), (2.12, 0.4), (2.9, 0.25)):
        p = envelope([math.sin(TAU * f * mult * i / SR) for i in range(len(x))], 0.001, 0.08)
        misturar(x, p, 0, amp * 0.3)
    return misturar(x, envelope(passa_alta(ruido(0.1), 3000), 0.001, 0.03), 0, 0.4)


def ataque(tipo, f0):
    if tipo == "contundente":
        x = vulto(0.2, 400, 1600)
        misturar(x, baque(1.0), 0.17)
        return misturar(x, curimba(f0 * 0.8, tapa=True), 0.17, 0.4)
    if tipo == "lamina":
        x = vulto(0.14, 900, 3500)
        return misturar(x, lamina(2200 + f0 * 2), 0.11)
    if tipo == "duplo":
        x = misturar(vulto(0.12, 900, 3500), lamina(2600), 0.09)
        misturar(x, vulto(0.12, 1000, 3800), 0.16)
        return misturar(x, lamina(3100), 0.25, 0.9)
    if tipo == "garras":
        x = []
        for k in range(3):
            misturar(x, vulto(0.16, 300 + 80 * k, 1400), k * 0.13)
            misturar(x, lamina(1500 + 300 * k), k * 0.13 + 0.12, 0.6)
        misturar(x, voz("grito", 60, 0.6, 0.7, aspereza=1.0), 0.0, 0.5)
        return misturar(x, baque(1.0), 0.4)
    if tipo == "lanca":
        x = vulto(0.12, 1200, 2800)
        misturar(x, envelope(passa_faixa(ruido(0.08), 1500, 2), 0.001, 0.03), 0.1)
        return misturar(x, curimba(f0, tapa=True), 0.1, 0.6)
    if tipo == "mordida":
        x = []
        for k in range(2):
            misturar(x, envelope(passa_baixa(ruido(0.07), 1800), 0.001, 0.02), k * 0.1)
            misturar(x, curimba(110, tapa=True), k * 0.1, 0.5)
        return misturar(x, voz("madeira", f0, 0.3), 0.0, 0.3)
    if tipo == "investida":
        x = vulto(0.4, 300, 2000)
        return misturar(x, baque(0.8), 0.36)
    if tipo == "chicote":
        x = vulto(0.2, 500, 3000, 0.7)
        crack = envelope(passa_alta(ruido(0.03), 2500), 0.0005, 0.006)
        return misturar(x, crack, 0.2, 1.5)
    if tipo == "folha":
        x = []
        for k in range(5):
            misturar(x, maraca(0.07, 0.8), k * 0.035)
        return misturar(x, baque(0.5), 0.15, 0.8)
    if tipo == "dardo":
        x = envelope(passa_faixa(ruido(0.1), 900, 1.5), 0.005, 0.04)
        misturar(x, envelope(seno_glide(0.15, 2400, 1800), 0.005, 0.08), 0.05, 0.3)
        return misturar(x, curimba(300, tapa=True), 0.2, 0.4)
    if tipo in ("flecha", "espinhos"):
        x = list(viola(64 if tipo == "flecha" else 71, 0.35, 0.8))
        x = envelope(x, 0.001, 0.12)
        for k in range(1 if tipo == "flecha" else 3):
            misturar(x, envelope(seno_glide(0.25, 3000 - 200 * k, 2200), 0.03, 0.12), 0.05 + 0.06 * k, 0.25)
            misturar(x, curimba(220 + 40 * k, tapa=True), 0.3 + 0.06 * k, 0.5)
        return x
    if tipo == "luz":
        x = []
        for k, m in enumerate((72, 76, 79, 84, 88)):
            misturar(x, sino(midi_hz(m + (f0 > 200) * 2), 0.7), k * 0.05, 0.5)
        for k in range(8):
            misturar(x, maraca(0.05, 0.3), k * 0.05)
        return x
    if tipo == "penas":
        x = voz("coruja", f0, 0.6, 0.8)
        aba = [v * (0.5 + 0.5 * math.sin(TAU * 16 * i / SR)) for i, v in enumerate(passa_baixa(ruido(0.5), 1500))]
        return misturar(x, envelope(aba, 0.05, 0.25), 0.15, 0.5)
    if tipo == "esporos":
        x = []
        for k in range(4):
            misturar(x, envelope(passa_baixa(ruido(0.12), 700), 0.005, 0.05), k * 0.08)
        for k in range(10):
            misturar(x, envelope(seno_glide(0.03, 600 + rnd.random() * 900, 1600), 0.001, 0.01), 0.15 + k * 0.035, 0.3)
        return x
    if tipo == "fumaca":
        r = ruido(0.9)
        x = passa_baixa(r, 900)
        x = [v * math.sin(math.pi * i / len(x)) for i, v in enumerate(x)]
        return misturar(x, voz("sapo", f0, 0.4, 0.9), 0.0, 0.3)
    if tipo == "bote":
        x = voz("chiado", f0, 0.4)
        misturar(x, envelope(seno_glide(0.3, 300, 1200), 0.02, 0.15), 0.1, 0.4)
        return misturar(x, curimba(180, tapa=True), 0.38, 0.8)
    raise ValueError(tipo)


# --- tabelas: personagens e habilidades ------------------------------------------
# id (igual aos .tres de scripts/combate/habilidades/ataques) :
#   (tipo do ataque básico, tipo de voz, altura da voz em Hz, peso 0..1)
PERSONAGENS = {
    "bufalo": ("lamina", "grito", 85, 1.0),
    "tartaruga": ("contundente", "grito", 110, 0.9),
    "tartaruga_paladina": ("contundente", "grito", 110, 0.9),
    "murucututu": ("penas", "coruja", 380, 0.3),
    "guara": ("flecha", "ave", 300, 0.4),
    "boto": ("luz", "agua", 600, 0.6),
    "onca": ("lamina", "grito", 140, 0.7),
    "acaizeiro": ("contundente", "madeira", 120, 0.7),
    "vitoria_regia": ("folha", "madeira", 150, 0.6),
    "carnivora": ("mordida", "madeira", 100, 0.8),
    "cogumelo": ("esporos", "madeira", 420, 0.3),
    "golem_toco": ("contundente", "madeira", 70, 1.0),
    "bromelia": ("espinhos", "madeira", 330, 0.4),
    "aninga": ("lanca", "madeira", 200, 0.6),
    "buriti": ("investida", "madeira", 220, 0.5),
    "sapo_dardo": ("dardo", "sapo", 500, 0.2),
    "tartaruga_amazonia": ("luz", "grito", 160, 0.7),
    "iguana": ("flecha", "grito", 260, 0.4),
    "teiu": ("contundente", "grito", 180, 0.6),
    "naga": ("bote", "chiado", 240, 0.6),
    "coral": ("lamina", "chiado", 280, 0.4),
    "cobra_cavaleira": ("lanca", "chiado", 160, 0.7),
    "jacare_acu": ("contundente", "grito", 75, 1.0),
    "jacaretinga": ("duplo", "grito", 170, 0.6),
    "cururu": ("fumaca", "sapo", 140, 0.6),
    "perereca": ("chicote", "sapo", 450, 0.3),
    "mapinguari": ("garras", "grito", 55, 1.0),
}


def dano(tipo_voz, f0, peso):
    x = baque(peso)
    aspero = 0.8 if f0 < 70 else 0.0
    return misturar(x, voz(tipo_voz, f0, 0.35, 0.8, aspero), 0.02, 0.9)


def morte(tipo_voz, f0, peso):
    aspero = 1.0 if f0 < 70 else 0.0
    x = voz(tipo_voz, f0, 1.0 + 0.4 * peso, 0.55, aspero)
    misturar(x, queda_corpo(peso), 0.7 + 0.3 * peso, 1.0)
    # maracá que vai sumindo e duas notas descendentes da viola: despedida
    for k in range(6):
        misturar(x, maraca(0.08, 0.5 * (1 - k / 6)), 0.75 + k * 0.09)
    misturar(x, viola(57, 1.0, 0.3), 0.8, 0.5)
    return misturar(x, viola(52, 1.2, 0.3), 1.05, 0.5)


def hab_golpe():
    x = vulto(0.35, 250, 1800, 1.2)
    misturar(x, baque(1.0), 0.32)
    misturar(x, curimba(60, seg=0.7), 0.32)
    return misturar(x, curimba(80, seg=0.5), 0.45, 0.7)


def hab_golpe_cajado():
    x = vulto(0.22, 500, 2200)
    misturar(x, curimba(200, tapa=True), 0.19)
    return misturar(x, envelope(passa_faixa(ruido(0.05), 900, 3), 0.001, 0.02), 0.19, 0.8)


def hab_area():
    x = list(curimba(45, seg=1.0))
    misturar(x, envelope(passa_baixa(ruido(1.2), 300), 0.01, 0.4), 0, 0.8)
    for k in range(12):
        misturar(x, curimba(300 + rnd.random() * 500, tapa=True), 0.15 + rnd.random() * 0.6, 0.15)
    return misturar(x, pandeiro(), 0.0, 0.4)


def hab_casco_firme():
    x = list(curimba(90, seg=0.5))
    for f in (420, 610, 1130, 1790):
        misturar(x, envelope([math.sin(TAU * f * i / SR) for i in range(n_am(0.9))], 0.002, 0.25), 0, 0.15)
    for k in range(4):
        misturar(x, pandeiro(), 0.25 + k * 0.08, 0.5 - k * 0.1)
    return x


def hab_cura(notas, passo=0.09):
    x = []
    for k, m in enumerate(notas):
        misturar(x, sino(midi_hz(m), 1.0), k * passo, 0.5)
    for k in range(len(notas) * 2):
        misturar(x, maraca(0.06, 0.25), k * passo / 2)
    misturar(x, viola(notas[0] - 12, 1.2, 0.3), 0, 0.4)
    return x


def hab_mare():
    onda = passa_baixa(ruido(1.6), 700)
    onda = [v * (0.5 + 0.5 * math.sin(math.pi * i / len(onda))) * (0.7 + 0.3 * math.sin(TAU * 1.5 * i / SR))
            for i, v in enumerate(onda)]
    x = janela(onda, 0.2, 0.4)
    misturar(x, hab_cura([67, 71, 74, 79, 83], 0.12), 0.2, 1.2)
    return misturar(x, acordeom(43, 1.3, 0.3), 0.1)


HABILIDADES = {
    "golpe": hab_golpe,
    "golpe_cajado": hab_golpe_cajado,
    "area": hab_area,
    "casco_firme": hab_casco_firme,
    "cura_leve": lambda: hab_cura([72, 76, 79]),
    "cura_forte": lambda: hab_cura([67, 72, 76, 79, 84], 0.1),
    "mare_curativa": hab_mare,
}


def gerar_acoes():
    print("Efeitos de ação:")
    for pid, (atq, tv, f0, peso) in PERSONAGENS.items():
        salvar(os.path.join(DIR_ACOES, pid + "_ataque.wav"), ataque(atq, f0))
        salvar(os.path.join(DIR_ACOES, pid + "_dano.wav"), dano(tv, f0, peso))
        salvar(os.path.join(DIR_ACOES, pid + "_morte.wav"), morte(tv, f0, peso))
    for hid, fazer in HABILIDADES.items():
        salvar(os.path.join(DIR_ACOES, "hab_" + hid + ".wav"), fazer())


# --- trilhas ---------------------------------------------------------------------
# Partitura: cada compasso 2/4 tem 8 semicolcheias. Nota = (midi, duração em
# semicolcheias); midi None = pausa.

ACORDES = {
    "G": [55, 59, 62, 67], "D7": [50, 54, 57, 60], "C": [48, 52, 55, 60],
    "Em": [52, 55, 59, 64], "B7": [47, 51, 54, 57], "Am": [45, 52, 57, 60],
}

EXPLORACAO = {
    "bpm": 100,
    "acordes": ["G", "G", "D7", "D7", "D7", "D7", "G", "G", "C", "C", "G", "G", "D7", "D7", "G", "G"],
    "melodia": [
        [(74, 2), (71, 1), (74, 1), (79, 2), (74, 2)], [(76, 2), (74, 1), (71, 1), (67, 4)],
        [(69, 2), (66, 1), (69, 1), (72, 2), (69, 2)], [(74, 2), (72, 1), (69, 1), (66, 4)],
        [(69, 1), (71, 1), (72, 2), (74, 2), (78, 2)], [(76, 2), (74, 1), (72, 1), (69, 4)],
        [(71, 2), (74, 1), (71, 1), (69, 2), (67, 2)], [(67, 6), (None, 2)],
        [(76, 2), (79, 1), (76, 1), (72, 2), (76, 2)], [(74, 2), (72, 1), (71, 1), (72, 4)],
        [(71, 2), (74, 1), (71, 1), (67, 2), (71, 2)], [(69, 2), (67, 1), (66, 1), (67, 4)],
        [(66, 1), (69, 1), (74, 2), (72, 2), (69, 2)], [(71, 2), (69, 1), (67, 1), (66, 4)],
        [(67, 2), (71, 1), (74, 1), (79, 2), (78, 1), (76, 1)], [(74, 2), (71, 2), (67, 4)],
    ],
}

CHEFE = {
    "bpm": 132,
    "acordes": ["Em", "Em", "B7", "B7", "Em", "Em", "C", "B7", "Am", "Am", "Em", "Em", "C", "B7", "Em", "Em"],
    "melodia": [
        [(64, 1), (64, 1), (67, 1), (64, 1), (71, 2), (64, 2)], [(67, 1), (69, 1), (71, 1), (67, 1), (76, 4)],
        [(75, 1), (76, 1), (75, 1), (71, 1), (66, 2), (69, 2)], [(71, 1), (69, 1), (67, 1), (66, 1), (63, 4)],
        [(64, 1), (64, 1), (67, 1), (71, 1), (76, 2), (75, 1), (76, 1)], [(79, 2), (78, 1), (76, 1), (71, 4)],
        [(72, 1), (71, 1), (72, 1), (76, 1), (79, 2), (76, 2)], [(78, 1), (75, 1), (71, 1), (69, 1), (66, 4)],
        [(69, 1), (69, 1), (72, 1), (69, 1), (76, 2), (69, 2)], [(72, 1), (74, 1), (76, 1), (72, 1), (69, 4)],
        [(71, 1), (69, 1), (67, 1), (66, 1), (64, 2), (67, 2)], [(71, 2), (76, 2), (67, 2), (71, 2)],
        [(72, 1), (76, 1), (79, 1), (76, 1), (72, 2), (67, 2)], [(71, 1), (75, 1), (78, 1), (81, 1), (83, 2), (81, 1), (78, 1)],
        [(79, 2), (76, 1), (71, 1), (67, 2), (71, 2)], [(76, 4), (64, 4)],
    ],
}

# Toque de carimbó no curimbó (8 semicolcheias): G = grave, T = tapa, . = nada
CARIMBO = "G..T.GT."
CARIMBO_CHEFE = "G.TTG.TG"


def tocar_melodia(trilha, compassos, inicio, semi, instrumento, transpor=0, vol=1.0):
    t = inicio
    for comp in compassos:
        for nota, dur in comp:
            seg = dur * semi
            if nota is not None:
                if instrumento == "acordeom":
                    misturar(trilha, acordeom(nota + transpor, seg * 0.95, vol), t)
                else:
                    misturar(trilha, viola(nota + transpor, max(0.5, seg * 2), 0.6), t, vol)
            t += seg


def musica(partitura, voltas, chefe=False):
    semi = 60.0 / partitura["bpm"] / 4
    comp_seg = semi * 8
    acordes = partitura["acordes"]
    total = len(acordes) * voltas
    x = [0.0] * n_am(total * comp_seg)
    padrao = CARIMBO_CHEFE if chefe else CARIMBO
    for c in range(total):
        t0 = c * comp_seg
        volta = c // len(acordes)
        ac = ACORDES[acordes[c % len(acordes)]]
        # percussão
        for s, ch in enumerate(padrao):
            ts = t0 + s * semi
            if ch == "G":
                misturar(x, curimba(80 if chefe else 95, seg=0.4), ts, 0.9)
            elif ch == "T":
                misturar(x, curimba(110 if chefe else 120, tapa=True), ts, 0.45)
            misturar(x, maraca(0.07 if s % 2 else 0.1, 0.35 if s % 2 else 0.55), ts)
        if chefe or volta % 2 == 1:
            misturar(x, pandeiro(), t0 + 2 * semi, 0.35)
            misturar(x, pandeiro(), t0 + 6 * semi, 0.35)
        # baixo: viola grave na tônica de cada tempo
        misturar(x, viola(ac[0] - 12, 0.6, 0.2), t0, 0.7)
        misturar(x, viola(ac[0] - 12 + (7 if not chefe else 0), 0.6, 0.2), t0 + 4 * semi, 0.6)
        # viola rasgueada
        if chefe:
            for s in range(8):  # tremolo abafado, tenso
                for k, nota in enumerate(ac[1:]):
                    misturar(x, viola(nota, 0.25, 0.5, abafar=True), t0 + s * semi + k * 0.008, 0.18)
        else:
            for s, forca in ((0, 0.3), (3, 0.15), (4, 0.25), (6, 0.15)):
                ordem = ac if s % 2 == 0 else list(reversed(ac))
                for k, nota in enumerate(ordem):
                    misturar(x, viola(nota, 0.7, 0.45), t0 + s * semi + k * 0.012, forca)
            if volta % 2 == 0:  # acordeom segurando o acorde, baixinho
                for nota in ac[1:]:
                    misturar(x, acordeom(nota, comp_seg, 0.12), t0)
    # melodias: viola na 1ª volta, acordeom na 2ª (exploração); acordeom sempre no chefe
    for v in range(voltas):
        ini = v * len(acordes) * comp_seg
        if chefe:
            tocar_melodia(x, partitura["melodia"], ini, semi, "acordeom", -12 if v == 0 else 0, 0.55)
            if v == 1:
                tocar_melodia(x, partitura["melodia"], ini, semi, "acordeom", -12, 0.35)
        elif v % 2 == 0:
            tocar_melodia(x, partitura["melodia"], ini, semi, "viola", 0, 0.8)
        else:
            tocar_melodia(x, partitura["melodia"], ini, semi, "acordeom", 0, 0.5)
    return reverb(x, 0.6 if chefe else 0.4, 0.3, circular=True)


def gerar_trilhas():
    print("Trilhas (demora um pouco):")
    salvar(os.path.join(DIR_TRILHAS, "exploracao_carimbo.wav"), musica(EXPLORACAO, 2), 0.8)
    salvar(os.path.join(DIR_TRILHAS, "chefe_mapinguari.wav"), musica(CHEFE, 2, chefe=True), 0.85)


if __name__ == "__main__":
    qual = sys.argv[1] if len(sys.argv) > 1 else "tudo"
    if qual in ("tudo", "acoes"):
        gerar_acoes()
    if qual in ("tudo", "trilhas"):
        gerar_trilhas()
