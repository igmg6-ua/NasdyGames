;;==============================================================
;; sys/sys_ai.asm -- La IA de los espectros (Challenge 6, más "cazar")
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"

DEF AI_HUNT_CHANCE_BIT = 4            ;; bit of the random number: 0 = hunt this time

SECTION "AI", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; AI system, for ONE entity: every so often, it chooses what to do next.
;; Its THINK counts the frames left before it chooses. When it reaches 0:
;;   - THINK = AI_THINK_MIN + a random number (0-31): the time until the next choice.
;;   - It chooses what to do with that same random number (sys_ai_decide).
;; ⚠️ Precondition: the entity has CMP_AI.
;; 📥 DE = entity
;; ❌ Modifies A, BC, HL
sys_ai_one::

    FIELD_HL E_AI_TYPE    
    ld a, [hl]
    bit AI_HUNT_BIT, a
    jp nz, sys_ai_follow_navigation

    ld   h, d                         ;; \ HL = &entity.THINK: the same page as the entity,
    ld   a, e                         ;; | the offset added to the low byte (no carry)
    add  E_THINK                      ;; |
    ld   l, a                         ;; /
    dec  [hl]                         ;; \ One frame less to think:
    ret  nz                           ;; / it is not time yet

    push hl                           ;; Save &THINK (rng_next changes HL)
    call rng_next                     ;; A = a random number
    ld   c, a                         ;; C = the random number
    pop  hl                           ;; HL = &THINK

    and  AI_THINK_MASK                ;; \ THINK = AI_THINK_MIN + (its 5 low bits)
    add  AI_THINK_MIN                 ;; |
    ld   [hl], a                      ;; /

    ld   a, c                         ;; A = the random number again
    ; continues in sys_ai_decide
    ;; (In the Challenge 6: jp sys_ai_choose. Here a hunter may hunt instead.)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A spectre that hunts (AI_HUNT_BIT in E_AI_TYPE) goes towards the hero half
;; of the times (bit 4 of the number: the bits 7-5 are for sys_ai_choose).
;; 📥 DE = entity, A = a random number
;; ❌ Modifies A, BC, HL
sys_ai_decide:
    ld   c, a                         ;; C = the number
    FIELD_HL E_AI_TYPE                ;; \ Not a hunter: the Challenge 6 AI
    ld   a, c                         ;; |
    bit  AI_HUNT_BIT, [hl]            ;; |
    jr   z, sys_ai_choose             ;; /
    bit  AI_HUNT_CHANCE_BIT, a        ;; \ A hunter, but not this time
    jr   nz, sys_ai_choose            ;; /
    ; continues in sys_ai_hunt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Walks towards the hero, on the axis where it is further away. It does not
;; know the maze: if a wall is in the way, it bumps and thinks again.
;; 📥 DE = entity
;; ❌ Modifies A, BC, HL
sys_ai_hunt:
    FIELD_HL E_Y                      ;; \ C = |hero.Y - Y|, B = DOWN or UP
    ld   a, [PLAYER_ENTITY + E_Y]     ;; |
    sub  [hl]                         ;; |
    ld   b, DIR_DOWN                  ;; |
    jr   nc, .y_positive              ;; |
    cpl                               ;; | (negative: A = -A)
    inc  a                            ;; |
    ld   b, DIR_UP                    ;; |
.y_positive                           ;; |
    ld   c, a                         ;; /
    inc  l                            ;; \ A = |hero.X - X|, L = RIGHT or LEFT
    ld   a, [PLAYER_ENTITY + E_X]     ;; |
    sub  [hl]                         ;; |
    ld   l, DIR_RIGHT                 ;; |
    jr   nc, .x_positive              ;; |
    cpl                               ;; |
    inc  a                            ;; |
    ld   l, DIR_LEFT                  ;; |
.x_positive                           ;; /
    cp   c                            ;; \ Further in X than in Y? Go in X
    jr   c, .walk                     ;; |
    ld   b, l                         ;; /
.walk
    jp   sys_physics_walk

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The AI decides what an entity does, from a random number: half of the times it
;; stands still, and the other half it walks in one of the 4 directions.
;;    - Bit 7 of the number: 1 = stand still (sys_physics_stop).
;;    - Bits 6-5 of the number: the direction to walk (sys_physics_walk, B = direction).
;; 📥 DE = entity, A = a random number
;; ❌ Modifies A, BC, HL
;; ⚠️ sys_physics_stop and sys_physics_walk end with their own ret
sys_ai_choose::
    swap a                            ;; \ The 3 high bits of the number, to the low bits
    rrca                              ;; /
    bit  AI_STILL_BIT, a              ;; \ Stand still this time?
    jp   nz, sys_physics_stop         ;; / Yes: stop (and return)

    and  DIR_MASK                     ;; \ B = the direction (DIR_DOWN ... DIR_RIGHT)
    ld   b, a                         ;; /
    jp   sys_physics_walk             ;; Walk that way (and return)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; AI system: all the entities with CMP_AI. ❌ Modifies A, BC, DE, HL
sys_ai_update::
    ld   b, CMP_AI
    ld   hl, sys_ai_one
    jp   man_entity_forall_matching


sys_ai_follow_navigation::

    FIELD_HL E_X
    ld a, [hl]
    and 7
    jr nz, .end

    FIELD_HL E_Y
    ld a, [hl]
    and 7
    jr nz, .end

    FIELD_HL E_Y
    ld a, [hl]
    srl a
    srl a
    srl a
    ld b, a

    FIELD_HL E_X
    ld a, [hl]
    srl a
    srl a
    srl a
    ld c, a

    ld l, b
    ld h, 0
    add hl, hl
    add hl ,hl
    add hl, hl
    add hl, hl
    add hl, hl
    
    ld b, 0
    add hl, bc 

    ld bc, walk_dist
    add hl, bc

    ld a, [hl]
    cp DIR_MASK + 1
    jr nc, .not_valid

    ld b, a
    call sys_physics_walk
    ret 

    .not_valid
        call sys_physics_stop
        ret
    .end
        ret
