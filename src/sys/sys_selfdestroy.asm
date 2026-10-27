;;==============================================================
;; sys/sys_selfdestroy.asm -- Entidades que duran un tiempo (balas, nubes)
;;==============================================================
INCLUDE "scn/scn_game.inc"
INCLUDE "engine/macros.inc"

SECTION "Selfdestroy", ROM0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Selfdestroy system, for ONE entity: LIFE counts the frames it has left.
;; At 0, it is destroyed (game_entity_destroy: the game may need to know).
;; ⚠️ Precondition: the entity has CMP_SELFDESTROY.
;; 📥 DE = entity
;; ❌ Modifies A, HL
sys_selfdestroy_one::
    FIELD_HL E_LIFE                   ;; \ One frame less of life
    dec  [hl]                         ;; |
    ret  nz                           ;; /
    jp   game_entity_destroy          ;; Its time is over

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; All the entities with CMP_SELFDESTROY. ❌ Modifies A, BC, DE, HL
sys_selfdestroy_update::
    ld   b, CMP_SELFDESTROY
    ld   hl, sys_selfdestroy_one
    jp   man_entity_forall_matching
