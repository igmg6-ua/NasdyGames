;;==============================================================
;; man/man_map.asm -- Gestor del mapa (Challenge 6, más tiles que cambian)
;;==============================================================
INCLUDE "engine/hardware.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "man/man_map.inc"

SECTION "Map RAM", WRAM0, ALIGN[8]
map_ram::       ds MAP_SIZE           ;; the map of the level, in RAM (coins disappear)

SECTION "Map vars", WRAM0
map_current::   ds 2                  ;; the map that map_tile_address reads
pending_count:  ds 1                  ;; tiles of the screen waiting for the VBLANK
pending_tiles:  ds PENDING_TILES_MAX * 3 ;; each one: VRAM address (low, high), tile

SECTION "Map manager", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Loads a map: it is copied to map_ram and to the background of the screen.
;; A map can be smaller than 32 x 32: it is stored by rows of its own width,
;; and the rest of map_ram (and of the screen) is filled with TILE_WALL_EDGE,
;; a solid tile. map_ram always has rows of MAP_WIDTH (32) tiles, so
;; map_tile_address works the same for every map.
;; 📥 HL = map in the ROM, B = width, C = height (tiles)
;; ⚠️ The screen must be OFF
;; ❌ Modifies A, BC, DE, HL
map_load::
    push hl                           ;; \ map_ram all solid
    push bc                           ;; |
    ld   hl, map_ram                  ;; |
    ld   bc, MAP_SIZE                 ;; |
    ld   a, TILE_WALL_EDGE            ;; |
    call memset16                     ;; |
    pop  bc                           ;; |
    pop  hl                           ;; /
    ld   de, map_ram
.row
    push bc                           ;; \ One row: B tiles
    push de                           ;; |
    call memcpy8                      ;; | (HL -> the next row of the ROM map)
    pop  de                           ;; |
    pop  bc                           ;; /
    ld   a, e                         ;; \ DE = the next row of map_ram (+32)
    add  MAP_WIDTH                    ;; |
    ld   e, a                         ;; |
    adc  d                            ;; |
    sub  e                            ;; |
    ld   d, a                         ;; /
    dec  c
    jr   nz, .row
    ld   hl, map_ram                  ;; \ map_ram -> background
    ld   de, TILEMAP                  ;; |
    ld   bc, MAP_SIZE                 ;; |
    call memcpy16                     ;; /
    ld   a, LOW(map_ram)              ;; \ map_current = map_ram
    ld   [map_current], a             ;; |
    ld   a, HIGH(map_ram)             ;; |
    ld   [map_current + 1], a         ;; /
    xor  a                            ;; \ Nothing waiting
    ld   [pending_count], a           ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Where is the tile that covers a point of the world?
;; The map is a table of rows of MAP_WIDTH (32) tiles, and a tile is 8 x 8 pixels:
;;      tile row    = Y / 8        tile column = X / 8
;;      address     = map + row * 32 + column
;; 📥 D = Y, E = X (pixels of the world)
;; ⫷▬ HL = address of its tile in the map
;; ❌ Modifies A, HL
map_tile_address::
    ld   a, d                         ;; \ A = Y without its 3 low bits = row * 8
    and  %11111000                    ;; |
    ld   l, a                         ;; | HL = row * 8
    ld   h, 0                         ;; /
    add  hl, hl                       ;; \ HL = row * 8 * 2 * 2 = row * 32
    add  hl, hl                       ;; / (the start of its row in the map)

    ld   a, e                         ;; \ A = X / 8 = column
    srl  a                            ;; |
    srl  a                            ;; |
    srl  a                            ;; /
    add  l                            ;; \ HL += column: row * 32 has its 5 low bits at 0
    ld   l, a                         ;; / and column < 32, so no carry: only L changes

    ld   a, [map_current]             ;; \ HL += map_current: the address in the map
    add  l                            ;; |
    ld   l, a                         ;; |
    ld   a, [map_current + 1]         ;; |
    adc  h                            ;; |
    ld   h, a                         ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Is the point solid? A tile is solid if it is TILE_FIRST_SOLID or higher:
;; the tiles are ordered in the tile block so that one comparison decides it.
;; 📥 D = Y, E = X (pixels of the world)
;; ⫷▬ NZ, the point is in a solid tile
;;     Z, it is free
;; ❌ Modifies A, HL. Does NOT modify DE
map_is_solid_at::
    call map_tile_address             ;; HL = the tile that covers the point
    ld   a, [hl]                      ;; \ A = the tile
    cp   TILE_FIRST_SOLID             ;; | Is it below the first solid tile?
    jr   c, .free                     ;; / Yes: it is free
    or   1                            ;; \ NZ: solid
    ret                               ;; /
.free
    xor  a                            ;; \ Z: free
    ret                               ;; /

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Changes a tile of the map. The map in RAM changes now; the screen, in the
;; next VBLANK (the VRAM can not be written while the screen is being drawn).
;; map_ram and TILEMAP are both aligned to a page and have the same layout, so
;; the address on the screen is the same with another high byte.
;; 📥 HL = address of the tile in map_ram, A = new tile
;; ❌ Modifies A, BC, HL. Does NOT modify DE
map_set_tile::
    ld   [hl], a                      ;; The map in RAM
    ld   c, a                         ;; C = the tile
    ld   a, [pending_count]           ;; \ Is the list full? (it never is: at most
    cp   PENDING_TILES_MAX            ;; | one coin is taken in a frame)
    ret  nc                           ;; /
    ld   b, a                         ;; \ pending_count++ (B = the old count)
    inc  a                            ;; |
    ld   [pending_count], a           ;; /
    push de
    ld   d, h                         ;; DE = the address in map_ram
    ld   e, l
    ld   a, b                         ;; \ HL = pending_tiles + count * 3
    add  a                            ;; |
    add  b                            ;; |
    add  LOW(pending_tiles)           ;; |
    ld   l, a                         ;; |
    ld   a, HIGH(pending_tiles)       ;; |
    adc  0                            ;; |
    ld   h, a                         ;; /
    ld   a, e                         ;; \ The address on the screen: the same low byte,
    ld   [hl+], a                     ;; | and the high byte moved from map_ram to TILEMAP
    ld   a, d                         ;; |
    sub  HIGH(map_ram)                ;; |
    add  HIGH(TILEMAP)                ;; |
    ld   [hl+], a                     ;; /
    ld   [hl], c                      ;; The tile
    pop  de
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; In the VBLANK: writes the pending tiles on the screen.
;; ❌ Modifies A, B, HL
map_flush_pending::
    ld   a, [pending_count]
    or   a
    ret  z
    ld   b, a
    ld   hl, pending_tiles
.tile
    push bc
    ld   a, [hl+]                     ;; \ BC = VRAM address
    ld   c, a                         ;; |
    ld   a, [hl+]                     ;; |
    ld   b, a                         ;; /
    ld   a, [hl+]                     ;; \ The tile
    ld   [bc], a                      ;; /
    pop  bc
    dec  b
    jr   nz, .tile
    xor  a
    ld   [pending_count], a
    ret
