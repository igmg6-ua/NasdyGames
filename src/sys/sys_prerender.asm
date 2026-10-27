;;==============================================================
;; sys/sys_prerender.asm -- Preparar los sprites en la shadow OAM (Challenge 6)
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/ui/hud.inc"

SECTION "Prerender vars", WRAM0
shadow_cursor:: ds 1                  ;; low byte of the next free sprite of shadow_oam

SECTION "Prerender", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Changes a position from WORLD coordinates to OAM coordinates:
;;    OAM = world - camera + offset   (offset: OAM_Y_OFFSET for Y, OAM_X_OFFSET for X)
;; All in 8 bits: if the position is outside the screen, the result wraps around to
;; values that the console does not draw (Y >= 160 or X >= 168).
;; 📥 D = world Y, E = world X
;; ⫷▬ B = OAM Y, C = OAM X
;; ❌ Modifies A, BC. Does NOT modify DE or HL
;; ⚠️ Use sys_camera_get
world_to_oam::
    call sys_camera_get               ;; B = camera Y, C = camera X (DE and HL do not change)

    ld   a, d                         ;; \ B = OAM Y = world Y - camera Y + OAM_Y_OFFSET
    sub  b                            ;; |
    add  OAM_Y_OFFSET                 ;; |
    ld   b, a                         ;; /

    ld   a, e                         ;; \ C = OAM X = world X - camera X + OAM_X_OFFSET
    sub  c                            ;; |
    add  OAM_X_OFFSET                 ;; |
    ld   c, a                         ;; /

    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Prepares ONE entity to be drawn. Its image is 16 x 16 pixels, drawn with 2
;; sprites of 8 x 16 (each one shows two tiles, one above the other):
;;      sprite 0: the left half, its tile is entity.TILE
;;      sprite 1: the right half, 8 pixels to the right, its tile is entity.TILE + 2
;; If the image is mirrored (ATTR_XFLIP), each half is mirrored and they swap sides.
;; ⚠️ Precondition: the entity has CMP_SPRITE.
;; 📥 DE: entity
;; ❌ May modify A, BC, DE, HL
sys_prerender_one::
    ld   h, d                         ;; \ HL = &entity.Y
    ld   a, e                         ;; |
    add  E_Y                          ;; |
    ld   l, a                         ;; /

    ld   a, [hl+]                     ;; \ D = entity.Y (HL -> X)
    ld   d, a                         ;; /
    ld   e, [hl]                      ;; E = entity.X
    call world_to_oam                 ;; B = OAM Y, C = OAM X of the left half

    ld   a, b                         ;; \ Does its bottom (OAM Y) reach the HUD, or
    cp   HUD_WINDOW_Y + 1             ;; | is it below the screen (the Y wrapped around)?
    ret  nc                           ;; / Yes: not drawn

    inc  l                            ;; \ D = entity.TILE
    ld   d, [hl]                      ;; /
    inc  l                            ;; \ E = entity.ATTR
    ld   e, [hl]                      ;; /
    ; continues in sys_prerender_image
    ;; (In the Challenge 6 the two sprites were written here. They are in their
    ;;  own routine because the menus also draw 16 x 16 images without entities.)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Writes a 16 x 16 image (2 sprites of 8 x 16) in the next free sprites.
;; 📥 B = OAM Y, C = OAM X, D = first tile, E = ATTR
;; ❌ Modifies A, HL
sys_prerender_image::
    ld   h, HIGH(shadow_oam)          ;; \ HL = where to write: the shadow OAM + the cursor
    ld   a, [shadow_cursor]           ;; |
    ld   l, a                         ;; /
    cp   OAM_SIZE                     ;; \ No sprites left? (never with 12 entities)
    ret  nc                           ;; /

    ld   a, b                         ;; \ Sprite 0: the left half
    ld   [hl+], a                     ;; | Y
    ld   a, c                         ;; | X: normally on the left; mirrored, on the right
    bit  ATTR_XFLIP_BIT, e            ;; |
    jr   z, .left                     ;; |
    add  SPRITE_WIDTH                 ;; |
.left
    ld   [hl+], a                     ;; |
    ld   a, d                         ;; | TILE
    ld   [hl+], a                     ;; |
    ld   a, e                         ;; | ATTR
    ld   [hl+], a                     ;; /

    ld   a, b                         ;; \ Sprite 1: the right half
    ld   [hl+], a                     ;; | Y
    ld   a, c                         ;; | X: normally on the right; mirrored, on the left
    bit  ATTR_XFLIP_BIT, e            ;; |
    jr   nz, .right                   ;; |
    add  SPRITE_WIDTH                 ;; |
.right
    ld   [hl+], a                     ;; |
    ld   a, d                         ;; | TILE + TILES_PER_SPRITE (the right half)
    add  TILES_PER_SPRITE             ;; |
    ld   [hl+], a                     ;; |
    ld   a, e                         ;; | ATTR
    ld   [hl+], a                     ;; /

    ld   a, l                         ;; \ shadow_cursor = the next free sprite
    ld   [shadow_cursor], a           ;; /

    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Prepares all the sprites of a frame: the entities with CMP_SPRITE, and the
;; sprites that are left are hidden (Y = 0).
;; ❌ Modifies A, BC, DE, HL
sys_prerender_update::
    call sys_prerender_begin
    ld   b, CMP_SPRITE
    ld   hl, sys_prerender_one
    call man_entity_forall_matching
    ; continues in sys_prerender_end

;; Hides the sprites that have not been used in this frame. ❌ Modifies A, HL
sys_prerender_end::
    ld   h, HIGH(shadow_oam)
    ld   a, [shadow_cursor]
    ld   l, a
.hide
    cp   OAM_SIZE
    ret  nc
    ld   [hl], 0                      ;; Y = 0: out of the screen
    add  4
    ld   l, a
    jr   .hide

;; A new frame of sprites: from the first one. ❌ Modifies A
sys_prerender_begin::
    xor  a
    ld   [shadow_cursor], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; No sprites at all: the shadow OAM and the OAM empty.
;; ⚠️ The screen must be OFF (the OAM is written directly)
;; ❌ Modifies A, B, HL
oam_clear::
    ld   hl, shadow_oam
    ld   b, OAM_SIZE
    xor  a
    call memset8
    ld   hl, OAM_START
    ld   b, OAM_SIZE
    jp   memset8
