;;==============================================================
;; scn/scn_medal.asm -- El medallón ganado, girando
;;
;; Al acabar un nivel con todos los espectros derrotados: un medallón grande
;; (32 x 32 = 8 sprites de 8 x 16) que da 3 vueltas y se para de frente.
;; Sus imágenes (de frente a de canto) se copian sobre las hojas de los
;; personajes, que se vuelven a cargar al empezar la escena siguiente.
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"

DEF MEDAL_MIN_FRAMES   = 40           ;; START does not work before (it can skip the spin)
DEF MEDAL_PHASE_FRAMES = 4            ;; frames of each image
DEF MEDAL_PHASES       = 16           ;; images of a whole turn
DEF MEDAL_TURNS        = 3
DEF MEDAL_OAM_X        = 64 + OAM_X_OFFSET  ;; the 32 x 32 medallion, centred
DEF MEDAL_OAM_Y        = 56 + OAM_Y_OFFSET
DEF IMAGE_PIXELS       = 16
DEF FLIPPED            = $80          ;; in MedalPhases: the image, mirrored
DEF ROW_TILES          = 8            ;; tiles of a row of 16 pixels of an image
DEF IMAGE_TILES        = 16           ;; tiles of an image (32 x 32)
ASSERT (MEDAL_OAM_X & IMAGE_PIXELS) == 0  ;; (medal_row swaps the halves with xor)

SECTION "Medal vars", WRAM0
medal_phase:    ds 1                  ;; 0-15: the image of the turn
medal_tick:     ds 1                  ;; frames of this image
medal_turns:    ds 1                  ;; whole turns done

SECTION "Medal scene", ROM0

;; A turn: front, narrower, edge, the back (mirrored), edge and front again
MedalPhases:
    db 0, 1, 2, 3, 4, 3 | FLIPPED, 2 | FLIPPED, 1 | FLIPPED
    db 0 | FLIPPED, 1 | FLIPPED, 2 | FLIPPED, 3 | FLIPPED, 4, 3, 2, 1
ASSERT @ - MedalPhases == MEDAL_PHASES

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ❌ Modifies A, BC, DE, HL
scn_medal_init::
    ld   hl, MedalSpinTiles           ;; \ The images of the spin, over the characters
    ld   de, VRAM_TILES + MEDAL_SPIN_TILE * 16 ;; |
    ld   bc, MedalSpinTilesEnd - MedalSpinTiles ;; |
    call memcpy16                     ;; |
    call tiles_dirty_set              ;; / (they will be loaded again)
    call screen_clear
    PUTS_C 2, TxtMedal
    SCRN_POS 4, 6                     ;; \ "NIVEL 3"
    ld   de, TxtLevel                 ;; |
    call draw_ltext                   ;; |
    inc  hl                           ;; |
    call level_number_bcd             ;; |
    call draw_level_number            ;; /
    PUTS_C 13, TxtMedalWon
    PUTS_C 16, TxtPressStart
    xor  a
    ld   [medal_phase], a
    ld   [medal_tick], a
    ld   [medal_turns], a
    call medal_draw
    ld   hl, SongVictory
    call music_play
    ld   hl, scn_medal_update
    ld   a, LCDC_NO_WINDOW
    jp   scene_set

scn_medal_update:
    call medal_spin
    call medal_draw
    ld   a, [scene_timer]
    cp   MEDAL_MIN_FRAMES
    ret  c
    call confirm_pressed
    ret  z
    ld   a, SFX_MENU
    call sfx_play
    ld   hl, scn_clear_init
    jp   scene_request

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The next image every MEDAL_PHASE_FRAMES frames, until the turns are done
;; (then it stays on the front). ❌ Modifies A, HL
medal_spin:
    ld   a, [medal_turns]
    cp   MEDAL_TURNS
    ret  nc
    ld   hl, medal_tick
    inc  [hl]
    ld   a, [hl]
    cp   MEDAL_PHASE_FRAMES
    ret  c
    ld   [hl], 0
    ld   a, [medal_phase]
    inc  a
    and  MEDAL_PHASES - 1
    ld   [medal_phase], a
    ret  nz
    ld   hl, medal_turns              ;; Back on the front: one more turn
    inc  [hl]
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The 8 sprites of the medallion, with the image of its phase.
;; ❌ Modifies A, BC, DE, HL
medal_draw:
    call sys_prerender_begin
    ld   a, [medal_phase]             ;; \ A = the image (and FLIPPED)
    ld   hl, MedalPhases              ;; |
    add  l                            ;; |
    ld   l, a                         ;; |
    adc  h                            ;; |
    sub  l                            ;; |
    ld   h, a                         ;; |
    ld   a, [hl]                      ;; /
    ld   e, 0                         ;; \ E = ATTR: mirrored or not
    bit  7, a                         ;; |
    jr   z, .attr                     ;; |
    ld   e, ATTR_XFLIP                ;; |
.attr                                 ;; /
    and  LOW(~FLIPPED)                  ;; \ D = its first tile
    swap a                            ;; | (IMAGE_TILES = 16 per image)
    add  MEDAL_SPIN_TILE              ;; |
    ld   d, a                         ;; /
    ld   b, MEDAL_OAM_Y               ;; \ The top half
    call medal_row                    ;; /
    ld   a, d                         ;; \ The bottom half
    add  ROW_TILES                    ;; |
    ld   d, a                         ;; |
    ld   b, MEDAL_OAM_Y + IMAGE_PIXELS ;; |
    call medal_row                    ;; /
    jp   sys_prerender_end
ASSERT IMAGE_TILES == 16

;; A row of 16 pixels: two 16 x 16 images, swapped if it is mirrored.
;; 📥 B = OAM Y, D = first tile, E = ATTR   ❌ Modifies A, C, HL
medal_row:
    ld   c, MEDAL_OAM_X
    bit  ATTR_XFLIP_BIT, e
    jr   z, .left
    ld   c, MEDAL_OAM_X + IMAGE_PIXELS
.left
    call sys_prerender_image
    ld   a, d
    add  TILES_PER_IMAGE
    ld   d, a
    ld   a, c
    xor  IMAGE_PIXELS
    ld   c, a
    call sys_prerender_image
    ld   a, d
    sub  TILES_PER_IMAGE
    ld   d, a
    ret
