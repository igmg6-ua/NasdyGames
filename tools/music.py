#!/usr/bin/env python3
"""Convierte las canciones del juego (escritas con nombres de notas) a ensamblador.

Uso: python3 tools/music.py        ->  src/assets/snd/songs.asm

Cada canción tiene dos voces que suenan a la vez:
  melodía -> canal 2 (pulso)        bajo -> canal 3 (onda)
Formato de una voz: "NOTA DURACIÓN, NOTA DURACIÓN, ..."
  NOTA = C D E F G A B (+ '#' para sostenido) + octava (2-7), o R (silencio)
  DURACIÓN en frames (60 = 1 segundo)
Las dos voces de una canción deben durar lo mismo (se comprueba).
LOOP = True: vuelve a empezar al acabar. False: se para (jingles).

El motor (src/engine/sound.asm) lee pares de bytes: nota (0-71: C2..B7),
duración. NOTE_REST = silencio, NOTE_LOOP = volver al principio, NOTE_STOP = parar.
El canal 3 suena una octava más grave que el 2 con el mismo valor, así que el
bajo se guarda una octava por encima de lo escrito.
"""
import os
import re
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'assets', 'snd', 'songs.asm')
NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
FIRST_OCTAVE = 2        # índice 0 = C2
REST, LOOP, STOP = 0xFE, 0xFF, 0xFD

# ---------------------------------------------------------------------------
# Las canciones (composiciones originales para este juego)
# ---------------------------------------------------------------------------
Q = 10   # una corchea en la portada
SONGS = {
    # Portada: misteriosa, en La menor, con arpegios
    'SongTitle': (True,
        f"A4 {Q}, C5 {Q}, E5 {Q}, A5 {Q}, G5 {Q}, E5 {Q}, C5 {Q}, E5 {Q},"
        f"F4 {Q}, A4 {Q}, C5 {Q}, F5 {Q}, E5 {Q}, C5 {Q}, A4 {Q}, C5 {Q},"
        f"G4 {Q}, B4 {Q}, D5 {Q}, G5 {Q}, F5 {Q}, D5 {Q}, B4 {Q}, D5 {Q},"
        f"E4 {Q}, G#4 {Q}, B4 {Q}, E5 {2*Q}, R {Q}, D5 {Q}, B4 {Q}",
        f"A2 {4*Q}, E3 {4*Q}, F2 {4*Q}, C3 {4*Q}, G2 {4*Q}, D3 {4*Q}, E2 {4*Q}, B2 {4*Q}"),
    # Nivel 1: alegre, Do mayor
    'SongLevel1': (True,
        "C5 8, E5 8, G5 8, E5 8, F5 8, A5 8, G5 16,"
        "E5 8, D5 8, C5 8, D5 8, E5 16, R 16,"
        "D5 8, F5 8, A5 8, F5 8, E5 8, G5 8, C6 16,"
        "B5 8, A5 8, G5 8, F5 8, E5 8, D5 8, C5 16",
        "C3 16, G3 16, F3 16, G3 16, C3 16, G3 16, C3 16, G3 16,"
        "D3 16, A3 16, C3 16, E3 16, G3 16, B3 16, C3 16, G3 16"),
    # Nivel 2: Re menor, un poco más rápido
    'SongLevel2': (True,
        "D5 6, F5 6, A5 6, F5 6, D5 6, F5 6, A5 12,"
        "G5 6, A#5 6, A5 6, G5 6, F5 6, E5 6, D5 12,"
        "C5 6, E5 6, G5 6, E5 6, C5 6, E5 6, G5 12,"
        "A5 6, G5 6, F5 6, E5 6, D5 6, C#5 6, D5 12",
        "D3 12, A3 12, D3 12, A3 12, G2 12, D3 12, G2 12, D3 12,"
        "C3 12, G3 12, C3 12, G3 12, A2 12, E3 12, D3 12, A2 12"),
    # Nivel 3: Mi menor, tenso y rápido
    'SongLevel3': (True,
        "E5 5, E5 5, G5 5, E5 5, B5 5, E5 5, A5 5, G5 5,"
        "E5 5, E5 5, G5 5, E5 5, D6 5, C6 5, B5 10,"
        "C5 5, C5 5, E5 5, C5 5, A5 5, C5 5, G5 5, F#5 5,"
        "D#5 5, F#5 5, A5 5, B5 5, A5 5, F#5 5, D#5 10",
        "E2 10, E3 10, E2 10, E3 10, E2 10, E3 10, E2 10, E3 10,"
        "C3 10, C2 10, C3 10, C2 10, B2 10, B1 10, B2 10, B1 10"),
    # Nivel superado (no se repite)
    'SongClear': (False,
        "G5 6, A5 6, B5 6, D6 24, R 12",
        "G3 6, G3 6, G3 6, G2 24, R 12"),
    # Victoria (no se repite)
    'SongVictory': (False,
        "C5 8, E5 8, G5 8, C6 16, G5 8, C6 32, R 16",
        "C3 8, C3 8, C3 8, E3 16, G3 8, C3 32, R 16"),
    # Game over (no se repite)
    'SongGameOver': (False,
        "G4 14, F#4 14, F4 14, E4 42, R 16",
        "G2 14, F#2 14, F2 14, E2 42, R 16"),
}


def parse(voice, octave_up=0):
    out = []
    total = 0
    for tok in [t.strip() for t in voice.split(',') if t.strip()]:
        note, dur = tok.split()
        dur = int(dur)
        assert 1 <= dur <= 255, tok
        if note == 'R':
            out.append((REST, dur))
        else:
            m = re.fullmatch(r'([A-G])(#?)(\d)', note)
            if not m:
                sys.exit(f'Nota incorrecta: {tok}')
            idx = NAMES[m.group(1)] + (1 if m.group(2) else 0) + 12 * (int(m.group(3)) - FIRST_OCTAVE + octave_up)
            if not 0 <= idx < 72:
                sys.exit(f'Nota fuera de rango: {tok}')
            out.append((idx, dur))
        total += dur
    return out, total


def main():
    lines = [';; GENERADO por tools/music.py -- no editar a mano', '',
             'INCLUDE "engine/sound.inc"', '',
             'SECTION "Note frequencies", ROM0',
             ';; Valor de frecuencia (11 bits) de cada nota, C2..B7: 2048 - 131072 / Hz',
             'NoteFreq::']
    for i in range(72):
        hz = 440.0 * 2 ** ((i + 12 * FIRST_OCTAVE - 57) / 12)
        x = round(2048 - 131072 / hz)
        lines.append(f'    dw {x:4d}    ;; {i}')
    lines += ['', 'SECTION "Songs", ROMX']
    for name, (loop, mel, bass) in SONGS.items():
        m, tm = parse(mel)
        b, tb = parse(bass, octave_up=1)
        if tm != tb:
            sys.exit(f'{name}: la melodía dura {tm} frames y el bajo {tb}')
        end = 'NOTE_LOOP' if loop else 'NOTE_STOP'
        lines.append(f'{name}::  ;; {tm} frames ({tm / 60:.1f} s){" en bucle" if loop else ""}')
        lines.append(f'    dw .melody, .bass')
        for lab, voice in (('melody', m), ('bass', b)):
            lines.append(f'.{lab}')
            for k in range(0, len(voice), 8):
                part = voice[k:k + 8]
                lines.append('    db ' + ', '.join(
                    f'{"NOTE_REST" if n == REST else n}, {d}' for n, d in part))
            lines.append(f'    db {end}, 0')
        lines.append('')
    with open(OUT, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(f'{len(SONGS)} canciones -> {os.path.relpath(OUT)}')


if __name__ == '__main__':
    main()
