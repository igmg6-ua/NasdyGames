#!/usr/bin/env python3
"""Genera laberintos en texto: levels/nivelN.txt.

Uso: python3 tools/gen_maze.py N SEMILLA ANCHO ALTO ENEMIGOS MONEDAS_EXTRA CICLOS
     (sin argumentos genera los 10 niveles del juego, de la tabla LEVELS)

Un laberinto tiene ANCHO x ALTO salas de 2x2 tiles (los personajes miden 16x16)
y paredes de 1 tile: sala (fila, columna) = tiles 3*fila+1..3*fila+2.
Como mucho 10x10 salas: 31x31 tiles, lo que cabe en el fondo de la Game Boy.
Leyenda:  # pared   . suelo   o moneda   P jugador   E enemigo   S portal (salida)
          (P, E y S marcan el tile de arriba a la izquierda de la sala)
Los .txt se pueden retocar a mano; después: make assets && make.
"""
import os
import random
import sys
from collections import deque

MAX_ROOMS = 10
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'levels')


def make(n, seed, rw, rh, enemies, extra_coins, loops):
    assert rw <= MAX_ROOMS and rh <= MAX_ROOMS
    rnd = random.Random(seed)
    g = [['#'] * (3 * rw + 1) for _ in range(3 * rh + 1)]

    def room(cy, cx, ch='.'):
        for y in (3 * cy + 1, 3 * cy + 2):
            for x in (3 * cx + 1, 3 * cx + 2):
                g[y][x] = ch

    def open_between(a, b):
        (ay, ax), (by, bx) = a, b
        if ay == by:   # horizontal: abre la columna de pared entre las dos
            x = 3 * min(ax, bx) + 3
            g[3 * ay + 1][x] = g[3 * ay + 2][x] = '.'
        else:          # vertical: abre la fila de pared
            y = 3 * min(ay, by) + 3
            g[y][3 * ax + 1] = g[y][3 * ax + 2] = '.'

    links = {(y, x): set() for y in range(rh) for x in range(rw)}
    seen = {(0, 0)}
    stack = [(0, 0)]
    room(0, 0)
    while stack:
        c = stack[-1]
        nb = [(c[0] + dy, c[1] + dx) for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))
              if 0 <= c[0] + dy < rh and 0 <= c[1] + dx < rw and (c[0] + dy, c[1] + dx) not in seen]
        if not nb:
            stack.pop()
            continue
        nx = rnd.choice(nb)
        room(*nx)
        open_between(c, nx)
        links[c].add(nx); links[nx].add(c)
        seen.add(nx)
        stack.append(nx)

    # Algunos ciclos para poder esquivar a los espectros
    cand = [((y, x), (y + dy, x + dx)) for y in range(rh) for x in range(rw)
            for dy, dx in ((0, 1), (1, 0)) if y + dy < rh and x + dx < rw
            and (y + dy, x + dx) not in links[(y, x)]]
    for a, b in rnd.sample(cand, loops):
        open_between(a, b)
        links[a].add(b); links[b].add(a)

    # Distancias desde la salida del jugador (sala 0,0 o la esquina que toque)
    start = rnd.choice([(0, 0), (0, rw - 1), (rh - 1, 0)])
    dist = {start: 0}
    q = deque([start])
    while q:
        c = q.popleft()
        for d in links[c]:
            if d not in dist:
                dist[d] = dist[c] + 1
                q.append(d)
    exit_ = max(dist, key=dist.get)
    dead_ends = [c for c in links if len(links[c]) == 1 and c not in (start, exit_)]
    far = [c for c in dist if dist[c] >= max(5, (rw + rh) // 3) and c != exit_]
    rnd.shuffle(far)
    foes = []
    for c in far:            # enemigos repartidos: lejos unos de otros
        if all(abs(c[0] - f[0]) + abs(c[1] - f[1]) >= 3 for f in foes):
            foes.append(c)
        if len(foes) == enemies:
            break
    others = [c for c in dist if c not in dead_ends and c not in (start, exit_) and c not in foes]
    coins = dead_ends + rnd.sample(others, extra_coins)

    for cy, cx in coins:           # la moneda va en la fila de abajo de la sala
        g[3 * cy + 2][3 * cx + 1 + rnd.randint(0, 1)] = 'o'
    g[3 * start[0] + 1][3 * start[1] + 1] = 'P'
    g[3 * exit_[0] + 1][3 * exit_[1] + 1] = 'S'
    for cy, cx in foes:
        g[3 * cy + 1][3 * cx + 1] = 'E'

    path = os.path.join(OUT, f'nivel{n}.txt')
    with open(path, 'w') as f:
        f.write('\n'.join(''.join(r) for r in g) + '\n')
    assert len(foes) == enemies, (n, len(foes))
    print(f'{path}: {rw}x{rh} salas, salida a {dist[exit_]} salas, {len(foes)} enemigos, {len(coins)} monedas')


# Los 10 niveles: cada uno más grande y con más espectros que el anterior
#          N  semilla ancho alto espectros monedas_extra ciclos
LEVELS = [(1, 1103, 6, 6, 2, 2, 8),
          (2, 2207, 7, 6, 2, 3, 8),
          (3, 3301, 7, 7, 3, 3, 8),
          (4, 4409, 8, 7, 3, 4, 7),
          (5, 5503, 8, 8, 4, 4, 7),
          (6, 6607, 9, 8, 4, 5, 6),
          (7, 7703, 9, 9, 5, 5, 6),
          (8, 8807, 10, 9, 5, 6, 5),
          (9, 9901, 10, 10, 6, 6, 5),
          (10, 1009, 10, 10, 6, 6, 4)]


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) > 1:
        make(*[int(a) for a in sys.argv[1:8]])
    else:
        for level in LEVELS:
            make(*level)
