;;==============================================================
;; scn/scn_level.asm -- La pantalla antes de cada nivel
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"
INCLUDE "assets/levels/levels.inc"

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
    call level_number_bcd             ;; |
    call draw_level_number            ;; /
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
    inc  hl                           ;; \ ...and the time of this level
    inc  hl                           ;; |
    ld   [hl], TILE_ICON_CLOCK        ;; |
    inc  hl                           ;; |
    push hl                           ;; |
    call level_get                    ;; |
    ld   de, LVL_TIME                 ;; |
    add  hl, de                       ;; |
    ld   a, [hl+]                     ;; |
    ld   e, [hl]                      ;; |
    pop  hl                           ;; |
    and  $0F                          ;; |
    call draw_digit                   ;; |
    ld   a, e                         ;; |
    call draw_bcd                     ;; /

    SCRN_POS 13, 3                    ;; \ The best time of this level
    ld   de, TxtRecord                ;; |
    call draw_ltext                   ;; |
    inc  hl                           ;; |
    call level_best_get               ;; | D = minutes, E = seconds
    call draw_time                    ;; /

    ld   a, [current_level]           ;; \ Before the first level: the buttons
    or   a                            ;; |
    jr   nz, .not_first               ;; |
    PUTS_C 15, TxtShoot               ;; |
    jr   .start                       ;; /
.not_first
    cp   PICKUPS_LEVEL                ;; \ The first level with a shield and a heart
    jr   nz, .start                   ;; |
    PUTS_C 15, TxtPickups             ;; /
.start
    PUTS_C 17, TxtPressStart
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
