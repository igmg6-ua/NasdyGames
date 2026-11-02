;;==============================================================
;; HUD: corazones, monedas, espectros, tiempo y nivel (en la window)
;;==============================================================
IF !DEF(HUD_INC)
DEF HUD_INC = 1

INCLUDE "engine/hardware.inc"

;; The HUD lives in the WINDOW: a layer that is drawn over the background and
;; does NOT scroll. A strip of one row of tiles at the bottom of the screen.
DEF HUD_WINDOW_X = 7                    ;; rWX: window at column 0 (WX = column + 7)
DEF HUD_WINDOW_Y = SCREEN_HEIGHT - 8    ;; rWY: the last row of tiles of the screen
DEF HUD_HIDDEN_Y = SCREEN_HEIGHT        ;; rWY below the screen: no window
DEF HUD_CELLS    = 20                   ;; the cells of the strip (one row of the screen)

;; In the Challenge 6 the hearts were drawn straight into the window, with the
;; screen off. Here the HUD changes while playing (coins, time...), so it is
;; built in hud_buffer (WRAM) and copied to the window in the VBLANK.
;; These are the cells of hud_buffer (column of the window):
;;   0-4     5  6   7  8-9    10 11   12 13-15   17 18-19
;;   ♥♥♥♡♡   ◈  ⌐   ●  07     ☠  3    ◷  118      ▣  10
DEF HUD_HEARTS_CELL = 0
DEF HUD_SHIELD_CELL = 5       ;; the shield icon, while the hero has it
DEF HUD_GUN_CELL    = 6       ;; the gun icon, once the hero has it
DEF HUD_COIN_ICON   = 7
DEF HUD_COINS_CELL  = 8
DEF HUD_ENEMY_ICON  = 10
DEF HUD_ENEMY_CELL  = 11
DEF HUD_CLOCK_ICON  = 12
DEF HUD_TIME_CELL   = 13
DEF HUD_LEVEL_ICON  = 17
DEF HUD_LEVEL_CELL  = 18

ENDC
