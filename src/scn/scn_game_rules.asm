;;==============================================================
;; scn/scn_game_rules.asm -- Las reglas del juego
;;
;; Los sistemas (sys/) no saben nada del juego: mueven, animan y dibujan
;; entidades. Aquí está lo que hace que esto sea "Laberinto": las plantillas
;; de las entidades, los niveles, las monedas, los disparos, los corazones,
;; el tiempo y el portal.
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"
INCLUDE "engine/gfx.inc"
INCLUDE "engine/sound.inc"
INCLUDE "man/man_map.inc"
INCLUDE "assets/levels/levels.inc"

SECTION "Game vars", WRAM0
current_level:: ds 1                  ;; 0, 1, 2
hearts::        ds 1
coins::         ds 1                  ;; BCD (the whole game)
kills::         ds 1                  ;; BCD (the whole game)
bonus::         ds 2                  ;; BCD, high byte first: seconds left at each portal
level_bonus::   ds 2                  ;; BCD: the seconds left at the last portal
enemies_left::  ds 1
time_hi::       ds 1                  ;; BCD: seconds left (time_hi is 0 or 1)
time_lo::       ds 1
sec_frames:     ds 1                  ;; frames left of this second
hurt_timer::    ds 1                  ;; frames of immunity left after a hit
shot_entity::   ds 1                  ;; low byte of the bullet (ENTITY_NONE: no bullet)
game_result::   ds 1                  ;; RESULT_...
has_gun::       ds 1                 ;; 0=nogun/1=hasgun

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
             TILE_PORTAL, KIND_GUN, 0, 0


;; The velocity of a bullet in each direction (VY, VX), index = DIR * 2
ShotVelocity:
    db  SHOT_SPEED, 0                 ;; DIR_DOWN
    db -SHOT_SPEED, 0                 ;; DIR_UP
    db  0, -SHOT_SPEED                ;; DIR_LEFT
    db  0,  SHOT_SPEED                ;; DIR_RIGHT

;; The AI of the spectres of each level: even ones, odd ones
LevelAi:
    db AI_RANDOM, AI_RANDOM           ;; level 1: they wander
    db AI_HUNTER, AI_RANDOM           ;; level 2: half of them hunt
    db AI_FAST,   AI_HUNTER           ;; level 3: fast ones and hunters
ASSERT @ - LevelAi == NUM_LEVELS * 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A new game: level 1, HEARTS_START hearts, no coins.
;; ❌ Modifies A
game_new::
    xor  a
    ld   [current_level], a
    ld   [coins], a
    ld   [kills], a
    ld   [bonus], a
    ld   [bonus + 1], a
    ld   [level_bonus], a
    ld   [level_bonus + 1], a
    ld   a, HEARTS_START
    ld   [hearts], a
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

;; Gives each spectre the AI of the level (LevelAi): even, odd, even...
;; ❌ Modifies A, BC, DE, HL
game_enemies_ai:
    ld   a, [current_level]           ;; \ B = AI of the even ones, C = of the odd ones
    add  a                            ;; |
    add  LOW(LevelAi)                 ;; |
    ld   l, a                         ;; |
    ld   a, HIGH(LevelAi)             ;; |
    adc  0                            ;; |
    ld   h, a                         ;; |
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
;; Prepares the current level: map, hero, portal, spectres, time, HUD, music.
;; ⚠️ The screen must be OFF
;; ❌ Modifies A, BC, DE, HL
game_level_start::
    call man_entity_init
    xor a
    ld [has_gun], a                   ;; NO GUN ON NEW LEVEL
    ld   a, ENTITY_NONE               ;; \ No bullet
    ld   [shot_entity], a             ;; /
    xor  a
    ld   [hurt_timer], a
    ld   [game_result], a
    ld   a, LEVEL_TIME_HI             ;; \ The clock
    ld   [time_hi], a                 ;; |
    ld   a, LEVEL_TIME_LO             ;; |
    ld   [time_lo], a                 ;; |
    ld   a, FRAMES_PER_SEC            ;; |
    ld   [sec_frames], a              ;; /

    call level_get                    ;; \ The map
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

                               ;; |
    ;ld   de, 1               ;; |
    ;add  hl, de                       ;; |
    ;ld   c, [hl]                      ;; |
    ;inc  hl                           ;; |
    ;ld   b, [hl]
    ld b, 28
    ld c, 5                      ;; |
    ld   hl, GunTemplate          ;; |
    call game_spawn_at 

    pop  hl                           ;; \ The portal
    push hl                           ;; |
    ld   de, LVL_EXIT_TX              ;; |
    add  hl, de                       ;; |
    ld   c, [hl]                      ;; |
    inc  hl                           ;; |
    ld   b, [hl]                      ;; |
    ld   hl, PortalTemplate           ;; |
    call game_spawn_at                ;; /

    pop  hl                           ;; \ The spectres
    push hl                           ;; |
    ld   de, LVL_ENEMIES              ;; |
    add  hl, de                       ;; |
    call game_enemies_spawn           ;; |
    call game_enemies_ai              ;; /

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
    jr   z, game_portal
    cp   KIND_GUN
    jr   z, .give_gun
    ret
    .give_gun:
        ld a, 1
        ld [has_gun], a
        jp man_entity_free


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A spectre touches the hero: a heart less, and some time of immunity.
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
    ld   hl, hearts
    dec  [hl]
    jr   nz, .alive
    ld   a, RESULT_DEAD
    ld   [game_result], a
.alive
    ld   a, SFX_HURT
    call sfx_play
    jp   hud_refresh

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The hero reaches the portal: the seconds left are the bonus.
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
    add  [hl]                         ;; |
    daa                               ;; |
    ld   [hl-], a                     ;; |
    ld   a, [time_hi]                 ;; |
    adc  [hl]                         ;; |
    daa                               ;; |
    ld   [hl], a                      ;; /
    ld   a, RESULT_CLEAR
    ld   [game_result], a
    ld   a, SFX_PORTAL
    jp   sfx_play

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A spectre is defeated: a cloud in its place, KILL_REWARD coins, and if it was
;; the last one of the level, a heart (up to HEARTS_MAX).
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
    ld   a, [coins]                   ;; \ coins += KILL_REWARD (BCD, up to 99)
    add  KILL_REWARD                  ;; |
    daa                               ;; |
    jr   nc, .coins_ok                ;; |
    ld   a, $99                       ;; |
.coins_ok                             ;; |
    ld   [coins], a                   ;; /
    ld   a, [kills]                   ;; \ kills++ (BCD)
    add  1                            ;; |
    daa                               ;; |
    ld   [kills], a                   ;; /
    ld   hl, enemies_left             ;; \ The last one?
    dec  [hl]                         ;; |
    ld   a, SFX_KILL                  ;; |
    jr   nz, .sound                   ;; /
    ld   a, [hearts]                  ;; \ Yes: a heart more
    cp   HEARTS_MAX                   ;; |
    jr   nc, .full                    ;; |
    inc  a                            ;; |
    ld   [hearts], a                  ;; |
.full                                 ;; |
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
    ld   a, [coins]                   ;; \ coins++ (BCD, up to 99)
    cp   $99                          ;; |
    jr   z, .full                     ;; |
    add  1                            ;; |
    daa                               ;; |
    ld   [coins], a                   ;; /
.full
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
;; The clock: a second less every FRAMES_PER_SEC frames. The last 10 seconds
;; tick, and at 0 the game is over.
;; ❌ Modifies A, BC, HL
game_time_update::
    ld   hl, sec_frames
    dec  [hl]
    ret  nz
    ld   [hl], FRAMES_PER_SEC
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
    ld   a, [time_hi]                 ;; \ 10 seconds or less: tick
    or   a                            ;; |
    jr   nz, .refresh                 ;; |
    ld   a, c                         ;; |
    cp   $11                          ;; |
    jr   nc, .refresh                 ;; |
    ld   a, SFX_TYPE                  ;; |
    call sfx_play                     ;; /
.refresh
    jp   hud_refresh

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The score: coins * 10 + bonus (BCD, 4 digits).
;; ⫷▬ B = high byte, C = low byte (BCD)
;; ❌ Modifies A, BC
game_score::
    ld   a, [coins]                   ;; \ BC = coins * 10: the digits move one place
    swap a                            ;; | ($84 -> $0840)
    ld   b, a                         ;; |
    and  $F0                          ;; |
    ld   c, a                         ;; |
    ld   a, b                         ;; |
    and  $0F                          ;; |
    ld   b, a                         ;; /
    ld   a, [bonus + 1]               ;; \ BC += bonus
    add  c                            ;; |
    daa                               ;; |
    ld   c, a                         ;; |
    ld   a, [bonus]                   ;; |
    adc  b                            ;; |
    daa                               ;; |
    ld   b, a                         ;; /
    ret
