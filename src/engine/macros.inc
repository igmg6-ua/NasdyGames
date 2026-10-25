;;==============================================================
;; Macros y constantes comunes
;;==============================================================
IF !DEF(MACROS_INC)
DEF MACROS_INC = 1

INCLUDE "engine/hardware.inc"

DEF TEXT_END     = $FF        ;; end of a text
DEF SCREEN_TILES = 20         ;; width of the screen in tiles
DEF NAME_SIZE    = 9          ;; a name: 8 letters + TEXT_END

;; HL = address of the background tilemap at (row, column)
MACRO SCRN_POS      ;; \1 = row, \2 = column
    ld   hl, TILEMAP + (\1) * TILEMAP_WIDTH + (\2)
ENDM

;; Writes a two-language text at (row, column)
MACRO PUTS          ;; \1 = row, \2 = column, \3 = text (BITEXT)
    SCRN_POS \1, \2
    ld   de, \3
    call draw_ltext
ENDM

;; Writes a two-language text centred in a row
MACRO PUTS_C        ;; \1 = row, \2 = text (BITEXT)
    SCRN_POS \1, 0
    ld   de, \2
    call draw_ltext_centered
ENDM

;; A text in Spanish and in English. The label points to two pointers
;; (dw spanish, dw english) that text_get reads.
MACRO BITEXT        ;; \1 = label, \2 = spanish, \3 = english
\1::
    dw \1_es, \1_en
\1_es: db \2, TEXT_END
\1_en: db \3, TEXT_END
ENDM

;; HL = &entity.FIELD, with DE = entity (same page: only the low byte changes)
MACRO FIELD_HL      ;; \1 = field (E_...)
    ld   h, d
    ld   a, e
    add  \1
    ld   l, a
ENDM

ENDC
