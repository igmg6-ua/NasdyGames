;;==============================================================
;; engine/video.asm -- Pantalla: encender, apagar, fundidos de paleta
;;==============================================================
INCLUDE "engine/hardware.inc"

SECTION "Video", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Turns the screen off (only in VBLANK: doing it while drawing can damage a
;; real Game Boy). If it is already off, it does nothing.
;; ❌ Modifies A
lcd_off::
    ldh  a, [rLCDC]                   ;; \ Already off?
    bit  LCDC_ON_BIT, a               ;; |
    ret  z                            ;; /
.wait
    ldh  a, [rLY]                     ;; \ Wait for the VBLANK
    cp   VBLANK_LINE                  ;; |
    jr   c, .wait                     ;; /
    ldh  a, [rLCDC]                   ;; \ Off
    res  LCDC_ON_BIT, a               ;; |
    ldh  [rLCDC], a                   ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 📥 A = rLCDC (LCDC_VALUE or LCDC_NO_WINDOW)
lcd_on::
    ldh  [rLCDC], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Palette fades: 4 steps from white to the normal palette (and back), 4 frames
;; each. The same palette for the background and the sprites.
;; ❌ Modifies A, B, HL
fade_in::
    ld   hl, FadeSteps
    jr   fade_run
fade_out::
    ld   hl, FadeSteps + 3
    ld   a, l                         ;; (the table is walked backwards)
    jr   fade_back

fade_run:
    ld   b, 4
.step
    ld   a, [hl+]
    call fade_set
    dec  b
    jr   nz, .step
    ret

fade_back:
    ld   b, 4
.step
    ld   a, [hl-]
    call fade_set
    dec  b
    jr   nz, .step
    ret

;; A = palette: it is used for 4 frames
fade_set:
    ldh  [rBGP], a
    ldh  [rOBP0], a
    push bc
    ld   b, 4
.wait
    call wait_frame
    dec  b
    jr   nz, .wait
    pop  bc
    ret

FadeSteps:
    db %00000000, %01000000, %10010000, PALETTE

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Normal palettes (without fade).
;; ❌ Modifies A
palettes_reset::
    ld   a, PALETTE
    ldh  [rBGP], a
    ldh  [rOBP0], a
    ld   a, PALETTE_HURT
    ldh  [rOBP1], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; All white (before a fade in). ❌ Modifies A
palettes_white::
    xor  a
    ldh  [rBGP], a
    ldh  [rOBP0], a
    ret
