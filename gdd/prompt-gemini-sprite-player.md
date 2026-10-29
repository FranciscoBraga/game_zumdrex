# Prompt para o Gemini: sprite sheet do Sobrevivente

Anexe `gdd/referencia-player-antigo.png` junto com o prompt, como referência de estilo.

---

## Prompt (copie daqui para baixo)

Use the attached image as the exact style and character reference. Create a new **pixel art sprite sheet** of the **same character**: a young survivor with messy brown hair, a white/cream shirt, blue pants and dark shoes, in a top-down 3/4 view (classic 16-bit RPG style, like the reference).

**Style rules (very important):**
- Pixel art only, crisp hard pixels, no anti-aliasing, no blur, no gradients, no painterly shading.
- Same limited color palette, the same 1-pixel dark outline and the same proportions as the reference (big head, small chibi body).
- Each character fits in roughly 20×24 pixels, centered inside its cell, with the same small gray oval shadow under the feet.
- **Fully transparent background** (PNG with alpha). No checkerboard pattern, no white background, no text, no labels, no grid lines, no borders.

**Grid layout (exact):**
- Sheet size **288 × 768 pixels**.
- **6 columns × 16 rows**, every cell exactly **48 × 48 pixels**.
- Each row is one animation, frames read from left to right. Leave unused cells empty (transparent).
- "Front" means facing the viewer (down), "side" means facing **right**, "back" means facing away (up).

| Row | Animation | Frames |
|---|---|---|
| 1 | Idle, front (gentle breathing) | 6 |
| 2 | Idle, side | 6 |
| 3 | Idle, back | 6 |
| 4 | Walk, front | 6 |
| 5 | Walk, side | 6 |
| 6 | Walk, back | 6 |
| 7 | **Shoot pistol**, front: raise a small black handgun with both hands, fire (small yellow muzzle flash), recoil, lower | 4 |
| 8 | **Shoot pistol**, side (same sequence, gun pointing right) | 4 |
| 9 | **Shoot pistol**, back (gun pointing up/away) | 4 |
| 10 | **Shoot bow and arrow**, front: hold a wooden bow, pull the string back, release (arrow leaving), follow-through | 4 |
| 11 | **Shoot bow and arrow**, side (bow pointing right, arrow flies right) | 4 |
| 12 | **Shoot bow and arrow**, back | 4 |
| 13 | **Shoot rifle**, front: lift a long dark gray assault rifle to the shoulder, aim, fire (bigger muzzle flash), strong recoil | 4 |
| 14 | **Shoot rifle**, side (rifle pointing right) | 4 |
| 15 | **Shoot rifle**, back | 4 |
| 16 | Death: hit, kneel, fall flat on the ground | 3 |

The weapons must be small and readable at this pixel size (pistol about 5 px long, bow about 12 px tall, rifle about 14 px long), drawn with the same outline and palette style. The character must look identical in every frame: same hair, clothes and colors. Only the pose and the weapon change.

---

## Dicas

- **Grade torta:** o Gemini às vezes erra o tamanho das células. Se isso acontecer, peça uma folha por arma com 6 colunas × 3 linhas (288 × 144 px), só com as linhas da pistola, depois só do arco, depois só do fuzil. Use o mesmo texto e mude apenas a tabela.
- **Fundo xadrez ou branco:** se a imagem vier com fundo xadrez cinza ou branco, peça: *"regenerate with a truly transparent background"*.
- **Tamanho errado:** se a imagem vier maior (por exemplo 1024 px), dá para reduzir com "vizinho mais próximo" (nearest neighbor). Posso fazer isso no projeto.
