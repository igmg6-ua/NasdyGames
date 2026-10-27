;;==============================================================
;; engine/ui/hud.asm -- El marcador (HUD) en la window
;;==============================================================
INCLUDE "engine/ui/hud.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "scn/scn_game.inc"

SECTION "HUD vars", WRAM0
hud_buffer::    ds HUD_CELLS          ;; the strip, ready to be copied
hud_dirty::     ds 1                  ;; 1: copy hud_buffer in the next VBLANK

SECTION "HUD", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Shows the window at the bottom of the screen.
;; ⚠️ The screen must be OFF (or be in VBLANK)
;; ❌ Modifies A
hud_show::
    ld   a, HUD_WINDOW_X              ;; \ The window starts at the left of the screen
    ldh  [rWX], a                     ;; /
    ld   a, HUD_WINDOW_Y              ;; \ and at the last row of tiles
    ldh  [rWY], a                     ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Hides the window (it is moved below the screen). ❌ Modifies A
hud_hide::
    ld   a, HUD_HIDDEN_Y
    ldh  [rWY], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Draws the hearts of the HUD: HEARTS_MAX cells, the first C full and the rest empty.
;; 📥 C = hearts the hero has
;; ❌ Modifies A, BC, HL
hud_draw_hearts::
    ld   b, HEARTS_MAX                ;; B = hearts to draw
    ld   hl, hud_buffer + HUD_HEARTS_CELL ;; HL = the first cell of the hearts
.heart
    ld   a, c                         ;; \ Does the hero have a heart left to show?
    or   a                            ;; |
    ld   a, TILE_HEART_EMPTY          ;; | A = an empty heart, if it does not
    jr   z, .put                      ;; |
    ld   a, TILE_HEART_FULL           ;; | A = a full heart
    dec  c                            ;; / One heart less to show
.put
    ld   [hl+], a                     ;; Write it in the cell
    dec  b                            ;; \ B--: next heart,
    jr   nz, .heart                   ;; / while there are cells left
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Builds the whole strip from the state of the game, and asks to copy it.
;; ❌ Modifies A, BC, HL
hud_refresh::
    ld   hl, hud_buffer               ;; \ Clean strip
    ld   a, TILE_BLANK                ;; |
    ld   b, HUD_CELLS                 ;; |
    call memset8                      ;; /
    ld   a, [hearts]                  ;; \ Hearts
    ld   c, a                         ;; |
    call hud_draw_hearts              ;; /
    ld   hl, hud_buffer + HUD_COIN_ICON ;; \ Coins (2 BCD digits)
    ld   [hl], TILE_COIN              ;; |
    inc  hl                           ;; |
    ld   a, [coins]                   ;; |
    call draw_bcd                     ;; /
    ld   hl, hud_buffer + HUD_ENEMY_ICON ;; \ Spectres left
    ld   [hl], TILE_ICON_ENEMY        ;; |
    inc  hl                           ;; |
    ld   a, [enemies_left]            ;; |
    call draw_digit                   ;; /
    ld   hl, hud_buffer + HUD_CLOCK_ICON ;; \ Time: 3 digits (time_hi has only one)
    ld   [hl], TILE_ICON_CLOCK        ;; |
    inc  hl                           ;; |
    ld   a, [time_hi]                 ;; |
    and  $0F                          ;; |
    call draw_digit                   ;; |
    ld   a, [time_lo]                 ;; |
    call draw_bcd                     ;; /
    ld   hl, hud_buffer + HUD_LEVEL_ICON ;; \ Level (1-3)
    ld   [hl], TILE_ICON_LEVEL        ;; |
    inc  hl                           ;; |
    ld   a, [current_level]           ;; |
    inc  a                            ;; |
    call draw_digit                   ;; /
    ; continues in hud_mark

;; Asks to copy the strip in the next VBLANK. ❌ Modifies A
hud_mark::
    ld   a, 1
    ld   [hud_dirty], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; In the VBLANK (or with the screen off): copies the strip to the window
;; if it has changed. 20 bytes: about 200 cycles of the 1140 of a VBLANK.
;; ❌ Modifies A, B, DE, HL
hud_vblank::
    ld   a, [hud_dirty]
    or   a
    ret  z
    xor  a
    ld   [hud_dirty], a
    ld   hl, hud_buffer
    ld   de, WINDOW_MAP
    ld   b, HUD_CELLS
    jp   memcpy8
