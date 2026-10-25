;;==============================================================
;; Gestor del mapa: constantes (Challenge 6)
;;==============================================================
IF !DEF(MAN_MAP_INC)
DEF MAN_MAP_INC = 1

;; The map of a level is a table of tiles: MAP_HEIGHT rows of MAP_WIDTH tiles.
;; It is exactly the size of the background (32 x 32 tiles), so the same bytes
;; are copied to the screen and used to know what is solid. In this game the
;; map is copied to RAM (map_ram), because the coins disappear when you take them.
DEF MAP_WIDTH   = 32                    ;; tiles
DEF MAP_HEIGHT  = 32
DEF MAP_SIZE    = MAP_WIDTH * MAP_HEIGHT
DEF TILE_SIZE   = 8                     ;; a tile is 8 x 8 pixels
DEF MAP_PIXELS  = MAP_WIDTH * TILE_SIZE ;; 256: a position (Y or X) fits in ONE byte

DEF PENDING_TILES_MAX = 4               ;; tiles of the background to change in one VBLANK

ENDC
