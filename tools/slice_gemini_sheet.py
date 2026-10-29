"""Recorta o sprite sheet gerado pelo Gemini (fundo magenta) e monta
uma folha limpa de 6 colunas x 16 linhas com quadros de 48x48 px.

Uso: python3 tools/slice_gemini_sheet.py <imagem_gemini> <saida.png> [colunas linhas escala]
  personagem: 6 colunas x 16 linhas (padrão)
  um zumbi:   python3 tools/slice_gemini_sheet.py img.jpg assets/zombies/Z.png 6 3 h24
              (h24 = altura do zumbi andando, em pixels do jogo)
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


def background_mask(rgb):
    """True onde é fundo (magenta, ou outra cor lisa lida nos cantos)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    corners = np.array([rgb[2, 2], rgb[2, -3], rgb[-3, 2], rgb[-3, -3]]).mean(0)
    cr, cg, cb = corners
    if cg < 0.55 * min(cr, cb):  # magenta
        return (g < 0.55 * np.minimum(r, b)) & (r > 70) & (b > 70) & (abs(r - b) < 70)
    # outra cor (ex.: ciano): tudo que está perto da cor do canto
    dist = np.sqrt(((rgb - corners) ** 2).sum(-1))
    return dist < 110


def cut_sprite(rgb, fg, y0, y1, x0, x1, scale):
    """Recorta e reduz um boneco. Devolve (imagem, centro das pernas, pé)."""
    m = fg[y0:y1 + 1, x0:x1 + 1]
    px = rgb[y0:y1 + 1, x0:x1 + 1].astype(float)
    h, w = m.shape
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    # média ponderada pelo alfa (evita borda magenta)
    alpha = Image.fromarray((m * 255).astype(np.uint8)).resize((nw, nh), Image.BOX)
    prem = Image.fromarray((px * m[..., None]).clip(0, 255).astype(np.uint8)).resize((nw, nh), Image.BOX)
    a = np.asarray(alpha).astype(float)
    c = np.asarray(prem).astype(float) * 255.0 / np.maximum(a, 1)[..., None]
    out = np.zeros((nh, nw, 4), np.uint8)
    keep = a >= 110
    out[..., :3] = c.clip(0, 255)
    out[..., 3] = np.where(keep, 255, 0)
    ys, xs = np.nonzero(keep)
    legs = xs[ys >= ys.max() - max(3, (ys.max() - ys.min()) // 3)]
    return Image.fromarray(out, "RGBA"), int(np.median(legs)), int(ys.max())


def place(sheet, spr, cx, bottom, col, row):
    """Põe o boneco no quadro (col, row): centrado pelas pernas, pés na BASELINE."""
    nw, _ = spr.size
    ox = col * CELL + CELL // 2 - cx
    oy = row * CELL + BASELINE - bottom
    ox = min(max(ox, col * CELL), col * CELL + CELL - nw)
    oy = max(oy, row * CELL)
    sheet.alpha_composite(spr, (ox, oy))


def quantize(sheet, colors=40):
    """Reduz o ruído do JPEG para uma paleta pequena, estilo pixel art."""
    a = sheet.getchannel("A")
    q = sheet.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGB")
    q.putalpha(a)
    return q


def main(src, dst, cols=COLS, rows=ROWS, scale=SCALE, pick=None, expected=None):
    rgb = np.asarray(Image.open(src).convert("RGB")).astype(int)
    fg = ~background_mask(rgb)
    row_bands = bands(fg.sum(1), 2, 12)
    if pick:
        # linhas escolhidas à mão, ex.: "0,2,3"
        row_bands = [row_bands[int(i)] for i in pick.split(",")]
    elif rows == 3 and len(row_bands) > 3:
        # folha de zumbi com linha extra: andar = 1ª, ataque = 2ª, morte = última
        print(f"aviso: {len(row_bands)} linhas; usando 1ª, 2ª e última")
        row_bands = [row_bands[0], row_bands[1], row_bands[-1]]
    assert len(row_bands) == rows, f"esperava {rows} linhas, achei {len(row_bands)}"
    if scale == "auto":
        # escala pela altura média das linhas: personagem comum ~ 24 px
        heights = sorted(y1 - y0 for y0, y1 in row_bands)
        scale = 24.0 / heights[len(heights) // 2]
        print("escala automática:", round(1 / scale, 2))
    elif isinstance(scale, str) and scale.startswith("h"):
        # "h28" = a 1ª linha (andando) fica com 28 px de altura
        scale = float(scale[1:]) / (row_bands[0][1] - row_bands[0][0])
        print("escala:", round(1 / scale, 2))

    sheet = Image.new("RGBA", (cols * CELL, rows * CELL), (0, 0, 0, 0))
    for row, (y0, y1) in enumerate(row_bands):
        prof = fg[y0:y1 + 1].sum(0)
        found = bands(prof, 1, 25)
        want = expected[row] if expected else cols
        while len(found) < want:
            # quadros encostados: corta o bloco mais largo na coluna mais vazia
            i = max(range(len(found)), key=lambda k: found[k][1] - found[k][0])
            x0, x1 = found[i]
            w = x1 - x0
            lo, hi = x0 + int(w * 0.25), x1 - int(w * 0.25)
            if hi <= lo:
                break
            cut = lo + int(np.argmin(prof[lo:hi]))
            found[i:i + 1] = [(x0, cut), (cut + 1, x1)]
        if len(found) != want:
            print(f"aviso: linha {row + 1} tem {len(found)} quadros (esperava {want})")
        for col, (x0, x1) in enumerate(found[:cols]):
            spr, cx, bottom = cut_sprite(rgb, fg, y0, y1, x0, x1, scale)
            place(sheet, spr, cx, bottom, col, row)
    q = quantize(sheet)
    q.save(dst)
    print("salvo", dst, q.size)


if __name__ == "__main__":
    a = sys.argv
    if len(a) > 3:
        sc = a[5] if (a[5] == "auto" or a[5].startswith("h")) else float(a[5])
        pick = a[6] if len(a) > 6 and a[6] != "-" else None
        # folha de zumbi (6x3): andando 6, atacando 4, morrendo 3
        expected = [6, 4, 3] if (int(a[3]), int(a[4])) == (6, 3) else None
        main(a[1], a[2], int(a[3]), int(a[4]), sc, pick, expected)
    else:
        main(a[1], a[2])
