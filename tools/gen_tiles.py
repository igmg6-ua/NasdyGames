#!/usr/bin/env python3
"""Genera los gráficos del juego en formato Game Boy (2bpp).

Salida:
  src/assets/gfx/tiles.asm   datos de los tiles (se copian a VRAM $8000)
  src/engine/gfx.inc         el número de cada tile (TILE_WALL_TOP, TILE_BOY...)
  src/engine/charmap.inc     CHARMAP para escribir textos con db "HOLA"

Orden de los tiles (como en el Challenge 6):
    0-63    fuente: tile = código ASCII - $20  (espacio ... '_')
    64-     suelo y monedas (se pueden pisar)
            iconos del HUD (nunca están en un mapa)
    76-     TILE_FIRST_SOLID: paredes (no se pueden atravesar)
    80-     hojas de los personajes (24 tiles = 6 imágenes de 16x16) y objetos
            (8 tiles = 2 imágenes). Empiezan en múltiplo de 4: los sprites de
            8x16 usan siempre una pareja de tiles par/impar.
    180-    logo grande de la portada (letras de 2x2 tiles)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sprites as S

SRC = os.path.join(HERE, '..', 'src')

# Fuente de 5x7 píxeles (se dibuja en un tile de 8x8, color 3)
FONT = {
    '0': [" ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### "],
    '1': ["  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
    '2': [" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"],
    '3': ["#####", "   # ", "  #  ", "   # ", "    #", "#   #", " ### "],
    '4': ["   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # "],
    '5': ["#####", "#    ", "#### ", "    #", "    #", "#   #", " ### "],
    '6': ["  ## ", " #   ", "#    ", "#### ", "#   #", "#   #", " ### "],
    '7': ["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "],
    '8': [" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### "],
    '9': [" ### ", "#   #", "#   #", " ####", "    #", "   # ", " ##  "],
    'A': [" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    'B': ["#### ", "#   #", "#   #", "#### ", "#   #", "#   #", "#### "],
    'C': [" ### ", "#   #", "#    ", "#    ", "#    ", "#   #", " ### "],
    'D': ["#### ", "#   #", "#   #", "#   #", "#   #", "#   #", "#### "],
    'E': ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####"],
    'F': ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#    "],
    'G': [" ### ", "#   #", "#    ", "# ###", "#   #", "#   #", " ####"],
    'H': ["#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    'I': [" ### ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
    'J': ["  ###", "   # ", "   # ", "   # ", "   # ", "#  # ", " ##  "],
    'K': ["#   #", "#  # ", "# #  ", "##   ", "# #  ", "#  # ", "#   #"],
    'L': ["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"],
    'M': ["#   #", "## ##", "# # #", "# # #", "#   #", "#   #", "#   #"],
    'N': ["#   #", "##  #", "# # #", "#  ##", "#   #", "#   #", "#   #"],
    'O': [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
    'P': ["#### ", "#   #", "#   #", "#### ", "#    ", "#    ", "#    "],
    'Q': [" ### ", "#   #", "#   #", "#   #", "# # #", "#  # ", " ## #"],
    'R': ["#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #"],
    'S': [" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "],
    'T': ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "],
    'U': ["#   #", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
    'V': ["#   #", "#   #", "#   #", "#   #", "#   #", " # # ", "  #  "],
    'W': ["#   #", "#   #", "#   #", "# # #", "# # #", "# # #", " # # "],
    'X': ["#   #", "#   #", " # # ", "  #  ", " # # ", "#   #", "#   #"],
    'Y': ["#   #", "#   #", " # # ", "  #  ", "  #  ", "  #  ", "  #  "],
    'Z': ["#####", "    #", "   # ", "  #  ", " #   ", "#    ", "#####"],
    ':': ["     ", "  #  ", "  #  ", "     ", "  #  ", "  #  ", "     "],
    '!': ["  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "     ", "  #  "],
    '?': [" ### ", "#   #", "    #", "   # ", "  #  ", "     ", "  #  "],
    '/': ["    #", "    #", "   # ", "  #  ", " #   ", "#    ", "#    "],
    '.': ["     ", "     ", "     ", "     ", "     ", "     ", "  #  "],
    ',': ["     ", "     ", "     ", "     ", "     ", "  #  ", " #   "],
    '-': ["     ", "     ", "     ", " ### ", "     ", "     ", "     "],
    "'": ["  #  ", "  #  ", " #   ", "     ", "     ", "     ", "     "],
    '<': ["   # ", "  #  ", " #   ", "#    ", " #   ", "  #  ", "   # "],
    '>': [" #   ", "  #  ", "   # ", "    #", "   # ", "  #  ", " #   "],
    '+': ["     ", "  #  ", "  #  ", "#####", "  #  ", "  #  ", "     "],
    '_': ["     ", "     ", "     ", "     ", "     ", "     ", "#####"],
    'x': ["     ", "     ", "#   #", " # # ", "  #  ", " # # ", "#   #"],
    'Ñ': [" ### ", "     ", "#   #", "##  #", "# # #", "#  ##", "#   #"],
}
# Caracteres fuera de ASCII $20-$5F: van a huecos libres de la fuente
EXTRA_SLOT = {'Ñ': '^', 'x': '#'}


def glyph(rows):
    out = ['.' + ''.join('3' if c == '#' else '.' for c in r) + '..' for r in rows]
    return out + ['........']


def big_glyph(rows):
    """Letra al doble de tamaño (16x16) con sombra: para el logo."""
    g = [['.'] * 16 for _ in range(16)]
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == '#':
                for dy in (0, 1):
                    for dx in (0, 1):
                        yy, xx = 1 + 2 * y + dy, 2 + 2 * x + dx
                        g[yy][xx] = '3'
                        if yy + 1 < 16 and g[yy + 1][xx] == '.':
                            g[yy + 1][xx] = '2'      # sombra debajo
    return [''.join(r) for r in g]


def encode(rows):
    data = []
    for r in rows:
        assert len(r) == 8, r
        lo = hi = 0
        for i, c in enumerate(r):
            v = 0 if c == '.' else int(c)
            lo |= (v & 1) << (7 - i)
            hi |= (v >> 1) << (7 - i)
        data += [lo, hi]
    return data


def split16(rows):
    """Imagen de 16x16 -> 4 tiles en el orden de 2 sprites de 8x16:
    izquierda-arriba, izquierda-abajo, derecha-arriba, derecha-abajo."""
    L = [r[:8] for r in rows]
    R = [r[8:] for r in rows]
    return [L[:8], L[8:], R[:8], R[8:]]


def main():
    bad = S.check()
    if bad:
        sys.exit(f'Dibujos con tamaño incorrecto: {bad}')
    tiles = [None] * 256
    names = {}

    def put(i, name, rows):
        assert tiles[i] is None, (i, name)
        tiles[i] = (name, rows)
        if name:
            names[name] = i

    # Fuente
    blank = ['........'] * 8
    for code in range(0x20, 0x60):
        put(code - 0x20, None, blank)
    charmap = {}
    for ch, rows in FONT.items():
        slot = EXTRA_SLOT.get(ch, ch)
        i = ord(slot) - 0x20
        tiles[i] = (None, glyph(rows))
        charmap[ch] = i
    charmap[' '] = 0

    # Fondo
    i = 64
    for name, rows in S.BG_FLOOR + S.BG_HUD:
        put(i, name, rows)
        i += 1
    FIRST_SOLID = 76
    assert i <= FIRST_SOLID
    i = FIRST_SOLID
    for name, rows in S.BG_SOLID:
        put(i, name, rows)
        i += 1
    assert i <= 80

    # Hojas de personajes y objetos
    i = 80
    sheets = {}
    for name, frames in S.CHARACTERS + S.OBJECTS:
        sheets[name] = i
        for _, rows in frames:
            for t in split16(rows):
                put(i, None, t)
                i += 1
    names['TILE_CURSOR'] = i
    put(i, None, S.CURSOR[:8])
    put(i + 1, None, S.CURSOR[8:])
    i += 2
    while i % 4:
        put(i, None, blank)
        i += 1

    # Logo: letras de LABERINTO al doble de tamaño
    logo = {}
    for ch in 'LABERINTO':
        if ch in logo:
            continue
        logo[ch] = i
        for t in split16(big_glyph(FONT[ch])):
            put(i, None, t)
            i += 1
    # Medallón pequeño (16x16, para el fondo): conseguido y sin conseguir
    for nm, img in (('TILE_MEDAL', S.MEDAL_SMALL), ('TILE_MEDAL_LOCKED', S.MEDAL_LOCKED)):
        names[nm] = i
        for t in split16(img):
            put(i, None, t)
            i += 1
    assert i <= 256, i
    n = i

    # Medallón grande girando (32x32 = 8 sprites de 8x16 por imagen). No cabe
    # con el resto: la escena del medallón lo copia sobre las hojas de personajes.
    spin = S.medal_spin_frames()
    with open(os.path.join(SRC, 'assets', 'gfx', 'medal.asm'), 'w') as f:
        f.write(';; GENERADO por tools/gen_tiles.py -- no editar a mano\n')
        f.write(';; El medallón grande girando: imagen k = tiles k*16 .. k*16+15.\n')
        f.write(';; Sprite (columna c, fila r) de 8x16 = tiles (r * 4 + c) * 2 y +1.\n\n')
        f.write('SECTION "Medal spin tiles", ROMX\n\nMedalSpinTiles::\n')
        for k, img in enumerate(spin):
            for r in range(2):
                for c in range(4):
                    for half in range(2):
                        y0 = r * 16 + half * 8
                        rows = [row[c * 8:c * 8 + 8] for row in img[y0:y0 + 8]]
                        f.write(f'    db {", ".join(f"${b:02X}" for b in encode(rows))} ;; img {k} c{c} r{r}\n')
        f.write('MedalSpinTilesEnd::\n')
    names['MEDAL_SPIN_FRAMES'] = len(spin)

    with open(os.path.join(SRC, 'assets', 'gfx', 'tiles.asm'), 'w') as f:
        f.write(';; GENERADO por tools/gen_tiles.py -- no editar a mano\n\n')
        f.write('SECTION "Tiles", ROM0\n\ntiles::\n')
        for k in range(n):
            nm, rows = tiles[k] if tiles[k] else (None, blank)
            f.write(f'    db {", ".join(f"${b:02X}" for b in encode(rows))} ;; {k}{" " + nm if nm else ""}\n')
        f.write('tiles_end::\n')

    with open(os.path.join(SRC, 'engine', 'gfx.inc'), 'w') as f:
        f.write(';; GENERADO por tools/gen_tiles.py -- no editar a mano\n')
        f.write(';; Los IDs de los tiles (todos en el bloque $8000)\n\n')
        f.write('IF !DEF(GFX_INC)\nDEF GFX_INC = 1\n\n')
        f.write(f'DEF NUM_TILES = {n}\n')
        f.write(';; La fuente: tile = código ASCII - ASCII_TILE_OFFSET\n')
        f.write('DEF ASCII_TILE_OFFSET = $20\nDEF TILE_BLANK = 0\nDEF TILE_DIGIT_0 = 16\n')
        f.write(f"DEF TILE_CHAR_X = {charmap['x']}\nDEF TILE_CHAR_SLASH = {charmap['/']}\n")
        f.write(f"DEF TILE_CHAR_LT = {charmap['<']}\nDEF TILE_CHAR_GT = {charmap['>']}\n")
        f.write(f"DEF TILE_CHAR_UNDERSCORE = {charmap['_']}\nDEF TILE_CHAR_PLUS = {charmap['+']}\n\n")
        f.write(';; Tiles del nivel. Desde TILE_FIRST_SOLID son SÓLIDOS: no se atraviesan\n')
        for nm in [nm for nm, _ in S.BG_FLOOR + S.BG_HUD]:
            f.write(f'DEF {nm} = {names[nm]}\n')
        f.write(f'DEF TILE_FIRST_SOLID = {FIRST_SOLID}\n')
        for nm in [nm for nm, _ in S.BG_SOLID]:
            f.write(f'DEF {nm} = {names[nm]}\n')
        f.write('\n;; Imágenes de las entidades: 16x16 píxeles = 4 tiles.\n')
        f.write(';; Una hoja: 3 filas (abajo, arriba, lado) de 2 imágenes: imagen = fila * 2 + paso\n')
        for nm, t in sheets.items():
            f.write(f'DEF TILE_{nm} = {t}\n')
        f.write(f"DEF TILE_CURSOR = {names['TILE_CURSOR']}\n")
        f.write(f"DEF TILE_MEDAL = {names['TILE_MEDAL']}\n")
        f.write(f"DEF TILE_MEDAL_LOCKED = {names['TILE_MEDAL_LOCKED']}\n")
        f.write(f"DEF MEDAL_SPIN_FRAMES = {names['MEDAL_SPIN_FRAMES']}\n")
        f.write("DEF MEDAL_SPIN_TILE = TILE_BOY  ;; where the spin is copied (medal scene)\n")
        f.write('DEF TILES_PER_IMAGE = 4\nDEF SHEET_ROW_TILES = 2 * TILES_PER_IMAGE\n\n')
        f.write(';; Logo de la portada: cada letra son 4 tiles (2 columnas de 8x16)\n')
        for ch, t in logo.items():
            f.write(f'DEF TILE_LOGO_{ch} = {t}\n')
        f.write('\nENDC\n')

    with open(os.path.join(SRC, 'engine', 'charmap.inc'), 'w', encoding='utf-8') as f:
        f.write(';; GENERADO por tools/gen_tiles.py -- no editar a mano\n')
        f.write(';; Permite escribir textos con db "HOLA": cada letra es su tile de la fuente\n\n')
        f.write('IF !DEF(CHARMAP_INC)\nDEF CHARMAP_INC = 1\n')
        for ch, t in sorted(charmap.items(), key=lambda kv: kv[1]):
            esc = ch.replace('\\', '\\\\').replace('"', '\\"')
            f.write(f'CHARMAP "{esc}", {t}\n')
        f.write('ENDC\n')
    print(f'{n} tiles generados')


if __name__ == '__main__':
    main()
