;;==============================================================
;; scn/scn_game.asm -- La escena del juego: el bucle de los sistemas
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"
INCLUDE "engine/ui/hud.inc"

SECTION "Game scene vars", WRAM0
paused:         ds 1
ending_timer:   ds 1                  ;; frames left before the next screen (0: playing)

SECTION "Game scene", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start of the scene: the current level. ❌ Modifies A, BC, DE, HL
scn_game_init::
    xor  a
    ld   [paused], a
    ld   [ending_timer], a
    call game_level_start
    ld   hl, scn_game_update
    ld   a, LCDC_VALUE                ;; (with the window: the HUD)
    jp   scene_set

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; One frame of the game. The order matters:
;;   input and AI decide -> physics moves -> animation chooses the image ->
;;   the rules (what touches what, coins, time) -> camera -> sprites.
;; ❌ Modifies A, BC, DE, HL
scn_game_update:
    ld   a, [ending_timer]            ;; \ The level has ended: wait a moment
    or   a                            ;; |
    jr   nz, .ending                  ;; /

    ld   a, [input_pressed]           ;; \ START: pause / go on
    bit  BTN_START_BIT, a             ;; |
    call nz, game_toggle_pause        ;; /
    ld   a, [paused]
    or   a
    ret  nz

    call sys_input_update
    call sys_ai_update
    call sys_physics_update
    call sys_animation_update
    call sys_selfdestroy_update
    call game_collisions
    call game_coins
    call game_hurt_update
    call game_time_update

    ld   a, [game_result]             ;; \ Has the level just ended?
    or   a                            ;; |
    call nz, game_ending_start        ;; /
.draw
    ld   de, PLAYER_ENTITY
    call sys_camera_update
    jp   sys_prerender_update

.ending
    dec  a                            ;; \ Still waiting: only the animations
    ld   [ending_timer], a            ;; |
    jr   z, game_next_scene           ;; |
    call sys_animation_update         ;; |
    call sys_selfdestroy_update       ;; |
    jr   .draw                        ;; /

;; The level has ended: everything stops, and a jingle sounds.
game_ending_start:
    ld   a, ENDING_FRAMES
    ld   [ending_timer], a
    ld   hl, PLAYER_ENTITY + E_ATTR   ;; \ The hero, with his normal palette
    res  ATTR_PALETTE_BIT, [hl]       ;; /
    ld   a, [game_result]
    cp   RESULT_CLEAR
    ld   hl, SongClear
    jr   z, .song
    ld   hl, SongGameOver
.song
    jp   music_play

;; After the moment of waiting: the next screen.
game_next_scene:
    ld   a, [game_result]
    cp   RESULT_CLEAR
    jr   nz, .the_end                 ;; dead or no time: the end
    ld   a, [current_level]           ;; \ The next level...
    inc  a                            ;; |
    ld   [current_level], a           ;; |
    cp   NUM_LEVELS                   ;; |
    ld   hl, scn_level_init           ;; |
    jp   c, scene_request             ;; /
    ld   a, RESULT_VICTORY            ;; \ ...or there is none: victory
    ld   [game_result], a             ;; /
.the_end
    ld   hl, scn_end_init
    jp   scene_request

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Pause: the HUD says it, the music is silent and nothing moves.
;; ❌ Modifies A, BC, DE, HL
game_toggle_pause:
    ld   a, [paused]
    xor  1
    ld   [paused], a
    ld   [music_pause], a
    jp   z, hud_refresh               ;; Go on: the normal HUD
    ld   hl, hud_buffer               ;; \ Paused: the HUD says it
    ld   a, TILE_BLANK                ;; |
    ld   b, HUD_CELLS                 ;; |
    call memset8                      ;; |
    ld   hl, hud_buffer               ;; |
    ld   de, TxtPause                 ;; |
    call draw_ltext_centered          ;; |
    call hud_mark                     ;; /
    ld   a, SFX_MENU
    jp   sfx_play
