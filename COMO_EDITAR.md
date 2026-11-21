# Como editar o jogo no Godot (3D)

Abra a pasta no Godot 4.7 e dê duplo clique numa cena em `scenes/3d/`:
`batalha_3d.tscn` (batalha 16x16) ou `mapa_mundi_3d.tscn` (mapa-múndi).
F5 roda o jogo, que começa no **Ato I** (mapa de Aruã): é lá que as 12 batalhas têm música e
efeitos de som. Dentro do jogo: **F3** Ato I, **F1** batalha de protótipo (sem música),
**F2** mapa-múndi de protótipo, **Esc** sai. Para testar uma batalha do Ato I direto, abra
`scenes/3d/ato1/batalha_NN.tscn` e aperte **F6**.

## Controles de teste
- Batalha: **Tab** troca o aliado selecionado (azul = onde ele pode andar, vermelho = casas
  vizinhas dos inimigos), **Espaço** faz ele atacar. Ainda não há combate de verdade.
- Mapa-múndi: **setas** movem o grupo uma casa; perto de um local, **Enter** abre a batalha.

## Peças (scenes/3d/pecas/<kit>/)
Uma cena por modelo: `terreno2` (pisos), `floresta`, `pantano`, `castelo` e `terreno` (peças cinza
com um material de pedra). Arraste a cena do painel FileSystem para dentro de `Terreno/` ou
`Cenario/`: ela **encaixa sozinha no centro da casa**. Ctrl+D duplica.
No Inspector (nó `Peca3D`):
- `piso`: as unidades pisam nela. Desligado = objeto (árvore, casa) em cima do piso.
- `andavel`: dá para andar nessa casa? (água funda, árvores e muros = não)
- `altura_topo`: altura onde os pés ficam. `tamanho`: quantas casas ocupa (piso do castelo = 2x2).
- Pisos giram de 90 em 90°; objetos giram livre. Escala e altura (Y) são livres, para empilhar.

## Personagens (Personagens/, nó Unidade3D)
- `modelo`: arraste um `.glb` de `assets/diorge/rigged/` (bichos), `rigged/minions/` ou `rigged/bosses/`.
- `display_name`, `classe`, `enemy` (anel vermelho), `escala`, `animacao` (idle, walk, attack, hurt, die).
- Atributos D&D (FOR, DES, CON, INT, SAB, CAR). A ordem de turno usa a **Destreza**.
- Arraste no editor: encaixa na casa e sobe até o piso dela. Gire no eixo Y para virar o rosto.

## Câmera, luz e locais
- `Camera` (ortográfica, fixa): mude o zoom em Size. O filho `Contorno` desenha o traço escuro.
- `Sol`, `LuzDoCeu` e `WorldEnvironment`: cores, sombras, brilho e oclusão.
- Fogueiras: nó `Fogo` (luz que tremula, ajuste `base_energy`).
- Mapa-múndi: cada nó em `Locais/` tem um nome e o metadado `batalha` (qual cena abrir).
- Na raiz da batalha: `selected_unit`, `move_range`, `salto` (maior degrau num passo), `show_ranges`.

## Ferramenta
`tools/gerar_cenas_3d.gd` cria as cenas de peça e as duas cenas acima. Ele **não sobrescreve**
arquivos que já existem; rode de novo para ganhar cenas de peças novas que você colocar nas pastas:
`Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/gerar_cenas_3d.gd`
Com `-- --forcar` ele refaz tudo e **apaga o que você editou** nessas cenas.
