# Zumdrex — Xadrez Zumbi

Jogo de estratégia por turnos em pixel art: sobreviventes e zumbis andam como peças de xadrez. Atravesse o tabuleiro, resgate pessoas e pets e não deixe ninguém morrer.

Feito em **Godot 4.3** (GDScript).

## Como jogar

- Leve o grupo até a **linha de cima** do tabuleiro (a saída).
- Cada rodada você faz **uma ação** com um personagem: andar, atirar, esperar ou usar um item. Depois os zumbis agem.
- Cada personagem anda como uma peça de xadrez: o Sobrevivente como o rei, o Cachorro em L como o cavalo.
- Ao entrar numa fase aparece um cartão com o objetivo. O botão **?** mostra o cartão de novo.
- Passe o mouse numa peça ou num item para ver os detalhes num balão. Num zumbi, as casas laranja mostram a mordida e as roxas o ataque de longe.
- Linhas e áreas vermelhas avisam que um zumbi vai atacar na próxima rodada: saia delas!

### Vida

- Todos os personagens têm vida de 0 a 100: o Sobrevivente tem **100**, o Cachorro **70** e o Bebê **50**.
- Cada golpe de zumbi tira **34**. O kit médico cura **50** de quem estiver selecionado.
- Com 0 de vida o personagem morre. Se for o Sobrevivente, a fase acaba. Os outros levantam como zumbi. Se o bebê morrer, a missão falha.

### Itens

| Item | Efeito |
|---|---|
| Chave | Abre uma porta trancada |
| Kit Médico | Cura 50 de vida |
| Munição / Flecha | +3 / +1 tiro |
| Escopeta, Rifle, Arco | Trocam a arma (o arco alcança 4 casas e a flecha cai no chão para ser recuperada) |
| Boné Branco / Verde / Preto | +10% / +20% / +30% de vida |
| Fita Vermelha | Golpes tiram 10% a menos |
| Mochila Nível 2 / Militar | +30% / +50% de espaço na mochila |
| Anel do Poder | Anda até 2 casas em qualquer direção |
| Tênis Branco | Anda até 3 casas em qualquer direção |
| Mamadeira | Acalma o bebê por 3 rodadas: o choro para de atrair os zumbis |

Os equipamentos (bonés, fita, mochilas, anel e tênis) valem até o fim da fase. Do mesmo tipo fica só o melhor. Detalhes no [GDD](gdd/GDD.md#24-mochila-e-itens).

### Controles

| Tecla | Ação |
|---|---|
| Clique numa casa / setas | Andar |
| Clique numa peça sua / `Tab` | Selecionar / trocar de personagem |
| `1` ou `A` | Modo andar |
| `2` ou `F` | Modo atirar (clique numa casa vermelha) |
| `3` ou `Espaço` | Esperar |
| Clique num item da mochila | Usar o item |
| `R` | Reiniciar a fase |
| Botão `?` | Mostrar o objetivo da fase |
| `Enter` | Fechar o cartão / ir para a próxima fase |
| `Esc` / botão direito | Cancelar o tiro |

## Fases

| # | Fase | Novidade | Item |
|---|---|---|---|
| 1 | Primeiros Passos | Andar como o rei | Boné Branco |
| 2 | Rua Bloqueada | Chave, porta e tiro | Arco, Fita Vermelha |
| 3 | O Melhor Amigo | Cachorro (anda em L) e Corredor | Mochila Nível 2 |
| 4 | Bebê Chorão | O choro do bebê atrai os zumbis; Tanque e Saltador | Mamadeira |
| 5 | Fila de Peões | Peão Podre e Rastejante escondido | Anel do Poder |
| 6 | Investida | Trotador e Brutamontes | Boné Verde |
| 7 | Delegacia | Zumbis que atacam de longe: Cuspidor e Policial | Mochila Militar |
| 8 | Cemitério | Soldado, Necromante, Arqueiro e Inchado | Tênis Branco |
| 9 | A Rainha | Chefe final: Rainha Zumbi e Gritador | Boné Preto |

Mais 21 missões estão planejadas em [missoes.md](gdd/missoes.md).

## Rodando

1. Instale o [Godot 4.3](https://godotengine.org/download).
2. Abra a pasta do projeto no Godot (`project.godot`) e aperte **F5**.

Ou pelo terminal:

```bash
godot --path .
godot --path . -- --level=4               # começa direto na fase 4
godot --path . -- --level=4 --no-intro    # sem o cartão do objetivo
godot --path . -- --level=4 --no-intro --screenshot=tela.png   # salva uma imagem e fecha
```

## Testes

```bash
godot --headless --path . --script res://tests/test_rules.gd   # regras do tabuleiro
godot --headless --path . --script res://tests/test_scene.gd   # cena jogável (simula cliques)
```

O `test_rules.gd` também joga cada fase 400 vezes com um robô simples e mostra quantas ele venceu. Use esse número para comparar a dificuldade das fases depois de mexer num mapa.

## Estrutura

```
script/
  board_logic.gd   regras: movimentos, vida, ataques, itens, IA dos zumbis
  game.gd          cena principal: desenho do tabuleiro, entrada, painéis e cartões
  levels.gd        fases (mapas em texto, com a legenda no topo)
  unit_view.gd     sprites, animações e barras de vida das peças
scenes/            cenas do Godot (game.tscn é a principal)
assets/            sprites do herói, dos zumbis e dos itens
tests/             testes automáticos
tools/             scripts para cortar as folhas de sprite geradas no Gemini
gdd/               documentação de design
```

## Documentação

- [GDD](gdd/GDD.md): design completo do jogo (regras, personagens, itens, progressão)
- [Missões](gdd/missoes.md): as 30 missões planejadas
- [Bestiário](gdd/bestiario-zumbis.md): os 16 zumbis

## Para criar uma fase

Adicione um item em `LEVELS` no `script/levels.gd` com `name`, `intro` (texto curto do cartão) e o mapa em texto. A legenda das letras (chão, paredes, sobreviventes, zumbis, itens e equipamentos) está no topo do arquivo. Depois rode o `test_rules.gd` para ver se a fase é vencível e quão difícil ficou.

## Arte

Os sprites são gerados no Gemini e cortados com os scripts de `tools/`. Veja `gdd/prompt-gemini-sprite-player.md` e a seção "Arte" do bestiário.
