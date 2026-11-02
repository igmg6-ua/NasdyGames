;;==============================================================
;; scn/scn_medals.asm -- La galería de medallones (desde el menú)
;;
;; Los 10 medallones en 2 filas de 5, con el número de su nivel debajo: los
;; ganados se ven y los que faltan, en silueta.
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"

DEF MEDALS_PER_ROW   = 5
DEF FIRST_MEDAL_ROW  = 3              ;; rows 3-4 (and the number in 6)
DEF SECOND_MEDAL_ROW = 9              ;; rows 9-10 (and 12)
DEF FIRST_MEDAL_COL  = 1              ;; columns 1, 5, 9, 13, 17
DEF MEDAL_COL_STEP   = 4
DEF COUNT_ROW        = 15
DEF COUNT_COL        = 8
ASSERT MEDAL_COL_STEP == 4            ;; (medal_cell multiplies by 4)
ASSERT NUM_LEVELS <= 2 * MEDALS_PER_ROW

SECTION "Medals scene", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ❌ Modifies A, BC, DE, HL
scn_medals_init::
    call screen_clear
    PUTS_C 1, TxtMedals
    ld   c, 0                         ;; C = the level
.medal
    push bc
    ld   a, c                         ;; \ D = its tile: won or a silhouette
    call medal_mask                   ;; |
    and  [hl]                         ;; |
    ld   d, TILE_MEDAL_LOCKED         ;; |
    jr   z, .tile                     ;; |
    ld   d, TILE_MEDAL                ;; |
.tile                                 ;; /
    pop  bc
    push bc
    call medal_cell                   ;; \ The medallion
    push hl                           ;; |
    ld   a, d                         ;; |
    call draw_image16                 ;; |
    pop  hl                           ;; /
    ld   de, 3 * TILEMAP_WIDTH        ;; \ Its level, below (2 digits: under the 2 tiles)
    add  hl, de                       ;; |
    pop  bc                           ;; |
    push bc                           ;; |
    ld   a, c                         ;; |
    call level_to_bcd                 ;; |
    call draw_bcd                     ;; /
    pop  bc
    inc  c
    ld   a, c
    cp   NUM_LEVELS
    jr   nz, .medal

    ld   c, 0                         ;; \ E = how many have been won
    ld   e, 0                         ;; |
.count                                ;; |
    ld   a, c                         ;; |
    call medal_mask                   ;; |
    and  [hl]                         ;; |
    jr   z, .not_won                  ;; |
    inc  e                            ;; |
.not_won                              ;; |
    inc  c                            ;; |
    ld   a, c                         ;; |
    cp   NUM_LEVELS                   ;; |
    jr   nz, .count                   ;; /
    SCRN_POS COUNT_ROW, COUNT_COL     ;; \ "7/10"
    ld   a, e                         ;; |
    dec  a                            ;; | (level_to_bcd adds 1)
    call level_to_bcd                 ;; |
    call draw_level_number            ;; |
    ld   [hl], TILE_CHAR_SLASH        ;; |
    inc  hl                           ;; |
    ld   a, NUM_LEVELS - 1            ;; |
    call level_to_bcd                 ;; |
    call draw_level_number            ;; /
    PUTS_C 17, TxtBack
    ld   hl, scn_medals_update
    ld   a, LCDC_NO_WINDOW
    jp   scene_set

scn_medals_update:
    ld   a, [input_pressed]
    and  BTN_START | BTN_A | BTN_B
    ret  z
    ld   a, SFX_MENU
    call sfx_play
    ld   hl, scn_setup_init
    jp   scene_request

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 📥 C = level (0-9)   ⫷▬ HL = the top left of its medallion
;; ❌ Modifies A, HL
medal_cell:
    ld   hl, TILEMAP + FIRST_MEDAL_ROW * TILEMAP_WIDTH + FIRST_MEDAL_COL
    ld   a, c
    cp   MEDALS_PER_ROW
    jr   c, .row
    sub  MEDALS_PER_ROW
    ld   hl, TILEMAP + SECOND_MEDAL_ROW * TILEMAP_WIDTH + FIRST_MEDAL_COL
.row
    add  a                            ;; \ HL += column * MEDAL_COL_STEP
    add  a                            ;; |
    add  l                            ;; |
    ld   l, a                         ;; |
    adc  h                            ;; |
    sub  l                            ;; |
    ld   h, a                         ;; /
    ret

;; 📥 A = level (0-9; -1 for 0)   ⫷▬ A = level + 1 in BCD   ❌ Modifies A
level_to_bcd:
    inc  a
    cp   10
    ret  c
    add  6                            ;; 10 -> $10
    ret
