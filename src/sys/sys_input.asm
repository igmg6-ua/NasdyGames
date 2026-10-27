;;==============================================================
;; sys/sys_input.asm -- El jugador controla al héroe
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"

SECTION "Input system", ROM0

;; The button of each direction (index = DIR)
DirButton:
    db BTN_DOWN, BTN_UP, BTN_LEFT, BTN_RIGHT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input system, for ONE entity: the D-pad makes it walk, A shoots.
;; With several directions held: the one just pressed wins; if none was just
;; pressed, it keeps the direction it had (if it is still held). This way,
;; holding RIGHT and touching UP turns at the next corner without stopping.
;; The bits of the D-pad are 0 right, 1 left, 2 up, 3 down: DIR = 3 - bit.
;; ⚠️ Precondition: the entity has CMP_INPUT.
;; 📥 DE = entity
;; ❌ Modifies A, BC, HL
sys_input_one::
    ld   a, [input_held]              ;; \ C = the directions held
    and  BTN_DPAD                     ;; |
    jr   z, .stop                     ;; | None: stop
    ld   c, a                         ;; /
    ld   a, [input_pressed]           ;; \ One just pressed? It wins
    and  BTN_DPAD                     ;; |
    jr   nz, .pick                    ;; /
    FIELD_HL E_DIR                    ;; \ B = the direction it had
    ld   b, [hl]                      ;; /
    ld   a, b                         ;; \ HL = &DirButton[B]
    add  LOW(DirButton)               ;; |
    ld   l, a                         ;; |
    ld   a, HIGH(DirButton)           ;; |
    adc  0                            ;; |
    ld   h, a                         ;; /
    ld   a, [hl]                      ;; \ Is its button still held? Keep it
    and  c                            ;; |
    jr   nz, .walk                    ;; /
.any
    ld   a, c
.pick
    ld   b, DIR_RIGHT                 ;; \ B = the direction of the lowest bit of A
.find                                 ;; | (bit 0 -> DIR_RIGHT = 3 ... bit 3 -> DIR_DOWN = 0)
    rrca                              ;; |
    jr   c, .walk                     ;; |
    dec  b                            ;; |
    jr   .find                        ;; /
.walk
    call sys_physics_walk
    jr   .shoot
.stop
    call sys_physics_stop
.shoot
    ld   a, [input_pressed]           ;; \ A: shoot
    bit  BTN_A_BIT, a                 ;; |
    ret  z                            ;; |
    jp   game_shoot                   ;; /

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input system: all the entities with CMP_INPUT. ❌ Modifies A, BC, DE, HL
sys_input_update::
    ld   b, CMP_INPUT
    ld   hl, sys_input_one
    jp   man_entity_forall_matching
