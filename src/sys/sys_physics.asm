;;==============================================================
;; sys/sys_physics.asm -- Movimiento y choques con el mapa
;;
;; Lo que el mapa para es la zona de los PIES de cada entidad (FEET_*): una
;; caja de 8 x 8 en la parte de abajo de su imagen de 16 x 16. Así la cabeza
;; puede "tapar" la pared de arriba, como en los juegos vistos desde arriba.
;; Cada eje se mueve por separado: si la Y choca, la X todavía puede moverse.
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"

SECTION "Enemy spacing vars", WRAM0
spacing_y: ds 1
spacing_x: ds 1
spacing_self: ds 1

SECTION "Physics", ROM0

;; The velocity of each direction (VY, VX), index = DIR * 2
DirVelocity:
    db  WALK_SPEED, 0                 ;; DIR_DOWN
    db -WALK_SPEED, 0                 ;; DIR_UP
    db  0, -WALK_SPEED                ;; DIR_LEFT
    db  0,  WALK_SPEED                ;; DIR_RIGHT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The entity walks in a direction: DIR = B, and its velocity, the one of B.
;; 📥 DE = entity, B = direction (DIR_...)
;; ❌ Modifies A, BC, HL
sys_physics_walk::
    FIELD_HL E_DIR                    ;; \ entity.DIR = B
    ld   [hl], b                      ;; /
    ld   a, b                         ;; \ BC = &DirVelocity[B]
    add  a                            ;; |
    add  LOW(DirVelocity)             ;; |
    ld   c, a                         ;; |
    ld   a, HIGH(DirVelocity)         ;; |
    adc  0                            ;; |
    ld   b, a                         ;; /
    FIELD_HL E_VY                     ;; \ VY, VX = the velocity of the direction
    ld   a, [bc]                      ;; |
    ld   [hl+], a                     ;; |
    inc  bc                           ;; |
    ld   a, [bc]                      ;; |
    ld   [hl], a                      ;; /
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The entity stops (VY = VX = 0). Its direction does not change.
;; 📥 DE = entity
;; ❌ Modifies A, HL
sys_physics_stop::
    FIELD_HL E_VY
    xor  a
    ld   [hl+], a
    ld   [hl], a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Would the feet of the entity touch a solid tile, if it moved (dY, dX)?
;; The 4 corners of the feet are checked: the box is 8 x 8 and a tile is 8 x 8,
;; so nothing solid can fit between them.
;; 📥 DE = entity, B = dY, C = dX
;; ⫷▬ NZ: blocked   Z: free
;; ❌ Modifies A, HL. Does NOT modify BC or DE
sys_physics_blocked::
    push de
    FIELD_HL E_Y                      ;; \ D = Y + dY + FEET_TOP
    ld   a, [hl+]                     ;; |
    add  b                            ;; |
    add  FEET_TOP                     ;; |
    ld   d, a                         ;; /
    ld   a, [hl]                      ;; \ E = X + dX + FEET_LEFT
    add  c                            ;; |
    add  FEET_LEFT                    ;; |
    ld   e, a                         ;; /
    call map_is_solid_at              ;; \ Top left
    jr   nz, .end                     ;; /
    ld   a, e                         ;; \ Top right
    add  FEET_RIGHT - FEET_LEFT       ;; |
    ld   e, a                         ;; |
    call map_is_solid_at              ;; |
    jr   nz, .end                     ;; /
    ld   a, d                         ;; \ Bottom right
    add  FEET_BOTTOM - FEET_TOP       ;; |
    ld   d, a                         ;; |
    call map_is_solid_at              ;; |
    jr   nz, .end                     ;; /
    ld   a, e                         ;; \ Bottom left
    sub  FEET_RIGHT - FEET_LEFT       ;; |
    ld   e, a                         ;; |
    call map_is_solid_at              ;; /
.end
    pop  de                           ;; (pop does not change the flags)
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Moves the entity (dY, dX) if nothing stops it.
;; 📥 DE = entity, B = dY, C = dX
;; ⫷▬ Z: it moved   NZ: blocked (it did not move)
;; ❌ Modifies A, HL. Does NOT modify BC or DE
sys_physics_try::
    call sys_physics_blocked
    ret  nz
    ld a, [de]
    bit CMP_AI_BIT, a
    jr z, .apply
    ;; Comprobar separacion en cada pixel: mirar solo nodos permitiria cruzarse.
    call sys_enemy_blocked
    ret nz
.apply
    FIELD_HL E_Y                      ;; \ Y += dY
    ld   a, [hl]                      ;; |
    add  b                            ;; |
    ld   [hl+], a                     ;; /
    ld   a, [hl]                      ;; \ X += dX
    add  c                            ;; |
    ld   [hl], a                      ;; /
    ld a, [de]
    bit CMP_AI_BIT, a
    jr z, .moved
    FIELD_HL E_AI_WAIT
    ld [hl], 0
.moved
    xor  a                            ;; Z
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Physics system, for ONE entity: it moves with its velocity, first in Y and
;; then in X. The spectres that are not FAST skip one frame of each 4.
;; ⚠️ Precondition: the entity has CMP_PHYSICS.
;; 📥 DE = entity
;; ❌ Modifies A, BC, HL (and the entity may be destroyed)
sys_physics_one::
    ld   a, [de]                      ;; \ A spectre...
    bit  CMP_AI_BIT, a                ;; |
    jr   z, .move                     ;; /
    FIELD_HL E_AI_TYPE                ;; \ ...that is not fast
    bit  AI_FAST_BIT, [hl]            ;; |
    jr   nz, .move                    ;; /
    ld   a, [frame_counter]           ;; \ rests 1 frame of 4
    and  AI_SLOW_MASK                 ;; |
    ret  z                            ;; /
.move
    FIELD_HL E_VY                     ;; \ Y axis: B = VY, C = 0
    ld   a, [hl]                      ;; |
    or   a                            ;; |
    jr   z, .x_axis                   ;; |
    ld   b, a                         ;; |
    ld   c, 0                         ;; |
    call sys_physics_try              ;; |
    jr   z, .x_axis                   ;; /
    call sys_physics_bump             ;; \ Blocked: what does it do?
    ret  c                            ;; / (carry: it does not exist any more)
.x_axis
    FIELD_HL E_VX                     ;; \ X axis: B = 0, C = VX
    ld   a, [hl]                      ;; |
    or   a                            ;; |
    ret  z                            ;; |
    ld   c, a                         ;; |
    ld   b, 0                         ;; |
    call sys_physics_try              ;; |
    ret  z                            ;; /
    ; continues in sys_physics_bump

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; What an entity does when the map stops it, according to its components:
;;  - SELFDESTROY (a bullet): it is destroyed.
;;  - AI (a spectre): it chooses a new direction in the next frame.
;;  - INPUT (the hero): it slides round the corner, if the way is almost free.
;; 📥 DE = entity, B = dY, C = dX (the move that was blocked)
;; ⫷▬ carry: the entity has been destroyed
;; ❌ Modifies A, BC, HL
sys_physics_bump:
    ld   a, [de]
    or   a                            ;; carry = 0
    bit  CMP_SELFDESTROY_BIT, a       ;; \ A bullet: destroyed
    jr   z, .not_bullet               ;; |
    call game_entity_destroy          ;; |
    scf                               ;; |
    ret                               ;; /
.not_bullet
    bit  CMP_AI_BIT, a                ;; \ A spectre: think again now
    jr   z, .not_ai                   ;; |
    FIELD_HL E_THINK                  ;; |
    ld   [hl], 1                      ;; |
    FIELD_HL E_AI_WAIT
    ld a, [hl]
    cp $FF
    jr z, .wait_full
    inc [hl]
.wait_full
    and  a                            ;; | carry = 0
    ret                               ;; /
.not_ai
    bit  CMP_INPUT_BIT, a             ;; \ The hero: help at the corners
    ret  z                            ;; /
    ; continues in sys_physics_assist

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Corner assist. The corridors are 16 pixels wide and the feet 8, so going
;; into a side corridor needs a good aim. If the hero is blocked but would be
;; free CORNER_ASSIST pixels (or less) to one side, it slides 1 pixel that way.
;; 📥 DE = entity, B = dY, C = dX (the move that was blocked)
;; ⫷▬ carry = 0
;; ❌ Modifies A, BC, HL
sys_physics_assist:
    ld   a, b                         ;; \ Moving in Y? Look to the sides (X).
    or   a                            ;; | Moving in X? Look up and down (Y).
    jr   z, .horizontal               ;; /
    ld   c, 1                         ;; C = how far to look (1..CORNER_ASSIST)
.vertical
    push bc                           ;; \ Free with X - C?
    ld   a, c                         ;; |
    cpl                               ;; |
    inc  a                            ;; |
    ld   c, a                         ;; |
    call sys_physics_blocked          ;; |
    pop  bc                           ;; |
    jr   z, .left                     ;; /
    call sys_physics_blocked          ;; \ Free with X + C?
    jr   z, .right                    ;; /
    inc  c                            ;; \ Look further
    ld   a, c                         ;; |
    cp   CORNER_ASSIST + 1            ;; |
    jr   c, .vertical                 ;; /
    and  a
    ret
.left
    ld   bc, $00FF                    ;; B = 0, C = -1
    jr   .slide
.right
    ld   bc, $0001                    ;; B = 0, C = 1
    jr   .slide

.horizontal
    ld   b, 1                         ;; B = how far to look
.h_loop
    push bc                           ;; \ Free with Y - B?
    ld   a, b                         ;; |
    cpl                               ;; |
    inc  a                            ;; |
    ld   b, a                         ;; |
    call sys_physics_blocked          ;; |
    pop  bc                           ;; |
    jr   z, .up                       ;; /
    call sys_physics_blocked          ;; \ Free with Y + B?
    jr   z, .down                     ;; /
    inc  b
    ld   a, b
    cp   CORNER_ASSIST + 1
    jr   c, .h_loop
    and  a
    ret
.up
    ld   bc, $FF00                    ;; B = -1, C = 0
    jr   .slide
.down
    ld   bc, $0100                    ;; B = 1, C = 0
.slide
    call sys_physics_try
    and  a
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Physics system: all the entities with CMP_PHYSICS. ❌ Modifies A, BC, DE, HL
sys_physics_update::
    ld   b, CMP_PHYSICS
    ld   hl, sys_physics_one
    jp   man_entity_forall_matching

;; DE = enemigo, B/C = desplazamiento propuesto. NZ si invade otro cuerpo.
;; No incluye al heroe ni disparos. Conserva BC y DE; modifica A, HL.
sys_enemy_blocked::
    push bc
    FIELD_HL E_Y
    ld a, [hl+]
    add b
    ld [spacing_y], a
    ld a, [hl]
    add c
    ld [spacing_x], a
    ld a, e
    ld [spacing_self], a
    ld hl, entity_array
    ld b, MAX_ENTITIES
.next
    ld a, [hl]
    bit CMP_AI_BIT, a
    jr z, .skip
    ld a, [spacing_self]
    cp l
    jr z, .skip
    inc l
    ld a, [spacing_y]
    sub [hl]
    jr nc, .positive_y
    cpl
    inc a
.positive_y
    cp ENEMY_GAP
    jr nc, .skip
    inc l
    ld a, [spacing_x]
    sub [hl]
    jr nc, .positive_x
    cpl
    inc a
.positive_x
    cp ENEMY_GAP
    jr nc, .skip
    pop bc
    ld a, 1
    or a
    ret
.skip
    ;; La entidad ocupa 16 bytes alineados; quitar el offset de Y/X antes de avanzar.
    ld a, l
    and $F0
    add SIZEOF_ENTITY
    ld l, a
    dec b
    jr nz, .next
    pop bc
    xor a
    ret
