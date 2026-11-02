;;==============================================================
;; scn/scn_game_rules.asm -- Las reglas del juego
;;
;; Los sistemas (sys/) no saben nada del juego: mueven, animan y dibujan
;; entidades. Aquí está lo que hace que esto sea "Laberinto": las plantillas
;; de las entidades, los niveles, las monedas, los disparos, los corazones,
;; los objetos que se recogen (pistola, escudo y corazón), el tiempo, el
;; medallón y el portal.
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"
INCLUDE "man/man_map.inc"
INCLUDE "assets/levels/levels.inc"

SECTION "Game vars", WRAM0
current_level:: ds 1                  ;; 0 .. NUM_LEVELS - 1
hearts::        ds 1
coins::         ds 1                  ;; BCD: coins taken in this level
total_coins::   ds 2                  ;; BCD: coins of the whole game
score::         ds 2                  ;; BCD: 10 per coin + the seconds left at each portal
kills::         ds 1                  ;; BCD (the whole game)
bonus::         ds 2                  ;; BCD, high byte first: seconds left at each portal
level_bonus::   ds 2                  ;; BCD: the seconds left at the last portal
enemies_left::  ds 1
time_hi::       ds 1                  ;; BCD: seconds left (time_hi is 0 .. 9)
time_lo::       ds 1
sec_frames:     ds 1                  ;; frames left of this second
hurt_timer::    ds 1                  ;; frames of immunity left after a hit
shot_entity::   ds 1                  ;; low byte of the bullet (ENTITY_NONE: no bullet)
game_result::   ds 1                  ;; RESULT_...
has_gun::       ds 1                  ;; 0=nogun/1=hasgun
has_shield::    ds 1                  ;; 1: the next hit of a spectre is stopped
level_medal::   ds 1                  ;; 1: all the spectres of this level defeated
level_enemies:: ds 1                  ;; spectres at the start of the level
elapsed_mm::    ds 1                  ;; time spent in this level: minutes (BCD)
elapsed_ss::    ds 1                  ;;   and seconds (BCD, 0-59)
time_half:      ds 2                  ;; BCD: below it, the music goes faster
time_third:     ds 2                  ;; BCD: below it, faster still
level_w::       ds 1                  ;; size of the map (tiles)
level_h::       ds 1
exit_row:       ds 1                  ;; where the portal is (tiles)
exit_col:       ds 1
spawn_tpl:      ds 2                  ;; game_spawn_random: the template,
spawn_min:      ds 1                  ;;   the minimum distance from the hero,
spawn_tries:    ds 1                  ;;   tries left,
spawn_row:      ds 1                  ;;   and the place being tried
spawn_col:      ds 1

DEF WALK_NONE  = $FF                  ;; walk_dist: not reached
DEF WALK_FIRST = TILEMAP_WIDTH + 1     ;; the places looked at: from row 1, column 1
DEF WALK_LAST  = MAP_SIZE - 2 * TILEMAP_WIDTH ;; to row 29 (their feet, in row 30 at most)

SECTION "Walk distances", WRAM0
walk_dist:      ds MAP_SIZE           ;; tiles the hero walks to each place (game_spawn_near)

SECTION "Game rules", ROM0

;;--------------------------------------------------------------
;; Templates: the 16 bytes of each kind of entity (man_entity.inc).
;; Y and X are set when it is created.
;;--------------------------------------------------------------
MACRO TEMPLATE      ;; \1 CMP, \2 sheet, \3 kind, \4 life, \5 think
    db \1                             ;; E_CMP
    db 0, 0                           ;; E_Y, E_X
    db \2, 0                          ;; E_TILE, E_ATTR
    db 0, 0                           ;; E_VY, E_VX
    db \3, DIR_DOWN                   ;; E_KIND, E_DIR
    db \2, 0                          ;; E_SHEET, E_TICK
    db \4, \5                         ;; E_LIFE, E_THINK
    db 0, 0, 0                        ;; E_RESERVED (E_AI_TYPE)
ENDM

PlayerTemplate:
    TEMPLATE CMP_ALIVE | CMP_SPRITE | CMP_PHYSICS | CMP_COLLIDER | CMP_INPUT | CMP_ANIMATION, \
             TILE_BOY, KIND_PLAYER, 0, 0
EnemyTemplate:
    TEMPLATE CMP_ALIVE | CMP_SPRITE | CMP_PHYSICS | CMP_COLLIDER | CMP_AI | CMP_ANIMATION, \
             TILE_SPECTRE, KIND_ENEMY, 0, 1
ShotTemplate:
    TEMPLATE CMP_ALIVE | CMP_SPRITE | CMP_PHYSICS | CMP_COLLIDER | CMP_SELFDESTROY, \
             TILE_BULLET, KIND_SHOT, SHOT_FRAMES, 0
PortalTemplate:
    TEMPLATE CMP_ALIVE | CMP_SPRITE | CMP_COLLIDER | CMP_ANIMATION, \
             TILE_PORTAL, KIND_PORTAL, 0, 0
PoofTemplate:
    TEMPLATE CMP_ALIVE | CMP_SPRITE | CMP_SELFDESTROY | CMP_ANIMATION, \
             TILE_POOF, 0, POOF_FRAMES, 0
GunTemplate:
    TEMPLATE CMP_ALIVE | CMP_SPRITE | CMP_COLLIDER, \
             TILE_GUN, KIND_GUN, 0, 0
ShieldTemplate:
    TEMPLATE CMP_ALIVE | CMP_SPRITE | CMP_COLLIDER, \
             TILE_SHIELD, KIND_SHIELD, 0, 0
HeartTemplate:
    TEMPLATE CMP_ALIVE | CMP_SPRITE | CMP_COLLIDER, \
             TILE_HEART, KIND_HEART, 0, 0


;; The velocity of a bullet in each direction (VY, VX), index = DIR * 2
ShotVelocity:
    db  SHOT_SPEED, 0                 ;; DIR_DOWN
    db -SHOT_SPEED, 0                 ;; DIR_UP
    db  0, -SHOT_SPEED                ;; DIR_LEFT
    db  0,  SHOT_SPEED                ;; DIR_RIGHT


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A new game: level 1, HEARTS_START hearts, no coins.
;; ❌ Modifies A
game_new::
    xor  a
    ld   [current_level], a
    ld   [total_coins], a
    ld   [total_coins + 1], a
    ld   [score], a
    ld   [score + 1], a
    ld   [kills], a
    ld   [bonus], a
    ld   [bonus + 1], a
    ld   [level_bonus], a
    ld   [level_bonus + 1], a
    ld   a, HEARTS_START
    ld   [hearts], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The number of the current level (1 .. 10) in BCD, to draw it.
;; ⫷▬ A = BCD   ❌ Modifies A
level_number_bcd::
    ld   a, [current_level]
    inc  a
    cp   10
    ret  c
    add  6                            ;; 10 -> $10 (BCD)
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ⫷▬ HL = the current level (its structure: levels.inc)
;; ❌ Modifies A, HL
level_get::
    ld   a, [current_level]           ;; \ HL = &LevelTable[current_level]
    add  a                            ;; |
    add  LOW(LevelTable)              ;; |
    ld   l, a                         ;; |
    ld   a, HIGH(LevelTable)          ;; |
    adc  0                            ;; |
    ld   h, a                         ;; /
    ld   a, [hl+]                     ;; \ HL = LevelTable[current_level]
    ld   h, [hl]                      ;; |
    ld   l, a                         ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Creates an entity at a position of the world (pixels).
;; 📥 HL = template, B = Y, C = X
;; ⫷▬ HL = the new entity, carry = 0
;;     carry = 1: there was no room (nothing is created)
;; ❌ Modifies A, B, HL. Does NOT modify C or DE
game_spawn_px::
    push de
    push bc
    call man_entity_create            ;; DE = the new entity
    pop  bc
    jr   c, .end
    ld   h, d                         ;; \ Its Y and X
    ld   a, e                         ;; |
    add  E_Y                          ;; |
    ld   l, a                         ;; |
    ld   [hl], b                      ;; |
    inc  l                            ;; |
    ld   [hl], c                      ;; /
    ld   l, e                         ;; HL = the entity (carry = 0 from the add)
.end
    pop  de
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Creates an entity in a tile of the map: Y = row * 8, X = column * 8.
;; 📥 HL = template, C = column, B = row
;; ⫷▬ HL = the new entity (carry = 1: no room)
;; ❌ Modifies A, BC, HL. Does NOT modify DE
game_spawn_at::
    ld   a, b                         ;; \ B = row * 8
    add  a                            ;; |
    add  a                            ;; |
    add  a                            ;; |
    ld   b, a                         ;; /
    ld   a, c                         ;; \ C = column * 8
    add  a                            ;; |
    add  a                            ;; |
    add  a                            ;; |
    ld   c, a                         ;; /
    jr   game_spawn_px

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Creates the enemies of a level. In the data of the level, a byte with how many
;; they are is followed by the position of each one: its column and row, in tiles.
;; It also remembers how many there are (enemies_left).
;; 📥 HL = &level.ENEMIES
;; ❌ Modifies A, BC, DE, HL
;; ⚠️ Use game_spawn_at, with EnemyTemplate
game_enemies_spawn::
    ld   a, [hl+]                     ;; \ enemies_left = the number of enemies
    ld   [enemies_left], a            ;; | (HL -> their positions)
    ld   d, h                         ;; | DE = the positions
    ld   e, l                         ;; /
    or   a                            ;; \ No enemies? Nothing else to do
    ret  z                            ;; /
.enemy
    push af                           ;; Save the enemies left to create
    ld   a, [de]                      ;; \ C = the column of the enemy
    inc  de                           ;; |
    ld   c, a                         ;; /
    ld   a, [de]                      ;; \ B = its row
    inc  de                           ;; |
    ld   b, a                         ;; /
    ld   hl, EnemyTemplate            ;; \ Create the enemy in that tile
    call game_spawn_at                ;; / (DE is not modified)
    pop  af                           ;; \ One enemy less to create,
    dec  a                            ;; | while there are enemies left
    jr   nz, .enemy                   ;; /
    ret

;; Gives each spectre the AI of its level: even, odd, even...
;; 📥 HL = the level
;; ❌ Modifies A, BC, DE, HL
game_enemies_ai:
    ld   de, LVL_AI_EVEN              ;; \ B = AI of the even ones, C = of the odd ones
    add  hl, de                       ;; |
    ld   a, [hl+]                     ;; |
    ld   b, a                         ;; |
    ld   c, [hl]                      ;; /
    ld   de, entity_array
.next
    ld   a, [de]                      ;; \ A spectre?
    bit  CMP_AI_BIT, a                ;; |
    jr   z, .skip                     ;; /
    FIELD_HL E_AI_TYPE                ;; \ Its AI = B, and B and C swap for the next one
    ld   [hl], b                      ;; |
    ld   a, b                         ;; |
    ld   b, c                         ;; |
    ld   c, a                         ;; /
.skip
    ld   a, e
    add  SIZEOF_ENTITY
    ld   e, a
    cp   LOW(entity_array) + ENTITY_ARRAY_SIZE
    jr   nz, .next
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Creates an entity in a random free place of the map, at least some tiles
;; away from the hero (rows + columns) and not on the portal.
;; A place (row, column) is the top left tile of the image: it is free if the
;; 2 tiles of its feet (row + 1, column and column + 1) are not solid. Every
;; floor tile of the maze can be reached, so the hero can always get there.
;; If no place is found after PICKUP_TRIES tries, nothing is created.
;; 📥 HL = template, A = minimum distance from the hero (tiles)
;; ❌ Modifies A, BC, DE, HL
game_spawn_random:
    ld   [spawn_min], a
    ld   a, l
    ld   [spawn_tpl], a
    ld   a, h
    ld   [spawn_tpl + 1], a
    ld   a, PICKUP_TRIES
    ld   [spawn_tries], a
.try
    ld   hl, spawn_tries              ;; \ One try less (none left: give up)
    dec  [hl]                         ;; |
    ret  z                            ;; /
    ld   a, [level_h]                 ;; \ row = 1 + random % (height - 3)
    sub  3                            ;; |
    call random_below                 ;; |
    inc  a                            ;; |
    ld   [spawn_row], a               ;; /
    ld   a, [level_w]                 ;; \ column = 1 + random % (width - 3)
    sub  3                            ;; |
    call random_below                 ;; |
    inc  a                            ;; |
    ld   [spawn_col], a               ;; /
    ld   c, a                         ;; \ Its feet on free tiles?
    ld   a, [spawn_row]               ;; | (HL = &map_ram[row + 1][column])
    inc  a                            ;; |
    ld   l, a                         ;; |
    ld   h, 0                         ;; |
    add  hl, hl                       ;; |
    add  hl, hl                       ;; |
    add  hl, hl                       ;; |
    add  hl, hl                       ;; |
    add  hl, hl                       ;; | (* 32)
    ld   b, 0                         ;; |
    add  hl, bc                       ;; |
    ld   bc, map_ram                  ;; |
    add  hl, bc                       ;; |
    ld   a, [hl+]                     ;; |
    cp   TILE_FIRST_SOLID             ;; |
    jr   nc, .try                     ;; |
    ld   a, [hl]                      ;; |
    cp   TILE_FIRST_SOLID             ;; |
    jr   nc, .try                     ;; /
    ld   a, [exit_row]                ;; \ Not on the portal
    ld   b, a                         ;; |
    ld   a, [exit_col]                ;; |
    ld   c, a                         ;; |
    call spawn_distance               ;; |
    cp   3                            ;; |
    jr   c, .try                      ;; /
    ld   a, [PLAYER_ENTITY + E_Y]     ;; \ Far enough from the hero
    rrca                              ;; | (his tile: position / 8)
    rrca                              ;; |
    rrca                              ;; |
    and  %00011111                    ;; |
    ld   b, a                         ;; |
    ld   a, [PLAYER_ENTITY + E_X]     ;; |
    rrca                              ;; |
    rrca                              ;; |
    rrca                              ;; |
    and  %00011111                    ;; |
    ld   c, a                         ;; |
    call spawn_distance               ;; |
    ld   hl, spawn_min                ;; |
    cp   [hl]                         ;; |
    jr   c, .try                      ;; /
    ld   a, [spawn_tpl]               ;; \ Here
    ld   l, a                         ;; |
    ld   a, [spawn_tpl + 1]           ;; |
    ld   h, a                         ;; |
    ld   a, [spawn_row]               ;; |
    ld   b, a                         ;; |
    ld   a, [spawn_col]               ;; |
    ld   c, a                         ;; |
    jp   game_spawn_at                ;; /

;; ⫷▬ A = |spawn_row - B| + |spawn_col - C|   ❌ Modifies A, B
spawn_distance:
    ld   a, [spawn_row]
    sub  b
    jr   nc, .rows
    cpl
    inc  a
.rows
    ld   b, a
    ld   a, [spawn_col]
    sub  c
    jr   nc, .cols
    cpl
    inc  a
.cols
    add  b
    ret

;; ⫷▬ A = a random number from 0 to A - 1   📥 A = 1 .. 255
;; ❌ Modifies A, B, HL. Does NOT modify C or DE
random_below:
    push af
    call rng_next                     ;; A = 0 .. 255 (rng_next does not touch C)
    pop  hl                           ;; H = the limit
.mod
    cp   h                            ;; \ A % limit
    ret  c                            ;; |
    sub  h                            ;; |
    jr   .mod                         ;; /

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Creates an entity in a random place NEAR the hero: one he can reach
;; walking GUN_NEAR_MIN to GUN_NEAR_MAX tiles. (In a maze, a place 3 tiles
;; away in a straight line can be behind a wall and 60 tiles away walking:
;; that is why the distance is measured walking, with walk_fill.)
;; If there is no such place (a map edited by hand), anywhere.
;; 📥 HL = template
;; ❌ Modifies A, BC, DE, HL
game_spawn_near:
    ld   a, l                         ;; \ Save the template
    ld   [spawn_tpl], a               ;; |
    ld   a, h                         ;; |
    ld   [spawn_tpl + 1], a           ;; /
    call walk_fill
    ld   a, $FF                       ;; \ C = how many places are near
    call walk_scan                    ;; /
    ld   a, c
    or   a
    jr   nz, .pick
    ld   a, [spawn_tpl]               ;; \ None: anywhere
    ld   l, a                         ;; |
    ld   a, [spawn_tpl + 1]           ;; |
    ld   h, a                         ;; |
    xor  a                            ;; |
    jp   game_spawn_random            ;; /
.pick
    call random_below                 ;; \ DE = one of them, at random
    call walk_scan                    ;; /
    ld   a, e                         ;; \ HL = its index (row * 32 + column)
    sub  LOW(walk_dist)               ;; |
    ld   l, a                         ;; |
    ld   a, d                         ;; |
    sbc  HIGH(walk_dist)              ;; |
    ld   h, a                         ;; /
    ld   a, l                         ;; \ C = column = index % 32
    and  TILEMAP_WIDTH - 1            ;; |
    ld   c, a                         ;; /
    ld   a, l                         ;; \ B = row = index / 32
    swap a                            ;; |
    rrca                              ;; |
    and  %00000111                    ;; |
    ld   b, a                         ;; |
    ld   a, h                         ;; |
    add  a                            ;; |
    add  a                            ;; |
    add  a                            ;; |
    or   b                            ;; |
    ld   b, a                         ;; /
    ld   a, [spawn_tpl]               ;; \ Here
    ld   l, a                         ;; |
    ld   a, [spawn_tpl + 1]           ;; |
    ld   h, a                         ;; |
    jp   game_spawn_at                ;; /
ASSERT TILEMAP_WIDTH == 32

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Goes through the places that are near the hero (walk_dist from
;; GUN_NEAR_MIN to GUN_NEAR_MAX).
;; 📥 A = which one to stop at (0 ..), or $FF: count them all
;; ⫷▬ C = how many were counted; with A < $FF, DE = that place in walk_dist
;; ❌ Modifies A, C, DE, HL
walk_scan:
    ld   h, a                         ;; H = the one to stop at
    ld   c, 0
    ld   de, walk_dist + WALK_FIRST
.cell
    ld   a, [de]                      ;; \ Near?
    cp   GUN_NEAR_MIN                 ;; |
    jr   c, .next                     ;; |
    cp   GUN_NEAR_MAX + 1             ;; |
    jr   nc, .next                    ;; /
    ld   a, c                         ;; \ The one we wanted?
    cp   h                            ;; |
    ret  z                            ;; /
    inc  c
.next
    inc  de
    ld   a, e
    cp   LOW(walk_dist + WALK_LAST)
    jr   nz, .cell
    ld   a, d
    cp   HIGH(walk_dist + WALK_LAST)
    jr   nz, .cell
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; walk_dist = how many tiles the hero has to walk to reach each place of the
;; map (a place is the top left tile of a 16 x 16 image: it is free if its 2
;; feet tiles are not solid), up to GUN_NEAR_MAX; the rest, WALK_NONE.
;; It is a breadth first search done in passes: in pass k, the free
;; neighbours not reached yet of the places at k are at k + 1.
;; At the start of a level, with the screen off (some frames).
;; ❌ Modifies A, BC, DE, HL
walk_fill:
    ld   hl, walk_dist                ;; \ Nothing reached
    ld   bc, MAP_SIZE                 ;; |
    ld   a, WALK_NONE                 ;; |
    call memset16                     ;; /
    ld   a, [PLAYER_ENTITY + E_Y]     ;; \ The hero: 0
    and  %11111000                    ;; | HL = walk_dist + Y / 8 * 32 + X / 8
    ld   l, a                         ;; |
    ld   h, 0                         ;; |
    add  hl, hl                       ;; |
    add  hl, hl                       ;; |
    ld   a, [PLAYER_ENTITY + E_X]     ;; |
    rrca                              ;; |
    rrca                              ;; |
    rrca                              ;; |
    and  %00011111                    ;; |
    ld   c, a                         ;; |
    ld   b, 0                         ;; |
    add  hl, bc                       ;; |
    ld   bc, walk_dist                ;; |
    add  hl, bc                       ;; |
    ld   [hl], 0                      ;; /
    ld   b, 0                         ;; B = the pass (k)
.pass
    ld   de, walk_dist + WALK_FIRST
.cell
    ld   a, [de]
    cp   b
    jr   nz, .next
    ld   hl, $10000 - TILEMAP_WIDTH   ;; up
    call walk_try
    ld   hl, TILEMAP_WIDTH            ;; down
    call walk_try
    ld   hl, $FFFF                    ;; left
    call walk_try
    ld   hl, 1                        ;; right
    call walk_try
.next
    inc  de
    ld   a, e
    cp   LOW(walk_dist + WALK_LAST)
    jr   nz, .cell
    ld   a, d
    cp   HIGH(walk_dist + WALK_LAST)
    jr   nz, .cell
    inc  b
    ld   a, b
    cp   GUN_NEAR_MAX
    jr   nz, .pass
    ret

;; The neighbour DE + HL: if it was not reached and it is free, it is at B + 1.
;; ❌ Modifies A, HL
walk_try:
    add  hl, de
    ld   a, [hl]
    cp   WALK_NONE
    ret  nz
    push hl
    push de
    ld   de, map_ram + TILEMAP_WIDTH - walk_dist ;; \ HL = its feet in map_ram
    add  hl, de                       ;; /         (the row below)
    pop  de
    ld   a, [hl+]
    cp   TILE_FIRST_SOLID
    jr   nc, .blocked
    ld   a, [hl]
    cp   TILE_FIRST_SOLID
    jr   nc, .blocked
    pop  hl
    ld   a, b
    inc  a
    ld   [hl], a
    ret
.blocked
    pop  hl
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Prepares the current level: map, hero, portal, spectres, the things to
;; pick up, time, HUD, music.
;; ⚠️ The screen must be OFF
;; ❌ Modifies A, BC, DE, HL
game_level_start::
    call man_entity_init
    ld   a, ENTITY_NONE               ;; \ No bullet
    ld   [shot_entity], a             ;; /
    xor  a
    ld   [coins], a
    ld   [has_gun], a                 ;; NO GUN ON NEW LEVEL
    ld   [has_shield], a              ;; nor shield
    ld   [level_medal], a
    ld   [hurt_timer], a
    ld   [game_result], a
    ld   [elapsed_mm], a
    ld   [elapsed_ss], a
    ld   a, FRAMES_PER_SEC
    ld   [sec_frames], a

    call level_get                    ;; \ The clock: the time of the level, and
    push hl                           ;; | its half and its third (for the music)
    ld   de, LVL_TIME                 ;; |
    add  hl, de                       ;; |
    ld   a, [hl+]                     ;; |
    ld   [time_hi], a                 ;; |
    ld   a, [hl+]                     ;; |
    ld   [time_lo], a                 ;; |
    ld   de, time_half                ;; |
    ld   b, 4                         ;; |
    call memcpy8                      ;; /

    pop  hl                           ;; \ The map, of its size
    push hl                           ;; |
    ld   de, LVL_WIDTH                ;; |
    add  hl, de                       ;; |
    ld   a, [hl+]                     ;; |
    ld   [level_w], a                 ;; |
    ld   b, a                         ;; |
    ld   a, [hl]                      ;; |
    ld   [level_h], a                 ;; |
    ld   c, a                         ;; |
    call sys_camera_set_limits        ;; | (the camera stays inside it)
    pop  hl                           ;; |
    push hl                           ;; |
    ld   a, [hl+]                     ;; |
    ld   h, [hl]                      ;; |
    ld   l, a                         ;; |
    call map_load                     ;; /

    pop  hl                           ;; \ The hero (the FIRST entity: PLAYER_ENTITY)
    push hl                           ;; |
    ld   de, LVL_PLAYER_TX            ;; |
    add  hl, de                       ;; |
    ld   c, [hl]                      ;; |
    inc  hl                           ;; |
    ld   b, [hl]                      ;; |
    ld   hl, PlayerTemplate           ;; |
    call game_spawn_at                ;; /
    ld   a, [gender]                  ;; \ The girl or the boy
    or   a                            ;; |
    ld   a, TILE_BOY                  ;; |
    jr   z, .sheet                    ;; |
    ld   a, TILE_GIRL                 ;; |
.sheet                                ;; |
    ld   [PLAYER_ENTITY + E_TILE], a  ;; |
    ld   [PLAYER_ENTITY + E_SHEET], a ;; /

    pop  hl                           ;; \ The portal
    push hl                           ;; |
    ld   de, LVL_EXIT_TX              ;; |
    add  hl, de                       ;; |
    ld   c, [hl]                      ;; |
    inc  hl                           ;; |
    ld   b, [hl]                      ;; |
    ld   a, c                         ;; |
    ld   [exit_col], a                ;; |
    ld   a, b                         ;; |
    ld   [exit_row], a                ;; |
    ld   hl, PortalTemplate           ;; |
    call game_spawn_at                ;; /

    pop  hl                           ;; \ The spectres
    push hl                           ;; |
    ld   de, LVL_ENEMIES              ;; |
    add  hl, de                       ;; |
    call game_enemies_spawn           ;; |
    ld   a, [enemies_left]            ;; |
    ld   [level_enemies], a           ;; |
    pop  hl                           ;; |
    push hl                           ;; |
    call game_enemies_ai              ;; /

    ld   hl, GunTemplate              ;; \ The gun: every level, in a random
    call game_spawn_near              ;; / place near the hero (walking)
    ld   a, [current_level]           ;; \ From level 3: a shield and a heart,
    cp   PICKUPS_LEVEL                ;; | far from the hero
    jr   c, .no_pickups               ;; |
    ld   hl, ShieldTemplate           ;; |
    ld   a, PICKUP_MIN_DIST           ;; |
    call game_spawn_random            ;; |
    ld   hl, HeartTemplate            ;; |
    ld   a, PICKUP_MIN_DIST           ;; |
    call game_spawn_random            ;; |
.no_pickups                           ;; /

    pop  hl                           ;; \ Its song
    ld   de, LVL_SONG                 ;; |
    add  hl, de                       ;; |
    ld   a, [hl+]                     ;; |
    ld   h, [hl]                      ;; |
    ld   l, a                         ;; |
    call music_play                   ;; /

    ld   de, PLAYER_ENTITY            ;; \ The camera on the hero, and the scroll
    call sys_camera_update            ;; | now (the screen is off)
    call sys_render_scroll            ;; /
    call sys_animation_update         ;; \ The sprites
    call sys_prerender_update         ;; /
    call hud_refresh                  ;; \ The HUD, also now
    call hud_vblank                   ;; |
    jp   hud_show                     ;; /

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Destroys an entity. If it is the bullet, there is no bullet any more.
;; Called by the systems (a bullet that hits a wall, the end of a LIFE).
;; 📥 DE = entity
;; ❌ Modifies A
game_entity_destroy::
    ld   a, [shot_entity]
    cp   e
    jr   nz, .free
    ld   a, ENTITY_NONE
    ld   [shot_entity], a
.free
    jp   man_entity_free

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The hero shoots, if there is no bullet already: it goes the way he faces.
;; 📥 DE = the hero
;; ❌ Modifies A, BC, HL
game_shoot::
    ld a, [has_gun]      
    and a
    ret z                             ;; If no gun, do nothing
    ld   a, [shot_entity]             ;; \ Only one bullet at a time
    cp   ENTITY_NONE                  ;; |
    ret  nz                           ;; /
    FIELD_HL E_Y                      ;; \ B, C = the position of the hero
    ld   b, [hl]                      ;; |
    inc  l                            ;; |
    ld   c, [hl]                      ;; /
    ld   hl, ShotTemplate             ;; \ The bullet, there
    call game_spawn_px                ;; |
    ret  c                            ;; /
    ld   a, l                         ;; \ Remember it
    ld   [shot_entity], a             ;; /
    ld   c, l                         ;; C = the bullet
    ld   a, [PLAYER_ENTITY + E_DIR]   ;; \ HL = &ShotVelocity[DIR]
    add  a                            ;; |
    add  LOW(ShotVelocity)            ;; |
    ld   l, a                         ;; |
    ld   a, HIGH(ShotVelocity)        ;; |
    adc  0                            ;; |
    ld   h, a                         ;; /
    push de
    ld   d, HIGH(entity_array)        ;; \ bullet.VY, VX = the velocity
    ld   a, c                         ;; |
    add  E_VY                         ;; |
    ld   e, a                         ;; |
    ld   a, [hl+]                     ;; |
    ld   [de], a                      ;; |
    inc  e                            ;; |
    ld   a, [hl]                      ;; |
    ld   [de], a                      ;; /
    pop  de
    ld   a, SFX_SHOOT
    jp   sfx_play

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; What touches what (sys_collision_overlap):
;;   the bullet and a spectre -> the spectre is defeated
;;   the hero and a spectre   -> the hero loses a heart
;;   the hero and the portal  -> the level is over
;; ❌ Modifies A, BC, DE, HL
game_collisions::
    ld   a, [shot_entity]             ;; \ The bullet against the spectres
    cp   ENTITY_NONE                  ;; |
    jr   z, .hero                     ;; |
    ld   b, CMP_AI | CMP_COLLIDER     ;; |
    ld   hl, collide_shot             ;; |
    call man_entity_forall_matching   ;; /
.hero
    ld   b, CMP_COLLIDER              ;; \ The hero against everything
    ld   hl, collide_hero             ;; |
    jp   man_entity_forall_matching   ;; /

;; 📥 DE = a spectre
collide_shot:
    ld   a, [shot_entity]             ;; \ Is there still a bullet? (it may have hit
    cp   ENTITY_NONE                  ;; | another spectre in this frame)
    ret  z                            ;; /
    ld   h, HIGH(entity_array)        ;; \ HL = &bullet.Y
    add  E_Y                          ;; |
    ld   l, a                         ;; /
    call sys_collision_overlap
    ret  nc
    push de                           ;; \ The bullet disappears
    ld   a, [shot_entity]             ;; |
    ld   e, a                         ;; |
    call game_entity_destroy          ;; |
    pop  de                           ;; /
    jp   game_enemy_defeated

;; 📥 DE = an entity with COLLIDER
collide_hero:
    ld   a, e                         ;; \ Not with himself
    cp   LOW(PLAYER_ENTITY)           ;; |
    ret  z                            ;; /
    ld   hl, PLAYER_ENTITY + E_Y
    call sys_collision_overlap
    ret  nc
    FIELD_HL E_KIND
    ld   a, [hl]
    cp   KIND_ENEMY
    jr   z, game_hero_hurt
    cp   KIND_PORTAL
    jp   z, game_portal
    cp   KIND_GUN
    jr   z, .give_gun
    cp   KIND_SHIELD
    jr   z, .give_shield
    cp   KIND_HEART
    jr   z, .give_heart
    ret
.give_gun
    ld   hl, has_gun
    jr   .picked
.give_shield
    ld   hl, has_shield
.picked
    ld   [hl], 1
    call man_entity_free
    ld   a, SFX_LIFE
    call sfx_play
    jp   hud_refresh
.give_heart
    call man_entity_free
    ld   a, [hearts]                  ;; \ A heart more...
    cp   HEARTS_MAX                   ;; |
    jr   nc, .heart_time              ;; |
    inc  a                            ;; |
    ld   [hearts], a                  ;; |
    jr   .heart_sound                 ;; /
.heart_time
    ld   a, HEART_TIME_BONUS          ;; \ ...or, with all of them, some seconds
    call time_add                     ;; /
.heart_sound
    ld   a, SFX_LIFE
    call sfx_play
    jp   hud_refresh

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A spectre touches the hero. With the shield, the shield breaks and nothing
;; else happens; without it, a heart less. Either way, some time of immunity.
;; ❌ Modifies A, BC, HL
game_hero_hurt:
    ld   a, [hurt_timer]              ;; \ Immune?
    or   a                            ;; |
    ret  nz                           ;; /
    ld   a, [game_result]             ;; \ The level has already ended?
    or   a                            ;; |
    ret  nz                           ;; /
    ld   a, HURT_FRAMES
    ld   [hurt_timer], a
    ld   hl, has_shield               ;; \ The shield stops this hit (only this one)
    ld   a, [hl]                      ;; |
    or   a                            ;; |
    jr   z, .no_shield                ;; |
    ld   [hl], 0                      ;; |
    ld   a, SFX_KILL                  ;; |
    jr   .sound                       ;; /
.no_shield
    ld   hl, hearts
    dec  [hl]
    jr   nz, .alive
    ld   a, RESULT_DEAD
    ld   [game_result], a
.alive
    ld   a, SFX_HURT
.sound
    call sfx_play
    jp   hud_refresh

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The hero reaches the portal: the seconds left are the bonus, and they are
;; added to the score.
;; ❌ Modifies A, HL
game_portal:
    ld   a, [game_result]
    or   a
    ret  nz
    ld   a, [time_hi]                 ;; \ level_bonus = time left
    ld   [level_bonus], a             ;; |
    ld   a, [time_lo]                 ;; |
    ld   [level_bonus + 1], a         ;; /
    ld   hl, bonus + 1                ;; \ bonus += time left (BCD, 4 digits)
    call bcd16_add_time               ;; /
    ld   hl, score + 1                ;; \ score += time left
    call bcd16_add_time               ;; /
    ld   a, RESULT_CLEAR
    ld   [game_result], a
    ld   a, SFX_PORTAL
    jp   sfx_play

;; [HL - 1, HL] += time left (BCD, 4 digits). ❌ Modifies A, HL
bcd16_add_time:
    ld   a, [time_lo]
    add  [hl]
    daa
    ld   [hl-], a
    ld   a, [time_hi]
    adc  [hl]
    daa
    ld   [hl], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Adds seconds to the clock (never over 999).
;; 📥 A = seconds (BCD, up to $99)
;; ❌ Modifies A, BC, HL
time_add::
    ld   hl, time_lo
    add  [hl]
    daa
    ld   [hl-], a                     ;; HL -> time_hi
    ld   a, [hl]
    adc  0
    daa
    ld   [hl], a
    cp   TIME_MAX_HI + 1              ;; \ Over 999? 999
    jr   c, .ok                       ;; |
    ld   [hl], TIME_MAX_HI            ;; |
    inc  hl                           ;; |
    ld   [hl], $99                    ;; /
.ok
    jp   game_update_tempo

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A spectre is defeated: a cloud in its place and KILL_TIME_BONUS more seconds.
;; If it was the last one of the level, the medallion of the level is won.
;; 📥 DE = the spectre
;; ❌ Modifies A, BC, HL
game_enemy_defeated:
    FIELD_HL E_Y                      ;; \ B, C = where it was
    ld   b, [hl]                      ;; |
    inc  l                            ;; |
    ld   c, [hl]                      ;; /
    call man_entity_free              ;; \ The cloud instead of the spectre
    ld   hl, PoofTemplate             ;; |
    call game_spawn_px                ;; /
    ld   a, KILL_TIME_BONUS           ;; \ More time
    call time_add                     ;; /
    ld   a, [kills]                   ;; \ kills++ (BCD)
    add  1                            ;; |
    daa                               ;; |
    ld   [kills], a                   ;; /
    ld   hl, enemies_left             ;; \ The last one?
    dec  [hl]                         ;; |
    ld   a, SFX_KILL                  ;; |
    jr   nz, .sound                   ;; /
    ld   a, 1                         ;; \ Yes: the medallion of this level
    ld   [level_medal], a             ;; |
    ld   a, SFX_LIFE                  ;; /
.sound
    call sfx_play
    jp   hud_refresh

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The coins: if the feet of the hero touch a coin, it is taken.
;; ❌ Modifies A, BC, DE, HL
game_coins::
    ld   hl, PLAYER_ENTITY + E_Y      ;; \ D, E = top left corner of the feet
    ld   a, [hl+]                     ;; |
    add  FEET_TOP                     ;; |
    ld   d, a                         ;; |
    ld   a, [hl]                      ;; |
    add  FEET_LEFT                    ;; |
    ld   e, a                         ;; /
    call coin_at                      ;; \ The 4 corners
    ld   a, e                         ;; |
    add  FEET_RIGHT - FEET_LEFT       ;; |
    ld   e, a                         ;; |
    call coin_at                      ;; |
    ld   a, d                         ;; |
    add  FEET_BOTTOM - FEET_TOP       ;; |
    ld   d, a                         ;; |
    call coin_at                      ;; |
    ld   a, e                         ;; |
    sub  FEET_RIGHT - FEET_LEFT       ;; |
    ld   e, a                         ;; /
    ; continues in coin_at

;; 📥 D = Y, E = X  ❌ Modifies A, BC, HL. Does NOT modify DE
coin_at:
    call map_tile_address             ;; \ A coin there?
    ld   a, [hl]                      ;; |
    cp   TILE_COIN                    ;; |
    ret  nz                           ;; /
    ld   a, TILE_FLOOR                ;; \ It disappears from the map
    call map_set_tile                 ;; /
    ld   a, [coins]                   ;; \ coins++ in this level (BCD, up to 99)
    cp   $99                          ;; |
    jr   z, .full                     ;; |
    add  1                            ;; |
    daa                               ;; |
    ld   [coins], a                   ;; /
.full
    ld   hl, total_coins + 1          ;; \ total_coins++ (BCD, 4 digits)
    ld   a, [hl]                      ;; |
    add  1                            ;; |
    daa                               ;; |
    ld   [hl-], a                     ;; |
    ld   a, [hl]                      ;; |
    adc  0                            ;; |
    daa                               ;; |
    ld   [hl], a                      ;; /
    ld   hl, score + 1                ;; \ score += 10 (BCD)
    ld   a, [hl]                      ;; |
    add  $10                          ;; |
    daa                               ;; |
    ld   [hl-], a                     ;; |
    ld   a, [hl]                      ;; |
    adc  0                            ;; |
    daa                               ;; |
    ld   [hl], a                      ;; /
    ld   a, SFX_COIN
    call sfx_play
    jp   hud_refresh

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; While the hero is immune, he flashes: every 4 frames, the other palette.
;; ❌ Modifies A, HL
game_hurt_update::
    ld   hl, hurt_timer
    ld   a, [hl]
    or   a
    jr   z, .normal
    dec  [hl]
    ld   a, [hl]
    and  HURT_FLASH_MASK
    jr   z, .normal
    ld   hl, PLAYER_ENTITY + E_ATTR
    set  ATTR_PALETTE_BIT, [hl]
    ret
.normal
    ld   hl, PLAYER_ENTITY + E_ATTR
    res  ATTR_PALETTE_BIT, [hl]
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The clock: every FRAMES_PER_SEC frames, a second less to finish the level
;; and a second more in the time spent in it. The last 10 seconds tick, and
;; at 0 the game is over. The music follows the time left (game_update_tempo).
;; ❌ Modifies A, BC, HL
game_time_update::
    ld   hl, sec_frames
    dec  [hl]
    ret  nz
    ld   [hl], FRAMES_PER_SEC
    call elapsed_tick
    ld   a, [time_lo]                 ;; \ time-- (BCD: daa after sub also works)
    sub  1                            ;; |
    daa                               ;; |
    ld   [time_lo], a                 ;; |
    ld   c, a                         ;; |
    ld   a, [time_hi]                 ;; |
    sbc  0                            ;; |
    daa                               ;; |
    ld   [time_hi], a                 ;; /
    or   c                            ;; \ 0?
    jr   nz, .left                    ;; /
    ld   a, RESULT_TIMEUP
    ld   [game_result], a
    jp   hud_refresh
.left
    call game_update_tempo
    ld   a, [time_hi]                 ;; \ 10 seconds or less: tick
    or   a                            ;; |
    jr   nz, .refresh                 ;; |
    ld   a, [time_lo]                 ;; |
    cp   $11                          ;; |
    jr   nc, .refresh                 ;; |
    ld   a, SFX_TYPE                  ;; |
    call sfx_play                     ;; /
.refresh
    jp   hud_refresh

;; One second more in elapsed_mm:elapsed_ss (BCD; it stops at 99:59)
elapsed_tick:
    ld   a, [elapsed_ss]
    add  1
    daa
    cp   $60
    jr   c, .seconds
    ld   a, [elapsed_mm]
    cp   $99
    ret  z
    add  1
    daa
    ld   [elapsed_mm], a
    xor  a
.seconds
    ld   [elapsed_ss], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The speed of the music follows the time left: normal while there is more
;; than half of the time of the level, faster below the half, and faster still
;; below a third. (Seconds won make it slow down again.)
;; ❌ Modifies A, BC, HL
game_update_tempo::
    ld   b, TEMPO_NORMAL
    ld   a, [time_half]               ;; \ time < half?
    ld   hl, time_half + 1            ;; |
    call time_below                   ;; |
    jr   nc, .set                     ;; |
    ld   b, TEMPO_FAST                ;; /
    ld   a, [time_third]              ;; \ time < third?
    ld   hl, time_third + 1           ;; |
    call time_below                   ;; |
    jr   nc, .set                     ;; |
    ld   b, TEMPO_FASTER              ;; /
.set
    ld   a, b
    ld   [music_tempo], a
    ret

;; Is the time left below a BCD value? (BCD numbers compare as binary)
;; 📥 A = its high byte, HL = &its low byte   ⫷▬ carry: time < value
;; ❌ Modifies A, C
time_below:
    ld   c, a
    ld   a, [time_hi]
    cp   c
    ret  nz                           ;; different high bytes: carry says it
    ld   a, [time_lo]
    cp   [hl]
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The score (BCD, 4 digits): 10 for each coin and the seconds left at each portal.
;; ⫷▬ B = high byte, C = low byte (BCD)
;; ❌ Modifies A, BC
game_score::
    ld   a, [score]
    ld   b, a
    ld   a, [score + 1]
    ld   c, a
    ret
