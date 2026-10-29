# Zumdrex — Xadrez Zumbi

Jogo de estratégia por turnos em pixel art: sobreviventes e zumbis andam como peças de xadrez. Atravesse o tabuleiro, resgate pessoas e pets e não deixe ninguém ser mordido.

Feito em **Godot 4.3** (GDScript).

## Como jogar

- Leve o grupo até a **linha de cima** do tabuleiro (a saída).
- Cada rodada você faz **uma ação** com um personagem; depois os zumbis agem.
- Passe o mouse num zumbi para ver até onde ele alcança.
- Pelas fases há equipamentos: bonés (mais vida), Fita Vermelha (menos dano), mochilas maiores, Anel do Poder e Tênis Branco (andar mais longe) e a Mamadeira (acalma os bebês). A lista está no [GDD](gdd/GDD.md#24-mochila-e-itens).

| Tecla | Ação |
|---|---|
| Clique numa casa / setas | Andar |
| `1` ou `A` | Modo andar |
| `2` ou `F` | Modo atirar |
| `3` ou `Espaço` | Esperar |
| `Tab` | Trocar de personagem |
| `R` | Reiniciar a fase |
| `Esc` / botão direito | Cancelar |

## Rodando

1. Instale o [Godot 4.3](https://godotengine.org/download).
2. Abra a pasta do projeto no Godot (`project.godot`) e aperte **F5**.

Ou pelo terminal:

```bash
godot --path .
```

## Testes

```bash
godot --headless --path . --script res://tests/test_rules.gd   # regras do tabuleiro
godot --headless --path . --script res://tests/test_scene.gd   # cena jogável (simula cliques)
```

## Estrutura

```
script/
  board_logic.gd   regras: movimentos, ataques, itens, IA dos zumbis
  game.gd          cena principal: desenho, entrada, interface
  levels.gd        fases (mapas em texto, com a legenda no topo)
  unit_view.gd     sprites e animações das peças
scenes/            cenas do Godot (game.tscn é a principal)
assets/            sprites do herói, dos zumbis e dos itens
tests/             testes automáticos
tools/             scripts para cortar as folhas de sprite geradas no Gemini
gdd/               documentação de design
```

## Documentação

- [GDD](gdd/GDD.md): design completo do jogo
- [Missões](gdd/missoes.md): as 30 missões planejadas
- [Bestiário](gdd/bestiario-zumbis.md): os 16 zumbis

## Para criar uma fase

Adicione um item em `LEVELS` no `script/levels.gd` com `name`, `intro` e o mapa em texto. A legenda das letras (chão, paredes, sobreviventes, zumbis e itens) está no topo do arquivo.

## Arte

Os sprites são gerados no Gemini e cortados com os scripts de `tools/`. Veja `gdd/prompt-gemini-sprite-player.md` e a seção "Arte" do bestiário.
