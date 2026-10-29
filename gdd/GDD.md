# Game Design Document (GDD) — Xadrez Zumbi

> Versão de 29/10/2026. Este arquivo substitui o `Game Design Document (GDD) - Xadrez Zumbi.pdf` e o `Xadrez Zumbi.docx` (versões antigas, mantidas só como histórico).
>
> Documentos ligados: [missoes.md](missoes.md) (30 missões) · [bestiario-zumbis.md](bestiario-zumbis.md) (16 zumbis)

## 1. Visão geral

Jogo de tabuleiro tático em turnos, num mundo pós-apocalíptico. Junta as regras de movimento do xadrez com a sobrevivência contra zumbis, em pixel art 32-bits.

O jogador controla um grupo de sobreviventes. Cada um anda como uma peça de xadrez. O objetivo de cada missão é atravessar o tabuleiro (ou cumprir uma tarefa) sem ser pego pelos zumbis, que tentam morder e transformar os humanos.

- **Gênero:** estratégia por turnos, quebra-cabeça, sobrevivência
- **Plataforma:** PC (Godot 4.3); mobile no futuro
- **Público:** quem gosta de xadrez, quebra-cabeças e jogos táticos curtos

## 2. Mecânicas principais

### 2.1 Turnos

1. **Turno do jogador:** escolhe **um** personagem do grupo e faz **uma** ação: andar, atirar, usar item, usar habilidade ou esperar.
2. **Turno dos zumbis:** a IA move os zumbis pelo caminho mais curto até o sobrevivente mais próximo (ou até o barulho mais forte).
3. Repete até a missão ser cumprida ou falhar.

### 2.2 Combate

- Só o Sobrevivente (e alguns personagens) atiram. Atirar gasta munição e a rodada.
- Paredes, móveis, portas e outros zumbis bloqueiam tiros em linha.

| Arma | Alcance | Dano | Detalhe |
|---|---|---|---|
| Pistola | 2 casas | 1 | Arma inicial |
| Escopeta | 1 casa | 3 | Forte de perto |
| Rifle | 3 casas | 1 | Atravessa vários zumbis |
| Arco e Flecha | 4 casas | 1 | A flecha cai no chão e pode ser recuperada |

### 2.3 Vida, mordida e infecção

- **Todos os personagens têm vida**, numa escala de 0 a 100. O Sobrevivente tem 100; os outros têm 50 ou 70 (veja as tabelas da seção 4).
- Cada golpe de zumbi tira **34**. O kit médico cura **50** de quem estiver selecionado.
- Zumbis mordem conforme a peça de xadrez de cada um (ver bestiário).
- **Com 0 de vida o personagem morre.** Se for o Sobrevivente, a fase acaba. Os outros levantam como zumbi e passam a atacar o grupo.
- Se um personagem obrigatório (ex.: um bebê) morrer, a missão falha.

### 2.4 Mochila e itens

A mochila tem espaço limitado. Chave, kit médico e mamadeira ocupam espaço; munição e armas não.

**Itens comuns:** chave, kit médico, munição (+3), escopeta, rifle, arco, flecha solta (+1).

**Equipamentos (novos):** o Sobrevivente veste assim que pega e eles valem até o fim da fase. Do mesmo tipo (boné, mochila, calçado/anel) fica só o melhor; um item pior fica no chão.

| Letra | Item | Efeito | Aparece na fase |
|---|---|---|---|
| `1` | **Boné Branco** | +10% de vida (máx. 110) | 1 — Primeiros Passos |
| `2` | **Boné Verde** | +20% de vida (máx. 120) | 6 — Investida |
| `3` | **Boné Preto** | +30% de vida (máx. 130) | 9 — A Rainha |
| `v` | **Fita Vermelha** | Mordidas e tiros tiram 10% a menos (31 em vez de 34) | 2 — Rua Bloqueada |
| `u` | **Mochila Nível 2** | +30% de espaço (arredonda para cima) | 3 — O Melhor Amigo |
| `y` | **Mochila Militar** | +50% de espaço (arredonda para cima) | 7 — Delegacia |
| `o` | **Anel do Poder** | Anda até 2 casas em qualquer direção | 5 — Fila de Peões |
| `t` | **Tênis Branco** | Anda até 3 casas em qualquer direção | 8 — Cemitério |
| `m` | **Mamadeira** | Vai na mochila. Usar acalma os bebês por 3 rodadas: o choro para de atrair zumbis | 4 — Bebê Chorão |

Com o Anel ou o Tênis, o Sobrevivente desliza em linha reta ou diagonal, como a dama, e para ao encontrar móveis, paredes, portas ou outras peças.

### 2.5 Barulho

O barulho decide para onde os zumbis vão. Fontes de barulho: choro de bebê, tiro, latido do Thor, voz falsa do Kiwi, grito do Gritador. Usar barulho a favor (iscas) é uma das estratégias centrais.

## 3. Tabuleiro e cenário

- Malha de casas; o tamanho muda por missão.
- A saída padrão é a linha de cima do tabuleiro.
- Elementos: chão, mesa, entulho, parede, porta trancada, carros, ninhos (planejado), ponte (planejada).
- Cenários por capítulo: rua, bairro, centro, arredores (cemitério, hospital, ponte), estação.

## 4. Personagens

Protagonista + 9 pessoas + 3 pets. Cada um anda como uma peça de xadrez e tem uma habilidade.
A habilidade gasta a ação do personagem naquela rodada.

### 4.1 Protagonista

| Nome | Movimento | Vida (0–100) | Habilidade | Status |
|---|---|---|---|---|
| **Sobrevivente** | 1 casa em qualquer direção (rei); 2 ou 3 com Anel/Tênis | 100 | Atira, carrega a mochila e usa equipamentos | ✅ |

### 4.2 Pessoas

| Nome | Idade | Profissão | Movimento | Vida (0–100) | Habilidade |
|---|---|---|---|---|---|
| **Marina Costa** | 34 | Enfermeira | Rei (1 casa, qualquer direção) | 70 | Cura 34 de vida de quem está ao lado |
| **Rafael Duarte** | 41 | Mecânico | Até 2 casas em linha reta (torre curta) | 100 | Abre portas sem chave (2 rodadas) e empurra mesas |
| **Beatriz Lima** | 19 | Estudante | Até 2 casas na diagonal (bispo curto) | 70 | Chama a Pipoca; anda rápido pelas diagonais |
| **Otávio Ramos** | 67 | Professor aposentado | 1 casa reta, a cada 2 rodadas | 70 | Mostra onde estão os zumbis escondidos |
| **Júlia Nogueira** | 28 | Bombeira | Rei | 100 | Machado: quebra entulho e bate em zumbi ao lado (1 de dano) |
| **Caio Ferreira** | 12 | Estudante (filho da Marina) | Até 2 casas em qualquer linha (dama curta) | 50 | Passa por baixo das mesas |
| **Helena Souza** | 52 | Cozinheira | 1 casa reta | 70 | Joga comida até 3 casas: zumbis vão até lá por 2 rodadas |
| **Lucas** | 6 meses | Bebê no carrinho | Não anda sozinho: é empurrado 1 casa reta por quem está atrás | 50 | Chora se ficar 3 rodadas sem ninguém ao lado (atrai zumbis) |
| **Sofia** | 10 meses | Bebê engatinhando (filha do Rafael) | Engatinha 1 casa reta a cada 2 rodadas, sozinha | 50 | Vai na direção do barulho; para quando alguém a pega no colo |

### 4.3 Pets

| Nome | Animal | Dono | Movimento | Vida (0–100) | Habilidade |
|---|---|---|---|---|---|
| **Thor** | Cachorro pastor-alemão | Rafael | Em L, pula obstáculos (cavalo) | 70 | Late: os zumbis a até 3 casas vão até ele ✅ (movimento já no jogo) |
| **Pipoca** | Gata laranja | Beatriz | 1 casa na diagonal; sobe em mesas e carros | 50 | Em cima de um móvel, zumbis simples não alcançam |
| **Kiwi** | Papagaio | Otávio | Voa até 3 casas em qualquer linha, por cima de tudo | 50 | Imita vozes: cria um barulho falso numa casa até 4 casas |

### 4.4 Animações (todos os personagens)

Parado, andando, atacando/usando habilidade, ferido, morrendo, pedindo socorro e comemorando. Bebês têm "chorando"; pets têm "latir/miar/voar".

## 5. Zumbis

16 tipos: 8 simples (mordem de perto) e 8 com super poderes (atacam de longe). Lista completa com movimento, vida e poderes em [bestiario-zumbis.md](bestiario-zumbis.md). Todos já estão no jogo.

## 6. Regras novas planejadas

Regras que as missões 🔜 precisam (ver [missoes.md](missoes.md)):

| Regra | Usada nas missões |
|---|---|
| Habilidades dos personagens (cura, isca, abrir porta, machado, voz falsa…) | 5, 8, 11, 14, 16, 18, 22, 23 |
| Carrinho de bebê empurrado | 15, 27 |
| Bebê que engatinha sozinho | 9, 24, 27 |
| Pets que sobem em móveis / voam | 6, 17, 23, 29 |
| Escuridão (visão de 2 casas) e lanternas | 20 |
| Sobreviver N rodadas com ondas de zumbis | 25 |
| Ninhos que criam zumbis | 26 |
| Proteger alguém parado por várias rodadas | 22 |
| Só 1 peça anda por rodada com grupo grande | 28 |
| Escolher o grupo antes da missão | 28, 30 |

## 7. Progressão

- **5 capítulos, 30 missões**, com dificuldade crescente: novos zumbis, tabuleiros maiores e mais gente para proteger.
- **Estrelas:** cada missão dá até 3 (sair; ninguém mordido; desafio da missão).
- **Grupo:** cada pessoa resgatada entra no grupo e pode ser escolhida nas missões seguintes.
- **Loja entre capítulos (planejada):** gastar estrelas em armas, munição, mochila maior e melhorias das habilidades.

## 8. Interface

- Vida e munição do personagem selecionado; ícones da mochila; rodada atual.
- Passar o mouse num zumbi mostra o alcance (casas roxas = tiro, laranja = mordida).
- Linhas e áreas vermelhas avisam ataques que acontecem na próxima rodada.
- Tela de fim de missão com as estrelas ganhas.
- Menus: principal, pausa, mapa de missões, escolha do grupo, loja.

## 9. Arte e som

- **Arte:** pixel art retrô 32-bits, sprites 48×48 gerados no Gemini (veja `prompt-gemini-sprite-player.md` e a seção Arte do bestiário).
- **Som:** música e efeitos 32-bits gerados no Suno. Sons por personagem: choro dos bebês, latido, miado, papagaio imitando vozes.

## 10. Controles

Mouse e teclado no PC. Clicar num personagem seleciona; clicar numa casa anda; modo de tiro para atirar. No mobile, toque.
