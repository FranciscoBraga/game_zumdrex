"""Recorta o sprite sheet gerado pelo Gemini (fundo magenta) e monta
uma folha limpa de 6 colunas x 16 linhas com quadros de 48x48 px.

Uso: python3 tools/slice_gemini_sheet.py <imagem_gemini> <saida.png>
"""
import sys
import numpy as np
from PIL import Image

CELL = 48
COLS, ROWS = 6, 16
SCALE = 1 / 4.8        # tamanho do "pixel" do Gemini -> 1 px do jogo
BASELINE = 44          # linha onde ficam os pés dentro do quadro


def bands(v, thr, gap):
    out, s, last = [], None, -999
    for i, x in enumerate(v):
        if x > thr:
            if s is None or i - last > gap:
                if s is not None:
                    out.append((s, last))
                s = i
            last = i
    if s is not None:
        out.append((s, last))
    return out


def main(src, dst):
    rgb = np.asarray(Image.open(src).convert("RGB")).astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    bg = (g < 0.55 * np.minimum(r, b)) & (r > 70) & (b > 70) & (abs(r - b) < 70)
    fg = ~bg
    row_bands = bands(fg.sum(1), 2, 12)
    assert len(row_bands) == ROWS, f"esperava {ROWS} linhas, achei {len(row_bands)}"

    sheet = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
    for row, (y0, y1) in enumerate(row_bands):
        for col, (x0, x1) in enumerate(bands(fg[y0:y1 + 1].sum(0), 1, 25)[:COLS]):
            m = fg[y0:y1 + 1, x0:x1 + 1]
            px = rgb[y0:y1 + 1, x0:x1 + 1].astype(float)
            h, w = m.shape
            nw, nh = max(1, round(w * SCALE)), max(1, round(h * SCALE))
            # média ponderada pelo alfa (evita borda magenta)
            alpha = Image.fromarray((m * 255).astype(np.uint8)).resize((nw, nh), Image.BOX)
            prem = Image.fromarray((px * m[..., None]).clip(0, 255).astype(np.uint8)).resize((nw, nh), Image.BOX)
            a = np.asarray(alpha).astype(float)
            c = np.asarray(prem).astype(float) * 255.0 / np.maximum(a, 1)[..., None]
            out = np.zeros((nh, nw, 4), np.uint8)
            keep = a >= 110
            out[..., :3] = c.clip(0, 255)
            out[..., 3] = np.where(keep, 255, 0)
            spr = Image.fromarray(out, "RGBA")
            # centraliza pelo corpo (mediana das pernas), pés na BASELINE
            ys, xs = np.nonzero(keep)
            legs = xs[ys >= ys.max() - max(3, (ys.max() - ys.min()) // 3)]
            cx = int(np.median(legs))
            ox = col * CELL + CELL // 2 - cx
            oy = row * CELL + BASELINE - ys.max()
            ox = min(max(ox, col * CELL), col * CELL + CELL - nw)
            oy = max(oy, row * CELL)
            sheet.alpha_composite(spr, (ox, oy))
    # reduz o ruído do JPEG para uma paleta pequena, estilo pixel art
    a = sheet.getchannel("A")
    q = sheet.convert("RGB").quantize(colors=40, method=Image.Quantize.MEDIANCUT).convert("RGB")
    q.putalpha(a)
    q.save(dst)
    print("salvo", dst, q.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
