;;==============================================================
;; scn/scn_clear.asm -- El resumen de un nivel superado
;;
;; Tiempo que ha tardado, su récord en ese nivel (guardado en el cartucho),
;; espectros derrotados, monedas, bonus y si ha ganado el medallón.
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"

DEF CLEAR_MIN_FRAMES = 40             ;; 2/3 s before START works
DEF LABEL_COLUMN     = 2
DEF VALUE_COLUMN     = 13             ;; the values: columns 13-18
DEF CHAR_COLON       = ":" - ASCII_TILE_OFFSET
DEF CHAR_DASH        = "-" - ASCII_TILE_OFFSET
DEF NO_TIME          = $FF            ;; level_best of a level not finished yet

SECTION "Clear vars", WRAM0
clear_record:   ds 1                  ;; 1: this time is a new record

SECTION "Clear scene", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ❌ Modifies A, BC, DE, HL
scn_clear_init::
    call end_level_save               ;; Record and medallion, to the cartridge
    call screen_clear
    SCRN_POS 1, 1                     ;; \ "NIVEL 3 SUPERADO!"
    ld   de, TxtLevel                 ;; |
    call draw_ltext                   ;; |
    inc  hl                           ;; |
    call level_number_bcd             ;; |
    call draw_level_number            ;; |
    inc  hl                           ;; |
    ld   de, TxtCleared               ;; |
    call draw_ltext                   ;; /

    PUTS 3, LABEL_COLUMN, TxtTime     ;; \ The time it took
    SCRN_POS 3, VALUE_COLUMN          ;; |
    ld   a, [elapsed_mm]              ;; |
    ld   d, a                         ;; |
    ld   a, [elapsed_ss]              ;; |
    ld   e, a                         ;; |
    call draw_time                    ;; /
    ld   a, [clear_record]            ;; \ New record, or the record
    or   a                            ;; |
    jr   z, .old_record               ;; |
    PUTS_C 5, TxtNewRecord            ;; |
    jr   .spectres                    ;; |
.old_record                           ;; |
    PUTS 5, LABEL_COLUMN, TxtRecord   ;; |
    SCRN_POS 5, VALUE_COLUMN          ;; |
    call level_best_get               ;; |
    call draw_time                    ;; /
.spectres
    PUTS 7, LABEL_COLUMN, TxtSpectres ;; \ Spectres: defeated / all
    SCRN_POS 7, VALUE_COLUMN          ;; |
    ld   a, [enemies_left]            ;; |
    ld   b, a                         ;; |
    ld   a, [level_enemies]           ;; |
    ld   c, a                         ;; |
    sub  b                            ;; |
    call draw_digit                   ;; |
    ld   [hl], TILE_CHAR_SLASH        ;; |
    inc  hl                           ;; |
    ld   a, c                         ;; |
    call draw_digit                   ;; /
    PUTS 9, LABEL_COLUMN, TxtCoins   ;; \ Coins of this level
    SCRN_POS 9, VALUE_COLUMN         ;; |
    ld   a, [coins]                   ;; |
    call draw_bcd                     ;; /
    PUTS 11, LABEL_COLUMN, TxtBonus   ;; \ Seconds left: the bonus
    SCRN_POS 11, VALUE_COLUMN         ;; |
    ld   [hl], TILE_CHAR_PLUS         ;; |
    inc  hl                           ;; |
    ld   a, [level_bonus]             ;; |
    and  $0F                          ;; |
    call draw_digit                   ;; |
    ld   a, [level_bonus + 1]         ;; |
    call draw_bcd                     ;; /

    ld   a, [level_medal]             ;; \ The medallion: yes or no, with its picture
    or   a                            ;; |
    ld   a, TILE_MEDAL_LOCKED         ;; |
    jr   z, .medal_tile               ;; |
    ld   a, TILE_MEDAL                ;; |
.medal_tile                           ;; |
    SCRN_POS 13, LABEL_COLUMN         ;; |
    call draw_image16                 ;; |
    PUTS 14, LABEL_COLUMN + 3, TxtMedal ;; |
    ld   a, [level_medal]             ;; |
    or   a                            ;; |
    ld   de, TxtNo                    ;; |
    jr   z, .medal_text               ;; |
    ld   de, TxtYes                   ;; |
.medal_text                           ;; |
    SCRN_POS 14, VALUE_COLUMN + 2     ;; |
    call draw_ltext                   ;; /

    PUTS_C 16, TxtPressStart
    ld   hl, scn_clear_update
    ld   a, LCDC_NO_WINDOW
    jp   scene_set

scn_clear_update:
    ld   a, [scene_timer]
    cp   CLEAR_MIN_FRAMES
    ret  c
    call confirm_pressed
    ret  z
    ld   a, SFX_MENU
    call sfx_play
    jp   game_after_summary

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; At the end of a level: is its time a new record? And the medallion, if it
;; was won. Both are saved in the cartridge.
;; ❌ Modifies A, BC, DE, HL
end_level_save:
    xor  a
    ld   [clear_record], a
    call level_best_address           ;; HL = &level_best[level] (minutes, seconds)
    ld   a, [hl]                      ;; \ No time yet: this one is the record
    cp   NO_TIME                      ;; |
    jr   z, .record                   ;; /
    ld   a, [elapsed_mm]              ;; \ Fewer minutes: record
    cp   [hl]                         ;; |
    jr   c, .record                   ;; |
    jr   nz, .medal                   ;; / more minutes: no
    inc  hl                           ;; \ The same minutes: fewer seconds?
    ld   a, [elapsed_ss]              ;; |
    cp   [hl]                         ;; |
    dec  hl                           ;; |
    jr   nc, .medal                   ;; /
.record
    ld   a, [elapsed_mm]              ;; \ The new record
    ld   [hl+], a                     ;; |
    ld   a, [elapsed_ss]              ;; |
    ld   [hl], a                      ;; |
    ld   a, 1                         ;; |
    ld   [clear_record], a            ;; /
.medal
    ld   a, [level_medal]             ;; \ The medallion
    or   a                            ;; |
    jr   z, .save                     ;; |
    ld   a, [current_level]           ;; |
    call medal_mask                   ;; |
    or   [hl]                         ;; |
    ld   [hl], a                      ;; /
.save
    jp   save_store

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ⫷▬ HL = &level_best[current_level]   ❌ Modifies A, HL
level_best_address:
    ld   a, [current_level]
    add  a
    add  LOW(level_best)
    ld   l, a
    ld   a, HIGH(level_best)
    adc  0
    ld   h, a
    ret

;; ⫷▬ D = minutes, E = seconds of the record of the current level
;; ❌ Modifies A, DE
level_best_get::
    push hl
    call level_best_address
    ld   a, [hl+]
    ld   d, a
    ld   e, [hl]
    pop  hl
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The bit of the medallion of a level, in the 16 bits of medals.
;; 📥 A = level (0 ..)
;; ⫷▬ HL = the byte of medals where it is, A = its bit (a mask)
;; ❌ Modifies A, B, HL
medal_mask::
    ld   hl, medals
    cp   8                            ;; \ Levels 8 and more: the second byte
    jr   c, .byte                     ;; |
    inc  hl                           ;; |
    sub  8                            ;; /
.byte
    ld   b, a                         ;; \ A = 1 << B
    ld   a, 1                         ;; |
    inc  b                            ;; |
.shift                                ;; |
    dec  b                            ;; |
    ret  z                            ;; |
    add  a                            ;; |
    jr   .shift                       ;; /

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Writes a time as M:SS or MM:SS, or --:-- if there is none.
;; 📥 HL = where, D = minutes, E = seconds (BCD; D = NO_TIME: no time)
;; ⫷▬ HL = after it
;; ❌ Modifies A, B, HL
draw_time::
    ld   a, d
    cp   NO_TIME
    jr   z, .none
    cp   $10                          ;; \ Minutes: 1 or 2 digits
    jr   c, .one                      ;; |
    call draw_bcd                     ;; |
    jr   .colon                       ;; |
.one                                  ;; |
    call draw_digit                   ;; /
.colon
    ld   [hl], CHAR_COLON
    inc  hl
    ld   a, e
    jp   draw_bcd
.none
    ld   a, CHAR_DASH
    ld   [hl+], a
    ld   [hl+], a
    ld   [hl], CHAR_COLON
    inc  hl
    ld   [hl+], a
    ld   [hl+], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Writes the number of a level: 1 digit (1-9) or 2 (10).
;; 📥 A = the number (BCD), HL = where   ❌ Modifies A, B, HL
draw_level_number::
    cp   $10
    jp   c, draw_digit
    jp   draw_bcd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Writes a 16 x 16 image of the background (2 x 2 tiles, in the order of the
;; sprites: top left, bottom left, top right, bottom right).
;; 📥 A = its first tile, HL = where (top left)
;; ⚠️ The screen must be OFF
;; ❌ Modifies A, BC, HL
draw_image16::
    ld   bc, TILEMAP_WIDTH
    ld   [hl], a                      ;; top left
    inc  a
    push hl
    add  hl, bc
    ld   [hl+], a                     ;; bottom left
    add  2
    ld   [hl], a                      ;; bottom right
    pop  hl
    inc  hl
    dec  a
    ld   [hl], a                      ;; top right
    ret
