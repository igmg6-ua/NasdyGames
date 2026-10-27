#!/usr/bin/env python3
"""Convierte los niveles en texto (levels/nivel1.txt, nivel2.txt...) a ensamblador.

Uso: python3 tools/map2asm.py
Salida: src/assets/levels/levels.asm   (mapas + LevelTable con el formato LVL_)

Leyenda:  # pared   . suelo   o moneda   P jugador   E espectro   S portal
          (P, E y S marcan el tile de arriba a la izquierda de su imagen 16x16)

Comprueba que el mapa es de 32x32, que hay un jugador y un portal, y que el
portal y todas las monedas son alcanzables con los "pies" de un personaje de
16x16 (una caja de 2 tiles de ancho en la fila de abajo de su imagen).
Cada pared se dibuja con "frente de ladrillo" si debajo hay suelo y con la
"tapa" si no, para dar relieve.
"""
import glob
import os
import re
import sys
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS = os.path.join(HERE, '..', 'levels')
OUT = os.path.join(HERE, '..', 'src', 'assets', 'levels', 'levels.asm')
SIZE = 32
MAX_ENEMIES = 6
SONGS = ['SongLevel1', 'SongLevel2', 'SongLevel3']


def fail(path, msg):
    sys.exit(f'{path}: {msg}')


def convert(path, n):
    rows = [l.rstrip('\n') for l in open(path) if l.strip()]
    if len(rows) != SIZE or any(len(r) != SIZE for r in rows):
        fail(path, f'el mapa debe ser de {SIZE}x{SIZE}')
    wall = lambda y, x: not (0 <= y < SIZE and 0 <= x < SIZE) or rows[y][x] == '#'
    find = lambda c: [(y, x) for y in range(SIZE) for x in range(SIZE) if rows[y][x] == c]
    P, S, E, coins = find('P'), find('S'), find('E'), find('o')
    if len(P) != 1: fail(path, 'tiene que haber un jugador (P)')
    if len(S) != 1: fail(path, 'tiene que haber un portal (S)')
    if len(E) > MAX_ENEMIES: fail(path, f'como mucho {MAX_ENEMIES} espectros (E)')

    # Alcanzable: posición (y, x) válida si los 2 tiles de los pies (fila y+1) están libres
    ok = lambda y, x: not wall(y + 1, x) and not wall(y + 1, x + 1)
    for c, what in [(P[0], 'el jugador'), (S[0], 'el portal')] + [(e, 'un espectro') for e in E]:
        if not ok(*c):
            fail(path, f'{what} en {c} no cabe (necesita 2 tiles libres debajo)')
    seen = {P[0]}
    q = deque(seen)
    while q:
        y, x = q.popleft()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            p = (y + dy, x + dx)
            if p not in seen and ok(*p):
                seen.add(p); q.append(p)
    if S[0] not in seen: fail(path, 'el portal no es alcanzable')
    for cy, cx in coins:
        if not any((cy - 1, x) in seen for x in (cx - 1, cx)):
            fail(path, f'moneda inalcanzable en {(cy, cx)}')

    def tile(y, x):
        c = rows[y][x]
        if c == '#':
            return 'WF' if not wall(y + 1, x) else 'WT'
        if c == 'o':
            return 'CN'
        h = (y * 31 + x * 17 + n * 7) % 13
        return 'FB' if h == 0 else 'FC' if h == 5 else 'FL'

    out = [f';; ---- {os.path.basename(path)}: {len(coins)} monedas, {len(E)} espectros',
           f'SECTION "Level{n} map", ROMX', f'Level{n}Map::']
    for y in range(SIZE):
        out.append('    db ' + ','.join(tile(y, x) for x in range(SIZE)))
    (py, px), (sy, sx) = P[0], S[0]
    out += ['', f'SECTION "Level{n} data", ROMX', f'Level{n}::',
            f'    dw Level{n}Map             ;; LVL_MAP',
            f'    dw {SONGS[(n - 1) % len(SONGS)]}            ;; LVL_SONG',
            f'    db {px}, {py}               ;; LVL_PLAYER_TX, LVL_PLAYER_TY (columna, fila)',
            f'    db {sx}, {sy}               ;; LVL_EXIT_TX, LVL_EXIT_TY',
            f'    db {len(E)}                  ;; LVL_ENEMIES, y cada uno: columna, fila']
    for y, x in E:
        out.append(f'    db {x}, {y}')
    out.append('')
    return out


def main():
    files = sorted(glob.glob(os.path.join(LEVELS, 'nivel*.txt')),
                   key=lambda p: int(re.findall(r'\d+', os.path.basename(p))[0]))
    if not files:
        sys.exit('No hay niveles en levels/')
    out = [';; GENERADO por tools/map2asm.py a partir de levels/*.txt -- no editar a mano',
           ';; Para cambiar un nivel, edita su .txt y ejecuta "make assets".', '',
           'INCLUDE "engine/gfx.inc"', '',
           'DEF FL = TILE_FLOOR', 'DEF FB = TILE_FLOOR_B', 'DEF FC = TILE_FLOOR_C',
           'DEF CN = TILE_COIN', 'DEF WT = TILE_WALL_TOP', 'DEF WF = TILE_WALL_FRONT', '']
    for i, f in enumerate(files, 1):
        out += convert(f, i)
    out += ['SECTION "Level table", ROM0', ';; Los niveles en orden (level_get los lee de aquí)',
            'LevelTable::']
    out += [f'    dw Level{i}' for i in range(1, len(files) + 1)]
    out += [f'DEF LEVEL_COUNT EQU {len(files)}', 'EXPORT LEVEL_COUNT', '',
            'PURGE FL, FB, FC, CN, WT, WF']
    with open(OUT, 'w') as f:
        f.write('\n'.join(out) + '\n')
    print(f'{len(files)} niveles -> {os.path.relpath(OUT)}')


if __name__ == '__main__':
    main()
