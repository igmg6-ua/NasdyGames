;;==============================================================
;; scn/scn_level.asm -- La pantalla antes de cada nivel
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"

DEF LEVEL_AUTO_FRAMES = 240           ;; it goes on by itself after 4 seconds
DEF LEVEL_MIN_FRAMES  = 20            ;; and not before 1/3 s (a button held does not skip it)

SECTION "Level scene", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ❌ Modifies A, BC, DE, HL
scn_level_init::
    call music_stop
    call screen_clear
    SCRN_POS 3, 6                     ;; \ "NIVEL 2"
    ld   de, TxtLevel                 ;; |
    call draw_ltext                   ;; |
    inc  hl                           ;; |
    ld   a, [current_level]           ;; |
    inc  a                            ;; |
    call draw_digit                   ;; /
    PUTS_C 6, TxtGoodLuck             ;; \ "SUERTE," and the name
    SCRN_POS 7, 0                     ;; |
    ld   de, player_name              ;; |
    call draw_text_centered           ;; /
    PUTS_C 9, TxtGoal

    SCRN_POS 11, 4                    ;; \ The hearts...
    ld   a, [hearts]                  ;; |
    ld   c, a                         ;; |
    ld   b, HEARTS_MAX                ;; |
.heart                                ;; |
    ld   a, c                         ;; |
    or   a                            ;; |
    ld   a, TILE_HEART_EMPTY          ;; |
    jr   z, .put                      ;; |
    ld   a, TILE_HEART_FULL           ;; |
    dec  c                            ;; |
.put                                  ;; |
    ld   [hl+], a                     ;; |
    dec  b                            ;; |
    jr   nz, .heart                   ;; /
    inc  hl                           ;; \ ...and the coins
    inc  hl                           ;; |
    ld   [hl], TILE_COIN              ;; |
    inc  hl                           ;; |
    ld   [hl], TILE_CHAR_X            ;; |
    inc  hl                           ;; |
    ld   a, [coins]                   ;; |
    call draw_bcd                     ;; /

    ld   a, [current_level]           ;; \ After a level: its time bonus
    or   a                            ;; |
    jr   z, .help                     ;; |
    SCRN_POS 13, 6                    ;; |
    ld   de, TxtBonus                 ;; |
    call draw_ltext                   ;; |
    inc  hl                           ;; |
    ld   [hl], TILE_CHAR_PLUS         ;; |
    inc  hl                           ;; |
    ld   a, [level_bonus]             ;; |
    and  $0F                          ;; |
    call draw_digit                   ;; |
    ld   a, [level_bonus + 1]         ;; |
    call draw_bcd                     ;; |
    jr   .start                       ;; /
.help
    PUTS_C 13, TxtShoot               ;; \ Before the first one: the buttons
    PUTS_C 14, TxtPauseHelp           ;; /
.start
    PUTS_C 16, TxtPressStart
    ld   hl, scn_level_update
    ld   a, LCDC_NO_WINDOW
    jp   scene_set

scn_level_update:
    ld   a, [scene_timer]
    cp   LEVEL_MIN_FRAMES
    ret  c
    cp   LEVEL_AUTO_FRAMES
    jr   nc, .go
    call confirm_pressed
    ret  z
.go
    ld   a, SFX_MENU
    call sfx_play
    ld   hl, scn_game_init
    jp   scene_request
