# Horny UP — Bíblia do jogo (para o roteirista)

> Documento de referência com o conceito, o cenário, o elenco e os assets prontos. Ainda **não existe história**: tudo aqui é material para o roteiro construir em cima. Itens marcados com *(a confirmar)* são decisões em aberto.

---

## 1. Conceito

**Gênero:** RPG tático por turnos (estilo Final Fantasy Tactics / Tactics Ogre), com batalhas em grade.

**Visual:** 3D estilizado, "pintado à mão", com formas robustas e chanfros suaves. A câmera é isométrica e fixa, como num diorama. Habilidades terão efeitos de luz marcantes.

**Motor:** Godot 4. Cenários montados com peças modulares encaixadas numa grade (1 casa = 1 bloco).

**Tom e identidade:** fantasia inspirada na **Amazônia** e na **Ilha de Marajó (Pará)**. Todos os personagens são **animais antropomórficos** ou **seres do folclore amazônico**. A estética une três coisas:
- **Natureza amazônica:** rios, várzeas, igapós, mata densa, samaúmas, açaizais e vitórias-régias.
- **Cultura nortista e ribeirinha:** palafitas, canoas, cuias, tacacá, açaí, carimbó e vaqueiros de búfalo de Marajó.
- **Arte marajoara:** a cerâmica pré-colonial da Ilha de Marajó, com grafismos geométricos em vermelho, preto e creme, urnas funerárias, tangas de cerâmica e muiraquitãs. Ela aparece em roupas, armaduras, armas, construções e totens.

**Mecânicas principais:**
- Atributos no estilo D&D (Força, Destreza, Constituição, Inteligência, Sabedoria, Carisma). A **Destreza define a ordem dos turnos**.
- Movimento em grade, respeitando a altura do terreno, a água e os obstáculos.
- Batalhas de **8 contra 8**, em mapas de no mínimo 16x16.
- **Classes base:** Guerreiro, Mago, Ranger, Clérigo, Assassino e Paladino. Classes avançadas virão depois.
- Inventário e equipamento só **fora** da batalha.
- **Mapa-múndi** navegável, com regiões (floresta, pântano, vila/fortaleza, montanhas, rio) que levam às batalhas.

---

## 2. O mundo / cenário

Um arquipélago-floresta de rios, inspirado em Marajó e na bacia amazônica. Regiões já representadas em assets:

| Região | Descrição | Elementos |
|---|---|---|
| **Floresta amazônica (mata densa)** | Floresta fechada, úmida, com luz filtrada e árvores gigantes. | Samaúmas com sapopemas, açaizeiros, buritis, cipós, samambaias, troncos ocos, cogumelos bioluminescentes, cachoeiras pequenas. |
| **Pântano / várzea marajoara** | Terras alagadas que mudam com as cheias, com lama, juncos e manguezais. | Lama, água rasa, mangue com raízes aéreas, vitórias-régias, aninga, palafitas, passarelas de tábua, canoas encalhadas, cupinzeiros, totens de cerâmica. |
| **Campos e rios de Marajó** | Pastos alagáveis, praias de rio e bancos de areia; terra dos búfalos. | Grama alagada, areia de rio, barrancos, corredeiras, cercas de gado, pasto de búfalos. |
| **Vila / fortaleza amazônica** | Povoado fortificado de pedra de laterita vermelha e madeira de lei, amarrado com cipó e coberto de palha. | Muralhas, torres com telhado de palha, portão de madeira entalhada, urnas marajoaras gigantes, totens com penas, braseiros de barro, pontes de corda, torres de vigia sobre palafitas. |
| **Locais místicos** | Lugares rituais e ruínas de uma civilização antiga ceramista. | Altares com cristais, pedras rúnicas com grafismo marajoara, totens de pajé, tambores rituais, cocares. |

**Ganchos de mundo sugeridos** *(livres para o roteirista)*:
- Uma **civilização antiga marajoara** deixou ruínas, urnas e pedras rúnicas: os "Ceramistas".
- As **cheias e vazantes** dos rios podem ser um ciclo do mundo, alterando mapas e rotas.
- Os seres do folclore (bosses) podem ser **guardiões corrompidos** ou **forças da natureza** desequilibradas.
- Os monstros-planta (minions) podem ser a floresta "acordando" ou reagindo a uma ameaça.

---

## 3. Heróis

| Personagem | Classe / função | Características |
|---|---|---|
| **Tartaruga Paladina** (jabuti) | Paladino, tanque defensivo | Casco grosso como armadura, escudo de pedra e maça. Lenta, resistente e protetora. Promovida de inimiga a heroína. |
| Búfalo Guerreiro *(a confirmar)* | Guerreiro, dano corpo a corpo | Musculoso, chifres largos, armadura de placas, espadão. |
| Coruja Maga *(a confirmar)* | Mago, dano mágico à distância | Olhos âmbar enormes, manto azul, cajado com cristal, grimório. |
| Raposa Ranger *(a confirmar)* | Ranger, dano à distância e mobilidade | Ágil, capa verde com capuz, arco longo. |
| Cervo Clérigo *(a confirmar)* | Clérigo, cura e suporte | Galhada elegante, vestes brancas e douradas, maça com emblema de sol. |
| Gato Assassino *(a confirmar)* | Assassino, dano crítico e furtividade | Pelo preto, olhos verdes, couro escuro, duas adagas curvas. |

> Os cinco heróis originais vieram do primeiro rascunho, com visual de fantasia mais genérico, e ainda não foram adaptados ao tema amazônico. O roteirista pode propor heróis novos dentro do tema (ex.: animais ribeirinhos).

---

## 4. Bosses — seres do folclore amazônico e marajoara

| Boss | Origem folclórica | Função em batalha | Características |
|---|---|---|---|
| **Curupira** | Guardião da floresta, com pés virados para trás e cabelo de fogo. | Boss ágil, ilusões, rastros falsos | Pequeno, selvagem, roupa de folhas, porrete. |
| **Iara** | Sereia dos rios que encanta e afoga. | Controle (encantamento) e água | Cabelos negros longos, cauda de peixe, tridente, joias de concha. |
| **Matinta Perera** | Bruxa que vira pássaro e assobia à noite (lenda paraense). | Maldições e debuffs | Velha curvada, manto de penas escuras, máscara de coruja, cajado torto. |
| **Mãe-da-Mata** | Espírito protetor das matas. | Invocação de plantas (comanda minions) | Alta, corpo de casca e cipós, flores no cabelo, lança de madeira. |
| **Mapinguari** | Gigante peludo de um olho só, com boca na barriga. | Bruto, dano massivo | Parecido com uma preguiça-gigante, garras enormes. |
| **Boitatá** | Serpente de fogo que protege os campos. | Dano de fogo em área | Serpente erguida de chamas azuis, olhos em brasa. |
| **Anhangá** | Espírito em forma de veado branco que protege os animais. | Investidas rápidas, assombração | Cervo fantasmagórico (quadrúpede), olhos pálidos, chifres ramificados. |
| **Cobra Grande (Boiúna)** | Sucuri gigante que forma os rios. | Boss final ou de rio, dano e controle | Tronco humanoide com cauda longa, escamas escuras, armadura de urnas marajoaras, lança de osso. |

---

## 5. Inimigos

### 5.1 Inimigos genéricos — animais de Marajó e da Amazônia
Tropa comum, com uma classe para cada um. Roupas com grafismo marajoara.

| Inimigo | Classe | Características |
|---|---|---|
| **Búfalo-de-Marajó** | Guerreiro | Couro cinza-escuro, chifres largos, armadura de bronze e couro, arma de duas mãos. |
| **Murucututu** (coruja-de-óculos) | Mago | Manchas brancas como óculos, manto verde, cajado com cristal e cipó. |
| **Guará** (ave vermelha) | Ranger | Penas escarlates, bico longo curvo, arco longo, aljava. |
| **Boto-cor-de-rosa** | Clérigo | Pele rosada, focinho fino, vestes brancas, chapéu da lenda do boto, cajado com orbe d'água. |
| **Onça-pintada** | Assassino | Pelo dourado com rosetas, máscara, duas adagas de osso. |

### 5.2 Minions — monstros da flora amazônica
Plantas animadas; servem bem como lacaios da Mãe-da-Mata ou do Curupira.

| Minion | Função | Características |
|---|---|---|
| Guerreiro Açaizeiro | Corpo a corpo | Folhas de palmeira como cabelo, clava de cacho de açaí. |
| Criatura Vitória-régia | Tanque | Escudo de folha, flor rosa como cabeça, pernas de raiz. |
| Bruto Planta-carnívora | Corpo a corpo, agarrar | Braços de cipó, boca babando. |
| Diabrete Cogumelo | Suporte, esporos | Pequeno, chapéu bioluminescente. |
| Golem de Toco | Tanque | Toco musgoso com punhos de casca. |
| Arqueira Bromélia | À distância | Arco de cipó, dispara espinhos. |
| Lanceiro Aninga | Alcance médio | Lança de folha em forma de flecha. |
| Batedor Buriti | Batedor rápido | Cabeça de fruto escamoso vermelho, capa de palha. |

### 5.3 Mobs — répteis e anfíbios amazônicos (antropomórficos)

| Mob | Função | Características |
|---|---|---|
| Sapo-dardo | Assassino com veneno | Pequeno, azul com pintas pretas, zarabatana. |
| Tartaruga-da-amazônia | Clérigo | Casco desenhado, vestes, cajado d'água. |
| Iguana | Ranger | Crista espinhosa, capa de penas, arco. |
| Teiú | Lutador | Listrado de preto e branco, punhos enfaixados. |
| Naga / Jiboia | Feiticeira | Corpo de cobra sem pernas, manto com capuz, cajado. |
| Cobra-coral | Assassina | Anéis vermelhos, pretos e amarelos, duas lâminas. |
| Cobra cavaleira (surucucu) | Cavaleiro | Escamas em losango, lança e escudo. |
| Jacaré-açu | Guerreiro pesado | Enorme, placas de osso, clava. |
| Jacaretinga | Batedor | Esguio, colete de couro, duas facas. |
| Sapo-cururu | Xamã | Gordo e verrugoso, colares de cabaça, cajado-cachimbo. |
| Perereca-macaco | Acrobata | Esguia, dedos longos, chicote de cipó. |

> O jabuti com escudo deste grupo virou a heroína **Tartaruga Paladina**.

---

## 6. Assets prontos (modelos 3D)

Todos estão em `assets/diorge/` no projeto Godot. Os personagens têm esqueleto humanoide padrão e as animações **parado, andar, atacar, tomar dano e morrer**.

| Grupo | Pasta | Conteúdo |
|---|---|---|
| Inimigos genéricos | `rigged/` | Búfalo, coruja, guará, boto, onça |
| Bosses | `rigged/bosses/` | Os 8 do folclore |
| Minions | `rigged/minions/` | As 8 plantas |
| Mobs e heróis | `rigged/mobs/`, `rigged/herois/` | 11 répteis e anfíbios, Tartaruga Paladina |
| Terreno | `terreno/`, `terreno2/` | Blocos de grama, terra, areia, água, penhascos, rampas, escadas, cachoeira, vitórias-régias |
| Várzea e mata densa | `terreno3/` | 30 tiles marajoaras: raízes com musgo, lama, campo alagado, juncos, mangue, samambaias, cipós, barro vermelho, areia de rio, barrancos, tablado de madeira, cais de palafita, pedra molhada, corredeira, pasto de búfalo, campo florido, sapopemas, tronco caído, laje com grafismo marajoara. Água funda, vitórias-régias, corredeira e troncos não são andáveis. |
| Vila / fortaleza | `castelo/` | Muralhas, torres, portão, urna marajoara, totens, braseiro, ponte de corda |
| Pântano | `pantano/` | Lama, água, mangue, palafita, passarela, canoa, cupinzeiro |
| Floresta | `floresta/` | Samaúma, açaizeiros, buriti, cipós, cogumelos, cachoeira |
| Props | `props/` | Tesouros (baú, urna com ouro, poções, altar), pesca (cais, redes, cestos, remos), ritual (totem, tambor, pedra rúnica, cocar), utensílios de aldeia (25 itens, de rede de dormir a cobertura de palha) |

**Cenas jogáveis:** uma batalha de teste 3D (16x16, 8 contra 8) e um mapa-múndi 3D com floresta, pântano, aldeia, montanhas e rio.

---

## 7. Perguntas em aberto para o roteiro

1. Quem é o grupo de heróis e por que lutam? (Os 5 heróis originais ficam ou são substituídos por animais amazônicos?)
2. Qual é o conflito central: corrupção da floresta, invasão, desequilíbrio das cheias, despertar dos Ceramistas?
3. Os bosses do folclore são vilões, guardiões enganados ou aliados que se tornam inimigos?
4. Por que os animais de Marajó (búfalos, botos, onças) lutam contra os heróis: facções, tribos, mercenários?
5. Qual é a ordem das regiões no mapa-múndi e onde fica cada boss?

> **Cuidado cultural:** o folclore e a arte marajoara são patrimônio de povos indígenas e ribeirinhos do Pará. Recomenda-se tratá-los com respeito e, se possível, consultar referências locais.
