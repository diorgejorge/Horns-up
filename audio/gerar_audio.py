"""Gera todos os áudios do Ato I do zero, sem amostras de terceiros (versão 2).

Tudo é sintetizado aqui, em Python puro (só biblioteca padrão):
  amazônia/carimbó -> curimbó (tambor de tronco), maracá, pau-de-chuva,
                      flauta de bambu, viola, acordeom
  power metal      -> bateria com bumbo duplo, guitarras distorcidas dobradas,
                      baixo, guitarras solo gêmeas em terças e coro
Melodias e riffs originais.

Uso:   python audio/gerar_audio.py            (gera tudo)
       python audio/gerar_audio.py acoes      (só os efeitos)
       python audio/gerar_audio.py trilhas    (só exploração e chefe)
       python audio/gerar_audio.py batalhas   (só as 6 de batalha: audio/trilhas_batalha.py)

Saída: assets/diorge/audio/acoes/*.wav (mono) e assets/diorge/audio/trilhas/*.wav
(estéreo). Cada som tem semente própria: gerar só uma parte dá o mesmo resultado.
O loop das trilhas é ligado nos arquivos .import (edit/loop_mode=2).
Para ajustar: tabelas PERSONAGENS / HABILIDADES e partituras EXPLORACAO / CHEFE.
"""
import math
import os
import random
import struct
import sys
import wave
import zlib

SR = 44100
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR_ACOES = os.path.join(RAIZ, "assets", "diorge", "audio", "acoes")
DIR_TRILHAS = os.path.join(RAIZ, "assets", "diorge", "audio", "trilhas")
TAU = 2 * math.pi

rnd = random.Random()


def semear(nome):
    rnd.seed(zlib.crc32(repr(nome).encode()))


# --- básico ------------------------------------------------------------------

def n_am(seg):
    return max(1, int(seg * SR))


def misturar(dest, src, em=0.0, ganho=1.0):
    """Soma src dentro de dest a partir de `em` segundos (estica dest se precisar)."""
    i0 = int(em * SR)
    fim = i0 + len(src)
    if fim > len(dest):
        dest.extend([0.0] * (fim - len(dest)))
    dest[i0:fim] = [a + b * ganho for a, b in zip(dest[i0:fim], src)]
    return dest


def ruido(seg):
    g = rnd.uniform
    return [g(-1.0, 1.0) for _ in range(n_am(seg))]


def _biquad(x, b0, b1, b2, a1, a2):
    x1 = x2 = y1 = y2 = 0.0
    y = []
    ap = y.append
    for v in x:
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        ap(o)
    return y


def filtro(x, tipo, freq, q=0.707, ganho_db=0.0):
    """Biquads RBJ: pb (passa-baixa), pa (passa-alta), pf (passa-faixa), pico."""
    w = TAU * min(freq, SR * 0.45) / SR
    cw, al = math.cos(w), math.sin(w) / (2 * q)
    if tipo == "pb":
        b = ((1 - cw) / 2, 1 - cw, (1 - cw) / 2)
        a0, a1, a2 = 1 + al, -2 * cw, 1 - al
    elif tipo == "pa":
        b = ((1 + cw) / 2, -(1 + cw), (1 + cw) / 2)
        a0, a1, a2 = 1 + al, -2 * cw, 1 - al
    elif tipo == "pf":
        b = (al, 0.0, -al)
        a0, a1, a2 = 1 + al, -2 * cw, 1 - al
    else:  # pico
        A = 10 ** (ganho_db / 40)
        b = (1 + al * A, -2 * cw, 1 - al * A)
        a0, a1, a2 = 1 + al / A, -2 * cw, 1 - al / A
    return _biquad(x, b[0] / a0, b[1] / a0, b[2] / a0, a1 / a0, a2 / a0)


def varredura(x, f0, f1, q=1.5, curva=1.0):
    """Passa-faixa com a frequência deslizando de f0 a f1 (sem emendas)."""
    n = len(x)
    y = []
    x1 = x2 = y1 = y2 = 0.0
    b0 = b2 = a1 = a2 = 0.0
    for i, v in enumerate(x):
        if i % 32 == 0:
            t = (i / n) ** curva
            f = f0 * (f1 / f0) ** t
            w = TAU * min(f, SR * 0.45) / SR
            al = math.sin(w) / (2 * q)
            a0 = 1 + al
            b0, b2 = al / a0, -al / a0
            a1, a2 = -2 * math.cos(w) / a0, (1 - al) / a0
        o = b0 * v + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y.append(o)
    return y


def env_exp(x, ataque=0.005, queda=0.2):
    """Ataque linear e queda exponencial (queda = tempo para cair ~63%)."""
    na = n_am(ataque)
    k = math.exp(-1.0 / (queda * SR)) if queda > 0 else 0.0
    y, g = [], 1.0
    for i, v in enumerate(x):
        if i < na:
            y.append(v * i / na)
        else:
            g *= k
            y.append(v * g)
    return y


def janela(x, ataque=0.005, soltura=0.03):
    n = len(x)
    na, ns = min(n, n_am(ataque)), min(n, n_am(soltura))
    y = list(x)
    for i in range(na):
        y[i] *= i / na
    for i in range(ns):
        y[n - 1 - i] *= i / ns
    return y


def seno_glide(seg, f0, f1, curva=1.0):
    n = n_am(seg)
    y, fase = [], 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n) ** (1.0 / curva)
        fase += TAU * f / SR
        y.append(math.sin(fase))
    return y


def saturar(x, ganho, assimetria=0.0):
    off = math.tanh(assimetria)
    return [math.tanh(v * ganho + assimetria) - off for v in x]


def limitar(canais, limiar=0.5, razao=4.0, soltura=0.12, loop=False):
    """Compressor simples ligado nos canais juntos (mantém a imagem estéreo).
    `loop`: começa já 'aquecido' com o fim do arquivo, para o ganho não pular na emenda."""
    ka = math.exp(-1 / (0.002 * SR))
    kr = math.exp(-1 / (soltura * SR))
    env = 0.0
    n = len(canais[0])
    if loop:
        for i in range(max(0, n - SR), n):
            p = max(abs(c[i]) for c in canais)
            env = ka * env + (1 - ka) * p if p > env else kr * env + (1 - kr) * p
    saida = [[0.0] * n for _ in canais]
    expo = 1 - 1 / razao
    for i in range(n):
        p = max(abs(c[i]) for c in canais)
        env = ka * env + (1 - ka) * p if p > env else kr * env + (1 - kr) * p
        g = 1.0 if env <= limiar else (limiar / env) ** expo
        for c, s in zip(canais, saida):
            s[i] = c[i] * g
    return saida


def salvar(caminho, canais, pico=0.95):
    """canais: lista com 1 (mono) ou 2 (estéreo) listas de amostras."""
    m = max(1e-9, max(abs(v) for c in canais for v in c))
    k = pico / m
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with wave.open(caminho, "wb") as w:
        w.setnchannels(len(canais))
        w.setsampwidth(2)
        w.setframerate(SR)
        if len(canais) == 1:
            dados = [int(max(-1.0, min(1.0, v * k)) * 32767) for v in canais[0]]
        else:
            dados = [int(max(-1.0, min(1.0, v * k)) * 32767) for par in zip(*canais) for v in par]
        w.writeframes(struct.pack("<%dh" % len(dados), *dados))
    print("  ", os.path.relpath(caminho, RAIZ), f"{len(canais[0]) / SR:.2f}s")


_cache = {}


def guardado(chave, fazer):
    """Cada som é gerado uma vez, com semente própria (repetível)."""
    if chave not in _cache:
        semear(chave)
        _cache[chave] = fazer()
    return _cache[chave]


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def reverb(x, tamanho=1.0, mistura=0.25, cauda=1.5, desvio=0, circular=False):
    """Reverb de Schroeder (4 pentes + 2 passa-tudo). `desvio` muda os atrasos
    (canal direito diferente do esquerdo = estéreo). `circular` dobra a cauda no
    começo, para a música emendar em loop."""
    n = len(x)
    nc = n_am(cauda)
    entrada = x + [0.0] * nc
    molhado = [0.0] * len(entrada)
    for atraso, fb in ((1557, 0.84), (1617, 0.83), (1491, 0.85), (1422, 0.82)):
        d = int((atraso + desvio) * tamanho)
        buf = [0.0] * d
        j = 0
        for i, v in enumerate(entrada):
            s = buf[j]
            buf[j] = v + s * fb
            molhado[i] += s
            j = (j + 1) % d
    for atraso in (225, 556):
        d = int((atraso + desvio // 3) * tamanho)
        buf = [0.0] * d
        j = 0
        for i, v in enumerate(molhado):
            s = buf[j]
            buf[j] = v + s * 0.5
            molhado[i] = s - v * 0.5
            j = (j + 1) % d
    molhado = filtro(molhado, "pb", 6000)
    saida = [a + b * mistura * 0.25 for a, b in zip(entrada, molhado)]
    if circular:
        for i in range(nc):
            saida[i % n] += saida[n + i]
        return saida[:n]
    return saida


# --- percussão amazônica ---------------------------------------------------------

MODOS_PELE = ((1.0, 1.0), (1.59, 0.55), (2.14, 0.4), (2.30, 0.3), (2.65, 0.22), (2.92, 0.15), (3.16, 0.1))


def membrana(f, seg, queda, curvatura=0.35, brilho=1.0):
    """Pele de tambor por modos (razões de Bessel) com a altura caindo no ataque."""
    n = n_am(seg)
    y = [0.0] * n
    kp = math.exp(-1 / (0.025 * SR))
    for r, a in MODOS_PELE:
        a *= brilho ** (r - 1)
        k = math.exp(-1 / (queda / math.sqrt(r) * SR))
        g, fase, fr = a, rnd.random() * TAU, f * r
        p = curvatura
        for i in range(n):
            fase += TAU * fr * (1 + p) / SR
            p *= kp
            y[i] += math.sin(fase) * g
            g *= k
    return y


def curimba(altura=90.0, tapa=False):
    """Curimbó: tronco escavado com couro, tocado com as mãos."""
    def fazer():
        if tapa:
            x = membrana(altura * 2.2, 0.25, 0.05, brilho=1.3)
            estalo = env_exp(filtro(ruido(0.05), "pf", 2400, 0.9), 0.0005, 0.012)
            return janela(misturar(x, estalo, 0, 1.2), 0.0005, 0.02)
        x = membrana(altura, 0.6, 0.18, brilho=0.8)
        oco = env_exp(filtro(ruido(0.4), "pf", altura * 1.5, 6), 0.002, 0.1)  # ressonância do tronco
        mao = env_exp(filtro(ruido(0.03), "pb", 1500), 0.0005, 0.008)
        misturar(x, oco, 0, 2.0)
        return janela(misturar(x, mao, 0, 0.8), 0.0005, 0.05)
    return guardado(("curimba", altura, tapa), fazer)


def maraca(seg=0.12, chacoalhada=1.0):
    """Maracá: modelo de partículas (sementes batendo dentro da cabaça)."""
    def fazer():
        n = n_am(seg)
        y = [0.0] * n
        energia = 0.3
        ke = math.exp(-1 / (seg * 0.3 * SR))
        for i in range(n):
            if i < n * 0.15:
                energia = min(1.0, energia + 0.0003)
            else:
                energia *= ke
            if rnd.random() < 0.12 * energia:
                y[i] = rnd.uniform(-1, 1) * energia
        a = filtro(y, "pf", 3200, 2.5)
        b = filtro(y, "pf", 5600, 3)
        return janela([p + 0.7 * q for p, q in zip(a, b)], 0.001, 0.01)
    return [v * chacoalhada for v in guardado(("maraca", seg), fazer)]


def pau_de_chuva(seg=1.2):
    """Grãos caindo devagar (pau-de-chuva), para curas e despedidas."""
    def fazer():
        n = n_am(seg)
        y = [0.0] * n
        for i in range(n):
            if rnd.random() < 0.02 * math.sin(math.pi * i / n):
                y[i] = rnd.uniform(-1, 1)
        return filtro(filtro(y, "pf", 4200, 4), "pa", 2000)
    return guardado(("pau_de_chuva", seg), fazer)


# --- bateria de metal ---------------------------------------------------------------

def bumbo(duplo=False):
    def fazer():
        corpo = env_exp(seno_glide(0.35, 140, 48, curva=7), 0.001, 0.07 if duplo else 0.12)
        clique = env_exp(filtro(ruido(0.012), "pf", 3500, 1.2), 0.0003, 0.003)
        return janela(misturar(corpo, clique, 0, 0.9), 0.0005, 0.02)
    return guardado(("bumbo", duplo), fazer)


def caixa():
    def fazer():
        pele = membrana(190, 0.25, 0.06, curvatura=0.15, brilho=1.2)
        esteira = env_exp(filtro(filtro(ruido(0.3), "pa", 1200), "pico", 4000, 1, 6), 0.0008, 0.09)
        return janela(misturar([v * 0.6 for v in pele], esteira, 0, 1.0), 0.0005, 0.03)
    return guardado("caixa", fazer)


def metal_cluster(seg, queda, corte=7000):
    """Prato/chimbal: seis ondas quadradas inarmônicas (como as baterias eletrônicas)."""
    n = n_am(seg)
    y = [0.0] * n
    for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0):
        per = SR / (f * 1.7)
        meio = per / 2
        y = [v + (1.0 if (i % per) < meio else -1.0) for i, v in enumerate(y)]
    y = filtro(filtro(y, "pa", corte), "pa", corte)
    y = misturar(y, filtro(ruido(seg), "pa", corte), 0, 2.0)
    return env_exp(y, 0.0005, queda)


def chimbal(aberto=False):
    return guardado(("chimbal", aberto), lambda: metal_cluster(0.4 if aberto else 0.08, 0.15 if aberto else 0.02))


def prato():
    return guardado("prato", lambda: metal_cluster(2.2, 0.7, 4500))


def tom(altura):
    return guardado(("tom", altura), lambda: janela(membrana(altura, 0.5, 0.15, curvatura=0.3), 0.0005, 0.05))


# --- cordas -------------------------------------------------------------------------

def corda(f, seg, brilho=0.6, perda=0.997, posicao=0.15):
    """Karplus-Strong com posição da palheta e atraso fracionário (afinado)."""
    p_real = SR / f + 0.5
    p = max(2, int(p_real))
    frac = p_real - p
    c = (1 - frac) / (1 + frac)  # passa-tudo para o pedaço fracionário do atraso
    exc = filtro([rnd.uniform(-1, 1) for _ in range(p)], "pb", 800 + 9000 * brilho)
    d = max(1, int(p * posicao))
    buf = [exc[i] - 0.7 * exc[i - d] for i in range(p)]
    y = []
    i = 0
    ax = ay = 0.0
    for _ in range(n_am(seg)):
        a = buf[i]
        media = (a + buf[(i + 1) % p]) * 0.5 * perda
        ay = c * media + ax - c * ay
        ax = media
        buf[i] = ay
        y.append(a)
        i = (i + 1) % p
    return y


def viola(nota, seg=0.9, brilho=0.55):
    """Viola de dez cordas (pares em oitava/uníssono), com caixa de madeira."""
    def fazer():
        f = midi_hz(nota)
        x = corda(f, seg, brilho)
        par = corda(f * (2.0 if nota < 60 else 1.003), seg, brilho)
        x = [a + 0.6 * b for a, b in zip(x, par)]
        corpo = filtro(x, "pf", 220, 1.5)
        corpo2 = filtro(x, "pf", 480, 2)
        x = [a + 0.8 * b + 0.4 * c for a, b, c in zip(x, corpo, corpo2)]
        return janela(x, 0.0005, 0.04)
    return guardado(("viola", nota, seg, brilho), fazer)


def gabinete(x):
    """Caixa de guitarra: corta graves e agudos ásperos, realça o médio."""
    x = filtro(x, "pa", 90)
    x = filtro(x, "pico", 1800, 0.8, 4)
    x = filtro(x, "pico", 400, 1.0, -3)
    x = filtro(x, "pb", 5200, 0.8)
    return filtro(x, "pb", 6500, 0.6)


def guitarra(raiz, seg, abafada=False, take=0):
    """Guitarra base distorcida (power chord tônica + quinta + oitava).
    `take` diferente = outra gravação, para dobrar esquerda/direita."""
    def fazer():
        x = [0.0] * n_am(seg)
        perda = 0.975 if abafada else 0.9985
        for k, m in enumerate((raiz, raiz + 7, raiz + 12)):
            misturar(x, corda(midi_hz(m), seg, 0.9, perda, 0.12), k * 0.003 * (1 + take))
        x = x[:n_am(seg)]
        if abafada:
            x = filtro(x, "pb", 1400)
        x = filtro(x, "pa", 120)
        x = saturar(x, 14.0 if abafada else 10.0, 0.15)
        return janela(gabinete(x), 0.0005, 0.02)
    return guardado(("guitarra", raiz, round(seg, 4), abafada, take), fazer)


def baixo(nota, seg):
    def fazer():
        x = corda(midi_hz(nota), seg, 0.5, 0.996, 0.2)
        sub = env_exp([math.sin(TAU * midi_hz(nota) * i / SR) for i in range(len(x))], 0.003, seg)
        x = saturar([a + 0.5 * b for a, b in zip(x, sub)], 2.5)
        return janela(filtro(x, "pb", 1600), 0.001, 0.02)
    return guardado(("baixo", nota, round(seg, 4)), fazer)


def solo(nota, seg):
    """Guitarra solo: duas dente-de-serra com vibrato, distorção e caixa."""
    def fazer():
        f = midi_hz(nota)
        y = []
        f1 = f2 = 0.0
        for i in range(n_am(seg)):
            t = i / SR
            v = 1 + 0.006 * min(1.0, max(0.0, (t - 0.15) / 0.2)) * math.sin(TAU * 5.5 * t)
            f1 = (f1 + f * v / SR) % 1.0
            f2 = (f2 + f * 1.003 * v / SR) % 1.0
            y.append(f1 + f2 - 1.0)
        y = saturar(filtro(y, "pb", 3000), 6.0, 0.1)
        return janela(gabinete(y), 0.006, 0.04)
    return guardado(("solo", nota, round(seg, 4)), fazer)


# --- sopros e vozes ---------------------------------------------------------------------

def flauta(nota, seg):
    """Flauta de bambu: fundamental forte, sopro de ar e vibrato que chega devagar."""
    def fazer():
        f = midi_hz(nota)
        sopro = filtro(ruido(seg), "pf", f * 2, 2.5)
        y = []
        fase = 0.0
        for i in range(n_am(seg)):
            t = i / SR
            v = 1 + 0.008 * min(1.0, max(0.0, (t - 0.12) / 0.25)) * math.sin(TAU * 5.2 * t)
            fase += TAU * f * v / SR
            y.append(math.sin(fase) + 0.18 * math.sin(2 * fase) + 0.07 * math.sin(3 * fase))
        y = [a + 0.12 * b for a, b in zip(y, sopro)]
        misturar(y, env_exp(filtro(ruido(0.06), "pf", f * 3, 1.5), 0.002, 0.02), 0, 0.5)
        return janela(y[:n_am(seg)], 0.035, min(0.08, seg * 0.3))
    return guardado(("flauta", nota, round(seg, 4)), fazer)


VOGAIS = {"a": (800, 1150, 2900), "o": (450, 800, 2830), "u": (325, 700, 2530), "e": (400, 1700, 2600)}


def formantes(x, vogal, escala=1.0):
    f1, f2, f3 = (v * escala for v in VOGAIS[vogal])
    a = filtro(x, "pf", f1, 6)
    b = filtro(x, "pf", f2, 8)
    c = filtro(x, "pf", f3, 10)
    return [p + 0.6 * q + 0.25 * r for p, q, r in zip(a, b, c)]


def coro(nota, seg, vogal="a"):
    """Coro 'aah': três vozes levemente desafinadas por nota, com vibrato."""
    def fazer():
        f = midi_hz(nota)
        n = n_am(seg)
        y = [0.0] * n
        for k, det in enumerate((-0.006, 0.0, 0.007)):
            fase = rnd.random()
            vel = rnd.uniform(4.5, 5.8)
            for i in range(n):
                v = 1 + det + 0.005 * math.sin(TAU * vel * i / SR + k)
                fase = (fase + f * v / SR) % 1.0
                y[i] += 2 * fase - 1
        y = formantes(y, vogal, 1.0 if nota < 64 else 1.1)
        n_at = min(n, n_am(min(0.25, seg * 0.3)))
        for i in range(n_at):
            y[i] *= i / n_at
        return janela(y, 0.01, min(0.2, seg * 0.3))
    return guardado(("coro", nota, round(seg, 4), vogal), fazer)


def _tabela_palheta():
    n = 2048
    harm = [(1, 1.0), (2, 0.55), (3, 0.6), (4, 0.3), (5, 0.35), (6, 0.15), (7, 0.2), (8, 0.08), (9, 0.1)]
    t = [sum(a * math.sin(TAU * h * i / n) for h, a in harm) for i in range(n)]
    m = max(abs(v) for v in t)
    return [v / m for v in t]


TAB_PALHETA = _tabela_palheta()


def acordeom(nota, seg):
    """Acordeom de marujada: três palhetas (uma afinada, duas 'musette')."""
    def fazer():
        tab, tn = TAB_PALHETA, len(TAB_PALHETA)
        f = midi_hz(nota)
        passos = [f * d * tn / SR for d in (0.996, 1.0, 1.0045)]
        fases = [rnd.random() * tn for _ in passos]
        y = []
        for _ in range(n_am(seg)):
            s = 0.0
            for k in range(3):
                fases[k] += passos[k]
                s += tab[int(fases[k]) % tn]
            y.append(s)
        return janela(filtro(y, "pb", 4000), min(0.04, seg * 0.3), min(0.06, seg * 0.3))
    return guardado(("acordeom", nota, round(seg, 4)), fazer)


def sino(freq, seg=1.2):
    """Sino de cristal por FM (portadora 1 : modulador 3,5)."""
    def fazer():
        y = []
        ki = math.exp(-1 / (0.15 * SR))
        ka = math.exp(-1 / (seg * 0.35 * SR))
        ind, amp = 3.0, 1.0
        for i in range(n_am(seg)):
            t = i / SR
            y.append(math.sin(TAU * freq * t + ind * math.sin(TAU * freq * 3.5 * t)) * amp)
            ind *= ki
            amp *= ka
        return janela(y, 0.001, 0.05)
    return guardado(("sino", freq, seg), fazer)


# --- vozes dos bichos ---------------------------------------------------------------------

def pulsos_glote(n, f_ini, f_fim, aspereza=0.0, jitter=0.01):
    """Fonte de voz: pulsos suaves com variação natural de altura."""
    y, fase = [], 0.0
    for i in range(n):
        f = (f_ini + (f_fim - f_ini) * i / n) * (1 + rnd.uniform(-jitter, jitter))
        if aspereza:
            f *= 1 + 0.08 * aspereza * math.sin(TAU * 33 * i / SR)
        fase = (fase + f / SR) % 1.0
        y.append(math.sin(math.pi * fase) ** 3 - 0.42)
    return y


def voz(tipo, f0, seg, queda=0.75, vogal="a", aspereza=0.0):
    """Voz curta de bicho. tipo: grito, ave, coruja, sapo, chiado, madeira, agua."""
    n = n_am(seg)
    if tipo in ("grito", "sapo"):
        y = pulsos_glote(n, f0 * 1.15, f0 * queda, aspereza)
        sopro = filtro(ruido(seg), "pb", 3000)
        y = [a + b * (0.15 + 0.35 * aspereza) for a, b in zip(y, sopro)]
        y = formantes(y, vogal, max(0.55, min(1.5, (f0 / 140) ** 0.35)))
        if aspereza:  # rosnado: sub-harmônico e corpo grave
            sub = pulsos_glote(n, f0 * 0.58, f0 * queda * 0.5, 0)
            y = misturar(y, filtro(sub, "pb", 400), 0, 0.8 * aspereza)
        if tipo == "sapo":
            y = [v * (0.5 + 0.5 * math.sin(TAU * 26 * i / SR)) ** 3 for i, v in enumerate(y)]
        return janela(env_exp(y, 0.02, seg * 0.6), 0.005, seg * 0.35)
    if tipo == "ave":
        y = [0.0] * n
        for s in range(3):
            pio = seno_glide(seg / 3 * 0.8, f0 * 7.5, f0 * 5, curva=0.6)
            misturar(y, env_exp(pio, 0.004, seg / 3 * 0.35), s * seg / 3, 1.0 - 0.2 * s)
        return janela(y[:n], 0.002, 0.02)
    if tipo == "coruja":
        y = [0.0] * n
        for k, (ts, d) in enumerate(((0.0, 0.45), (0.5, 0.5))):
            h = seno_glide(seg * d, f0 * 1.05, f0 * queda, curva=1.5)
            h = [a + 0.3 * b for a, b in zip(h, filtro(ruido(seg * d), "pf", f0, 8))]
            misturar(y, janela(env_exp(h, 0.05, seg * 0.25), 0.04, 0.08), seg * ts, 1.0 - 0.25 * k)
        return y[:n]
    if tipo == "chiado":
        h = filtro(filtro(ruido(seg), "pa", 4000), "pico", 6500, 1.5, 6)
        h = [v * (0.6 + 0.4 * math.sin(TAU * 45 * i / SR)) for i, v in enumerate(h)]
        return janela(env_exp(h, 0.03, seg * 0.6), 0.01, seg * 0.35)
    if tipo == "madeira":  # rangido de tronco: estalos que aceleram + folhas
        y = [0.0] * n
        t = 0.0
        while t < seg * 0.85:
            y[int(t * SR)] = rnd.uniform(0.6, 1.0)
            t += max(0.004, 0.028 * (1.0 - 0.6 * t / seg) * (200.0 / f0))
        a = filtro(y, "pf", f0 * 2.5, 6)
        b = filtro(y, "pf", f0 * 5.3, 8)
        y = misturar([p + 0.5 * q for p, q in zip(a, b)], maraca(seg, 0.15), 0, 1.0)
        return janela(env_exp(y[:n], 0.005, seg * 0.6), 0.003, seg * 0.3)
    if tipo == "agua":  # boto: assobio com trinado + cliques
        y = []
        fase = 0.0
        for i in range(n):
            t = i / n
            f = f0 * 5 * (1.0 + 0.25 * math.sin(math.pi * t)) * (queda ** t) * (1 + 0.02 * math.sin(TAU * 18 * i / SR))
            fase += TAU * f / SR
            y.append(math.sin(fase))
        y = env_exp(y, 0.02, seg * 0.5)
        for k in range(8):
            misturar(y, env_exp(filtro(ruido(0.008), "pa", 3000), 0.0003, 0.002), k * 0.028, 0.8)
        return janela(y[:n], 0.005, seg * 0.3)
    raise ValueError(tipo)


# --- camadas dos efeitos ---------------------------------------------------------------

def vulto(seg=0.2, f0=500, f1=2600, forca=1.0):
    """Zunido de golpe no ar: ruído com filtro deslizando e volume em arco."""
    x = varredura(ruido(seg), f0, f1, 1.8)
    n = len(x)
    return [v * forca * 3 * math.sin(math.pi * i / n) ** 1.8 for i, v in enumerate(x)]


def impacto(peso=1.0, material="carne"):
    """Acerto: grave que bate no peito + corpo do material + estalo."""
    sub = env_exp(seno_glide(0.3, 110 - 40 * peso, 42, curva=5), 0.001, 0.08 + 0.08 * peso)
    if material == "madeira":
        corpo = env_exp(filtro(ruido(0.2), "pf", 320, 5), 0.001, 0.05)
        corpo = misturar([v * 4 for v in corpo], membrana(260, 0.2, 0.04, brilho=1.3), 0, 0.3)
    elif material == "pedra":
        corpo = env_exp(filtro(ruido(0.25), "pf", 700, 2), 0.001, 0.06)
        corpo = [v * 3 for v in corpo]
    else:
        corpo = env_exp(filtro(ruido(0.2), "pb", 900), 0.001, 0.045)
    estalo = env_exp(filtro(ruido(0.02), "pa", 2500), 0.0003, 0.004)
    x = misturar([v * (0.9 * peso + 0.3) for v in sub], corpo, 0, 1.0)
    return misturar(x, estalo, 0, 0.6)


def metal(f=2200, seg=0.5):
    """Lâmina: parciais inarmônicas em pares que batem (brilho de aço)."""
    x = [0.0] * n_am(seg)
    for mult, amp in ((1.0, 1.0), (1.007, 0.8), (2.32, 0.5), (2.34, 0.4), (4.25, 0.25), (6.63, 0.12)):
        p = env_exp([math.sin(TAU * f * mult * i / SR) for i in range(len(x))], 0.0005, seg * 0.25 / mult ** 0.3)
        misturar(x, p, 0, amp * 0.3)
    return misturar(x, env_exp(filtro(ruido(0.06), "pa", 4000), 0.0005, 0.012), 0, 0.5)


def sala(x, tamanho=0.6, mistura=0.35):
    return reverb(x, tamanho, mistura, cauda=0.8)


def ataque(tipo, f0, peso):
    if tipo == "contundente":
        x = vulto(0.22, 300, 1500, 0.8)
        return sala(misturar(x, impacto(peso, "madeira"), 0.19, 1.2))
    if tipo == "lamina":
        x = misturar(vulto(0.15, 800, 4200), metal(1900 + f0 * 2), 0.12)
        return sala(misturar(x, impacto(0.4), 0.12, 0.6))
    if tipo == "duplo":
        x = misturar(vulto(0.12, 900, 4500), metal(2500), 0.09)
        misturar(x, vulto(0.12, 1000, 5000), 0.17)
        return sala(misturar(x, metal(3000), 0.26, 0.9))
    if tipo == "garras":
        x = voz("grito", 52, 0.75, 0.7, "o", aspereza=1.0)
        for k in range(3):
            misturar(x, vulto(0.16, 250 + 60 * k, 1800, 1.3), 0.1 + k * 0.12)
            misturar(x, metal(1200 + 250 * k, 0.3), 0.22 + k * 0.12, 0.5)
        return sala(misturar(x, impacto(1.0), 0.48, 1.4), 1.0, 0.45)
    if tipo == "lanca":
        x = vulto(0.12, 1100, 3200)
        misturar(x, env_exp(filtro(ruido(0.08), "pf", 1600, 2), 0.0005, 0.02), 0.1, 3.0)
        return sala(misturar(x, impacto(peso * 0.7, "madeira"), 0.1, 0.8))
    if tipo == "mordida":
        x = voz("madeira", f0, 0.3)
        for k in range(2):
            misturar(x, env_exp(filtro(ruido(0.06), "pb", 2200), 0.0005, 0.015), 0.08 + k * 0.11, 1.5)
            misturar(x, impacto(0.5, "madeira"), 0.08 + k * 0.11, 0.7)
        return sala(x)
    if tipo == "investida":
        x = vulto(0.45, 200, 2400, 1.1)
        for k in range(4):  # passos
            misturar(x, impacto(0.3, "madeira"), k * 0.09, 0.3)
        return sala(misturar(x, impacto(peso), 0.42, 1.3))
    if tipo == "chicote":
        x = vulto(0.22, 400, 3500, 0.7)
        crack = env_exp(filtro(ruido(0.03), "pa", 2000), 0.0002, 0.005)
        return sala(misturar(x, crack, 0.21, 2.5))
    if tipo == "folha":
        x = []
        for k in range(6):
            misturar(x, maraca(0.08, 3.0), k * 0.03)
        return sala(misturar(x, impacto(0.5, "madeira"), 0.16, 1.0))
    if tipo == "dardo":
        x = env_exp(filtro(ruido(0.12), "pf", 800, 1.5), 0.004, 0.04)  # sopro na zarabatana
        x = [v * 3 for v in x]
        misturar(x, env_exp(seno_glide(0.16, 2600, 1900), 0.004, 0.08), 0.06, 0.25)
        return sala(misturar(x, impacto(0.2, "madeira"), 0.22, 0.8))
    if tipo in ("flecha", "espinhos"):
        x = env_exp(corda(midi_hz(40 if tipo == "flecha" else 47), 0.4, 0.7, 0.99), 0.001, 0.1)
        for k in range(1 if tipo == "flecha" else 3):
            misturar(x, vulto(0.2, 2500, 5500, 0.6), 0.03 + 0.06 * k)
            misturar(x, impacto(0.3, "madeira"), 0.24 + 0.06 * k, 0.9)
        return sala(x)
    if tipo == "luz":
        x = []
        base = 72 + (2 if f0 > 200 else 0)
        for k, m in enumerate((0, 4, 7, 12, 16)):
            misturar(x, sino(midi_hz(base + m), 1.0), k * 0.045, 0.45)
        misturar(x, varredura(ruido(0.6), 2000, 9000, 4), 0.0, 0.6)
        return sala(x, 1.0, 0.5)
    if tipo == "penas":
        x = voz("coruja", f0, 0.7, 0.8)
        for k in range(3):  # bater de asas
            misturar(x, env_exp(filtro(ruido(0.09), "pb", 1300), 0.01, 0.03), 0.1 + k * 0.11, 2.0)
        return sala(x, 0.9, 0.45)
    if tipo == "esporos":
        x = env_exp(filtro(ruido(0.35), "pb", 600), 0.01, 0.1)
        x = [v * 3 for v in x]
        for k in range(14):
            b = env_exp(seno_glide(0.04, rnd.uniform(500, 1400), rnd.uniform(1500, 2600)), 0.001, 0.012)
            misturar(x, b, 0.1 + k * rnd.uniform(0.02, 0.04), 0.3)
        return sala(x)
    if tipo == "fumaca":
        r = varredura(ruido(1.0), 300, 1400, 2.0)
        x = [v * 3 * math.sin(math.pi * i / len(r)) for i, v in enumerate(r)]
        return sala(misturar(x, voz("sapo", f0, 0.45, 0.85, "o"), 0.0, 0.35), 0.9, 0.4)
    if tipo == "bote":
        x = voz("chiado", f0, 0.4)
        misturar(x, vulto(0.2, 600, 3000), 0.22)
        return sala(misturar(x, impacto(0.5), 0.4, 1.0))
    raise ValueError(tipo)


# --- tabelas: personagens e habilidades ------------------------------------------
# id (igual aos .tres de scripts/combate/habilidades/ataques) :
#   (tipo do ataque básico, tipo de voz, altura da voz em Hz, peso 0..1, vogal)
PERSONAGENS = {
    "bufalo": ("lamina", "grito", 90, 1.0, "o"),
    "tartaruga": ("contundente", "grito", 120, 0.9, "u"),
    "tartaruga_paladina": ("contundente", "grito", 120, 0.9, "u"),
    "murucututu": ("penas", "coruja", 380, 0.3, "u"),
    "guara": ("flecha", "ave", 320, 0.4, "a"),
    "boto": ("luz", "agua", 600, 0.6, "a"),
    "onca": ("lamina", "grito", 135, 0.7, "a"),
    "acaizeiro": ("contundente", "madeira", 120, 0.7, "o"),
    "vitoria_regia": ("folha", "madeira", 150, 0.6, "o"),
    "carnivora": ("mordida", "madeira", 100, 0.8, "o"),
    "cogumelo": ("esporos", "madeira", 420, 0.3, "e"),
    "golem_toco": ("contundente", "madeira", 70, 1.0, "o"),
    "bromelia": ("espinhos", "madeira", 330, 0.4, "e"),
    "aninga": ("lanca", "madeira", 200, 0.6, "o"),
    "buriti": ("investida", "madeira", 220, 0.5, "o"),
    "sapo_dardo": ("dardo", "sapo", 520, 0.2, "e"),
    "tartaruga_amazonia": ("luz", "grito", 160, 0.7, "u"),
    "iguana": ("flecha", "grito", 260, 0.4, "e"),
    "teiu": ("contundente", "grito", 180, 0.6, "a"),
    "naga": ("bote", "chiado", 240, 0.6, "e"),
    "coral": ("lamina", "chiado", 280, 0.4, "e"),
    "cobra_cavaleira": ("lanca", "chiado", 160, 0.7, "e"),
    "jacare_acu": ("contundente", "grito", 75, 1.0, "o"),
    "jacaretinga": ("duplo", "grito", 170, 0.6, "a"),
    "cururu": ("fumaca", "sapo", 140, 0.6, "o"),
    "perereca": ("chicote", "sapo", 460, 0.3, "e"),
    "mapinguari": ("garras", "grito", 52, 1.0, "o"),
}


def dano(tipo_voz, f0, peso, vogal):
    x = impacto(peso)
    aspero = 0.9 if f0 < 70 else 0.0
    return sala(misturar(x, voz(tipo_voz, f0, 0.38, 0.8, vogal, aspero), 0.03, 0.9), 0.5, 0.25)


def morte(tipo_voz, f0, peso, vogal):
    aspero = 1.0 if f0 < 70 else 0.0
    x = voz(tipo_voz, f0, 1.0 + 0.5 * peso, 0.5, vogal, aspero)
    t = 0.75 + 0.3 * peso
    misturar(x, impacto(peso, "madeira"), t, 1.2)  # corpo no chão
    misturar(x, env_exp(filtro(ruido(0.5), "pb", 700), 0.01, 0.15), t, 1.2 * peso)
    misturar(x, pau_de_chuva(1.4), t, 0.5)  # despedida: pau-de-chuva e flauta descendo
    misturar(x, flauta(76, 0.45), t + 0.1, 0.25)
    misturar(x, flauta(71, 0.8), t + 0.45, 0.25)
    return sala(x, 1.0, 0.4)


def hab_golpe():
    x = vulto(0.38, 200, 2200, 1.3)
    misturar(x, impacto(1.0, "pedra"), 0.35, 1.5)
    misturar(x, curimba(55), 0.35, 1.0)
    misturar(x, prato(), 0.35, 0.15)
    return sala(x, 1.0, 0.4)


def hab_golpe_cajado():
    x = vulto(0.24, 450, 2600)
    return sala(misturar(x, impacto(0.6, "madeira"), 0.21, 1.2))


def hab_area():
    x = list(curimba(42))
    misturar(x, impacto(1.0, "pedra"), 0, 1.5)
    misturar(x, env_exp(filtro(ruido(1.4), "pb", 250), 0.01, 0.45), 0, 3.0)
    for _ in range(14):  # pedrinhas caindo
        misturar(x, impacto(0.1, "pedra"), rnd.uniform(0.15, 0.9), rnd.uniform(0.1, 0.25))
    return sala(x, 1.1, 0.45)


def hab_casco_firme():
    x = impacto(0.8, "pedra")
    for f in (380, 590, 1070, 1730, 2650):
        misturar(x, env_exp([math.sin(TAU * f * i / SR) for i in range(n_am(1.1))], 0.002, 0.35), 0, 0.12)
    misturar(x, coro(57, 0.9, "o"), 0.05, 0.08)
    misturar(x, coro(64, 0.9, "o"), 0.05, 0.06)
    return sala(x, 1.0, 0.45)


def hab_cura(notas, passo=0.09):
    x = []
    for k, m in enumerate(notas):
        misturar(x, sino(midi_hz(m), 1.2), k * passo, 0.5)
    misturar(x, pau_de_chuva(1.0 + 0.1 * len(notas)), 0, 0.6)
    misturar(x, flauta(notas[-1], 0.6), passo * len(notas), 0.3)
    return sala(x, 1.0, 0.5)


def hab_mare():
    onda = varredura(ruido(1.8), 250, 900, 1.2)
    onda = [v * 3 * math.sin(math.pi * i / len(onda)) * (0.7 + 0.3 * math.sin(TAU * 1.4 * i / SR))
            for i, v in enumerate(onda)]
    x = misturar(onda, hab_cura([67, 71, 74, 79, 83], 0.12), 0.2, 1.4)
    misturar(x, coro(55, 1.6, "u"), 0.1, 0.06)
    return sala(x, 1.1, 0.45)


HABILIDADES = {
    "golpe": hab_golpe,
    "golpe_cajado": hab_golpe_cajado,
    "area": hab_area,
    "casco_firme": hab_casco_firme,
    "cura_leve": lambda: hab_cura([72, 76, 79]),
    "cura_forte": lambda: hab_cura([67, 72, 76, 79, 84], 0.1),
    "mare_curativa": hab_mare,
}


def efeito(nome, fazer):
    semear(nome)
    x = filtro(fazer(), "pa", 35)  # tira grave inaudível que só come volume
    m = max(1e-9, max(abs(v) for v in x))
    x = limitar([[v / m for v in x]], 0.5, 3.0, 0.08)[0]
    fim = len(x)
    while fim > SR // 4 and abs(x[fim - 1]) < 0.003:  # corta o silêncio do fim da cauda
        fim -= 1
    x = janela(x[:fim], 0.0, 0.05)
    salvar(os.path.join(DIR_ACOES, nome + ".wav"), [x], 0.95)


def gerar_acoes():
    print("Efeitos de ação:")
    for pid, (atq, tv, f0, peso, vogal) in PERSONAGENS.items():
        efeito(pid + "_ataque", lambda: ataque(atq, f0, peso))
        efeito(pid + "_dano", lambda: dano(tv, f0, peso, vogal))
        efeito(pid + "_morte", lambda: morte(tv, f0, peso, vogal))
    for hid, fazer in HABILIDADES.items():
        efeito("hab_" + hid, fazer)


# --- trilhas: power metal amazônico -------------------------------------------------------
# Compasso 4/4 = 16 semicolcheias. Nota = (midi, duração em semicolcheias), None = pausa.
# Seções: intro, verso, refrao (guitarras gêmeas + coro), ponte (só a floresta).

ACORDES = {  # nome: (tônica da guitarra, notas do coro/acordeom)
    "Em": (40, [64, 67, 71]), "C": (48, [60, 64, 67]), "D": (50, [62, 66, 69]),
    "B": (47, [59, 63, 66]), "G": (43, [62, 67, 71]), "Am": (45, [60, 64, 69]),
    "Dm": (50, [62, 65, 69]), "Bb": (46, [58, 62, 65]), "F": (41, [60, 65, 69]),
    "A": (45, [61, 64, 69]), "Gm": (43, [62, 67, 70]),
}

EXPLORACAO = {
    "bpm": 168,
    "escala": {4, 6, 7, 9, 11, 0, 2},  # Mi menor / Sol maior
    "secoes": [
        ("intro", ["Em", "C", "D", "B"], [
            [(76, 4), (79, 2), (83, 2), (81, 4), (79, 4)], [(79, 2), (76, 2), (72, 4), (76, 8)],
            [(78, 4), (81, 2), (78, 2), (74, 4), (78, 4)], [(75, 4), (78, 4), (83, 8)]]),
        ("verso", ["Em", "Em", "C", "C", "D", "D", "B", "B"], [
            [(64, 2), (67, 2), (71, 4), (69, 2), (67, 2), (66, 4)], [(64, 4), (71, 4), (67, 8)],
            [(64, 2), (67, 2), (72, 4), (71, 2), (69, 2), (67, 4)], [(69, 4), (67, 4), (64, 8)],
            [(66, 2), (69, 2), (74, 4), (72, 2), (71, 2), (69, 4)], [(71, 4), (72, 4), (74, 8)],
            [(75, 4), (71, 4), (66, 4), (71, 4)], [(75, 2), (78, 2), (75, 2), (71, 2), (66, 8)]]),
        ("refrao", ["G", "D", "Em", "C", "G", "D", "C", "D"], [
            [(79, 6), (78, 2), (79, 4), (83, 4)], [(81, 6), (79, 2), (78, 8)],
            [(76, 4), (78, 4), (79, 4), (83, 4)], [(84, 8), (83, 4), (79, 4)],
            [(79, 6), (78, 2), (79, 4), (86, 4)], [(86, 4), (84, 4), (83, 4), (81, 4)],
            [(79, 4), (81, 4), (83, 4), (84, 4)], [(86, 12), (None, 4)]]),
        ("ponte", ["Em", "D", "C", "B"], [
            [(88, 2), (86, 2), (83, 4), (86, 2), (83, 2), (79, 4)], [(81, 4), (78, 4), (74, 8)],
            [(76, 2), (79, 2), (84, 4), (83, 2), (79, 2), (76, 4)], [(78, 4), (75, 4), (71, 8)]]),
    ],
}

CHEFE = {
    "bpm": 188,
    "escala": {2, 4, 5, 7, 9, 10, 1},  # Ré menor harmônica
    "secoes": [
        ("intro", ["Dm", "Dm", "Bb", "A"], [
            [(62, 2), (62, 2), (65, 2), (62, 2), (69, 4), (67, 4)], [(65, 2), (64, 2), (62, 4), (57, 8)],
            [(58, 2), (62, 2), (65, 4), (70, 4), (69, 4)], [(64, 4), (61, 4), (57, 8)]]),
        ("verso", ["Dm", "Dm", "C", "C", "Bb", "Bb", "A", "A"], [
            [(74, 4), (77, 4), (81, 4), (79, 2), (77, 2)], [(76, 4), (74, 4), (69, 8)],
            [(72, 4), (76, 4), (79, 4), (77, 2), (76, 2)], [(74, 4), (72, 4), (67, 8)],
            [(70, 4), (74, 4), (77, 4), (76, 2), (74, 2)], [(72, 4), (70, 4), (65, 8)],
            [(69, 4), (73, 4), (76, 4), (79, 4)], [(81, 4), (79, 2), (76, 2), (73, 8)]]),
        ("refrao", ["Dm", "Bb", "F", "C", "Dm", "Bb", "A", "A"], [
            [(81, 6), (79, 2), (77, 4), (74, 4)], [(77, 6), (76, 2), (74, 8)],
            [(72, 4), (74, 4), (77, 4), (81, 4)], [(79, 8), (76, 8)],
            [(81, 6), (79, 2), (77, 4), (86, 4)], [(86, 4), (84, 4), (82, 4), (81, 4)],
            [(81, 4), (79, 4), (76, 4), (73, 4)], [(76, 12), (None, 4)]]),
        ("ponte", ["Dm", "Dm", "Bb", "A"], [
            [(62, 8), (65, 8)], [(69, 8), (67, 8)], [(65, 8), (62, 8)], [(61, 16)]]),
    ],
}

# Toque de carimbó (16 semicolcheias): G = grave, T = tapa.
CARIMBO = "G..T.GT.G..T.GT."


def terca_abaixo(nota, escala):
    """Harmonia de guitarra gêmea: a nota da escala duas posições abaixo."""
    if nota % 12 not in escala:
        return nota - 4
    m, passos = nota, 0
    while passos < 2:
        m -= 1
        if m % 12 in escala:
            passos += 1
    return m


class Estereo:
    def __init__(self, seg):
        n = n_am(seg)
        self.l = [0.0] * n
        self.r = [0.0] * n

    def por(self, src, t, ganho=1.0, pan=0.0):
        a = (pan + 1) * math.pi / 4
        misturar(self.l, src, t, ganho * math.cos(a))
        misturar(self.r, src, t, ganho * math.sin(a))


def tocar(bus, melodia, t0, semi, instr, vol, pan=0.0, transpor=0, escala=None):
    t = t0
    for comp in melodia:
        for nota, dur in comp:
            seg = dur * semi
            if nota is not None:
                m = nota + transpor
                if escala is not None:
                    m = terca_abaixo(m, escala)
                if instr == "flauta":
                    bus.por(flauta(m, seg * 0.97), t, vol, pan)
                elif instr == "solo":
                    bus.por(solo(m, seg * 1.02), t, vol, pan)
                elif instr == "acordeom":
                    bus.por(acordeom(m, seg * 0.95), t, vol, pan)
            t += seg


def guitarras(bus, raiz, t, seg, abafada, vol):
    for take, pan in ((0, -0.85), (1, 0.85)):
        bus.por(guitarra(raiz, seg, abafada, take), t, vol, pan)


def musica(partitura, chefe=False):
    semi = 60.0 / partitura["bpm"] / 4
    comp = semi * 16
    total = sum(len(ac) for _, ac, _ in partitura["secoes"])
    bus = Estereo(total * comp)
    c = 0
    for nome, acordes, melodia in partitura["secoes"]:
        t_secao = c * comp
        for i, nome_ac in enumerate(acordes):
            t0 = c * comp
            raiz, notas_ac = ACORDES[nome_ac]
            grave = raiz - 12 if raiz >= 40 else raiz
            ultimo = i == len(acordes) - 1
            pesado = nome != "ponte"
            # --- bateria
            if pesado:
                for s in range(16):
                    ts = t0 + s * semi
                    if nome == "intro":  # galope
                        if s % 4 in (0, 2, 3):
                            bus.por(bumbo(True), ts, 0.8)
                    else:  # bumbo duplo
                        bus.por(bumbo(True), ts, 0.7 if s % 2 else 0.85)
                    if s in (4, 12):
                        bus.por(caixa(), ts, 0.9, 0.05)
                    if s % 2 == 0 and s != 0:
                        bus.por(chimbal(nome == "refrao" and s % 4 == 2), ts, 0.22, 0.3)
                if i == 0 or nome == "refrao" and i % 2 == 0:
                    bus.por(prato(), t0, 0.4, -0.4)
                elif nome == "refrao":
                    bus.por(prato(), t0, 0.3, 0.4)
                else:
                    bus.por(chimbal(), t0, 0.22, 0.3)
                if ultimo:  # virada de tons
                    for k, s in enumerate(range(8, 16)):
                        bus.por(tom(160 - k * 12), t0 + s * semi, 0.6, -0.5 + k * 0.14)
            else:  # ponte: só a floresta (curimbó forte, bumbo meio-tempo)
                for s in ((0, 3, 6, 10) if chefe else (0, 6, 8, 14)):
                    bus.por(bumbo(), t0 + s * semi, 0.8)
                if chefe:
                    bus.por(caixa(), t0 + 8 * semi, 0.8)
                if ultimo:  # rufo de caixa crescendo de volta para o começo
                    for s in range(16):
                        bus.por(caixa(), t0 + s * semi, 0.2 + 0.04 * s)
            # --- carimbó por cima (curimbó e maracá)
            vol = 0.65 if pesado else 1.0
            for s, ch in enumerate(CARIMBO):
                ts = t0 + s * semi
                if ch == "G":
                    bus.por(curimba(85 if chefe else 95), ts, 0.9 * vol, -0.35)
                elif ch == "T":
                    bus.por(curimba(110 if chefe else 120, tapa=True), ts, 0.5 * vol, -0.3)
                bus.por(maraca(0.1 if s % 2 == 0 else 0.07, 0.45 if s % 4 == 0 else 0.28), ts, vol, 0.55)
            # --- guitarras dobradas e baixo
            if pesado:
                for s in range(16):
                    ts = t0 + s * semi
                    if nome == "refrao":
                        if s in (0, 8):
                            guitarras(bus, raiz, ts, semi * 8, False, 0.4)
                    else:  # galope no mapa e na intro; metralhadora de semicolcheias no chefe
                        galope = nome == "intro" or not chefe
                        if not galope or s % 4 in (0, 2, 3):
                            aberto = s == 0
                            guitarras(bus, raiz, ts, semi * (2 if aberto else 0.9), not aberto, 0.38 if aberto else 0.3)
                    if s % 2 == 0:
                        bus.por(baixo(grave, semi * 1.9), ts, 0.55)
            else:
                if i >= len(acordes) - 2:  # guitarra volta abafada, crescendo
                    for s in range(0, 16, 2):
                        guitarras(bus, raiz, t0 + s * semi, semi * 0.9, True, 0.12 + 0.015 * s)
                bus.por(baixo(grave, comp * 0.9), t0, 0.5)
                for s in (0, 6, 8, 14):  # viola rasgando o acorde
                    for k, nota in enumerate(notas_ac):
                        bus.por(viola(nota, 0.6), t0 + s * semi + k * 0.012, 0.22, 0.3)
            # --- coro e acordeom segurando o acorde
            if nome == "refrao" or (chefe and nome != "verso"):
                for k, nota in enumerate(notas_ac):
                    bus.por(coro(nota, comp, "o" if chefe else "a"), t0, 0.05, -0.6 + 0.6 * k)
                    bus.por(coro(nota - 12, comp, "o"), t0, 0.035, 0.6 - 0.6 * k)
            if nome == "ponte":
                for nota in notas_ac:
                    bus.por(acordeom(nota - 12, comp), t0, 0.07, -0.2)
            c += 1
        # --- melodias da seção
        if nome == "intro":
            if chefe:  # riff grave em oitavas
                tocar(bus, melodia, t_secao, semi, "solo", 0.3)
                tocar(bus, melodia, t_secao, semi, "solo", 0.2, 0, -12)
            else:
                tocar(bus, melodia, t_secao, semi, "flauta", 0.45)
        elif nome == "verso":
            tocar(bus, melodia, t_secao, semi, "flauta", 0.45, 0.15)
            tocar(bus, melodia, t_secao, semi, "acordeom", 0.1, -0.25, -12)
        elif nome == "refrao":  # guitarras gêmeas em terças
            tocar(bus, melodia, t_secao, semi, "solo", 0.3, -0.25)
            tocar(bus, melodia, t_secao, semi, "solo", 0.24, 0.25, 0, partitura["escala"])
        elif chefe:
            tocar(bus, melodia, t_secao, semi, "acordeom", 0.2, 0.1)
        else:
            tocar(bus, melodia, t_secao, semi, "flauta", 0.5, 0.1)
    # mistura final: cauda de volta ao começo (loop), reverb estéreo, compressor
    n = n_am(total * comp)
    for canal in (bus.l, bus.r):
        for i, v in enumerate(canal[n:]):
            canal[i % n] += v
        del canal[n:]
    l = reverb(bus.l, 1.0, 0.22, circular=True)
    r = reverb(bus.r, 1.0, 0.22, desvio=23, circular=True)
    m = max(max(abs(v) for v in l), max(abs(v) for v in r))
    return limitar([[v / m for v in l], [v / m for v in r]], 0.35, 3.0, 0.15, loop=True)


def gerar_trilhas():
    print("Trilhas (demora um pouco):")
    salvar(os.path.join(DIR_TRILHAS, "exploracao_carimbo.wav"), musica(EXPLORACAO), 0.93)
    salvar(os.path.join(DIR_TRILHAS, "chefe_mapinguari.wav"), musica(CHEFE, chefe=True), 0.93)


if __name__ == "__main__":
    qual = sys.argv[1] if len(sys.argv) > 1 else "tudo"
    if qual in ("tudo", "acoes"):
        gerar_acoes()
    if qual in ("tudo", "trilhas"):
        gerar_trilhas()
    if qual in ("tudo", "batalhas"):
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import trilhas_batalha
        trilhas_batalha.gerar()
