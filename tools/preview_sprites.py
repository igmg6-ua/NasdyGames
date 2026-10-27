#!/usr/bin/env python3
"""Hoja con todos los diseños de tools/sprites.py ampliados (paleta verde DMG).

Uso: python3 tools/preview_sprites.py [salida.png]      (por defecto sprites.png)
Necesita Pillow (pip install pillow).
"""
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprites as S

K = 6
PAL = [(224, 248, 208), (136, 192, 112), (52, 104, 86), (8, 24, 32)]
FLOOR = (200, 228, 184)


def draw(img, rows, ox, oy, k=K, flip=False, bg=None):
    d = ImageDraw.Draw(img)
    if bg:
        d.rectangle([ox, oy, ox + len(rows[0]) * k - 1, oy + len(rows) * k - 1], fill=bg)
    for y, r in enumerate(rows):
        if flip:
            r = r[::-1]
        for x, c in enumerate(r):
            if c != '.':
                d.rectangle([ox + x * k, oy + y * k, ox + x * k + k - 1, oy + y * k + k - 1],
                            fill=PAL[int(c)])


def main():
    cell = 16 * K + 14
    labels = ['abajo', 'abajo 2', 'arriba', 'arriba 2', 'lado', 'lado 2', 'izquierda']
    W = 120 + cell * 7
    H = 40 + cell * (len(S.CHARACTERS) + 1) + 8 * K * 2 + 60
    img = Image.new('RGB', (W, H), PAL[0])
    d = ImageDraw.Draw(img)
    for i, l in enumerate(labels):
        d.text((120 + i * cell, 12), l, fill=PAL[3])
    y = 32
    for name, frames in S.CHARACTERS:
        d.text((10, y + 40), name, fill=PAL[3])
        for i, (_, rows) in enumerate(frames):
            draw(img, rows, 120 + i * cell, y, bg=FLOOR)
        draw(img, frames[4][1], 120 + 6 * cell, y, flip=True, bg=FLOOR)
        y += cell
    d.text((10, y + 40), 'OBJETOS', fill=PAL[3])
    x = 120
    for name, frames in S.OBJECTS:
        for _, rows in frames:
            draw(img, rows, x, y, bg=FLOOR)
            x += cell
    draw(img, S.CURSOR, x, y, bg=FLOOR)
    y += cell
    d.text((10, y + 10), 'FONDO', fill=PAL[3])
    x = 120
    for name, rows in S.BG_FLOOR + S.BG_HUD + S.BG_SOLID:
        draw(img, rows, x, y, k=K, bg=None)
        x += 8 * K + 10
    out = sys.argv[1] if len(sys.argv) > 1 else 'sprites.png'
    img.save(out)
    print('Guardado en', out)


if __name__ == '__main__':
    main()
