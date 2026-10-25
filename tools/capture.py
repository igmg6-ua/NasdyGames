#!/usr/bin/env python3
"""Juega la ROM sola en un emulador y genera el material de la página de itch.io.

Uso (desde la carpeta del proyecto, después de "make"):
    python3 tools/capture.py [carpeta_salida]          (por defecto: media/)

Necesita:  pip install pyboy pillow   y   ffmpeg instalado.

Un bot juega la partida entera: elige chica e inglés, escribe un nombre,
y en cada uno de los 3 niveles recoge monedas (camino más corto con BFS),
caza a los espectros disparando cuando los tiene delante y entra en el portal.
Mientras juega se graban los frames y luego se montan:

    screenshot_1..5.png   capturas (x4, paleta verde de la DMG)
    gameplay.gif          exploración con scroll
    shooting.gif          un espectro derrotado
    trailer.mp4           tráiler de menos de 40 s (1280x720, sin sonido)
    cover.png             portada de itch.io (630x500)
    banner.png            banner para la página (960x240)

También sirve de prueba: al final dice si ha llegado a la victoria y cuántos
frames del juego han tardado más de un frame de la pantalla (debería ser 0).
"""
import os
import re
import subprocess
import sys
from collections import deque

from PIL import Image, ImageDraw, ImageFont
from pyboy import PyBoy

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'media')
ROM = os.path.join(ROOT, 'laberinto.gb')
SYM = os.path.join(ROOT, 'obj', 'laberinto.sym')
GFX = os.path.join(ROOT, 'src', 'engine', 'gfx.inc')
TILES = os.path.join(ROOT, 'src', 'assets', 'gfx', 'tiles.asm')

DMG = [(224, 248, 208), (136, 192, 112), (52, 104, 86), (8, 24, 32)]
BG_DARK = (15, 33, 26)
FPS = 30                      # el juego va a 60; se graba 1 de cada 2 frames
FONT_PATHS = ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
              '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf']
NAME_CHARS = " ABCDEFGHIJKLMNÑOPQRSTUVWXYZ"
ENTITY_NONE = 0xFF
E_SIZE, E_Y, E_X, E_KIND, E_DIR = 16, 1, 2, 7, 8
KIND_ENEMY = 4
STEP = {0: (1, 0), 1: (-1, 0), 2: (0, -1), 3: (0, 1)}      # DIR -> (dy, dx)
BUTTON = {(0, 1): 'right', (0, -1): 'left', (1, 0): 'down', (-1, 0): 'up'}


# ----------------------------------------------------------------------------
# Imagen
# ----------------------------------------------------------------------------
def to_dmg(img):
    """Captura del emulador (grises) -> paleta verde de la DMG."""
    img = img.convert('L')
    lut = [DMG[3 - min(3, v * 4 // 256)] for v in range(256)]
    out = Image.new('RGB', img.size)
    out.putdata([lut[v] for v in img.get_flattened_data()])
    return out


def scaled(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def font(size):
    for p in FONT_PATHS:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def load_tiles():
    names = {}
    for line in open(GFX):
        m = re.match(r'DEF (TILE_\w+) = (\d+)', line)
        if m:
            names[m.group(1)] = int(m.group(2))
    tiles = []
    for line in open(TILES):
        if line.strip().startswith('db'):
            d = [int(b, 16) for b in re.findall(r'\$([0-9A-F]{2})', line)]
            tiles.append([[((d[2 * r] >> (7 - i)) & 1) | (((d[2 * r + 1] >> (7 - i)) & 1) << 1)
                           for i in range(8)] for r in range(8)])
    return tiles, names


def tile_img(px, k, transparent0=True):
    img = Image.new('RGBA', (8 * k, 8 * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y, row in enumerate(px):
        for x, c in enumerate(row):
            if c or not transparent0:
                d.rectangle([x * k, y * k, x * k + k - 1, y * k + k - 1], fill=DMG[c])
    return img


def image16(tiles, first, k):
    """Una imagen de 16x16 (4 tiles: arriba izq., abajo izq., arriba der., abajo der.)."""
    img = Image.new('RGBA', (16 * k, 16 * k), (0, 0, 0, 0))
    for i, (x, y) in enumerate(((0, 0), (0, 8), (8, 0), (8, 8))):
        img.alpha_composite(tile_img(tiles[first + i], k), (x * k, y * k))
    return img


# ----------------------------------------------------------------------------
# Partida automática
# ----------------------------------------------------------------------------
class Session:
    def __init__(self, record=True):
        self.pb = PyBoy(ROM, window='null', sound_emulated=False)
        self.m = self.pb.memory
        self.sym = {}
        for l in open(SYM):
            p = l.split()
            if len(p) == 2 and ':' in p[0]:
                self.sym[p[1]] = int(p[0].split(':')[1], 16)
        self.inv = {a: n for n, a in self.sym.items()}
        self.E = self.sym['entity_array']
        self.record = record
        self.frames, self.events = [], []
        self.tag, self.held, self.n = '', None, 0
        self.last = None
        self.grid = None
        self.slow_frames = 0

    def v(self, name, off=0):
        return self.m[self.sym[name] + off]

    def scene(self):
        return self.inv.get(self.v('scene_update_ptr') + 256 * self.v('scene_update_ptr', 1), '')

    def state(self):
        return (self.v('coins'), self.v('kills'), self.v('hearts'), self.v('current_level'))

    def tick(self, k=1):
        for _ in range(k):
            before = self.v('frame_counter')
            self.pb.tick()
            self.n += 1
            if (self.v('frame_counter') - before) & 0xFF > 1:
                self.slow_frames += 1
            if self.record and self.n % (60 // FPS) == 0:
                self.frames.append((to_dmg(self.pb.screen.image), self.tag))
                now = self.state()
                if self.last and self.tag == 'game':
                    i = len(self.frames) - 1
                    if now[1] != self.last[1]:
                        self.events.append((i, 'kill'))
                    elif now[0] != self.last[0]:
                        self.events.append((i, 'coin'))
                    if now[2] > self.last[2]:
                        self.events.append((i, 'life'))
                    if now[2] < self.last[2]:
                        self.events.append((i, 'hurt'))
                self.last = now

    def tap(self, b, wait=8):
        self.pb.button_press(b)
        self.tick(3)
        self.pb.button_release(b)
        self.tick(wait)

    def hold(self, b):
        if self.held != b:
            if self.held:
                self.pb.button_release(self.held)
            if b:
                self.pb.button_press(b)
            self.held = b

    def wait_scene(self, name, max_frames=600):
        for _ in range(max_frames):
            if self.scene() == name:
                return True
            self.tick()
        return False

    # --- menú ---
    def type_name(self, name):
        self.tap('a', 10)                          # empieza a escribir
        for _ in range(7):
            self.tap('right', 3)
        for _ in range(8):
            self.tap('b', 3)                       # borra todo
        for i, ch in enumerate(name):
            k = NAME_CHARS.index(ch)
            if k <= len(NAME_CHARS) // 2:
                for _ in range(k):
                    self.tap('up', 3)
            else:
                for _ in range(len(NAME_CHARS) - k):
                    self.tap('down', 3)
            if i < len(name) - 1:
                self.tap('right', 4)
        self.tick(20)
        self.tap('a', 20)                          # listo

    # --- laberinto: una "celda" es la posición (fila, columna) de la imagen 16x16,
    #     válida si los 2 tiles de los pies (fila + 1) están libres
    def load_level(self):
        n = self.v('current_level') + 1
        self.grid = [l.rstrip('\n') for l in open(os.path.join(ROOT, 'levels', f'nivel{n}.txt'))
                     if l.strip()]

    def ok(self, y, x):
        g = self.grid
        return 0 <= y + 1 < 32 and 0 <= x + 1 < 32 and g[y + 1][x] != '#' and g[y + 1][x + 1] != '#'

    def bfs(self, a):
        prev = {a: None}
        q = deque([a])
        while q:
            c = q.popleft()
            for d in BUTTON:
                n = (c[0] + d[0], c[1] + d[1])
                if n not in prev and self.ok(*n):
                    prev[n] = c
                    q.append(n)
        return prev

    def path(self, a, b):
        prev = self.bfs(a)
        if b not in prev:
            return None
        p = [b]
        while prev[p[-1]]:
            p.append(prev[p[-1]])
        return p[::-1]

    def hero(self):
        return self.m[self.E + E_Y], self.m[self.E + E_X]

    def enemies(self):
        out = []
        for i in range(1, 12):
            b = self.E + E_SIZE * i
            if self.m[b] & 0x40 and self.m[b + E_KIND] == KIND_ENEMY:
                out.append((self.m[b + E_Y], self.m[b + E_X]))
        return out

    def enemy_ahead(self):
        """¿Hay un espectro delante del héroe, en línea y sin pared en medio?"""
        py, px = self.hero()
        dy, dx = STEP[self.m[self.E + E_DIR]]
        cy, cx = (py + 4) // 8, (px + 4) // 8
        for gy, gx in self.enemies():
            if dx and abs(gy - py) < 8 and (gx - px) * dx > 0:
                n = abs(gx - px) // 8
            elif dy and abs(gx - px) < 8 and (gy - py) * dy > 0:
                n = abs(gy - py) // 8
            else:
                continue
            if n <= 12 and all(self.ok(cy + dy * j, cx + dx * j) for j in range(1, n + 1)):
                return True
        return False

    def step_towards(self, target):
        """Un frame hacia una celda. True si ya está en ella."""
        if self.enemy_ahead() and self.v('shot_entity') == ENTITY_NONE:
            self.pb.button('a')
        # Los botones llegan al juego con un frame de retraso: se decide con la
        # posición que tendrá el héroe en el frame siguiente
        y, x = self.hero()
        sgn = lambda v: v - 256 if v > 127 else v
        y = (y + sgn(self.m[self.E + 5])) & 0xFF
        x = (x + sgn(self.m[self.E + 6])) & 0xFF
        if y % 8 == 0 and x % 8 == 0:
            cur = (y // 8, x // 8)
            if cur == target:
                self.hold(None)
                return True
            p = self.path(cur, target)
            if not p or len(p) < 2:
                self.hold(None)
                return True
            n = p[1]
            self.hold(BUTTON[(n[0] - cur[0], n[1] - cur[1])])
        elif not self.m[self.E + 5] and not self.m[self.E + 6]:
            # Parado entre dos celdas: a la más cercana
            if y % 8:
                self.hold('up' if y % 8 < 4 else 'down')
            else:
                self.hold('left' if x % 8 < 4 else 'right')
        self.tick()
        return False

    def playing(self):
        return self.scene() == 'scn_game_update' and self.v('game_result') == 0

    def goto(self, target, max_frames=60 * 30):
        for _ in range(max_frames):
            if not self.playing():
                return False
            if self.step_towards(target):
                return True
        return False

    def hunt(self, max_frames=60 * 25):
        """Persigue al espectro más cercano disparando cuando lo tiene delante."""
        for _ in range(max_frames):
            if not self.playing() or not self.enemies():
                break
            y, x = self.hero()
            prev = self.bfs(((y + 4) // 8, (x + 4) // 8))
            best = None
            for gy, gx in self.enemies():
                for c in ((gy + 4) // 8, (gx + 4) // 8), (gy // 8, gx // 8):
                    if c in prev:
                        k, p = 0, c
                        while prev[p]:
                            p = prev[p]
                            k += 1
                        if best is None or k < best[0]:
                            best = (k, c)
            if not best:
                self.tick()
                continue
            self.step_towards(best[1])
        self.hold(None)

    def coin_cells(self):
        cells = []
        for y, r in enumerate(self.grid):
            for x, c in enumerate(r):
                if c == 'o':
                    tile = self.m[self.sym['map_ram'] + y * 32 + x]
                    if tile != self.coin_tile:
                        continue          # ya cogida
                    for cell in ((y - 1, x - 1), (y - 1, x)):
                        if self.ok(*cell):
                            cells.append(cell)
                            break
        return cells

    def collect(self, count):
        for _ in range(count):
            if not self.playing():
                return
            y, x = self.hero()
            prev = self.bfs((y // 8, x // 8))
            best = None
            for c in self.coin_cells():
                if c in prev:
                    k, p = 0, c
                    while prev[p]:
                        p = prev[p]
                        k += 1
                    if best is None or k < best[0]:
                        best = (k, c)
            if not best:
                return
            self.goto(best[1])

    def exit_cell(self):
        return next((y, x) for y, r in enumerate(self.grid) for x, c in enumerate(r) if c == 'S')


def play(record=True):
    tiles_names = load_tiles()[1]
    s = Session(record)
    s.coin_tile = tiles_names['TILE_COIN']
    s.pb.tick(30)
    s.tag = 'title'
    s.tick(200)
    s.tag = 'trans'
    s.tap('start', 10)
    s.wait_scene('scn_setup_update')
    s.tick(30)
    s.tag = 'options'
    s.tap('down', 20)
    s.tap('right', 30)                     # chica
    s.tap('up', 20)
    s.tap('right', 40)                     # inglés
    for _ in range(3):
        s.tap('down', 12)                  # nombre
    s.tag = 'name'
    s.type_name('NASDY')
    s.tag = 'options'
    s.tick(30)
    s.tap('start', 10)
    for level in range(3):
        s.tag = 'intro'
        if not s.wait_scene('scn_level_update', 900):
            break
        s.tick(80)
        s.tap('start', 4)
        s.wait_scene('scn_game_update')
        s.tag = 'game'
        s.load_level()
        s.tick(10)
        s.collect(3)
        s.hunt()
        s.collect(2)
        s.goto(s.exit_cell(), 60 * 40)
        s.hold(None)
        s.tag = 'clear'
        while s.scene() == 'scn_game_update':
            s.tick()
        if s.scene() == 'scn_end_update':
            break
    s.tag = 'end'
    s.wait_scene('scn_end_update', 300)
    s.tick(200)
    return s


# ----------------------------------------------------------------------------
# Montaje
# ----------------------------------------------------------------------------
def frames_with(s, tag):
    return [i for i, (_, t) in enumerate(s.frames) if t == tag]


def lit(s, idx):
    """Quita los fotogramas en blanco (pantalla apagada entre escenas)."""
    return [i for i in idx if len(s.frames[i][0].getcolors(4) or []) > 1]


def title_shot(s):
    """Una captura de la portada con "PRESS START" a la vista (parpadea)."""
    idx = lit(s, frames_with(s, 'title'))
    for i in reversed(idx):
        band = s.frames[i][0].crop((0, 120, 160, 128))
        if len(band.getcolors(4) or []) > 1:
            return i
    return idx[-1]


def save_gif(frames, path, k=3, step=2):
    imgs = [scaled(f, k) for f in frames[::step]]
    imgs[0].save(path, save_all=True, append_images=imgs[1:], duration=int(1000 * step / FPS),
                 loop=0, optimize=True)


def make_cover(s, tiles, names, size=(630, 500)):
    """Portada: un trozo del laberinto de verdad, oscurecido, con el logo y los personajes."""
    W, H = size
    game = lit(s, frames_with(s, 'game'))
    bg = scaled(s.frames[game[len(game) // 4]][0].crop((0, 0, 160, 136)), 5)
    bg = bg.resize((max(W, bg.width * W // bg.width), max(H, bg.height * W // bg.width)), Image.NEAREST)
    bg = bg.crop(((bg.width - W) // 2, (bg.height - H) // 2, (bg.width - W) // 2 + W,
                  (bg.height - H) // 2 + H)).convert('RGBA')
    bg.alpha_composite(Image.new('RGBA', (W, H), BG_DARK + (205,)))
    k = min(6, (W - 80) // 144, (H // 2 - 40) // 16)
    logo = Image.new('RGBA', (9 * 16 * k, 16 * k), (0, 0, 0, 0))
    for i, ch in enumerate('LABERINTO'):
        logo.alpha_composite(image16(tiles, names[f'TILE_LOGO_{ch}'], k), (i * 16 * k, 0))
    # el logo es oscuro sobre claro: una placa clara detrás
    big = H > 300
    ty = H // 6 if big else 28
    plate = Image.new('RGBA', (logo.width + 40, logo.height + 24), DMG[0] + (255,))
    bg.alpha_composite(plate, ((W - plate.width) // 2, ty - 12))
    bg.alpha_composite(logo, ((W - logo.width) // 2, ty))
    sk = 7 if big else 5
    row = [image16(tiles, names['TILE_GIRL'], sk), image16(tiles, names['TILE_SPECTRE'] + 16, sk),
           image16(tiles, names['TILE_PORTAL'], sk), image16(tiles, names['TILE_BOY'], sk)]
    if big:
        gap = 30
        total = sum(i.width for i in row) + gap * (len(row) - 1)
        x, y = (W - total) // 2, ty + logo.height + 60
        plate = Image.new('RGBA', (total + 40, row[0].height + 30), DMG[0] + (255,))
        bg.alpha_composite(plate, (x - 20, y - 15))
        for im in row:
            bg.alpha_composite(im, (x, y))
            x += im.width + gap
        d = ImageDraw.Draw(bg)
        f = font(26)
        t = 'GAME BOY  ·  DMG'
        d.text(((W - d.textlength(t, font=f)) / 2, H - 58), t, font=f, fill=DMG[0])
    else:
        for im, x in ((row[0], 30), (row[1], W - 30 - row[1].width)):
            plate = Image.new('RGBA', (im.width + 16, im.height + 16), DMG[0] + (255,))
            bg.alpha_composite(plate, (x - 8, (H - im.height) // 2 - 8 + 20))
            bg.alpha_composite(im, (x, (H - im.height) // 2 + 20))
    return bg.convert('RGB')


def make_trailer(s, path, cover):
    W, H, K = 1280, 720, 4
    gx, gy = (W - 160 * K) // 2, 24
    f_cap = font(30)
    clips = []
    game = lit(s, frames_with(s, 'game'))
    clips.append((lit(s, frames_with(s, 'title'))[:int(3.5 * FPS)], ''))
    clips.append((lit(s, frames_with(s, 'options'))[:int(3 * FPS)],
                  'Play as a girl or a boy, in English or Spanish'))
    clips.append((lit(s, frames_with(s, 'name'))[::3][:int(2 * FPS)], 'Type your name'))
    clips.append((game[:int(4.5 * FPS)], 'Three mazes, bigger than the screen'))
    used = set(game[:int(4.5 * FPS)])
    budget = 38 * FPS - sum(len(c[0]) for c in clips) - int(4.5 * FPS) - int(2.5 * FPS)
    texts = {'coin': 'Grab the coins', 'kill': 'Shoot the spectres: +5 coins each',
             'life': 'Defeat them all: an extra heart!', 'hurt': 'Three hearts... be careful'}
    shown = {k: 0 for k in texts}
    limit = {'coin': 1, 'kill': 2, 'life': 1, 'hurt': 1}
    for i, kind in s.events:
        if shown[kind] >= limit[kind] or budget <= 0:
            continue
        a, b = max(i - int(2.0 * FPS), 0), min(i + int(1.2 * FPS), len(s.frames))
        idx = [j for j in range(a, b) if s.frames[j][1] == 'game' and j not in used]
        idx = lit(s, idx)
        if len(idx) < FPS or len(idx) > budget:
            continue
        clips.append((idx, texts[kind]))
        used.update(idx)
        shown[kind] += 1
        budget -= len(idx)
    clear = lit(s, frames_with(s, 'clear'))
    end = lit(s, frames_with(s, 'end'))
    clips.append((clear[:int(1.5 * FPS)] + end[:int(3 * FPS)], 'Reach the portal before time runs out'))

    proc = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
                             '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-c:v', 'libx264',
                             '-pix_fmt', 'yuv420p', '-crf', '18', '-movflags', '+faststart', path],
                            stdin=subprocess.PIPE)
    n = 0
    for idx, txt in clips:
        for j in idx:
            frame = Image.new('RGB', (W, H), BG_DARK)
            frame.paste(scaled(s.frames[j][0], K), (gx, gy))
            if txt:
                d = ImageDraw.Draw(frame)
                d.text(((W - d.textlength(txt, font=f_cap)) / 2, gy + 144 * K + 30), txt,
                       font=f_cap, fill=DMG[0])
            proc.stdin.write(frame.tobytes())
            n += 1
    card = Image.new('RGB', (W, H), BG_DARK)
    c = cover.resize((int(cover.width * 1.15), int(cover.height * 1.15)), Image.NEAREST)
    card.paste(c, ((W - c.width) // 2, (H - c.height) // 2 - 24))
    d = ImageDraw.Draw(card)
    t = "#GBRetroDev'26  ·  100% assembly  ·  Game Boy DMG"
    d.text(((W - d.textlength(t, font=f_cap)) / 2, H - 64), t, font=f_cap, fill=DMG[0])
    for _ in range(int(2.5 * FPS)):
        proc.stdin.write(card.tobytes())
        n += 1
    proc.stdin.close()
    proc.wait()
    return n / FPS


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles, names = load_tiles()
    print('Jugando la partida automática...')
    s = play()
    res = {0: 'jugando', 1: 'nivel superado', 2: 'sin corazones', 3: 'sin tiempo', 4: 'VICTORIA'}
    print(f"  {len(s.frames)} frames grabados; eventos: {[k for _, k in s.events]}")
    print(f"  final: {res.get(s.v('game_result'))}, monedas {s.v('coins'):X}, "
          f"espectros {s.v('kills'):X}, corazones {s.v('hearts')}, frames lentos: {s.slow_frames}")

    game = lit(s, frames_with(s, 'game'))
    kills = [i for i, k in s.events if k == 'kill']
    opts = lit(s, frames_with(s, 'options'))
    shots = {
        'screenshot_1.png': title_shot(s),
        'screenshot_2.png': opts[min(len(opts) - 1, 70)],
        'screenshot_3.png': game[len(game) // 5],
        'screenshot_4.png': (kills[0] + 2) if kills else game[len(game) // 2],
        'screenshot_5.png': lit(s, frames_with(s, 'end'))[-1],
    }
    for fn, i in shots.items():
        scaled(s.frames[i][0], 4).save(os.path.join(OUT, fn))
    save_gif([s.frames[i][0] for i in game[:6 * FPS]], os.path.join(OUT, 'gameplay.gif'))
    if kills:
        a = max(kills[0] - 3 * FPS, 0)
        save_gif([s.frames[i][0] for i in lit(s, range(a, kills[0] + FPS))],
                 os.path.join(OUT, 'shooting.gif'))
    cover = make_cover(s, tiles, names)
    cover.save(os.path.join(OUT, 'cover.png'))
    make_cover(s, tiles, names, size=(960, 240)).save(os.path.join(OUT, 'banner.png'))
    secs = make_trailer(s, os.path.join(OUT, 'trailer.mp4'), cover)
    print(f'  tráiler: {secs:.1f} s')
    print('Listo en', os.path.abspath(OUT))


if __name__ == '__main__':
    main()
