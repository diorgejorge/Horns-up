"""Seis trilhas de batalha comum do Ato I (uma por ambiente), sintetizadas do zero.

Usa os instrumentos de gerar_audio.py (curimbó, maracá, viola, flauta, acordeom,
coro, bateria e guitarras de metal) e acrescenta o pandeiro. Melodias e riffs
originais. A trilha do chefe (Mapinguari) continua em gerar_audio.py.

Uso:   python audio/trilhas_batalha.py              (gera as seis)
       python audio/trilhas_batalha.py vila igarape (só essas)

Saída: assets/diorge/audio/trilhas/batalha_<ambiente>.wav (estéreo, 44,1 kHz, em loop).
Qual batalha toca qual trilha: campo "trilha" em scripts/campanha/dados_ato1.gd.

Como escrever as melodias: cada compasso (4/4) é uma linha de "grau/duração"
separados por espaço, compassos separados por "|". Grau 0 = tônica da trilha,
7 = oitava acima, -1 = sétimo grau abaixo; "+" sobe meio tom (ex.: 6+ = sensível),
"-" no lugar do grau = pausa. Duração em semicolcheias (16 = compasso inteiro).

Estilos de bateria por seção:
  galope   bumbo e guitarra em galope (colcheia + duas semicolcheias)
  duplo    bumbo duplo em semicolcheias, guitarra em colcheias
  metralha bumbo duplo e guitarra abafada em semicolcheias
  marcha   bumbo nos tempos, guitarra em colcheias, caixa marcial
  meio     meio-tempo pesado (caixa no 3), guitarra soando
  folk     sem bateria: percussão amazônica, viola rasgando, baixo e acordeom
Instrumentos da melodia: flauta, viola, acordeom, solo, gemeas (duas guitarras em
terças), riff (guitarra solo em oitavas, grave) e arpejo (gêmeas em arpejo, ignora a
melodia e segue os acordes).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gerar_audio as g  # noqa: E402

ESCALAS = {
    "menor": (0, 2, 3, 5, 7, 8, 10),
    "dorico": (0, 2, 3, 5, 7, 9, 10),
    "frigio": (0, 1, 3, 5, 7, 8, 10),
    "harmonica": (0, 2, 3, 5, 7, 8, 11),
}
NOTAS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


# --- leitura das partituras ---------------------------------------------------------------

def acorde(nome):
    """'F#m' -> (tônica da guitarra entre Mi1 e Ré#2, tríade do coro perto do Dó central)."""
    pc = NOTAS[nome[0]]
    resto = nome[1:]
    if resto.startswith("#"):
        pc, resto = pc + 1, resto[1:]
    elif resto.startswith("b"):
        pc, resto = pc - 1, resto[1:]
    pc %= 12
    terca = 3 if resto == "m" else 4
    raiz = 40 + (pc - 4) % 12
    base = 57 + (pc - 9) % 12  # tônica do coro entre Lá3 e Sol#4
    return raiz, [base, base + terca, base + 7]


def melodia(texto, tonica, modo):
    esc = ESCALAS[modo]
    compassos = []
    for i, bloco in enumerate(texto.split("|")):
        comp, soma = [], 0
        for tok in bloco.split():
            grau, dur = tok.split("/")
            dur = int(dur)
            soma += dur
            if grau == "-":
                comp.append((None, dur))
                continue
            mais = grau.endswith("+")
            d = int(grau.rstrip("+"))
            nota = tonica + 12 * (d // 7) + esc[d % 7] + (1 if mais else 0)
            comp.append((nota, dur))
        assert soma == 16, f"compasso {i + 1} soma {soma}: {bloco!r}"
        compassos.append(comp)
    return compassos


# --- instrumento novo: pandeiro -------------------------------------------------------------

def platinelas(seg, forca=1.0):
    """Platinelas do pandeiro: chapinhas de metal batendo (parciais agudos inarmônicos)."""
    def fazer():
        n = g.n_am(seg)
        y = [0.0] * n
        for f, a in ((4150, 1.0), (5320, 0.8), (6890, 0.6), (8410, 0.45), (9960, 0.3)):
            k = g.math.exp(-1 / (0.035 * g.SR))
            amp, fase = a, g.rnd.random() * g.TAU
            for i in range(n):
                y[i] += g.math.sin(fase + g.TAU * f * i / g.SR) * amp
                amp *= k
        chiado = g.env_exp(g.filtro(g.ruido(seg), "pa", 6000), 0.0005, 0.03)
        y = [a * 0.35 + b for a, b in zip(y, chiado)]
        return g.janela(y, 0.0005, 0.01)
    return [v * forca for v in g.guardado(("platinelas", seg), fazer)]


def pandeiro(golpe):
    """o = grave (polegar no couro), x = platinela, t = tapa com platinela."""
    def fazer():
        if golpe == "o":
            x = g.membrana(150, 0.3, 0.09, brilho=0.8)
            return g.janela(g.misturar(x, platinelas(0.12, 0.35), 0, 0.6), 0.0005, 0.03)
        if golpe == "t":
            x = g.membrana(330, 0.18, 0.04, brilho=1.4)
            estalo = g.env_exp(g.filtro(g.ruido(0.04), "pf", 2800, 0.9), 0.0005, 0.01)
            g.misturar(x, estalo, 0, 0.8)
            return g.janela(g.misturar(x, platinelas(0.15), 0, 0.9), 0.0005, 0.03)
        return platinelas(0.1, 0.8)
    return g.guardado(("pandeiro", golpe), fazer)


# --- as seis trilhas ----------------------------------------------------------------------
# Cada seção: (nome, bateria, acordes, instrumento da melodia, melodia)

VILA = {  # Vila de Aruã: heroica, galope, carimbó com pandeiro leve
    "arquivo": "batalha_vila", "bpm": 160, "tonica": 69, "modo": "menor",
    "curimbo": "G..T.GT.G..T.GT.", "pandeiro": "x.x.t.x.x.x.t.xx", "vogal": "a",
    "secoes": [
        ("intro", "galope", ["Am", "F", "G", "E"], "flauta",
         "4/4 7/2 6/2 4/4 2/4 | 5/4 4/2 2/2 0/8 | 1/4 3/2 4/2 6/4 4/4 | 6+/4 4/4 1/4 -1+/4"),
        ("verso", "duplo", ["Am", "Am", "F", "F", "C", "C", "G", "E"], "flauta",
         "0/2 2/2 4/4 2/2 0/2 -1/4 | 0/4 4/4 2/8 | -2/2 0/2 3/4 2/2 0/2 -2/4 | 0/4 2/4 0/8 |"
         "2/2 4/2 7/4 6/2 4/2 2/4 | 4/4 6/4 4/8 | 1/2 3/2 6/4 4/2 3/2 1/4 | 6+/4 4/4 1/8"),
        ("refrao", "galope", ["F", "G", "Am", "Am", "F", "G", "E", "E"], "gemeas",
         "7/6 6/2 5/4 7/4 | 8/6 7/2 6/8 | 7/4 9/4 11/4 9/4 | 11/8 9/4 7/4 |"
         "7/6 6/2 5/4 9/4 | 10/4 9/4 8/4 6/4 | 8/4 6+/4 4/4 6+/4 | 8/12 -/4"),
        ("solo", "duplo", ["Am", "F", "G", "E"], "arpejo", ""),
        ("ponte", "folk", ["Dm", "Am", "F", "E"], "flauta",
         "3/4 5/4 7/4 5/4 | 4/8 2/4 0/4 | 2/2 3/2 5/4 4/2 2/2 0/4 | 1/4 -1+/4 1/8"),
    ],
}

VARZEA = {  # Várzea das Águas: marujada, viola e pandeiro na frente, Ré dórico
    "arquivo": "batalha_varzea", "bpm": 148, "tonica": 62, "modo": "dorico",
    "curimbo": "G.T.G.T.GG.T.G.T", "pandeiro": "o.x.xtx.o.x.xtxx", "vogal": "a",
    "secoes": [
        ("intro", "folk", ["Dm", "C", "G", "Dm"], "viola",
         "7/2 9/2 11/2 9/2 7/4 11/4 | 13/2 11/2 9/2 11/2 13/8 | 10/2 12/2 14/2 12/2 10/4 8/4 | 9/4 8/4 7/8"),
        ("verso", "marcha", ["Dm", "Dm", "C", "C", "G", "G", "Am", "Am"], "flauta",
         "7/3 9/1 11/4 12/4 11/4 | 14/6 12/2 11/8 | 13/3 11/1 9/4 11/4 13/4 | 12/6 11/2 9/8 |"
         "10/3 12/1 14/4 15/4 14/4 | 12/6 14/2 10/8 | 11/3 13/1 15/4 14/4 13/4 | 12/4 13/4 11/8"),
        ("refrao", "duplo", ["F", "C", "G", "Dm", "F", "C", "G", "G"], "gemeas",
         "9/6 8/2 7/4 5/4 | 6/6 7/2 8/8 | 10/4 9/4 8/4 7/4 | 7/8 9/4 11/4 |"
         "13/6 11/2 9/4 7/4 | 8/4 9/4 8/4 6/4 | 7/4 8/4 10/4 12/4 | 10/12 -/4"),
        ("solo", "duplo", ["Dm", "C", "G", "Am"], "arpejo", ""),
        ("ponte", "meio", ["Am", "F", "C", "G"], "flauta",
         "11/8 13/4 15/4 | 16/8 14/8 | 13/4 15/4 13/4 11/4 | 10/12 -/4"),
    ],
}

IGARAPE = {  # Igarapé dos Ossos: sombria, meio-tempo, Mi frígio, pau-de-chuva e coro "u"
    "arquivo": "batalha_igarape", "bpm": 126, "tonica": 64, "modo": "frigio",
    "curimbo": "G.....T...G..T..", "pandeiro": None, "vogal": "u",
    "chuva": True,
    "secoes": [
        ("intro", "folk", ["Em", "F", "Dm", "Em"], "flauta",
         "7/8 8/4 7/4 | 9/6 8/2 7/8 | 6/4 5/4 3/4 5/4 | 4/4 1/4 0/8"),
        ("verso", "meio", ["Em", "Em", "F", "F", "Em", "Em", "Dm", "F"], "flauta",
         "7/4 10/2 11/2 12/4 11/4 | 10/4 8/4 7/8 | 8/4 10/2 12/2 14/4 12/4 | 11/4 12/4 8/8 |"
         "7/4 11/2 14/2 15/4 14/4 | 13/4 11/4 14/8 | 13/4 12/4 10/4 8/4 | 8/6 7/2 8/8"),
        ("refrao", "duplo", ["Am", "F", "G", "Em", "Am", "F", "Dm", "Em"], "gemeas",
         "3/6 2/2 3/4 5/4 | 5/6 3/2 1/8 | 2/4 4/4 6/4 4/4 | 0/12 -/4 |"
         "3/6 2/2 3/4 7/4 | 8/4 7/4 5/4 3/4 | 6/4 5/4 3/4 1/4 | 0/8 1/4 0/4"),
        ("solo", "metralha", ["Em", "F", "Em", "Dm"], "arpejo", ""),
        ("ponte", "meio", ["Em", "F", "Em", "F"], "acordeom",
         "7/16 | 8/16 | 7/8 4/8 | 8/16"),
    ],
}

FLORESTA = {  # Floresta das Sapopemas: a mais rápida, carimbó dobrado, Sol menor
    "arquivo": "batalha_floresta", "bpm": 178, "tonica": 67, "modo": "menor",
    "curimbo": "G.TGG.T.G.TGG.TT", "pandeiro": "x.xtx.x.x.xtx.xt", "vogal": "a",
    "secoes": [
        ("intro", "galope", ["Gm", "Eb", "F", "D"], "flauta",
         "7/2 9/2 11/2 9/2 7/4 4/4 | 9/2 8/2 7/2 5/2 4/8 | 6/2 8/2 10/2 8/2 6/4 3/4 | 4/4 6+/4 8/8"),
        ("verso", "galope", ["Gm", "Gm", "Eb", "Eb", "Cm", "Cm", "D", "D"], "flauta",
         "7/2 9/2 11/4 10/2 9/2 7/4 | 11/4 14/4 13/8 | 9/2 11/2 12/4 11/2 9/2 7/4 | 5/4 7/4 9/8 |"
         "10/2 12/2 14/4 12/2 10/2 9/4 | 10/4 9/4 7/8 | 8/2 11/2 13+/4 11/2 8/2 6+/4 | 8/4 13+/4 11/8"),
        ("refrao", "duplo", ["Eb", "F", "Gm", "Gm", "Eb", "F", "D", "D"], "gemeas",
         "2/4 1/4 0/4 2/4 | 3/6 2/2 1/8 | 0/4 2/4 4/4 7/4 | 6/8 4/4 2/4 |"
         "2/4 1/4 0/4 4/4 | 5/4 4/4 3/4 1/4 | 1/4 4/4 6+/4 8/4 | 6+/12 -/4"),
        ("solo", "metralha", ["Gm", "Eb", "Cm", "D"], "arpejo", ""),
        ("ponte", "folk", ["Cm", "Gm", "Eb", "D"], "flauta",
         "10/8 12/4 14/4 | 11/8 9/4 7/4 | 9/4 11/4 12/4 14/4 | 13+/12 -/4"),
    ],
}

RUINAS = {  # Ruínas dos Ceramistas: épica, marcha com coro "o" e sinos, Si menor harmônica
    "arquivo": "batalha_ruinas", "bpm": 140, "tonica": 71, "modo": "harmonica",
    "curimbo": "G...G.T.G...G.TT", "pandeiro": "o...t...o...t.t.", "vogal": "o",
    "sinos": True,
    "secoes": [
        ("intro", "marcha", ["Bm", "G", "Em", "F#"], "riff",
         "0/4 2/4 4/4 2/4 | 5/4 4/4 2/8 | 3/4 4/4 5/4 7/4 | 6/8 4/4 1/4"),
        ("verso", "marcha", ["Bm", "Bm", "G", "G", "Em", "Em", "F#", "F#"], "flauta",
         "4/2 7/2 9/4 8/2 7/2 6/4 | 7/4 11/4 9/8 | 5/2 7/2 10/4 9/2 7/2 5/4 | 9/4 8/4 7/8 |"
         "3/2 5/2 7/4 10/2 9/2 7/4 | 9/4 7/4 5/8 | 6/2 8/2 11/4 10/2 8/2 6/4 | 8/4 6/4 4/8"),
        ("refrao", "galope", ["G", "D", "Em", "Bm", "G", "D", "F#", "F#"], "gemeas",
         "0/6 2/2 3/4 2/4 | 2/6 1/2 0/8 | 0/4 1/4 2/4 3/4 | 4/8 2/4 0/4 |"
         "5/6 4/2 3/4 5/4 | 4/4 2/4 1/4 2/4 | 1/4 -1/4 -3/4 1/4 | -1/12 -/4"),
        ("solo", "duplo", ["Bm", "G", "Em", "F#"], "arpejo", ""),
        ("ponte", "meio", ["Em", "Bm", "G", "F#"], "flauta",
         "10/8 12/8 | 11/8 9/8 | 9/8 7/8 | 6/16"),
    ],
}

COVIL = {  # Trilha do covil (batalha 11): a mais tensa, metralha, Dó menor harmônica
    "arquivo": "batalha_covil", "bpm": 192, "tonica": 72, "modo": "harmonica",
    "curimbo": "GTGT..GTG.TT..GT", "pandeiro": None, "vogal": "o",
    "secoes": [
        ("intro", "metralha", ["Cm", "Ab", "Fm", "G"], "riff",
         "0/2 0/2 2/2 0/2 4/4 3/4 | 5/2 4/2 2/4 0/8 | 3/2 3/2 5/2 3/2 7/4 6/4 | 4/4 6/4 4/8"),
        ("verso", "metralha", ["Cm", "Cm", "Ab", "Ab", "Fm", "Fm", "G", "G"], "acordeom",
         "0/4 2/4 4/4 3/2 2/2 | 1/4 -1/4 0/8 | 0/2 2/2 5/4 4/2 2/2 0/4 | -2/4 0/4 2/8 |"
         "3/2 5/2 7/4 5/2 3/2 2/4 | 1/4 2/4 3/8 | 4/2 6/2 8/4 6/2 4/2 1/4 | 6/4 4/4 -1/8"),
        ("refrao", "duplo", ["Ab", "Eb", "Fm", "G", "Ab", "Eb", "G", "G"], "gemeas",
         "0/6 -1/2 -2/4 -3/4 | -3/6 -5/2 -3/8 | -2/4 0/4 3/4 2/4 | 1/8 -1/4 -3/4 |"
         "0/6 2/2 3/4 2/4 | 2/4 0/4 -3/4 0/4 | 1/4 -1/4 -3/4 -1/4 | 1/12 -/4"),
        ("solo", "metralha", ["Cm", "Ab", "Fm", "G"], "arpejo", ""),
        ("ponte", "meio", ["Fm", "Cm", "Ab", "G"], "acordeom",
         "3/8 2/8 | 0/16 | 0/8 -2/8 | -1/16"),
    ],
}

TRILHAS = {"vila": VILA, "varzea": VARZEA, "igarape": IGARAPE,
           "floresta": FLORESTA, "ruinas": RUINAS, "covil": COVIL}


# --- arranjo ------------------------------------------------------------------------------

def bateria(bus, estilo, t0, semi, ultimo, primeiro, refrao):
    por = bus.por
    for s in range(16):
        ts = t0 + s * semi
        if estilo == "galope":
            if s % 4 in (0, 2, 3):
                por(g.bumbo(True), ts, 0.8)
        elif estilo in ("duplo", "metralha"):
            por(g.bumbo(True), ts, 0.7 if s % 2 else 0.85)
        elif estilo == "marcha":
            if s % 4 == 0 or s in (6, 14):
                por(g.bumbo(), ts, 0.85)
        if estilo == "meio":
            continue
        if s in (4, 12):
            por(g.caixa(), ts, 0.9, 0.05)
        if estilo == "marcha" and s in (11, 15):  # repique marcial
            por(g.caixa(), ts, 0.35, 0.05)
        if s % 2 == 0 and s != 0:
            por(g.chimbal(refrao and s % 4 == 2), ts, 0.22, 0.3)
    if estilo == "meio":
        for s in (0, 3, 6, 10, 11):
            por(g.bumbo(), t0 + s * semi, 0.85)
        por(g.caixa(), t0 + 8 * semi, 0.95, 0.05)
        for s in range(0, 16, 4):
            por(g.chimbal(s == 4 or s == 12), t0 + s * semi, 0.25, 0.3)
    if primeiro or refrao:
        por(g.prato(), t0, 0.4 if primeiro else 0.3, -0.4)
    else:
        por(g.chimbal(), t0, 0.22, 0.3)
    if ultimo:  # virada de tons
        for k, s in enumerate(range(8, 16)):
            por(g.tom(160 - k * 12), t0 + s * semi, 0.6, -0.5 + k * 0.14)


def guitarra_base(bus, estilo, raiz, t0, semi, refrao):
    grave = raiz - 12 if raiz >= 40 else raiz
    for s in range(16):
        ts = t0 + s * semi
        if refrao and estilo != "meio":
            if s in (0, 8):
                g.guitarras(bus, raiz, ts, semi * 8, False, 0.4)
        elif estilo == "galope":
            if s % 4 in (0, 2, 3):
                aberto = s == 0
                g.guitarras(bus, raiz, ts, semi * (2 if aberto else 0.9), not aberto, 0.38 if aberto else 0.3)
        elif estilo == "metralha":
            aberto = s == 0
            g.guitarras(bus, raiz, ts, semi * (2 if aberto else 0.9), not aberto, 0.38 if aberto else 0.3)
        elif estilo in ("duplo", "marcha"):
            if s % 2 == 0:
                aberto = s in (0, 8)
                g.guitarras(bus, raiz, ts, semi * (2 if aberto else 1.4), not aberto, 0.38 if aberto else 0.3)
        elif estilo == "meio":
            if s in (0, 6):
                g.guitarras(bus, raiz, ts, semi * 6, False, 0.36)
            elif s in (3, 10, 11):
                g.guitarras(bus, raiz, ts, semi * 0.9, True, 0.3)
        if s % 2 == 0:
            bus.por(g.baixo(grave, semi * 1.9), ts, 0.55)


def folk(bus, raiz, notas, t0, semi, comp, final):
    grave = raiz - 12 if raiz >= 40 else raiz
    for s in (0, 6, 8, 14):
        bus.por(g.bumbo(), t0 + s * semi, 0.8)
    bus.por(g.baixo(grave, comp * 0.9), t0, 0.5)
    for s in (0, 3, 6, 8, 11, 14):  # viola de marujada rasgando o acorde
        for k, nota in enumerate(notas):
            bus.por(g.viola(nota, 0.6), t0 + s * semi + k * 0.012, 0.2 if s in (0, 8) else 0.13, 0.3)
    for nota in notas:
        bus.por(g.acordeom(nota - 12, comp), t0, 0.06, -0.2)
    if final:  # guitarra volta abafada, crescendo, e rufo de caixa
        for s in range(0, 16, 2):
            g.guitarras(bus, raiz, t0 + s * semi, semi * 0.9, True, 0.12 + 0.015 * s)
        for s in range(16):
            bus.por(g.caixa(), t0 + s * semi, 0.2 + 0.04 * s)


def percussao(bus, p, t0, semi, vol):
    for s, ch in enumerate(p["curimbo"]):
        ts = t0 + s * semi
        if ch == "G":
            bus.por(g.curimba(95), ts, 0.9 * vol, -0.35)
        elif ch == "T":
            bus.por(g.curimba(120, tapa=True), ts, 0.5 * vol, -0.3)
        bus.por(g.maraca(0.1 if s % 2 == 0 else 0.07, 0.45 if s % 4 == 0 else 0.28), ts, vol, 0.55)
        if p["pandeiro"] and p["pandeiro"][s] != ".":
            golpe = p["pandeiro"][s]
            bus.por(pandeiro(golpe), ts, (0.5 if golpe == "x" else 0.6) * vol, 0.4)


def arpejo(bus, acordes, t_secao, semi, escala):
    """Guitarras gêmeas em arpejo de semicolcheias, sobe e desce pelo acorde."""
    t = t_secao
    for nome in acordes:
        _, notas = acorde(nome)
        r, tc, q = (n + 12 for n in notas)
        figura = [r, tc, q, r + 12, q, tc] * 2 + [r, tc, q, r + 12]
        for s, nota in enumerate(figura):
            ts = t + s * semi
            bus.por(g.solo(nota, semi * 1.05), ts, 0.24, -0.3)
            bus.por(g.solo(g.terca_abaixo(nota, escala), semi * 1.05), ts, 0.19, 0.3)
        t += 16 * semi


def musica_batalha(p):
    semi = 60.0 / p["bpm"] / 4
    comp = semi * 16
    esc = ESCALAS[p["modo"]]
    escala = {(p["tonica"] + e) % 12 for e in esc}
    total = sum(len(s[2]) for s in p["secoes"])
    bus = g.Estereo(total * comp)
    c = 0
    for nome, estilo, acordes, instr, texto in p["secoes"]:
        t_secao = c * comp
        refrao = nome == "refrao"
        for i, nome_ac in enumerate(acordes):
            t0 = c * comp
            raiz, notas = acorde(nome_ac)
            ultimo = i == len(acordes) - 1
            if estilo == "folk":
                folk(bus, raiz, notas, t0, semi, comp, ultimo)
                percussao(bus, p, t0, semi, 1.0)
            else:
                bateria(bus, estilo, t0, semi, ultimo, i == 0, refrao)
                guitarra_base(bus, estilo, raiz, t0, semi, refrao)
                percussao(bus, p, t0, semi, 0.8 if estilo == "meio" else 0.6)
            # coro segura o acorde no refrão e nas seções lentas
            if refrao or estilo == "meio" or (p["vogal"] == "o" and nome == "intro"):
                for k, nota in enumerate(notas):
                    bus.por(g.coro(nota, comp, p["vogal"]), t0, 0.05, -0.6 + 0.6 * k)
                    bus.por(g.coro(nota - 12, comp, "o"), t0, 0.035, 0.6 - 0.6 * k)
            if p.get("sinos") and (i % 2 == 0) and nome in ("intro", "ponte", "refrao"):
                bus.por(g.sino(g.midi_hz(notas[0] + 24), 1.6), t0, 0.12, 0.5)
            if p.get("chuva") and i == 0 and nome in ("intro", "ponte"):
                bus.por(g.pau_de_chuva(comp * 2), t0, 0.5, -0.5)
            c += 1
        # --- melodia da seção
        if instr == "arpejo":
            arpejo(bus, acordes, t_secao, semi, escala)
            continue
        mel = [melodia(texto, p["tonica"], p["modo"])]
        if instr == "gemeas":
            g.tocar(bus, mel[0], t_secao, semi, "solo", 0.3, -0.25)
            g.tocar(bus, mel[0], t_secao, semi, "solo", 0.24, 0.25, 0, escala)
        elif instr == "riff":  # guitarra solo grave em oitavas
            g.tocar(bus, mel[0], t_secao, semi, "solo", 0.3, 0, -12)
            g.tocar(bus, mel[0], t_secao, semi, "solo", 0.2, 0, -24)
        elif instr == "viola":
            t = t_secao
            for compasso in mel[0]:
                for nota, dur in compasso:
                    if nota is not None:
                        bus.por(g.viola(nota, max(0.5, dur * semi * 1.5), 0.7), t, 0.5, -0.1)
                    t += dur * semi
            g.tocar(bus, mel[0], t_secao, semi, "flauta", 0.18, 0.2, 12)
        elif instr == "acordeom":
            g.tocar(bus, mel[0], t_secao, semi, "acordeom", 0.2, 0.1)
            g.tocar(bus, mel[0], t_secao, semi, "flauta", 0.2, -0.15, 12)
        else:  # flauta, com acordeom uma oitava abaixo no verso
            g.tocar(bus, mel[0], t_secao, semi, "flauta", 0.45, 0.15)
            if nome == "verso":
                g.tocar(bus, mel[0], t_secao, semi, "acordeom", 0.1, -0.25, -12)
    # mistura final igual às outras trilhas: cauda volta ao começo, reverb circular, compressor
    n = g.n_am(total * comp)
    for canal in (bus.l, bus.r):
        for i, v in enumerate(canal[n:]):
            canal[i % n] += v
        del canal[n:]
    l = g.reverb(bus.l, 1.0, 0.22, circular=True)
    r = g.reverb(bus.r, 1.0, 0.22, desvio=23, circular=True)
    m = max(max(abs(v) for v in l), max(abs(v) for v in r))
    return g.limitar([[v / m for v in l], [v / m for v in r]], 0.35, 3.0, 0.15, loop=True)


def gerar(quais=None):
    print("Trilhas de batalha do Ato I (demora um pouco):")
    for amb, p in TRILHAS.items():
        if quais and amb not in quais:
            continue
        caminho = os.path.join(g.DIR_TRILHAS, p["arquivo"] + ".wav")
        g.salvar(caminho, musica_batalha(p), 0.93)
        print(f"     {p['bpm']} bpm")


if __name__ == "__main__":
    gerar(sys.argv[1:] or None)
