;;==============================================================
;; engine/interrupts.asm -- Interrupciones de VBLANK y de STAT
;;
;; El bucle principal duerme con halt hasta que llega el VBLANK (wait_frame):
;; no gasta la CPU esperando y empieza a dibujar justo a tiempo.
;; La interrupción STAT (en cada HBLANK) sólo se usa en la portada para
;; ondular el logo: cambia rSCX línea a línea (un efecto de raster).
;;==============================================================
INCLUDE "engine/hardware.inc"

DEF LOGO_FIRST_LINE = 16              ;; lines of the screen where the logo waves
DEF LOGO_LAST_LINE  = 32

SECTION "VBlank vector", ROM0[$40]
    jp   vblank_isr

SECTION "STAT vector", ROM0[$48]
    jp   stat_isr

SECTION "Interrupt vars", HRAM

hVBlankFlag::  ds 1                   ;; 1: a VBLANK has started
hWavePhase::   ds 1                   ;; where the wave of the logo is

;; The wave: 32 values of SCX (a sine of 3 pixels). In one page: index = low byte
SECTION "Wave table", ROM0, ALIGN[8]
WaveTable:
    db 0, 1, 1, 2, 2, 3, 3, 3, 3, 3, 3, 2, 2, 1, 1, 0
    db 0, -1, -1, -2, -2, -3, -3, -3, -3, -3, -3, -2, -2, -1, -1, 0

SECTION "Interrupts", ROM0

vblank_isr:
    push af
    ld   a, 1                         ;; \ Tell the main loop
    ldh  [hVBlankFlag], a             ;; /
    pop  af
    reti

;; In each HBLANK of the lines of the logo, SCX = the wave for that line
stat_isr:
    push af
    push hl
    ldh  a, [rLY]                     ;; \ The next line drawn is LY + 1
    cp   LOGO_FIRST_LINE - 1          ;; | Is it a line of the logo?
    jr   c, .flat                     ;; |
    cp   LOGO_LAST_LINE               ;; |
    jr   nc, .flat                    ;; /
    ld   hl, hWavePhase               ;; \ A = (line + phase) % 32
    add  [hl]                         ;; |
    and  31                           ;; /
    ld   l, a                         ;; \ SCX = WaveTable[A]
    ld   h, HIGH(WaveTable)           ;; |
    ld   a, [hl]                      ;; |
    ldh  [rSCX], a                    ;; /
    jr   .end
.flat
    xor  a                            ;; \ Outside the logo, no wave
    ldh  [rSCX], a                    ;; /
.end
    pop  hl
    pop  af
    reti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sleeps (halt) until the next VBLANK starts.
;; ❌ Modifies A
wait_frame::
    xor  a
    ldh  [hVBlankFlag], a
    ldh a, [rIE]
    and IEF_STAT
    jr nz, .poll
.sleep
    halt                              ;; \ Any interrupt wakes the CPU up:
    ldh  a, [hVBlankFlag]             ;; | sleep again until it is the VBLANK
    or   a                            ;; |
    jr   z, .sleep                    ;; /
    ret
.poll
    ldh a, [hVBlankFlag]
    or a
    jr z, .poll
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Turns the wave of the logo on / off (STAT interrupt at every HBLANK).
;; ❌ Modifies A
raster_on::
    ld   a, STATF_MODE0
    ldh  [rSTAT], a
    ld   a, IEF_VBLANK | IEF_STAT
    ldh  [rIE], a
    ret

raster_off::
    ld   a, IEF_VBLANK
    ldh  [rIE], a
    xor  a
    ldh  [rSTAT], a
    ldh  [rSCX], a
    ret
