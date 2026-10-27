;;==============================================================
;; sys/sys_render.asm -- Todo lo que se escribe en la VRAM, en el VBLANK
;;
;; El VBLANK dura 1140 ciclos (10 líneas). Por orden de urgencia:
;;   1. DMA de los sprites (~170 ciclos)
;;   2. Scroll (la cámara)
;;   3. Tiles del mapa que han cambiado (monedas cogidas)
;;   4. El HUD, si ha cambiado (~200 ciclos)
;;   5. Una fila de texto de los menús, si hay una preparada (~200 ciclos)
;; En el peor caso son unos 750 ciclos: cabe con margen.
;;==============================================================
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"

SECTION "Row buffer vars", WRAM0
row_dest:       ds 2                  ;; where the row goes (an address of the VRAM)
row_buffer::    ds SCREEN_TILES + 1   ;; the row, prepared outside the VBLANK (+1: TEXT_END)
row_dirty:      ds 1                  ;; 1: copy it in the next VBLANK

SECTION "Render", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Moves the background to the position of the camera: the scroll. The registers
;; rSCX and rSCY say which pixel of the background is at the top left of the screen.
;; ⚠️ Changing them in the middle of a frame tears the picture: do it in VBLANK
;;    (or with the screen off). Use sys_camera_get
;; ❌ Modifies A, BC
sys_render_scroll::
    call sys_camera_get               ;; B = camera Y, C = camera X

    ld   a, c                         ;; \ rSCX = camera X
    ldh  [rSCX], a                    ;; /
    ld   a, b                         ;; \ rSCY = camera Y
    ldh  [rSCY], a                    ;; /

    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Everything that goes to the VRAM in a frame. Called just after the VBLANK starts.
;; ❌ Modifies A, BC, DE, HL
sys_render_vblank::
    call dma_run
    call sys_render_scroll
    call map_flush_pending
    call hud_vblank
    ; continues in row_vblank

;; Copies the row of text, if there is one ready (in the VBLANK, or with the
;; screen off). ❌ Modifies A, B, DE, HL
row_vblank::
    ld   a, [row_dirty]
    or   a
    ret  z
    xor  a
    ld   [row_dirty], a
    ld   a, [row_dest]
    ld   e, a
    ld   a, [row_dest + 1]
    ld   d, a
    ld   hl, row_buffer
    ld   b, SCREEN_TILES
    jp   memcpy8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Starts a row of text for a menu: an empty row that will go to a row of the
;; background. Write in it (draw_text...) and then call row_commit.
;; ⚠️ Only one row per frame
;; 📥 A = row of the screen (0-17)
;; ⫷▬ HL = row_buffer
;; ❌ Modifies A, B, HL
row_begin::
    ld   l, a                         ;; \ row_dest = TILEMAP + row * 32
    ld   h, 0                         ;; |
    add  hl, hl                       ;; |
    add  hl, hl                       ;; |
    add  hl, hl                       ;; |
    add  hl, hl                       ;; |
    add  hl, hl                       ;; |
    ld   a, l                         ;; | (TILEMAP has its low byte at 0)
    ld   [row_dest], a                ;; |
    ld   a, h                         ;; |
    add  HIGH(TILEMAP)                ;; |
    ld   [row_dest + 1], a            ;; /
    ld   hl, row_buffer               ;; \ An empty row
    ld   b, SCREEN_TILES              ;; |
    ld   a, TILE_BLANK                ;; |
    call memset8                      ;; /
    ld   hl, row_buffer
    ret

;; The row is ready: it is copied in the next VBLANK. ❌ Modifies A
row_commit::
    ld   a, 1
    ld   [row_dirty], a
    ret

;; Forgets the row and the HUD (when a scene starts). ❌ Modifies A
render_reset::
    xor  a
    ld   [row_dirty], a
    ld   [hud_dirty], a
    ret
