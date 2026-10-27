;; GENERADO por tools/music.py -- no editar a mano

INCLUDE "engine/sound.inc"

SECTION "Note frequencies", ROM0
;; Valor de frecuencia (11 bits) de cada nota, C2..B7: 2048 - 131072 / Hz
NoteFreq::
    dw   44    ;; 0
    dw  157    ;; 1
    dw  263    ;; 2
    dw  363    ;; 3
    dw  457    ;; 4
    dw  547    ;; 5
    dw  631    ;; 6
    dw  711    ;; 7
    dw  786    ;; 8
    dw  856    ;; 9
    dw  923    ;; 10
    dw  986    ;; 11
    dw 1046    ;; 12
    dw 1102    ;; 13
    dw 1155    ;; 14
    dw 1205    ;; 15
    dw 1253    ;; 16
    dw 1297    ;; 17
    dw 1339    ;; 18
    dw 1379    ;; 19
    dw 1417    ;; 20
    dw 1452    ;; 21
    dw 1486    ;; 22
    dw 1517    ;; 23
    dw 1547    ;; 24
    dw 1575    ;; 25
    dw 1602    ;; 26
    dw 1627    ;; 27
    dw 1650    ;; 28
    dw 1673    ;; 29
    dw 1694    ;; 30
    dw 1714    ;; 31
    dw 1732    ;; 32
    dw 1750    ;; 33
    dw 1767    ;; 34
    dw 1783    ;; 35
    dw 1798    ;; 36
    dw 1812    ;; 37
    dw 1825    ;; 38
    dw 1837    ;; 39
    dw 1849    ;; 40
    dw 1860    ;; 41
    dw 1871    ;; 42
    dw 1881    ;; 43
    dw 1890    ;; 44
    dw 1899    ;; 45
    dw 1907    ;; 46
    dw 1915    ;; 47
    dw 1923    ;; 48
    dw 1930    ;; 49
    dw 1936    ;; 50
    dw 1943    ;; 51
    dw 1949    ;; 52
    dw 1954    ;; 53
    dw 1959    ;; 54
    dw 1964    ;; 55
    dw 1969    ;; 56
    dw 1974    ;; 57
    dw 1978    ;; 58
    dw 1982    ;; 59
    dw 1985    ;; 60
    dw 1989    ;; 61
    dw 1992    ;; 62
    dw 1995    ;; 63
    dw 1998    ;; 64
    dw 2001    ;; 65
    dw 2004    ;; 66
    dw 2006    ;; 67
    dw 2009    ;; 68
    dw 2011    ;; 69
    dw 2013    ;; 70
    dw 2015    ;; 71

SECTION "Songs", ROMX
SongTitle::  ;; 320 frames (5.3 s) en bucle
    dw .melody, .bass
.melody
    db 33, 10, 36, 10, 40, 10, 45, 10, 43, 10, 40, 10, 36, 10, 40, 10
    db 29, 10, 33, 10, 36, 10, 41, 10, 40, 10, 36, 10, 33, 10, 36, 10
    db 31, 10, 35, 10, 38, 10, 43, 10, 41, 10, 38, 10, 35, 10, 38, 10
    db 28, 10, 32, 10, 35, 10, 40, 20, NOTE_REST, 10, 38, 10, 35, 10
    db NOTE_LOOP, 0
.bass
    db 21, 40, 28, 40, 17, 40, 24, 40, 19, 40, 26, 40, 16, 40, 23, 40
    db NOTE_LOOP, 0

SongLevel1::  ;; 256 frames (4.3 s) en bucle
    dw .melody, .bass
.melody
    db 36, 8, 40, 8, 43, 8, 40, 8, 41, 8, 45, 8, 43, 16, 40, 8
    db 38, 8, 36, 8, 38, 8, 40, 16, NOTE_REST, 16, 38, 8, 41, 8, 45, 8
    db 41, 8, 40, 8, 43, 8, 48, 16, 47, 8, 45, 8, 43, 8, 41, 8
    db 40, 8, 38, 8, 36, 16
    db NOTE_LOOP, 0
.bass
    db 24, 16, 31, 16, 29, 16, 31, 16, 24, 16, 31, 16, 24, 16, 31, 16
    db 26, 16, 33, 16, 24, 16, 28, 16, 31, 16, 35, 16, 24, 16, 31, 16
    db NOTE_LOOP, 0

SongLevel2::  ;; 192 frames (3.2 s) en bucle
    dw .melody, .bass
.melody
    db 38, 6, 41, 6, 45, 6, 41, 6, 38, 6, 41, 6, 45, 12, 43, 6
    db 46, 6, 45, 6, 43, 6, 41, 6, 40, 6, 38, 12, 36, 6, 40, 6
    db 43, 6, 40, 6, 36, 6, 40, 6, 43, 12, 45, 6, 43, 6, 41, 6
    db 40, 6, 38, 6, 37, 6, 38, 12
    db NOTE_LOOP, 0
.bass
    db 26, 12, 33, 12, 26, 12, 33, 12, 19, 12, 26, 12, 19, 12, 26, 12
    db 24, 12, 31, 12, 24, 12, 31, 12, 21, 12, 28, 12, 26, 12, 21, 12
    db NOTE_LOOP, 0

SongLevel3::  ;; 160 frames (2.7 s) en bucle
    dw .melody, .bass
.melody
    db 40, 5, 40, 5, 43, 5, 40, 5, 47, 5, 40, 5, 45, 5, 43, 5
    db 40, 5, 40, 5, 43, 5, 40, 5, 50, 5, 48, 5, 47, 10, 36, 5
    db 36, 5, 40, 5, 36, 5, 45, 5, 36, 5, 43, 5, 42, 5, 39, 5
    db 42, 5, 45, 5, 47, 5, 45, 5, 42, 5, 39, 10
    db NOTE_LOOP, 0
.bass
    db 16, 10, 28, 10, 16, 10, 28, 10, 16, 10, 28, 10, 16, 10, 28, 10
    db 24, 10, 12, 10, 24, 10, 12, 10, 23, 10, 11, 10, 23, 10, 11, 10
    db NOTE_LOOP, 0

SongClear::  ;; 54 frames (0.9 s)
    dw .melody, .bass
.melody
    db 43, 6, 45, 6, 47, 6, 50, 24, NOTE_REST, 12
    db NOTE_STOP, 0
.bass
    db 31, 6, 31, 6, 31, 6, 19, 24, NOTE_REST, 12
    db NOTE_STOP, 0

SongVictory::  ;; 96 frames (1.6 s)
    dw .melody, .bass
.melody
    db 36, 8, 40, 8, 43, 8, 48, 16, 43, 8, 48, 32, NOTE_REST, 16
    db NOTE_STOP, 0
.bass
    db 24, 8, 24, 8, 24, 8, 28, 16, 31, 8, 24, 32, NOTE_REST, 16
    db NOTE_STOP, 0

SongGameOver::  ;; 100 frames (1.7 s)
    dw .melody, .bass
.melody
    db 31, 14, 30, 14, 29, 14, 28, 42, NOTE_REST, 16
    db NOTE_STOP, 0
.bass
    db 19, 14, 18, 14, 17, 14, 16, 42, NOTE_REST, 16
    db NOTE_STOP, 0

