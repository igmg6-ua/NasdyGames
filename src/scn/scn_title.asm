;;==============================================================
;; scn/scn_title.asm -- La portada
;;
;; El logo ondula: la interrupción STAT cambia rSCX en cada línea del logo
;; (engine/interrupts.asm). Abajo, el héroe cruza la pantalla perseguido por
;; un espectro.
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"

DEF LOGO_ROW       = 2                ;; the logo: 2 rows of tiles (lines 16-31)
DEF LOGO_COLUMN    = 1                ;; 9 letters of 2 tiles: columns 1-18
DEF WALK_OAM_Y     = 11 * 8 + OAM_Y_OFFSET ;; the walkers, in rows 11-12
DEF CHASE_DISTANCE = 28               ;; pixels between the hero and the spectre
DEF PRESS_ROW      = 15
DEF BLINK_MASK     = %00011111        ;; "PRESS START" changes every 32 frames
DEF BLINK_BIT      = 5
DEF TITLE_MIN_FRAMES = 20

SECTION "Title vars", WRAM0
title_x:        ds 1                  ;; X (OAM) of the hero who walks

SECTION "Title scene", ROM0

;; The tiles of the logo, letter by letter
LogoLetters:
    db TILE_LOGO_L, TILE_LOGO_A, TILE_LOGO_B, TILE_LOGO_E, TILE_LOGO_R
    db TILE_LOGO_I, TILE_LOGO_N, TILE_LOGO_T, TILE_LOGO_O
DEF LOGO_LETTERS = @ - LogoLetters

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ❌ Modifies A, BC, DE, HL
scn_title_init::
    call screen_clear
    ld   de, LogoLetters              ;; \ The logo: each letter is 2 x 2 tiles,
    SCRN_POS LOGO_ROW, LOGO_COLUMN    ;; | in the order top left, bottom left,
    ld   b, LOGO_LETTERS              ;; | top right, bottom right
.letter                               ;; |
    ld   a, [de]                      ;; | A = the first tile of the letter
    inc  de                           ;; |
    push bc                           ;; |
    ld   bc, TILEMAP_WIDTH            ;; |
    ld   [hl], a                      ;; | top left     (tile)
    inc  a                            ;; |
    push hl                           ;; |
    add  hl, bc                       ;; | (one row down)
    ld   [hl+], a                     ;; | bottom left  (tile + 1)
    add  2                            ;; |
    ld   [hl], a                      ;; | bottom right (tile + 3)
    pop  hl                           ;; |
    inc  hl                           ;; |
    dec  a                            ;; |
    ld   [hl+], a                     ;; | top right    (tile + 2); HL -> next letter
    pop  bc                           ;; |
    dec  b                            ;; |
    jr   nz, .letter                  ;; /
    SCRN_POS 8, 0                     ;; \ The record
    call draw_record                  ;; /
    PUTS_C PRESS_ROW, TxtPressStart
    PUTS_C 17, TxtCredits
    xor  a
    ld   [title_x], a
    ldh  [hWavePhase], a
    call raster_on                    ;; \ The logo waves
    ld   hl, SongTitle                ;; | and the music
    call music_play                   ;; /
    ld   hl, scn_title_update
    ld   a, LCDC_NO_WINDOW
    jp   scene_set

scn_title_update:
    ldh  a, [hWavePhase]              ;; \ The wave moves
    inc  a                            ;; |
    ldh  [hWavePhase], a              ;; /
    call title_walkers
    call title_blink
    ld   a, [scene_timer]
    cp   TITLE_MIN_FRAMES
    ret  c
    call confirm_pressed
    ret  z
    call rng_seed                     ;; Every game different: it depends on when START is pressed
    ld   a, SFX_MENU
    call sfx_play
    ld   hl, scn_setup_init
    jp   scene_request

;; The hero and the spectre cross the screen (sprites without entities)
title_walkers:
    call sys_prerender_begin
    ld   hl, title_x                  ;; \ One pixel more
    inc  [hl]                         ;; |
    ld   c, [hl]                      ;; / C = X of the hero
    ld   a, [frame_counter]           ;; \ E = the step: 0 or 4 tiles
    and  ANIM_STEP_MASK               ;; |
    rrca                              ;; |
    ld   e, a                         ;; /
    ld   a, [gender]                  ;; \ D = the hero, side image, its step
    or   a                            ;; |
    ld   a, TILE_BOY                  ;; |
    jr   z, .sheet                    ;; |
    ld   a, TILE_GIRL                 ;; |
.sheet                                ;; |
    add  2 * SHEET_ROW_TILES          ;; |
    add  e                            ;; |
    ld   d, a                         ;; /
    ld   a, TILE_SPECTRE + 2 * SHEET_ROW_TILES ;; \ The spectre's image, kept in E
    add  e                            ;; |
    ld   e, a                         ;; /
    push de
    ld   b, WALK_OAM_Y                ;; \ The hero
    ld   e, 0                         ;; |
    call sys_prerender_image          ;; /
    pop  de
    ld   d, e                         ;; \ The spectre, behind him
    ld   e, 0                         ;; |
    ld   a, c                         ;; |
    sub  CHASE_DISTANCE               ;; |
    ld   c, a                         ;; |
    call sys_prerender_image          ;; /
    jp   sys_prerender_end

;; "PRESS START" appears and disappears
title_blink:
    ld   a, [frame_counter]
    and  BLINK_MASK
    ret  nz
    ld   a, PRESS_ROW
    call row_begin                    ;; HL = an empty row
    ld   a, [frame_counter]
    bit  BLINK_BIT, a
    jr   z, .commit                   ;; Empty this time
    ld   de, TxtPressStart
    call draw_ltext_centered
.commit
    jp   row_commit
