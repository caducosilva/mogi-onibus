#!/usr/bin/env python
"""Gera o ícone do app (ônibus branco em fundo verde) + versão foreground."""
from PIL import Image, ImageDraw
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "app", "assets")
os.makedirs(OUT, exist_ok=True)

S = 1024
GREEN = (27, 94, 32, 255)      # 0xFF1B5E20
GREEN_LT = (46, 125, 50, 255)
WHITE = (255, 255, 255, 255)
GLASS = (200, 230, 201, 255)   # verde clarinho p/ janelas


def draw_bus(d, cx, cy, scale, body=WHITE):
    """Desenha um ônibus estilizado centrado em (cx, cy)."""
    w = int(560 * scale)
    h = int(440 * scale)
    x0 = cx - w // 2
    y0 = cy - h // 2
    r = int(70 * scale)
    # corpo
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=r, fill=body)
    # faixa de janelas
    pad = int(50 * scale)
    win_top = y0 + pad
    win_h = int(150 * scale)
    d.rounded_rectangle(
        [x0 + pad, win_top, x0 + w - pad, win_top + win_h],
        radius=int(28 * scale), fill=GREEN)
    # divisórias das janelas (3 janelas)
    n = 3
    inner_w = (w - 2 * pad)
    gap = int(22 * scale)
    win_w = (inner_w - (n - 1) * gap) / n
    for i in range(n):
        wx = x0 + pad + i * (win_w + gap)
        d.rounded_rectangle(
            [wx, win_top, wx + win_w, win_top + win_h],
            radius=int(18 * scale), fill=GLASS)
    # faixa inferior (porta/destino)
    band_y = win_top + win_h + int(40 * scale)
    d.rounded_rectangle(
        [x0 + pad, band_y, x0 + w - pad, band_y + int(40 * scale)],
        radius=int(16 * scale), fill=GREEN)
    # rodas
    wheel_r = int(60 * scale)
    wy = y0 + h - int(10 * scale)
    for wx in (x0 + int(150 * scale), x0 + w - int(150 * scale)):
        d.ellipse([wx - wheel_r, wy - wheel_r, wx + wheel_r, wy + wheel_r],
                  fill=GREEN)
        d.ellipse([wx - wheel_r // 2, wy - wheel_r // 2,
                   wx + wheel_r // 2, wy + wheel_r // 2], fill=body)


# 1) Ícone completo (fundo verde + ônibus)
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle([0, 0, S, S], radius=int(S * 0.22), fill=GREEN)
draw_bus(d, S // 2, S // 2 + 10, 1.05)
img.save(os.path.join(OUT, "icon.png"))

# 2) Foreground p/ ícone adaptativo (ônibus menor, transparente, com margem)
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
df = ImageDraw.Draw(fg)
draw_bus(df, S // 2, S // 2 + 10, 0.78)
fg.save(os.path.join(OUT, "icon_foreground.png"))

print("ok:", os.listdir(OUT))
