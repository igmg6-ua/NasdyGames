;;==============================================================
;; engine/text.asm -- Escribir textos y números en el fondo o la window
;; (con la pantalla apagada, en VBLANK o en el búfer de una fila)
;;==============================================================
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"

SECTION "Text", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 📥 HL = destination, DE = text ended in TEXT_END
;; ⫷▬ HL = just after the text
;; ❌ Modifies A, DE, HL
draw_text::
    ld   a, [de]
    cp   TEXT_END
    ret  z
    ld   [hl+], a
    inc  de
    jr   draw_text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Writes a text centred in a row of the screen.
;; 📥 HL = start of the row (column 0), DE = text (20 letters at most)
;; ❌ Modifies A, B, DE, HL
draw_text_centered::
    push de
    ld   b, 0
.count
    ld   a, [de]                      ;; \ B = length of the text
    cp   TEXT_END                     ;; |
    jr   z, .counted                  ;; |
    inc  b                            ;; |
    inc  de                           ;; |
    jr   .count                       ;; /
.counted
    pop  de
    ld   a, SCREEN_TILES              ;; \ HL += (20 - length) / 2
    sub  b                            ;; |
    srl  a                            ;; |
    add  l                            ;; |
    ld   l, a                         ;; |
    jr   nc, .no_carry                ;; |
    inc  h                            ;; |
.no_carry                             ;; /
    jp   draw_text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The version of a two-language text in the current language.
;; 📥 HL = text (BITEXT: dw spanish, dw english)
;; ⫷▬ DE = the text
;; ❌ Modifies A, HL
text_get::
    ld   a, [language]                ;; \ HL += language * 2
    add  a                            ;; |
    add  l                            ;; |
    ld   l, a                         ;; |
    jr   nc, .no_carry                ;; |
    inc  h                            ;; |
.no_carry                             ;; /
    ld   a, [hl+]                     ;; \ DE = [HL]
    ld   e, a                         ;; |
    ld   d, [hl]                      ;; /
    ret

;; Like draw_text / draw_text_centered, with a two-language text in DE
;; ❌ Modifies A, (B), DE, HL
draw_ltext::
    push hl
    ld   h, d
    ld   l, e
    call text_get
    pop  hl
    jp   draw_text

draw_ltext_centered::
    push hl
    ld   h, d
    ld   l, e
    call text_get
    pop  hl
    jr   draw_text_centered

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Writes a BCD byte as two digits.
;; 📥 A = number in BCD ($00-$99), HL = destination
;; ⫷▬ HL += 2
;; ❌ Modifies A, B, HL
draw_bcd::
    ld   b, a
    swap a                            ;; \ Tens
    and  $0F                          ;; |
    add  TILE_DIGIT_0                 ;; |
    ld   [hl+], a                     ;; /
    ld   a, b                         ;; \ Units
    and  $0F                          ;; /
    ; continues in draw_digit

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 📥 A = digit (0-9), HL = destination
;; ⫷▬ HL += 1
;; ❌ Modifies A, HL
draw_digit::
    add  TILE_DIGIT_0
    ld   [hl+], a
    ret
