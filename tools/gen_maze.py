#!/usr/bin/env python3
"""Genera laberintos de 32x32 tiles en texto: levels/nivelN.txt.

Uso: python3 tools/gen_maze.py N SEMILLA ENEMIGOS MONEDAS_EXTRA CICLOS
     (sin argumentos genera los 3 niveles del juego)

El laberinto tiene 10x10 salas de 2x2 tiles (los personajes miden 16x16) y
paredes de 1 tile: sala (fila, columna) = tiles 3*fila+1..3*fila+2.
Leyenda:  # pared   . suelo   o moneda   P jugador   E enemigo   S portal (salida)
          (P, E y S marcan el tile de arriba a la izquierda de la sala)
Los .txt se pueden retocar a mano; después: make assets && make.
"""
import os
import random
import sys
from collections import deque

ROOMS = 10
SIZE = 32
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'levels')


def make(n, seed, enemies, extra_coins, loops):
    rnd = random.Random(seed)
    g = [['#'] * SIZE for _ in range(SIZE)]

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

    links = {(y, x): set() for y in range(ROOMS) for x in range(ROOMS)}
    seen = {(0, 0)}
    stack = [(0, 0)]
    room(0, 0)
    while stack:
        c = stack[-1]
        nb = [(c[0] + dy, c[1] + dx) for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))
              if 0 <= c[0] + dy < ROOMS and 0 <= c[1] + dx < ROOMS and (c[0] + dy, c[1] + dx) not in seen]
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
    cand = [((y, x), (y + dy, x + dx)) for y in range(ROOMS) for x in range(ROOMS)
            for dy, dx in ((0, 1), (1, 0)) if y + dy < ROOMS and x + dx < ROOMS
            and (y + dy, x + dx) not in links[(y, x)]]
    for a, b in rnd.sample(cand, loops):
        open_between(a, b)
        links[a].add(b); links[b].add(a)

    # Distancias desde la salida del jugador (sala 0,0 o la esquina que toque)
    start = rnd.choice([(0, 0), (0, ROOMS - 1), (ROOMS - 1, 0)])
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
    far = [c for c in dist if dist[c] >= 6 and c != exit_]
    rnd.shuffle(far)
    foes = []
    for c in far:            # enemigos repartidos: lejos unos de otros
        if all(abs(c[0] - f[0]) + abs(c[1] - f[1]) >= 4 for f in foes):
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
    print(f'{path}: salida a {dist[exit_]} salas, {len(foes)} enemigos, {len(coins)} monedas')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) > 1:
        make(*[int(a) for a in sys.argv[1:6]])
    else:
        make(1, 1103, 2, 4, 10)    # nivel 1: 2 espectros, muchos ciclos
        make(2, 2207, 3, 5, 8)     # nivel 2: 3 espectros
        make(3, 3301, 4, 6, 6)     # nivel 3: 4 espectros, menos atajos
