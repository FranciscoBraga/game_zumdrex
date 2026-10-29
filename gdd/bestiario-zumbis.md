# Bestiário — Xadrez Zumbi

16 zumbis: 8 simples (atacam só de perto, andam até 3 casas) e 8 com super poderes (atacam de longe, andam mais).
Os movimentos usam peças de xadrez. A letra é a usada nos mapas de `script/levels.gd`.

Legenda de status: ✅ no jogo · 🔜 planejado

"1 de dano" = 1 golpe = **34 de vida** do Sobrevivente (a vida vai de 0 a 100; a Fita Vermelha reduz para 31).

## Zumbis simples (ataque corpo a corpo, até 3 casas)

| # | Letra | Nome | Movimento | Ataque | Vida | Detalhe | Status |
|---|---|---|---|---|---|---|---|
| 1 | Z | **Zumbi Comum** | 1 casa reta | Morde a casa vizinha reta | 2 | O mais básico | ✅ |
| 2 | R | **Corredor** | 1 casa em qualquer direção (rei) | Morde em volta (8 casas) | 1 | Rápido, mas frágil | ✅ |
| 3 | T | **Tanque** | 1 casa reta, a cada 2 rodadas | Morde a casa vizinha reta | 4 | Lento, aguenta muito tiro | ✅ |
| 4 | K | **Saltador** | Em L (cavalo), pula obstáculos | Morde onde cai (em L) | 2 | Age a cada 2 rodadas | ✅ |
| 5 | N | **Peão Podre** | 1 casa para baixo (em direção ao jogador) | Só na diagonal da frente, como o peão | 1 | Se ficar bloqueado na frente, não anda. Ao chegar à última linha, vira Tanque | ✅ |
| 6 | C | **Rastejante** | 1 casa na diagonal (bispo curto) | Diagonal vizinha | 1 | Fica escondido e parado (mancha escura) até alguém chegar a 2 casas | ✅ |
| 7 | G | **Trotador** | Até 2 casas em linha reta (torre curta) | Morde a casa vizinha reta | 2 | Não atravessa móveis nem outras peças | ✅ |
| 8 | U | **Brutamontes** | Investida de até 3 casas em linha reta | Empurra 1 casa e tira 1 de vida | 4 | Fica tonto 1 rodada depois de uma investida de 2 ou mais casas | ✅ |

## Zumbis com super poderes (ataque a distância, andam mais)

**Regra de mira (para ser justo, como no xadrez):** quem ataca em linha primeiro **mira** — aparece uma linha vermelha — e só atira na rodada seguinte se ainda houver alguém nela. Sair da linha desvia o tiro. O Gritador faz o mesmo: "puxa o ar" (área vermelha) e grita na rodada seguinte. Paredes, móveis, portas e outros zumbis bloqueiam os ataques em linha. Passando o mouse no zumbi, as casas roxas mostram o alcance.

| # | Letra | Nome | Movimento | Ataque a distância | Vida | Super poder | Status |
|---|---|---|---|---|---|---|---|
| 9 | S | **Cuspidor** | Até 2 casas em qualquer linha | Cospe até 3 casas em linha reta | 2 | Deixa poça de ácido que queima 1 por rodada, durante 2 rodadas | ✅ |
| 10 | O | **Policial Zumbi** | Até 4 casas em linha reta (torre) | Tiro até 3 casas reta | 3 | Larga munição ao morrer | ✅ |
| 11 | J | **Bispo Necromante** | Até 4 casas na diagonal (bispo) | Raio até 3 casas na diagonal | 3 | A cada 3 ações levanta um zumbi abatido a até 2 casas (no lugar de agir) | ✅ |
| 12 | Q | **Rainha Zumbi** | Até 5 casas em qualquer linha (dama) | Grito até 3 casas em qualquer linha | 6 | Zumbis a até 2 casas dela agem 2 vezes (chefe) | ✅ |
| 13 | Y | **Gritador** | 1 casa (rei) | Grito: 1 de dano em tudo a até 2 casas, a cada 2 rodadas | 2 | O grito chama os zumbis: todos agem de novo | ✅ |
| 14 | F | **Soldado Caído** | Até 3 casas reta | Fuzil até 5 casas reta, atravessa sobreviventes | 3 | Recarrega: atira a cada 2 rodadas | ✅ |
| 15 | A | **Esqueleto Arqueiro** | Até 3 casas em qualquer linha | Flecha até 4 casas, reta ou diagonal | 2 | Foge se alguém chega a 2 casas | ✅ |
| 16 | I | **Inchado** | Até 3 casas reta | Explode ao encostar: 1 de dano nas 8 casas em volta | 3 | Explode também ao morrer, e a explosão fere zumbis | ✅ |

## Ideia de progressão

- Fases 1–4: Comum, Corredor, Tanque, Saltador.
- Fase 5 ("Fila de Peões"): Peão Podre e Rastejante.
- Fase 6 ("Investida"): Trotador e Brutamontes.
- Fase 7 ("Delegacia"): Policial, Cuspidor e Soldado.
- Fase 8 ("Cemitério"): Necromante, Arqueiro e Inchado.
- Fase 9 ("A Rainha"): Rainha Zumbi e Gritador — chefe final.

## Arte

Cada zumbi tem a própria folha de sprites, gerada no Gemini no mesmo estilo do herói (o `survivor.png` vai anexado como referência em cada pedido):

- imagem original do Gemini: `gdd/gemini-zumbis/<letra>.jpg`
- folha usada no jogo: `assets/zombies/<letra>.png` — 6 colunas × 3 linhas de 48×48: andando (6), atacando (4), morrendo (3). O Inchado usa a linha de ataque (explosão) também ao morrer.
- para trocar a arte de um zumbi: gere a imagem no Gemini (fundo magenta, 3 linhas, de lado olhando para a direita), baixe e rode `tools/zombie_from_gemini.sh <letra> <altura em px>`. Se o Gemini fizer uma linha a mais, passe quais usar: `tools/zombie_from_gemini.sh T 29 0,2,3`.
