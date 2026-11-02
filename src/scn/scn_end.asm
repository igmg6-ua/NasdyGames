;;==============================================================
;; scn/scn_end.asm -- La pantalla final: victoria o fin de la partida
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"

DEF END_MIN_FRAMES = 60               ;; 1 second before START works
DEF NUMBER_COLUMN  = 14               ;; where the numbers are written (4 digits)

SECTION "End vars", WRAM0
end_score:      ds 2                  ;; BCD, high byte first

SECTION "End scene", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ❌ Modifies A, BC, DE, HL
scn_end_init::
    call screen_clear
    ld   a, [game_result]             ;; \ The title and the music
    cp   RESULT_VICTORY               ;; |
    jr   nz, .lost                    ;; |
    PUTS_C 2, TxtVictory              ;; |
    PUTS_C 3, TxtWellDone             ;; |
    ld   hl, SongVictory              ;; |
    jr   .song                        ;; |
.lost                                 ;; |
    cp   RESULT_TIMEUP                ;; |
    ld   de, TxtGameOver              ;; |
    jr   nz, .title                   ;; |
    ld   de, TxtTimeUp                ;; |
.title                                ;; |
    SCRN_POS 2, 0                     ;; |
    call draw_ltext_centered          ;; |
    ld   hl, SongGameOver             ;; |
.song                                 ;; |
    call music_play                   ;; /
    SCRN_POS 5, 0                     ;; \ The name
    ld   de, player_name              ;; |
    call draw_text_centered           ;; /

    PUTS 7, 2, TxtCoins               ;; \ Coins
    SCRN_POS 7, NUMBER_COLUMN         ;; | (all the levels: 4 digits)
    ld   a, [total_coins]             ;; |
    call draw_bcd                     ;; |
    ld   a, [total_coins + 1]         ;; |
    call draw_bcd                     ;; /
    PUTS 9, 2, TxtSpectres            ;; \ Spectres defeated
    SCRN_POS 9, NUMBER_COLUMN + 2     ;; |
    ld   a, [kills]                   ;; |
    call draw_bcd                     ;; /
    PUTS 11, 2, TxtBonus              ;; \ Time bonus
    SCRN_POS 11, NUMBER_COLUMN        ;; |
    ld   a, [bonus]                   ;; |
    call draw_bcd                     ;; |
    ld   a, [bonus + 1]               ;; |
    call draw_bcd                     ;; /
    PUTS 13, 2, TxtScore              ;; \ The score
    call game_score                   ;; |
    ld   a, b                         ;; |
    ld   [end_score], a               ;; |
    ld   a, c                         ;; |
    ld   [end_score + 1], a           ;; |
    SCRN_POS 13, NUMBER_COLUMN        ;; |
    ld   a, [end_score]               ;; |
    call draw_bcd                     ;; |
    ld   a, [end_score + 1]           ;; |
    call draw_bcd                     ;; /

    call end_check_record             ;; \ A new record? (carry)
    jr   nc, .old_record              ;; |
    PUTS_C 15, TxtNewRecord           ;; |
    jr   .start                       ;; /
.old_record
    SCRN_POS 15, 0                    ;; \ The record that still stands
    call draw_record                  ;; /
.start
    PUTS_C 17, TxtPressStart
    ld   hl, scn_end_update
    ld   a, LCDC_NO_WINDOW
    jp   scene_set

scn_end_update:
    ld   a, [scene_timer]
    cp   END_MIN_FRAMES
    ret  c
    call confirm_pressed
    ret  z
    ld   a, SFX_MENU
    call sfx_play
    ld   hl, scn_title_init
    jp   scene_request

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; If end_score beats the record, it is the new record (with the name) and it
;; is saved in the cartridge.
;; ⫷▬ carry: new record
;; ❌ Modifies A, BC, DE, HL
end_check_record:
    ld   a, [best_score]              ;; \ Compare the high bytes
    ld   b, a                         ;; |
    ld   a, [end_score]               ;; |
    cp   b                            ;; |
    jr   c, .no                       ;; | lower: no
    jr   nz, .yes                     ;; / higher: yes
    ld   a, [best_score + 1]          ;; \ The same: compare the low bytes
    ld   b, a                         ;; |
    ld   a, [end_score + 1]           ;; |
    cp   b                            ;; |
    jr   c, .no                       ;; |
    jr   z, .no                       ;; / the same score is not a new record
.yes
    ld   a, [end_score]               ;; \ Copy the score and the name
    ld   [best_score], a              ;; |
    ld   a, [end_score + 1]           ;; |
    ld   [best_score + 1], a          ;; |
    ld   hl, player_name              ;; |
    ld   de, best_name                ;; |
    ld   b, NAME_SIZE                 ;; |
    call memcpy8                      ;; /
    call save_store                   ;; Save it
    ld   a, SFX_LIFE
    call sfx_play
    scf
    ret
.no
    and  a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Writes "RECORD 0000 NAME", centred (title and end screens). It is built
;; in row_buffer (free while the screen is off) and then centred.
;; 📥 HL = the start of the row
;; ⚠️ The screen must be OFF
;; ❌ Modifies A, B, DE, HL
draw_record::
    push hl
    ld   hl, row_buffer
    ld   de, TxtRecord
    call draw_ltext
    ld   [hl], TILE_BLANK
    inc  hl
    ld   a, [best_score]
    call draw_bcd
    ld   a, [best_score + 1]
    call draw_bcd
    ld   [hl], TILE_BLANK
    inc  hl
    ld   de, best_name
    call draw_text
    ld   [hl], TEXT_END
    pop  hl
    ld   de, row_buffer
    jp   draw_text_centered
