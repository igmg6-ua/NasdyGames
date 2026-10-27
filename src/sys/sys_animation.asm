;;==============================================================
;; sys/sys_animation.asm -- La imagen de cada entidad (Challenge 6)
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/hardware.inc"

SECTION "Animation", ROM0

;; For each direction: the first tile of its row in the sheet, and its flip.
;; The sheets have 3 rows: down, up and side (looking right). Left = side, mirrored.
DirImage:
    db 0,                   0         ;; DIR_DOWN
    db SHEET_ROW_TILES,     0         ;; DIR_UP
    db 2 * SHEET_ROW_TILES, ATTR_XFLIP ;; DIR_LEFT
    db 2 * SHEET_ROW_TILES, 0         ;; DIR_RIGHT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Animation system, for ONE entity. The image it shows is:
;;      TILE = SHEET + the row of its direction + the image of its step
;; and ATTR gets the flip of its direction. TICK counts the frames it has been walking;
;; its step changes every 8 frames, so it alternates between its 2 images.
;; An entity with PHYSICS only animates while it moves (VY or VX not 0): when it
;; stands still, it shows the first image. The others (a portal) always animate.
;; ⚠️ Precondition: the entity has CMP_ANIMATION.
;; 📥 DE = entity
;; ❌ Modifies A, BC, HL
sys_animation_one::
    ld   a, [de]                      ;; \ A = entity.CMP
    and  CMP_PHYSICS                  ;; | Does it have PHYSICS?
    jr   z, .tick                     ;; / No: it always animates

    ld   h, d                         ;; \ A = VY | VX: it is 0 only if it is standing still
    ld   a, e                         ;; | (HL = &entity.VY: same page as the entity,
    add  E_VY                         ;; | the offset added to the low byte)
    ld   l, a                         ;; |
    ld   a, [hl+]                     ;; |
    or   [hl]                         ;; /
    jr   nz, .tick                    ;; Moving: it animates

    ld   h, d                         ;; \ Standing still: TICK = 0, the first image
    ld   a, e                         ;; | (HL = &entity.TICK)
    add  E_TICK                       ;; |
    ld   l, a                         ;; |
    ld   [hl], 0                      ;; |
    jr   .image                       ;; /

.tick
    ld   h, d                         ;; \ One more frame walking:
    ld   a, e                         ;; | entity.TICK++
    add  E_TICK                       ;; | (HL = &entity.TICK)
    ld   l, a                         ;; |
    inc  [hl]                         ;; /

.image
    ld   a, [hl]                      ;; \ A = TICK
    and  ANIM_STEP_MASK               ;; | Bit 3 of TICK: 0 for 8 frames, 8 for the next 8...
    rrca                              ;; | / 2: 0 or 4 (TILES_PER_IMAGE): its step
    ld   b, a                         ;; / B = the tile offset of its step (0 or 4)

    ld   h, d                         ;; \ A = entity.DIR
    ld   a, e                         ;; |
    add  E_DIR                        ;; |
    ld   l, a                         ;; |
    ld   a, [hl]                      ;; /
    add  a                            ;; \ BC = DIR * 2: the offset in the table
    ld   c, a                         ;; | (B moves to A for a moment)
    ld   a, b                         ;; | A = the offset of the step
    ld   b, 0                         ;; /
    ld   hl, DirImage                 ;; \ HL = &DirImage[DIR]
    add  hl, bc                       ;; /

    add  [hl]                         ;; \ A = step offset + tile of the row of its direction
    inc  hl                           ;; | (HL -> the flip)
    ld   b, [hl]                      ;; / B = the flip of its direction
    ld   c, a                         ;; C = that tile (A is needed to build the addresses)

    ld   h, d                         ;; \ HL = &entity.SHEET
    ld   a, e                         ;; |
    add  E_SHEET                      ;; |
    ld   l, a                         ;; /
    ld   a, c                         ;; \ C = the tile of the image:
    add  [hl]                         ;; | that tile + entity.SHEET
    ld   c, a                         ;; /

    ld   h, d                         ;; \ HL = &entity.TILE
    ld   a, e                         ;; |
    add  E_TILE                       ;; |
    ld   l, a                         ;; /
    ld   [hl], c                      ;; \ entity.TILE = C
    inc  l                            ;; / (HL -> ATTR: the next field)

    ld   a, [hl]                      ;; \ entity.ATTR = its ATTR with the flip of
    res  ATTR_XFLIP_BIT, a            ;; | its direction (the other bits stay)
    or   b                            ;; |
    ld   [hl], a                      ;; /

    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Animation system: all the entities with CMP_ANIMATION. ❌ Modifies A, BC, DE, HL
sys_animation_update::
    ld   b, CMP_ANIMATION
    ld   hl, sys_animation_one
    jp   man_entity_forall_matching
